import Foundation
import SwiftData

@Model
final class VoiceNote {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    
    // Raw user speech
    var transcript: String
    
    // 🔥 Audio file path for playback
    var audioFilePath: String?
    
    // AI Analysis
    var summary: String?
    var sentiment: String?
    var keywords: [String]?
    
    var actionItems: [String]? // Extracted tasks
    var category: String?      // e.g., "Work", "Personal", "Ideas"
    var priority: String?      // "High", "Medium", "Low"
    
    var eventDate: Date?       // When the event happens
    var isCompleted: Bool      // Checkbox for task items
    var noteType: NoteType     
    var eventLocation: String? // Where the event happens

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
        audioFilePath: String? = nil
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
        self.detectedLanguage = detectedLanguage
        self.audioFilePath = audioFilePath
    }
}

// Simplified Enum
enum NoteType: String, CaseIterable, Codable {
    case note         // Standard thought/journal
    case task         // Actionable item (needs a checkbox)
    case event        // Has a specific time/location (meeting)
}