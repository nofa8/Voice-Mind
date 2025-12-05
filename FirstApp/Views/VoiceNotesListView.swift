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
    @State private var searchText = ""  // 🔥 Search state

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Filter buttons
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
                    
                    if displayedNotes.isEmpty {
                        ContentUnavailableView(
                            emptyStateTitle,
                            systemImage: emptyStateIcon,
                            description: Text(emptyStateDescription)
                        )
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(displayedNotes) { note in
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
            .searchable(text: $searchText, prompt: "Search notes...")  // 🔥 Search bar
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
    
    // MARK: - Search + Filter Logic
    
    // First apply type filter
    private var filteredNotes: [VoiceNote] {
        switch selectedFilter {
        case .all: return notes
        case .notes: return notes.filter { $0.noteType == .note }
        case .tasks: return notes.filter { $0.noteType == .task }
        case .events: return notes.filter { $0.noteType == .event }
        }
    }
    
    // Then apply search on top of filter
    private var displayedNotes: [VoiceNote] {
        guard !searchText.isEmpty else { return filteredNotes }
        
        let query = searchText.lowercased()
        return filteredNotes.filter { note in
            // Search in transcript
            if note.transcript.lowercased().contains(query) { return true }
            
            // Search in summary
            if let summary = note.summary, summary.lowercased().contains(query) { return true }
            
            // Search in keywords
            if let keywords = note.keywords {
                for keyword in keywords {
                    if keyword.lowercased().contains(query) { return true }
                }
            }
            
            // Search in location
            if let location = note.eventLocation, location.lowercased().contains(query) { return true }
            
            // Search in category
            if let category = note.category, category.lowercased().contains(query) { return true }
            
            return false
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
        if !searchText.isEmpty {
            return "No Results"
        }
        switch selectedFilter {
        case .all: return "No Items"
        case .notes: return "No Notes"
        case .tasks: return "No Tasks"
        case .events: return "No Events"
        }
    }
    
    private var emptyStateIcon: String {
        if !searchText.isEmpty {
            return "magnifyingglass"
        }
        switch selectedFilter {
        case .all: return "tray"
        case .notes: return "doc.text"
        case .tasks: return "checklist"
        case .events: return "calendar"
        }
    }
    
    private var emptyStateDescription: String {
        if !searchText.isEmpty {
            return "No items match '\(searchText)'"
        }
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