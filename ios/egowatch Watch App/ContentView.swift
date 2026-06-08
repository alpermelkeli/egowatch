//
//  ContentView.swift
//  egowatchw Watch App
//

import SwiftUI

struct ContentView: View {
    @StateObject private var favorites = FavoritesStore.shared
    private let service = WatchConnectivityEGOService()

    var body: some View {
        TabView {
            NavigationStack {
                WatchStopHomeView(service: service, favorites: favorites)
                    .toolbarBackground(EGOTheme.background, for: .navigationBar)
            }

            NavigationStack {
                WatchLineHomeView(service: service, favorites: favorites)
                    .toolbarBackground(EGOTheme.background, for: .navigationBar)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .tint(EGOTheme.accentBright)
        .preferredColorScheme(.dark)
    }
}
