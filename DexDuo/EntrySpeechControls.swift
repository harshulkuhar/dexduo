import SwiftUI

struct EntrySpeechControls: View {
    @ObservedObject var store: DexStore
    @EnvironmentObject private var speech: EntrySpeech
    @State private var settings = false

    var body: some View {
        HStack(spacing: 8) {
            Button {
                if speech.state.active { speech.stop() }
                else if let entry = store.spokenEntry { speech.read(entry) }
            } label: {
                Label(speech.state.active ? "Stop" : "Read", systemImage: speech.state.active ? "stop.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 14, weight: .semibold)).frame(minHeight: 44).padding(.horizontal, 10)
            }.buttonStyle(.plain).background(.white.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
                .disabled(!speech.state.active && (store.loading || store.spokenEntry == nil))
                .accessibilityIdentifier("entryRead")
                .accessibilityValue(speech.state.active ? (speech.state == .preparing ? "Preparing speech" : "Speaking") : "Stopped")
            Text(status).font(.system(size: 12)).frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("entryAudioStatus")
            Button { settings = true } label: { Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44) }
                .buttonStyle(.plain).accessibilityLabel("Audio settings").accessibilityIdentifier("audioSettings")
                .popover(isPresented: $settings) {
                    VStack(alignment: .leading, spacing: 12) {
                        ScrollView(.vertical) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Audio settings").font(.headline)
                                Toggle("Auto-read selections", isOn: $speech.autoRead).accessibilityIdentifier("autoRead")
                                Text("Read Pokémon names and English entries after selection. Opening the app or cover stays silent.")
                                    .font(.system(size: 14)).fixedSize(horizontal: false, vertical: true)
                            }
                        }.scrollIndicators(.visible)
                        Button("Done") { settings = false }.font(.system(size: 14)).frame(minHeight: 44).accessibilityIdentifier("audioSettingsDone")
                    }.padding(16).frame(width: 280, height: 260).presentationCompactAdaptation(.popover)
                }
        }
    }
    private var status: String {
        if speech.state == .preparing { return "Preparing…" }
        if speech.state == .speaking { return "Speaking" }
        if store.loading { return "Loading entry…" }
        return store.spokenEntry == nil ? "English entry unavailable" : "Robotic voice"
    }
}
