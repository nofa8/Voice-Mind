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
            VoiceNotesListView()
            //MainView()
        }
            .modelContainer(for: VoiceNote.self)
    }
}

// 
