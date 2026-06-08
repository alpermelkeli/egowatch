//
//  BusLine.swift
//  egowatch (Shared)
//
//  `/AjaxData/HatListesi*` yanıtındaki tek bir <option> öğesini temsil eder.
//
//  Gerçek HTML (docs/api-samples/hatlistesi_otobus.html):
//    <option value="0" selected>OTOBÜS</option>          // başlık — atlanır
//    <option value="101"> (101 ) - GÖLBAŞI-HAYMANA YOLU-BAHÇELİEVLER</option>
//

import Foundation

nonisolated struct BusLine: Codable, Sendable, Identifiable, Hashable {
    /// <option value> — HareketSaatleri isteğinde kullanılacak hat numarası, örn. "101", "101-1".
    let code: String
    /// Hattın güzergah adı, örn. "GÖLBAŞI-HAYMANA YOLU-BAHÇELİEVLER".
    let name: String
    /// Hattın türü (hangi listeden geldiği).
    let type: TransitType

    var id: String { "\(type.rawValue):\(code)" }

    /// Arama/gösterim için birleşik metin, örn. "101 · GÖLBAŞI-...".
    var displayLabel: String {
        name.isEmpty ? code : "\(code) · \(name)"
    }
}
