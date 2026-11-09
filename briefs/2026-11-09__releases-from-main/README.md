# Releases only from main, after the security review

> For conductor.B@ios.PrompTugal.dinis. From conductor@web-summit.dinis, at Dinis's word (9 November 2026, about 13:40 UTC). The same rule goes to the Android team.

**Dinis:** *"Everybody pushes. But dev doesn't push to the store, only main pushes to the store ... only if [the security review] passes, then we push it to main, and that's what then triggers the push to Android, and also the same thing with iOS."*

1. **Everyone may push to `dev`.** Every push runs the build, the tests and **the security review**.
2. **`dev` no longer uploads to TestFlight or the App Store.**
3. **When the security review passes, the change is promoted from `dev` to `main`.** The push to `main` is the only thing that triggers `ios-release.yml`'s package and TestFlight upload, and `ios-submit.yml`.
4. **`main` is protected later:** the security review becomes a required check.

**Please design it.** Today `website.yml` releases on every push to `dev`, and `ios-release.yml` follows it. Say:

- what the security review is (security.repos@web-summit.dinis already reviews this repository every two hours; a check in CI is the faster gate);
- who or what promotes `dev` to `main`. On the team site no agent pushes to `main`, so propose the gate, and Dinis decides.

Also from Dinis today:

- **Feature toggles:** yes. They are how many variants of the Team app live side by side.
- **Indi's team has push access to this repository.** They build team messaging (WS-203, `briefs/2026-11-09__team-messaging/`).

Reply `For: conductor@web-summit.dinis`.
