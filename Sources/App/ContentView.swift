import SwiftUI

private let teal = Color(red: 0.08, green: 0.39, blue: 0.34)

struct ContentView: View {
    @StateObject private var model = InterpreterModel()
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    header
                    directionPicker
                    statusCard
                    if let error = model.errorMessage {
                        Label(error, systemImage: "exclamationmark.circle")
                            .font(.subheadline).foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding().background(.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
                            .accessibilityIdentifier("errorMessage")
                    }
                    captionCard(title: "ԭ��", subtitle: "ORIGINAL", captions: model.source.captions,
                                empty: "��˵�Ļ������������", translated: false)
                    captionCard(title: "����", subtitle: "TRANSLATION", captions: model.translation.captions,
                                empty: "�����ʵʱ��ʾ�����Զ�����", translated: true)
                    if model.phase == .live {
                        HStack(spacing: 12) {
                            Button { model.micMuted.toggle() } label: {
                                Label(model.micMuted ? "����˷�" : "��˷�", systemImage: model.micMuted ? "mic.slash" : "mic")
                                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                            }.buttonStyle(.bordered)
                            Button { model.playbackEnabled.toggle() } label: {
                                Label(model.playbackEnabled ? "�����ѿ���" : "�����Ѿ���",
                                      systemImage: model.playbackEnabled ? "speaker.wave.2" : "speaker.slash")
                                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                            }.buttonStyle(.bordered)
                        }.tint(teal)
                        if model.micMuted {
                            Text("��˷��Ѿ������Ự�������в����ܼƷѡ�����ʹ�����ֹͣ��")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Button {
                        if model.active { model.stop() } else { model.start() }
                    } label: {
                        Label(buttonTitle, systemImage: model.active ? "stop.fill" : "waveform")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 19)
                    }
                    .buttonStyle(.borderedProminent).tint(model.active ? Color.primary : teal)
                    .disabled(model.phase == .finishing).accessibilityIdentifier("mainAction")
                    Text("ʹ�û�ɽ����ٷ�ͬ������ �� ��Ҫ����\n��Ƶ�ᷢ������ɽ���棬��Ӧ�ò�����¼����")
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        .padding(.bottom, 18)
                }.padding(.horizontal, 22).padding(.top, 12)
            }
            .background(Color(red: 0.96, green: 0.97, blue: 0.95))
            .navigationTitle("����ͬ��").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { model.showSettings = true } label: { Image(systemName: "slider.horizontal.3") }
                        .accessibilityLabel("����").disabled(model.active)
                }
            }
            .sheet(isPresented: $model.showSettings) { SettingsView(model: model) }
        }.tint(teal)
    }
    private var buttonTitle: String {
        switch model.phase {
        case .idle: return model.keySaved ? "��ʼͬ��" : "���� API Key"
        case .connecting: return "ȡ������"
        case .live: return "ֹͣͬ��"
        case .finishing: return "������β��"
        }
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("�öԻ���\n��Ȼ������").font(.system(size: 34, weight: .semibold, design: .rounded))
            Text("ʵʱ˫����Ļ �� ���ü��ķ���").font(.subheadline).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
    }
    private var directionPicker: some View {
        HStack {
            Image(systemName: "globe").foregroundStyle(teal)
            Picker("���뷽��", selection: $model.direction) {
                ForEach(model.directions.indices, id: \.self) { Text(model.directions[$0]).tag($0) }
            }.pickerStyle(.menu).tint(.primary).disabled(model.active)
            Spacer()
            Text("S2S").font(.caption.monospaced()).foregroundStyle(teal)
        }.padding(12).background(.white, in: RoundedRectangle(cornerRadius: 18))
    }
    private var statusCard: some View {
        HStack(spacing: 16) {
            Image(systemName: model.playing ? "speaker.wave.2.fill" : "waveform")
                .font(.system(size: 25)).foregroundStyle(teal)
                .frame(width: 62, height: 62)
                .background(teal.opacity(model.active ? 0.18 : 0.08), in: Circle())
                .symbolEffect(.variableColor, isActive: model.phase == .live)
            VStack(alignment: .leading, spacing: 6) {
                Text(model.playing ? "���ڲ�������" : model.status).font(.headline)
                Text(model.active ? model.route : "���϶�������ֱ��ʹ��������")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if model.phase == .connecting || model.phase == .finishing { ProgressView() }
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(teal.opacity(0.05), in: RoundedRectangle(cornerRadius: 22))
    }
    private func captionCard(title: String, subtitle: String, captions: [Caption], empty: String,
                             translated: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title).font(.headline)
                Text(subtitle).font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1.5)
                    .foregroundStyle(.secondary)
                Spacer()
                if translated && model.playing { Image(systemName: "speaker.wave.2.fill").foregroundStyle(teal) }
            }
            if captions.allSatisfy({ $0.text.isEmpty }) {
                Text(empty).foregroundStyle(.secondary).font(.body).padding(.vertical, 10)
            } else {
                ForEach(captions.suffix(8)) { caption in
                    if !caption.text.isEmpty {
                        Text(caption.text).font(.system(size: translated ? 22 : 18, weight: translated ? .medium : .regular))
                            .foregroundStyle(translated ? teal : Color.primary)
                            .opacity(caption.final ? 1 : 0.7).textSelection(.enabled)
                    }
                }
            }
        }.frame(maxWidth: .infinity, minHeight: 94, alignment: .topLeading)
            .padding(20).background(.white, in: RoundedRectangle(cornerRadius: 22))
    }
}

private struct SettingsView: View {
    @ObservedObject var model: InterpreterModel
    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label(model.keySaved ? "�ѱ��� API Key" : "��δ���� API Key",
                          systemImage: model.keySaved ? "checkmark.shield" : "key")
                    SecureField(model.keySaved ? "������ Key ���滻" : "ճ����ɽ���� API Key", text: $key)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityIdentifier("apiKeyField")
                    Button("���沢����") {
                        do { try model.saveKey(key); key = ""; dismiss() }
                        catch { self.error = error.localizedDescription }
                    }.disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if model.keySaved {
                        Button("�Ƴ����� API Key", role: .destructive) {
                            do { try model.deleteKey() } catch { self.error = error.localizedDescription }
                        }
                    }
                } header: { Text("��������ƾ��") } footer: {
                    Text("Key �����뱾��Կ�״�����д����Ŀ����־����ͨ���á���ʹ���ѿ�ͨͬ���������� Key�����ð���ɽ�������Ʒѡ�")
                }
                Section("��������") {
                    Toggle("�Զ���������", isOn: $model.playbackEnabled)
                    Text("���ùٷ� S2S ������δָ����ɫʱ������Ĭ�ϸ�������˵���˵���ɫ��")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text("�װ��豣��Ӧ����ǰ̨�������̨����Ƶ���ж�ʱ��������ӣ��Ự�����ڼ���Ļ���ֻ��ѡ�")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("��������˽") {
                    Link("��ͨͬ������ / API Key ����", destination: URL(string: "https://console.volcengine.com/speech/new/setting/apikey")!)
                    Link("�ٷ�ͬ�������ĵ�", destination: URL(string: "https://docs.volcengine.com/docs/doubao-voice/simultaneous-interpretation?lang=zh")!)
                    Text("��˷���Ƶ��ʵʱ��������ɽ���档��Ӧ�ò�����¼������Ļ�������ڵ�ǰ�ڴ�Ự�С��붹�� App ���˺Ź�����")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }
            .navigationTitle("����").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("���") { dismiss() } } }
        }.tint(teal)
    }
}
