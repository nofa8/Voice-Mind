import SwiftUI

struct MainView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var recorder = VoiceRecorderViewModel()
    
    let languages = ["English", "Portuguese", "Spanish", "French", "German", "Italian"]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text(recorder.transcription.isEmpty ? "🎤 Your transcription will appear here..." : recorder.transcription)
                        .padding()
                        .frame(maxWidth: .infinity, minHeight: 150)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    
                    Picker("Translate Summary To:", selection: $recorder.targetLanguage) {
                        ForEach(languages, id: \.self) { lang in
                            Text(lang)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal)
                    
                    if !recorder.summary.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("🧠 Summary: **\(recorder.summary)**")
                            Text("💬 Sentiment: **\(recorder.sentiment)**")
                            Text("🏷️ Keywords: **\(recorder.keywords.joined(separator: ", "))**")
                            
                            if !recorder.translation.isEmpty {
                                Divider()
                                Text("🌍 Translated (\(recorder.targetLanguage)): **\(recorder.translation)**")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                    
                    Button {
                        recorder.isRecording ? recorder.stopRecording() : recorder.startRecording()
                    } label: {
                        Label(
                            recorder.isRecording ? "Stop Recording" : "Start Recording",
                            systemImage: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill"
                        )
                        .font(.title)
                        .foregroundStyle(recorder.isRecording ? .red : .blue)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.vertical)
            }
            .navigationTitle("VoiceMind 🌐")
            .task {
                await recorder.requestPermissions()
            }
        }
        .onAppear {
            recorder.setContext(context)
        }
        
    }
}
