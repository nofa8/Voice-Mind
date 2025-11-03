//
//  VoiceNote.swift
//  FirstApp
//
//  Created by Afonso on 01/11/2025.
//

import Foundation

struct VoiceNote: Identifiable {
    let id = UUID()
    var date: Date
    var transcription: String
    var summary: String?
    var sentiment: String?
    var audioURL: URL?
}
