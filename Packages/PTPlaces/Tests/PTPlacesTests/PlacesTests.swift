import Foundation
import SwiftUI
import Testing
@testable import PTPlaces

// Trimmed copies of what promptugal.news serves on 15 November 2026.

private let indexJSON = """
{"about":"PrompTugal.news by place","places":[
 {"id":"portugal","name":"Portugal","kind":"country","parent":"","path":"portugal/","agent":"place.portugal@PrompTugal.dinis","status":"researching","updated":"2026-11-15","ai_news":12,"ai_map":26},
 {"id":"algarve","name":"The Algarve","kind":"region","parent":"portugal","path":"algarve/","agent":"place.algarve@PrompTugal.dinis","status":"researching","updated":"2026-11-15","ai_news":15,"ai_map":20},
 {"id":"faro","name":"Faro","kind":"municipality","parent":"algarve","path":"algarve/faro/","agent":"place.faro@PrompTugal.dinis","status":"live","updated":"2026-11-15","ai_news":10,"ai_map":12},
 {"id":"loule","name":"Loulé","kind":"municipality","parent":"algarve","path":"algarve/loule/","agent":"place.loule@PrompTugal.dinis","status":"researching","updated":"2026-11-15","ai_news":"5","ai_map":8},
 {"id":"quarteira","name":"Quarteira","kind":"city","parent":"loule","path":"algarve/quarteira/","agent":"place.quarteira@PrompTugal.dinis","status":"researching","updated":"2026-11-15","ai_news":4,"ai_map":4},
 {"name":"no id, dropped"}
]}
"""

private let listJSON = """
{"places":[{"id":"faro","name":"Faro","kind":"municipality","parent":"algarve","path":"algarve/faro/","agent":"place.faro@PrompTugal.dinis","at":[-7.935,37.019],"label":"s"}]}
"""

private let louleJSON = """
{"$schema":"../schemas/by-place.schema.json","id":"loule","name":"Loulé","kind":"municipality","parent":"algarve","status":"researching","updated":"2026-11-15","by":"place.loule@PrompTugal.dinis",
 "mandate":"PrompTugal.news Loulé: AI and technology in Loulé.",
 "gravity":{"text":"Institutional more than corporate.","sources":[{"title":"Barlavento","url":"https://www.barlavento.pt/?p=405832","read_on":"2026-11-15"}]},
 "look":{"accent":"#9A3412","landmark":"The neo-Moorish domes of the Mercado Municipal","motif":"terracotta"},
 "ai_news":[
  {"title":"Older, one step","summary":"s","date":"2023-04-14","publisher":"Barlavento","url":"https://a","read_on":"2026-11-15","ai_path":"p","steps":1},
  {"title":"Council buys AI tools","summary":"s","date":"2026-07-28","publisher":"Barlavento","url":"https://b","read_on":"2026-11-15","ai_path":"p","steps":0},
  {"title":"Newer, one step","summary":"s","date":"2026-09-24","url":"https://c","steps":"1"},
  {"summary":"no title, dropped"}
 ],
 "ai_map":[{"name":"SPIC","type":"company","url":"https://spic.pt","what":"Digital studio","source_url":"https://www.ualg.pt/x","read_on":"2026-11-15","ai_path":"Built an AI system","steps":0},
           {"name":"NERA","type":"association","steps":1},{"name":"Estádio centre","type":"programme"}],
 "sources":[{"name":"Câmara Municipal de Loulé","url":"https://www.cm-loule.pt","kind":"council","feed":null}],
 "events":[{"title":"DevFest","date":"2026-11-27 to 2026-11-28","url":"https://e","read_on":"2026-11-15","ai_path":"AI"}],
 "extras":[{"anything":"goes"}],
 "identity":{"key_id":"site.loule-promptugal","signed_by":"place.loule@PrompTugal.dinis"},
 "gaps":["postal.pt could not be read"],
 "voice":{"lede":"Loulé, ó pá","mandate":"m","gravity":"g"},
 "future_field":{"ignored":true}}
"""

private let statusJSON = """
{"agent":"place.loule@PrompTugal.dinis","focus":"promptugal.news/algarve/loule/","state":"second pass released; status researching","updated":"2026-11-15T22:25Z",
 "done":["keys","first pass"],"next":["council BTL"],"asks":["Dinis: postal.pt cannot be read"],"debrief":null}
"""

private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    try JSONDecoder().decode(T.self, from: Data(json.utf8))
}

@Suite("PTPlaces: the website's by-place data")
struct PlacesDecodingTests {
    @Test("the index decodes, a bad entry is dropped, a count given as text still reads")
    func index() throws {
        let index = try decode(PlaceIndex.self, indexJSON)
        #expect(index.places.map(\.id) == ["portugal", "algarve", "faro", "loule", "quarteira"])
        #expect(index.places[3].aiNews == 5)
        #expect(index.places.filter(\.isTown).map(\.id) == ["faro", "loule", "quarteira"])
        #expect(index.places[2].isLive)
    }

    @Test("places.json carries each town's seat as [lon, lat]")
    func seats() throws {
        let list = try decode(PlaceIndex.self, listJSON)
        #expect(list.places.first?.at == [-7.935, 37.019])
    }

    @Test("a place file decodes all its sections and ignores unknown ones")
    func placeFile() throws {
        let file = try decode(PlaceFile.self, louleJSON)
        #expect(file.name == "Loulé")
        #expect(file.look?.accent == "#9A3412")
        #expect(file.aiNews.count == 3)
        #expect(file.aiMap.count == 3)
        #expect(file.events.first?.date == "2026-11-27 to 2026-11-28")
        #expect(file.gaps == ["postal.pt could not be read"])
        #expect(file.identity?.keyID == "site.loule-promptugal")
        #expect(file.voice?.lede == "Loulé, ó pá")
        #expect(file.gravity?.sources.first?.readOn == "2026-11-15")
    }

    @Test("the lead is the story closest to AI, then the newest")
    func weight() throws {
        let file = try decode(PlaceFile.self, louleJSON)
        #expect(file.newsByWeight.map(\.title) == ["Council buys AI tools", "Newer, one step", "Older, one step"])
        #expect(file.newsByDate.first?.title == "Newer, one step")
    }
}

@Suite("PTPlaces: the agents behind a place (conductor-report/v1)")
struct PlaceAgentsTests {
    let loule = PlaceSummary(id: "loule", name: "Loulé", parent: "algarve", agent: "place.loule@PrompTugal.dinis")

    @Test("the roles read for a place: itself, its parent, then the shared team")
    func roles() {
        let roles = PlaceAgents.roles(for: loule)
        #expect(Array(roles.prefix(3)) == ["place.loule", "place.algarve", "dev.places"])
        #expect(roles.contains("ios.places"))
    }

    @Test("a report is built only from the status files found, with links to the place agent")
    func report() throws {
        let own = try decode(AgentStatus.self, statusJSON)
        let dev = AgentStatus(agent: "dev.places@PrompTugal.dinis", focus: "the frame", state: "steps 1 to 5 live")
        let region = AgentStatus(agent: "place.algarve@PrompTugal.dinis", focus: "the region", state: "researching")
        let report = PlaceAgents.report(place: loule, statuses: ["place.loule": own, "dev.places": dev, "place.algarve": region])
        #expect(report.v == 1)
        #expect(report.agents.map(\.id) == ["place.loule@PrompTugal.dinis", "place.algarve@PrompTugal.dinis", "dev.places@PrompTugal.dinis"])
        #expect(report.agents[0].status == "waiting")
        #expect(report.agents[0].waitingFor == "Dinis: postal.pt cannot be read")
        #expect(report.agents[0].newsroom == "loule")
        #expect(report.agents[0].parent == "place.algarve@PrompTugal.dinis")
        #expect(report.agents[2].role == "builds the page")
        #expect(report.links.contains(ReportLink(from: "place.loule@PrompTugal.dinis", to: "place.algarve@PrompTugal.dinis", label: "rises to")))
        #expect(report.links.contains(ReportLink(from: "dev.places@PrompTugal.dinis", to: "place.loule@PrompTugal.dinis", label: "builds the page")))
    }

    @Test("a served conductor-report/v1 decodes, with the proposed newsroom fields")
    func served() throws {
        let json = """
        {"v":1,"made":"2026-11-16T01:00:00Z","conductor":"conductor@PrompTugal.dinis",
         "agents":[{"id":"place.faro@PrompTugal.dinis","name":"place.faro","kind":"session","role":"Faro","status":"working","doing":"deepening","newsroom":"faro","newsroomRole":"place"},
                   {"id":"dev.places@PrompTugal.dinis","name":"dev.places","kind":"session","role":"frame","status":"working","doing":"x"},
                   {"id":"place.loule@PrompTugal.dinis","name":"place.loule","kind":"session","role":"Loulé","status":"idle","doing":"","newsroom":"loule"}],
         "links":[],"messages":[],"decisions":[]}
        """
        let report = try decode(AgentsReport.self, json)
        #expect(report.agents(for: "faro").map(\.name) == ["place.faro", "dev.places"])
    }

    @Test("status words come from the state and the open asks")
    func statusWords() {
        #expect(PlaceAgents.statusWord(AgentStatus(agent: "a", state: "deepening")) == "working")
        #expect(PlaceAgents.statusWord(AgentStatus(agent: "a", state: "deepening", asks: ["x"])) == "waiting")
        #expect(PlaceAgents.statusWord(AgentStatus(agent: "a", state: "blocked on keys")) == "blocked")
        #expect(PlaceAgents.statusWord(AgentStatus(agent: "a", state: "stopped; handed over")) == "done")
    }

    @Test("the dates the agents write all parse")
    func dates() {
        #expect(PlaceDates.parse("2026-11-15T22:25Z") != nil)
        #expect(PlaceDates.parse("2026-11-15T22:25:10Z") != nil)
        #expect(PlaceDates.parse("2026-11-15") != nil)
        #expect(PlaceDates.short("2026-07-28") == "28 Jul 2026")
        #expect(PlaceDates.short("2026-11-27 to 2026-11-28") == "27 Nov 2026")
        #expect(PlaceDates.short("soon") == "soon")
    }
}

@Suite("PTPlaces: the AI map's layout")
struct GraphLayoutTests {
    @Test("entries sit on rings by their steps; missing steps go to the outer ring")
    func rings() throws {
        let file = try decode(PlaceFile.self, louleJSON)
        let layout = ConnectionsGraph.layout(file.aiMap)
        #expect(layout.count == 3)
        #expect(layout.first { $0.entry.name == "SPIC" }?.ring == 0)
        #expect(layout.first { $0.entry.name == "NERA" }?.ring == 1)
        #expect(layout.first { $0.entry.name == "Estádio centre" }?.ring == 2)
    }

    @Test("hex accents read")
    func accents() {
        #expect(Color(hexString: "#9A3412") != nil)
        #expect(Color(hexString: "0B5C7A") != nil)
        #expect(Color(hexString: "red") == nil)
    }
}

@Suite("PTPlaces: towns connected by what their AI maps share")
struct ConnectionsTests {
    @Test("names match across spellings, brackets and short forms")
    func keys() {
        #expect(PlaceConnections.keys("Universidade do Algarve (UAlg)").contains("universidade do algarve"))
        #expect(PlaceConnections.keys("MARREAL underwater observatory, Sagres (UAlg, CINTAL, CCMAR, INESC-TEC)").contains("universidade do algarve"))
        #expect(PlaceConnections.keys("NERA, Associação Empresarial da Região do Algarve").contains("nera"))
        #expect(PlaceConnections.keys("Universidade do Algarve and CCMAR, Sagres marine biology laboratory").contains("universidade do algarve"))
        #expect(PlaceConnections.keys("ICArEHB (UAlg research centre)").contains("universidade do algarve") == false)
    }

    @Test("two towns that name the same organisation are linked, once")
    func links() {
        let faro = PlaceFile(id: "faro", name: "Faro", aiMap: [MapEntry(name: "Universidade do Algarve (UAlg)"), MapEntry(name: "Algarve Evolution")])
        let lagos = PlaceFile(id: "lagos", name: "Lagos", aiMap: [MapEntry(name: "Algarve Evolution")])
        let sagres = PlaceFile(id: "vila-do-bispo", name: "Vila do Bispo", aiMap: [MapEntry(name: "MARREAL observatory (UAlg, CCMAR)")])
        let links = PlaceConnections.links([faro, lagos, sagres])
        #expect(links.count == 2)
        #expect(links.contains(TownLink(a: "faro", b: "lagos", shared: ["Algarve Evolution"])))
        #expect(links.contains(TownLink(a: "faro", b: "vila-do-bispo", shared: ["Universidade do Algarve"])))
        #expect(PlaceConnections.hubs([faro, lagos, sagres]).count == 2)
    }
}
