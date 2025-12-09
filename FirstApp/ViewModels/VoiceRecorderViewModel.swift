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
        
        // 🔥 HYBRID: Generate filename but don't create file yet
        let filename = generateAudioFilename()
        currentAudioFilename = filename
        
        // Speech Recognition Setup
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
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
        
        // 🔥 HYBRID: Unified tap - writes to BOTH speech recognizer AND audio file
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            
            // 1. Send to Speech Recognizer
            self.recognitionRequest?.append(buffer)
            
            // 2. Write to Audio File (same data = no conflicts!)
            do {
                if self.audioFile == nil {
                    let filename = self.currentAudioFilename ?? self.generateAudioFilename()
                    self.currentAudioFilename = filename
                    let url = self.getDocumentsDirectory().appendingPathComponent(filename)
                    // Write as WAV (native format) - will compress to M4A after
                    self.audioFile = try AVAudioFile(forWriting: url, settings: recordingFormat.settings)
                }
                try self.audioFile?.write(from: buffer)
            } catch {
                print("❌ Error writing audio: \(error)")
            }
        }
        isAudioTapInstalled = true
        
        audioEngine.prepare()
        try? audioEngine.start()
        
        triggerHaptic(style: .heavy)
    }
    
    func stopRecording() {
        isRecording = false
        
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
        
        // 🔥 HYBRID: Compress WAV to M4A, then analyze
        Task {
            if let wavFilename = currentAudioFilename {
                // Compress to M4A (smaller file size)
                if let m4aFilename = await compressAudio(wavFilename: wavFilename) {
                    currentAudioFilename = m4aFilename
                }
            }
            await analyze()
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
            let detectedLang = try await detectLanguage(text)
            let analysis = try await GeminiAnalysisService.shared.analyze(text)
            
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
                detectedLanguage: detectedLang,
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