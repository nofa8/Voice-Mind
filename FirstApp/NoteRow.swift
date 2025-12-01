// NoteRow.swift
import SwiftUI

struct NoteRow: View {
    let note: VoiceNote

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: note.type == .agenda ? "calendar" : "checklist")
                    .foregroundStyle(note.type == .agenda ? .blue : .orange)
                
                Text(note.type.rawValue)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(note.type == .agenda ? .blue : .orange)

                Spacer()
                
                Text(note.eventDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            
            Text(note.summary ?? note.transcript)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
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
    
    private func sentimentBadge(_ sentiment: String) -> some View {
        let color: Color = sentiment.lowercased().contains("positive") ? .green : 
                           sentiment.lowercased().contains("negative") ? .red : .orange
        
        return Text(sentiment)
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}