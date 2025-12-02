// VoiceRecorderViewModel.swift
import Foundation
import AVFoundation
import Speech
import SwiftData

@MainActor
class VoiceRecorderViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var transcription = ""
    
    // Analysis Results
    @Published var summary = ""
    @Published var sentiment = ""
    @Published var keywords: [String] = []
    
    // 🔥 NEW: Actionable Insights
    @Published var actionItems: [String] = []
    @Published var category = ""
    @Published var priority = ""
    
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
    
    // MARK: - Database Saving
    func saveVoiceNote(
        transcript: String,
        analysis: LLMAnalysis,
        detectedLanguage: String?,
        noteType: NoteType,
        eventDate: Date,
        modelContext: ModelContext
    ) {
        let note = VoiceNote(
            transcript: transcript,
            summary: analysis.summary,
            sentiment: analysis.sentiment,
            keywords: analysis.keywords,
            // 🚀 Map new AI fields
            actionItems: analysis.actionItems,
            category: analysis.category,
            priority: analysis.priority,
            // 🗓 Map UI fields
            eventDate: eventDate, 
            detectedLanguage: detectedLanguage,
            noteType: noteType
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
        // Reset state
        transcription = ""
        summary = ""
        keywords = []
        actionItems = []
        category = ""
        priority = ""
        
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
                // If the system stops it (e.g. silence), we default to basic Note/Now. 
                // However, usually the user presses the button.
                self.stopRecording(noteType: .note, eventDate: Date())
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        try? audioEngine.start()
    }
    
    // 🔥 UPDATED: Accepts UI parameters
    func stopRecording(noteType: NoteType, eventDate: Date) {
        isRecording = false
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        Task {
            await analyze(noteType: noteType, eventDate: eventDate)
        }
    }
    
    // MARK: - Analysis
    func analyze(noteType: NoteType, eventDate: Date) async {
        let text = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        do {
            // 1. Detect language
            let detectedLang = try await detectLanguage(text)

            // 2. Analyze with Gemini (Returns Action Items, Category, etc.)
            let analysis = try await GeminiAnalysisService.shared.analyze(text)
            
            // 3. Update UI State
            self.summary = analysis.summary
            self.sentiment = analysis.sentiment
            self.keywords = analysis.keywords
            self.actionItems = analysis.actionItems
            self.category = analysis.category
            self.priority = analysis.priority

            // 4. Save
            guard let ctx = modelContext else { return }

            saveVoiceNote(
                transcript: text,
                analysis: analysis,
                detectedLanguage: detectedLang,
                noteType: noteType,
                eventDate: eventDate,
                modelContext: ctx
            )

        } catch {
            print("⚠️ Gemini failure:", error)
            self.summary = "Error during analysis"
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