import SwiftUI

struct WelcomeView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(Theme.primaryGradient)
                .padding(.top, 40)
            
            Text("Welcome to Voice Mind")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 20) {
                featureRow(icon: "mic.fill", color: .blue, title: "Recording", desc: "To capture your thoughts securely.")
                featureRow(icon: "waveform.badge.magnifyingglass", color: .purple, title: "Speech Recognition", desc: "To convert your voice into text instantly.")
                featureRow(icon: "calendar", color: .red, title: "Calendar & Tasks", desc: "To automatically schedule events and reminders.")
            }
            .padding()
            
            Spacer()
            
            Button {
                isPresented = false
                UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
            } label: {
                Text("Continue")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.primary)
                    .cornerRadius(14)
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }
    
    private func featureRow(icon: String, color: Color, title: String, desc: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(title).font(.headline)
                Text(desc).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
