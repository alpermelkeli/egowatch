//
//  StopLineEntity.swift
//  egowatch
//
//  Siri cümlesinde tek parametre kullanılabildiği için (App Shortcuts kuralı)
//  "Kızılay durağında 590" gibi durak + hat çifti tek bir entity olarak temsil edilir.
//  Değerler: her favori durak × o durakta görülen hatlar (SeenLinesStore).
//

import AppIntents
import OSLog

nonisolated struct StopLineEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Durak ve Hat"
    static let defaultQuery = StopLineQuery()

    /// "11532|590"
    let id: String
    let stopNo: String
    let stopTitle: String
    let lineCode: String

    init(stop: FavoriteStop, lineCode: String) {
        id = "\(stop.stopNo)|\(lineCode)"
        stopNo = stop.stopNo
        stopTitle = stop.title
        self.lineCode = lineCode
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(stopTitle) \(lineCode)",
            subtitle: "Durak \(stopNo)",
            synonyms: synonyms
        )
    }

    /// Siri'nin cümle içinde tanıyacağı söylenişler.
    private var synonyms: [LocalizedStringResource] {
        var lines = [lineCode]
        if lineCode.contains("-") {
            lines.append(lineCode.replacingOccurrences(of: "-", with: " "))
            lines.append(lineCode.replacingOccurrences(of: "-", with: " tire "))
        }
        var stops = [stopTitle]
        let folded = StopNameMatcher.tokens(stopTitle).joined(separator: " ")
        if !folded.isEmpty, folded != stopTitle.lowercased() { stops.append(folded) }

        var result: [LocalizedStringResource] = []
        for stop in stops {
            for line in lines {
                result.append("\(stop) durağında \(line)")
                result.append("\(stop) durağında \(line) numaralı otobüs")
                result.append("\(stop) durağında \(line) numaralı otobüse")
                result.append("\(stop) durağına \(line)")
                result.append("\(stop) \(line)")
            }
        }
        return result
    }
}

nonisolated struct StopLineQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [String]) async throws -> [StopLineEntity] {
        let stops = FavoritesStore.shared.stops
        return identifiers.compactMap { id in
            let parts = id.split(separator: "|", maxSplits: 1).map(String.init)
            guard parts.count == 2, let stop = stops.first(where: { $0.stopNo == parts[0] }) else { return nil }
            return StopLineEntity(stop: stop, lineCode: parts[1])
        }
    }

    /// Serbest metin: "kızlay durağında 590" → durak bulanık, hat numarası metinden.
    @MainActor
    func entities(matching string: String) async throws -> [StopLineEntity] {
        let stops = FavoritesStore.shared.stops
        // "beş yüz doksan" → "590"
        let text = SpokenNumbers.replacingNumberWords(in: string)
        guard let lineCode = Self.lineCode(in: text) else {
            SiriLog.logger.info("StopLine matching '\(string, privacy: .public)' → hat numarası bulunamadı ('\(text, privacy: .public)')")
            return []
        }
        let stopText = text.replacingOccurrences(of: lineCode.lowercased().replacingOccurrences(of: "-", with: " "), with: " ")
            .replacingOccurrences(of: lineCode.lowercased(), with: " ")
        let result = StopNameMatcher
            .match(stopText, in: stops, stopNo: \.stopNo, title: \.title)
            .map { StopLineEntity(stop: $0, lineCode: lineCode) }
        SiriLog.logger.info("StopLine matching '\(string, privacy: .public)' → hat \(lineCode, privacy: .public), durak metni '\(stopText, privacy: .public)', \(result.count) sonuç; favoriler: \(stops.map(\.title), privacy: .public)")
        return result
    }

    @MainActor
    func suggestedEntities() async throws -> [StopLineEntity] {
        let all = Self.allCombinations()
        SiriLog.logger.info("StopLine suggested: \(all.map(\.id), privacy: .public)")
        return all
    }

    @MainActor
    static func allCombinations() -> [StopLineEntity] {
        FavoritesStore.shared.stops.flatMap { stop in
            lines(atStop: stop.stopNo).map { StopLineEntity(stop: stop, lineCode: $0) }
        }
    }

    /// Durakta görülen hatlar. Durak hiç sorgulanmadıysa yedek olarak favori otobüs hatları.
    @MainActor
    static func lines(atStop stopNo: String) -> [String] {
        let seen = SeenLinesStore.lines(for: [stopNo])
        if !seen.isEmpty { return seen }
        return FavoritesStore.shared.lines.filter { $0.type == .otobus }.map(\.lineCode)
    }

    /// Metindeki son sayısal grup hat kodu kabul edilir ("... 297 tire 7 ..." → "297-7").
    /// 5 haneli sayılar durak numarasıdır, atlanır.
    static func lineCode(in text: String) -> String? {
        let pattern = #"(?<!\d)(\d{1,4}[A-Za-z]?)(?:\s*(?:-|tire|\s)\s*(\d{1,2}))?(?!\d)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.matches(in: text, range: range).last,
              let main = Range(match.range(at: 1), in: text) else { return nil }
        var code = String(text[main]).uppercased()
        if let suffix = Range(match.range(at: 2), in: text) {
            code += "-" + text[suffix]
        }
        return code
    }
}
