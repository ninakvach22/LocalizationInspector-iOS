# LocalizationInspector

Debug aracı: çalışan uygulamada ekrandaki herhangi bir yazının hangi CMS
(`ContentManager`) localization key'inden geldiğini gösterir; key'i olmayan
(hardcoded veya panelde tanımsız) metinleri işaretler.

Tek repo'dan yönetilir, tüm projelere Swift Package Manager ile eklenir.

- **Min iOS:** 12.0
- **Bağımlılık:** yok
- **UI:** kendi `UIWindow`'unda yaşar (app root VC değişse de kaybolmaz)

## Nasıl görünür

Sağ altta yüzen butonlar:

| Buton | İşlev |
|-------|-------|
| 🔑 | Inspect modunu açar/kapatır. Açıkken ekrandaki label / button / text field / text view'a dokun → key, renk, font, frame bilgisi alert'te çıkar. `exact match` (metin = değer) ve `partial match` (metin değeri içeriyor) ayrı gösterilir; eşleşme yoksa "Unknown". "Copy Key" / "Copy Color" ile panoya kopyalar. |
| 🌐 | Sadece `observesNetwork = true` iken görünür. Gözlemlenen HTTP(S) isteklerinin listesi (All / API / Other filtre) → satıra dokun → request/response header'ları, body (JSON pretty-print, görselse önizleme), timing, boyut. Paylaş butonu cURL + response/görsel verir. |
| 📋 | UserDefaults içeriği (App / All filtre, key arama) → satıra dokun → tam değer, tip, kopyala / sil. |

Butonlar sürüklenebilir. Inspect modu kapalıyken dokunuşlar uygulamaya normal geçer.

### Network observer

```swift
var config = LocalizationInspectorConfiguration { ContentManager.shared.newContents }
config.observesNetwork = true
LocalizationInspector.shared.start(configuration: config)
```

`URLSessionConfiguration.default` / `.ephemeral` kullanan session'ları yakalar — bu
Alamofire'ın varsayılan `Session`'ını ve çoğu ağ katmanını kapsar. **Kapsamaz:**
`URLSession.shared`, background session'lar, streaming/WebSocket, `URLSession` dışı
(CFNetwork/soket) trafik. Response body'leri bellekte `config.maxNetworkBodyBytes`
(varsayılan 4 MB) kadar tutulur, son 500 istek saklanır.

> Interceptor'ı Alamofire `Session` oluşmadan önce kurmak için `didFinishLaunchingWithOptions`
> başında `LocalizationInspector.shared.observeNetwork()` çağır.

## Kurulum

### 1. Paketi ekle

Xcode → **File › Add Package Dependencies** → repo URL'i gir:

```
https://github.com/altamira-yonetim-ve-danismanlik/LocalizationInspector-iOS
```

Sürüm kuralı: **Up to Next Major** (örn. `1.0.0`).
`LocalizationInspector` ürününü **uygulama target'ına** ekle.

> CocoaPods kullanan projelerde (Jety, Condo) SPM paketleri sorunsuz birlikte
> çalışır — Podfile'a dokunmaya gerek yok.

### 2. Başlat

`AppDelegate` içinde, **yalnızca DEBUG build'de**:

```swift
#if DEBUG
import LocalizationInspector
#endif

func applicationDidBecomeActive(_ application: UIApplication) {
    // ... mevcut kod ...
    #if DEBUG
    LocalizationInspector.shared.start { ContentManager.shared.newContents }
    #endif
}
```

`start` idempotent'tir — birden çok kez çağrılması sorun değil.

## Yapılandırma

```swift
var config = LocalizationInspectorConfiguration {
    ContentManager.shared.newContents
}
config.detectsUndefinedKeys = true   // "a.b.c" metni + sözlükte yok => backend key (default true)
config.allowsPartialMatch   = true   // value, metnin içinde geçiyorsa da eşleştir (default true)
config.isEnabled            = true   // false => start() hiçbir şey yapmaz (default true)

LocalizationInspector.shared.start(configuration: config)
```

`stop()` inspector penceresini kaldırır.

## `detectsUndefinedKeys` neden var

`ContentManager.getText(_:)`, key panelde tanımlı değilse key string'in kendisini
döndürür (analist raw key'i görüp panelden tanımlasın diye). Bu durumda ekranda
`welcome.title` gibi bir yazı görünür. Inspector bunu "hardcoded" değil,
**"Backend key — panelde tanımlı değil"** olarak ayırır ve ⚠️ taramasında turuncu
gösterir.

## Geliştirme

```bash
swift test          # KeyMatcher birim testleri (saf, UIKit'siz)
```

UIKit katmanı iOS simulator hedefiyle derlenir:

```bash
xcodebuild -scheme LocalizationInspector-iOS -destination 'generic/platform=iOS Simulator' build
```

## Mimari

| Dosya | Sorumluluk |
|-------|------------|
| `LocalizationInspector` | public facade — `start` / `stop` / `observeNetwork` / `isRunning` |
| `LocalizationInspectorConfiguration` | public ayarlar (`entriesProvider`, `observesNetwork`, `apiHosts`, …) |
| `InspectorWindow` | `.statusBar + 1` seviyesinde şeffaf pencere, hit-test pass-through |
| `InspectorRootViewController` | yüzen butonlar (🔑 🌐 📋), tap-overlay, toast, alert |
| `HostWindowResolver` | app'in key window'unu bulur (iOS 13+ / iOS 12) |
| `KeyMatcher` | saf sınıflandırma: backendExact / backendPartial / backendUndefined / staticText |
| `ViewIntrospector` | text / renk / font / frame / background çıkarımı |
| `ResultFormatter` | alert metni |
| `Network/NetworkObserver` | `URLProtocol` interceptor + `URLSessionConfiguration` swizzle |
| `Network/NetworkTransaction` · `NetworkTransactionStore` | model + thread-safe, size-capped history |
| `NetworkUI/NetworkListViewController` | istek listesi + All/API/Other filtre + arama |
| `NetworkUI/NetworkDetailViewController` | header / body / görsel önizleme / timing / cURL |
| `NetworkUI/NetworkFormatting` | scope sınıflandırma, byte/duration/JSON biçimleme |
| `DefaultsUI/UserDefaultsViewController` | UserDefaults listesi / detay / kopyala / sil |
