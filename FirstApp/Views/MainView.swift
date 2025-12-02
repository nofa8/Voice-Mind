import SwiftUI

struct MainView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var recorder = VoiceRecorderViewModel()
    
    // Local state for view controls (will be connected to ViewModel in next step)
    @State private var noteType: NoteType = .note
    @State private var eventDate: Date = Date()
    @State private var showPastDateAlert = false
    
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
                    
                    // 3. Date & Type Selector (Replaces Translation)
                    VStack(spacing: 16) {
                        // Type Picker
                        Picker("Type", selection: $noteType) {
                            ForEach(NoteType.allCases, id: \.self) { type in
                                Text(type.rawValue.capitalized).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: noteType) { oldValue, newValue in
                            // Logic: Prevent Agenda selection if date is in the past
                            if newValue == .agenda && eventDate < Date() {
                                noteType = .note // Revert change
                                showPastDateAlert = true
                            }
                        }
                        
                        Divider()
                        
                        // Date Picker
                        HStack {
                            Label(noteType == .agenda ? "Event Time" : "Timestamp", systemImage: "calendar")
                                .foregroundStyle(Theme.textSecondary)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            DatePicker(
                                "",
                                selection: $eventDate,
                                in: datePickerRange // Constrains selector based on type
                            )
                            .labelsHidden()
                        }
                    }
                    .padding()
                    .background(Theme.cardBackground)
                    .cornerRadius(Theme.cornerRadius)
                    .padding(.horizontal)

                    Spacer()
                    
                    // 4. Action Button
                    Button {
                        // In MainView.swift action button:
                        if recorder.isRecording {
                            // 👇 UPDATE THIS LINE
                            recorder.stopRecording(noteType: noteType, eventDate: eventDate)
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
            // Alert for invalid Agenda selection
            .alert("Invalid Selection", isPresented: $showPastDateAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Only notes are enabled for past events.")
            }
            .task {
                await recorder.requestPermissions()
            }
            .onAppear {
                recorder.setContext(context)
            }
        }
    }
    
    // Helper to restrict DatePicker range
    var datePickerRange: PartialRangeFrom<Date> {
        if noteType == .agenda {
            return Date()... // Agenda must be Future
        } else {
            return Date.distantPast... // Notes can be Past or Future
        }
    }
}