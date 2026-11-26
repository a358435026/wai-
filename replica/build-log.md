# Build log

2026-11-26: S01–S04 rebuilt around full-screen conversation. Official API probes produced source, translation and PCM in both explicit directions. A later handshake check found an empty response UUID, so the earlier UUID-filter root-cause inference was retracted. Device capture/sending now has preflight and watchdog diagnostics; actual microphone retest remains pending. API key was supplied at process runtime only. CI and real-phone validation results will be recorded in VALIDATION.md.

0.2.0 final source b6ee9b3: 8 core tests and ARM64 iPhone archive passed. Two CI attempts failed to boot the cloud simulator before app UI tests could run. No new screenshot or device-runtime pass is claimed. Release IPA was downloaded and minimum iOS15.0/ZIP integrity/no embedded supplied key verified.

0.2.1: user device still has permission but no first PCM packet. Replaced input graph with AudioQueue capture, added offline microphone probe and raw callback/byte diagnostics, actual playback-level metering, and continuously redrawn fluid visual. Removed full-duplex speaker/AEC claim; speaker playback suppresses uploaded input, headphones allow duplex. Cloud verification pending.

User device result for0.2.1: callback count and microphone bytes increase continuously; speaking changes animation. Native capture and input feedback are now device-confirmed. Live AST caption/playback verification on that phone remains pending.

User then confirmed a real zh-en AST session on iPhone: Chinese source, English translation and English playback all work. This validates the native input-to-service-to-playback path, separate from visual fixtures. Long-session speaker echo and interruption testing are still outside this short device test.

0.2.1 build5: replaced the SwiftUI Menu label that failed AX scroll-to-visible with a normal 44pt button and native confirmation action panel. All10 core tests and3 UI tests passed in run45803138491. Final IPA integrity/version/minimum-iOS checks passed. Input/network/playback implementation is unchanged from the device-confirmed build4.

0.3.0:48-language source/target catalog with9 source dialects and auto mixed Chinese-English recognition. Invalid foreign-to-foreign and same-language pairs filtered;16 default speech targets; other targets automatically use actual S2T. Added searchable native navigation lists, swapping, persisted non-secret language preferences and explicit subtitle-only output setting. Provider comparison uses current primary docs; no untested provider adapter presented as working.
