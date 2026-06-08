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
        let html = try await fetchHTML(.busArrivals(stopNo: trimmed))
        return EGOHTMLParser.parseBusArrivals(html)
    }

    // MARK: - Hat Listesi

    func lineList(type: TransitType) async throws -> [BusLine] {
        let html = try await fetchHTML(.lineList(type: type))
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
        let request = endpoint.makeRequest()
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw EGOAPIError.network(error.localizedDescription)
        } catch {
            throw EGOAPIError.network(error.localizedDescription)
        }

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw EGOAPIError.server(statusCode: http.statusCode)
        }

        // EGO sayfaları UTF-8'dir; bozuk baytlara karşı lossy decode.
        guard let html = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1) else {
            throw EGOAPIError.parsingFailed
        }
        return html
    }
}
