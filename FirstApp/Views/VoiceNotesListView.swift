import SwiftUI
import SwiftData

struct VoiceNotesListView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \VoiceNote.createdAt, order: .reverse)
    private var notes: [VoiceNote]

    var body: some View {
        NavigationStack {
            List {
                ForEach(notes) { note in
                    NavigationLink(value: note) {
                        NoteRow(note: note)
                    }
                }
                .onDelete(perform: deleteNotes)
            }
            .navigationTitle("Voice Notes")
            .navigationDestination(for: VoiceNote.self) { note in
                VoiceNoteDetailView(note: note)
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
