//
//  GeminiAnalysisService.swift
//  FirstApp
//
//  Created by Afonso on 03/11/2025.
//

// GeminiAnalysisService.swift

import Foundation

struct LLMAnalysis: Codable {
    let summary: String
    let sentiment: String
    let keywords: [String]
}

final class GeminiAnalysisService {
    static let shared = GeminiAnalysisService()
    private init() {}
    
    func analyze(_ text: String) async throws -> LLMAnalysis {
        // We include the schema in the prompt as a fallback,
        // but rely on responseMimeType for strict enforcement.
        let systemInstruction = """
        You are an AI assistant that analyzes text and returns structured JSON.
        Output must strictly follow this JSON schema. Do not include any surrounding markdown, backticks, or commentary.
        {
          "summary": "short 2-sentence summary",
          "sentiment": "Positive | Negative | Neutral",
          "keywords": ["keyword1", "keyword2", "keyword3"]
        }
        """
        
        let prompt = "Analyze the following text and respond ONLY with the JSON object:\n\(text)"
        
        // ⭐️ USE responseMimeType: "application/json" for guaranteed JSON output
        let rawResponse = try await GeminiService.shared.sendPrompt(
            prompt,
            systemInstruction: systemInstruction,
            responseMimeType: "application/json"
        )
        
        // Try to decode, handling potential surrounding backticks if the model ignores the instruction
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
