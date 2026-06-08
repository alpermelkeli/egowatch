//
//  LineViewModels.swift
//  egowatch (Shared)
//

import Combine
import Foundation

@MainActor
final class LineHomeViewModel: ObservableObject {
    let favorites: FavoritesStore

    init(favorites: FavoritesStore) {
        self.favorites = favorites
    }
}

@MainActor
final class LineListViewModel: ObservableObject {
    @Published private(set) var lines: [BusLine] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var query = ""

    let type: TransitType
    private let service: EGOService

    init(type: TransitType, service: EGOService) {
        self.type = type
        self.service = service
    }

    var filteredLines: [BusLine] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return lines }
        return lines.filter {
            $0.code.localizedCaseInsensitiveContains(term) ||
            $0.name.localizedCaseInsensitiveContains(term)
        }
    }

    func load() async {
        guard !isLoading, lines.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        do {
            lines = try await service.lineList(type: type)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

@MainActor
final class LineScheduleViewModel: ObservableObject {
    @Published private(set) var schedule: LineSchedule?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedDay = ServiceDay.current()
    @Published var favoriteName = ""
    @Published var isShowingFavoriteSheet = false

    let line: BusLine
    private let service: EGOService
    private let favorites: FavoritesStore

    init(line: BusLine, service: EGOService, favorites: FavoritesStore) {
        self.line = line
        self.service = service
        self.favorites = favorites
        favoriteName = favorites.lines.first { $0.lineCode == line.code && $0.type == line.type }?.displayName ?? ""
    }

    var isFavorite: Bool {
        favorites.isFavoriteLine(line)
    }

    var selectedTimes: [String] {
        schedule?.schedule.times(for: selectedDay) ?? []
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            schedule = try await service.lineSchedule(lineNo: line.code, type: line.type)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func toggleFavorite() {
        if isFavorite {
            favorites.removeLine(line)
        } else {
            favoriteName = favoriteName.isEmpty ? line.displayLabel : favoriteName
            isShowingFavoriteSheet = true
        }
    }

    func saveFavorite() {
        favorites.addLine(line, name: favoriteName)
        isShowingFavoriteSheet = false
    }
}
