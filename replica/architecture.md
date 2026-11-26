# Independent native client

SwiftUI UI, AudioQueue capture and independent AVAudioEngine playback, a dedicated URLSession WebSocket per AST session, native protobuf wire codec. Keychain holds user-entered personal credentials. No backend, original IPA runtime, private endpoints or packaged credentials.

VoiceTheme in Sources/App/ConversationView.swift owns the palette and main geometry. The view uses the existing InterpreterModel, not a simulated translation layer. Scene shortcuts configure explicit translation direction; automatic zhen reversal remains a labeled experimental option after live upstream 55000001 errors; both acquire local microphone audio. Caption history stays in memory only.

One socket belongs to one client session, and model generation IDs reject stale callbacks. A 2026-11-26 handshake check found an empty response SessionID. The earlier inference that UUID filtering caused the timeout was incorrect: the old code already allowed empty IDs. Dedicated socket generation remains the routing authority. The device-side cause of missing audio packets needs real-device counters; it has not been established from desktop API tests. Capture is prepared before connection; first-frame and ongoing capture watchdogs detect local stalls. Backpressure remains bounded.

Playback interruption discards the current sentence locally until the next TTS sentence start. It does not cancel server-side translation or charges.


0.2.1 replaces the input tap/voice-processing/converter chain after the device reported no effective captured packet with permission granted. PCMInputQueue owns native recording buffers and dispatches raw PCM and metering; offline microphone testing uses this same path without creating ASTClient. A playback mixer tap supplies actual output-level feedback to the Canvas/TimelineView renderer. Input callback and byte counts distinguish native capture failure from framing/sending failure. There is no claim of full-duplex speaker echo cancellation: while built-in speaker playback is active and during a 350ms tail, uploaded capture is replaced with silence; headphone routes retain duplex upload.


0.3.0 adds a typed language capability catalog and validates source/target combinations before starting a session. Selected languages and subtitle preference are non-secret UserDefaults values. Unsupported default speech targets request true S2T without target_audio, rather than generating chargeable audio and merely muting playback. Explicit subtitle-only mode does the same. AudioQueue and playback paths are unchanged from the phone-confirmed 0.2.1 build.
