//
//  TransitType.swift
//  egowatch (Shared)
//
//  Ulaşım türü. Hat listesi endpoint'ini ve HareketSaatleri istek alanını belirler.
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

    /// `/AjaxData/HatListesi*` endpoint yolu.
    var hatListesiPath: String {
        switch self {
        case .otobus:  return "/AjaxData/HatListesiOtobus"
        case .metro:   return "/AjaxData/HatListesiMetro"
        case .ankaray: return "/AjaxData/HatListesiAnkaray"
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
