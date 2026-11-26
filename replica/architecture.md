# Independent native client

SwiftUI UI, AVAudioEngine capture and playback, a dedicated URLSession WebSocket per AST session, native protobuf wire codec. Keychain holds user-entered personal credentials. No backend, original IPA runtime, private endpoints or packaged credentials.

VoiceTheme in Sources/App/ConversationView.swift owns the palette and main geometry. The view uses the existing InterpreterModel, not a simulated translation layer. Scene shortcuts configure explicit translation direction; automatic zhen reversal remains a labeled experimental option after live upstream 55000001 errors; both acquire local microphone audio. Caption history stays in memory only.

One socket belongs to one client session, and model generation IDs reject stale callbacks. A 2026-11-26 handshake check found an empty response SessionID. The earlier inference that UUID filtering caused the timeout was incorrect: the old code already allowed empty IDs. Dedicated socket generation remains the routing authority. The device-side cause of missing audio packets needs real-device counters; it has not been established from desktop API tests. Capture is prepared before connection; first-frame and ongoing capture watchdogs detect local stalls. Backpressure remains bounded.

Playback interruption discards the current sentence locally until the next TTS sentence start. It does not cancel server-side translation or charges.
