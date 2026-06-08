//
//  ContentView.swift
//  egowatch
//

import SwiftUI

struct ContentView: View {
    @StateObject private var favorites = FavoritesStore.shared
    private let service = DirectEGOService()

    var body: some View {
        TabView {
            IOSStopHomeView(service: service, favorites: favorites)
                .tabItem {
                    Label("Duraklar", systemImage: "mappin.and.ellipse")
                }

            IOSLineHomeView(service: service, favorites: favorites)
                .tabItem {
                    Label("Hatlar", systemImage: "bus.fill")
                }
        }
        .tint(EGOTheme.accentBright)
        .preferredColorScheme(.dark)
    }
}
