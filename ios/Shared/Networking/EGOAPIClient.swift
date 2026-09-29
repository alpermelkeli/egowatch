//
//  EGOAPIClient.swift
//  egowatch (Shared)
//
//  EGO endpoint'lerine async/await ile POST atan, HTML yanıtı parse eden istemci.
//  `nonisolated`: WatchConnectivity delegesi gibi arka plan bağlamlarından da çağrılabilir.
//
//  Mimari notu: Bu istemci asıl olarak iPhone tarafında çalışır; Apple Watch istekleri
//  WatchConnectivity üzerinden telefona iletir (bkz. Connectivity katmanı).
//

import Foundation

nonisolated struct EGOAPIClient: Sendable {

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Otobüs Nerede

    func busArrivals(stopNo: String) async throws -> [BusArrival] {
        let trimmed = stopNo.trimmingCharacters(in: .whitespaces)
        guard trimmed.count == 5, trimmed.allSatisfy(\.isNumber) else {
            throw EGOAPIError.invalidStopNumber
        }
        do {
            return try await fetchBusArrivals(stopNo: trimmed)
        } catch EGOAPIError.network {
            // Boşta kalmış (kopmuş) bir bağlantının yeniden kullanılması POST'u düşürebiliyor;
            // token tek kullanımlık olduğu için akış baştan bir kez daha denenir.
            return try await fetchBusArrivals(stopNo: trimmed)
        }
    }

    private func fetchBusArrivals(stopNo: String) async throws -> [BusArrival] {
        // 1) Form sayfası: her yüklemede değişen gönderim yolu ve alan adı + oturum çerezleri.
        let formHTML = try await fetchHTML(.busArrivalsForm)
        guard let form = EGOHTMLParser.parseBusForm(formHTML) else {
            throw EGOAPIError.parsingFailed
        }
        // 2) Dinamik güvenlik token'ı.
        let token = try await fetchDynamicToken()
        // 3) Sorgu.
        let html = try await fetchHTML(.busArrivals(stopNo: stopNo, form: form, token: token))
        return EGOHTMLParser.parseBusArrivals(html)
    }

    private struct DynamicTokenResponse: Decodable {
        let success: Bool
        let token: String?
    }

    private func fetchDynamicToken() async throws -> String {
        let data = try await fetchData(.dynamicToken)
        guard let response = try? JSONDecoder().decode(DynamicTokenResponse.self, from: data),
              response.success, let token = response.token, !token.isEmpty else {
            throw EGOAPIError.parsingFailed
        }
        return token
    }

    // MARK: - Hat Listesi

    func lineList(type: TransitType) async throws -> [BusLine] {
        let html = try await fetchHTML(.lineList)
        let lines = EGOHTMLParser.parseLineList(html, type: type)
        guard !lines.isEmpty else { throw EGOAPIError.parsingFailed }
        return lines
    }

    // MARK: - Hareket Saatleri

    func lineSchedule(lineNo: String, type: TransitType) async throws -> LineSchedule {
        let trimmed = lineNo.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { throw EGOAPIError.invalidLineNumber }
        let html = try await fetchHTML(.lineSchedule(lineNo: trimmed, type: type))
        guard let schedule = EGOHTMLParser.parseLineSchedule(html, requestedLineNo: trimmed) else {
            throw EGOAPIError.parsingFailed
        }
        return schedule
    }

    // MARK: - Ortak istek

    private func fetchHTML(_ endpoint: EGOEndpoint) async throws -> String {
        let data = try await fetchData(endpoint)
        // EGO sayfaları UTF-8'dir; bozuk baytlara karşı lossy decode.
        guard let html = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1) else {
            throw EGOAPIError.parsingFailed
        }
        return html
    }

    private func fetchData(_ endpoint: EGOEndpoint) async throws -> Data {
        let request = endpoint.makeRequest()
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw EGOAPIError.network(error.localizedDescription)
        }

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw EGOAPIError.server(statusCode: http.statusCode)
        }
        return data
    }
}
