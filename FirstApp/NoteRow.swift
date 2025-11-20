import SwiftUI

struct NoteRow: View {
    let note: VoiceNote

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.summary ?? note.transcript)
                .lineLimit(2)
                .font(.headline)

            HStack {
                Text(note.createdAt, style: .date)
                Text("•")
                Text(note.sentiment ?? "No sentiment")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}
