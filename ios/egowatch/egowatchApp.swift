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
        // Siri'nin favori durak/hat değerlerini güncel tut.
        EgoShortcuts.refresh()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
