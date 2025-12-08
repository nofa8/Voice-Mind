import SwiftUI
import SwiftData

struct AgendaView: View {
    @Environment(\.modelContext) private var context
    
    // Query notes WITH dates (for calendar display)
    @Query(
        filter: #Predicate<VoiceNote> { $0.eventDate != nil },
        sort: \VoiceNote.eventDate,
        order: .forward
    )
    private var notesWithDates: [VoiceNote]
    
    // 🔥 NEW: Query event-type notes WITHOUT dates
    @Query(
        filter: #Predicate<VoiceNote> { $0.eventDate == nil },
        sort: \VoiceNote.createdAt,
        order: .reverse
    )
    private var allNotesWithoutDates: [VoiceNote]
    
    // Filter to only event types without dates
    private var eventsWithoutDates: [VoiceNote] {
        allNotesWithoutDates.filter { $0.noteType == .event }
    }
    
    @State private var timeFrame: TimeFrame = .month
    @State private var currentDate = Date()
    @State private var selectedDate: Date?
    @State private var showEventsWithoutDates = false  // 🔥 Toggle for dateless events
    
    enum TimeFrame: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Time Frame Picker
                    Picker("Time Frame", selection: $timeFrame) {
                        ForEach(TimeFrame.allCases, id: \.self) { frame in
                            Text(frame.rawValue).tag(frame)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    
                    // Navigation Header
                    HStack {
                        Button(action: previousPeriod) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .foregroundColor(Theme.primary)
                        }
                        
                        Spacer()
                        
                        Text(headerTitle)
                            .font(.title2)
                            .fontWeight(.bold)
                            .animation(.none, value: currentDate)
                        
                        Spacer()
                        
                        Button(action: nextPeriod) {
                            Image(systemName: "chevron.right")
                                .font(.title2)
                                .foregroundColor(Theme.primary)
                        }
                    }
                    .padding()
                    
                    // Calendar View
                    ScrollView {
                        VStack(spacing: 20) {
                            switch timeFrame {
                            case .week:
                                WeekView(
                                    currentDate: currentDate,
                                    notesByDate: notesByDate,  // 🚀 O(1) lookup
                                    selectedDate: $selectedDate
                                )
                            case .month:
                                MonthView(
                                    currentDate: currentDate,
                                    notesByDate: notesByDate,  // 🚀 O(1) lookup
                                    selectedDate: $selectedDate
                                )
                            case .year:
                                YearView(
                                    currentDate: currentDate,
                                    notes: filteredNotes,
                                    onMonthTap: { date in
                                        currentDate = date
                                        timeFrame = .month
                                    }
                                )
                            }
                            
                            // Notes for selected date
                            if let selectedDate = selectedDate {
                                NotesForDateView(
                                    date: selectedDate,
                                    notes: notesForDate(selectedDate)
                                )
                            }
                            
                            // 🔥 NEW: Events without dates section
                            if !eventsWithoutDates.isEmpty {
                                eventsWithoutDatesSection
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Agenda")
            .navigationDestination(for: VoiceNote.self) { note in
                VoiceNoteDetailView(note: note)
            }
        }
    }
    
    // 🔥 NEW: Section for events without specific dates
    private var eventsWithoutDatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { showEventsWithoutDates.toggle() }) {
                HStack {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .foregroundColor(.orange)
                    Text("Events Without Dates (\(eventsWithoutDates.count))")
                        .font(.headline)
                    Spacer()
                    Image(systemName: showEventsWithoutDates ? "chevron.up" : "chevron.down")
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .buttonStyle(.plain)
            
            if showEventsWithoutDates {
                Text("These events were detected but no specific date was mentioned.")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                
                ForEach(eventsWithoutDates) { note in
                    NavigationLink(value: note) {
                        NoteRow(note: note)
                    }
                }
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
    }
    
    // MARK: - Helper Functions
    
    private var headerTitle: String {
        let formatter = DateFormatter()
        switch timeFrame {
        case .week:
            let calendar = Calendar.current
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: currentDate)?.start ?? currentDate
            formatter.dateFormat = "MMM d"
            let startStr = formatter.string(from: weekStart)
            let endDate = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
            let endStr = formatter.string(from: endDate)
            formatter.dateFormat = "yyyy"
            return "\(startStr) - \(endStr), \(formatter.string(from: currentDate))"
        case .month:
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: currentDate)
        case .year:
            formatter.dateFormat = "yyyy"
            return formatter.string(from: currentDate)
        }
    }
    
    private var filteredNotes: [VoiceNote] {
        let calendar = Calendar.current
        let range: DateInterval?
        
        switch timeFrame {
        case .week:
            range = calendar.dateInterval(of: .weekOfYear, for: currentDate)
        case .month:
            range = calendar.dateInterval(of: .month, for: currentDate)
        case .year:
            range = calendar.dateInterval(of: .year, for: currentDate)
        }
        
        guard let range = range else { return [] }
        
        return notesWithDates.filter { note in
            guard let eventDate = note.eventDate else { return false }
            return range.contains(eventDate)
        }
    }
    
    // 🔥 PERFORMANCE FIX: Pre-calculate notes by date for O(1) lookup
    private var notesByDate: [Date: [VoiceNote]] {
        let calendar = Calendar.current
        var dict: [Date: [VoiceNote]] = [:]
        
        for note in filteredNotes {
            guard let eventDate = note.eventDate else { continue }
            let dayStart = calendar.startOfDay(for: eventDate)
            dict[dayStart, default: []].append(note)
        }
        
        return dict
    }
    
    private func notesForDate(_ date: Date) -> [VoiceNote] {
        // 🔥 O(1) lookup instead of O(N) filter
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        return notesByDate[dayStart] ?? []
    }
    
    private func previousPeriod() {
        movePeriod(by: -1)
    }
    
    private func nextPeriod() {
        movePeriod(by: 1)
    }
    
    private func movePeriod(by value: Int) {
        let calendar = Calendar.current
        let component: Calendar.Component = switch timeFrame {
            case .week: .weekOfYear
            case .month: .month
            case .year: .year
        }
        currentDate = calendar.date(byAdding: component, value: value, to: currentDate) ?? currentDate
    }
}

// MARK: - Week View
struct WeekView: View {
    let currentDate: Date
    let notesByDate: [Date: [VoiceNote]]  // 🚀 Dictionary for O(1) lookup
    @Binding var selectedDate: Date?
    
    private var weekDays: [Date] {
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: currentDate)?.start else {
            return []
        }
        return (0..<7).compactMap { day in
            calendar.date(byAdding: .day, value: day, to: weekStart)
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Day headers
            HStack(spacing: 4) {
                ForEach(weekDays, id: \.self) { date in
                    VStack(spacing: 4) {
                        Text(dayOfWeekString(date))
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        
                        Text("\(Calendar.current.component(.day, from: date))")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(isToday(date) ? .white : Theme.textPrimary)
                            .frame(width: 40, height: 40)
                            .background(isToday(date) ? Theme.primary : Color.clear)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(selectedDate != nil && Calendar.current.isDate(date, inSameDayAs: selectedDate!) ? Theme.accent : Color.clear, lineWidth: 2)
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedDate = date
                    }
                }
            }
            
            // Note indicators
            HStack(spacing: 4) {
                ForEach(weekDays, id: \.self) { date in
                    VStack(spacing: 2) {
                        let dayNotes = notesForDay(date)
                        if !dayNotes.isEmpty {
                            Text("\(dayNotes.count)")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Theme.primary)
                                .clipShape(Circle())
                        } else {
                            Text("")
                                .font(.caption2)
                                .padding(4)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
    }
    
    private func notesForDay(_ date: Date) -> [VoiceNote] {
        // 🚀 O(1) lookup instead of O(N) filter
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        return notesByDate[startOfDay] ?? []
    }
    
    private func dayOfWeekString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    
    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
}

// MARK: - Month View
struct MonthView: View {
    let currentDate: Date
    let notesByDate: [Date: [VoiceNote]]  // 🚀 Dictionary for O(1) lookup
    @Binding var selectedDate: Date?
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    
    private var monthDays: [Date?] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentDate) else {
            return []
        }
        
        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let numberOfDays = calendar.dateComponents([.day], from: monthInterval.start, to: monthInterval.end).day ?? 0
        
        var days: [Date?] = []
        
        // Leading padding
        for _ in 1..<firstWeekday {
            days.append(nil)
        }
        
        // Actual days
        for day in 0..<numberOfDays {
            if let date = calendar.date(byAdding: .day, value: day, to: monthInterval.start) {
                days.append(date)
            }
        }
        
        return days
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Weekday headers
            HStack(spacing: 4) {
                ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar grid
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0..<monthDays.count, id: \.self) { index in
                    if let date = monthDays[index] {
                        DayCell(
                            date: date,
                            noteCount: notesForDay(date).count,
                            isSelected: selectedDate != nil && Calendar.current.isDate(date, inSameDayAs: selectedDate!),
                            isToday: Calendar.current.isDateInToday(date)
                        )
                        .onTapGesture {
                            selectedDate = date
                        }
                    } else {
                        Color.clear
                            .frame(height: 50)
                    }
                }
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
    }
    
    private func notesForDay(_ date: Date) -> [VoiceNote] {
        // 🚀 O(1) lookup instead of O(N) filter
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        return notesByDate[startOfDay] ?? []
    }
}

struct DayCell: View {
    let date: Date
    let noteCount: Int
    let isSelected: Bool
    let isToday: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.body)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundColor(isToday ? .white : Theme.textPrimary)
            
            if noteCount > 0 {
                Text("\(noteCount)")
                    .font(.caption2)
                    .foregroundColor(.white)
                    .frame(width: 20, height: 20)
                    .background(Theme.primary)
                    .clipShape(Circle())
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(isToday ? Theme.primary : (isSelected ? Theme.accent.opacity(0.2) : Color.clear))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Theme.accent : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Year View
struct YearView: View {
    let currentDate: Date
    let notes: [VoiceNote]
    let onMonthTap: (Date) -> Void
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
    
    private var months: [Date] {
        let calendar = Calendar.current
        guard let yearStart = calendar.dateInterval(of: .year, for: currentDate)?.start else {
            return []
        }
        return (0..<12).compactMap { month in
            calendar.date(byAdding: .month, value: month, to: yearStart)
        }
    }
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(months, id: \.self) { month in
                MonthCard(
                    date: month,
                    noteCount: notesForMonth(month).count
                )
                .onTapGesture {
                    onMonthTap(month)
                }
            }
        }
        .padding()
    }
    
    private func notesForMonth(_ date: Date) -> [VoiceNote] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: date) else {
            return []
        }
        return notes.filter { note in
            guard let eventDate = note.eventDate else { return false }
            return monthInterval.contains(eventDate)
        }
    }
}

struct MonthCard: View {
    let date: Date
    let noteCount: Int
    
    private var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(monthName)
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            
            if noteCount > 0 {
                Text("\(noteCount)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.primary)
                
                Text(noteCount == 1 ? "note" : "notes")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            } else {
                Text("—")
                    .font(.title2)
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}

// MARK: - Notes for Date View
struct NotesForDateView: View {
    @Environment(\.modelContext) private var context
    let date: Date
    let notes: [VoiceNote]
    
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(Theme.primary)
                Text("Notes for \(dateString)")
                    .font(.headline)
            }
            
            if notes.isEmpty {
                Text("No notes for this date")
                    .foregroundColor(Theme.textSecondary)
                    .italic()
                    .padding()
            } else {
                ForEach(notes) { note in
                    NavigationLink(value: note) {
                        NoteRow(note: note)
                    }
                }
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
    }
}
