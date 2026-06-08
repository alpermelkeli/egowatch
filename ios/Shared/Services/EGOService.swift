//
//  EGOService.swift
//  egowatch (Shared)
//

import Foundation

protocol EGOService: Sendable {
    func busArrivals(stopNo: String) async throws -> [BusArrival]
    func lineList(type: TransitType) async throws -> [BusLine]
    func lineSchedule(lineNo: String, type: TransitType) async throws -> LineSchedule
}

struct DirectEGOService: EGOService {
    private let client: EGOAPIClient

    init(client: EGOAPIClient = EGOAPIClient()) {
        self.client = client
    }

    func busArrivals(stopNo: String) async throws -> [BusArrival] {
        try await client.busArrivals(stopNo: stopNo)
    }

    func lineList(type: TransitType) async throws -> [BusLine] {
        try await client.lineList(type: type)
    }

    func lineSchedule(lineNo: String, type: TransitType) async throws -> LineSchedule {
        try await client.lineSchedule(lineNo: lineNo, type: type)
    }
}

#if os(watchOS)
struct WatchConnectivityEGOService: EGOService {
    func busArrivals(stopNo: String) async throws -> [BusArrival] {
        try await WatchSessionManager.shared.busArrivals(stopNo: stopNo)
    }

    func lineList(type: TransitType) async throws -> [BusLine] {
        try await WatchSessionManager.shared.lineList(type: type)
    }

    func lineSchedule(lineNo: String, type: TransitType) async throws -> LineSchedule {
        try await WatchSessionManager.shared.lineSchedule(lineNo: lineNo, type: type)
    }
}
#endif
