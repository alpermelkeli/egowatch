//
//  StopNameMatcher.swift
//  egowatch
//
//  Siri'nin duyduğu durak adını favori duraklarla bulanık eşleştirir.
//  "kızılay durağı", "kizilay", "kızlay" → "Kızılay".
//

import Foundation

nonisolated enum StopNameMatcher {

    /// Bu skorun altındaki adaylar eşleşme sayılmaz (0...1).
    static let threshold = 0.6
    /// En iyi skora bu kadar yakın adaylar da döner (Siri "Hangisi?" diye sorar); açık kazanan varsa tek sonuç.
    static let tieMargin = 0.06

    /// Cümlede anlam taşımayan, durak adlarında sık geçen kelimeler.
    private static let fillerWords: Set<String> = [
        "durak", "duragi", "duraginda", "duragina", "duragindan", "durakta",
        "istasyon", "istasyonu", "istasyonunda", "ist", "metro", "otobus", "otobuse", "otobusu",
        "numarali", "hat", "hatti", "tire", "kac", "dakika", "var", "ne", "zaman", "gelir", "ile"
    ]

    /// `candidates` içinden `query`'ye benzeyenleri skor sırasıyla döndürür.
    static func match<T>(_ query: String, in candidates: [T], stopNo: (T) -> String, title: (T) -> String) -> [T] {
        let digits = query.filter(\.isNumber)
        if digits.count == 5, let exact = candidates.first(where: { stopNo($0) == digits }) {
            return [exact]
        }

        let queryTokens = tokens(query)
        guard !queryTokens.isEmpty else { return [] }

        let scored = candidates
            .map { ($0, score(queryTokens, tokens(title($0)))) }
            .filter { $0.1 >= threshold }
            .sorted { $0.1 > $1.1 }
        guard let best = scored.first?.1 else { return [] }
        return scored.filter { $0.1 >= best - tieMargin }.map(\.0)
    }

    /// Türkçe karakterleri katlar, küçük harfe çevirir, noktalamayı ve dolgu kelimeleri atar.
    static func tokens(_ text: String) -> [String] {
        normalize(text)
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { !fillerWords.contains($0) }
    }

    static func normalize(_ text: String) -> String {
        let lowered = text.lowercased(with: Locale(identifier: "tr_TR"))
        let folded = lowered.map { char -> Character in
            switch char {
            case "ı", "i̇": return "i"
            case "ş": return "s"
            case "ğ": return "g"
            case "ç": return "c"
            case "ö": return "o"
            case "ü": return "u"
            case "â": return "a"
            case "î": return "i"
            case "û": return "u"
            default: return char
            }
        }
        return String(folded).folding(options: .diacriticInsensitive, locale: nil)
    }

    /// Sorgu kelimelerinin adayda karşılığı (ağırlık 0.6) ve adayın kelimelerinin sorguda
    /// karşılığı (0.4). İkincisi, "onur sitesi" sorgusunda "Onur Sitesi"ni
    /// "Koru Metro-Onur Sitesi"nden öne geçirir. Ek olarak kelimeler birleştirilmiş
    /// hâliyle de karşılaştırılır ("kizil ay" ↔ "kizilay").
    private static func score(_ query: [String], _ candidate: [String]) -> Double {
        guard !candidate.isEmpty else { return 0 }

        func coverage(_ from: [String], _ to: [String]) -> Double {
            let perToken = from.map { f in to.map { tokenSimilarity(f, $0) }.max() ?? 0 }
            return perToken.reduce(0, +) / Double(perToken.count)
        }
        let tokenScore = 0.6 * coverage(query, candidate) + 0.4 * coverage(candidate, query)
        let joinedScore = similarity(query.joined(), candidate.joined())
        return max(tokenScore, joinedScore)
    }

    private static func tokenSimilarity(_ a: String, _ b: String) -> Double {
        if a == b { return 1 }
        // "kizilay" ↔ "kizilayda" gibi ek almış biçimler.
        if a.count >= 3, b.count >= 3, a.hasPrefix(b) || b.hasPrefix(a) { return 0.9 }
        return similarity(a, b)
    }

    /// 1 - normalize Levenshtein uzaklığı.
    static func similarity(_ a: String, _ b: String) -> Double {
        let longest = max(a.count, b.count)
        guard longest > 0 else { return 1 }
        return 1 - Double(levenshtein(Array(a), Array(b))) / Double(longest)
    }

    private static func levenshtein(_ a: [Character], _ b: [Character]) -> Int {
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var previous = Array(0...b.count)
        var current = [Int](repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            current[0] = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
            }
            swap(&previous, &current)
        }
        return previous[b.count]
    }
}
