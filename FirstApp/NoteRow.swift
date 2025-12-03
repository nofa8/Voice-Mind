// NoteRow.swift
import SwiftUI

struct NoteRow: View {
    let note: VoiceNote

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // 🔥 Updated Icon Logic for 3 Types
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

                Spacer()
                
                // Display Date if it exists (for events/tasks)
                if let date = note.eventDate {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    // Fallback to createdAt
                    Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            
            Text(note.summary ?? note.transcript)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
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
            
            // Display Priority if Available
            if let priority = note.priority, !priority.isEmpty {
                Text(priority.uppercased())
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(priority == "High" ? .red : .gray)
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
        .padding(Theme.padding)
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}