// AppDelegate.swift
// VR-Perimetri
//
// Uygulama yaşam döngüsü yönetimi:
// - Ekran parlaklığını maksimuma ayarlama
// - Otomatik kilit (idle timer) devre dışı bırakma
// - Yalnızca landscape yönelim desteği

import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        // Ekranın kapanmasını engelle (Wake Lock yerine native çözüm)
        UIApplication.shared.isIdleTimerDisabled = true

        // Ekran parlaklığını maksimuma ayarla
        UIScreen.main.brightness = 1.0

        return true
    }

    // Uygulama ön plana geldiğinde parlaklığı tekrar ayarla
    func applicationDidBecomeActive(_ application: UIApplication) {
        UIScreen.main.brightness = 1.0
        UIApplication.shared.isIdleTimerDisabled = true
    }

    // Yalnızca landscape yönelim
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        return .landscape
    }
}
