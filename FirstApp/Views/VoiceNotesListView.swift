// VoiceNotesListView.swift
import SwiftUI
import SwiftData

// Filter options for note types
enum NoteFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case notes = "Notes"
    case tasks = "Tasks"
    case events = "Events"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .all: return "tray.fill"
        case .notes: return "doc.text.fill"
        case .tasks: return "checklist"
        case .events: return "calendar"
        }
    }
}

struct VoiceNotesListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \VoiceNote.createdAt, order: .reverse) private var notes: [VoiceNote]
    
    // State to control the presentation of the recording view
    @State private var isShowingRecorder = false
    
    // 🔥 NEW: Filter state
    @State private var selectedFilter: NoteFilter = .all

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea() // Apply global background
                
                VStack(spacing: 0) {
                    // 🔥 NEW: Filter control
                    filterControl
                        .padding(.horizontal)
                        .padding(.top, 8)
                    
                    if filteredNotes.isEmpty {
                        ContentUnavailableView(
                            emptyStateTitle,
                            systemImage: emptyStateIcon,
                            description: Text(emptyStateDescription)
                        )
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredNotes) { note in
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
                MainView().modelContext(context)
            }
        }
    }
    
    // MARK: - Filter Control UI
    private var filterControl: some View {
        VStack(spacing: 12) {
            Picker("Filter", selection: $selectedFilter) {
                ForEach(NoteFilter.allCases) { filter in
                    HStack {
                        Image(systemName: filter.icon)
                        Text(filter.rawValue)
                        if let count = filterCount(for: filter), count > 0 {
                            Text("(\(count))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(filter)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, 8)
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
    }
    
    // MARK: - Filtering Logic
    private var filteredNotes: [VoiceNote] {
        switch selectedFilter {
        case .all:
            return notes
        case .notes:
            return notes.filter { $0.noteType == .note }
        case .tasks:
            return notes.filter { $0.noteType == .task }
        case .events:
            return notes.filter { $0.noteType == .event }
        }
    }
    
    private func filterCount(for filter: NoteFilter) -> Int? {
        switch filter {
        case .all:
            return notes.count
        case .notes:
            return notes.filter { $0.noteType == .note }.count
        case .tasks:
            return notes.filter { $0.noteType == .task }.count
        case .events:
            return notes.filter { $0.noteType == .event }.count
        }
    }
    
    // MARK: - Empty State
    private var emptyStateTitle: String {
        switch selectedFilter {
        case .all: return "No Voice Notes"
        case .notes: return "No Notes"
        case .tasks: return "No Tasks"
        case .events: return "No Events"
        }
    }
    
    private var emptyStateIcon: String {
        switch selectedFilter {
        case .all: return "mic.slash"
        case .notes: return "doc.text"
        case .tasks: return "checklist"
        case .events: return "calendar"
        }
    }
    
    private var emptyStateDescription: String {
        switch selectedFilter {
        case .all: return "Tap the + button to record your first thought."
        case .notes: return "No standard notes yet. Record your thoughts!"
        case .tasks: return "No tasks found. Create actionable items!"
        case .events: return "No events scheduled. Record upcoming plans!"
        }
    }

    private func deleteNotes(at offsets: IndexSet) {
        for index in offsets {
            context.delete(notes[index])
        }
        try? context.save()
    }
}