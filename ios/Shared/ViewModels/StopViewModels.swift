//
//  StopViewModels.swift
//  egowatch (Shared)
//

import Combine
import Foundation

@MainActor
final class StopHomeViewModel: ObservableObject {
    @Published var stopNumber = ""

    let favorites: FavoritesStore

    init(favorites: FavoritesStore) {
        self.favorites = favorites
    }

    var normalizedStopNumber: String {
        String(stopNumber.filter(\.isNumber).prefix(5))
    }

    var canSearch: Bool {
        normalizedStopNumber.count == 5
    }

    func sanitizeStopNumber() {
        stopNumber = normalizedStopNumber
    }
}

@MainActor
final class StopDetailViewModel: ObservableObject {
    @Published private(set) var arrivals: [BusArrival] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var favoriteName = ""
    @Published var isShowingFavoriteSheet = false

    let stopNo: String
    private let service: EGOService
    private let favorites: FavoritesStore

    init(stopNo: String, service: EGOService, favorites: FavoritesStore) {
        self.stopNo = stopNo
        self.service = service
        self.favorites = favorites
        favoriteName = favorites.stops.first { $0.stopNo == stopNo }?.displayName ?? ""
    }

    var isFavorite: Bool {
        favorites.isFavoriteStop(stopNo)
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            arrivals = try await service.busArrivals(stopNo: stopNo)
            #if os(iOS)
            if isFavorite, SeenLinesStore.record(stopNo: stopNo, arrivals: arrivals) {
                EgoShortcuts.refresh()
            }
            #endif
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func toggleFavorite() {
        if isFavorite {
            favorites.removeStop(stopNo)
        } else {
            favoriteName = favoriteName.isEmpty ? "Durak \(stopNo)" : favoriteName
            isShowingFavoriteSheet = true
        }
    }

    func saveFavorite() {
        favorites.addStop(stopNo: stopNo, name: favoriteName)
        isShowingFavoriteSheet = false
    }
}
