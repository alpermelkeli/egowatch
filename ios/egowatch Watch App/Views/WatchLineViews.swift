//
//  WatchLineViews.swift
//  egowatchw Watch App
//

import SwiftUI

struct WatchLineHomeView: View {
    @StateObject private var viewModel: LineHomeViewModel
    let service: EGOService
    @ObservedObject var favorites: FavoritesStore

    init(service: EGOService, favorites: FavoritesStore) {
        self.service = service
        self.favorites = favorites
        _viewModel = StateObject(wrappedValue: LineHomeViewModel(favorites: favorites))
    }

    var body: some View {
        List {
            Section("Favori Hatlar") {
                if favorites.lines.isEmpty {
                    Text("Favori hat yok")
                        .foregroundStyle(EGOTheme.secondaryText)
                } else {
                    ForEach(favorites.lines) { favorite in
                        NavigationLink {
                            WatchLineScheduleView(line: favorite.busLine, service: service, favorites: favorites)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(favorite.lineCode)
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
                    WatchLineTypeSelectionView(service: service, favorites: favorites)
                } label: {
                    Label("Hat Sorgula", systemImage: "bus.fill")
                }
            }
        }
        .navigationTitle("Hat Sorgula")
    }
}

struct WatchLineTypeSelectionView: View {
    let service: EGOService
    @ObservedObject var favorites: FavoritesStore

    var body: some View {
        List {
            ForEach(TransitType.allCases) { type in
                NavigationLink {
                    WatchLineListView(type: type, service: service, favorites: favorites)
                } label: {
                    Text(type.displayName)
                }
            }
        }
        .navigationTitle("Tür")
    }
}

struct WatchLineListView: View {
    @StateObject private var viewModel: LineListViewModel
    let service: EGOService
    @ObservedObject var favorites: FavoritesStore

    init(type: TransitType, service: EGOService, favorites: FavoritesStore) {
        self.service = service
        self.favorites = favorites
        _viewModel = StateObject(wrappedValue: LineListViewModel(type: type, service: service))
    }

    var body: some View {
        List {
            if viewModel.isLoading {
                ProgressView()
            } else if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
            } else {
                ForEach(viewModel.filteredLines) { line in
                    NavigationLink {
                        WatchLineScheduleView(line: line, service: service, favorites: favorites)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(line.code)
                                .font(.headline.monospacedDigit())
                            Text(line.name)
                                .font(.caption)
                                .foregroundStyle(EGOTheme.secondaryText)
                                .lineLimit(2)
                        }
                    }
                }
            }
        }
        .searchable(text: $viewModel.query, prompt: "Hat ara")
        .navigationTitle(viewModel.type.displayName)
        .task {
            await viewModel.load()
        }
    }
}

struct WatchLineScheduleView: View {
    @StateObject private var viewModel: LineScheduleViewModel
    @ObservedObject private var favorites: FavoritesStore

    init(line: BusLine, service: EGOService, favorites: FavoritesStore) {
        _favorites = ObservedObject(wrappedValue: favorites)
        _viewModel = StateObject(wrappedValue: LineScheduleViewModel(line: line, service: service, favorites: favorites))
    }

    var body: some View {
        List {
            Picker("Gün", selection: $viewModel.selectedDay) {
                ForEach(ServiceDay.allCases) { day in
                    Text(day.displayName).tag(day)
                }
            }
            .pickerStyle(.navigationLink)

            if viewModel.isLoading && viewModel.schedule == nil {
                ProgressView()
            } else if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
            } else {
                Section("Saatler") {
                    ForEach(viewModel.selectedTimes, id: \.self) { time in
                        Text(time)
                            .font(.headline.monospacedDigit())
                    }
                }

                if let stops = viewModel.schedule?.stops, !stops.isEmpty {
                    Section("Güzergah") {
                        ForEach(stops) { stop in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(stop.order). \(stop.code)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(EGOTheme.accentBright)
                                Text(stop.name)
                                    .font(.caption)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(viewModel.line.code)
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
            FavoriteNameSheet(title: "Favori Hat", name: $viewModel.favoriteName, save: viewModel.saveFavorite)
        }
    }
}
