import SwiftUI

struct ConversationTranscript: View {
    @ObservedObject var model: InterpreterModel
    @ScaledMetric(relativeTo: .title2) private var translatedSize: CGFloat = 23
    var body: some View {
        LazyVStack(alignment: .leading, spacing: 28) {
            ForEach(0..<max(model.source.captions.count, model.translation.captions.count), id: \.self) { index in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text(String(format: "%02d", index + 1))
                            .font(.caption2.monospacedDigit()).foregroundColor(VoiceTheme.accent)
                            .padding(5).background(VoiceTheme.soft, in: Circle())
                        Text(model.translationTitle).font(.caption).foregroundColor(.secondary)
                    }.accessibilityHidden(true)
                    if index < model.source.captions.count {
                        Text(model.source.captions[index].text).font(.body).foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                    if index < model.translation.captions.count {
                        Text(model.translation.captions[index].text)
                            .font(.system(size: translatedSize, weight: .medium))
                            .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }.padding(.vertical, 14)
    }
}
