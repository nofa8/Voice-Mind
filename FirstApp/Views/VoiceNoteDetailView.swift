import SwiftUI

struct VoiceNoteDetailView: View {
    @Environment(\.modelContext) private var context
    @State var note: VoiceNote

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                // 🔥 Type Badge
                typeBadge
                
                // 🔥 Type-Specific Sections
                switch note.noteType {
                case .task:
                    taskSpecificSection
                case .event:
                    eventSpecificSection
                case .note:
                    noteSpecificSection
                }
                
                Divider()
                
                // Common Sections
                section("Transcript", text: note.transcript)
                section("Summary", text: note.summary)
                section("Sentiment", text: note.sentiment)
                
                if let keywords = note.keywords, !keywords.isEmpty {
                    keywordsSection(keywords)
                }
                
                if let lang = note.detectedLanguage {
                    section("Detected Language", text: lang)
                }
                
                Divider()

                deleteButton
            }
            .padding()
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
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
            
            Spacer()
            
            // Priority badge
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
            // Completion toggle
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
            
            // Action items
            if let actionItems = note.actionItems, !actionItems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Action Items")
                        .font(.headline)
                    
                    ForEach(Array(actionItems.enumerated()), id: \.offset) { index, item in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "\(index + 1).circle.fill")
                                .foregroundStyle(Theme.primary)
                            Text(item)
                                .font(.body)
                        }
                    }
                }
                .padding()
                .background(Theme.primary.opacity(0.05))
                .cornerRadius(Theme.cornerRadius)
            }
        }
    }
    
    // MARK: - Event-Specific Section
    private var eventSpecificSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Date & Time
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
                        
                        // Countdown or past indicator
                        Text(timeUntil(eventDate))
                            .font(.caption)
                            .foregroundStyle(eventDate > Date() ? .blue : .gray)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(Theme.cornerRadius)
            }
            
            // Location
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
