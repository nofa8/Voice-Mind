//
//  GeminiAnalysisService.swift
//  FirstApp
//
//  Created by Afonso on 03/11/2025.
//

import Foundation

// 1. Updated struct to match the new VoiceNote model fields
struct LLMAnalysis: Codable {
    let summary: String
    let sentiment: String
    let keywords: [String]
    let actionItems: [String]
    let category: String
    let priority: String
}

final class GeminiAnalysisService {
    static let shared = GeminiAnalysisService()
    private init() {}
    
    func analyze(_ text: String) async throws -> LLMAnalysis {
        // 2. Updated System Instruction with new JSON Schema
        let systemInstruction = """
        You are an intelligent personal assistant. Analyze the text and return structured JSON.
        Output must strictly follow this JSON schema. Do not include any surrounding markdown or backticks.
        
        {
          "summary": "Concise 1-sentence summary",
          "sentiment": "Positive | Negative | Neutral",
          "keywords": ["tag1", "tag2", "tag3"],
          "actionItems": ["Task 1", "Task 2"],
          "category": "Work | Personal | Health | Finance | Idea | Other",
          "priority": "High | Medium | Low"
        }
        
        Rules:
        - If there are no clear action items, return an empty array for "actionItems".
        - Choose the single best fit for "category".
        - Determine "priority" based on urgency and emotional tone.
        """
        
        let prompt = "Analyze the following text and respond ONLY with the JSON object:\n\(text)"
        
        // Use responseMimeType: "application/json" for guaranteed JSON output
        let rawResponse = try await GeminiService.shared.sendPrompt(
            prompt,
            systemInstruction: systemInstruction,
            responseMimeType: "application/json"
        )
        
        // Clean response just in case (though responseMimeType usually prevents this)
        let cleanedResponse = rawResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                                         .replacingOccurrences(of: "```json", with: "")
                                         .replacingOccurrences(of: "```", with: "")

        guard let jsonData = cleanedResponse.data(using: .utf8) else {
            throw GeminiError.decoding(URLError(.cannotDecodeContentData))
        }
        
        do {
            return try JSONDecoder().decode(LLMAnalysis.self, from: jsonData)
        } catch let error {
            print("Failed to decode final LLMAnalysis JSON. Raw text: \(rawResponse)")
            throw GeminiError.decoding(error)
        }
    }
}