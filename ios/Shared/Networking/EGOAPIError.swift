//
//  EGOAPIError.swift
//  egowatch (Shared)
//

import Foundation

nonisolated enum EGOAPIError: Error, Sendable, Equatable, LocalizedError {
    /// Durak numarası 5 haneli değil.
    case invalidStopNumber
    /// Hat numarası boş.
    case invalidLineNumber
    /// Ağ/bağlantı hatası.
    case network(String)
    /// HTTP hata kodu (2xx dışında).
    case server(statusCode: Int)
    /// Yanıt beklenen veriyi içermiyor / parse edilemedi.
    case parsingFailed
    /// Watch ↔ iPhone köprüsünde hata (telefon erişilemez vb.).
    case connectivity(String)

    var errorDescription: String? {
        switch self {
        case .invalidStopNumber:     return "Durak numarası 5 haneli olmalı."
        case .invalidLineNumber:     return "Geçerli bir hat seçilmedi."
        case .network(let message):  return "Bağlantı hatası: \(message)"
        case .server(let code):      return "Sunucu hatası (\(code))."
        case .parsingFailed:         return "Yanıt çözümlenemedi."
        case .connectivity(let msg): return "Telefon bağlantısı: \(msg)"
        }
    }
}
