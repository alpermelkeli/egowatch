//
//  Favorites.swift
//  egowatch (Shared)
//

import Combine
import Foundation
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

nonisolated struct FavoriteStop: Codable, Identifiable, Hashable {
    let stopNo: String
    var displayName: String
    let createdAt: Date

    var id: String { stopNo }
    var title: String { displayName.isEmpty ? "Durak \(stopNo)" : displayName }
}

nonisolated struct FavoriteLine: Codable, Identifiable, Hashable {
    let lineCode: String
    let lineName: String
    let type: TransitType
    var displayName: String
    let createdAt: Date

    var id: String { "\(type.rawValue):\(lineCode)" }
    var title: String { displayName.isEmpty ? lineName : displayName }

    var busLine: BusLine {
        BusLine(code: lineCode, name: lineName, type: type)
    }
}

nonisolated struct FavoritesSnapshot: Codable, Hashable {
    let stops: [FavoriteStop]
    let lines: [FavoriteLine]
}

@MainActor
final class FavoritesStore: ObservableObject {
    static let shared = FavoritesStore()

    @Published private(set) var stops: [FavoriteStop] = []
    @Published private(set) var lines: [FavoriteLine] = []

    private let defaults: UserDefaults
    private let stopsKey = "favoriteStops.v1"
    private let linesKey = "favoriteLines.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func isFavoriteStop(_ stopNo: String) -> Bool {
        stops.contains { $0.stopNo == stopNo }
    }

    func isFavoriteLine(_ line: BusLine) -> Bool {
        lines.contains { $0.lineCode == line.code && $0.type == line.type }
    }

    func addStop(stopNo: String, name: String) {
        let favorite = FavoriteStop(stopNo: stopNo, displayName: name.trimmingCharacters(in: .whitespacesAndNewlines), createdAt: Date())
        stops.removeAll { $0.stopNo == stopNo }
        stops.insert(favorite, at: 0)
        saveStops()
        syncToPairedDevice()
        refreshSiriParameters()
    }

    func removeStop(_ stopNo: String) {
        stops.removeAll { $0.stopNo == stopNo }
        saveStops()
        syncToPairedDevice()
        refreshSiriParameters()
    }

    func addLine(_ line: BusLine, name: String) {
        let favorite = FavoriteLine(
            lineCode: line.code,
            lineName: line.name,
            type: line.type,
            displayName: name.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: Date()
        )
        lines.removeAll { $0.lineCode == line.code && $0.type == line.type }
        lines.insert(favorite, at: 0)
        saveLines()
        syncToPairedDevice()
        refreshSiriParameters()
    }

    func removeLine(_ line: BusLine) {
        lines.removeAll { $0.lineCode == line.code && $0.type == line.type }
        saveLines()
        syncToPairedDevice()
        refreshSiriParameters()
    }

    func snapshot() -> FavoritesSnapshot {
        FavoritesSnapshot(stops: stops, lines: lines)
    }

    func apply(_ snapshot: FavoritesSnapshot) {
        guard snapshot.stops != stops || snapshot.lines != lines else { return }
        stops = snapshot.stops
        lines = snapshot.lines
        saveStops()
        saveLines()
        refreshSiriParameters()
    }

    private func load() {
        if let data = defaults.data(forKey: stopsKey),
           let decoded = try? JSONDecoder().decode([FavoriteStop].self, from: data) {
            stops = decoded
        }
        if let data = defaults.data(forKey: linesKey),
           let decoded = try? JSONDecoder().decode([FavoriteLine].self, from: data) {
            lines = decoded
        }
    }

    private func saveStops() {
        defaults.set(try? JSONEncoder().encode(stops), forKey: stopsKey)
    }

    private func saveLines() {
        defaults.set(try? JSONEncoder().encode(lines), forKey: linesKey)
    }

    /// Siri'nin tanıdığı durak/hat değerlerini tazeler (App Shortcuts yalnızca iPhone'da).
    private func refreshSiriParameters() {
        #if os(iOS)
        EgoShortcuts.refresh()
        #endif
    }

    private func syncToPairedDevice() {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        guard let data = try? JSONEncoder().encode(snapshot()) else { return }
        try? session.updateApplicationContext(["favoritesSnapshot": data])
        #endif
    }
}
