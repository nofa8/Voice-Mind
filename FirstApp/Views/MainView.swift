// FirstApp/Views/MainView.swift
import SwiftUI

// Define supported languages
enum AppLanguage: String, CaseIterable, Identifiable {
    case englishUS = "en-US"
    case portuguese = "pt-PT"
    case spanish = "es-ES"
    case french = "fr-FR"
    case german = "de-DE"
    
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .englishUS: return "🇺🇸 USA"
        case .portuguese: return "🇵🇹 PT"
        case .spanish: return "🇪🇸 ES"
        case .french: return "🇫🇷 FR"
        case .german: return "🇩🇪 DE"
        }
    }
}


struct MainView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var networkMonitor: NetworkMonitor // 🔥 New dependency
    
    var showCancelButton: Bool = false
    @StateObject private var recorder = VoiceRecorderViewModel()
    @State private var selectedLanguage: AppLanguage = .englishUS
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                VStack(spacing: 30) {
                    
                    // 1. Dynamic Header
                    VStack(spacing: 15) {
                        ZStack {
                            Circle()
                                .fill(recorder.isRecording ? Theme.recordingGradient : Theme.primaryGradient)
                                .frame(width: 100, height: 100)
                                .opacity(0.2)
                                .symbolEffect(.pulse, isActive: recorder.isRecording) // iOS 17 Animation
                            
                            Image(systemName: recorder.isRecording ? "waveform" : "mic.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(recorder.isRecording ? .red : Theme.primary)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        
                        Text(recorder.isRecording ? "Listening..." : "Tap to Record")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .padding(.top, 40)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(recorder.isRecording ? "Recording in progress" : "Ready to record")
                    
                    // 2. Transcript Card
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            if recorder.transcription.isEmpty {
                                HStack {
                                    Image(systemName: "sparkles")
                                        .foregroundStyle(.yellow)
                                    Text("Try saying:")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                Text("\"Lunch with John tomorrow at 2 PM\"")
                                    .font(.body)
                                    .italic()
                                    .foregroundStyle(Theme.textTertiary)
                            } else {
                                Text(recorder.transcription)
                                    .font(.body)
                                    .foregroundStyle(Theme.textPrimary)
                                    .animation(.default, value: recorder.transcription)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 200)
                    .adaptiveCardStyle()
                    .padding(.horizontal)
                    
                    // 3. Language Selector
                    VStack(spacing: 8) {
                        Text("Speaking Language")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(Theme.textSecondary)
                            .textCase(.uppercase)
                        
                        Picker("Language", selection: $selectedLanguage) {
                            ForEach(AppLanguage.allCases) { lang in
                                Text(lang.displayName).tag(lang)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding()
                    .adaptiveCardStyle()
                    .padding(.horizontal)

                    Spacer()
                    
                    // 4. Offline Warning
                    if !networkMonitor.isConnected {
                        HStack {
                            Image(systemName: "wifi.slash")
                            Text("Offline Mode: Analysis unavailable")
                        }
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.bottom, 8)
                    }
                    
                    // 5. Action Button
                    Button {
                        if recorder.isRecording {
                            recorder.stopRecording()
                        } else {
                            recorder.startRecording(language: selectedLanguage.rawValue)
                        }
                    } label: {
                        HStack {
                            Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                            Text(recorder.isRecording ? "Stop & Process" : "Start Recording")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            recorder.isRecording ? Theme.recordingGradient : Theme.primaryGradient
                        )
                        .cornerRadius(Theme.cornerRadius)
                        .shadow(color: recorder.isRecording ? .red.opacity(0.3) : .blue.opacity(0.3), radius: 10, y: 5)
                    }
                    .disabled(!networkMonitor.isConnected && !recorder.isRecording)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                    .accessibilityLabel(recorder.isRecording ? "Stop Recording" : "Start Recording")
                    .accessibilityHint(recorder.isRecording ? "Ends recording and starts AI analysis" : "Starts listening")
                }
            }
            .navigationTitle("Voice Mind")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showCancelButton {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
            .task { await recorder.requestPermissions() }
            .onAppear { recorder.setContext(context) }
        }
    }
}