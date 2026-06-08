//
//  EGOMessage.swift
//  egowatch (Shared)
//
//  Apple Watch ↔ iPhone arasında WatchConnectivity ile taşınan istek/yanıt tipleri.
//  Watch bir EGORequest gönderir; iPhone EGOAPIClient ile veriyi çekip EGOResponse döner.
//

import Foundation

/// Watch'tan telefona giden istek.
nonisolated enum EGORequest: Codable, Sendable, Hashable {
    case busArrivals(stopNo: String)
    case lineList(type: TransitType)
    case lineSchedule(lineNo: String, type: TransitType)
}

/// Telefondan watch'a dönen yanıt.
nonisolated enum EGOResponse: Codable, Sendable {
    case busArrivals([BusArrival])
    case lineList([BusLine])
    case lineSchedule(LineSchedule)
    case failure(message: String)
}

/// İstek/yanıtların Data'ya (JSON) çevrilmesi için ortak kodlayıcı.
nonisolated enum EGOCoder {
    static func encode<T: Encodable>(_ value: T) throws -> Data {
        try JSONEncoder().encode(value)
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }
}
