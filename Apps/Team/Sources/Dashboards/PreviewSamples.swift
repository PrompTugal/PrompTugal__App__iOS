import Foundation

/// Made-up data in the shape of the public JSON, for SwiftUI previews. No real people.
@MainActor
enum PreviewSamples {
    static let me = """
    {"version":"v0.0.0","built_at":"2026-11-08T08:00:00Z","people":{
      "ana":{"id":"ana","name":"Ana Example","first":"Ana","role":"Editor and planner","colour":"#1e7b4f","level":5,
        "level_name":"L5 agents on schedules","only_you":2,"decide":4,"open":20,"overdue":3,"soon":2,"focus":true,
        "standup_at":"2026-11-08T12:00:00Z","standup":"2026-11-08 12:00","briefing":"meetings/2026-11-08-1200/ana/index.html",
        "urgent":[{"id":"WS-1","title":"Sign off the print files","due":"Sat 8 Nov, 10:00","status":"open","late":true}],
        "decisions":[{"what":"Pick the morning edition's lead","issue":"WS-2","source":""}],
        "agents":[{"name":"journalist@team.ana","status":"active","last_at":"2026-11-08T07:57:00Z","last":"Report at 07:57: three releases, one decision"},
                  {"name":"pulse@team.ana","status":"idle","last_at":"2026-11-07T19:40:00Z","last":"Evening check-in summarised"}],
        "messages":[{"at":"2026-11-08T07:30:00Z","from":"conductor@team.ana","subject":"Stand-up brief ready"}],
        "daily":[2,5,3,8,6,9,4,7,10,6],"days":["2026-10-30","2026-10-31","2026-11-01","2026-11-02","2026-11-03","2026-11-04","2026-11-05","2026-11-06","2026-11-07","2026-11-08"]},
      "bruno":{"id":"bruno","name":"Bruno Example","first":"Bruno","role":"Builder","colour":"#1f3a93","level":3,
        "level_name":"L3 a conductor agent running","only_you":0,"decide":1,"open":8,"overdue":0,"soon":1,
        "standup_at":"2026-11-08T12:00:00Z","next":{"step":"Can push","how":"accept the invitation"},
        "agents":[{"name":"dev@team.bruno","status":"active","last_at":"2026-11-08T06:10:00Z","last":"Fixed the build"}],
        "daily":[1,0,2,3,1,4,2,2,3,5],"days":["2026-10-30","2026-10-31","2026-11-01","2026-11-02","2026-11-03","2026-11-04","2026-11-05","2026-11-06","2026-11-07","2026-11-08"]}
    }}
    """

    static let dashboard = """
    {"at":"2026-11-08T08:00:00Z","grid_hours":["09","10","11","12","13","14","15","16","17","18","19","20","21","22","23","00","01","02","03","04","05","06","07","08"],
     "agents":[
      {"role":"conductor","agent":"conductor@team.ana","focus":"the plan and the briefs","state":"running","minute":52,"stale":false,
       "grid":"●●·●◐●●·●●●·●●○●●·●●●●●●","last_wake":{"started":"2026-11-08T07:52Z","outcome":"ok","line":"Brief for the 12:00 stand-up"},
       "next":["the 12:00 brief"],"asks":[{"for":"Ana","ask":"Approve the lead story"}]},
      {"role":"journalist","agent":"journalist@team.ana","focus":"reports every two hours","state":"running","minute":57,
       "grid":"·●·●·●·●·●·●·●·●·●·●·●·●"},
      {"role":"dev","agent":"dev@team.bruno","focus":"the app","state":"running","minute":8,
       "grid":"●●◐●●●✕●●●●●···•••·•·•••"}],
     "asks":[{"from":"story board","since":"2026-11-07","ask":"Is the headline right?"}],
     "handoffs":[{"from":"designer","to":"Ana","n":12},{"from":"dev","to":"conductor","n":5}]}
    """

    static let status = """
    {"version":"v0.0.0","counts":{"stories":12,"articles":8,"agents_running":3,"runs":20,"pages":400,"nodes":300,"edges":500},
     "pipeline":[{"stage":"research","label":"Research","state":"running"},{"stage":"curate","label":"Curate","state":"running"},
                 {"stage":"write","label":"Write","state":"waiting"},{"stage":"publish","label":"Publish","state":"running"}],
     "waiting":[{"what":"Write access for the journalist desk","who":"Ana","unblocks":"the first full run"}],
     "agents":[{"id":"a","status":"running"},{"id":"b","status":"running"},{"id":"c","status":"paused"}],
     "runs":[{"id":"r1","when":"2026-11-08T07:00:00Z","kind":"commit","by":"dev@team.bruno","what":"release v0.0.1"},
             {"id":"r2","when":"2026-11-08T05:00:00Z","kind":"desk","by":"curator@team.ana","what":"mapped 12 captures"}]}
    """

    static let board = """
    {"columns":[{"id":"idea","name":"Idea"},{"id":"drafting","name":"Drafting"},{"id":"published","name":"Published"}],
     "stories":[{"id":"s1","title":"Getting to the venue","column":"published","assignee":"journalist@team.ana","next":"nothing: live"},
                {"id":"s2","title":"The agent sessions, day by day","column":"idea","next":"someone takes it"},
                {"id":"s3","title":"Who is hiring at the summit","column":"drafting","assignee":"writer@team.ana","next":"a fact check"}]}
    """

    static func decode<Value: Decodable>(_ text: String, as type: Value.Type = Value.self) -> Value? {
        try? JSONDecoder().decode(Value.self, from: Data(text.utf8))
    }

    /// A DashboardData filled with the samples. It does not touch "who am I": sample mode sets
    /// the sample person itself and restores the previous choice when it is left.
    static func data() -> DashboardData {
        let data = DashboardData()
        if let me = decode(me, as: Wire.Me.self) { data.team.preview(me) }
        if let dashboard = decode(dashboard, as: Wire.NewsroomDashboard.self) { data.dashboard.preview(dashboard) }
        if let status = decode(status, as: Wire.NewsroomStatus.self) { data.status.preview(status) }
        if let board = decode(board, as: Wire.StoryBoard.self) { data.board.preview(board) }
        return data
    }

    /// For SwiftUI previews only: the samples, with the sample person as "me".
    static func previewData() -> DashboardData {
        UserDefaults.standard.set(SampleMode.samplePersonID, forKey: DashboardData.meKey)
        return data()
    }
}
