//
//  FirstAppApp.swift
//  FirstApp
//
//  Created by Afonso on 29/09/2025.
//

import SwiftUI
import SwiftData

@main
struct VoiceMindApp: App {
    @StateObject private var networkMonitor = NetworkMonitor.shared
    var body: some Scene {
        WindowGroup {
            TabView {
                NavigationStack {
                    MainView()
                }
                .tabItem {
                    Label("Record", systemImage: "mic.fill")
                }

                NavigationStack {
                    VoiceNotesListView()
                }
                .tabItem {
                    Label("Library", systemImage: "tray.fill")
                }

                NavigationStack {
                    AgendaView()
                }
                .tabItem {
                    Label("Agenda", systemImage: "calendar")
                }
                
                NavigationStack {
                    StatsView()
                }
                .tabItem {
                    Label("Insights", systemImage: "chart.bar.fill")
                }
            }
        }
        .environmentObject(networkMonitor)
        .modelContainer(for: VoiceNote.self)
    }
}

// 
