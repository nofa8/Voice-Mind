//
//  LLM_Service.swift
//  FirstApp
//
//  Created by Afonso on 02/11/2025.
//

import Foundation

// 🔥 Enhanced error type with user-friendly messages
enum GeminiError: Error, LocalizedError {
    case decoding(Error)
    case badURL
    case badResponse
    case api(String)
    case missingAPIKey  // 🔥 New: Instead of fatalError
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .decoding(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .badURL:
            return "Invalid API URL"
        case .badResponse:
            return "Empty or invalid response from AI"
        case .api(let message):
            return "API Error: \(message)"
        case .missingAPIKey:
            return "API Key is missing. Please add GEMINI_API_KEY to your configuration."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
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
    
    private let model = "gemini-2.5-flash"
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"
    
    // 🔥 Changed from fatalError to throwing function
    private func getAPIKey() throws -> String {
        guard let key = Bundle.main.infoDictionary?["GEMINI_API_KEY"] as? String,
              !key.isEmpty,
              !key.contains("$(") else {  // Catch unresolved xcconfig variables
            throw GeminiError.missingAPIKey
        }
        return key
    }
    
    func sendPrompt(
        _ prompt: String,
        systemInstruction: String? = nil,
        responseMimeType: String? = nil
    ) async throws -> String {
        
        // 🔥 Get API key with proper error handling
        let apiKey = try getAPIKey()
        
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
        req.timeoutInterval = 30  // 🔥 Add timeout
        
        let responseData: Data
        let response: URLResponse
        
        do {
            (responseData, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw GeminiError.networkError(error)
        }

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            // Try to get error message from response
            if let errorBody = String(data: responseData, encoding: .utf8) {
                throw GeminiError.api("HTTP \(httpResponse.statusCode): \(errorBody)")
            }
            throw GeminiError.api("HTTP \(httpResponse.statusCode)")
        }
        
        do {
            let decoded = try JSONDecoder().decode(GeminiResponse.self, from: responseData)
            guard let result = decoded.candidates.first?.content.parts.first?.text else {
                throw GeminiError.badResponse
            }
            return result
        } catch let decodingError as GeminiError {
            throw decodingError
        } catch {
            throw GeminiError.decoding(error)
        }
    }
}
