//
//  EgoShortcuts.swift
//  egowatch
//
//  Siri cümleleri. Siri kuralı gereği her cümlede uygulama adı geçmelidir.
//

import AppIntents

nonisolated struct EgoShortcuts: AppShortcutsProvider {
    /// Favoriler ya da görülen hatlar değişince Siri'nin tanıdığı parametre değerlerini yeniler.
    static func refresh() {
        updateAppShortcutParameters()
    }

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StopLineETAIntent(),
            phrases: [
                "\(.applicationName) \(\.$target)",
                "\(.applicationName) \(\.$target) kaç dakika",
                "\(.applicationName) \(\.$target) kaç dakika var",
                "\(.applicationName) \(\.$target) ne zaman gelir",
                "\(.applicationName) ile \(\.$target) kaç dakika"
            ],
            shortTitle: "Duraktaki Hat",
            systemImageName: "bus.fill"
        )
        AppShortcut(
            intent: BusETAIntent(),
            phrases: [
                "\(.applicationName) otobüs kaç dakika",
                "\(.applicationName) ile otobüs ne zaman gelir"
            ],
            shortTitle: "Otobüs Kaç Dakika",
            systemImageName: "bus"
        )
    }
}
