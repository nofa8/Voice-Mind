import SwiftUI
import AVFoundation

// MARK: - Audio Player Manager
class AudioPlayerManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var duration: TimeInterval = 0
    
    private var player: AVAudioPlayer?
    private var timer: Timer?
    
    func loadAudio(from url: URL) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            duration = player?.duration ?? 0
        } catch {
            print("❌ Audio load error: \(error)")
        }
    }
    
    func togglePlayback() {
        guard let player = player else { return }
        
        if isPlaying {
            player.pause()
            stopTimer()
        } else {
            player.play()
            startTimer()
        }
        isPlaying.toggle()
    }
    
    func seek(to time: Double) {
        player?.currentTime = time
        progress = time
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.player else { return }
            self.progress = player.currentTime
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        progress = 0
        stopTimer()
    }
    
    func cleanup() {
        player?.stop()
        stopTimer()
        isPlaying = false
        progress = 0
    }
}

// MARK: - Main View
struct VoiceNoteDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State var note: VoiceNote
    @StateObject private var audioPlayer = AudioPlayerManager()
    
    // 🔥 Edit Mode
    @State private var isEditing = false
    
    // 🔥 Draft State (for Cancel support)
    @State private var draftTranscript = ""
    @State private var draftSummary = ""
    @State private var draftCategory = ""
    @State private var draftPriority = ""
    @State private var draftEventDate: Date? = nil
    @State private var draftEventLocation = ""
    @State private var draftNoteType: NoteType = .note
    
    // Toast state
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastType: ToastType = .success
    
    // Loading states
    @State private var isAddingToCalendar = false
    @State private var addingReminderIndex: Int? = nil
    @State private var isRetryingAnalysis = false
    
    // Picker options
    let categories = ["Work", "Personal", "Health", "Finance", "Idea", "Other"]
    let priorities = ["High", "Medium", "Low"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                // 🔥 Failed Analysis Warning Banner
                if note.analysisStatus == .failed {
                    failedAnalysisBanner
                }
                
                // Type Badge (with edit support)
                if isEditing {
                    editableTypeBadge
                } else {
                    typeBadge
                }
                
                // Audio Player (if audio exists)
                if note.audioURL != nil {
                    audioPlayerSection
                }
                
                // Type-Specific Sections
                if isEditing {
                    editableEventSection
                } else {
                    switch note.noteType {
                    case .task:
                        taskSpecificSection
                    case .event:
                        eventSpecificSection
                    case .note:
                        noteSpecificSection
                    }
                }
                
                Divider()
                
                // Editable Common Sections
                if isEditing {
                    editableTranscriptSection
                    editableSummarySection
                    editableCategoryPrioritySection
                } else {
                    section("Transcript", text: note.transcript)
                    section("Summary", text: note.summary)
                    section("Sentiment", text: note.sentiment)
                }
                
                if let keywords = note.keywords, !keywords.isEmpty {
                    keywordsSection(keywords)
                }
                
                if let lang = note.detectedLanguage {
                    section("Detected Language", text: lang)
                }
                
                if !isEditing {
                    Divider()
                    deleteButton
                }
            }
            .padding()
        }
        .navigationTitle(isEditing ? "Edit Note" : "Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditing {
                    Button("Save") {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                } else {
                    Button("Edit") {
                        enterEditMode()
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarLeading) {
                if isEditing {
                    Button("Cancel") {
                        cancelEdit()
                    }
                    .foregroundStyle(.red)
                }
            }
        }
        .onAppear {
            if let url = note.audioURL {
                audioPlayer.loadAudio(from: url)
            }
        }
        .onDisappear {
            audioPlayer.cleanup()
        }
        .toast(isPresented: $showToast, message: toastMessage, type: toastType)
    }
    
    // MARK: - Edit Mode Functions
    
    private func enterEditMode() {
        // Copy current values to draft state
        draftTranscript = note.transcript
        draftSummary = note.summary ?? ""
        draftCategory = note.category ?? ""
        draftPriority = note.priority ?? ""
        draftEventDate = note.eventDate
        draftEventLocation = note.eventLocation ?? ""
        draftNoteType = note.noteType
        
        withAnimation(.easeInOut(duration: 0.2)) {
            isEditing = true
        }
    }
    
    private func cancelEdit() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isEditing = false
        }
    }
    
    private func saveChanges() {
        // Write draft state back to model
        note.transcript = draftTranscript
        note.summary = draftSummary.isEmpty ? nil : draftSummary
        note.category = draftCategory.isEmpty ? nil : draftCategory
        note.priority = draftPriority.isEmpty ? nil : draftPriority
        note.eventDate = draftEventDate
        note.eventLocation = draftEventLocation.isEmpty ? nil : draftEventLocation
        note.noteType = draftNoteType
        
        try? context.save()
        
        withAnimation(.easeInOut(duration: 0.2)) {
            isEditing = false
        }
        
        showToastMessage("Changes saved", type: .success)
    }
    
    // MARK: - Editable Sections
    
    private var editableTypeBadge: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Note Type")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Picker("Type", selection: $draftNoteType) {
                Label("Note", systemImage: "doc.text").tag(NoteType.note)
                Label("Task", systemImage: "checklist").tag(NoteType.task)
                Label("Event", systemImage: "calendar").tag(NoteType.event)
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
    }
    
    private var editableEventSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Date Picker
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Event Date")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    if draftEventDate != nil {
                        Button("Clear") {
                            draftEventDate = nil
                        }
                        .font(.caption)
                        .foregroundStyle(.red)
                    }
                }
                
                if draftEventDate != nil {
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { draftEventDate ?? Date() },
                            set: { draftEventDate = $0 }
                        ),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.graphical)
                } else {
                    Button {
                        draftEventDate = Date()
                    } label: {
                        Label("Add Date", systemImage: "calendar.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            // Location
            VStack(alignment: .leading, spacing: 8) {
                Text("Location")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                TextField("Enter location...", text: $draftEventLocation)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
    }
    
    private var editableTranscriptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transcript")
                .font(.headline)
            
            TextEditor(text: $draftTranscript)
                .frame(minHeight: 100)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
    }
    
    private var editableSummarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Summary")
                .font(.headline)
            
            TextEditor(text: $draftSummary)
                .frame(minHeight: 80)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
    }
    
    private var editableCategoryPrioritySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Category Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Category")
                    .font(.headline)
                
                Picker("Category", selection: $draftCategory) {
                    Text("None").tag("")
                    ForEach(categories, id: \.self) { cat in
                        Text(cat).tag(cat)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            
            // Priority Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Priority")
                    .font(.headline)
                
                Picker("Priority", selection: $draftPriority) {
                    Text("None").tag("")
                    ForEach(priorities, id: \.self) { pri in
                        HStack {
                            Circle()
                                .fill(priorityColorFor(pri))
                                .frame(width: 8, height: 8)
                            Text(pri)
                        }
                        .tag(pri)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
    }
    
    private func priorityColorFor(_ priority: String) -> Color {
        switch priority.lowercased() {
        case "high": return .red
        case "medium": return .orange
        case "low": return .green
        default: return .gray
        }
    }
    
    // MARK: - Failed Analysis Banner
    
    private var failedAnalysisBanner: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.white)
                Text("Analysis Failed")
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
            }
            
            Text("The AI analysis failed. You can retry or edit the note manually.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
            
            Button {
                retryAnalysis()
            } label: {
                HStack {
                    if isRetryingAnalysis {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text(isRetryingAnalysis ? "Analyzing..." : "Retry Analysis")
                }
                .fontWeight(.semibold)
                .foregroundStyle(.orange)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.white)
                .cornerRadius(20)
            }
            .disabled(isRetryingAnalysis)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.orange.gradient)
        .cornerRadius(Theme.cornerRadius)
    }
    
    // MARK: - Retry Analysis
    
    private func retryAnalysis() {
        isRetryingAnalysis = true
        
        Task {
            do {
                let analysis = try await GeminiAnalysisService.shared.analyze(note.transcript)
                
                // Parse date if present
                var extractedDate: Date? = nil
                if let dateString = analysis.extractedDate {
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime]
                    extractedDate = formatter.date(from: dateString)
                }
                
                let type: NoteType = switch analysis.type.lowercased() {
                    case "task": .task
                    case "event": .event
                    default: .note
                }
                
                await MainActor.run {
                    // Update note with analysis results
                    note.summary = analysis.summary
                    note.sentiment = analysis.sentiment
                    note.keywords = analysis.keywords
                    note.actionItems = analysis.actionItems
                    note.category = analysis.category
                    note.priority = analysis.priority
                    note.eventDate = extractedDate
                    note.eventLocation = analysis.extractedLocation
                    note.noteType = type
                    note.analysisStatus = .completed
                    
                    try? context.save()
                    
                    isRetryingAnalysis = false
                    showToastMessage("Analysis complete!", type: .success)
                }
            } catch {
                await MainActor.run {
                    isRetryingAnalysis = false
                    showToastMessage("Retry failed: \(error.localizedDescription)", type: .error)
                }
            }
        }
    }
    
    // MARK: - Show Toast Helper
    private func showToastMessage(_ message: String, type: ToastType) {
        toastMessage = message
        toastType = type
        withAnimation {
            showToast = true
        }
    }
    
    // MARK: - Audio Player Section
    private var audioPlayerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "waveform")
                    .foregroundStyle(Theme.primary)
                Text("Original Recording")
                    .font(.headline)
                Spacer()
            }
            
            HStack(spacing: 16) {
                Button(action: { audioPlayer.togglePlayback() }) {
                    Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Theme.primary)
                }
                .buttonStyle(.plain)
                
                VStack(spacing: 4) {
                    Slider(
                        value: $audioPlayer.progress,
                        in: 0...max(audioPlayer.duration, 1),
                        onEditingChanged: { editing in
                            if !editing {
                                audioPlayer.seek(to: audioPlayer.progress)
                            }
                        }
                    )
                    .tint(Theme.primary)
                    
                    HStack {
                        Text(formatTime(audioPlayer.progress))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatTime(audioPlayer.duration))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Theme.primary.opacity(0.05))
        .cornerRadius(Theme.cornerRadius)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // MARK: - Type Badge
    private var typeBadge: some View {
        HStack {
            let (icon, color) = typeInfo
            
            Image(systemName: icon)
                .foregroundStyle(color)
            
            Text(note.noteType.rawValue.capitalized)
                .font(.headline)
                .foregroundStyle(color)
            
            // 🔥 Pin indicator
            if note.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            
            Spacer()
            
            if let priority = note.priority, !priority.isEmpty {
                priorityBadge(priority)
            }
        }
        .padding()
        .background(typeInfo.color.opacity(0.1))
        .cornerRadius(Theme.cornerRadius)
    }
    
    private var typeInfo: (icon: String, color: Color) {
        switch note.noteType {
        case .task: return ("checklist", .green)
        case .event: return ("calendar", .blue)
        case .note: return ("doc.text.fill", .orange)
        }
    }
    
    private func priorityBadge(_ priority: String) -> some View {
        Text(priority.uppercased())
            .font(.caption)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(priorityColor(priority))
            .foregroundStyle(.white)
            .cornerRadius(6)
    }
    
    private func priorityColor(_ priority: String) -> Color {
        switch priority.lowercased() {
        case "high": return .red
        case "medium": return .orange
        default: return .gray
        }
    }
    
    // MARK: - Task-Specific Section
    private var taskSpecificSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button(action: toggleCompletion) {
                HStack {
                    Image(systemName: note.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(note.isCompleted ? .green : .gray)
                    
                    Text(note.isCompleted ? "Completed" : "Mark as Complete")
                        .font(.headline)
                        .foregroundStyle(note.isCompleted ? .secondary : .primary)
                }
            }
            .buttonStyle(.plain)
            
            if let actionItems = note.actionItems, !actionItems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Action Items")
                        .font(.headline)
                    
                    ForEach(Array(actionItems.enumerated()), id: \.offset) { index, item in
                        HStack(alignment: .center, spacing: 8) {
                            Image(systemName: "\(index + 1).circle.fill")
                                .foregroundStyle(Theme.primary)
                            
                            Text(item)
                                .font(.body)
                            
                            Spacer()
                            
                            // 🔥 Add to Reminders button per item
                            Button {
                                addToReminders(item: item, index: index)
                            } label: {
                                if addingReminderIndex == index {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                } else {
                                    Image(systemName: "checklist")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(addingReminderIndex != nil)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(Theme.primary.opacity(0.05))
                .cornerRadius(Theme.cornerRadius)
            }
        }
    }
    
    // 🔥 Add action item to Apple Reminders
    private func addToReminders(item: String, index: Int) {
        addingReminderIndex = index
        
        Task {
            let result = await RemindersManager.shared.addReminder(
                title: item,
                notes: "From: \(note.summary ?? note.transcript)"
            )
            
            await MainActor.run {
                addingReminderIndex = nil
                
                switch result {
                case .success:
                    showToastMessage("Added to Reminders", type: .success)
                case .failure(let error):
                    showToastMessage(error.localizedDescription, type: .error)
                }
            }
        }
    }
    
    // MARK: - Event-Specific Section
    private var eventSpecificSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let eventDate = note.eventDate {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .font(.title2)
                        .foregroundStyle(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(eventDate.formatted(date: .long, time: .omitted))
                            .font(.headline)
                        Text(eventDate.formatted(date: .omitted, time: .shortened))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Text(timeUntil(eventDate))
                            .font(.caption)
                            .foregroundStyle(eventDate > Date() ? .blue : .gray)
                    }
                    
                    Spacer()
                    
                    // Add to Calendar button
                    Button(action: addToCalendar) {
                        VStack(spacing: 4) {
                            if isAddingToCalendar {
                                ProgressView()
                            } else {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.title2)
                            }
                            Text("Add")
                                .font(.caption2)
                        }
                        .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    .disabled(isAddingToCalendar)
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(Theme.cornerRadius)
            }
            
            if let location = note.eventLocation, !location.isEmpty {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundStyle(.red)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Location")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(location)
                            .font(.body)
                    }
                }
                .padding()
                .background(Color.red.opacity(0.05))
                .cornerRadius(Theme.cornerRadius)
            }
        }
    }
    
    // Add to Calendar action (now uses toast)
    private func addToCalendar() {
        guard let eventDate = note.eventDate else { return }
        
        isAddingToCalendar = true
        
        Task {
            let title = note.summary ?? "Voice Mind Event"
            let result = await CalendarManager.shared.addEvent(
                title: title,
                notes: note.transcript,
                startDate: eventDate,
                location: note.eventLocation
            )
            
            await MainActor.run {
                isAddingToCalendar = false
                
                switch result {
                case .success:
                    showToastMessage("Added to Calendar", type: .success)
                case .failure(let error):
                    showToastMessage(error.localizedDescription, type: .error)
                }
            }
        }
    }
    
    // MARK: - Note-Specific Section
    private var noteSpecificSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Created")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(note.createdAt.formatted(date: .long, time: .shortened))
                .font(.body)
        }
        .padding()
        .background(Color.orange.opacity(0.05))
        .cornerRadius(Theme.cornerRadius)
    }
    
    // MARK: - Helper Functions
    private func timeUntil(_ date: Date) -> String {
        let now = Date()
        let components = Calendar.current.dateComponents([.day, .hour], from: now, to: date)
        
        if date < now {
            return "Past event"
        } else if let days = components.day, days > 0 {
            return "In \(days) day\(days == 1 ? "" : "s")"
        } else if let hours = components.hour, hours > 0 {
            return "In \(hours) hour\(hours == 1 ? "" : "s")"
        } else {
            return "Coming up soon"
        }
    }
    
    private func toggleCompletion() {
        note.isCompleted.toggle()
        try? context.save()
    }
    
    // MARK: - Common Sections
    private func section(_ title: String, text: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(text ?? "—")
                .foregroundColor(text == nil ? .secondary : .primary)
        }
    }
    
    private func keywordsSection(_ keywords: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Keywords").font(.headline)
            
            FlowLayout(spacing: 8) {
                ForEach(keywords, id: \.self) { keyword in
                    Text("#\(keyword)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.primary.opacity(0.1))
                        .foregroundStyle(Theme.primary)
                        .cornerRadius(16)
                }
            }
        }
    }
    
    private var deleteButton: some View {
        Button(role: .destructive) {
            // 🔥 FIX: Use audioURL (transient) instead of audioFilePath
            if let url = note.audioURL {
                try? FileManager.default.removeItem(at: url)
            }
            context.delete(note)
            try? context.save()
        } label: {
            Text("Delete this note")
                .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - FlowLayout Helper
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: currentX, y: currentY))
                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }
            
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}
