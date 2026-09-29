//
//  SeenLinesStore.swift
//  egowatch (Shared)
//
//  Favori duraklarda görülen hat kodlarını saklar. Siri'nin cümle içinde hat
//  numarasını tanıyabilmesi için bu kodlar App Shortcut parametresi olarak verilir.
//

import Foundation

nonisolated enum SeenLinesStore {
    private static let key = "seenLinesByStop.v1"
    private static let maxLinesPerStop = 40

    /// Durakta görülen hat kodlarını ekler. Liste değiştiyse `true` döner.
    @discardableResult
    static func record(stopNo: String, arrivals: [BusArrival], defaults: UserDefaults = .standard) -> Bool {
        let codes = arrivals.map(\.lineCode).filter { !$0.isEmpty }
        guard !codes.isEmpty else { return false }

        var all = load(defaults)
        let existing = all[stopNo] ?? []
        var merged = existing
        for code in codes where !merged.contains(code) {
            merged.append(code)
        }
        merged = Array(merged.suffix(maxLinesPerStop))
        guard merged != existing else { return false }

        all[stopNo] = merged
        defaults.set(try? JSONEncoder().encode(all), forKey: key)
        return true
    }

    static func lines(for stopNos: [String], defaults: UserDefaults = .standard) -> [String] {
        let all = load(defaults)
        var result: [String] = []
        for stopNo in stopNos {
            for code in all[stopNo] ?? [] where !result.contains(code) {
                result.append(code)
            }
        }
        return result
    }

    private static func load(_ defaults: UserDefaults) -> [String: [String]] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            return [:]
        }
        return decoded
    }
}
