import Foundation
import AVFoundation
import Speech

@MainActor
class VoiceRecorderViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var transcription = ""
    @Published var summary = ""
    @Published var sentiment = ""
    @Published var keywords: [String] = []
    @Published var translation = ""
    @Published var targetLanguage = "English"
    
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
    
    // MARK: - Recording
    func startRecording() {
        transcription = "Olá tudo bem, como vai tudo por aí na Gronelandia"
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
            let analysis = try await GeminiAnalysisService.shared.analyze(text)
            self.summary = analysis.summary
            self.sentiment = analysis.sentiment
            self.keywords = analysis.keywords
            
            self.translation = try await GeminiTranslationService.shared.translate(
                analysis.summary,
                to: targetLanguage
            )
        } catch {
            print("⚠️ Gemini pipeline failed: \(error)")
            self.summary = "Error during analysis"
            self.translation = "Translation failed"
        }
    }
}
