// FirstApp/NoteRow.swift
import SwiftUI

struct NoteRow: View {
    @Environment(\.modelContext) private var context
    @State var note: VoiceNote

    var body: some View {
        HStack(spacing: 0) {
            // Priority Indicator Strip
            if let priority = note.priority, !priority.isEmpty {
                Rectangle()
                    .fill(priorityColor(priority))
                    .frame(width: 5)
                    .accessibilityLabel("Priority: \(priority)")
            }
            
            VStack(alignment: .leading, spacing: 8) {
                // Header: Icon, Type, Date
                HStack {
                    Image(systemName: typeIcon)
                        .foregroundStyle(typeColor)
                    
                    Text(note.noteType.rawValue.capitalized)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(typeColor)
                    
                    Spacer()
                    
                    if note.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .accessibilityLabel("Pinned")
                    }
                    
                    Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
                
                // Content
                Text(note.summary ?? note.transcript)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(note.isCompleted ? Theme.textSecondary : Theme.textPrimary)
                    .strikethrough(note.isCompleted)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Footer: Keywords
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
                                    .foregroundStyle(Theme.primary) // Ensures contrast
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .accessibilityHidden(true) // Skip reading individual keywords in list view
                }
            }
            .padding(Theme.padding)
        }
        .adaptiveCardStyle() // 🔥 Uses new Theme modifier
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(note.noteType.rawValue), \(note.summary ?? "Voice Note"), created \(note.createdAt.formatted())")
        .accessibilityHint("Double tap to view details")
    }
    
    // MARK: - Helpers
    private var typeIcon: String {
        switch note.noteType {
        case .task: return "checklist"
        case .event: return "calendar"
        case .note: return "doc.text"
        }
    }
    
    private var typeColor: Color {
        switch note.noteType {
        case .task: return .green
        case .event: return .blue
        case .note: return .orange
        }
    }
    
    private func priorityColor(_ priority: String) -> Color {
        switch priority.lowercased() {
        case "high": return .red
        case "medium": return .orange
        case "low": return .green
        default: return .clear
        }
    }
}