import SwiftUI

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
    @Environment(\.colorScheme) private var colorScheme
    
    var showCancelButton: Bool = false
    
    @StateObject private var recorder = VoiceRecorderViewModel()
    @State private var selectedLanguage: AppLanguage = .englishUS
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Adaptive gradient background
                LinearGradient(
                    colors: colorScheme == .dark 
                        ? [Theme.background, Theme.background]
                        : [Theme.background, Theme.primary.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    
                    // 1. Header with enhanced visual feedback
                    VStack(spacing: 16) {
                        ZStack {
                            // Pulse ring effect when recording
                            if recorder.isRecording {
                                Circle()
                                    .stroke(Color.red.opacity(0.3), lineWidth: 3)
                                    .scaleEffect(recorder.isRecording ? 1.3 : 1.0)
                                    .opacity(recorder.isRecording ? 0 : 1)
                                    .animation(
                                        .easeOut(duration: 1.5).repeatForever(autoreverses: false),
                                        value: recorder.isRecording
                                    )
                                    .frame(width: 100, height: 100)
                            }
                            
                            Image(systemName: recorder.isRecording ? "waveform.circle.fill" : "mic.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .foregroundStyle(
                                    recorder.isRecording 
                                        ? Color.red 
                                        : Theme.primary
                                )
                                .symbolEffect(.pulse, isActive: recorder.isRecording)
                                .symbolRenderingMode(.hierarchical)
                        }
                        
                        VStack(spacing: 4) {
                            Text(recorder.isRecording ? "Listening..." : "Tap to Record")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(Theme.textPrimary)
                            
                            if recorder.isRecording {
                                Text("Recording in progress")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                    .padding(.top, 40)
                    
                    // 2. Transcript area with enhanced styling
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "text.bubble")
                                .foregroundStyle(Theme.primary)
                            Text("Transcription")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .padding(.horizontal, Theme.padding)
                        
                        ScrollView {
                            Text(recorder.transcription.isEmpty 
                                ? "Say something like 'Lunch with John tomorrow at 2pm'..." 
                                : recorder.transcription)
                                .font(.body)
                                .foregroundStyle(recorder.transcription.isEmpty ? Theme.textTertiary : Theme.textPrimary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 180)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                .fill(Theme.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                        .stroke(
                                            recorder.isRecording ? Theme.primary.opacity(0.3) : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                        )
                        .adaptiveBorder()
                        .cardShadow()
                    }
                    .padding(.horizontal)
                    
                    // 3. Language Selector with enhanced design
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundStyle(Theme.primary)
                            Text("Speaking Language")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        
                        Picker("Language", selection: $selectedLanguage) {
                            ForEach(AppLanguage.allCases) { lang in
                                Text(lang.displayName).tag(lang)
                            }
                        }
                        .pickerStyle(.segmented)
                        .disabled(recorder.isRecording)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: Theme.cornerRadius)
                            .fill(Theme.cardBackground)
                    )
                    .adaptiveBorder()
                    .cardShadow()
                    .padding(.horizontal)

                    Spacer()
                    
                    // 4. Enhanced Action Button
                    Button {
                        if recorder.isRecording {
                            recorder.stopRecording()
                        } else {
                            recorder.startRecording(language: selectedLanguage.rawValue)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .font(.title3)
                            
                            Text(recorder.isRecording ? "Stop & AI Process" : "Start Recording")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                .fill(
                                    LinearGradient(
                                        colors: recorder.isRecording 
                                            ? [Color.red, Color.red.opacity(0.8)]
                                            : [Theme.primary, Theme.primary.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                        .shadow(
                            color: (recorder.isRecording ? Color.red : Theme.primary).opacity(0.3),
                            radius: 8,
                            y: 4
                        )
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