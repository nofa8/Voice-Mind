//
//  SecretsDecoder.swift
//  FirstApp
//
//  Created by Afonso on 02/11/2025.
//
// GeminiClient.swift

import Foundation
// Define a richer error type
enum GeminiError: Error {
    case decoding(Error)
    case badURL
    case badResponse
    case api(String)
}

struct GeminiResponsePart: Codable {
    let text: String
}

struct GeminiCandidateContent: Codable {
    let parts: [GeminiResponsePart]
}

struct GeminiCandidate: Codable {
    let content: GeminiCandidateContent
}

struct GeminiResponse: Codable {
    let candidates: [GeminiCandidate]
}

final class GeminiService {
    static let shared = GeminiService()
    private init() {}
    
    // Model should be defined consistently, e.g., gemini-2.5-flash for both speed and capability.
    private let model = "gemini-2.5-flash"
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"
    
    // Assuming you read the key from your secure configuration (e.g., a process environment variable or xcconfig)
    private var apiKey: String {
        guard let key = Bundle.main.infoDictionary?["GEMINI_API_KEY"] as? String else {
            fatalError("❌ Missing GEMINI_API_KEY in your configuration (e.g., Secrets.xcconfig).")
        }
        return key
    }
    
    func sendPrompt(
        _ prompt: String,
        systemInstruction: String? = nil,
        responseMimeType: String? = nil
    ) async throws -> String {
        
        let urlString = "\(baseURL)/\(model):generateContent"
        guard let url = URL(string: urlString) else { throw GeminiError.badURL }
        
        let requestBody: [String: Any] = [
            "systemInstruction": systemInstruction != nil
                ? ["parts": [["text": systemInstruction!]]]
                : nil,
            "contents": [
                [
                    "role": "user",
                    "parts": [["text": prompt]]
                ]
            ],
            "generationConfig": [
                "temperature": 0.2,
                "responseMimeType": responseMimeType
            ].compactMapValues { $0 }
        ].compactMapValues { $0 }
        
        let data = try JSONSerialization.data(withJSONObject: requestBody)
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        req.httpBody = data
        
        
        let (responseData, response) = try await URLSession.shared.data(for: req)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw GeminiError.api("HTTP \(httpResponse.statusCode)")
        }
        
        do {
            let decoded = try JSONDecoder().decode(GeminiResponse.self, from: responseData)
            guard let result = decoded.candidates.first?.content.parts.first?.text else {
                throw GeminiError.badResponse
            }
            return result
        } catch let decodingError {
            throw GeminiError.decoding(decodingError)
        }
    }

}
