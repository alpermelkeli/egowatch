//
//  EGOSharedViews.swift
//  egowatch (Shared)
//

import SwiftUI

struct EGOActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            EGOActionLabel(title: title, systemImage: systemImage)
        }
        .buttonStyle(.plain)
    }
}

struct EGOActionLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(EGOTheme.accent, in: Circle())
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(EGOTheme.secondaryText)
        }
        .padding(12)
        .background(EGOTheme.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(EGOTheme.border, lineWidth: 1)
        )
    }
}

struct FavoriteStopRow: View {
    let favorite: FavoriteStop

    var body: some View {
        HStack(spacing: 12) {
            Text(favorite.stopNo)
                .font(.system(.headline, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .frame(minWidth: 54, alignment: .leading)
            Text(favorite.title)
                .font(.subheadline)
                .foregroundStyle(EGOTheme.secondaryText)
                .lineLimit(2)
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(EGOTheme.secondaryText)
        }
        .padding(12)
        .background(EGOTheme.surface, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct FavoriteLineRow: View {
    let favorite: FavoriteLine

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(favorite.lineCode)
                    .font(.system(.headline, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                Text(favorite.type.displayName)
                    .font(.caption2)
                    .foregroundStyle(EGOTheme.accentBright)
            }
            .frame(minWidth: 54, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text(favorite.title)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(favorite.lineName)
                    .font(.caption)
                    .foregroundStyle(EGOTheme.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(EGOTheme.secondaryText)
        }
        .padding(12)
        .background(EGOTheme.surface, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct BusLineRow: View {
    let line: BusLine

    var body: some View {
        HStack(spacing: 12) {
            Text(line.code)
                .font(.system(.headline, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .frame(minWidth: 58, alignment: .leading)
            Text(line.name)
                .font(.subheadline)
                .foregroundStyle(EGOTheme.secondaryText)
                .lineLimit(2)
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(EGOTheme.secondaryText)
        }
        .padding(12)
        .background(EGOTheme.surface, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct BusArrivalCard: View {
    let arrival: BusArrival

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Text(arrival.lineCode)
                    .font(.system(.title3, design: .rounded).weight(.bold).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(EGOTheme.accent, in: RoundedRectangle(cornerRadius: 6))
                VStack(alignment: .leading, spacing: 3) {
                    Text(arrival.routeTitle)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    detailText
                        .font(.caption)
                        .foregroundStyle(EGOTheme.secondaryText)
                        .lineLimit(2)
                }
                Spacer(minLength: 4)
            }
            statusRow
        }
        .padding(12)
        .background(EGOTheme.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(EGOTheme.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var detailText: some View {
        switch arrival.kind {
        case .live(let info):
            Text([info.plate, info.lineRef.map { "[\($0)]" }].compactMap { $0 }.joined(separator: " "))
        case .scheduled:
            Text("Araç henüz ilk duraktan çıkmadı")
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        HStack(spacing: 8) {
            switch arrival.kind {
            case .live(let info):
                Label(info.etaText.isEmpty ? "-" : info.etaText, systemImage: "clock.fill")
                if let queue = info.queueText {
                    Label(queue, systemImage: "mappin.and.ellipse")
                }
                if info.isAccessible {
                    Image(systemName: "figure.roll")
                }
                if info.hasBikeRack {
                    Image(systemName: "bicycle")
                }
            case .scheduled(_, let departureTime, let inMinutes):
                Label("Henüz yola çıkmadı", systemImage: "calendar.badge.clock")
                if let departureTime {
                    Text("İlk durak \(departureTime)")
                }
                if let inMinutes {
                    Text("\(inMinutes) dk sonra")
                }
            }
            Spacer(minLength: 0)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(EGOTheme.accentBright)
    }
}

struct EGOStateView: View {
    let title: String
    let systemImage: String

    var body: some View {
        ContentUnavailableView(title, systemImage: systemImage)
            .foregroundStyle(EGOTheme.secondaryText)
    }
}

struct FavoriteNameSheet: View {
    let title: String
    @Binding var name: String
    let save: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Favori adı", text: $name)
            }
            .scrollContentBackground(.hidden)
            .background(EGOTheme.background)
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet", action: save)
                }
            }
        }
    }
}
