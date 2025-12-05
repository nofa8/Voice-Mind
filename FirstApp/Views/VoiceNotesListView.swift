// VoiceNotesListView.swift
import SwiftUI
import SwiftData

// Type filter options
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
    @State private var searchText = ""
    
    // 🔥 Advanced filters
    @State private var showFilterSheet = false
    @StateObject private var filterState = FilterState()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Type filter buttons
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
                    
                    // 🔥 Active filters indicator
                    if filterState.hasActiveFilters {
                        activeFiltersBar
                    }
                    
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
            .searchable(text: $searchText, prompt: "Search notes...")
            .toolbar {
                // 🔥 Filter button
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showFilterSheet = true }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.system(size: 22))
                                .foregroundStyle(filterState.hasActiveFilters ? Theme.primary : .gray)
                            
                            if filterState.activeFilterCount > 0 {
                                Text("\(filterState.activeFilterCount)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .frame(width: 16, height: 16)
                                    .background(Theme.primary)
                                    .clipShape(Circle())
                                    .offset(x: 8, y: -4)
                            }
                        }
                    }
                }
                
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
            .sheet(isPresented: $showFilterSheet) {
                FilterSheetView(
                    filterState: filterState,
                    availableKeywords: allKeywords
                )
                .presentationDetents([.medium, .large])
            }
        }
    }
    
    // 🔥 Active filters indicator bar
    private var activeFiltersBar: some View {
        HStack {
            Image(systemName: "line.3.horizontal.decrease")
                .foregroundStyle(Theme.primary)
            
            Text("\(filterState.activeFilterCount) filter\(filterState.activeFilterCount == 1 ? "" : "s") active")
                .font(.caption)
                .foregroundStyle(Theme.primary)
            
            Spacer()
            
            Button("Clear") {
                filterState.clearAll()
            }
            .font(.caption)
            .foregroundStyle(.red)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Theme.primary.opacity(0.1))
    }
    
    // MARK: - Available Keywords (from all notes)
    private var allKeywords: [String] {
        var keywords = Set<String>()
        for note in notes {
            if let noteKeywords = note.keywords {
                keywords.formUnion(noteKeywords)
            }
        }
        return Array(keywords).sorted()
    }
    
    // MARK: - Filter Logic (Chained)
    
    // Step 1: Type filter
    private var typeFilteredNotes: [VoiceNote] {
        switch selectedFilter {
        case .all: return notes
        case .notes: return notes.filter { $0.noteType == .note }
        case .tasks: return notes.filter { $0.noteType == .task }
        case .events: return notes.filter { $0.noteType == .event }
        }
    }
    
    // Step 2: Apply advanced filters
    private var advancedFilteredNotes: [VoiceNote] {
        var result = typeFilteredNotes
        
        // Date filter
        if filterState.dateFilter != .all {
            let calendar = Calendar.current
            let now = Date()
            
            result = result.filter { note in
                switch filterState.dateFilter {
                case .today:
                    return calendar.isDateInToday(note.createdAt)
                case .thisWeek:
                    return calendar.isDate(note.createdAt, equalTo: now, toGranularity: .weekOfYear)
                case .thisMonth:
                    return calendar.isDate(note.createdAt, equalTo: now, toGranularity: .month)
                case .all:
                    return true
                }
            }
        }
        
        // Category filter
        if !filterState.selectedCategories.isEmpty {
            result = result.filter { note in
                guard let category = note.category else { return false }
                return filterState.selectedCategories.contains(category)
            }
        }
        
        // Priority filter
        if !filterState.selectedPriorities.isEmpty {
            result = result.filter { note in
                guard let priority = note.priority else { return false }
                return filterState.selectedPriorities.contains(priority)
            }
        }
        
        // Sentiment filter
        if let sentiment = filterState.selectedSentiment {
            result = result.filter { note in
                guard let noteSentiment = note.sentiment else { return false }
                return noteSentiment.lowercased() == sentiment.lowercased()
            }
        }
        
        // Keywords filter
        if !filterState.selectedKeywords.isEmpty {
            result = result.filter { note in
                guard let noteKeywords = note.keywords else { return false }
                return !filterState.selectedKeywords.isDisjoint(with: Set(noteKeywords))
            }
        }
        
        // Show/hide completed
        if !filterState.showCompletedTasks {
            result = result.filter { !$0.isCompleted }
        }
        
        // Only with audio
        if filterState.onlyWithAudio {
            result = result.filter { $0.audioFilePath != nil }
        }
        
        return result
    }
    
    // Step 3: Apply search
    private var displayedNotes: [VoiceNote] {
        guard !searchText.isEmpty else { return advancedFilteredNotes }
        
        let query = searchText.lowercased()
        return advancedFilteredNotes.filter { note in
            if note.transcript.lowercased().contains(query) { return true }
            if let summary = note.summary, summary.lowercased().contains(query) { return true }
            if let keywords = note.keywords {
                for keyword in keywords {
                    if keyword.lowercased().contains(query) { return true }
                }
            }
            if let location = note.eventLocation, location.lowercased().contains(query) { return true }
            if let category = note.category, category.lowercased().contains(query) { return true }
            return false
        }
    }
    
    // 🔥 Dynamic counts based on advanced filters
    private func filterCount(for filter: NoteFilter) -> Int {
        // Apply advanced filters first (without type filter)
        var base = notes
        
        // Date filter
        if filterState.dateFilter != .all {
            let calendar = Calendar.current
            let now = Date()
            base = base.filter { note in
                switch filterState.dateFilter {
                case .today: return calendar.isDateInToday(note.createdAt)
                case .thisWeek: return calendar.isDate(note.createdAt, equalTo: now, toGranularity: .weekOfYear)
                case .thisMonth: return calendar.isDate(note.createdAt, equalTo: now, toGranularity: .month)
                case .all: return true
                }
            }
        }
        
        // Category filter
        if !filterState.selectedCategories.isEmpty {
            base = base.filter { note in
                guard let category = note.category else { return false }
                return filterState.selectedCategories.contains(category)
            }
        }
        
        // Priority filter
        if !filterState.selectedPriorities.isEmpty {
            base = base.filter { note in
                guard let priority = note.priority else { return false }
                return filterState.selectedPriorities.contains(priority)
            }
        }
        
        // Sentiment filter
        if let sentiment = filterState.selectedSentiment {
            base = base.filter { note in
                guard let noteSentiment = note.sentiment else { return false }
                return noteSentiment.lowercased() == sentiment.lowercased()
            }
        }
        
        // Keywords filter
        if !filterState.selectedKeywords.isEmpty {
            base = base.filter { note in
                guard let noteKeywords = note.keywords else { return false }
                return !filterState.selectedKeywords.isDisjoint(with: Set(noteKeywords))
            }
        }
        
        // Show/hide completed
        if !filterState.showCompletedTasks {
            base = base.filter { !$0.isCompleted }
        }
        
        // Only with audio
        if filterState.onlyWithAudio {
            base = base.filter { $0.audioFilePath != nil }
        }
        
        // Now count by type
        switch filter {
        case .all: return base.count
        case .notes: return base.filter { $0.noteType == .note }.count
        case .tasks: return base.filter { $0.noteType == .task }.count
        case .events: return base.filter { $0.noteType == .event }.count
        }
    }
    
    // MARK: - Empty State
    private var emptyStateTitle: String {
        if !searchText.isEmpty {
            return "No Results"
        }
        if filterState.hasActiveFilters {
            return "No Matches"
        }
        switch selectedFilter {
        case .all: return "No Items"
        case .notes: return "No Notes"
        case .tasks: return "No Tasks"
        case .events: return "No Events"
        }
    }
    
    private var emptyStateIcon: String {
        if !searchText.isEmpty || filterState.hasActiveFilters {
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
        if filterState.hasActiveFilters {
            return "Try adjusting your filters"
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