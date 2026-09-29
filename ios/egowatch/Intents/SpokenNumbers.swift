//
//  SpokenNumbers.swift
//  egowatch
//
//  Siri Türkçede sayıları yazıyla aktarabiliyor ("beş yüz doksan", "iki yüz doksan yedi tire yedi").
//  Bu yardımcı yazıyla söylenen sayıları rakama çevirir: "beş yüz doksan" → "590".
//

import Foundation

nonisolated enum SpokenNumbers {

    private static let values: [String: Int] = [
        "sifir": 0, "bir": 1, "iki": 2, "uc": 3, "dort": 4, "bes": 5,
        "alti": 6, "yedi": 7, "sekiz": 8, "dokuz": 9,
        "on": 10, "yirmi": 20, "otuz": 30, "kirk": 40, "elli": 50,
        "altmis": 60, "yetmis": 70, "seksen": 80, "doksan": 90
    ]

    /// Metindeki yazıyla sayı dizilerini rakama çevirir; diğer kelimeler olduğu gibi kalır.
    /// Dönen metin `StopNameMatcher.normalize` ile katlanmış (küçük harf, Türkçe karaktersiz) hâldedir.
    static func replacingNumberWords(in text: String) -> String {
        let words = StopNameMatcher.normalize(text).split(separator: " ").map(String.init)
        var output: [String] = []
        var total = 0
        var current = 0
        var inNumber = false

        func flush() {
            if inNumber { output.append(String(total + current)) }
            total = 0; current = 0; inNumber = false
        }

        for word in words {
            if let value = values[word] {
                current += value
                inNumber = true
            } else if word == "yuz" {
                current = (current == 0 ? 1 : current) * 100
                inNumber = true
            } else if word == "bin" {
                total += (current == 0 ? 1 : current) * 1000
                current = 0
                inNumber = true
            } else {
                flush()
                output.append(word)
            }
        }
        flush()
        return output.joined(separator: " ")
    }
}
