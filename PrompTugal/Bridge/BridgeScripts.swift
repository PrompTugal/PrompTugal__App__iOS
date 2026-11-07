import Foundation

/// The JavaScript the app injects. Kept in one place so the Debug panel can show it and the website team can read it.
enum BridgeScripts {
    static let scheduleKey = ScheduleDocument.storageKey          // nr.schedule.v1
    static let meterKey = "web-summit.newsroom.meter.v1"

    /// Page world, document start: `window.ptApp = { version, ops, call(op, args) }`.
    /// `call` relays through DOM events to the bridge world, which alone can reach the `pt` handler.
    static func pageAPI(version: String, ops: [String]) -> String {
        let opsJSON = (try? String(decoding: JSONSerialization.data(withJSONObject: ops), as: UTF8.self)) ?? "[]"
        let versionJSON = (try? String(decoding: JSONSerialization.data(withJSONObject: [version]), as: UTF8.self))
            .map { String($0.dropFirst().dropLast()) } ?? "\"\""
        return """
        (() => {
          'use strict'
          if (window.ptApp) return
          const pending = new Map()
          let seq = 0
          // The payload rides in event.detail and, in case another content world cannot read it, in a DOM attribute
          // set just before the (synchronous) dispatch.
          const root = () => document.documentElement
          const send = (name, json) => {
            if (root()) root().setAttribute('data-' + name.replace(':', '-'), json)
            document.dispatchEvent(new CustomEvent(name, { detail: json }))
          }
          const take = (name, e) => typeof e.detail === 'string' ? e.detail : (root() && root().getAttribute('data-' + name.replace(':', '-')))
          document.addEventListener('pt:reply', e => {
            let m
            try { m = JSON.parse(take('pt:reply', e)) } catch (x) { return }
            const p = m && pending.get(m.id)
            if (!p) return
            pending.delete(m.id)
            if (m.ok) p.resolve(m.result); else p.reject(new Error(m.error || 'The app refused the request.'))
          })
          const call = (op, args) => new Promise((resolve, reject) => {
            const id = 'pt' + (++seq) + '.' + Date.now()
            pending.set(id, { resolve, reject })
            send('pt:request', JSON.stringify({ id, op: String(op), args: args || {} }))
            setTimeout(() => { if (pending.delete(id)) reject(new Error('The app did not answer.')) }, 120000)
          })
          Object.defineProperty(window, 'ptApp', {
            value: Object.freeze({ version: \(versionJSON), ops: Object.freeze(\(opsJSON)), call }),
            configurable: false, enumerable: true, writable: false,
          })
          const mark = () => document.documentElement && document.documentElement.classList.add('in-pt-app')
          mark(); document.addEventListener('DOMContentLoaded', mark)
        })();
        """
    }

    /// Bridge world, document start: relays requests to the `pt` handler, and tells the app when the page changes the
    /// schedule (`nr:schedule`) or the reading meter (`sg:meter.changed`). It shares the DOM and localStorage with the
    /// page, but not its JavaScript objects, so page scripts cannot reach the handler directly.
    static let bridgeWorld = """
    (() => {
      'use strict'
      const h = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.pt
      if (!h || window.__ptBridge) return
      window.__ptBridge = true
      const root = () => document.documentElement
      const reply = m => {
        const json = JSON.stringify(m)
        if (root()) root().setAttribute('data-pt-reply', json)
        document.dispatchEvent(new CustomEvent('pt:reply', { detail: json }))
      }
      document.addEventListener('pt:request', async e => {
        let m
        try { m = JSON.parse(typeof e.detail === 'string' ? e.detail : (root() && root().getAttribute('data-pt-request'))) } catch (x) { return }
        if (!m || typeof m.id !== 'string' || typeof m.op !== 'string') return
        try { reply({ id: m.id, ok: true, result: await h.postMessage({ op: m.op, args: m.args || {} }) }) }
        catch (err) { reply({ id: m.id, ok: false, error: String((err && err.message) || err) }) }
      })
      const read = k => { try { return localStorage.getItem(k) } catch (x) { return null } }
      window.addEventListener('nr:schedule', () => {
        h.postMessage({ op: 'schedule.pageChanged', args: { doc: read('\(scheduleKey)') } }).catch(() => {})
      })
      const meter = () => {
        let s = null
        try { s = JSON.parse(read('\(meterKey)')) } catch (x) { s = null }
        if (!s || typeof s.balance !== 'number') return null
        const t = Array.isArray(s.topups) ? s.topups : []
        return { balance: s.balance, spent: s.spent || 0, reads: s.reads || 0, declined: s.declined || 0,
                 topups: t.length, lastTopup: t[0] ? { ref: String(t[0].ref || ''), at: String(t[0].at || ''), credit: t[0].credit || 0 } : null }
      }
      document.addEventListener('sg:meter.changed', () => {
        h.postMessage({ op: 'meter.pageChanged', args: { meter: meter() } }).catch(() => {})
      })
    })();
    """

    /// Page world, document start, promptugal.news only: hides the website's Stripe top-up inside the app (App Store
    /// rule 3.1.1, brief 06) and adds a "Top up in the app" button to the account page that opens the native purchase.
    static let hideWebTopUp = """
    (() => {
      'use strict'
      const css = `
        #nr-pay, #nr-topup .nr-pay, a[href*="buy.stripe.com"],
        #nr-account .balance-card .actions a.btn.primary[href*="top-up"],
        #nr-topped .field, #nr-paste-add { display: none !important; }
      `
      const style = () => {
        if (document.getElementById('pt-app-style') || !document.head) return !!document.getElementById('pt-app-style')
        const s = document.createElement('style'); s.id = 'pt-app-style'; s.textContent = css
        document.head.append(s); return true
      }
      const button = () => {
        const box = document.querySelector('#nr-account .balance-card .actions')
        if (!box || box.querySelector('.pt-app-topup') || !window.ptApp) return
        const b = document.createElement('button')
        b.type = 'button'; b.className = 'btn primary pt-app-topup'; b.textContent = 'Top up in the app'
        b.addEventListener('click', () => window.ptApp.call('meter.topup', {}).catch(() => {}))
        box.prepend(b)
      }
      const note = () => {
        const t = document.getElementById('nr-topup')
        if (!t || t.querySelector('.pt-app-note')) return
        const p = document.createElement('p'); p.className = 'notice pt-app-note'
        p.textContent = 'In the PrompTugal app, reading credit is topped up in the app.'
        const b = document.createElement('button'); b.type = 'button'; b.className = 'btn primary'; b.textContent = 'Top up in the app'
        b.addEventListener('click', () => window.ptApp && window.ptApp.call('meter.topup', {}).catch(() => {}))
        t.replaceChildren(p, b)
      }
      if (!style()) document.addEventListener('DOMContentLoaded', style)
      const tick = () => { style(); button(); note() }
      document.addEventListener('DOMContentLoaded', () => {
        tick()
        new MutationObserver(tick).observe(document.body, { childList: true, subtree: true })
      })
    })();
    """

    /// Page world: reads the page's schedule. Returns the raw string, or '' when the page has none
    /// (never null: the async `callAsyncJavaScript` is safest with a value).
    static let readSchedule = "try { return localStorage.getItem('\(scheduleKey)') || '' } catch (e) { return '' }"

    /// Page world, with argument `doc` (a JSON string): writes the app's schedule into the page, keeping any other key
    /// the page's document has, and fires the page's own `nr:schedule` event once per changed pick, with the
    /// `{ id, picked }` detail its buttons repaint from. Returns the number of picks changed.
    static let writeSchedule = """
    const KEY = '\(scheduleKey)'
    let base = null, before = []
    try { base = JSON.parse(localStorage.getItem(KEY)) } catch (e) { base = null }
    if (!base || typeof base !== 'object' || Array.isArray(base)) base = {}
    if (Array.isArray(base.picks)) before = base.picks.map(p => p && p.id)
    const next = JSON.parse(doc)
    base.v = 1
    base.picks = next.picks
    try { localStorage.setItem(KEY, JSON.stringify(base)) } catch (e) { return -1 }
    const now = new Set(next.picks.map(p => p.id)), had = new Set(before)
    const changed = []
    for (const id of now) if (!had.has(id)) changed.push([id, true])
    for (const id of had) if (id && !now.has(id)) changed.push([id, false])
    for (const [id, picked] of changed) window.dispatchEvent(new CustomEvent('\(ScheduleDocument.changeEvent)', { detail: { id, picked, source: 'app' } }))
    return changed.length
    """

    /// Page world: the meter summary as a JSON string, or '' when this browser has no meter yet.
    static let readMeter = """
    let s = null
    try { s = JSON.parse(localStorage.getItem('\(meterKey)')) } catch (e) { s = null }
    if (!s || typeof s.balance !== 'number') return ''
    const t = Array.isArray(s.topups) ? s.topups : []
    return JSON.stringify({ balance: s.balance, spent: s.spent || 0, reads: s.reads || 0, declined: s.declined || 0, topups: t.length,
             lastTopup: t[0] ? { ref: String(t[0].ref || ''), at: String(t[0].at || ''), credit: t[0].credit || 0 } : null })
    """

    /// Page world, with arguments `amount` (pence) and `ref` (the App Store transaction id): credits the meter once per
    /// reference, through the website's own meter (`window.__meter`, sg-meter-core `credit(amount, 'link', ref)`, which
    /// refuses a reference it has seen). Without the meter on the page, it applies the same rule to localStorage.
    /// Returns 'credited', 'already' or 'failed'.
    static let creditMeter = """
    const api = window.__meter
    if (api && api.ready) {
      try {
        const m = await api.ready
        if (m && typeof m.credit === 'function') return m.credit(amount, 'link', ref) ? 'credited' : 'already'
      } catch (e) { /* fall through to storage */ }
    }
    const KEY = '\(meterKey)'
    let s = null
    try { s = JSON.parse(localStorage.getItem(KEY)) } catch (e) { s = null }
    const now = new Date().toISOString()
    if (!s || typeof s.balance !== 'number') {
      s = { v: 3, created: now, balance: 500, spent: 0, reads: 0, declined: 0, paused: false, log: [], topups: [], cart: [], sessions: [] }
    }
    if (!Array.isArray(s.sessions)) s.sessions = []
    if (!Array.isArray(s.topups)) s.topups = []
    if (s.sessions.includes(ref)) return 'already'
    s.sessions.push(ref)
    s.balance = Math.round((s.balance + amount) * 10) / 10
    s.topups.unshift({ ref: String(ref).slice(0, 40), at: now, credit: amount, source: 'link' })
    try { localStorage.setItem(KEY, JSON.stringify(s)) } catch (e) { return 'failed' }
    return 'credited'
    """

    /// Page world, web-summit.sgit.ai: sets the site's own "Who are you?" choice (`ws.me`) from the app's identity.
    static let writeTeamIdentity = """
    try {
      const was = localStorage.getItem('ws.me') || ''
      if (id) localStorage.setItem('ws.me', id); else localStorage.removeItem('ws.me')
      return was !== (id || '')
    } catch (e) { return false }
    """
}
