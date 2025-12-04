// VoiceNotesListView.swift
import SwiftUI
import SwiftData

// Simplified filter options
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
    
    @State private var isShowingRecorder = false
    @State private var selectedFilter: NoteFilter = .all

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 🔥 Simplified Filter - Just icons with counts
                    HStack(spacing: 16) {
                        ForEach(NoteFilter.allCases) { filter in
                            FilterButton(
                                filter: filter,
                                count: filterCount(for: filter),
                                isSelected: selectedFilter == filter
                            ) {
                                selectedFilter = filter
                            }
                        }
                    }
                    .padding()
                    .background(Theme.cardBackground)
                    
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
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Library")
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
            .sheet(isPresented: $isShowingRecorder) {
                MainView().modelContext(context)
            }
        }
    }
    
    // MARK: - Filtering Logic
    private var filteredNotes: [VoiceNote] {
        switch selectedFilter {
        case .all: return notes
        case .notes: return notes.filter { $0.noteType == .note }
        case .tasks: return notes.filter { $0.noteType == .task }
        case .events: return notes.filter { $0.noteType == .event }
        }
    }
    
    private func filterCount(for filter: NoteFilter) -> Int {
        switch filter {
        case .all: return notes.count
        case .notes: return notes.filter { $0.noteType == .note }.count
        case .tasks: return notes.filter { $0.noteType == .task }.count
        case .events: return notes.filter { $0.noteType == .event }.count
        }
    }
    
    // MARK: - Empty State
    private var emptyStateTitle: String {
        switch selectedFilter {
        case .all: return "No Items"
        case .notes: return "No Notes"
        case .tasks: return "No Tasks"
        case .events: return "No Events"
        }
    }
    
    private var emptyStateIcon: String {
        switch selectedFilter {
        case .all: return "tray"
        case .notes: return "doc.text"
        case .tasks: return "checklist"
        case .events: return "calendar"
        }
    }
    
    private var emptyStateDescription: String {
        switch selectedFilter {
        case .all: return "Tap + to record your first item."
        case .notes: return "No notes yet."
        case .tasks: return "No tasks found."
        case .events: return "No events scheduled."
        }
    }

    private func deleteNotes(at offsets: IndexSet) {
        for index in offsets {
            context.delete(notes[index])
        }
        try? context.save()
    }
}

// MARK: - Filter Button Component
struct FilterButton: View {
    let filter: NoteFilter
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: filter.icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : iconColor)
                
                Text(filter.rawValue)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? .white : .primary)
                
                Text("\(count)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? iconColor : Color.clear)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    private var iconColor: Color {
        switch filter {
        case .all: return Theme.primary
        case .notes: return .orange
        case .tasks: return .green
        case .events: return .blue
        }
    }
}