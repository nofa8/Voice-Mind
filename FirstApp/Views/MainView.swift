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
    
    // Control whether Cancel button appears (true when presented as sheet)
    var showCancelButton: Bool = false
    
    @StateObject private var recorder = VoiceRecorderViewModel()
    @State private var selectedLanguage: AppLanguage = .englishUS // Default
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                VStack(spacing: 30) {
                    
                    // 1. Header
                    VStack(spacing: 10) {
                        Image(systemName: recorder.isRecording ? "waveform.circle.fill" : "mic.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .foregroundStyle(recorder.isRecording ? Color.red : Theme.primary)
                            .symbolEffect(.pulse, isActive: recorder.isRecording)
                        
                        Text(recorder.isRecording ? "Listening..." : "Tap to Record")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    .padding(.top, 40)
                    
                    // 2. Transcript
                    ScrollView {
                        Text(recorder.transcription.isEmpty ? "Say something like 'Lunch with John tomorrow at 2pm'..." : recorder.transcription)
                            .font(.body)
                            .foregroundStyle(recorder.transcription.isEmpty ? .gray : .primary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 200)
                    .background(Theme.cardBackground)
                    .cornerRadius(Theme.cornerRadius)
                    .shadow(color: .black.opacity(0.05), radius: 5)
                    .padding(.horizontal)
                    
                    // 3. Language Selector (Replaces Manual Type Selector)
                    VStack(spacing: 12) {
                        Text("Speaking Language")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                        
                        Picker("Language", selection: $selectedLanguage) {
                            ForEach(AppLanguage.allCases) { lang in
                                Text(lang.displayName).tag(lang)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding()
                    .background(Theme.cardBackground)
                    .cornerRadius(Theme.cornerRadius)
                    .padding(.horizontal)

                    Spacer()
                    
                    // 4. Action Button
                    Button {
                        if recorder.isRecording {
                            recorder.stopRecording()
                        } else {
                            // Pass selected language to the engine
                            recorder.startRecording(language: selectedLanguage.rawValue)
                        }
                    } label: {
                        Text(recorder.isRecording ? "Stop & AI Process" : "Start Recording")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(recorder.isRecording ? Color.red : Theme.primary)
                            .cornerRadius(Theme.cornerRadius)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("AI Note")
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