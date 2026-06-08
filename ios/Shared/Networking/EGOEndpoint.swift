//
//  EGOEndpoint.swift
//  egowatch (Shared)
//
//  EGO endpoint tanımları ve form-encoded POST isteklerinin kurulması.
//

import Foundation

nonisolated enum EGOEndpoint: Sendable {
    case busArrivals(stopNo: String)
    case lineList(type: TransitType)
    case lineSchedule(lineNo: String, type: TransitType)

    static let baseURL = URL(string: "https://www.ego.gov.tr")!

    private var path: String {
        switch self {
        case .busArrivals:            return "/otobusnerede"
        case .lineList(let type):     return type.hatListesiPath
        case .lineSchedule:           return "/HareketSaatleri"
        }
    }

    /// Referer header — bazı endpoint'ler için sunucu tarafından beklenir.
    private var referer: String {
        switch self {
        case .busArrivals:  return "https://www.ego.gov.tr/otobusnerede"
        case .lineList, .lineSchedule:
            return "https://www.ego.gov.tr/HareketSaatleri"
        }
    }

    /// x-www-form-urlencoded gövde alanları.
    private var formFields: [String: String] {
        switch self {
        case .busArrivals(let stopNo):
            return ["durak_no": stopNo]
        case .lineList:
            return [:]   // boş gövde (alan gerekmez)
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
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(referer, forHTTPHeaderField: "Referer")
        request.setValue("text/html", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20

        let body = formFields
            .map { "\(Self.encode($0.key))=\(Self.encode($0.value))" }
            .joined(separator: "&")
        // lineList için boş gövde yerine tek boşluk gönderilir (curl örneğindeki gibi).
        request.httpBody = (body.isEmpty ? " " : body).data(using: .utf8)
        return request
    }

    private static func encode(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}
