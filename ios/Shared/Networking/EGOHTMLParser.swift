//
//  EGOHTMLParser.swift
//  egowatch (Shared)
//
//  EGO'nun HTML yanıtlarını Codable modellere çevirir. Yapılar
//  docs/api-samples/ altındaki gerçek yanıtlara göre yazılmıştır.
//

import Foundation

nonisolated enum EGOHTMLParser {

    // MARK: - Otobüs Nerede

    /// `/otobusnerede` sayfasındaki `bus-form`'un durak numarası alanının adını döndürür.
    /// Ad her sayfa yüklemesinde rastgele üretilir (örn. `name="5615486279"`).
    static func parseBusFormFieldName(_ html: String) -> String? {
        guard let formStart = html.range(of: "bus-form") else { return nil }
        let formEnd = html.range(of: "</form>", range: formStart.upperBound..<html.endIndex)?.lowerBound
            ?? html.endIndex
        let form = String(html[formStart.lowerBound..<formEnd])
        return firstMatch(#"<input(?![^>]*type="hidden")[^>]*\bname="([^"]+)""#, in: form)
    }

    /// `/otobusnerede/sorgula` yanıtını ETA'ya göre sıralı BusArrival listesine çevirir.
    static func parseBusArrivals(_ html: String) -> [BusArrival] {
        let badges = allCaptures(#"route-badge[^>]*>([^<]*)"#, in: html)
        let titles = allCaptures(#"route-title[^>]*>([^<]*)"#, in: html)
        let metas  = allCaptures(#"route-meta[^>]*>([^<]*)"#, in: html)
        let etas   = allCaptures(#"eta-mins[^>]*>([^<]*)"#, in: html)
        let queues = allCaptures(#"eta-queue[^>]*>([^<]*)"#, in: html)

        let count = metas.count
        guard count > 0 else { return [] }

        var arrivals: [BusArrival] = []
        arrivals.reserveCapacity(count)

        for i in 0..<count {
            let lineCode   = clean(badges[safe: i] ?? "")
            let routeTitle = clean(titles[safe: i] ?? "")
            let metaText   = clean(metas[i])
            let etaText    = clean(etas[safe: i] ?? "")
            let queueText  = clean(queues[safe: i] ?? "")

            let kind: BusArrival.Kind
            if metaText.localizedCaseInsensitiveContains("Sonraki Hareket Saati") || etaText.isEmpty {
                kind = .scheduled(
                    text: metaText,
                    departureTime: firstMatch(#"(\d{1,2}:\d{2})"#, in: metaText),
                    inMinutes: firstInt(firstMatch(#"(\d+)\s*dk"#, in: metaText) ?? "")
                )
            } else {
                kind = .live(parseLiveInfo(meta: metaText, etaText: etaText, queueText: queueText))
            }

            arrivals.append(BusArrival(lineCode: lineCode, routeTitle: routeTitle, kind: kind))
        }

        return arrivals.sorted { $0.sortMinutes < $1.sortMinutes }
    }

    /// route-meta metnini ayrıştırır. İki biçim görülmüştür:
    ///   - güncel: "06 HO 2297- [37-105]"
    ///   - eski:   "06 BD 0863, [07-501], Hız:0 km, Solo, Engelli, Bisiklet Aparatı"
    private static func parseLiveInfo(meta: String, etaText: String, queueText: String) -> BusArrival.LiveInfo {
        let comps = meta.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var plate: String?
        var lineRef: String?
        var speed: Int?
        var features: [String] = []

        for (index, comp) in comps.enumerated() {
            if let ref = firstMatch(#"\[([^\]]+)\]"#, in: comp) {
                lineRef = ref
                // Güncel biçimde plaka aynı parçada, "[" öncesinde ("06 HO 2297- [37-105]").
                let prefix = comp[..<(comp.firstIndex(of: "[") ?? comp.startIndex)]
                    .trimmingCharacters(in: CharacterSet(charactersIn: " -"))
                if index == 0, !prefix.isEmpty { plate = prefix }
            } else if comp.localizedCaseInsensitiveContains("Hız") {
                speed = firstInt(comp)
            } else if index == 0 {
                plate = comp
            } else {
                features.append(comp)
            }
        }

        return BusArrival.LiveInfo(
            etaText: etaText,
            etaMinutes: etaMinutes(etaText),
            queueText: queueText.isEmpty ? nil : queueText,
            plate: plate,
            lineRef: lineRef,
            speedKmh: speed,
            features: features,
            rawMeta: meta
        )
    }

    /// "13dk 3sn" → 13, "Geliyor"/"Geldi" → 0.
    private static func etaMinutes(_ text: String) -> Int? {
        if let minutes = firstInt(text) { return minutes }
        let lower = text.lowercased(with: Locale(identifier: "tr_TR"))
        return (lower.hasPrefix("geliyor") || lower.hasPrefix("geldi")) ? 0 : nil
    }

    // MARK: - Hat Listesi

    /// `/HareketSaatleri` sayfasındaki ilgili `<select>` (örn. `#hat_liste_otobus`) seçeneklerini
    /// BusLine listesine çevirir. value="0" (başlık) atlanır.
    static func parseLineList(_ html: String, type: TransitType) -> [BusLine] {
        guard let selectStart = html.range(of: #"id="\#(type.lineListSelectID)""#) else { return [] }
        let selectEnd = html.range(of: "</select>", range: selectStart.upperBound..<html.endIndex)?.lowerBound
            ?? html.endIndex
        let html = String(html[selectStart.upperBound..<selectEnd])

        let pattern = #"<option value="([^"]+)"[^>]*>([^<]*)</option>"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(html.startIndex..., in: html)

        var lines: [BusLine] = []
        regex.enumerateMatches(in: html, range: range) { match, _, _ in
            guard let match,
                  let valueRange = Range(match.range(at: 1), in: html),
                  let labelRange = Range(match.range(at: 2), in: html) else { return }

            let code = String(html[valueRange]).trimmingCharacters(in: .whitespaces)
            guard code != "0", !code.isEmpty else { return }   // başlık satırı

            let rawLabel = String(html[labelRange]).decodingHTMLEntities()
                .trimmingCharacters(in: .whitespaces)
            // " (101 ) - GÖLBAŞI-..." → "GÖLBAŞI-..."
            let name = rawLabel
                .replacingOccurrences(of: #"^\([^)]*\)\s*-\s*"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)

            lines.append(BusLine(code: code, name: name, type: type))
        }
        return lines
    }

    // MARK: - Hareket Saatleri

    /// `/HareketSaatleri` yanıtını LineSchedule'a çevirir.
    static func parseLineSchedule(_ html: String, requestedLineNo: String? = nil) -> LineSchedule? {
        // Hat bilgileri tablosu (table.hs-kv) — key/value satırları.
        var info: [String: String] = [:]
        let kvPattern = #"<td class="key">(.*?)</td>\s*<td class="sep">:</td>\s*<td>(.*?)</td>"#
        if let regex = try? NSRegularExpression(pattern: kvPattern, options: [.dotMatchesLineSeparators]) {
            let range = NSRange(html.startIndex..., in: html)
            regex.enumerateMatches(in: html, range: range) { match, _, _ in
                guard let match,
                      let kRange = Range(match.range(at: 1), in: html),
                      let vRange = Range(match.range(at: 2), in: html) else { return }
                let key = String(html[kRange]).strippingHTMLTags()
                let value = String(html[vRange]).strippingHTMLTags()
                if !key.isEmpty { info[key] = value }
            }
        }

        let lineNo = info["Hat No"] ?? requestedLineNo ?? ""
        let lineName = info["Hat Adı"] ?? ""
        // Hat bilgisi bulunamadıysa yanıt geçersiz/boş kabul edilir.
        guard !lineNo.isEmpty || !lineName.isEmpty else { return nil }

        let schedule = parseWeeklySchedule(html)
        let stops = parseStops(html)

        return LineSchedule(
            lineNo: lineNo,
            lineName: lineName,
            departurePlace: info["Kalkış Yeri"].flatMap { $0.isEmpty ? nil : $0 },
            distanceText: info["Mesafesi"].flatMap { $0.isEmpty ? nil : $0 },
            durationText: info["Süresi"].flatMap { $0.isEmpty ? nil : $0 },
            schedule: schedule,
            stops: stops
        )
    }

    /// table.hs-table içindeki üç `hs-times` hücresinden (Hafta içi/Cmt/Pazar) saatleri çıkarır.
    private static func parseWeeklySchedule(_ html: String) -> LineSchedule.WeeklySchedule {
        let cells = allCaptures(
            #"<td class="hs-times">(.*?)</td>"#,
            in: html,
            options: [.dotMatchesLineSeparators]
        )
        func times(_ index: Int) -> [String] {
            guard let cell = cells[safe: index] else { return [] }
            return allCaptures(#"(\d{1,2}:\d{2})"#, in: cell)
        }
        return LineSchedule.WeeklySchedule(
            weekday: times(0),
            saturday: times(1),
            sunday: times(2)
        )
    }

    /// table.route-table (Geçtiği Güzergahlar) tbody satırlarından durakları çıkarır.
    private static func parseStops(_ html: String) -> [LineSchedule.Stop] {
        // route-table'ın tbody bloğunu yalıtmaya çalış.
        let scope: String
        if let tableStart = html.range(of: "route-table"),
           let bodyStart = html.range(of: "<tbody>", range: tableStart.upperBound..<html.endIndex),
           let bodyEnd = html.range(of: "</tbody>", range: bodyStart.upperBound..<html.endIndex) {
            scope = String(html[bodyStart.upperBound..<bodyEnd.lowerBound])
        } else {
            scope = html
        }

        let rows = allCaptures(#"<tr>(.*?)</tr>"#, in: scope, options: [.dotMatchesLineSeparators])
        var stops: [LineSchedule.Stop] = []

        for row in rows {
            let cells = allCaptures(#"<td[^>]*>(.*?)</td>"#, in: row, options: [.dotMatchesLineSeparators])
                .map { $0.strippingHTMLTags() }
            guard cells.count >= 3, let order = firstInt(cells[0]) else { continue }
            let address = cells.count >= 4 ? cells[3] : nil
            stops.append(LineSchedule.Stop(
                order: order,
                code: cells[1],
                name: cells[2],
                address: (address?.isEmpty == true) ? nil : address
            ))
        }
        return stops
    }

    // MARK: - Regex Yardımcıları

    private static func allCaptures(
        _ pattern: String,
        in text: String,
        group: Int = 1,
        options: NSRegularExpression.Options = []
    ) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard match.numberOfRanges > group,
                  let r = Range(match.range(at: group), in: text) else { return nil }
            return String(text[r])
        }
    }

    private static func firstMatch(
        _ pattern: String,
        in text: String,
        group: Int = 1,
        options: NSRegularExpression.Options = []
    ) -> String? {
        allCaptures(pattern, in: text, group: group, options: options).first
    }

    private static func firstInt(_ text: String) -> Int? {
        firstMatch(#"(\d+)"#, in: text).flatMap { Int($0) }
    }

    /// HTML entity çöz, etiket söküntüsü yapmadan boşlukları sadeleştir.
    private static func clean(_ text: String) -> String {
        text.decodingHTMLEntities()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

nonisolated private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
