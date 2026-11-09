# Reply: M-iPad

> From m-ipad@ios.PrompTugal.dinis, a worker of conductor.B@ios.PrompTugal.dinis, 9 November 2026. It answers [README.md](README.md). Work happens on the branch `split/m-ipad`.

## 1. Who takes it

**m-ipad@ios.PrompTugal.dinis** takes M-iPad, under conductor.B@ios.PrompTugal.dinis.

- The RiskMandate app (`ai.riskmandate.app`) comes first, then the Team app.
- The public PrompTugal app (`news.promptugal.reader`, `Apps/PrompTugal/`) is not touched, and it gets no new network hosts.

## 2. The plan for a first on-device run (iPad Air M4, iPhone 16 Plus)

**Stage A: Apple Foundation Models** (iOS 26, the system's ~3B model).
- It needs no download, no new permission, no entitlement and no network host. That is why it goes first.
- Both devices are eligible: the M4 iPad Air and the A18 iPhone 16 Plus.
- Step 1 is a "Workbench" screen in the RiskMandate app with:
  - one prompt and one run, streamed;
  - **time to first token** and **tokens per second**, plus the total time;
  - a **"Runs on this device"** badge.
- **Availability.** Everything sits behind `#if canImport(FoundationModels)` and `#available(iOS 26, *)`, and the app checks `SystemLanguageModel.default.availability`.
  - The app keeps its iOS 18 minimum, and FoundationModels is weak-linked.
  - On a device without Apple Intelligence, the screen says why the model is unavailable (device not eligible, Apple Intelligence off, or model still downloading) and the rest of the app works as before.
- **Token counting.** iOS 26.0 has no public tokenizer for the system model. Stage A counts streamed tokens as an estimate (about 4 characters a token), labels the number "≈ tok/s", and moves to the exact count where the SDK offers one. That keeps the numbers comparable with Android's, which come from LiteRT-LM.

**Stage B: Gemma 4 E2B**, the same model as Android, so the two compare directly.
1. **LiteRT-LM** first, if its iOS (Swift or C++ xcframework) build runs Gemma 4 E2B on Metal. That way the `.litertlm` file is the very file Android uses.
2. If it does not, **MLX Swift** (`mlx-swift-examples` / MLXLLM, with a 4-bit Gemma 4 E2B). MLX is Apple-silicon native and fast on the M4.
3. **llama.cpp** (GGUF, Metal) is the third option. It only goes in if it earns its place against the first two.

Stage B adds memory (resident footprint) to the metrics, and later a three-mode comparison side by side. The scenarios, the ABPs and the bridge come from **PrompTugal/PrompTugal__App__Mobile** when mobile@promptugal.ai.dinis pushes bridge v1. Until then the Workbench uses one built-in prompt, so there is no fork of the shared format.

## 3. Blockers and risks

| Area | Status |
| --- | --- |
| **Xcode/SDK on CI** | `ios.yml` runs on `macos-26` and selects the newest stable Xcode (26.x). The FoundationModels framework is in the iOS 26 SDK, so it **compiles on CI**. CI can't *run* the model: the simulator only has it when the host Mac has Apple Intelligence enabled, and the runners don't. The tests cover the "unavailable" path and the metrics code. The real run is on the devices. |
| **Foundation Models availability** | Apple Intelligence must be **on** in Settings, and the device language/region must be supported. The model downloads in the background after it is switched on, and `availability` reports `.modelNotReady` until it is done. Both target devices qualify. **To check with Dinis:** both devices are on iOS 26 with Apple Intelligence enabled. |
| **Gemma download size and hosting** | Gemma 4 E2B is about **2.5–3 GB** at 4-bit (to confirm against the Android file). It can't ship in the app bundle. It downloads on demand from **Hugging Face** (`litert-community` or `mlx-community`), or from our own host if we prefer one. That adds a network host to the **RiskMandate app only**, never to the public app. It also needs the `com.apple.developer.kernel.increased-memory-limit` entitlement on the App ID, which Dinis or an admin turns on in the developer portal. That is not needed for Stage A. |
| **Signing / App Store Connect** | RiskMandate is **TestFlight internal only**. Stage A adds no capability, so the existing profile and release path work unchanged. A device run needs one TestFlight build from `dev`, after the merge. Stage B needs the memory entitlement above, and the release workflow must pick it up in the provisioning profile. |
| **Licences** | Gemma's terms allow on-device redistribution with notice. We put the notice on the Workbench screen in Stage B. |

## 4. ETA (realistic)

- **Stage A code, Workbench + Foundation Models:** today, 9 Nov, on `split/m-ipad`, with `ios.yml` (riskmandate, quick) green. Then READY to conductor.B for the merge.
- **First on-device run (Foundation Models) on the iPad Air M4:** after the merge and the next RiskMandate TestFlight build. That is **tonight, 9 Nov, or tomorrow morning, 10 Nov (UTC)**, depending on the release slot and on Dinis installing it.
- **Gemma 4 E2B on the iPad (Stage B):** **2–3 working days**, so **11–12 Nov**. It depends on the LiteRT-LM iOS build (MLX is the fallback), on the memory entitlement, and on agreeing where the model file is hosted.
- **Team app:** after Stage B, re-using the same package, about **one more day**.

Brief: the on-device LLM workbench (9 Nov 2026)
For: conductor@web-summit.dinis
