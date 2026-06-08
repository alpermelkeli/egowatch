//
//  WatchSessionManager.swift
//  egowatch (watchOS)
//
//  Apple Watch tarafı: istekleri WatchConnectivity ile iPhone'a iletir, yanıtı bekler.
//  Tüm ağ trafiği telefon üzerinden gittiği için watch doğrudan EGO'ya istek atmaz.
//

#if os(watchOS)
import Foundation
import Combine
import WatchConnectivity

@MainActor
final class WatchSessionManager: NSObject, ObservableObject {

    static let shared = WatchSessionManager()

    /// iPhone uygulamasının şu an erişilebilir olup olmadığı (UI uyarısı için).
    @Published private(set) var isReachable = false

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - Tipli API

    func busArrivals(stopNo: String) async throws -> [BusArrival] {
        guard case let .busArrivals(arrivals) = try await send(.busArrivals(stopNo: stopNo)) else {
            throw EGOAPIError.parsingFailed
        }
        return arrivals
    }

    func lineList(type: TransitType) async throws -> [BusLine] {
        guard case let .lineList(lines) = try await send(.lineList(type: type)) else {
            throw EGOAPIError.parsingFailed
        }
        return lines
    }

    func lineSchedule(lineNo: String, type: TransitType) async throws -> LineSchedule {
        guard case let .lineSchedule(schedule) = try await send(.lineSchedule(lineNo: lineNo, type: type)) else {
            throw EGOAPIError.parsingFailed
        }
        return schedule
    }

    // MARK: - Aktarım

    private func send(_ request: EGORequest) async throws -> EGOResponse {
        let session = WCSession.default
        guard session.activationState == .activated else {
            throw EGOAPIError.connectivity("Oturum etkin değil.")
        }
        guard session.isReachable else {
            throw EGOAPIError.connectivity("iPhone şu an erişilemez.")
        }

        let payload = try EGOCoder.encode(request)
        let reply: Data = try await withCheckedThrowingContinuation { continuation in
            session.sendMessageData(
                payload,
                replyHandler: { continuation.resume(returning: $0) },
                errorHandler: { continuation.resume(throwing: EGOAPIError.connectivity($0.localizedDescription)) }
            )
        }

        let response = try EGOCoder.decode(EGOResponse.self, from: reply)
        if case let .failure(message) = response {
            throw EGOAPIError.network(message)
        }
        return response
    }
}

extension WatchSessionManager: WCSessionDelegate {

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        let reachable = session.isReachable
        Task { @MainActor in self.isReachable = reachable }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in self.isReachable = reachable }
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
}
#endif
