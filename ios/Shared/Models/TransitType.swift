//
//  TransitType.swift
//  egowatch (Shared)
//
//  Ulaşım türü. Hat listesi <select>'ini ve HareketSaatleri istek alanını belirler.
//

import Foundation

nonisolated enum TransitType: String, Codable, Sendable, CaseIterable, Identifiable, Hashable {
    case otobus
    case metro
    case ankaray

    var id: String { rawValue }

    /// Kullanıcıya gösterilecek ad.
    var displayName: String {
        switch self {
        case .otobus:  return "Otobüs"
        case .metro:   return "Metro"
        case .ankaray: return "Ankaray"
        }
    }

    /// `/HareketSaatleri` sayfasında hat listesini taşıyan `<select>` id'si.
    var lineListSelectID: String {
        switch self {
        case .otobus:  return "hat_liste_otobus"
        case .metro:   return "hat_liste_metro"
        case .ankaray: return "hat_liste_ankaray"
        }
    }

    /// `/HareketSaatleri` isteğinde hat numarasının yazılacağı alan adı.
    var hareketSaatleriField: String {
        switch self {
        case .otobus:  return "hat_no1"
        case .metro:   return "hat_no2"
        case .ankaray: return "hat_no3"
        }
    }
}
