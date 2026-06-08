//
//  BusArrival.swift
//  egowatch (Shared)
//
//  `/otobusnerede` yanıtındaki tek bir `.bus-card` bloğunu temsil eder.
//
//  Gerçek HTML (docs/api-samples/otobusnerede_10135.html):
//    <div class="bus-card">
//      <div class="route-badge">590</div>
//      <div class="route-main">
//        <div class="route-title">KORU METRO İST.-YAŞAMKENT</div>
//        <div class="route-meta">06 BD 0863, [07-501], Hız:0 km, Solo, Engelli, Bisiklet Aparatı</div>
//      </div>
//      <div class="eta">
//        <div class="eta-mins">14 dk</div>
//        <div class="eta-queue">59/44</div>
//      </div>
//    </div>
//
//  Canlı olmayan varyantta route-meta "Sonraki Hareket Saati İlk Duraktan 16:11 / 2 dk Sonra"
//  şeklindedir ve eta alanları boştur.
//

import Foundation

nonisolated struct BusArrival: Codable, Sendable, Identifiable, Hashable {
    var id = UUID()

    /// route-badge — hat numarası, örn. "590".
    let lineCode: String
    /// route-title — hattın gittiği yön / başlık, örn. "KORU METRO İST.-YAŞAMKENT".
    let routeTitle: String
    /// Otobüsün canlı konumda mı yoksa henüz kalkmamış (planlı) mı olduğu.
    let kind: Kind

    nonisolated enum Kind: Codable, Sendable, Hashable {
        /// Yolda olan, canlı konumu bilinen otobüs.
        case live(LiveInfo)
        /// Henüz ilk duraktan kalkmamış; bir sonraki sefer saati bilgisi.
        case scheduled(text: String, departureTime: String?, inMinutes: Int?)
    }

    nonisolated struct LiveInfo: Codable, Sendable, Hashable {
        /// "14 dk" — ham metin (gösterim için).
        let etaText: String
        /// 14 — etaText içinden ayıklanan dakika (yoksa nil).
        let etaMinutes: Int?
        /// "59/44" — otobüsün bulunduğu durak sırası bilgisi (ham).
        let queueText: String?
        /// "06 BD 0863" — araç plakası.
        let plate: String?
        /// "07-501" — araç hat referansı ([07-501] içinden).
        let lineRef: String?
        /// 0 — anlık hız (km/s).
        let speedKmh: Int?
        /// ["Solo", "Engelli", "Bisiklet Aparatı"] — araç özellikleri.
        let features: [String]
        /// Ham route-meta metni.
        let rawMeta: String

        /// Engelli erişimine uygun araç.
        var isAccessible: Bool {
            features.contains { $0.localizedCaseInsensitiveContains("Engelli") }
        }
        /// Bisiklet aparatı var mı.
        var hasBikeRack: Bool {
            features.contains { $0.localizedCaseInsensitiveContains("Bisiklet") }
        }
        /// Körüklü (articulated) araç.
        var isArticulated: Bool {
            features.contains { $0.localizedCaseInsensitiveContains("Körüklü") }
        }
    }
}

nonisolated extension BusArrival {
    /// Canlı bilgi varsa döner (yoksa nil).
    var liveInfo: LiveInfo? {
        if case let .live(info) = kind { return info }
        return nil
    }

    /// Sıralama için kullanılacak dakika (planlı seferler için sona atılır).
    var sortMinutes: Int {
        switch kind {
        case let .live(info):
            return info.etaMinutes ?? Int.max - 1
        case let .scheduled(_, _, inMinutes):
            return inMinutes ?? Int.max
        }
    }
}
