# 06 · Monetization

> The app opens three honest revenue lines: a supporter subscription for native extras, sponsor slots in the agenda and widgets, and team packs sold directly to organisations. One existing feature is a review risk: the website’s Stripe top-up for the reading meter, shown inside the app.

## The App Store rules that decide this

| Rule | What it says (short form) | What it means for us |
| --- | --- | --- |
| 3.1.1 In-app purchase | Unlocking digital content or features in the app must use in-app purchase. Unlocking with licence keys or QR codes is not allowed. | Anything paid that people use in the app goes through StoreKit, outside the US storefront. |
| 3.1.1(a) and the US storefront | In the US storefront, apps may link to outside purchases. The commission Apple may charge on those was still before the courts in 2026 (status for November 2026 not confirmed). | A web checkout link is allowed for US users, but not for EU or Portuguese users. |
| 3.1.3(a) Reader apps | Newspapers, magazines and books may skip in-app purchase for content bought elsewhere, and may apply for the External Link Account Entitlement. | PrompTugal.news counts as news, so the reader-app route is open to it. |
| 3.1.3(c) Enterprise services | Apps sold directly to organisations for their own people may use other payment methods. | **Team packs can be invoiced directly.** |
| 3.1.3(e) Goods and services outside the app | Real-world services must not use in-app purchase. | Side-event tickets, meetups and workshops are paid by card or Apple Pay, never IAP. |
| 4.5.4 Push notifications | Notifications must not be used for advertising without explicit opt-in. | Sponsor content stays in the agenda and widgets, never in alerts. |
| EU DMA terms (from 1 October 2026) | One set of EU terms, with a 5% Core Technology Commission on some sales. App Store IAP rates differ by programme. | Check the Small Business Program (15%) before pricing. |

## The three lines

### 1. Supporter subscription (StoreKit 2)

A yearly or summit-season subscription that unlocks **native extras**, never the journalism:

- Live Activities and the Lock Screen "now and next" for every session, not just your picks;
- unlimited vault storage for notes, voice and photos (the free tier covers picks and stars);
- private briefing packs: an on-device summary of a company or person before a meeting (Apple Intelligence devices only);
- early access to new native features.

Articles, the agenda and the basic schedule stay free on the web and in the app. This keeps PrompTugal’s promise that "readers need no account". It also lets `SubscriptionStoreView` (iOS 17) do the purchase screen with very little code.

### 2. Sponsor slots

- One clearly labelled sponsor line in the Now tab, the agenda day header and the medium widget, sold per day of the summit.
- One "presented by" line on a curated side-event list.
- No tracking: a sponsor gets counts of views and taps from the app’s own analytics, which honours the website’s pause switch and Do Not Track. That means no App Tracking Transparency prompt.

This fits the newsroom’s independence only if the label is plain, and if sponsors never influence what the newsroom writes. The disclosure page should say so before the first sponsor goes live.

### 3. Team packs (B2B)

What the RiskMandate team built for itself (command centres, briefs, per-person vaults, capture, an app that opens on "my day") is a product for any team working an event. It would be sold to the organisation and invoiced directly under 3.1.3(c), then turned on in the app with the team’s vault, not with a code (codes are not allowed under 3.1.1). Apple Business Manager custom apps are the route if a customer wants a private build.

This line is closest to the RiskMandate story: an event team running on encrypted, audited vaults, with named owners and keys per person.

## The risk to fix first

The website’s reading meter offers a Stripe Payment Link top-up (`/account/`). Inside the app’s web view, that is a purchase of digital content outside in-app purchase. Outside the US storefront, that can fail review.

Options, in order of preference:

1. **The app tells the page it is in the app** (`window.ptApp`), and the page hides the top-up there. A note says "top up on the web". That is allowed for reader apps, and the entitlement makes it a link.
2. Offer reading credit as an **in-app consumable** in the app. This is more work, Apple takes its cut, and the website and app balances must then agree.
3. Remove the meter from the app view entirely.

## Order

1. Fix the meter risk before the first external TestFlight review.
2. Sell sponsor slots by hand for the summit. No code is needed beyond a labelled line in the feed.
3. Team packs: offer them to one other event team after the summit, using what the team actually used.
4. Supporter subscription: once there are native extras worth paying for, after phase 2 of the roadmap.
