//
//  LineSchedule.swift
//  egowatch (Shared)
//
//  `/HareketSaatleri` yanıtını temsil eder.
//
//  Gerçek HTML (docs/api-samples/hareketsaatleri_101.html):
//    <table class="hs-kv"> ... Hat No / Hat Adı / Kalkış Yeri / Mesafesi / Süresi ... </table>
//    <table class="hs-table"> <thead> Hafta içi | Cumartesi | Pazar </thead>
//        <tbody><tr><td class="hs-times">08:00 -<br/>09:00 -<br/>...</td> ...</tr></tbody>
//    </table>
//    <table class="route-table"> Sıra | Durak No | Durak Adı | Durak Adres ... </table>
//

import Foundation

nonisolated struct LineSchedule: Codable, Sendable, Hashable {
    /// "101" — Hat No.
    let lineNo: String
    /// "GÖLBAŞI-HAYMANA YOLU-BAHÇELİEVLER" — Hat Adı.
    let lineName: String
    /// "BAHÇELİEVLER MH.35.CD.GÖLBAŞI/ANKARA" — Kalkış Yeri.
    let departurePlace: String?
    /// "43 km" — Mesafesi (ham).
    let distanceText: String?
    /// "73 dakika" — Süresi (ham).
    let durationText: String?

    /// Sefer saatleri (gün tipine göre).
    let schedule: WeeklySchedule
    /// Güzergahtaki duraklar (sırasıyla).
    let stops: [Stop]

    nonisolated struct WeeklySchedule: Codable, Sendable, Hashable {
        /// "Hafta içi" kolonu — "08:00", "09:00", ...
        let weekday: [String]
        /// "Cumartesi" kolonu.
        let saturday: [String]
        /// "Pazar" kolonu.
        let sunday: [String]

        /// Verilen güne ait saat listesi.
        func times(for day: ServiceDay) -> [String] {
            switch day {
            case .weekday:  return weekday
            case .saturday: return saturday
            case .sunday:   return sunday
            }
        }
    }

    nonisolated struct Stop: Codable, Sendable, Identifiable, Hashable {
        /// Sıra numarası, örn. 1.
        let order: Int
        /// Durak No, örn. "14043".
        let code: String
        /// Durak Adı, örn. "GÖLBAŞI HAREKET NOKTASI".
        let name: String
        /// Durak Adres / mahalle, örn. "Bahçelievler Mh.35.Cd.Gölbaşı".
        let address: String?

        var id: Int { order }
    }
}

nonisolated enum ServiceDay: String, Codable, Sendable, CaseIterable, Identifiable, Hashable {
    case weekday
    case saturday
    case sunday

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .weekday:  return "Hafta içi"
        case .saturday: return "Cumartesi"
        case .sunday:   return "Pazar"
        }
    }

    /// Bugünün takvim gününe karşılık gelen ServiceDay.
    static func current(_ date: Date = Date(), calendar: Calendar = .current) -> ServiceDay {
        switch calendar.component(.weekday, from: date) {
        case 1:        return .sunday      // Pazar
        case 7:        return .saturday    // Cumartesi
        default:       return .weekday
        }
    }
}
