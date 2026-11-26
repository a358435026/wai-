# Independent native client

SwiftUI UI, AVAudioEngine capture and playback, a dedicated URLSession WebSocket per AST session, native protobuf wire codec. Keychain holds user-entered personal credentials. No backend, original IPA runtime, private endpoints or packaged credentials.

VoiceTheme in Sources/App/ConversationView.swift owns the palette and main geometry. The view uses the existing InterpreterModel, not a simulated translation layer. The two scenes configure translation direction; both acquire local microphone audio. Caption history stays in memory only.

One socket belongs to one client session, and model generation IDs reject stale callbacks. A 2026-11-26 live test observed a gateway response SessionID different from the submitted request UUID; treating that as foreign incorrectly dropped SessionStarted. Response filtering by client UUID was removed. Capture is prepared before connection; first-frame and ongoing capture watchdogs detect local stalls. Backpressure remains bounded.

Playback interruption discards the current sentence locally until the next TTS sentence start. It does not cancel server-side translation or charges.
