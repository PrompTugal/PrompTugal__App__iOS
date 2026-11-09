// schedule-rules/1: the reference implementation of the news app's schedule rules, for the web app, and the
// behaviour the iOS (DayPlanner.swift) and Android apps must match. Pure functions, no dependencies, no I/O.
// Rules data: rules.json. Shared test vectors: cases.json (run by schedule-rules.test.mjs; Swift and Kotlin
// tests should run the same file).
//
// An item: { id, title, start, end?, place?, shows_as? }, start/end ISO 8601 with an offset or Z.
// end missing: start + default_duration_minutes.

const MIN = 60 * 1000;

export const RULES = {
  travel: {
    within_summit_minutes: 5,
    elsewhere_minutes: 25,
    summit_place_keywords: ["stage", "masterclass", "meetup", "lounge", "meo arena", "fil", "pitch", "summit", "booth", "hall", "pavilion"],
  },
  default_duration_minutes: 30,
  shows_as: {
    fallback_free_title_patterns: ["registration", "badge pick", "opening night", "opening party", "start of the show", "start-of-the-show", "doors open", "venue open", "venue hours", "all day", "all-day"],
    fallback_free_min_minutes: 180,
  },
  ics: { uid_domain: "promptugal.news" },
};

const ms = (iso) => {
  const t = Date.parse(iso);
  if (Number.isNaN(t)) throw new TypeError(`not an ISO time: ${iso}`);
  return t;
};
const startMs = (it) => ms(it.start);
const endMs = (it) => (it.end ? ms(it.end) : startMs(it) + RULES.default_duration_minutes * MIN);
// Swift's Int(Double) truncates toward zero; so do we.
const minutesBetween = (a, b) => Math.trunc((b - a) / MIN);

export function isSummitVenue(place) {
  const p = String(place || "").toLowerCase();
  return RULES.travel.summit_place_keywords.some((k) => p.includes(k));
}

/** Walking minutes between two places (DayPlanner.travelMinutes). */
export function travelMinutes(a, b) {
  a = String(a || "");
  b = String(b || "");
  if (!a || !b || a.toLowerCase() === b.toLowerCase()) return 0;
  return isSummitVenue(a) && isSummitVenue(b) ? RULES.travel.within_summit_minutes : RULES.travel.elsewhere_minutes;
}

/** "busy" or "free": the person's toggle, else the event's shows_as, else the fallback rule. */
export function showsAs(item, toggles = {}) {
  const t = toggles[item.id];
  if (t === "busy" || t === "free") return t;
  if (item.shows_as === "busy" || item.shows_as === "free") return item.shows_as;
  const title = String(item.title || "").toLowerCase();
  if (RULES.shows_as.fallback_free_title_patterns.some((p) => title.includes(p))) return "free";
  if (minutesBetween(startMs(item), endMs(item)) >= RULES.shows_as.fallback_free_min_minutes) return "free";
  return "busy";
}

/** The key a "split my time" choice is stored under: the two ids, sorted, joined by "|". */
export const splitKey = (a, b) => [a, b].sort().join("|");

/** Items sorted as DayPlanner sorts them: by start, then by id. */
export function sortItems(items) {
  return [...items].sort((x, y) => startMs(x) - startMs(y) || (x.id < y.id ? -1 : x.id > y.id ? 1 : 0));
}

/**
 * Clashes among busy items (DayPlanner.clashes, plus busy/free and split).
 * Each: { first, second, minutes, travel, split, leave_at? }.
 *  - travel false: they overlap by `minutes`;
 *  - travel true: no overlap, but `minutes` short of the walk between them;
 *  - split true: the person chose to split their time; `leave_at` (ISO, UTC) is when to leave the first to reach
 *    the second on time. A split clash is a plan, not an error.
 * Free items never clash. Options: { toggles: {id: "busy"|"free"}, splits: Set or array of splitKey }.
 */
export function clashes(items, { toggles = {}, splits = [] } = {}) {
  const split = new Set(splits);
  const busy = sortItems(items).filter((it) => showsAs(it, toggles) === "busy");
  const out = [];
  for (let i = 0; i < busy.length; i++) {
    const a = busy[i];
    const aEnd = endMs(a);
    for (let j = i + 1; j < busy.length; j++) {
      const b = busy[j];
      const walk = travelMinutes(a.place, b.place);
      const bStart = startMs(b);
      if (!(bStart < aEnd + walk * MIN)) continue;
      const overlap = minutesBetween(bStart, Math.min(aEnd, endMs(b)));
      let c = null;
      if (overlap > 0) c = { first: a.id, second: b.id, minutes: overlap, travel: false };
      else {
        const short = walk - minutesBetween(aEnd, bStart);
        if (short > 0) c = { first: a.id, second: b.id, minutes: short, travel: true };
      }
      if (!c) continue;
      c.split = split.has(splitKey(a.id, b.id));
      if (c.split) c.leave_at = new Date(bStart - walk * MIN).toISOString();
      out.push(c);
    }
  }
  return out;
}

// ---- .ics (RFC 5545) ----

const icsEscape = (s) => String(s).replace(/\\/g, "\\\\").replace(/;/g, "\\;").replace(/,/g, "\\,").replace(/\r?\n/g, "\\n");
const icsTime = (t) => new Date(t).toISOString().replace(/[-:]/g, "").replace(/\.\d{3}/, "");

// Fold at 75 octets (UTF-8), continuation lines start with one space; never split a character.
function fold(line) {
  const enc = new TextEncoder();
  const parts = [];
  let cur = "";
  let len = 0;
  for (const ch of line) {
    const n = enc.encode(ch).length;
    const limit = parts.length === 0 ? 75 : 74;
    if (len + n > limit) {
      parts.push(cur);
      cur = "";
      len = 0;
    }
    cur += ch;
    len += n;
  }
  parts.push(cur);
  return parts.join("\r\n ");
}

/**
 * One VCALENDAR for the items (one pick, or the whole programme). Free items are TRANSP:TRANSPARENT.
 * Options: { toggles, now (ISO, for DTSTAMP; defaults to the current time), name }.
 */
export function toICS(items, { toggles = {}, now, name = "PrompTugal" } = {}) {
  const stamp = icsTime(now ? ms(now) : Date.now());
  const lines = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//PrompTugal//schedule-rules 1//EN", "CALSCALE:GREGORIAN", "METHOD:PUBLISH", `X-WR-CALNAME:${icsEscape(name)}`];
  for (const it of sortItems(items)) {
    lines.push("BEGIN:VEVENT", `UID:${icsEscape(it.id)}@${RULES.ics.uid_domain}`, `DTSTAMP:${stamp}`,
      `DTSTART:${icsTime(startMs(it))}`, `DTEND:${icsTime(endMs(it))}`, `SUMMARY:${icsEscape(it.title || "")}`);
    if (it.place) lines.push(`LOCATION:${icsEscape(it.place)}`);
    if (it.url) lines.push(`URL:${it.url}`);
    lines.push(`TRANSP:${showsAs(it, toggles) === "free" ? "TRANSPARENT" : "OPAQUE"}`, "END:VEVENT");
  }
  lines.push("END:VCALENDAR");
  return lines.map(fold).join("\r\n") + "\r\n";
}
