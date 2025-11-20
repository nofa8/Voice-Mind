import Foundation
import SwiftData

@Model
final class VoiceNote {
    @Attribute(.unique) var id: UUID
    var createdAt: Date

    // Raw user speech
    var transcript: String

    // Gemini analysis
    var summary: String?
    var sentiment: String?
    var keywords: [String]?
    var translation: String?

    // Language metadata
    var detectedLanguage: String?
    var targetLanguage: String?

    init(
        transcript: String,
        summary: String? = nil,
        sentiment: String? = nil,
        keywords: [String]? = nil,
        translation: String? = nil,
        detectedLanguage: String? = nil,
        targetLanguage: String? = nil,
        createdAt: Date? = nil
    ) {
        self.id = UUID()
        self.createdAt = createdAt ?? Date()
        
        self.transcript = transcript
        self.summary = summary
        self.sentiment = sentiment
        self.keywords = keywords
        self.translation = translation
        self.detectedLanguage = detectedLanguage
        self.targetLanguage = targetLanguage
    }
}


