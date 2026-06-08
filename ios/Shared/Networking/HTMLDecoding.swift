//
//  HTMLDecoding.swift
//  egowatch (Shared)
//
//  EGO yanıtları numerik HTML entity içerir (örn. "G&#214;LBAŞI", "Bah&#231;elievler").
//  NSAttributedString tabanlı çözüm watchOS'ta ağır/güvenilmez olduğundan hafif,
//  bağımlılıksız bir decoder kullanılır.
//

import Foundation

nonisolated extension String {

    /// Sık kullanılan adlandırılmış entity'ler.
    private static let namedHTMLEntities: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'",
        "nbsp": "\u{00A0}", "ccedil": "ç", "Ccedil": "Ç",
        "ouml": "ö", "Ouml": "Ö", "uuml": "ü", "Uuml": "Ü",
        " #39": "'"
    ]

    /// `&#214;`, `&#x1F;`, `&amp;` gibi HTML entity'lerini çözer.
    func decodingHTMLEntities() -> String {
        guard contains("&") else { return self }

        var result = ""
        result.reserveCapacity(count)
        var index = startIndex

        while index < endIndex {
            let char = self[index]
            guard char == "&" else {
                result.append(char)
                index = self.index(after: index)
                continue
            }

            // ';' konumunu makul bir pencere içinde ara.
            guard let semicolon = self[index...].firstIndex(of: ";"),
                  distance(from: index, to: semicolon) <= 10 else {
                result.append(char)
                index = self.index(after: index)
                continue
            }

            let entityBody = self[self.index(after: index)..<semicolon]  // '&' ve ';' arası

            if entityBody.first == "#" {
                // Numerik entity (&#214; veya &#x1F;).
                let numberPart = entityBody.dropFirst()
                let scalarValue: UInt32?
                if let f = numberPart.first, f == "x" || f == "X" {
                    scalarValue = UInt32(numberPart.dropFirst(), radix: 16)
                } else {
                    scalarValue = UInt32(numberPart, radix: 10)
                }
                if let value = scalarValue, let scalar = Unicode.Scalar(value) {
                    result.append(Character(scalar))
                    index = self.index(after: semicolon)
                    continue
                }
            } else if let mapped = String.namedHTMLEntities[String(entityBody)] {
                result.append(mapped)
                index = self.index(after: semicolon)
                continue
            }

            // Tanınmadıysa '&' karakterini olduğu gibi koru.
            result.append(char)
            index = self.index(after: index)
        }

        return result
    }

    /// HTML etiketlerini söker, entity çözer, boşlukları sadeleştirir.
    func strippingHTMLTags() -> String {
        let withoutTags = replacingOccurrences(
            of: "<[^>]+>", with: " ", options: .regularExpression
        )
        return withoutTags
            .decodingHTMLEntities()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
