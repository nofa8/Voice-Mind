// VoiceRecorderViewModel.swift
import Foundation
import AVFoundation
import Speech
import SwiftData
import StoreKit
import UIKit

@MainActor
class VoiceRecorderViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var isProcessing = false 
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
    
    // 🔥 HYBRID PIPELINE: Use AVAudioFile instead of AVAudioRecorder
    private var audioFile: AVAudioFile?
    private var currentAudioFilename: String?
    private var isAudioTapInstalled = false
    
    // 🔥 LANGUAGE: Store selected language for AI analysis output
    private var currentLanguageCode: String = "en-US"
    
    // MARK: - Permissions
    func requestPermissions() async {
        SFSpeechRecognizer.requestAuthorization { _ in }
        AVAudioApplication.requestRecordPermission { _ in }
    }
    
    // MARK: - Haptics
    private func triggerHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    private func triggerNotificationHaptic(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
    
    // MARK: - Audio File Management
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    // 🔥 HYBRID: Generate .wav filename (will be converted to .m4a after recording)
    private func generateAudioFilename() -> String {
        let timestamp = Date().timeIntervalSince1970
        return "voice_note_\(Int(timestamp)).wav"
    }
    
    // MARK: - Recording Logic
    
    func startRecording(language: String) {
        // 🔥 LANGUAGE: Save for AI analysis output
        self.currentLanguageCode = language
        
        self.transcription = ""
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
        
        // 🔥 AUDIO SESSION: Go with the Flow (Native Format)
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Use .default mode to let system handle processing (better for VM/Simulator)
            // Remove forced sample rate/buffer duration to prevent clock drift
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("❌ Audio session error: \(error)")
            return
        }
        
        // 🔥 HYBRID: Generate filename but don't create file yet
        let filename = generateAudioFilename()
        currentAudioFilename = filename
        
        // Speech Recognition Setup
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        
        // 🔥 STABILITY: Reset engine to clear previous state/crashes
        audioEngine.reset()
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0) // Use native output format
        
        // 🔥 SAFETY: Remove existing tap if any (prevents "Tap already installed" crash)
        inputNode.removeTap(onBus: 0)
        
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                Task { @MainActor in
                    if (result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines) != ""){
                        self.transcription = result.bestTranscription.formattedString
                    }
                }
            }
            // Only stop on real error, not just partials
            if error != nil {
                Task { @MainActor in
                    if self.isRecording {
                        self.stopRecording()
                    }
                }
            }
        }
        
        // 🔥 HYBRID: Unified tap - writes to BOTH speech recognizer AND audio file
        // RATIONALE: Installing a single tap avoids "double recording" conflicts where
        // multiple nodes try to pull from the hardware input. This ensures:
        // 1. Synchronization: The AI hears exactly what is saved to disk.
        // 2. Stability: No fighting for hardware resources.
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            
            // 1. Send to Speech Recognizer (Real-time transcription)
            self.recognitionRequest?.append(buffer)
            
            // 2. Write to Audio File (Permanent storage)
            // Note: We use the *buffer's* format settings to match the hardware exactly.
            do {
                if self.audioFile == nil {
                    let filename = self.currentAudioFilename ?? self.generateAudioFilename()
                    self.currentAudioFilename = filename
                    let url = self.getDocumentsDirectory().appendingPathComponent(filename)
                    
                    // Initialize file using incoming buffer format to prevent sample rate mismatch
                    self.audioFile = try AVAudioFile(forWriting: url, settings: buffer.format.settings)
                }
                try self.audioFile?.write(from: buffer)
            } catch {
                print("❌ Error writing audio: \(error)")
            }
        }
        isAudioTapInstalled = true
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("❌ Audio Engine failed to start: \(error.localizedDescription)")
            self.summary = "Hardware error: Could not start microphone"
            self.isRecording = false
            return
        }
        triggerHaptic(style: .heavy)
    }
    
    func stopRecording() {
        isRecording = false
        isProcessing = true // 🔒 Lock UI
        
        // 🔥 HYBRID: Close the audio file
        audioFile = nil
        
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        if isAudioTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            isAudioTapInstalled = false
        }
        
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        triggerNotificationHaptic(type: .success)
        
        Task {
            // Check if filename exists
            guard let filename = currentAudioFilename else {
                await MainActor.run { isProcessing = false } // 🔓 Unlock if error
                return
            }
            
            let fileURL = getDocumentsDirectory().appendingPathComponent(filename)
            
            if FileManager.default.fileExists(atPath: fileURL.path) {
                // File exists, proceed with compression
                if let m4aFilename = await compressAudio(wavFilename: filename) {
                    currentAudioFilename = m4aFilename
                }
                await analyze() // This saves to context
            } else {
                print("⚠️ No audio file captured (Microphone permission missing?)")
                await MainActor.run {
                    self.summary = "Recording failed: No audio captured."
                }
            }
            
            // 🔓 Unlock UI when EVERYTHING is done
            await MainActor.run {
                self.isProcessing = false
            }
        }
    }
    
    // 🔥 HYBRID: Compress WAV to M4A for storage efficiency
    private func compressAudio(wavFilename: String) async -> String? {
        let sourceURL = getDocumentsDirectory().appendingPathComponent(wavFilename)
        let m4aFilename = wavFilename.replacingOccurrences(of: ".wav", with: ".m4a")
        let destURL = getDocumentsDirectory().appendingPathComponent(m4aFilename)
        
        // Check if source exists
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            print("❌ WAV file not found: \(sourceURL)")
            return nil
        }
        
        let asset = AVAsset(url: sourceURL)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            print("❌ Could not create export session")
            return nil
        }
        
        exportSession.outputURL = destURL
        exportSession.outputFileType = .m4a
        
        await exportSession.export()
        
        if exportSession.status == .completed {
            print("✅ Compressed audio: \(wavFilename) → \(m4aFilename)")
            // Delete the large WAV file
            try? FileManager.default.removeItem(at: sourceURL)
            return m4aFilename
        } else {
            print("❌ Compression failed: \(exportSession.error?.localizedDescription ?? "unknown")")
            // Keep the WAV as fallback
            return wavFilename
        }
    }
    
    // MARK: - Analysis
    func analyze() async {
        let text = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { 
            if let filename = currentAudioFilename {
                let fileURL = getDocumentsDirectory().appendingPathComponent(filename)
                try? FileManager.default.removeItem(at: fileURL)
            }
            currentAudioFilename = nil
            return 
        }
        
        do {
            // 🔥 OPTIMIZATION: Use user-selected language instead of asking AI to detect it
            let targetLanguageName = Locale(identifier: currentLanguageCode).localizedString(forLanguageCode: currentLanguageCode) ?? currentLanguageCode
            
            // 🔥 LANGUAGE: Pass selected language for localized analysis
            let analysis = try await GeminiAnalysisService.shared.analyze(text, languageCode: currentLanguageCode)
            
            // Robust date parsing - try multiple formats
            var extractedDate: Date? = nil
            if let dateString = analysis.extractedDate {
                let formatter = ISO8601DateFormatter()
                
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
                
                // Fallback for non-ISO formats
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
                detectedLanguage: targetLanguageName, // 🔥 Use selected language name
                noteType: type,
                audioFilename: currentAudioFilename,
                analysisStatus: .completed
            )
            
            ctx.insert(note)
            try? ctx.save()
            currentAudioFilename = nil
            
            requestReviewIfAppropriate()

        } catch let error as GeminiError {
            print("⚠️ Gemini failure:", error)
            self.summary = error.localizedDescription
            saveFailedNote(text: text, error: error.localizedDescription)
            triggerNotificationHaptic(type: .error) 
    
        } catch {
            print("⚠️ Unknown error:", error)
            self.summary = "Error during analysis"
            saveFailedNote(text: text, error: "Error during analysis")
            triggerNotificationHaptic(type: .error)
        }
    }
    
    // Save note with failed status (for retry later)
    private func saveFailedNote(text: String, error: String) {
        guard let ctx = modelContext else { return }
        
        let note = VoiceNote(
            transcript: text,
            summary: "⚠️ Analysis failed: \(error)",
            audioFilename: currentAudioFilename,
            analysisStatus: .failed
        )
        
        ctx.insert(note)
        try? ctx.save()
        currentAudioFilename = nil
    }

    func detectLanguage(_ text: String) async throws -> String {
        let system = "Detect the language. Reply only with the language name."
        return try await GeminiService.shared.sendPrompt("Text:\n\(text)", systemInstruction: system)
    }
    
    // App Review Request
    private func requestReviewIfAppropriate() {
        let noteCountKey = "successfulNoteCount"
        let hasRequestedKey = "hasRequestedReview"
        
        guard !UserDefaults.standard.bool(forKey: hasRequestedKey) else { return }
        
        let count = UserDefaults.standard.integer(forKey: noteCountKey) + 1
        UserDefaults.standard.set(count, forKey: noteCountKey)
        
        if count == 3 {
            UserDefaults.standard.set(true, forKey: hasRequestedKey)
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                SKStoreReviewController.requestReview(in: windowScene)
            }
        }
    }
}