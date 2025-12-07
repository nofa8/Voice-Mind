// NoteRow.swift
import SwiftUI

struct NoteRow: View {
    @Environment(\.modelContext) private var context
    @State var note: VoiceNote

    // 🔥 Priority color for left border
    private var priorityColor: Color {
        guard let priority = note.priority else { return .clear }
        switch priority.lowercased() {
        case "high": return .red
        case "medium": return .orange
        case "low": return .green
        default: return .clear
        }
    }
    
    private var hasPriority: Bool {
        guard let priority = note.priority else { return false }
        return !priority.isEmpty
    }

    var body: some View {
        HStack(spacing: 0) {
            // 🔥 Priority colored left border
            if hasPriority {
                Rectangle()
                    .fill(priorityColor)
                    .frame(width: 4)
            }
            
            HStack(spacing: 12) {
                // Task completion checkbox
                if note.noteType == .task {
                    Button(action: toggleCompletion) {
                        Image(systemName: note.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(note.isCompleted ? .green : .gray)
                    }
                    .buttonStyle(.plain)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        let icon = switch note.noteType {
                            case .task: "checklist"
                            case .event: "calendar"
                            case .note: "doc.text"
                        }
                        
                        let iconColor = switch note.noteType {
                            case .task: Color.green
                            case .event: Color.blue
                            case .note: Color.orange
                        }
                        
                        Image(systemName: icon)
                            .foregroundStyle(iconColor)
                        
                        // 🔥 Pin indicator
                        if note.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        
                        Text(note.noteType.rawValue.capitalized)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(iconColor)
                        
                        // Priority badge (text)
                        if let priority = note.priority, !priority.isEmpty {
                            Text(priority.uppercased())
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(priorityColor)
                        }

                        Spacer()
                        
                        // Date display
                        if let date = note.eventDate {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption2)
                                    .foregroundStyle(Theme.textSecondary)
                                Text(date.formatted(date: .omitted, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        } else {
                            Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    
                    // Summary with strikethrough for completed
                    Text(note.summary ?? note.transcript)
                        .font(.headline)
                        .foregroundStyle(note.isCompleted ? Theme.textSecondary : Theme.textPrimary)
                        .strikethrough(note.isCompleted, color: .gray)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Location
                    if let location = note.eventLocation, !location.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption2)
                            Text(location)
                                .font(.caption2)
                        }
                        .foregroundStyle(Theme.textSecondary)
                    }
                    
                    // Action items count
                    if note.noteType == .task, let actionItems = note.actionItems, !actionItems.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "list.bullet")
                                .font(.caption2)
                            Text("\(actionItems.count) action item\(actionItems.count == 1 ? "" : "s")")
                                .font(.caption2)
                        }
                        .foregroundStyle(.green)
                    }
                    
                    // Keywords
                    if let keywords = note.keywords, !keywords.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(keywords.prefix(3), id: \.self) { keyword in
                                    Text("#\(keyword)")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Theme.primary.opacity(0.1))
                                        .cornerRadius(8)
                                        .foregroundStyle(Theme.primary)
                                }
                            }
                        }
                    }
                }
            }
            .padding(Theme.padding)
        }
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .opacity(note.isCompleted ? 0.7 : 1.0)
    }
    
    private func toggleCompletion() {
        note.isCompleted.toggle()
        try? context.save()
    }
}