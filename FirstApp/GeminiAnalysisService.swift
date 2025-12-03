//
//  GeminiAnalysisService.swift
//  FirstApp
//
//  Created by Afonso on 03/11/2025.
//

import Foundation

// 🔥 UPDATED Struct: Matches the new AI logic
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
    
    func analyze(_ text: String) async throws -> LLMAnalysis {
        // 🔥 Inject Current Date for Context
        let currentDate = Date().formatted(date: .numeric, time: .shortened)
        
        let systemInstruction = """
        You are an intelligent personal assistant. Analyze the transcript.
        Current Date/Time: \(currentDate). Use this to resolve relative dates (e.g., "tomorrow", "next Friday").
        
        Return JSON strictly matching this schema:
        {
          "summary": "Concise 1-sentence summary",
          "sentiment": "Positive | Negative | Neutral",
          "keywords": ["tag1", "tag2"],
          "actionItems": ["Task 1", "Task 2"],
          "category": "Work | Personal | Health | Finance | Idea",
          "priority": "High | Medium | Low",
          "type": "note | task | event",
          "extractedDate": "ISO8601 date string (YYYY-MM-DDTHH:mm:ss) ONLY if a specific time/date is mentioned. Otherwise null.",
          "extractedLocation": "Location name if mentioned, else null"
        }
        
        Rules:
        - "type": "task" if it implies an action to do. "event" if it has a specific time/place. "note" otherwise.
        - "extractedDate": Must be strictly ISO8601.
        """
        
        let prompt = "Analyze this:\n\(text)"
        
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