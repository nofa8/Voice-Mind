// NoteRow.swift
import SwiftUI

struct NoteRow: View {
    @Environment(\.modelContext) private var context
    @State var note: VoiceNote

    var body: some View {
        HStack(spacing: 12) {
            // 🔥 Task completion checkbox (left side)
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
                    // Updated Icon Logic for 3 Types
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
                    
                    Text(note.noteType.rawValue.capitalized)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(iconColor)
                    
                    // 🔥 Priority indicator
                    if let priority = note.priority, !priority.isEmpty, priority.lowercased() == "high" {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                    }

                    Spacer()
                    
                    // Display Date if it exists (for events/tasks)
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
                        // Fallback to createdAt
                        Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                
                // Summary/Transcript with strikethrough for completed tasks
                Text(note.summary ?? note.transcript)
                    .font(.headline)
                    .foregroundStyle(note.isCompleted ? Theme.textSecondary : Theme.textPrimary)
                    .strikethrough(note.isCompleted, color: .gray)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Display Event Location if Available
                if let location = note.eventLocation, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                        Text(location)
                            .font(.caption2)
                    }
                    .foregroundStyle(Theme.textSecondary)
                }
                
                // Display Action Items count for tasks
                if note.noteType == .task, let actionItems = note.actionItems, !actionItems.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "list.bullet")
                            .font(.caption2)
                        Text("\(actionItems.count) action item\(actionItems.count == 1 ? "" : "s")")
                            .font(.caption2)
                    }
                    .foregroundStyle(.green)
                }
                
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
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .opacity(note.isCompleted ? 0.7 : 1.0) // Dim completed tasks
    }
    
    private func toggleCompletion() {
        note.isCompleted.toggle()
        try? context.save()
    }
}