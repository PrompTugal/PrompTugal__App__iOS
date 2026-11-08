# Age rating, category, price and availability

> Answers for App Store Connect's age-rating questionnaire, in the 2025 version with the 4+, 9+, 13+, 16+ and 18+ ratings, plus the other settings Dinis enters by hand. Expected result: **4+**.

## Age rating questionnaire

| Question | Answer | Why |
| --- | --- | --- |
| Parental controls / in-app controls | No | None in the app |
| Age assurance | No | No accounts |
| Unrestricted web access | **No** | Web views stay on each site's own host (`WebsiteView.swift:212`); any other link opens in Safari. **Only true once R1 and N4 are fixed:** R1 is fixed on rc2 (WebsitesPublic.json). N4 is fixed on rc3: `WebPage` sends links to other sites to Safari (see [network-audit.md](network-audit.md)). |
| User-generated content | No | No posts, messages or comments; PTLanes is not linked |
| Messaging and chat | No | No user-to-user messaging. Ask is a question-and-answer assistant, not chat between people. |
| Advertising | No | None |
| Cartoon or fantasy violence | None | |
| Realistic violence | None | |
| Prolonged graphic or sadistic violence | None | |
| Profanity or crude humor | None | |
| Mature or suggestive themes | None | |
| Horror or fear themes | None | |
| Medical or treatment information | None | |
| Alcohol, tobacco or drug use or references | None | |
| Simulated gambling | None | |
| Sexual content or nudity | None | |
| Graphic sexual content and nudity | None | |
| Contests | None | |
| Guns or other weapons | None | |
| Health or wellness topics | No | |
| Gambling (real money) | No | |
| Loot boxes | No | |

If App Store Connect asks about generated content, answer that Ask produces AI text answers about the program, on request, behind a consent step. Ask is limited to summit topics by its system prompt (`AIContext.swift`). If Ask is hidden (B1 option (b)), the question does not apply.

**Made for Kids:** No.

## Category

- **Primary:** News. This matches `LSApplicationCategoryType` (`public.app-category.news`) and the newsroom behind the app.
- **Secondary:** Business. That is where people look for a conference app.

## Price and availability

- **Price:** Free (tier 0). No in-app purchases.
- **Availability:** All countries and regions. Participants travel from many countries, and their phones stay on their home App Store.
- **Distribution:** Public on the App Store, as Dinis decided today. The [readiness pack](../../2026-11-08__app-review-readiness/README.md) recommended Unlisted for the Team app; that advice is about the Team app, not this one.
- **Pre-orders:** No.
- **Release:** "Manually release this version". The conductor releases it once Apple approves, so it does not go live mid-change.
- **iPad:** Yes (universal app). Release supplies iPad 13" screenshots.
- **Apple silicon Macs and Apple Vision Pro:** Untick both. The app has not been tested there, and a reviewer may open it on a Mac.

## Export compliance

`ITSAppUsesNonExemptEncryption = NO` is in the build, so App Store Connect does not ask the question again. Basis: only Apple's encryption is used (CryptoKit, the Keychain, HTTPS). The yearly self-classification report is a legal call for Dinis ([readiness decision 5](../../2026-11-08__app-review-readiness/README.md#decisions-for-dinis)).
