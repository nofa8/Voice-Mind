import SwiftUI
import SwiftData

struct AgendaView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \VoiceNote.eventDate, order: .reverse)
    private var notes: [VoiceNote]
    
    @State private var timeFrame: TimeFrame = .day

    enum TimeFrame: String, CaseIterable {
        case day = "Day"
        case week = "Week"
        case month = "Month"
    }

    var body: some View {
        VStack {
            Picker("Time Frame", selection: $timeFrame) {
                ForEach(TimeFrame.allCases, id: \.self) { frame in
                    Text(frame.rawValue).tag(frame)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            List {
                ForEach(groupedNotes(), id: \.key) { section in
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
        }
        .navigationTitle("History")
        .navigationDestination(for: VoiceNote.self) { note in
            VoiceNoteDetailView(note: note)
        }
    }

    private func groupedNotes() -> [(key: String, value: [VoiceNote])] {
        let calendar = Calendar.current
        let formatter = DateFormatter()

        let grouped: [Date: [VoiceNote]]
        
        switch timeFrame {
        case .day:
            formatter.dateStyle = .medium
            grouped = Dictionary(grouping: notes) { note in
                calendar.startOfDay(for: note.eventDate)
            }
        case .week:
            formatter.dateFormat = "'Week of' MMM d"
            grouped = Dictionary(grouping: notes) { note in
                calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: note.eventDate).date!
            }
        case .month:
            formatter.dateFormat = "MMMM yyyy"
            grouped = Dictionary(grouping: notes) { note in
                calendar.dateComponents([.year, .month], from: note.eventDate).date!
            }
        }

        return grouped
            .map { (key: $0.key, value: $0.value) }
            .sorted { $0.key > $1.key }
            .map { (key: formatter.string(from: $0.key), value: $0.value) }
    }

    private func deleteNotes(offsets: IndexSet, in notesInSection: [VoiceNote]) {
        for index in offsets {
            let note = notesInSection[index]
            context.delete(note)
        }
        try? context.save()
    }
}
