import SwiftUI

struct MainView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recorder = VoiceRecorderViewModel()

    let languages = ["English", "Portuguese", "Spanish", "French", "German", "Italian"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(spacing: 10) {
                    Image(systemName: recorder.isRecording ? "waveform.circle.fill" : "mic.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .foregroundStyle(recorder.isRecording ? Color.red : Theme.primary)

                    Text(recorder.isRecording ? "Listening..." : "Tap to Record")
                        .font(.headline)
                }
                .padding(.top)

                ScrollView {
                    Text(recorder.transcription.isEmpty ? "🎤 Your transcription will appear here..." : recorder.transcription)
                        .padding()
                        .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
                        .background(Theme.cardBackground)
                        .cornerRadius(Theme.cornerRadius)
                        .padding(.horizontal)
                }

                Picker("Translate Summary To:", selection: $recorder.targetLanguage) {
                    ForEach(languages, id: \.self) { lang in
                        Text(lang)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal)

                DatePicker("Date & Time", selection: $recorder.scheduledDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .padding(.horizontal)

                Spacer()

                Button {
                    if recorder.isRecording {
                        recorder.stopRecording()
                        // dismiss after a short delay to allow processing if desired
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            dismiss()
                        }
                    } else {
                        recorder.startRecording()
                    }
                } label: {
                    Text(recorder.isRecording ? "Stop & Save" : "Start Recording")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(recorder.isRecording ? Color.red : Theme.primary)
                        .cornerRadius(Theme.cornerRadius)
                        .padding(.horizontal)
                }
                .padding(.bottom)
            }
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
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
