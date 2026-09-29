//
//  BusETAIntent.swift
//  egowatch
//
//  "Hey Siri, EgoWatch Kızılay durağında 590 kaç dakika?"
//  Canlı sorgu atar; cevabı sesli söyler ve Siri kartında gösterir. Uygulama açılmaz.
//

import AppIntents
import OSLog
import SwiftUI

/// Tek parametreli cümle için: "EgoWatch Kızılay durağında 590 kaç dakika".
struct StopLineETAIntent: AppIntent {
    static let title: LocalizedStringResource = "Duraktaki Hat Kaç Dakika"
    static let description = IntentDescription("Favori durağındaki bir hattın kaç dakika uzakta olduğunu canlı sorgular.")
    static let openAppWhenRun = false

    @Parameter(title: "Durak ve Hat", requestValueDialog: "Hangi durak ve hat?")
    var target: StopLineEntity

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$target) kaç dakika")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let result = await BusETAResult.fetch(stopTitle: target.stopTitle, stopNo: target.stopNo, lineCode: target.lineCode)
        return .result(dialog: IntentDialog(stringLiteral: result.spokenText), view: BusETASnippetView(result: result))
    }
}

/// "EgoWatch otobüs kaç dakika" → Siri durağı ve hattı sorar. Cevaplar ham metin olarak gelir
/// ve burada eşleştirilir (Siri'nin kendi entity eşleştirmesi Türkçe durak adlarında başarısız oluyordu):
/// durak adı favorilerle bulanık, hat numarası rakam ya da yazıyla ("beş yüz doksan").
struct BusETAIntent: AppIntent {
    static let title: LocalizedStringResource = "Otobüs Kaç Dakika"
    static let description = IntentDescription("Favori durağına gelen bir hattın kaç dakika uzakta olduğunu canlı sorgular.")
    static let openAppWhenRun = false

    @Parameter(title: "Durak", requestValueDialog: "Hangi durak?")
    var stopName: String

    @Parameter(title: "Hat")
    var lineName: String?

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$stopName) durağında \(\.$lineName) kaç dakika")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let stops = FavoritesStore.shared.stops
        guard !stops.isEmpty else {
            throw BusETAIntentError.noFavorites
        }

        // Durak cevabında hat da söylenmiş olabilir: "Onur Sitesi 590".
        let stopText = SpokenNumbers.replacingNumberWords(in: stopName)
        let lineInStopAnswer = StopLineQuery.lineCode(in: stopText)
        let nameOnly = lineInStopAnswer == nil ? stopText : String(stopText.filter { !$0.isNumber })

        let matches = StopNameMatcher.match(nameOnly, in: stops, stopNo: \.stopNo, title: \.title)
        SiriLog.logger.info("Durak cevabı '\(stopName, privacy: .public)' → \(matches.map(\.title), privacy: .public)")
        let stop: FavoriteStop
        switch matches.count {
        case 0:
            let names = stops.map(\.title).joined(separator: ", ")
            throw $stopName.needsValueError("\(stopName) favorilerinde yok. Favorilerin: \(names). Hangi durak?")
        case 1:
            stop = matches[0]
        default:
            let chosen = try await $stopName.requestDisambiguation(among: matches.map(\.title), dialog: "Hangisi?")
            stop = matches.first { $0.title == chosen } ?? matches[0]
        }

        var lineCode = lineInStopAnswer ?? lineName.flatMap(Self.lineCode(from:))
        if lineCode == nil {
            let answer = try await $lineName.requestValue("Hangi hat?")
            lineCode = Self.lineCode(from: answer)
            SiriLog.logger.info("Hat cevabı '\(answer, privacy: .public)' → \(lineCode ?? "-", privacy: .public)")
        }
        guard let lineCode else {
            throw $lineName.needsValueError("Hat numarasını anlayamadım. Hangi hat?")
        }

        let result = await BusETAResult.fetch(stopTitle: stop.title, stopNo: stop.stopNo, lineCode: lineCode)
        return .result(dialog: IntentDialog(stringLiteral: result.spokenText), view: BusETASnippetView(result: result))
    }

    /// "590", "beş yüz doksan", "297 tire 7" → hat kodu.
    static func lineCode(from spoken: String) -> String? {
        StopLineQuery.lineCode(in: SpokenNumbers.replacingNumberWords(in: spoken))
    }
}

nonisolated enum BusETAIntentError: Error, CustomLocalizedStringResourceConvertible {
    case noFavorites

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noFavorites: "Henüz favori durağın yok. Önce uygulamada bir durağı favorilere ekle."
        }
    }
}

/// Siri akışının logları: Console.app → cihaz → "subsystem:com.alpermelkeli.egowatch category:Siri".
nonisolated enum SiriLog {
    static let logger = Logger(subsystem: "com.alpermelkeli.egowatch", category: "Siri")
}

/// Sorgu sonucunu seçilen hatta indirger; diyalog ve kart aynı veriyi kullanır.
nonisolated struct BusETAResult: Sendable {
    let stopTitle: String
    let stopNo: String
    let lineCode: String
    /// Seçilen hatta ait canlı otobüsler (yakından uzağa).
    let live: [(arrival: BusArrival, info: BusArrival.LiveInfo)]
    /// Henüz yola çıkmamış seferler.
    let scheduled: [BusArrival]
    let date: Date
    let errorMessage: String?

    init(stopTitle: String, stopNo: String, lineCode: String, arrivals: [BusArrival], date: Date) {
        self.stopTitle = stopTitle
        self.stopNo = stopNo
        self.lineCode = lineCode
        self.date = date
        errorMessage = nil

        let matching = Self.filter(arrivals, lineCode: lineCode).sorted { $0.sortMinutes < $1.sortMinutes }
        live = matching.compactMap { arrival in arrival.liveInfo.map { (arrival, $0) } }
        scheduled = matching.filter { $0.liveInfo == nil }
    }

    init(stopTitle: String, stopNo: String, lineCode: String, errorMessage: String) {
        self.stopTitle = stopTitle
        self.stopNo = stopNo
        self.lineCode = lineCode
        live = []
        scheduled = []
        date = Date()
        self.errorMessage = errorMessage
    }

    /// Canlı sorguyu atar; görülen hatları kaydedip Siri parametrelerini tazeler.
    @MainActor
    static func fetch(stopTitle: String, stopNo: String, lineCode: String) async -> BusETAResult {
        SiriLog.logger.info("Sorgu: durak \(stopNo, privacy: .public) (\(stopTitle, privacy: .public)), hat \(lineCode, privacy: .public)")
        do {
            let arrivals = try await DirectEGOService().busArrivals(stopNo: stopNo)
            if SeenLinesStore.record(stopNo: stopNo, arrivals: arrivals) {
                EgoShortcuts.refresh()
            }
            let result = BusETAResult(stopTitle: stopTitle, stopNo: stopNo, lineCode: lineCode, arrivals: arrivals, date: Date())
            SiriLog.logger.info("Sonuç: \(arrivals.count) otobüs, hat için \(result.live.count) canlı → \(result.spokenText, privacy: .public)")
            return result
        } catch {
            SiriLog.logger.error("Sorgu hatası: \(error.localizedDescription, privacy: .public)")
            return BusETAResult(stopTitle: stopTitle, stopNo: stopNo, lineCode: lineCode, errorMessage: error.localizedDescription)
        }
    }

    /// Önce birebir hat kodu; yoksa "297" için "297-7" gibi varyantlar.
    static func filter(_ arrivals: [BusArrival], lineCode: String) -> [BusArrival] {
        let code = lineCode.uppercased()
        let exact = arrivals.filter { $0.lineCode.uppercased() == code }
        if !exact.isEmpty { return exact }
        return arrivals.filter { $0.lineCode.uppercased().hasPrefix(code + "-") }
    }

    var spokenText: String {
        if let errorMessage {
            return "\(stopTitle) durağı sorgulanamadı. \(errorMessage)"
        }
        if let first = live.first {
            var text: String
            if let minutes = first.info.etaMinutes, minutes > 0 {
                text = "\(stopTitle) durağına \(lineCode) numaralı otobüs \(minutes) dakika sonra geliyor."
            } else {
                text = "\(lineCode) numaralı otobüs şu an \(stopTitle) durağına geliyor."
            }
            if let next = live.dropFirst().first?.info.etaMinutes {
                text += " Bir sonraki \(next) dakika sonra."
            }
            return text
        }
        if let departure = scheduled.first, case let .scheduled(_, time, _) = departure.kind, let time {
            return "\(lineCode) numaralı otobüs henüz yola çıkmadı. İlk duraktan hareket saati \(time)."
        }
        return "Şu anda \(stopTitle) durağına yaklaşan \(lineCode) numaralı otobüs görünmüyor."
    }
}
