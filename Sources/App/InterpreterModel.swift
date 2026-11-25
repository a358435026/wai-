import AVFoundation
import Combine
import Foundation
import UIKit

@MainActor
final class InterpreterModel: ObservableObject {
    enum Phase: Equatable { case idle, connecting, live, finishing }
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var source = CaptionLane()
    @Published private(set) var translation = CaptionLane()
    @Published private(set) var errorMessage: String?
    @Published private(set) var status = "׼������"
    @Published private(set) var playing = false
    @Published private(set) var route = "������ / ����"
    @Published var direction = 0
    @Published var micMuted = false
    @Published var playbackEnabled = true {
        didSet { if !playbackEnabled { audio?.clearPlayback() } }
    }
    @Published var keySaved = KeychainStore.read() != nil
    @Published var showSettings = false
    private var client: ASTClient?
    private var audio: AudioIO?
    private var streamContinuation: AsyncStream<Data>.Continuation?
    private var sendTask: Task<Void, Never>?
    private var connectionTask: Task<Void, Never>?
    private var deadlineTask: Task<Void, Never>?
    private var drainTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private var generation = UUID()
    let directions = ["���� �� English", "English �� ����", "��Ӣ�Զ�����"]
    var active: Bool { phase != .idle }
    var configuration: ASTConfiguration {
        switch direction {
        case 1: return ASTConfiguration(source: "en", target: "zh")
        case 2: return ASTConfiguration(source: "zhen", target: "zhen")
        default: return ASTConfiguration()
        }
    }

    init() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification,
                                             object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.active else { return }
                self.fail("��Ƶ�����������Ӧ���жϡ��뷵�غ����¿�ʼ��")
            }
        })
        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification,
                                             object: nil, queue: .main) { [weak self] notification in
            let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            Task { @MainActor in
                guard let self else { return }
                self.route = self.audio?.routeName ?? "������ / ����"
                if self.active && reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue {
                    self.fail("��������Ƶ�豸�ѶϿ�����ȷ�ϲ����豸�����¿�ʼ��")
                }
            }
        })
        observers.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification,
                                             object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.active else { return }
                self.cleanup()
                self.status = "��ֹͣ��Ӧ�ý����̨"
            }
        })
    }
    deinit { observers.forEach { NotificationCenter.default.removeObserver($0) } }

    func saveKey(_ value: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try KeychainStore.save(trimmed)
        keySaved = true
    }
    func deleteKey() throws { try KeychainStore.delete(); keySaved = false }
    func clearCaptions() { source = CaptionLane(); translation = CaptionLane(); errorMessage = nil }

    func start() {
        guard phase == .idle else { return }
        guard let key = KeychainStore.read(), !key.isEmpty else { showSettings = true; return }
        clearCaptions(); micMuted = false
        phase = .connecting; status = "����������˷粢����"
        let run = UUID(); generation = run
        connectionTask = Task { [weak self] in
            guard let self else { return }
            let allowed = await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
            }
            guard self.generation == run && !Task.isCancelled else { return }
            guard allowed else { self.fail("��˷�Ȩ��δ���������� iPhone ��������������ͬ��ʹ����˷硣"); return }
            self.status = "�������ӻ�ɽ����"
            let client = ASTClient(onResponse: { [weak self] response in
                guard let self, self.generation == run else { return }
                self.receive(response)
            }, onError: { [weak self] error in
                guard let self, self.generation == run else { return }
                self.fail(self.describe(error))
            })
            self.client = client
            self.deadlineTask = Task { [weak self] in
                do { try await Task.sleep(nanoseconds: 20_000_000_000) } catch { return }
                guard let self, self.generation == run, self.phase == .connecting else { return }
                self.fail("���ӳ�ʱ���������硢API Key ��ͬ����������Ƿ��ѿ�ͨ��")
            }
            do { try await client.connect(key: key, configuration: self.configuration) }
            catch { if self.generation == run && !Task.isCancelled { self.fail(self.describe(error)) } }
        }
    }

    private func receive(_ response: ASTResponse) {
        if ![0, 21000, 20000000].contains(response.statusCode) || response.event == 153 {
            fail("������� \(response.statusCode)��\(response.message.isEmpty ? "�������Ȩ�ޡ������������á�" : response.message)")
            return
        }
        switch response.event {
        case 150:
            guard phase == .connecting else { return }
            deadlineTask?.cancel()
            beginAudio()
        case 650: source.begin()
        case 651: source.append(response.text)
        case 652: source.end()
        case 653: translation.begin()
        case 654: translation.append(response.text)
        case 655: translation.end()
        case 352:
            guard playbackEnabled else { return }
            do { try audio?.play(response.audio) } catch { fail(error.localizedDescription) }
        case 152, 151:
            finishReceiving()
        default: break // Includes usage, sentence boundaries, and future events.
        }
    }

    private func beginAudio() {
        let run = generation
        let stream = AsyncStream<Data>(bufferingPolicy: .bufferingOldest(16)) { self.streamContinuation = $0 }
        let continuation = streamContinuation!
        let audio = AudioIO()
        self.audio = audio
        audio.onPlaybackChanged = { [weak self] value in self?.playing = value }
        do {
            try audio.start(emit: { [weak self] data in
                if case .dropped = continuation.yield(data) {
                    Task { @MainActor in
                        guard let self, self.generation == run else { return }
                        self.fail("���緢�ͻ�ѹ����ֹͣͬ���Ա��������ӳ١�������������ԡ�")
                    }
                }
            }, failure: { [weak self] message in
                Task { @MainActor in
                    guard let self, self.generation == run else { return }
                    self.fail(message)
                }
            })
            phase = .live; status = "��������"
            route = audio.routeName
            UIApplication.shared.isIdleTimerDisabled = true
            sendTask = Task { [weak self] in
                do {
                    for await data in stream {
                        guard let self, self.generation == run, !Task.isCancelled, let client = self.client else { break }
                        let packet = self.micMuted ? Data(repeating: 0, count: data.count) : data
                        try await client.sendAudio(packet)
                    }
                } catch {
                    guard let self, self.generation == run, !Task.isCancelled else { return }
                    self.fail(self.describe(error))
                }
            }
        } catch { fail(error.localizedDescription) }
    }

    func stop() {
        guard phase != .idle else { return }
        if phase == .connecting { cleanup(); status = "��ȡ������"; return }
        guard phase == .live else { return }
        phase = .finishing; status = "����������һ��"
        audio?.stopCapture(); streamContinuation?.finish()
        let run = generation
        let sender = sendTask
        deadlineTask = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 12_000_000_000) } catch { return }
            guard let self, self.generation == run else { return }
            self.fail("����δ��ʱ�����β�����������ѹرա�����ʾ����Ļ������")
        }
        Task { [weak self] in
            await sender?.value
            guard let self, self.generation == run else { return }
            do { try await self.client?.finish() } catch { self.fail(self.describe(error)); return }
        }
    }
    private func finishReceiving() {
        deadlineTask?.cancel()
        phase = .finishing; status = "���ڲ�������"
        audio?.stopCapture(); streamContinuation?.finish()
        sendTask?.cancel()
        client?.disconnect()
        let run = generation
        drainTask = Task { [weak self] in
            for _ in 0..<220 {
                guard let self, self.generation == run else { return }
                if self.audio?.isPlaying != true { break }
                do { try await Task.sleep(nanoseconds: 100_000_000) } catch { return }
            }
            guard let self, self.generation == run else { return }
            self.source.end(); self.translation.end()
            self.cleanup(); self.status = "����ͬ���ѽ���"
        }
    }
    func fail(_ message: String) {
        cleanup(); errorMessage = message; status = "������ֹͣ"
    }
    private func cleanup() {
        generation = UUID()
        deadlineTask?.cancel(); drainTask?.cancel(); connectionTask?.cancel()
        audio?.shutdown(); audio = nil
        streamContinuation?.finish(); streamContinuation = nil
        sendTask?.cancel(); sendTask = nil
        client?.disconnect(); client = nil
        playing = false; phase = .idle; micMuted = false
        UIApplication.shared.isIdleTimerDisabled = false
    }
    private func describe(_ error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return "��������ʧ�ܣ�\(nsError.code)�����������磬�Լ���ɽ���� API Key������ͬ������Ȩ�ޡ�"
        }
        return error.localizedDescription
    }
}
