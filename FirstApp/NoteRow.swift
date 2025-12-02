// NoteRow.swift
import SwiftUI

struct NoteRow: View {
    let note: VoiceNote

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // 1. Fixed: Use 'note.noteType' instead of 'note.type'
                Image(systemName: note.noteType == .agenda ? "calendar" : "doc.text")
                    .foregroundStyle(note.noteType == .agenda ? .blue : .orange)
                
                // 1. Fixed: Use 'note.noteType'
                Text(note.noteType.rawValue.capitalized)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(note.noteType == .agenda ? .blue : .orange)

                Spacer()
                
                // 2. Fixed: Handle optional Date. Use eventDate if available, else createdAt
                Text((note.eventDate ?? note.createdAt).formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            
            Text(note.summary ?? note.transcript)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            // Optional: Display Priority if you want (since we added it to the model)
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