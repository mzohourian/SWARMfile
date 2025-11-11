//
//  ContentView.swift
//  OneBox
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var jobManager: JobManager

    var body: some View {
        TabView(selection: $coordinator.selectedTab) {
            HomeView()
                .tabItem {
                    Label("Toolbox", systemImage: "square.grid.2x2")
                }
                .tag(AppCoordinator.AppTab.home)

            RecentsView()
                .tabItem {
                    Label("Recents", systemImage: "clock.arrow.circlepath")
                }
                .tag(AppCoordinator.AppTab.recents)
                .badge(jobManager.jobs.filter { $0.status == .success }.count)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(AppCoordinator.AppTab.settings)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppCoordinator())
        .environmentObject(JobManager.shared)
        .environmentObject(PaymentsManager.shared)
        .environmentObject(ThemeManager())
}
