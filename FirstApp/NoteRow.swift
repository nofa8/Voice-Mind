import SwiftUI

struct NoteRow: View {
    let note: VoiceNote

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Image(systemName: "waveform")
                    .foregroundStyle(Theme.accent)
                Text(note.createdAt, style: .date)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                if let sentiment = note.sentiment {
                    sentimentBadge(sentiment)
                }
            }

            Text(note.summary ?? note.transcript)
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
                .lineLimit(2)

            if let keywords = note.keywords, !keywords.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(keywords.prefix(3), id: \.self) { keyword in
                            Text("#\(keyword)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Theme.primary.opacity(0.12))
                                .cornerRadius(8)
                                .foregroundColor(Theme.primary)
                        }
                    }
                }
            }
        }
        .padding(Theme.padding)
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    private func sentimentBadge(_ sentiment: String) -> some View {
        let lower = sentiment.lowercased()
        let color: Color = lower.contains("positive") ? .green : lower.contains("negative") ? .red : .orange

        return Text(sentiment)
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .foregroundColor(color)
            .cornerRadius(6)
    }
}
