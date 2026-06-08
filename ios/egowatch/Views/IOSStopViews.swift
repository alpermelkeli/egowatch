//
//  IOSStopViews.swift
//  egowatch
//

import SwiftUI

struct IOSStopHomeView: View {
    @StateObject private var viewModel: StopHomeViewModel
    let service: EGOService
    @ObservedObject var favorites: FavoritesStore

    init(service: EGOService, favorites: FavoritesStore) {
        self.service = service
        self.favorites = favorites
        _viewModel = StateObject(wrappedValue: StopHomeViewModel(favorites: favorites))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Durak Sorgula")
                            .font(.largeTitle.weight(.bold))
                        TextField("5 haneli durak numarası", text: $viewModel.stopNumber)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: viewModel.stopNumber) { _, _ in
                                viewModel.sanitizeStopNumber()
                            }

                        if viewModel.canSearch {
                            NavigationLink {
                                StopDetailView(stopNo: viewModel.normalizedStopNumber, service: service, favorites: favorites)
                            } label: {
                                EGOActionLabel(title: "Durak Sorgula", systemImage: "magnifyingglass.circle.fill")
                            }
                            .buttonStyle(.plain)
                        } else {
                            EGOActionButton(title: "Durak Sorgula", systemImage: "magnifyingglass.circle.fill") {}
                                .opacity(0.45)
                        }
                    }

                    favoritesSection
                }
                .padding()
            }
            .background(EGOTheme.background.ignoresSafeArea())
        }
    }

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Favori Duraklar")
                .font(.headline)

            if favorites.stops.isEmpty {
                EGOStateView(title: "Favori durak yok", systemImage: "star")
                    .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                ForEach(favorites.stops) { favorite in
                    NavigationLink {
                        StopDetailView(stopNo: favorite.stopNo, service: service, favorites: favorites)
                    } label: {
                        FavoriteStopRow(favorite: favorite)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct StopDetailView: View {
    @StateObject private var viewModel: StopDetailViewModel
    @ObservedObject private var favorites: FavoritesStore

    init(stopNo: String, service: EGOService, favorites: FavoritesStore) {
        _favorites = ObservedObject(wrappedValue: favorites)
        _viewModel = StateObject(wrappedValue: StopDetailViewModel(stopNo: stopNo, service: service, favorites: favorites))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                Text(viewModel.stopNo)
                    .font(.largeTitle.weight(.bold).monospacedDigit())
                content
            }
            .padding()
        }
        .background(EGOTheme.background.ignoresSafeArea())
        .navigationTitle("Durak")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: viewModel.toggleFavorite) {
                    Image(systemName: viewModel.isFavorite ? "star.fill" : "star")
                }
                .tint(EGOTheme.accentBright)
            }
        }
        .refreshable {
            await viewModel.load()
        }
        .task {
            await viewModel.load()
        }
        .sheet(isPresented: $viewModel.isShowingFavoriteSheet) {
            FavoriteNameSheet(title: "Favori Durak", name: $viewModel.favoriteName, save: viewModel.saveFavorite)
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.arrivals.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 220)
        } else if let error = viewModel.errorMessage {
            EGOStateView(title: error, systemImage: "exclamationmark.triangle")
                .frame(maxWidth: .infinity, minHeight: 220)
        } else if viewModel.arrivals.isEmpty {
            EGOStateView(title: "Yaklaşan araç bulunamadı", systemImage: "bus")
                .frame(maxWidth: .infinity, minHeight: 220)
        } else {
            ForEach(viewModel.arrivals) { arrival in
                BusArrivalCard(arrival: arrival)
            }
        }
    }
}
