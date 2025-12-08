//
//  GeminiAnalysisService.swift
//  FirstApp
//
//  Created by Afonso on 03/11/2025.
//

import Foundation

// Response struct matching AI output
struct LLMAnalysis: Codable {
    let summary: String
    let sentiment: String
    let keywords: [String]
    let actionItems: [String]
    let category: String
    let priority: String
    let type: String            // note, task, event
    let extractedDate: String?  // ISO8601 String
    let extractedLocation: String?
}

final class GeminiAnalysisService {
    static let shared = GeminiAnalysisService()
    private init() {}
    
    // 🔥 PERFORMANCE FIX: Static formatters (expensive to create)
    private static let humanDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy 'at' h:mm a"
        return formatter
    }()
    
    private static let isoDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime, .withTimeZone]
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    func analyze(_ text: String) async throws -> LLMAnalysis {
        // 🔥 Use static formatters (much faster)
        let now = Date()
        let fullDateTime = Self.humanDateFormatter.string(from: now)
        let isoDate = Self.isoDateFormatter.string(from: now)
        
        let systemInstruction = """
        You are an intelligent personal assistant analyzing voice notes.
        
        CURRENT DATE/TIME CONTEXT:
        - Human readable: \(fullDateTime)
        - ISO8601: \(isoDate)
        - Use this to resolve relative dates like "tomorrow", "next week", "Monday", etc.
        
        Return JSON strictly matching this schema:
        {
          "summary": "First-person summary using 'I' (not 'The user'). Example: 'I have a dentist appointment tomorrow at 8am.'",
          "sentiment": "Positive | Negative | Neutral",
          "keywords": ["keyword1", "keyword2"],
          "actionItems": ["Action 1", "Action 2"],
          "category": "Work | Personal | Health | Finance | Idea",
          "priority": "High | Medium | Low",
          "type": "note | task | event",
          "extractedDate": "ISO8601 format (YYYY-MM-DDTHH:mm:ss). CALCULATE from relative terms like 'tomorrow', 'next Monday'. Return null ONLY if NO time reference exists.",
          "extractedLocation": "Location name if mentioned, else null"
        }
        
        CRITICAL RULES:
        1. "extractedDate": You MUST calculate dates from relative terms!
           - If today is \(fullDateTime) and user says "tomorrow at 8am", calculate the actual ISO8601 date.
           - "tomorrow" = add 1 day to current date
           - "next Monday" = find the next Monday from today
           - ALWAYS include the time if mentioned (e.g., "8am" -> T08:00:00)
        
        2. "type": 
           - "event" = has a time/date/place (appointments, meetings, etc.)
           - "task" = action items without specific time
           - "note" = general thoughts/observations
        
        3. "summary": Write from user's perspective using "I" (first person).
           - CORRECT: "I have a dentist appointment tomorrow at 8am."
           - WRONG: "The user has a dentist appointment."
        """
        
        let prompt = "Analyze this voice note:\n\(text)"
        
        let rawResponse = try await GeminiService.shared.sendPrompt(
            prompt,
            systemInstruction: systemInstruction,
            responseMimeType: "application/json"
        )
        
        // Cleanup
        let cleanedResponse = rawResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                                         .replacingOccurrences(of: "```json", with: "")
                                         .replacingOccurrences(of: "```", with: "")

        guard let jsonData = cleanedResponse.data(using: .utf8) else {
            throw GeminiError.decoding(URLError(.cannotDecodeContentData))
        }
        
        do {
            return try JSONDecoder().decode(LLMAnalysis.self, from: jsonData)
        } catch let error {
            print("Failed to decode. Raw: \(rawResponse)")
            throw GeminiError.decoding(error)
        }
    }
}