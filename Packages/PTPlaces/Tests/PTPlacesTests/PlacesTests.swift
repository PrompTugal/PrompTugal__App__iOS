import Foundation
import CryptoKit
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
        #expect(Array(roles.prefix(3)) == ["place.loule", "place.algarve", "conductor"])
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

@Suite("PTPlaces: the newsroom dashboard")
struct DashboardTests {
    @Test("dashboard.json decodes into status records by role")
    func dashboard() throws {
        let json = """
        {"about":"x","built":"2026-11-16T00:10Z","agents":[
         {"role":"place.loule","agent":"place.loule@PrompTugal.dinis","focus":"loule","state":"live; pass 4 released","minute":10,"scheduled":true,
          "updated":"2026-11-16T00:10Z","stale":false,"last_wake":null,"done":["a","b"],"next":["c"],"asks":[],"grid":"..."},
         {"role":"dev.places","agent":"dev.places@PrompTugal.dinis","state":"steps live","updated":"2026-11-15T22:35Z"},
         {"role":"broken"}],
         "schedule":[]}
        """
        let board = try JSONDecoder().decode(NewsroomDashboard.self, from: Data(json.utf8))
        #expect(board.agents.count == 2)
        #expect(board.byRole["place.loule"]?.done == ["a", "b"])
        let loule = PlaceSummary(id: "loule", name: "Loulé", parent: "algarve")
        let report = PlaceAgents.report(place: loule, statuses: board.byRole)
        #expect(report.agents.map(\.name) == ["place.loule", "dev.places"])
        #expect(report.agents.first?.status == "working")
    }

    @Test("a status made in code derives its role from the agent id")
    func role() {
        #expect(AgentStatus(agent: "place.faro@PrompTugal.dinis").role == "place.faro")
    }
}

@Suite("PTPlaces: pick my town")
struct FollowTests {
    @Test("follow toggles in order and survives a round trip")
    func toggle() {
        var raw = ""
        raw = PlaceFollows.toggle("loule", in: raw)
        raw = PlaceFollows.toggle("faro", in: raw)
        #expect(PlaceFollows.ids(raw) == ["loule", "faro"])
        raw = PlaceFollows.toggle("loule", in: raw)
        #expect(PlaceFollows.ids(raw) == ["faro"])
        #expect(PlaceFollows.ids(" , faro,,") == ["faro"])
    }
}

@Suite("PTPlaces: the /api/v1 shape (16 Nov)")
struct APIShapeTests {
    @Test("a seat as {lon, lat}, a photo as an object, provenance and articles all read")
    func apiShape() throws {
        let summary = try decode(PlaceSummary.self, """
        {"id":"faro","name":"Faro","at":{"lon":-7.935,"lat":37.019}}
        """)
        #expect(summary.at == [-7.935, 37.019])
        let file = try decode(PlaceFile.self, """
        {"id":"faro","name":"Faro","look":{"accent":"#0B5C7A","image":{"url":"https://promptugal.news/assets/places/faro.webp","author":"designer.places@","licence":"AI-made"}},
         "ai_news":[{"title":"t","provenance":{"source_url":"https://s","read_on":"2026-11-15","read_by":"place.faro@PrompTugal.dinis","file":"f","signature":"valid","site_key":"site.faro-promptugal"}}],
         "articles":[{"title":"A","summary":"s","author":"place.faro@","date":"15 November 2026","url":"https://promptugal.news/articles/a/","signature":"x.sig"}]}
        """)
        #expect(file.look?.image == "https://promptugal.news/assets/places/faro.webp")
        #expect(file.look?.imageCredit == "designer.places@ · AI-made")
        #expect(file.aiNews.first?.provenance?.signature == "valid")
        #expect(file.articles.first?.title == "A")
    }
}

// A throwaway key made for this test with Node's crypto, the same steps as the website's person-key.mjs
// (issue, link, seal). It protects nothing.
private let testLink = "https://promptugal.news/login/#key=eyJ2IjoxLCJwIjoidGVzdGVyIiwiZiI6InNoYTI1Njo5ZmI3NzFiNzkxN2YzYTA3IiwiZSI6WyJzMU42YUJxM2p1T1BXSTVkX3FPYUlYdS02eTk1WDFaVnMyTXhPdXdOb0xZIiwiTmdlS3NmUkdSZFVQUktiRUowT1pnMjZBSmlIcXRlcFdMZldyaElXUWNaVSIsIlZuczRyTlFpdDVPZDhUazlGV2E4X3ppQ1IzRFpKUE04ejhCSkpfNmVpekkiXSwicyI6WyJDSW96TXhMOUpCczFVX20tVXBZV0o0dUpXcDRHWHZOMWYweHZyNVoxZEVVIiwibzFaQTk5Q1RLekFpVDJMaGJ4all0QlIzMTRwQ3UyQU1BSkZpclg3Zk9HcyIsIllCVkhJQjNDb29IVmNRbTlLZGtjRUNEcnBlMWdjeFNKR1FtSDV5WlhkNzgiXX0"
private let testEnvelope = #"{"v": "ws-ecies-1", "to": "tester", "key": "sha256:9fb771b7917f3a07", "by": "conductor@PrompTugal.dinis", "at": "2026-11-15T23:50:00Z", "epk": {"kty": "EC", "crv": "P-256", "x": "iH4wNGuN2ON6jgWy6mfbfOf3LbCRb93Ed2Fx7TYB3Wg", "y": "aWC7apwvq0Yi3DxvACJxazwqsGjoNK6HcI15M2cgSSA"}, "iv": "9QzNa11+Utg1bC8h", "ct": "n86wklesw+so9+9fKzd82vx5EnPWzwupP25/M8LT9/stPa8/qmSOECLcq8P1LBBoiOA="}"#
private let testRegister = #"{"keys": [{"person": "tester", "fingerprint": "sha256:9fb771b7917f3a07", "status": "active", "encrypt": {"kty": "EC", "crv": "P-256", "x": "NgeKsfRGRdUPRKbEJ0OZg26AJiHqtepWLfWrhIWQcZU", "y": "Vns4rNQit5Od8Tk9FWa8_ziCR3DZJPM8z8BJJ_6eizI"}, "sign": {"kty": "EC", "crv": "P-256", "x": "o1ZA99CTKzAiT2LhbxjYtBR314pCu2AMAJFirX7fOGs", "y": "YBVHIB3CooHVcQm9KdkcECDrpe1gcxSJGQmH5yZXd78"}}]}"#
private let testSignX = "o1ZA99CTKzAiT2LhbxjYtBR314pCu2AMAJFirX7fOGs"
private let testSignY = "YBVHIB3CooHVcQm9KdkcECDrpe1gcxSJGQmH5yZXd78"

@Suite("PTPlaces: sign-in with the person key")
struct PersonKeyTests {
    @Test("a sign-in link reads, its fingerprint checks, and it proves against the register")
    func link() throws {
        let key = try PersonKey(link: testLink)
        #expect(key.person == "tester")
        let register = try JSONDecoder().decode(PersonKeyRegister.self, from: Data(testRegister.utf8))
        try key.prove(against: register)
        #expect(try PersonKey(link: String(testLink.split(separator: "=").last!)).fingerprint == key.fingerprint)
    }

    @Test("a reply sealed by Node (ws-ecies-1) opens on the device")
    func openFromNode() throws {
        let key = try PersonKey(link: testLink)
        let envelope = try JSONDecoder().decode(SealedEnvelope.self, from: Data(testEnvelope.utf8))
        let plain = try JSONSerialization.jsonObject(with: key.open(envelope)) as? [String: String]
        #expect(plain?["text"] == "Olá from the conductor")
    }

    @Test("what the device signs verifies with the public signing key (raw r||s, SHA-256)")
    func sign() throws {
        let key = try PersonKey(link: testLink)
        let signature = try key.sign("comment on loule")
        let x = try #require(Base64URL.decode(testSignX)), y = try #require(Base64URL.decode(testSignY))
        let pub = try P256.Signing.PublicKey(rawRepresentation: x + y)
        let raw = try P256.Signing.ECDSASignature(rawRepresentation: try #require(Data(base64Encoded: signature)))
        #expect(pub.isValidSignature(raw, for: Data("comment on loule".utf8)))
    }

    @Test("a link with no key, a bad fingerprint or a replaced key is refused")
    func refusals() throws {
        #expect(throws: PersonKey.Failure.noKeyInLink) { try PersonKey(link: "https://promptugal.news/login/") }
        let key = try PersonKey(link: testLink)
        let replaced = testRegister.replacingOccurrences(of: "\"active\"", with: "\"replaced\"")
        let register = try JSONDecoder().decode(PersonKeyRegister.self, from: Data(replaced.utf8))
        #expect(throws: PersonKey.Failure.replaced) { try key.prove(against: register) }
        let empty = try JSONDecoder().decode(PersonKeyRegister.self, from: Data(#"{"keys":[]}"#.utf8))
        #expect(throws: PersonKey.Failure.notInRegister) { try key.prove(against: empty) }
    }
}

@Suite("PTPlaces: comments")
struct CommentTests {
    @Test("a comment is signed over its fields in order, and the signature verifies")
    func signed() throws {
        let key = try PersonKey(link: testLink)
        let subject = CommentSubject(place: "loule", title: "Loulé", item: "https://b", page: "https://promptugal.news/algarve/loule/")
        let at = Date(timeIntervalSince1970: 1_800_000_000)
        let data = try CommentMessage.payload(subject: subject, text: "Great page", feedback: nil, key: key, at: at)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: String])
        #expect(object["kind"] == "promptugal/comment/v1")
        #expect(object["person"] == "tester")
        let text = CommentMessage.signedText(kind: object["kind"]!, person: "tester", at: object["at"]!, place: "loule", item: "https://b", text: "Great page")
        let x = try #require(Base64URL.decode(testSignX)), y = try #require(Base64URL.decode(testSignY))
        let pub = try P256.Signing.PublicKey(rawRepresentation: x + y)
        let sig = try P256.Signing.ECDSASignature(rawRepresentation: try #require(Data(base64Encoded: object["signature"]!)))
        #expect(pub.isValidSignature(sig, for: Data(text.utf8)))
    }

    @Test("a reply sealed to the person opens into a reply")
    func reply() throws {
        let key = try PersonKey(link: testLink)
        let envelope = try JSONDecoder().decode(SealedEnvelope.self, from: Data(testEnvelope.utf8))
        let reply = try #require(CommentReply.open(try JSONEncoder().encode(envelope), with: key))
        #expect(reply.text == "Olá from the conductor")
        #expect(reply.by == "conductor@PrompTugal.dinis")
    }
}

@Suite("PTPlaces: anonymous votes")
struct VoteTests {
    @Test("a vote carries no person and no key, only the website's view fields and the vote")
    func event() {
        let e = AnonymousVote.event(vote: -5, on: "/algarve/loule/", version: "0.4.107", screen: "phone")
        #expect(e["type"] as? String == "vote")
        #expect(e["vote"] as? Int == -1)
        #expect(e["person"] == nil)
        #expect(e["key"] == nil)
        #expect((e["ts"] as? String)?.count == 17)
    }

    @Test("the SPKI wrapper comes off an RSA key, and the envelope is base64 of base64 of {v:2,w,i,c}")
    func seal() throws {
        // A throwaway 2048-bit key made with Node for this test.
        let pem = "-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA6+ETikMJo4IEQ7gpaGtj\n/POFgi6KHcCriJLiVoHR7NTw0/0z08xwkM7W/lj4AuOOZwpxXJWOwsB18ArkXpav\ndzgg7kBm6REm5aOuP+Cl8SSftm8O/AYbRQ0iOoKpkzg8AORH1q7j3jwYkvVDzcTs\nFAeIlsNVeCWm5M861RRUJoIi16oRiNjq52cclX5udv0BoTOz1JXiW3TBsc1zo3q4\nAX04tpxVIqXqZnKTwj4DPqqhftZ/Tx2QKU9zYyz5kzy5EZPTeNcjrs0+wH48gJ+P\n55Ku72ib8FmCpT1ZIT0m/u6xJcCcrLnfrl5OXn3dVAXokcTvdzv8S7TLGAYotleG\nzwIDAQAB\n-----END PUBLIC KEY-----\n"
        let sealed = try AnonymousVote.seal(Data("{}".utf8), toPEM: pem)
        let inner = try #require(Data(base64Encoded: sealed).flatMap { String(data: $0, encoding: .utf8) })
        let json = try #require(Data(base64Encoded: inner))
        let object = try #require(try JSONSerialization.jsonObject(with: json) as? [String: Any])
        #expect(object["v"] as? Int == 2)
        #expect((object["w"] as? String).flatMap { Data(base64Encoded: $0) }?.count == 256)
    }
}

@Suite("PTPlaces: sections by kind")
struct KindTests {
    @Test("the place agents' types map to Dinis's sections")
    func kinds() {
        #expect(PlaceKind.of("public body") == .government)
        #expect(PlaceKind.of("company") == .companies)
        #expect(PlaceKind.of("startup") == .startups)
        #expect(PlaceKind.of("investor") == .investors)
        #expect(PlaceKind.of("institution") == .research)
        #expect(PlaceKind.of("organisation") == .community)
        #expect(PlaceKind.of("community") == .community)
        #expect(PlaceKind.of("person") == .talent)
        #expect(PlaceKind.of("lighthouse") == .other)
        let groups = PlaceKind.groups([MapEntry(name: "a", type: "startup"), MapEntry(name: "b", type: "public body")])
        #expect(groups.map(\.kind) == [.government, .startups])
    }
}

@Suite("PTPlaces: public contacts and talent")
struct ContactTests {
    @Test("a contact shows only with its source page; talent can say it is looking for work")
    func contacts() throws {
        let entry = try decode(MapEntry.self, """
        {"name":"Câmara Municipal de Loulé","type":"public body",
         "contacts":[{"label":"Geral","phone":"+351 289 400 600","source_url":"https://www.cm-loule.pt/contactos","read_on":"2026-11-16"},
                     {"email":"x@example.org"}]}
        """)
        #expect(entry.contacts.count == 2)
        #expect(entry.contacts.filter(\.showable).count == 1)
        let talent = try decode(MapEntry.self, #"{"name":"A","type":"person","looking_for_work":true}"#)
        #expect(talent.lookingForWork)
        #expect(PlaceKind.of(talent.type) == .talent)
    }
}

@Suite("PTPlaces: the agents file per place")
struct PlaceAgentsFileTests {
    @Test("api/v1/by-place/<id>/agents.json decodes; roles come from the agent ids; commits ride along")
    func file() throws {
        let file = try decode(PlaceAgentsFile.self, """
        {"place":"loule","count":2,"agents":[
         {"agent":"place.loule@PrompTugal.dinis","role":"place","state":"live","updated":"2026-11-16T00:10Z","done":["a"],"next":[],"asks":[],
          "commits":[{"hash":"abc123456","date":"2026-11-16T00:09:00Z","subject":"pass 4","url":"https://github.com/x/commit/abc"}]},
         {"agent":"dev.places@PrompTugal.dinis","role":"shared","state":"steps live","updated":"2026-11-15T22:35Z"}]}
        """)
        #expect(file.byRole.keys.sorted() == ["dev.places", "place.loule"])
        let loule = PlaceSummary(id: "loule", name: "Loulé", parent: "algarve")
        let report = PlaceAgents.report(place: loule, statuses: file.byRole)
        #expect(report.agents.first?.commits?.first?.subject == "pass 4")
        #expect(report.agents.map(\.name) == ["place.loule", "dev.places"])
    }
}

@Suite("PTPlaces: the Algarve's towns and the cities across Portugal")
struct RegionSplitTests {
    @Test("district capitals are not Algarve towns; Quarteira (inside Loulé) is")
    @MainActor func split() throws {
        let store = PlacesStore()
        store.index.preview(try decode(PlaceIndex.self, """
        {"places":[{"id":"portugal","name":"Portugal","kind":"country","parent":""},
         {"id":"algarve","name":"The Algarve","kind":"region","parent":"portugal"},
         {"id":"loule","name":"Loulé","kind":"municipality","parent":"algarve"},
         {"id":"quarteira","name":"Quarteira","kind":"city","parent":"loule"},
         {"id":"porto","name":"Porto","kind":"city","parent":"portugal","at":{"lon":-8.611,"lat":41.15}}]}
        """))
        #expect(store.algarveTowns.map(\.id) == ["loule", "quarteira"])
        #expect(store.portugalCities.map(\.id) == ["porto"])
    }
}

@Suite("PTPlaces: now in a place (IPMA, hourly)")
struct NowTests {
    @Test("now.json as served on 16 Nov decodes into the panel's values")
    func now() throws {
        let now = try decode(PlaceNow.self, """
        {"place":"faro","read_at":"2026-11-16T09:40:37Z",
         "station":{"name":"Faro (Aeródromo)","id":1200554,"km":4,"reading":{"at":"2026-11-16T09:00Z","temp_c":15,"humidity_pct":93,"wind_kmh":9.4,"rain_mm":0},"source":"https://api.ipma.pt/x.json","page":"https://www.ipma.pt/en/otempo/obs.superficie/"},
         "forecast":{"place":"Faro","days":[{"date":"2026-11-16","t_min_c":11.8,"t_max_c":20.2,"rain_prob_pct":2,"weather_type":3},{"date":"2026-11-17"}]},
         "warnings":{"active":[{"type":"rough sea","level":"yellow","start":"2026-11-18T12:00:00","end":"2026-11-19T07:00:00"},{"type":"x","level":"green"}]},
         "fire_risk":{"days":[{"date":"2026-11-16","level":"low"}]},
         "uv":{"index":3},
         "sea":{"waves_max_m":0.7,"sea_temp_max_c":19.7},
         "airport":{"name":"Faro airport","airline":[{"callsign":"A"},{"callsign":"B"},{"callsign":"C"}]},
         "reads":{}}
        """)
        #expect(now.station?.tempC == 15)
        #expect(now.today?.maxC == 20.2)
        #expect(now.warnings.map(\.type) == ["rough sea"])
        #expect(now.fireRisk == "low")
        #expect(now.uv == 3)
        #expect(now.sea?.wavesMaxM == 0.7)
        #expect(now.flights == 3)
        #expect(now.pages["station"] == "https://www.ipma.pt/en/otempo/obs.superficie/")
        #expect(now.isEmpty == false)
    }
}
