//
//  EGOEndpoint.swift
//  egowatch (Shared)
//
//  EGO endpoint tanımları ve isteklerin kurulması.
//
//  Otobüs Nerede sorgusu üç adımlıdır (bkz. docs/ego-api.md):
//    1. GET  /otobusnerede                 → formun rastgele alan adı (`bus-form` name'i)
//    2. GET  /Security/GetDynamicToken     → {"success":true,"token":"..."}
//    3. POST /otobusnerede/sorgula         → __RequestVerificationToken=<token>&<alan>=<durak>
//  Adımlar aynı oturum çerezlerini (ASP.NET_SessionId) paylaşmalıdır.
//

import Foundation

nonisolated enum EGOEndpoint: Sendable {
    /// Otobüs Nerede formunun bulunduğu sayfa (alan adı buradan okunur).
    case busArrivalsForm
    /// Form gönderiminden hemen önce alınan tek kullanımlık güvenlik token'ı.
    case dynamicToken
    /// Asıl durak sorgusu.
    case busArrivals(stopNo: String, fieldName: String, token: String)
    /// Hat listeleri artık HareketSaatleri sayfasına gömülü `<select>`'lerde gelir.
    case lineList
    case lineSchedule(lineNo: String, type: TransitType)

    static let baseURL = URL(string: "https://www.ego.gov.tr")!

    private var path: String {
        switch self {
        case .busArrivalsForm:         return "/otobusnerede"
        case .dynamicToken:            return "/Security/GetDynamicToken"
        case .busArrivals:             return "/otobusnerede/sorgula"
        case .lineList, .lineSchedule: return "/HareketSaatleri"
        }
    }

    private var method: String {
        switch self {
        case .busArrivalsForm, .dynamicToken, .lineList: return "GET"
        case .busArrivals, .lineSchedule:                return "POST"
        }
    }

    /// Referer header — bazı endpoint'ler için sunucu tarafından beklenir.
    private var referer: String {
        switch self {
        case .busArrivalsForm, .dynamicToken, .busArrivals:
            return "https://www.ego.gov.tr/otobusnerede"
        case .lineList, .lineSchedule:
            return "https://www.ego.gov.tr/HareketSaatleri"
        }
    }

    /// x-www-form-urlencoded gövde alanları (yalnızca POST).
    private var formFields: [String: String] {
        switch self {
        case .busArrivalsForm, .dynamicToken, .lineList:
            return [:]
        case .busArrivals(let stopNo, let fieldName, let token):
            return ["__RequestVerificationToken": token, fieldName: stopNo]
        case .lineSchedule(let lineNo, let type):
            // hat_no1/2/3'ün hepsi gönderilir; sadece ilgili olan doldurulur.
            var fields = ["hat_no1": "", "hat_no2": "", "hat_no3": ""]
            fields[type.hareketSaatleriField] = lineNo
            return fields
        }
    }

    func makeRequest() -> URLRequest {
        let url = EGOEndpoint.baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(referer, forHTTPHeaderField: "Referer")
        request.timeoutInterval = 20

        switch self {
        case .dynamicToken:
            // Sitenin JS'i bu header'ı gönderir; olmadan token verilmez.
            request.setValue("JS-Tetikleme", forHTTPHeaderField: "X-Custom-Req")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
        default:
            request.setValue("text/html", forHTTPHeaderField: "Accept")
        }

        if method == "POST" {
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = formFields
                .map { "\(Self.encode($0.key))=\(Self.encode($0.value))" }
                .joined(separator: "&")
                .data(using: .utf8)
        }
        return request
    }

    private static func encode(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}
