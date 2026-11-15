# PTTalk: attribution

Parts of this package are ported from **VoiceDebrief** (https://github.com/VoiceDebrief/VoiceDebrief__App__iOS),
licensed under the Apache License, Version 2.0 (http://www.apache.org/licenses/LICENSE-2.0), and changed for
PrompTugal:

| Here | From VoiceDebrief | What changed |
| --- | --- | --- |
| `TalkWire.swift` | `Apps/VoiceDebrief/Sources/Engine/DeveloperLane.swift` | Header line + bytes messages and 2 MB parts kept; kinds are `sgit/talk/*` (so `tools/conductor/conductor.py drain` files them), a `meta.json` per item, reassembly with SHA-256 checks. The lane link and sealing live in PTLanes (`SealedLane`). Nothing is built in. |
| `TalkSender.swift` | `Engine/PictureSender.swift`, `DeveloperLane.send`, `Engine/NetworkWatch.swift` | Same five tries and waits; a retry resumes at the part that failed; a transport seam for tests. |
| `InterviewRecorder.swift` | `Engine/VoiceRecorder.swift`, `Engine/LiveTranscriber.swift` | AAC instead of WAV; the kept transcript is made from the file by `SFSpeechRecognizer` on the device (iOS 18); SpeechAnalyzer live preview on iOS 26. |
| `Views/ConductorSendView.swift` | `UI/PictureSheet.swift` | Paste a screenshot or choose a photo; send status. |
| `MediaPrep.swift` | `PictureSender.jpeg` | Plus video compression. |

The receiving end is VoiceDebrief's `tools/conductor/conductor.py` (or any receiver that reads the same format,
see `TalkWire`).
