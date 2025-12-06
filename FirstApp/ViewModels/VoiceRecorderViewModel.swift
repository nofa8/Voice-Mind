// VoiceRecorderViewModel.swift
import Foundation
import AVFoundation
import Speech
import SwiftData
import StoreKit

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
    
    // Selected Language for Recognition
    @Published var selectedLanguage = "en-US"

    var modelContext: ModelContext?
    func setContext(_ context: ModelContext) { self.modelContext = context }

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    
    // Audio Recording
    private var audioRecorder: AVAudioRecorder?
    private var currentAudioPath: String?
    
    // MARK: - Permissions
    func requestPermissions() async {
        SFSpeechRecognizer.requestAuthorization { _ in }
        AVAudioApplication.requestRecordPermission { _ in }
    }
    
    // MARK: - Audio File Management
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func generateAudioFilePath() -> URL {
        let timestamp = Date().timeIntervalSince1970
        let filename = "voice_note_\(Int(timestamp)).m4a"
        return getDocumentsDirectory().appendingPathComponent(filename)
    }
    
    // MARK: - Recording Logic
    
    func startRecording(language: String) {
        transcription = ""
        summary = ""
        keywords = []
        actionItems = []
        
        let locale = Locale(identifier: language)
        if speechRecognizer?.locale != locale {
            speechRecognizer = SFSpeechRecognizer(locale: locale)
        }
        
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            print("❌ Speech recognizer not available for \(language)")
            summary = "Speech recognition not available for this language"
            return
        }
        
        isRecording = true
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("❌ Audio session error: \(error)")
            return
        }
        
        // Setup Audio File Recording
        let audioURL = generateAudioFilePath()
        currentAudioPath = audioURL.path
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.record()
        } catch {
            print("❌ Audio recorder error: \(error)")
        }
        
        // Speech Recognition Setup
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                Task { @MainActor in
                    self.transcription = result.bestTranscription.formattedString
                }
            }
            if error != nil || result?.isFinal == true {
                Task { @MainActor in
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
        
        audioRecorder?.stop()
        audioRecorder = nil
        
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
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
        guard !text.isEmpty else { 
            if let path = currentAudioPath {
                try? FileManager.default.removeItem(atPath: path)
            }
            currentAudioPath = nil
            return 
        }
        
        do {
            let detectedLang = try await detectLanguage(text)
            let analysis = try await GeminiAnalysisService.shared.analyze(text)
            
            // 🔥 Robust date parsing - try multiple formats
            var extractedDate: Date? = nil
            if let dateString = analysis.extractedDate {
                let formatter = ISO8601DateFormatter()
                
                // Try formats in order of specificity
                let formatOptions: [ISO8601DateFormatter.Options] = [
                    [.withInternetDateTime, .withFractionalSeconds],
                    [.withInternetDateTime],
                    [.withFullDate, .withTime, .withColonSeparatorInTime],
                    [.withFullDate, .withTime, .withColonSeparatorInTime, .withTimeZone],
                    [.withFullDate]
                ]
                
                for options in formatOptions {
                    formatter.formatOptions = options
                    if let date = formatter.date(from: dateString) {
                        extractedDate = date
                        print("✅ Parsed date: \(date) from: \(dateString)")
                        break
                    }
                }
                
                // Fallback: try DateFormatter for non-ISO formats
                if extractedDate == nil {
                    let fallbackFormatter = DateFormatter()
                    fallbackFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                    fallbackFormatter.timeZone = TimeZone.current
                    extractedDate = fallbackFormatter.date(from: dateString)
                    
                    if extractedDate != nil {
                        print("✅ Parsed date (fallback): \(extractedDate!) from: \(dateString)")
                    } else {
                        print("⚠️ Failed to parse date: \(dateString)")
                    }
                }
            }
            
            let type: NoteType = switch analysis.type.lowercased() {
                case "task": .task
                case "event": .event
                default: .note
            }
            
            self.summary = analysis.summary
            self.sentiment = analysis.sentiment
            self.category = analysis.category

            guard let ctx = modelContext else { return }
            
            let note = VoiceNote(
                transcript: text,
                summary: analysis.summary,
                sentiment: analysis.sentiment,
                keywords: analysis.keywords,
                actionItems: analysis.actionItems,
                category: analysis.category,
                priority: analysis.priority,
                eventDate: extractedDate,
                eventLocation: analysis.extractedLocation,
                detectedLanguage: detectedLang,
                noteType: type,
                audioFilePath: currentAudioPath
            )
            
            ctx.insert(note)
            try? ctx.save()
            currentAudioPath = nil
            
            // 🔥 App Review: Request after 3rd successful note
            requestReviewIfAppropriate()

        } catch let error as GeminiError {
            print("⚠️ Gemini failure:", error)
            self.summary = error.localizedDescription
        } catch {
            print("⚠️ Unknown error:", error)
            self.summary = "Error during analysis"
        }
    }

    func detectLanguage(_ text: String) async throws -> String {
        let system = "Detect the language. Reply only with the language name."
        return try await GeminiService.shared.sendPrompt("Text:\n\(text)", systemInstruction: system)
    }
    
    // 🔥 App Review Request
    private func requestReviewIfAppropriate() {
        let noteCountKey = "successfulNoteCount"
        let hasRequestedKey = "hasRequestedReview"
        
        // Don't ask again if already requested
        guard !UserDefaults.standard.bool(forKey: hasRequestedKey) else { return }
        
        // Increment and check count
        let count = UserDefaults.standard.integer(forKey: noteCountKey) + 1
        UserDefaults.standard.set(count, forKey: noteCountKey)
        
        // Request review on 3rd successful note
        if count == 3 {
            UserDefaults.standard.set(true, forKey: hasRequestedKey)
            
            // Get active window scene and request review
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                SKStoreReviewController.requestReview(in: windowScene)
            }
        }
    }
}