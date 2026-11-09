# M-iPad Stage B: Gemma 4 E2B on the iPad, the preparation

> From m-ipad@ios.PrompTugal.dinis, for conductor.B@ios.PrompTugal.dinis and conductor@web-summit.dinis (relay to Dinis and to mobile@promptugal.ai.dinis). 9 November 2026.

Stage A, the Workbench with Apple Foundation Models, is on `dev` (63333c6, merged as 8b05eff). This page prepares Stage B: the same Gemma 4 E2B as Android, in the RiskMandate app only.

## 1. The increased-memory entitlement (needs Dinis or an admin, about 5 minutes)

Gemma 4 E2B at 4-bit takes about 2.5–3 GB resident, plus the KV cache. That is close to the default per-app memory limit on an 8 GB device such as the iPhone 16 Plus, so iOS could stop the app mid-answer. `com.apple.developer.kernel.increased-memory-limit` raises the limit.

**It is staged, not switched on.** `Apps/RiskMandate/RiskMandate-LLM.entitlements` holds it, and the app still signs with the empty `RiskMandate.entitlements`. Switching it on before the App ID has the capability would break the next RiskMandate TestFlight upload: `scripts/release/check-profiles.sh` fails when a profile lacks an entitlement the target asks for.

To switch it on:
1. **Dinis or an admin:** in the Apple Developer portal, go to Identifiers, then `ai.riskmandate.app`, and tick **Increased Memory Limit**. Then save.
2. **Manual signing:** regenerate the RiskMandate App Store profile and update its secret (`IOS_PROFILE_RISKMANDATE_APP_BASE64`). With automatic signing (`-allowProvisioningUpdates`), Xcode fetches a new profile itself.
3. **m-ipad:** point `CODE_SIGN_ENTITLEMENTS` at `RiskMandate-LLM.entitlements` (or move the key into `RiskMandate.entitlements`). Then run a release dry run (`ios-release.yml`, `dry_run: true`) to see the profile check pass.

No other app changes. The public PrompTugal app and the Team app are untouched.

## 2. Where the model file lives: the proposal

| Option | For | Against |
| --- | --- | --- |
| **A. Hugging Face, pinned revision** (`litert-community/...` for LiteRT-LM, `mlx-community/...` for MLX) | Free, fast CDN, it is where Android gets its file, and there is nothing for us to run | A third-party host in the app. Gemma's licence must be accepted on HF for gated repos (a token we must not ship) |
| **B. Our own host** (a release asset or a bucket behind `riskmandate.ai`) | One host we control, no token, and the same URL for iOS and Android | ~3 GB per model to host and serve. Licence notice to carry |
| C. In the app bundle | Works offline from install | Gemma alone makes a ~3 GB app. Too big for TestFlight testers on mobile data |

**Proposal: B, with A as the fallback while B is set up.**
- Serve the file from our own host, under the RiskMandate domain.
- Pin it by **SHA-256**. The app refuses a file whose hash differs.
- The app downloads only when the user taps "Download model (≈ 3 GB)" on the Workbench. It shows the size first, prefers Wi-Fi, and can be cancelled and resumed (a background `URLSession`).
- The file is stored in Application Support, excluded from iCloud backup.
- That adds **one network host, to the RiskMandate app only.** The public PrompTugal app gets no new host, and the Team app comes later.
- The Workbench shows Gemma's licence notice next to the model.

**Decisions needed from Dinis:**
- B or A?
- If B, the URL. Android should use the same one, so the two apps compare the very same file and its SHA-256.

## 3. The shared scenario reader (done, on `split/m-ipad`)

- **The files.** The app bundles the 13 `abp-tooltest/1` case files (40 cases) from **PrompTugal/PrompTugal__App__Mobile**, `scenarios/tool-tests/`, at commit `7433286`.
  - They are copied unchanged into `Apps/RiskMandate/Resources/ToolTests/` by `scripts/apps/sync-tool-tests.sh`.
  - All the data is synthetic. The planted values in `08_secret.json` are the repository's own `PLANTED-…-do-not-use` fakes.
- **The reader.** `Apps/RiskMandate/Sources/Workbench/ToolTestCase.swift` follows the README and `schema.json`. It reads every field, and keeps check parameters, fake results and schemas as JSON, so a new check kind still reads.
- **Validation.** The reader checks what can be checked without a model:
  - the format and `synthetic`;
  - the id pattern;
  - at most 5 tools;
  - one fake per tool;
  - the user message first;
  - `max_steps` of at most 6;
  - known check kinds.
- **Tests.** `ToolTestCaseTests` reads all 13 files and checks the 40 unique ids.

**Next, with mobile@:**
- The checker (the 16 check kinds) runs on the `reference` and `wrong` scripts as its fixtures, as the README asks.
- Then the runner, in `native` mode with Foundation Models tool calling, and in `text` mode.
- Then `abp-eval-run/1` records, and the `abp-lab-loop-export/1` export so the iPad's runs import next to the Lenovo's.
- The bridge (`bridge/ops.json`, `llm.*` first) follows the same names.

**Questions for mobile@:**
1. Should iOS read the cases straight from the repository at build time (a pinned copy, as now), or from the vault at run time, as Android does?
2. Is `results.export` the op for the loop export?

## 4. Runtime choice for Gemma

Two candidate runtimes:
- **LiteRT-LM:** I still have to confirm that its iOS build (Metal GPU) loads the same `.litertlm` file as Android.
- **MLX Swift:** native on Apple silicon. It needs the MLX-format weights, which is a different file from Android's.

**Plan:** try LiteRT-LM first, for the like-for-like comparison, and time-box it to half a day. If it doesn't load, go to MLX. Either sits behind the same `OnDeviceModel` shape as Foundation Models, with tokens per second, time to first token and resident memory.

Brief: brief:2026-11-09-on-device-llm-workbench
For: conductor@web-summit.dinis
