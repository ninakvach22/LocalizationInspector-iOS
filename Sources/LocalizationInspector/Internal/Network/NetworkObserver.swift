import Foundation

/// Installs a URL-loading interceptor that records every HTTP(S) round trip
/// made through `URLSession` (including `URLSession.shared` and the default /
/// ephemeral configurations most apps and networking libraries use).
enum NetworkObserver {

    private static var installed = false

    static func install() {
        guard !installed else { return }
        installed = true
        URLProtocol.registerClass(InspectorURLProtocol.self)
        InspectorURLProtocol.injectIntoSessionConfigurations()
    }
}

// MARK: - Interceptor

final class InspectorURLProtocol: URLProtocol {

    private static let handledKey = "LocalizationInspector.handled"

    private var transaction: NetworkTransaction?
    private var accumulated = Data()
    private var proxySession: URLSession?
    private var proxyTask: URLSessionDataTask?

    override class func canInit(with request: URLRequest) -> Bool {
        guard let scheme = request.url?.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return false
        }
        return property(forKey: handledKey, in: request) == nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let mutable = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        InspectorURLProtocol.setProperty(true, forKey: InspectorURLProtocol.handledKey, in: mutable)

        let transaction = NetworkTransaction(request: request)
        self.transaction = transaction
        NetworkTransactionStore.shared.insert(transaction)

        let config = URLSessionConfiguration.default
        config.protocolClasses = (config.protocolClasses ?? []).filter { $0 != InspectorURLProtocol.self }
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        self.proxySession = session

        let task = session.dataTask(with: mutable as URLRequest)
        self.proxyTask = task
        task.resume()
    }

    override func stopLoading() {
        proxyTask?.cancel()
        proxySession?.invalidateAndCancel()
    }

    // MARK: Config injection

    static func injectIntoSessionConfigurations() {
        let selectors = ["defaultSessionConfiguration", "ephemeralSessionConfiguration"]

        for name in selectors {
            let selector = NSSelectorFromString(name)
            guard let method = class_getClassMethod(URLSessionConfiguration.self, selector) else { continue }

            typealias Getter = @convention(c) (AnyObject, Selector) -> URLSessionConfiguration
            let originalGetter = unsafeBitCast(method_getImplementation(method), to: Getter.self)

            let block: @convention(block) (AnyObject) -> URLSessionConfiguration = { obj in
                let config = originalGetter(obj, selector)
                var classes = config.protocolClasses ?? []
                if !classes.contains(where: { $0 == InspectorURLProtocol.self }) {
                    classes.insert(InspectorURLProtocol.self, at: 0)
                    config.protocolClasses = classes
                }
                return config
            }
            method_setImplementation(method, imp_implementationWithBlock(block))
        }
    }
}

// MARK: - Proxy session delegate

extension InspectorURLProtocol: URLSessionDataDelegate {

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        transaction?.recordResponse(response)
        if let transaction = transaction { NetworkTransactionStore.shared.markUpdated(transaction) }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        client?.urlProtocol(self, didLoad: data)
        transaction?.appendReceived(data)
        let cap = NetworkTransactionStore.shared.maxBodyBytes
        if accumulated.count < cap {
            accumulated.append(data.prefix(cap - accumulated.count))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }
        let truncated = (transaction?.receivedByteCount ?? 0) > Int64(accumulated.count)
        transaction?.finish(body: accumulated, truncated: truncated, error: error)
        if let transaction = transaction { NetworkTransactionStore.shared.markUpdated(transaction) }
        proxySession?.finishTasksAndInvalidate()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        // Follow redirects internally; the client sees only the final response.
        completionHandler(request)
    }
}
