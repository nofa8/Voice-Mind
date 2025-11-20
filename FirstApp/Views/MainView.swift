// MainView.swift
import SwiftUI

struct MainView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss // Allows closing the sheet
    
    @StateObject private var recorder = VoiceRecorderViewModel()
    
    let languages = ["English", "Portuguese", "Spanish", "French", "German", "Italian"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                VStack(spacing: 30) {
                    
                    // 1. Dynamic Header
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
                    
                    // 2. Live Transcript Card
                    ScrollView {
                        Text(recorder.transcription.isEmpty ? "Your speech will appear here..." : recorder.transcription)
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
                    
                    // 3. Language Picker
                    HStack {
                        Text("Translate Summary:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Picker("", selection: $recorder.targetLanguage) {
                            ForEach(languages, id: \.self) { lang in
                                Text(lang)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Theme.primary)
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
                            // Optional: Add a small delay or wait for processing before dismissing
                            // For now, we let the user close manually or you can trigger dismiss inside ViewModel events
                        } else {
                            recorder.startRecording()
                        }
                    } label: {
                        Text(recorder.isRecording ? "Stop & Analyze" : "Start Recording")
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
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                await recorder.requestPermissions()
            }
            .onAppear {
                recorder.setContext(context)
            }
        }
    }
}