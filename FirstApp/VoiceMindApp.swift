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
            }
        }
        .modelContainer(for: VoiceNote.self)
    }
}

// 
