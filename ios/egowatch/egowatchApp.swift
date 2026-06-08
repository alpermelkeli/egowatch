//
//  egowatchApp.swift
//  egowatch
//
//  Created by alpermelkeli on 29.03.2026.
//

import SwiftUI

@main
struct egowatchApp: App {
    init() {
        // Watch'tan gelecek istekleri karşılamak için WatchConnectivity oturumunu başlat.
        PhoneSessionManager.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
