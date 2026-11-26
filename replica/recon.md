# Voice interpretation reference

User screenshots define the requested hierarchy: full-screen pastel background, top scene selector and captions toggle, a listening orb when captions are absent, a scrolling conversation, microphone/playback controls and an end button.

This is a new independent interpretation app. It does not extract assets, code, branding or private service credentials from Doubao. The reference screenshot's general-purpose voice conversation, camera and screen sharing are outside the AST interpretation capability.

Screens: S01 listening/conversation (idle, connecting, live, speaking, muted, finishing, error); S02 scene/direction picker; S03 local credential/settings; S04 session diagnostics.

Core flow: configure a personal API key, choose direction, request microphone access, prepare audio, open AST, wait for SessionStarted, send PCM, display subtitles and play translation, finish session.
