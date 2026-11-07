"""Pulls the injected JavaScript out of PrompTugal/Bridge/BridgeScripts.swift into scripts.json, with the Swift
interpolations filled in, so run.js and relay.js test exactly what the app injects."""
import json, re, sys, pathlib

root = pathlib.Path(__file__).resolve().parents[2]
s = (root / "PrompTugal/Bridge/BridgeScripts.swift").read_text()
fill = {r"\(scheduleKey)": "nr.schedule.v1", r"\(meterKey)": "web-summit.newsroom.meter.v1",
        r"\(ScheduleDocument.changeEvent)": "nr:schedule", r"\(versionJSON)": '"1.2"', r"\(opsJSON)": '["schedule.get"]'}

def done(text):
    for k, v in fill.items():
        text = text.replace(k, v)
    return text

def block(name):
    start = s.index(f"static let {name} = \"\"\"\n") + len(f"static let {name} = \"\"\"\n")
    return done(s[start:s.index('\n    """', start)])

out = {n: block(n) for n in ["writeSchedule", "creditMeter", "readMeter", "hideWebTopUp", "bridgeWorld"]}
out["readSchedule"] = done(re.search(r'static let readSchedule = "(.*)"\n', s).group(1))
start = s.index('return """\n', s.index("static func pageAPI")) + len('return """\n')
out["pageAPI"] = done(s[start:s.index('"""', start)])
(pathlib.Path(__file__).parent / "scripts.json").write_text(json.dumps(out))
print("extracted", sorted(out))
