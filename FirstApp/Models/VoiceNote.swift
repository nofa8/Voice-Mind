import Foundation
import SwiftData

// 🔥 Analysis Status for Retry Logic
enum AnalysisStatus: String, Codable {
    case pending
    case completed
    case failed
}

@Model
final class VoiceNote {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    
    // Raw user speech
    var transcript: String
    
    // Audio file path for playback
    var audioFilePath: String?
    
    // AI Analysis
    var summary: String?
    var sentiment: String?
    var keywords: [String]?
    
    var actionItems: [String]?
    var category: String?
    var priority: String?
    
    var eventDate: Date?
    var isCompleted: Bool
    var noteType: NoteType     
    var eventLocation: String?
    
    // 🔥 Pin feature
    var isPinned: Bool
    
    // 🔥 Analysis Status (for retry)
    var analysisStatus: AnalysisStatus

    // Metadata
    var detectedLanguage: String? 
    
    // Computed property for audio URL
    var audioURL: URL? {
        guard let path = audioFilePath else { return nil }
        return URL(fileURLWithPath: path)
    }
    
    init(
        transcript: String,
        summary: String? = nil,
        sentiment: String? = nil,
        keywords: [String]? = nil,
        actionItems: [String]? = nil,
        category: String? = nil,
        priority: String? = nil,
        eventDate: Date? = nil,
        eventLocation: String? = nil,
        detectedLanguage: String? = nil,
        createdAt: Date = Date(),
        noteType: NoteType = .note,
        audioFilePath: String? = nil,
        isPinned: Bool = false,
        analysisStatus: AnalysisStatus = .completed
    ) {
        self.id = UUID()
        self.createdAt = createdAt
        self.noteType = noteType
        self.eventDate = eventDate
        self.eventLocation = eventLocation
        
        self.transcript = transcript
        self.summary = summary
        self.sentiment = sentiment
        self.keywords = keywords
        
        self.actionItems = actionItems
        self.category = category
        self.priority = priority
        
        self.isCompleted = false
        self.isPinned = isPinned
        self.analysisStatus = analysisStatus
        self.detectedLanguage = detectedLanguage
        self.audioFilePath = audioFilePath
    }
}

// Simplified Enum
enum NoteType: String, CaseIterable, Codable {
    case note
    case task
    case event
}