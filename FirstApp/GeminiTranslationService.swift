//
//  GeminiTranslationService.swift
//  FirstApp
//
//  Created by Afonso on 03/11/2025.
//

import Foundation

final class GeminiTranslationService {
    static let shared = GeminiTranslationService()
    private init() {}
    
    func translate(_ text: String, to targetLanguage: String) async throws -> String {
        let systemInstruction = """
        You are a professional translator. Automatically detect the input language.
        Translate the text naturally into \(targetLanguage).
        Return only the translated text, nothing else.
        """
        
        let prompt = "Translate this text:\n\(text)"
        
        // No responseMimeType needed, as we expect plain text
        return try await GeminiService.shared.sendPrompt(
            prompt,
            systemInstruction: systemInstruction
        )
    }
}
