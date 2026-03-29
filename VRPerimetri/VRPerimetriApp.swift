// VRPerimetriApp.swift
// VR-Perimetri — iPhone + Google Cardboard Visual Field Test
//
// Ana uygulama giriş noktası (SwiftUI App lifecycle)

import SwiftUI

@main
struct VRPerimetriApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            PerimetryWebView()
                .ignoresSafeArea(.all)
                .preferredColorScheme(.dark)
                .persistentSystemOverlays(.hidden)
        }
    }
}
