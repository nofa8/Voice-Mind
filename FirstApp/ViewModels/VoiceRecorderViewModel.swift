import Foundation
import AVFoundation
import Speech
import SwiftData

@MainActor
class VoiceRecorderViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var transcription = ""
    @Published var summary = ""
    @Published var sentiment = ""
    @Published var keywords: [String] = []
    @Published var translation = ""
    @Published var targetLanguage = "English"
    @Published var scheduledDate = Date()
    
        // 🔥 Add this:
    var modelContext: ModelContext?

    func setContext(_ context: ModelContext) {
        self.modelContext = context
    }

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    
    // MARK: - Permissions
    func requestPermissions() async {
        SFSpeechRecognizer.requestAuthorization { status in
            print(status == .authorized ? "✅ Speech recognition authorized" : "❌ Speech recognition denied")
        }
        AVAudioApplication.requestRecordPermission { granted in
            print(granted ? "✅ Microphone access granted" : "❌ Microphone access denied")
        }
    }
    
    
    func saveVoiceNote(
        transcript: String,
        summary: String?,
        sentiment: String?,
        keywords: [String]?,
        translation: String?,
        detectedLanguage: String?,
        targetLanguage: String?,
        createdAt: Date? = nil,
        modelContext: ModelContext
    ) {
        let note = VoiceNote(
            transcript: transcript,
            summary: summary,
            sentiment: sentiment,
            keywords: keywords,
            translation: translation,
            detectedLanguage: detectedLanguage,
            targetLanguage: targetLanguage,
            createdAt: createdAt
        )

        modelContext.insert(note)

        do {
            try modelContext.save()
        } catch {
            print("❌ Failed to save note:", error)
        }
    }


    
    // MARK: - Recording
    func startRecording() {
        transcription = "Hello how are you in this beaufiful morning?"
        isRecording = true
        
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                self.transcription = result.bestTranscription.formattedString
            }
            if error != nil || result?.isFinal == true {
                self.stopRecording()
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        try? audioEngine.start()
    }
    
    func stopRecording() {
        isRecording = false
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        Task {
            await analyzeAndTranslate()
        }
    }
    
    // MARK: - Analysis + Translation
    func analyzeAndTranslate() async {
        let text = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        do {
            // 1. Detect original language
            let detectedLang = try await detectLanguage(text)

            // 2. Analyze with Gemini
            let analysis = try await GeminiAnalysisService.shared.analyze(text)
            self.summary = analysis.summary
            self.sentiment = analysis.sentiment
            self.keywords = analysis.keywords

            // 3. Translate summary
            let translated = try await GeminiTranslationService.shared.translate(
                analysis.summary,
                to: targetLanguage
            )
            self.translation = translated

            // 4. Save to database
            guard let ctx = modelContext else {
                print("❌ ModelContext not set")
                return
            }

            saveVoiceNote(
                transcript: text,
                summary: summary,
                sentiment: sentiment,
                keywords: keywords,
                translation: translation,
                detectedLanguage: detectedLang,
                targetLanguage: targetLanguage,
                createdAt: self.scheduledDate,
                modelContext: ctx
            )

        } catch {
            print("⚠️ Gemini failure:", error)
            self.summary = "Error during analysis"
            self.translation = "Translation failed"
        }
    }

    
    func detectLanguage(_ text: String) async throws -> String {
        let system = "Detect the language of this text. Reply with only the language name (e.g., English, Portuguese)."

        let result = try await GeminiService.shared.sendPrompt(
            "Text:\n\(text)",
            systemInstruction: system
        )

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

}
