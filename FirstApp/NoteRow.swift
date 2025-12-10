// Enhanced NoteRow.swift
import SwiftUI

struct NoteRow: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    @State var note: VoiceNote

    private var priorityColor: Color {
        guard let priority = note.priority else { return .clear }
        switch priority.lowercased() {
        case "high": return Theme.priorityHigh
        case "medium": return Theme.priorityMedium
        case "low": return Theme.priorityLow
        default: return .clear
        }
    }
    
    private var hasPriority: Bool {
        guard let priority = note.priority else { return false }
        return !priority.isEmpty
    }
    
    private var typeColor: Color {
        switch note.noteType {
        case .task: return Theme.taskGreen
        case .event: return Theme.eventBlue
        case .note: return Theme.noteOrange
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Priority colored left border
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
                            .foregroundStyle(note.isCompleted ? Theme.success : Theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    // Header row
                    HStack {
                        let icon = switch note.noteType {
                            case .task: "checklist"
                            case .event: "calendar"
                            case .note: "doc.text"
                        }
                        
                        Image(systemName: icon)
                            .foregroundStyle(typeColor)
                            .imageScale(.small)
                        
                        // Pin indicator
                        if note.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.caption)
                                .foregroundStyle(Theme.warning)
                        }
                        
                        // Failed analysis warning
                        if note.analysisStatus == .failed {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(Theme.error)
                        }
                        
                        Text(note.noteType.rawValue.capitalized)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(typeColor)
                        
                        // Priority badge
                        if let priority = note.priority, !priority.isEmpty {
                            Text(priority.uppercased())
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(priorityColor)
                                .cornerRadius(4)
                        }

                        Spacer()
                        
                        // Date display
                        dateView
                    }
                    
                    // Summary with strikethrough for completed
                    Text(note.summary ?? note.transcript)
                        .font(.headline)
                        .foregroundStyle(note.isCompleted ? Theme.textSecondary : Theme.textPrimary)
                        .strikethrough(note.isCompleted, color: Theme.textTertiary)
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
                        .foregroundStyle(Theme.success)
                    }
                    
                    // Keywords
                    if let keywords = note.keywords, !keywords.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(keywords.prefix(3), id: \.self) { keyword in
                                    Text("#\(keyword)")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            typeColor.opacity(colorScheme == .dark ? 0.3 : 0.15)
                                        )
                                        .foregroundStyle(typeColor)
                                        .cornerRadius(Theme.cornerRadiusSmall)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, Theme.paddingSmall)
            }
            .padding(.horizontal, Theme.padding)
        }
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
        .adaptiveBorder()
        .cardShadow()
        .opacity(note.isCompleted ? 0.7 : 1.0)
    }
    
    // MARK: - Date View
    @ViewBuilder
    private var dateView: some View {
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
    
    private func toggleCompletion() {
        note.isCompleted.toggle()
        try? context.save()
    }
}