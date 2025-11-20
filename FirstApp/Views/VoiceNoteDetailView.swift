import SwiftUI

struct VoiceNoteDetailView: View {
    @Environment(\.modelContext) private var context
    @State var note: VoiceNote

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                section("Transcript", text: note.transcript)
                section("Summary", text: note.summary)
                section("Sentiment", text: note.sentiment)
                section("Keywords", text: note.keywords?.joined(separator: ", "))
                section("Translation", text: note.translation)

                Divider()

                Button(role: .destructive) {
                    context.delete(note)
                    try? context.save()
                } label: {
                    Text("Delete this note")
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(_ title: String, text: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(text ?? "—")
                .foregroundColor(text == nil ? .secondary : .primary)
        }
    }
}
