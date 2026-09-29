//
//  BusETASnippetView.swift
//  egowatch
//
//  Siri'nin cevap kartında gösterilen görünüm.
//

import SwiftUI

struct BusETASnippetView: View {
    let result: BusETAResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if let error = result.errorMessage {
                message(error, systemImage: "exclamationmark.triangle.fill")
            } else if let first = result.live.first {
                primaryRow(first.arrival, first.info)
                if result.live.count > 1 {
                    Divider().overlay(EGOTheme.border)
                    ForEach(Array(result.live.dropFirst().prefix(3).enumerated()), id: \.offset) { _, item in
                        secondaryRow(item.info)
                    }
                }
            } else if let departure = result.scheduled.first,
                      case let .scheduled(_, time, _) = departure.kind, let time {
                message("Henüz yola çıkmadı · İlk duraktan \(time)", systemImage: "calendar.badge.clock")
            } else {
                message("Şu anda yaklaşan otobüs yok", systemImage: "bus")
            }

            Text("\(result.date.formatted(date: .omitted, time: .shortened)) itibarıyla")
                .font(.caption2)
                .foregroundStyle(EGOTheme.secondaryText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EGOTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .environment(\.colorScheme, .dark)
    }

    private var header: some View {
        HStack(spacing: 10) {
            // "297" dendiğinde gerçek kod ("297-7") gösterilir.
            Text(result.live.first?.arrival.lineCode ?? result.lineCode)
                .font(.system(.title3, design: .rounded).weight(.bold).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(EGOTheme.accent, in: RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                Text(result.stopTitle)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(result.live.first?.arrival.routeTitle ?? "Durak \(result.stopNo)")
                    .font(.caption)
                    .foregroundStyle(EGOTheme.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    private func primaryRow(_ arrival: BusArrival, _ info: BusArrival.LiveInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(etaLabel(info))
                .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(EGOTheme.accentBright)
            Text(details(info))
                .font(.subheadline)
                .foregroundStyle(EGOTheme.secondaryText)
        }
    }

    private func secondaryRow(_ info: BusArrival.LiveInfo) -> some View {
        HStack {
            Text(etaLabel(info))
                .font(.headline.monospacedDigit())
                .foregroundStyle(.white)
                .frame(minWidth: 64, alignment: .leading)
            Text(details(info))
                .font(.caption)
                .foregroundStyle(EGOTheme.secondaryText)
            Spacer(minLength: 0)
        }
    }

    private func message(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(.white)
    }

    private func etaLabel(_ info: BusArrival.LiveInfo) -> String {
        if let minutes = info.etaMinutes {
            return minutes == 0 ? "Geliyor" : "\(minutes) dk"
        }
        return info.etaText.isEmpty ? "-" : info.etaText
    }

    private func details(_ info: BusArrival.LiveInfo) -> String {
        [info.queueText, info.plate].compactMap { $0 }.joined(separator: " · ")
    }
}

#Preview("Canlı") {
    BusETASnippetView(result: .preview(etas: ["4dk 7sn", "33dk 38sn"]))
        .padding()
}

#Preview("Geliyor") {
    BusETASnippetView(result: .preview(etas: ["Geliyor"]))
        .padding()
}

#Preview("Boş") {
    BusETASnippetView(result: .preview(etas: []))
        .padding()
}

#Preview("Hata") {
    BusETASnippetView(result: BusETAResult(stopTitle: "Kızılay", stopNo: "11532", lineCode: "590", errorMessage: "Bağlantı hatası"))
        .padding()
}

private extension BusETAResult {
    static func preview(etas: [String]) -> BusETAResult {
        let arrivals = etas.enumerated().map { index, eta in
            BusArrival(lineCode: "590", routeTitle: "KORU METRO İST.-YAŞAMKENT", kind: .live(.init(
                etaText: eta,
                etaMinutes: eta == "Geliyor" ? 0 : Int(eta.prefix { $0.isNumber }),
                queueText: "\(53 - index * 38)/59",
                plate: index == 0 ? "06 DCN 220" : "06 DY 0364",
                lineRef: nil, speedKmh: nil, features: [], rawMeta: ""
            )))
        }
        return BusETAResult(stopTitle: "Kızılay", stopNo: "11532", lineCode: "590", arrivals: arrivals, date: Date())
    }
}
