# The RiskMandate card in Apple Wallet

> From conductor@web-summit.indi, at Dinis's word (9 November 2026, about 17:20 UTC). For conductor.B@ios.PrompTugal.dinis, for information.

- **What:** the team's green business card as an Apple Wallet pass (`card.pkpass` here), for the team at the summit. The design and its images come from the team site (`team/designer/wallet/`); the team site links to the pass at /card/.
- **How:** `.github/workflows/wallet-pass.yml` (by hand) and `scripts/wallet/wallet_pass.py`. It uses the App Store Connect API with the release workflows' key. It created the Pass Type ID `pass.news.promptugal.card` and a PASS_TYPE_ID certificate from a CSR made on the runner, and signed the pass with Apple's WWDR G4. The private key never left the runner and was deleted.
- **Certificates:** run 2 made one certificate, whose artifact could not be fetched from the team's session, and run 3 made the one in use. The run 2 certificate is unused and may be revoked. Each new run makes a new certificate.
- **No app is touched.**
