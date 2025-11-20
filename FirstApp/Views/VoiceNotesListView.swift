// VoiceNotesListView.swift
import SwiftUI
import SwiftData

struct VoiceNotesListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \VoiceNote.createdAt, order: .reverse) private var notes: [VoiceNote]
    
    // State to control the presentation of the recording view
    @State private var isShowingRecorder = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea() // Apply global background
                
                if notes.isEmpty {
                    ContentUnavailableView(
                        "No Voice Notes",
                        systemImage: "mic.slash",
                        description: Text("Tap the + button to record your first thought.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(notes) { note in
                                NavigationLink(value: note) {
                                    NoteRow(note: note)
                                }
                                .buttonStyle(PlainButtonStyle()) // Removes default blue link color
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("VoiceMind")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isShowingRecorder = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Theme.primary)
                    }
                }
            }
            .navigationDestination(for: VoiceNote.self) { note in
                VoiceNoteDetailView(note: note)
            }
            // Present MainView as a sheet
            .sheet(isPresented: $isShowingRecorder) {
                MainView()
            }
        }
    }

    private func deleteNotes(at offsets: IndexSet) {
        for index in offsets {
            context.delete(notes[index])
        }
        try? context.save()
    }
}