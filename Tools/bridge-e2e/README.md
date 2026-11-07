# Bridge end-to-end check

The app injects JavaScript into promptugal.news (`PrompTugal/Bridge/BridgeScripts.swift`). These scripts run that
exact JavaScript in Chromium against the live website, so a change to the website or to the scripts shows up here
without a device.

    python3 Tools/bridge-e2e/extract.py
    NODE_PATH=$(npm root -g) node Tools/bridge-e2e/run.js      # schedule, my-day, meter, top-up hiding
    NODE_PATH=$(npm root -g) node Tools/bridge-e2e/relay.js    # window.ptApp.call relay, with a stand-in handler

Chromium has no WebKit content worlds, so the relay runs both scripts in one world; the origin check and the
content world are native and covered by reading the code. It writes only to a throwaway browser profile.

Result on 7 November 2026, 07:14 UTC (site v0.1.414):

- The app's schedule write repaints the website's own button ("☆ Add to my day" → "★ In my day"),
  `NRSchedule.has` agrees, and /my-day/ lists the pick. A toggle on the website is read back.
- Meter: £4.99 → credit 500p "appstore-test-1" → £9.99; the same reference again → "already".
- Top-up: the Stripe button on /account/ and the link on /account/top-up.html are hidden; "Top up in the app" shows.
- Relay: `window.ptApp` appears with version and ops; a call returns the handler's reply; a refused op rejects with its
  message; the website's own toggle reaches the app as `schedule.pageChanged`, and meter changes as `meter.pageChanged`.
