// VoiceRecorderViewModel.swift
import Foundation
import AVFoundation
import Speech
import SwiftData

@MainActor
class VoiceRecorderViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var transcription = ""
    
    // Analysis State
    @Published var summary = ""
    @Published var sentiment = ""
    @Published var keywords: [String] = []
    
    // AI Insights
    @Published var actionItems: [String] = []
    @Published var category = ""
    @Published var priority = ""
    
    // 🔥 New: Selected Language for Recognition
    @Published var selectedLanguage = "en-US"

    var modelContext: ModelContext?
    func setContext(_ context: ModelContext) { self.modelContext = context }

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // 🔥 Make Recognizer Optional (to re-init with new languages)
    private var speechRecognizer: SFSpeechRecognizer?
    
    // MARK: - Permissions
    func requestPermissions() async {
        SFSpeechRecognizer.requestAuthorization { _ in }
        AVAudioApplication.requestRecordPermission { _ in }
    }
    
    // MARK: - Recording Logic
    
    func startRecording(language: String) {
        // 1. Reset State
        transcription = ""
        summary = ""
        keywords = []
        actionItems = []
        
        // 2. Setup Recognizer for Selected Language
        let locale = Locale(identifier: language)
        if speechRecognizer?.locale != locale {
            speechRecognizer = SFSpeechRecognizer(locale: locale)
        }
        
        // 🔥 FIX #1: Validate speech recognizer is available
        // WHY: Prevents silent failure if language isn't supported or device doesn't support speech recognition
        // IMPACT: User will see error instead of recording with no transcription
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            print("❌ Speech recognizer not available for \(language)")
            summary = "Speech recognition not available for this language"
            return
        }
        
        isRecording = true
        
        // 3. Audio Setup
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        
        // 🔥 FIX #3: Fix race condition with weak self and state check
        // WHY: If speech recognition auto-completes while user manually stops, 
        //      we could call stopRecording() twice simultaneously
        // IMPACT: Prevents audio engine crashes from duplicate cleanup
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                Task { @MainActor in
                    self.transcription = result.bestTranscription.formattedString
                }
            }
            if error != nil || result?.isFinal == true {
                Task { @MainActor in
                    // Only auto-stop if we're still in recording state
                    if self.isRecording {
                        self.stopRecording()
                    }
                }
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
        
        // 🔥 FIX #2: Add safety checks for audio engine cleanup
        // WHY: If user rapidly taps start/stop or if startRecording() fails partway,
        //      the tap might not be installed, causing a crash when trying to remove it
        // IMPACT: Prevents crash on rapid start/stop cycles
        
        // Only stop if actually running
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        // Safely remove tap only if it was installed
        if audioEngine.inputNode.numberOfInputs > 0 {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        Task {
            await analyze()
        }
    }
    
    // MARK: - Analysis
    func analyze() async {
        let text = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        do {
            // 1. Detect language (for metadata)
            let detectedLang = try await detectLanguage(text)

            // 2. Analyze with Gemini
            let analysis = try await GeminiAnalysisService.shared.analyze(text)
            
            // 3. Parse ISO Date from Gemini
            var extractedDate: Date? = nil
            if let dateString = analysis.extractedDate {
                let formatter = ISO8601DateFormatter()
                // Handle optional fractional seconds just in case
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds] 
                extractedDate = formatter.date(from: dateString)
                
                // Fallback for standard ISO if fractional fails
                if extractedDate == nil {
                    formatter.formatOptions = [.withInternetDateTime]
                    extractedDate = formatter.date(from: dateString)
                }
            }
            
            // 4. Determine NoteType from String
            let type: NoteType = switch analysis.type.lowercased() {
                case "task": .task
                case "event": .event
                default: .note
            }
            
            // 5. Update UI
            self.summary = analysis.summary
            self.sentiment = analysis.sentiment
            self.category = analysis.category

            // 6. Save
            guard let ctx = modelContext else { return }
            
            let note = VoiceNote(
                transcript: text,
                summary: analysis.summary,
                sentiment: analysis.sentiment,
                keywords: analysis.keywords,
                actionItems: analysis.actionItems,
                category: analysis.category,
                priority: analysis.priority,
                eventDate: extractedDate, // Uses Gemini's date or nil
                eventLocation: analysis.extractedLocation,
                detectedLanguage: detectedLang,
                noteType: type // Determined by AI
            )
            
            ctx.insert(note)
            try? ctx.save()

        } catch {
            print("⚠️ Gemini failure:", error)
            self.summary = "Error during analysis"
        }
    }

    func detectLanguage(_ text: String) async throws -> String {
        let system = "Detect the language. Reply only with the language name."
        return try await GeminiService.shared.sendPrompt("Text:\n\(text)", systemInstruction: system)
    }
}