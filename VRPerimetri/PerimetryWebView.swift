// PerimetryWebView.swift
// VR-Perimetri
//
// WKWebView sarmalayıcı — HTML perimetri uygulamasını native iOS içinde çalıştırır.
//
// Özellikler:
// - Tam ekran WKWebView (safe area yok sayılır)
// - JavaScript ↔ Swift köprüsü (sonuç dışa aktarma, parlaklık kontrolü)
// - Gamepad desteği (GCController framework)
// - Otomatik parlaklık yönetimi
// - JSON sonuç dosyalarını paylaşma

import SwiftUI
import WebKit
import GameController

// MARK: - SwiftUI Wrapper

struct PerimetryWebView: UIViewRepresentable {

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {

        // === WKWebView Yapılandırma ===
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        // JavaScript ↔ Swift iletişim kanalı
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "vrPerimetri")

        // Viewport ve touch delay optimizasyonu
        let viewportScript = WKUserScript(
            source: """
            // iOS Safari'de 300ms touch delay'i kaldır
            document.addEventListener('touchstart', function(){}, {passive: true});

            // Native uygulama olduğunu bildir
            window.isNativeApp = true;

            // Parlaklık kontrol fonksiyonu
            window.setBrightness = function(level) {
                window.webkit.messageHandlers.vrPerimetri.postMessage({
                    action: 'setBrightness', value: level
                });
            };

            // JSON dışa aktarma fonksiyonu (native paylaşım sayfası)
            window.nativeExportJSON = function(jsonString, filename) {
                window.webkit.messageHandlers.vrPerimetri.postMessage({
                    action: 'exportJSON', data: jsonString, filename: filename
                });
            };

            // Gamepad bağlantı durumu sorgulama
            window.checkNativeGamepad = function() {
                window.webkit.messageHandlers.vrPerimetri.postMessage({
                    action: 'checkGamepad'
                });
            };
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        contentController.addUserScript(viewportScript)
        config.userContentController = contentController

        // Tercihler
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        // === WebView Oluşturma ===
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = true
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black

        // Scroll davranışını devre dışı bırak (VR modu için)
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        // Safe area görmezden gel — tam ekran
        if #available(iOS 16.4, *) {
            webView.isInspectable = true // Geliştirme sırasında Safari Web Inspector
        }

        // Navigation delegate
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView

        // === HTML Dosyasını Yükle ===
        if let htmlURL = Bundle.main.url(forResource: "vr-perimetri", withExtension: "html") {
            webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
        }

        // === Gamepad Dinleme ===
        context.coordinator.startGamepadMonitoring()

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Güncelleme gerekli değil
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        coordinator.stopGamepadMonitoring()
    }
}

// MARK: - Coordinator (JavaScript ↔ Swift Köprüsü)

extension PerimetryWebView {

    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {

        weak var webView: WKWebView?
        private var gamepadObservers: [Any] = []

        // MARK: JavaScript → Swift Mesajları

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard let body = message.body as? [String: Any],
                  let action = body["action"] as? String else { return }

            switch action {

            case "setBrightness":
                if let level = body["value"] as? Double {
                    DispatchQueue.main.async {
                        UIScreen.main.brightness = CGFloat(max(0, min(1, level)))
                    }
                }

            case "savePDF", "exportPDF":
                if let base64String = body["data"] as? String,
                   let filename = body["filename"] as? String {
                    saveAndShare(base64Data: Data(base64Encoded: base64String), filename: filename)
                }

            case "saveJSON", "exportJSON":
                if let jsonString = body["data"] as? String,
                   let filename = body["filename"] as? String {
                    saveAndShare(base64Data: jsonString.data(using: .utf8), filename: filename)
                }

            case "checkGamepad":
                let connected = !GCController.controllers().isEmpty
                webView?.evaluateJavaScript(
                    "window._nativeGamepadConnected = \(connected);"
                )

            default:
                break
            }
        }

        // MARK: Dosya Kaydetme + Paylaşım

        /// Documents/VR-Perimetri/ klasörüne kaydeder, ardından share sheet açar
        private func saveAndShare(base64Data: Data?, filename: String) {
            guard let data = base64Data else {
                notifyJS(success: false, message: "Veri oluşturulamadı")
                return
            }

            // 1) Documents/VR-Perimetri/ klasörüne kaydet
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let vrDir = documentsURL.appendingPathComponent("VR-Perimetri", isDirectory: true)
            var savedURL: URL?

            do {
                try FileManager.default.createDirectory(at: vrDir, withIntermediateDirectories: true)
                let fileURL = vrDir.appendingPathComponent(filename)
                try data.write(to: fileURL)
                savedURL = fileURL
                print("[VRPerimetri] Dosya kaydedildi: \(fileURL.path)")
            } catch {
                print("[VRPerimetri] Documents'a kaydetme hatası: \(error)")
            }

            // 2) Share sheet aç — kullanıcı "Dosyalara Kaydet" / AirDrop / vb. seçebilir
            let shareURL: URL
            if let saved = savedURL {
                shareURL = saved
            } else {
                // Documents'a yazılamadıysa temp'e yaz
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                do {
                    try data.write(to: tempURL)
                    shareURL = tempURL
                } catch {
                    print("[VRPerimetri] Temp'e de yazılamadı: \(error)")
                    notifyJS(success: false, message: "Dosya kaydedilemedi")
                    return
                }
            }

            DispatchQueue.main.async { [weak self] in
                guard let webView = self?.webView,
                      let rootVC = webView.window?.rootViewController else {
                    self?.notifyJS(success: false, message: "Ekran bulunamadı")
                    return
                }

                let activityVC = UIActivityViewController(
                    activityItems: [shareURL],
                    applicationActivities: nil
                )

                // iPad popover
                if let popover = activityVC.popoverPresentationController {
                    popover.sourceView = webView
                    popover.sourceRect = CGRect(
                        x: webView.bounds.midX,
                        y: webView.bounds.midY,
                        width: 0, height: 0
                    )
                }

                activityVC.completionWithItemsHandler = { [weak self] _, completed, _, _ in
                    self?.notifyJS(
                        success: true,
                        message: completed
                            ? "Dosya paylaşıldı: \(filename)"
                            : "Dosya kaydedildi: \(filename)"
                    )
                }

                rootVC.present(activityVC, animated: true)
            }
        }

        private func notifyJS(success: Bool, message: String) {
            let escapedMsg = message.replacingOccurrences(of: "'", with: "\\'")
            DispatchQueue.main.async { [weak self] in
                self?.webView?.evaluateJavaScript("""
                    if (typeof window._onFileSaved === 'function') {
                        window._onFileSaved(\(success), '\(escapedMsg)');
                    }
                """)
            }
        }

        // MARK: Gamepad (MFi / Xbox / PS5 Controller)

        func startGamepadMonitoring() {
            // Mevcut controller'ları kontrol et
            for controller in GCController.controllers() {
                setupController(controller)
            }

            // Yeni bağlantıları dinle
            let connectObserver = NotificationCenter.default.addObserver(
                forName: .GCControllerDidConnect,
                object: nil, queue: .main
            ) { [weak self] notification in
                if let controller = notification.object as? GCController {
                    self?.setupController(controller)
                    self?.webView?.evaluateJavaScript(
                        "console.log('[Native] Gamepad bağlandı: \(controller.vendorName ?? "Unknown")');"
                    )
                }
            }

            let disconnectObserver = NotificationCenter.default.addObserver(
                forName: .GCControllerDidDisconnect,
                object: nil, queue: .main
            ) { [weak self] _ in
                self?.webView?.evaluateJavaScript(
                    "console.log('[Native] Gamepad bağlantısı kesildi');"
                )
            }

            gamepadObservers = [connectObserver, disconnectObserver]

            // Controller arama başlat
            GCController.startWirelessControllerDiscovery {}
        }

        func stopGamepadMonitoring() {
            GCController.stopWirelessControllerDiscovery()
            for observer in gamepadObservers {
                NotificationCenter.default.removeObserver(observer)
            }
            gamepadObservers.removeAll()
        }

        private func setupController(_ controller: GCController) {
            // Herhangi bir butona basıldığında JavaScript'e bildir
            if let gamepad = controller.extendedGamepad {
                gamepad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
                    if pressed { self?.sendGamepadPress() }
                }
                gamepad.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in
                    if pressed { self?.sendGamepadPress() }
                }
                gamepad.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in
                    if pressed { self?.sendGamepadPress() }
                }
                gamepad.buttonY.pressedChangedHandler = { [weak self] _, _, pressed in
                    if pressed { self?.sendGamepadPress() }
                }
                // Shoulder / trigger buttons
                gamepad.rightShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
                    if pressed { self?.sendGamepadPress() }
                }
                gamepad.leftShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
                    if pressed { self?.sendGamepadPress() }
                }
                gamepad.rightTrigger.pressedChangedHandler = { [weak self] _, _, pressed in
                    if pressed { self?.sendGamepadPress() }
                }
                gamepad.leftTrigger.pressedChangedHandler = { [weak self] _, _, pressed in
                    if pressed { self?.sendGamepadPress() }
                }
            } else if let micro = controller.microGamepad {
                micro.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
                    if pressed { self?.sendGamepadPress() }
                }
                micro.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in
                    if pressed { self?.sendGamepadPress() }
                }
            }
        }

        private func sendGamepadPress() {
            DispatchQueue.main.async { [weak self] in
                // Doğrudan InputHandler'ın trigger fonksiyonunu çağır
                self?.webView?.evaluateJavaScript("""
                    if (typeof InputHandler !== 'undefined') {
                        // Simulate a keyboard space press event for the input handler
                        document.dispatchEvent(new KeyboardEvent('keydown', {
                            code: 'Space', key: ' ', bubbles: true
                        }));
                    }
                """)
            }
        }

        // MARK: WKNavigationDelegate

        func webView(
            _ webView: WKWebView,
            didFinish navigation: WKNavigation!
        ) {
            // Sayfa yüklendikten sonra status bar'ı gizle
            webView.evaluateJavaScript("""
                document.body.style.webkitUserSelect = 'none';
                document.body.style.webkitTouchCallout = 'none';
                // Rubber-band scroll engelle
                document.body.addEventListener('touchmove', function(e) {
                    if (e.target.closest('.results-screen')) return;
                    e.preventDefault();
                }, { passive: false });
            """)
        }
    }
}
