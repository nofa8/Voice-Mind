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
    
    // 🔥 LANGUAGE: Accept languageCode to localize output
    func analyze(_ text: String, languageCode: String) async throws -> LLMAnalysis {
        // 🔥 Use static formatters (much faster)
        let now = Date()
        let fullDateTime = Self.humanDateFormatter.string(from: now)
        let isoDate = Self.isoDateFormatter.string(from: now)
        
        // Convert "es-ES" -> "Spanish" for better AI understanding
        let targetLanguage = Locale(identifier: languageCode).localizedString(forLanguageCode: languageCode) ?? languageCode
        
        // 🔥 PROMPT ENGINEERING STRATEGY:
        // 1. Context Injection: We inject the current date/time to allow the LLM to resolve relative terms
        //    (e.g., "next Friday" becomes a concrete ISO8601 date).
        // 2. Multilingual Enforcing: We explicitly instruct the model to output in the *target* language
        //    regardless of the input language, ensuring consistency (e.g., Spanish input -> Spanish output).
        
        let systemInstruction = """
        You are an intelligent personal assistant analyzing voice notes.
        
        CURRENT CONTEXT:
        - Date: \(fullDateTime)
        - User Language: \(targetLanguage) (\(languageCode))
        
        OUTPUT INSTRUCTIONS:
        - You MUST generate the 'summary', 'actionItems', 'category', and 'sentiment' in \(targetLanguage).
        - If the user speaks \(targetLanguage), keep it in \(targetLanguage).
        - If the user speaks a different language, TRANSLATE the analysis into \(targetLanguage).
        
        Return JSON strictly matching this schema:
        {
          "summary": "First-person summary in \(targetLanguage) using 'I'. Example: 'Tengo cita con el dentista...'",
          "sentiment": "Positive | Negative | Neutral",
          "keywords": ["keyword1", "keyword2"],
          "actionItems": ["Action 1", "Action 2"],
          "category": "Work | Personal | Health | Finance | Idea",
          "priority": "High | Medium | Low",
          "type": "note | task | event",
          "extractedDate": "ISO8601 or null",
          "extractedLocation": "Location or null"
        }
        
        CRITICAL RULES:
        1. Calculate relative dates (tomorrow -> \(Self.isoDateFormatter.string(from: now.addingTimeInterval(86400))))
        2. Respond strictly in \(targetLanguage).
        3. "type": 
           - "event" = has a time/date/place
           - "task" = action items without specific time
           - "note" = general thoughts
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