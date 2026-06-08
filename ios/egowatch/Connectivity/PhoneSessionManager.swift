//
//  PhoneSessionManager.swift
//  egowatch (iOS)
//
//  Apple Watch'tan gelen EGORequest'leri alır, EGOAPIClient ile veriyi çeker
//  ve EGOResponse olarak geri döner. Tüm ağ istekleri telefon üzerinden gider.
//

#if os(iOS)
import Foundation
import WatchConnectivity

final class PhoneSessionManager: NSObject {

    static let shared = PhoneSessionManager()

    private override init() {
        super.init()
    }

    /// Uygulama açılışında çağrılır; WCSession'ı etkinleştirir.
    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Gelen isteği işler: decode → API çağrısı → EGOResponse.
    nonisolated private static func handle(_ data: Data) async -> EGOResponse {
        let client = EGOAPIClient()
        do {
            let request = try EGOCoder.decode(EGORequest.self, from: data)
            switch request {
            case .busArrivals(let stopNo):
                return .busArrivals(try await client.busArrivals(stopNo: stopNo))
            case .lineList(let type):
                return .lineList(try await client.lineList(type: type))
            case .lineSchedule(let lineNo, let type):
                return .lineSchedule(try await client.lineSchedule(lineNo: lineNo, type: type))
            }
        } catch {
            return .failure(message: error.localizedDescription)
        }
    }
}

extension PhoneSessionManager: WCSessionDelegate {

    nonisolated func session(_ session: WCSession,
                             didReceiveMessageData messageData: Data,
                             replyHandler: @escaping (Data) -> Void) {
        Task {
            let response = await Self.handle(messageData)
            let reply = (try? EGOCoder.encode(response)) ?? Data()
            replyHandler(reply)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext["favoritesSnapshot"] as? Data,
              let snapshot = try? JSONDecoder().decode(FavoritesSnapshot.self, from: data) else {
            return
        }
        Task { @MainActor in
            FavoritesStore.shared.apply(snapshot)
        }
    }

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {}

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Yeni watch eşleştirmesi sonrası oturumu yeniden etkinleştir.
        session.activate()
    }
}
#endif
