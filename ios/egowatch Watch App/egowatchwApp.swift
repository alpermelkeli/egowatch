//
//  egowatchwApp.swift
//  egowatchw Watch App
//
//  Created by alpermelkeli on 29.03.2026.
//

import SwiftUI

@main
struct egowatchw_Watch_AppApp: App {
    init() {
        // İstekleri iPhone'a iletmek için WatchConnectivity oturumunu başlat.
        WatchSessionManager.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
