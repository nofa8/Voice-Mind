import SwiftUI
import SwiftData

struct AgendaView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \VoiceNote.createdAt, order: .reverse)
    private var notes: [VoiceNote]

    var body: some View {
        List {
            ForEach(groupedByDay(), id: \.key) { section in
                Section(header: Text(section.key)) {
                    ForEach(section.value) { note in
                        NavigationLink(value: note) {
                            NoteRow(note: note)
                        }
                    }
                    .onDelete { offsets in
                        deleteNotes(offsets: offsets, in: section.value)
                    }
                }
            }
        }
        .navigationTitle("Agenda")
        .navigationDestination(for: VoiceNote.self) { note in
            VoiceNoteDetailView(note: note)
        }
    }

    private func groupedByDay() -> [(key: String, value: [VoiceNote])] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        let grouped = Dictionary(grouping: notes) { (note: VoiceNote) -> Date in
            calendar.startOfDay(for: note.createdAt)
        }

        return grouped
            .map { (key: $0.key, value: $0.value) }
            .sorted { $0.key > $1.key }
            .map { (key: formatter.string(from: $0.key), value: $0.value) }
    }

    private func deleteNotes(offsets: IndexSet, in notesInSection: [VoiceNote]) {
        // offsets refer to positions inside the section's array
        for index in offsets {
            let note = notesInSection[index]
            context.delete(note)
        }
        try? context.save()
    }
}
