//
//  IOSLineViews.swift
//  egowatch
//

import SwiftUI

struct IOSLineHomeView: View {
    @StateObject private var viewModel: LineHomeViewModel
    let service: EGOService
    @ObservedObject var favorites: FavoritesStore

    init(service: EGOService, favorites: FavoritesStore) {
        self.service = service
        self.favorites = favorites
        _viewModel = StateObject(wrappedValue: LineHomeViewModel(favorites: favorites))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Hat Sorgula")
                        .font(.largeTitle.weight(.bold))

                    NavigationLink {
                        IOSLineTypeSelectionView(service: service, favorites: favorites)
                    } label: {
                        EGOActionLabel(title: "Hat Sorgula", systemImage: "bus.fill")
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Favori Hatlar")
                            .font(.headline)
                        if favorites.lines.isEmpty {
                            EGOStateView(title: "Favori hat yok", systemImage: "star")
                                .frame(maxWidth: .infinity, minHeight: 180)
                        } else {
                            ForEach(favorites.lines) { favorite in
                                NavigationLink {
                                    LineScheduleView(line: favorite.busLine, service: service, favorites: favorites)
                                } label: {
                                    FavoriteLineRow(favorite: favorite)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(EGOTheme.background.ignoresSafeArea())
        }
    }
}

struct IOSLineTypeSelectionView: View {
    let service: EGOService
    @ObservedObject var favorites: FavoritesStore

    var body: some View {
        List {
            ForEach(TransitType.allCases) { type in
                NavigationLink {
                    LineListView(type: type, service: service, favorites: favorites)
                } label: {
                    Label(type.displayName, systemImage: icon(for: type))
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(EGOTheme.background)
        .navigationTitle("Ulaşım Türü")
    }

    private func icon(for type: TransitType) -> String {
        switch type {
        case .otobus: "bus.fill"
        case .metro: "tram.fill"
        case .ankaray: "tram.circle.fill"
        }
    }
}

struct LineListView: View {
    @StateObject private var viewModel: LineListViewModel
    let service: EGOService
    @ObservedObject var favorites: FavoritesStore

    init(type: TransitType, service: EGOService, favorites: FavoritesStore) {
        self.service = service
        self.favorites = favorites
        _viewModel = StateObject(wrappedValue: LineListViewModel(type: type, service: service))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 220)
                } else if let error = viewModel.errorMessage {
                    EGOStateView(title: error, systemImage: "exclamationmark.triangle")
                        .frame(maxWidth: .infinity, minHeight: 220)
                } else {
                    ForEach(viewModel.filteredLines) { line in
                        NavigationLink {
                            LineScheduleView(line: line, service: service, favorites: favorites)
                        } label: {
                            BusLineRow(line: line)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .background(EGOTheme.background.ignoresSafeArea())
        .navigationTitle(viewModel.type.displayName)
        .searchable(text: $viewModel.query, prompt: "Hat ara")
        .task {
            await viewModel.load()
        }
    }
}

struct LineScheduleView: View {
    @StateObject private var viewModel: LineScheduleViewModel
    @ObservedObject private var favorites: FavoritesStore

    init(line: BusLine, service: EGOService, favorites: FavoritesStore) {
        _favorites = ObservedObject(wrappedValue: favorites)
        _viewModel = StateObject(wrappedValue: LineScheduleViewModel(line: line, service: service, favorites: favorites))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                header
                Picker("Gün", selection: $viewModel.selectedDay) {
                    ForEach(ServiceDay.allCases) { day in
                        Text(day.displayName).tag(day)
                    }
                }
                .pickerStyle(.segmented)

                content
            }
            .padding()
        }
        .background(EGOTheme.background.ignoresSafeArea())
        .navigationTitle(viewModel.line.code)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: viewModel.toggleFavorite) {
                    Image(systemName: viewModel.isFavorite ? "star.fill" : "star")
                }
                .tint(EGOTheme.accentBright)
            }
        }
        .task {
            await viewModel.load()
        }
        .sheet(isPresented: $viewModel.isShowingFavoriteSheet) {
            FavoriteNameSheet(title: "Favori Hat", name: $viewModel.favoriteName, save: viewModel.saveFavorite)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.line.displayLabel)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
            if let schedule = viewModel.schedule {
                HStack {
                    if let distance = schedule.distanceText { Label(distance, systemImage: "arrow.left.and.right") }
                    if let duration = schedule.durationText { Label(duration, systemImage: "clock") }
                }
                .font(.caption)
                .foregroundStyle(EGOTheme.secondaryText)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.schedule == nil {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 220)
        } else if let error = viewModel.errorMessage {
            EGOStateView(title: error, systemImage: "exclamationmark.triangle")
                .frame(maxWidth: .infinity, minHeight: 220)
        } else {
            Text("Sefer Saatleri")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], spacing: 8) {
                ForEach(viewModel.selectedTimes, id: \.self) { time in
                    Text(time)
                        .font(.system(.body, design: .rounded).weight(.semibold).monospacedDigit())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(EGOTheme.surface, in: RoundedRectangle(cornerRadius: 8))
                }
            }

            if let stops = viewModel.schedule?.stops, !stops.isEmpty {
                Text("Güzergah")
                    .font(.headline)
                    .padding(.top, 8)
                ForEach(stops) { stop in
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(stop.order). \(stop.code) · \(stop.name)")
                            .font(.subheadline.weight(.semibold))
                        if let address = stop.address {
                            Text(address)
                                .font(.caption)
                                .foregroundStyle(EGOTheme.secondaryText)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(EGOTheme.surface, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}
