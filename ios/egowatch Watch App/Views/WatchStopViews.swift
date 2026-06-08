//
//  WatchStopViews.swift
//  egowatchw Watch App
//

import SwiftUI

struct WatchStopHomeView: View {
    @StateObject private var viewModel: StopHomeViewModel
    let service: EGOService
    @ObservedObject var favorites: FavoritesStore

    init(service: EGOService, favorites: FavoritesStore) {
        self.service = service
        self.favorites = favorites
        _viewModel = StateObject(wrappedValue: StopHomeViewModel(favorites: favorites))
    }

    var body: some View {
        List {
            Section("Favori Duraklar") {
                if favorites.stops.isEmpty {
                    Text("Favori durak yok")
                        .foregroundStyle(EGOTheme.secondaryText)
                } else {
                    ForEach(favorites.stops) { favorite in
                        NavigationLink {
                            WatchStopDetailView(stopNo: favorite.stopNo, service: service, favorites: favorites)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(favorite.stopNo)
                                    .font(.headline.monospacedDigit())
                                Text(favorite.title)
                                    .font(.caption)
                                    .foregroundStyle(EGOTheme.secondaryText)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }

            Section {
                NavigationLink {
                    WatchStopSearchView(service: service, favorites: favorites)
                } label: {
                    Label("Durak Sorgula", systemImage: "magnifyingglass.circle.fill")
                }
            }
        }
        .navigationTitle("Durak Sorgula")
    }
}

struct WatchStopSearchView: View {
    @StateObject private var viewModel: StopHomeViewModel
    let service: EGOService
    @ObservedObject var favorites: FavoritesStore
    private let keypadColumns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

    init(service: EGOService, favorites: FavoritesStore) {
        self.service = service
        self.favorites = favorites
        _viewModel = StateObject(wrappedValue: StopHomeViewModel(favorites: favorites))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                stopNumberDisplay
                keypad
                searchControl
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 8)
        }
        .navigationTitle("Durak No")
    }

    private var stopNumberDisplay: some View {
        HStack(spacing: 5) {
            ForEach(0..<5, id: \.self) { index in
                Text(character(at: index))
                    .font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(EGOTheme.surface, in: RoundedRectangle(cornerRadius: 7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(index < viewModel.normalizedStopNumber.count ? EGOTheme.accentBright : EGOTheme.border, lineWidth: 1)
                    )
            }
        }
        .padding(.top, 2)
    }

    private var keypad: some View {
        LazyVGrid(columns: keypadColumns, spacing: 6) {
            ForEach(1...9, id: \.self) { number in
                digitButton("\(number)")
            }

            iconButton(systemName: "trash", action: clear)
            digitButton("0")
            iconButton(systemName: "delete.left", action: deleteLast)
        }
    }

    @ViewBuilder
    private var searchControl: some View {
        if viewModel.canSearch {
            NavigationLink {
                WatchStopDetailView(stopNo: viewModel.normalizedStopNumber, service: service, favorites: favorites)
            } label: {
                Label("Sorgula", systemImage: "magnifyingglass")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(EGOTheme.accent)
        } else {
            Label("\(5 - viewModel.normalizedStopNumber.count) hane kaldı", systemImage: "number")
                .font(.caption.weight(.semibold))
                .foregroundStyle(EGOTheme.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
    }

    private func digitButton(_ digit: String) -> some View {
        Button {
            append(digit)
        } label: {
            Text(digit)
                .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
        }
        .buttonStyle(.plain)
        .background(EGOTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(EGOTheme.border, lineWidth: 1)
        )
        .disabled(viewModel.normalizedStopNumber.count >= 5)
        .opacity(viewModel.normalizedStopNumber.count >= 5 ? 0.45 : 1)
    }

    private func iconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
        }
        .buttonStyle(.plain)
        .background(EGOTheme.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(EGOTheme.border, lineWidth: 1)
        )
        .disabled(viewModel.normalizedStopNumber.isEmpty)
        .opacity(viewModel.normalizedStopNumber.isEmpty ? 0.45 : 1)
    }

    private func character(at index: Int) -> String {
        let number = viewModel.normalizedStopNumber
        guard index < number.count else { return "-" }
        return String(number[number.index(number.startIndex, offsetBy: index)])
    }

    private func append(_ digit: String) {
        guard viewModel.normalizedStopNumber.count < 5 else { return }
        viewModel.stopNumber = viewModel.normalizedStopNumber + digit
    }

    private func deleteLast() {
        var number = viewModel.normalizedStopNumber
        guard !number.isEmpty else { return }
        number.removeLast()
        viewModel.stopNumber = number
    }

    private func clear() {
        viewModel.stopNumber = ""
    }
}

struct WatchStopDetailView: View {
    @StateObject private var viewModel: StopDetailViewModel
    @ObservedObject private var favorites: FavoritesStore

    init(stopNo: String, service: EGOService, favorites: FavoritesStore) {
        _favorites = ObservedObject(wrappedValue: favorites)
        _viewModel = StateObject(wrappedValue: StopDetailViewModel(stopNo: stopNo, service: service, favorites: favorites))
    }

    var body: some View {
        List {
            if viewModel.isLoading && viewModel.arrivals.isEmpty {
                ProgressView()
            } else if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
            } else if viewModel.arrivals.isEmpty {
                Text("Yaklaşan araç yok")
                    .foregroundStyle(EGOTheme.secondaryText)
            } else {
                ForEach(viewModel.arrivals) { arrival in
                    compactArrival(arrival)
                }
            }
        }
        .navigationTitle(viewModel.stopNo)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: viewModel.toggleFavorite) {
                    Image(systemName: viewModel.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(viewModel.isFavorite ? .yellow : .white)
                }
                .buttonStyle(.plain)
            }
        }
        .task {
            await viewModel.load()
        }
        .sheet(isPresented: $viewModel.isShowingFavoriteSheet) {
            FavoriteNameSheet(title: "Favori Durak", name: $viewModel.favoriteName, save: viewModel.saveFavorite)
        }
    }

    private func compactArrival(_ arrival: BusArrival) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(arrival.lineCode)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(EGOTheme.accentBright)
                Spacer()
                Text(statusText(for: arrival))
                    .font(.headline.monospacedDigit())
            }
            Text(arrival.routeTitle)
                .font(.caption)
                .foregroundStyle(EGOTheme.secondaryText)
                .lineLimit(2)
            if case .scheduled(_, let time, let minutes) = arrival.kind {
                Text(scheduledDetail(time: time, minutes: minutes))
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            }
        }
    }

    private func statusText(for arrival: BusArrival) -> String {
        switch arrival.kind {
        case .live(let info):
            return info.etaText.isEmpty ? "-" : info.etaText
        case .scheduled:
            return "Planlı"
        }
    }

    private func scheduledDetail(time: String?, minutes: Int?) -> String {
        var parts = ["Henüz yola çıkmadı"]
        if let time {
            parts.append("ilk durak \(time)")
        }
        if let minutes {
            parts.append("\(minutes) dk sonra")
        }
        return parts.joined(separator: " · ")
    }
}
