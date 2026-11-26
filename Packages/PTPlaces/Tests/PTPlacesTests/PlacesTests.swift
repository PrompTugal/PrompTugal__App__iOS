import Foundation
import CryptoKit
import SwiftUI
import Testing
import PTCore
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

    @Test("every capital shows, also one only places.json has; ids that start with another id stay apart")
    @MainActor func allCapitals() throws {
        let store = PlacesStore()
        store.index.preview(try decode(PlaceIndex.self, """
        {"built":"2026-11-25","places":[{"id":"portugal","name":"Portugal","kind":"country","parent":null},
         {"id":"algarve","name":"The Algarve","kind":"region","parent":"portugal"},
         {"id":"vila-real-de-santo-antonio","name":"Vila Real de Santo António","kind":"municipality","parent":"algarve","updated":"2026-11-16"},
         {"id":"lisboa","name":"Lisboa","kind":"city","parent":"portugal","updated":"2026-11-17"},
         {"id":"vila-real","name":"Vila Real","kind":"city","parent":"portugal","updated":"2026-11-17","at":{"lon":-7.746,"lat":41.3}}]}
        """))
        store.list.preview(try decode(PlaceIndex.self, """
        {"places":[{"id":"vila-real-de-santo-antonio","name":"VRSA","kind":"municipality","parent":"algarve","at":[-7.42,37.19]},
         {"id":"lisboa","name":"Lisboa","kind":"city","parent":"portugal","at":[-9.14,38.72]},
         {"id":"beja","name":"Beja","kind":"city","parent":"portugal","at":[-7.863,38.015]}]}
        """))
        #expect(store.algarveTowns.map(\.id) == ["vila-real-de-santo-antonio"])
        #expect(store.portugalCities.map(\.id) == ["lisboa", "vila-real", "beja"])
        #expect(store.place("vila-real-de-santo-antonio")?.name == "Vila Real de Santo António")
        #expect(store.place("vila-real-de-santo-antonio")?.at == [-7.42, 37.19])
        #expect(store.place("vila-real")?.at == [-7.746, 41.3])
        #expect(store.place("lisboa")?.at == [-9.14, 38.72])
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

// MARK: - Since you last looked (api/v1/since.json, 25 Nov)

private let sinceJSON = """
{"about":"x","version":"v0.1.2280","built":"2026-11-25","days":45,
 "places":[{"id":"portugal","name":"Portugal","kind":"country","parent":null},
           {"id":"vila-real","name":"Vila Real","kind":"city","parent":"portugal"},
           {"id":"vila-real-de-santo-antonio","name":"Vila Real de Santo António","kind":"municipality","parent":"algarve"}],
 "items":[
  {"kind":"story","date":"2026-11-17","title":"VRSA story","url":"https://postal.pt/a","publisher":"Postal","place":"vila-real-de-santo-antonio","rings":["vila-real-de-santo-antonio","algarve","portugal"],
   "license":{"name":"the source's terms","url":"https://postal.pt/"},"provenance":{"source_url":"https://postal.pt/a","read_on":"2026-11-17","kind":"story"}},
  {"kind":"article","date":"2026-11-24","title":"Our article","url":"https://promptugal.news/articles/a.html","place":null,"rings":["portugal"],
   "license":{"name":"CC BY 4.0","url":"https://creativecommons.org/licenses/by/4.0/","by":"PrompTugal.news"},"provenance":{"written_by":"journalist-ai@PrompTugal.vicky","published":"2026-11-24","kind":"article"}},
  {"kind":"story","date":"2026-11-17","title":"Vila Real story","url":"https://example.pt/b","place":"vila-real","rings":["vila-real","portugal"],"provenance":{"publisher":"Diário de Trás-os-Montes"}},
  {"kind":"story","date":"2026-11-20","title":"No link, dropped","place":"vila-real"},
  {"kind":"story","date":"2026-11-20","title":"Not a web link, dropped","url":"javascript:alert(1)"},
  {"date":"2026-11-19","url":"https://x.pt/no-title"},
  {"kind":"story","date":"2026-11-18","title":"Link only in provenance","provenance":{"source_url":"https://sul.pt/c","publisher":"Sul Informação"},"rings":"bad shape"}
 ]}
"""

@Suite("PTPlaces: since you last looked")
struct SinceTests {
    @Test("since.json decodes; items without a web link or title are dropped, never the feed")
    func decodes() throws {
        let feed = try decode(SinceFeed.self, sinceJSON)
        #expect(feed.built == "2026-11-25")
        #expect(feed.days == 45)
        #expect(feed.items.map(\.title) == ["VRSA story", "Our article", "Vila Real story", "Link only in provenance"])
        let fromProvenance = try #require(feed.items.last)
        #expect(fromProvenance.url == "https://sul.pt/c")
        #expect(fromProvenance.byline == "Sul Informação")
        #expect(fromProvenance.rings.isEmpty)
        #expect(feed.items[1].isArticle)
        #expect(feed.items[1].byline == "PrompTugal.news")
        #expect(feed.items[1].place == nil)
        #expect(feed.items[2].byline == "Diário de Trás-os-Montes")
        #expect(feed.items[0].licenseName == "the source's terms")
    }

    @Test("newest first; place names match exactly, even when one id starts with another")
    func orderAndPlaces() throws {
        let feed = try decode(SinceFeed.self, sinceJSON)
        #expect(feed.newestFirst.map(\.title) == ["Our article", "Link only in provenance", "VRSA story", "Vila Real story"])
        #expect(feed.placeName(for: feed.items[0]) == "Vila Real de Santo António")
        #expect(feed.placeName(for: feed.items[2]) == "Vila Real")
        #expect(feed.placeName(for: feed.items[1]) == "Portugal")
    }

    @Test("the marker keeps the newest day and its items; later days and unseen items of that day are new")
    func marker() throws {
        let feed = try decode(SinceFeed.self, sinceJSON)
        let seen = SinceMarker(showing: Array(feed.items.prefix(3)), at: Date(timeIntervalSince1970: 1_000))
        #expect(seen.day == "2026-11-24")
        #expect(seen.isNew(feed.items[1]) == false)
        #expect(seen.isNew(feed.items[0]) == false)
        let sameDay = SinceItem(date: "2026-11-24", title: "Another that day", url: "https://n.pt/1")
        let later = SinceItem(date: "2026-11-25", title: "Later", url: "https://n.pt/2")
        #expect(seen.isNew(sameDay))
        #expect(seen.isNew(later))
        let back = try #require(SinceMarker(raw: seen.raw))
        #expect(back == seen)
        #expect(SinceMarker(raw: "") == nil)
        #expect(SinceMarker(raw: "{\"day\":\"\"}") == nil)
    }

    @Test("the marker round-trips through UserDefaults")
    func markerStore() throws {
        let defaults = try #require(UserDefaults(suiteName: "ptplaces.since.test"))
        defaults.removePersistentDomain(forName: "ptplaces.since.test")
        #expect(SinceMarker.load(defaults) == nil)
        let marker = SinceMarker(day: "2026-11-25", ids: ["a|b"], at: Date(timeIntervalSince1970: 5))
        marker.save(defaults)
        #expect(SinceMarker.load(defaults) == marker)
    }
}

@Suite("PTPlaces: where the data came from")
struct OriginTests {
    let now = PlaceDates.parse("2026-11-25T22:00Z")!

    @Test("live only when read from the network and dated within a day")
    func live() {
        let o = PlacesOrigin.describe(pinned: false, phase: .loaded, fetched: now, dataDate: "2026-11-25", now: now)
        #expect(o.kind == .live)
        let yesterday = PlacesOrigin.describe(pinned: false, phase: .loaded, fetched: now, dataDate: "2026-11-24", now: now)
        #expect(yesterday.kind == .live)
    }

    @Test("data older than a day says its date, not live")
    func dated() {
        let o = PlacesOrigin.describe(pinned: false, phase: .loaded, fetched: now, dataDate: "2026-11-21", now: now)
        #expect(o.kind == .dated)
        #expect(o.text.contains("21 Nov 2026"))
        #expect(o.warns)
        let time = PlacesOrigin.describe(pinned: false, phase: .loaded, fetched: now, dataDate: "2026-11-24T20:00Z", now: now)
        #expect(time.kind == .dated)
    }

    @Test("a saved copy, the built-in snapshot, loading and failure each say so")
    func others() {
        #expect(PlacesOrigin.describe(pinned: false, phase: .failed("x"), fetched: now, dataDate: "2026-11-25", now: now).kind == .deviceCopy)
        #expect(PlacesOrigin.describe(pinned: false, phase: .idle, fetched: now, dataDate: nil, now: now).kind == .deviceCopy)
        #expect(PlacesOrigin.describe(pinned: true, phase: .loaded, fetched: now, dataDate: nil, now: now).kind == .snapshot)
        #expect(PlacesOrigin.describe(pinned: false, phase: .loading, fetched: nil, dataDate: nil, now: now).kind == .loading)
        #expect(PlacesOrigin.describe(pinned: false, phase: .failed("x"), fetched: nil, dataDate: nil, now: now).kind == .missing)
    }
}

@Suite("PTPlaces: a town page's news and events (api/v1/by-place/<id>.json, 25 Nov)")
struct TownPageTests {
    let json = """
    {"id":"faro","name":"Faro","kind":"municipality","parent":"algarve","updated":"2026-11-16",
     "ai_news":[
      {"title":"Older","summary":"s","date":"2026-11-06","publisher":"Sul Informação","url":"https://www.sulinformacao.pt/a","read_on":"2026-11-07","steps":0,
       "license":{"name":"the source's terms","url":"https://www.sulinformacao.pt/"}},
      {"title":"Newest","summary":"s","date":"2026-11-16","url":"https://www.barlavento.pt/b","steps":2,"hold":"held under R12",
       "provenance":{"source_url":"https://www.barlavento.pt/b","publisher":"Barlavento","read_on":"2026-11-16","signature":"valid"}},
      {"title":"No link, not shown","date":"2026-11-20","publisher":"X"},
      {"title":"Not a web link, not shown","date":"2026-11-19","url":"mailto:a@b.pt"},
      {"title":"Host as outlet","date":"2026-11-12","url":"https://postal.pt/c"}
     ],
     "events":[
      {"title":"Month of AI","date":"2026-11-01 to 2026-11-30","url":"https://www.cm-faro.pt/e1","read_on":"2026-11-15"},
      {"title":"No date","date":"date not shown","provenance":{"source_url":"https://www.unicornfactorylisboa.com/","read_on":"2026-11-16"}},
      {"title":"Later","date":"2026-11-25","note":null,"provenance":{"source_url":"https://startupportugal.com/","publisher":null,"read_on":"2026-11-16"}},
      {"date":"2026-11-30","url":"https://no-title.pt"}
     ]}
    """

    @Test("news shows newest first, only with a web source link, with its outlet")
    func news() throws {
        let file = try decode(PlaceFile.self, json)
        #expect(file.aiNews.count == 5)
        let shown = file.newsNewestFirst
        #expect(shown.map(\.title) == ["Newest", "Host as outlet", "Older"])
        #expect(shown[0].outlet == "Barlavento")
        #expect(shown[0].readOn == "2026-11-16")
        #expect(shown[1].outlet == "postal.pt")
        #expect(shown[2].outlet == "Sul Informação")
        #expect(shown.allSatisfy { $0.sourceLink != nil })
        #expect(shown[0].isHeld)
        #expect(shown[0].hold == "held under R12")
        #expect(shown[1].isHeld == false)
        #expect(NewsItem(title: "made in code").isHeld == false)
    }

    @Test("events: latest date first, unreadable dates last, links from provenance, host as outlet")
    func events() throws {
        let file = try decode(PlaceFile.self, json)
        let events = file.eventsNewestFirst
        #expect(events.map(\.title) == ["Later", "Month of AI", "No date"])
        #expect(events[0].url == "https://startupportugal.com/")
        #expect(events[0].outlet == "startupportugal.com")
        #expect(events[0].readOn == "2026-11-16")
        #expect(events[1].outlet == "www.cm-faro.pt")
        #expect(events[2].sourceLink?.host() == "www.unicornfactorylisboa.com")
    }
}

@Suite("PTPlaces: news bubbling up from the town (since.json rings)")
struct BubblingTests {
    @Test("rings match exactly, so Vila Real never collects Vila Real de Santo António's stories")
    func reaching() throws {
        let feed = try decode(SinceFeed.self, sinceJSON)
        #expect(feed.items(reaching: "vila-real").map(\.title) == ["Vila Real story"])
        #expect(feed.items(reaching: "vila-real-de-santo-antonio").map(\.title) == ["VRSA story"])
        #expect(feed.items(reaching: "algarve").map(\.title) == ["VRSA story"])
        #expect(feed.items(reaching: "portugal").count == 3)
    }

    @Test("a story's trail runs town, region, country; unknown ids still get a name")
    func trail() throws {
        let feed = try decode(SinceFeed.self, sinceJSON)
        #expect(feed.trail(for: feed.items[0]).map(\.name) == ["Vila Real de Santo António", "Algarve", "Portugal"])
        #expect(feed.trail(for: feed.items[1]).map(\.id) == ["portugal"])
        let noRings = SinceItem(date: "2026-11-20", title: "t", url: "https://a.pt", place: "vila-real")
        #expect(feed.trail(for: noRings).map(\.id) == ["vila-real"])
    }

    @Test("town stories leave out the country's; the featured town is the first followed one with a story")
    func featured() throws {
        let feed = try decode(SinceFeed.self, sinceJSON)
        #expect(Set(feed.townItems.map(\.title)) == ["VRSA story", "Vila Real story"])
        #expect(feed.featuredTown(followed: ["faro", "vila-real"]) == "vila-real")
        let any = try #require(feed.featuredTown(followed: []))
        #expect(["vila-real", "vila-real-de-santo-antonio"].contains(any))
        #expect(SinceFeed().featuredTown(followed: ["faro"]) == nil)
    }
}

@Suite("PTPlaces: deep links into a place page (spec S5)")
struct DeepLinkTests {
    @Test("place:<id>, #now and #lead read; anything else is refused or loses only the anchor")
    func parse() {
        #expect(PlacesDeepLink("place:loule") == PlacesDeepLink(id: "loule"))
        #expect(PlacesDeepLink("place:loule#lead") == PlacesDeepLink(id: "loule", anchor: .lead))
        #expect(PlacesDeepLink("place:vila-real-de-santo-antonio#now")?.anchor == .now)
        #expect(PlacesDeepLink("place:vila-real#now")?.id == "vila-real")
        #expect(PlacesDeepLink("place:faro#map") == PlacesDeepLink(id: "faro"))
        #expect(PlacesDeepLink("place:") == nil)
        #expect(PlacesDeepLink("place:#lead") == nil)
        #expect(PlacesDeepLink("local.maps") == nil)
        #expect(PlacesDeepLink(id: "loule", anchor: .lead).text == "place:loule#lead")
        #expect(PlacesDeepLink(id: "loule").text == "place:loule")
    }
}

@Suite("PTPlaces: the news home (PortugalHomeView)")
struct NewsHomeTests {
    @Test("lead and top stories are local; placeless items go to Also in the news")
    func front() throws {
        let feed = try decode(SinceFeed.self, sinceJSON)
        let lead = try #require(feed.lead)
        #expect(lead.title == "VRSA story")
        #expect(feed.topStories(limit: 10, excluding: [lead.id]).map(\.title) == ["Vila Real story"])
        #expect(feed.alsoInTheNews(limit: 5).map(\.title) == ["Our article", "Link only in provenance"])
        #expect(SinceFeed().lead == nil)
    }

    @Test("a placeless item is local when its title names a place, accents and case aside, whole words only")
    func local() throws {
        let feed = try decode(SinceFeed.self, sinceJSON)
        #expect(feed.isLocal(SinceItem(date: "2026-11-23", title: "AI use in Portugal jumps in 2026", url: "https://a.pt")))
        #expect(feed.isLocal(SinceItem(date: "2026-11-23", title: "VILA REAL DE SANTO ANTONIO buys AI tools", url: "https://a.pt")))
        #expect(feed.isLocal(SinceItem(date: "2026-11-23", title: "A study in Vila Real, Trás-os-Montes", url: "https://a.pt")))
        #expect(!feed.isLocal(SinceItem(date: "2026-11-23", title: "CrewAI raises a round; Spotify ships agents", url: "https://a.pt")))
        #expect(!feed.isLocal(SinceItem(date: "2026-11-23", title: "Portugalia airline news", url: "https://a.pt")))
        #expect(feed.isLocal(SinceItem(date: "2026-11-23", title: "Portuguese startups raising", url: "https://a.pt")))
        let summit = SinceItem(date: "2026-11-23", title: "Web Summit Lisbon: your first day", url: "https://a.pt")
        #expect(SinceFeed.isAboutWebSummit(summit))
        #expect(!SinceFeed.isAboutWebSummit(SinceItem(date: "2026-11-23", title: "A summit on the web", url: "https://a.pt")))
    }

    @Test("Places opens on Portugal")
    func scope() {
        #expect(MapScope.allCases.first == .portugal)
    }
}

@Suite("PTPlaces: town colours in light mode (design review D)")
struct AccentClampTests {
    @Test("a light colour is darkened to 45% lightness, keeping its hue; a dark one is left alone")
    func clamp() {
        // #F2C14E, a light amber: L about 0.63.
        let light = PlaceTheme.clamp(red: 0xF2 / 255.0, green: 0xC1 / 255.0, blue: 0x4E / 255.0)
        let high = max(light.red, light.green, light.blue), low = min(light.red, light.green, light.blue)
        #expect(abs((high + low) / 2 - 0.45) < 0.001)
        #expect(light.red > light.green && light.green > light.blue)
        // #9A3412, Loulé's terracotta: L about 0.34, unchanged.
        let dark = PlaceTheme.clamp(red: 0x9A / 255.0, green: 0x34 / 255.0, blue: 0x12 / 255.0)
        #expect(dark.red == 0x9A / 255.0 && dark.green == 0x34 / 255.0 && dark.blue == 0x12 / 255.0)
        let white = PlaceTheme.clamp(red: 1, green: 1, blue: 1)
        #expect(white.red == 0.45 && white.green == 0.45 && white.blue == 0.45)
    }
}

// MARK: - The article reader (api/v1/articles/<id>.json, the .md.sig and board/keys.json, 26 Nov)

// A throwaway P-256 key made for this test; only its public half is here. The twin is signed in form 2.
private let testTwin = """
# Test article

*Source: <https://promptugal.news/articles/test-article.html> · site v0.1.2293 · generated from the same content as the page.*

Body line. built by: a body line that stays

```
version: v0.1.2293
built by: the agents, operator X
```

"""
private let testPEM = """
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEALkaGKd4PKiMVyL6Soa0l4COF8jG
MjTsO0T/atiy4UYbPEkCB9mt4ffs/3DLOcplyxRHB7Vr6FR++ctSUIrYDg==
-----END PUBLIC KEY-----
"""
private let testSignature = ArticleSignature(
    signature: "OyI9W/gtDCdDVRkhQULjNQekyH/9/VnC3gNr7FMp945HhqHWcwBG9S/LyMJTRhAojsbS2CzwcbBVu24jV3lIKg==",
    fingerprint: "sha256:33909fb7bd6a1a1a", form: "twin-without-version-or-builder/2")

// reviewer@PrompTugal.vicky's public signing key as published in board/keys.json (signing_fingerprint 9bdecdbf857ccf8b).
private let reviewerPEM = """
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEyYn9R4s7OjGqDNZVt76p0ZJmPLYq
N0Mu4DqYRfpJcFly5Yqo2ZEsyDu7Zb2sI73DwebxyVveGoJmoEqq+UP9aA==
-----END PUBLIC KEY-----
"""

@Suite("PTPlaces: the article reader and its signature check")
struct ArticleTests {
    @Test("the signed form writes the versions as VERSION and only the last line-start 'built by' as BUILDER")
    func form() {
        let form = ArticleSigning.signedForm(testTwin)
        #expect(form.contains("· site VERSION ·"))
        #expect(form.contains("\nversion: VERSION\n"))
        #expect(form.contains("\nbuilt by: BUILDER\n"))
        #expect(form.contains("Body line. built by: a body line that stays"))
        #expect(!form.contains("v0.1.2293"))
    }

    @Test("fingerprints are SHA-256 of the key's DER, 16 hex digits, as the site writes them")
    func fingerprint() {
        #expect(ArticleSigning.fingerprint(pem: reviewerPEM) == "sha256:9bdecdbf857ccf8b")
        #expect(ArticleSigning.fingerprint(pem: testPEM) == "sha256:33909fb7bd6a1a1a")
        #expect(ArticleSigning.fingerprint(pem: "not a key") == nil)
    }

    @Test("a good signature verifies; a changed text fails; a missing key, an old form or junk is not checked")
    func check() {
        let key = SigningKey(id: "test-key", agent: "tester@PrompTugal.test", signPEM: testPEM)
        let other = SigningKey(id: "reviewer", agent: "reviewer@PrompTugal.vicky", signPEM: reviewerPEM)
        #expect(ArticleSigning.check(twin: testTwin, signature: testSignature, keys: [other, key])
                == .verified(agent: "tester@PrompTugal.test", keyID: "test-key", handedOver: false))
        // A new site version does not break it: the version is not signed.
        let newVersion = testTwin.replacingOccurrences(of: "v0.1.2293", with: "v0.1.9999")
        #expect(ArticleSigning.check(twin: newVersion, signature: testSignature, keys: [key])
                == .verified(agent: "tester@PrompTugal.test", keyID: "test-key", handedOver: false))
        let changed = testTwin.replacingOccurrences(of: "Body line.", with: "Body line, changed.")
        if case .failed = ArticleSigning.check(twin: changed, signature: testSignature, keys: [key]) {} else {
            Issue.record("a changed text must fail")
        }
        if case .notChecked = ArticleSigning.check(twin: testTwin, signature: testSignature, keys: [other]) {} else {
            Issue.record("no key with that fingerprint must not be checked")
        }
        var old = testSignature
        old.form = "twin-without-version/1"
        #expect(ArticleSigning.check(twin: testTwin, signature: old, keys: [key]) == .olderForm)
        old.form = ""
        #expect(ArticleSigning.check(twin: testTwin, signature: old, keys: [key]) == .olderForm)
        let handedOver = SigningKey(id: "test-key", agent: "tester@PrompTugal.test", status: "superseded", signPEM: testPEM)
        #expect(ArticleSigning.check(twin: testTwin, signature: testSignature, keys: [handedOver])
                == .verified(agent: "tester@PrompTugal.test", keyID: "test-key", handedOver: true))
        let twoBuilders = testTwin + "built by: someone else\n"
        if case .notChecked = ArticleSigning.check(twin: twoBuilders, signature: testSignature, keys: [key]) {} else {
            Issue.record("two built-by lines must not be checked")
        }
        var junk = testSignature
        junk.signature = "bm90IGEgc2lnbmF0dXJl"
        if case .notChecked = ArticleSigning.check(twin: testTwin, signature: junk, keys: [key]) {} else {
            Issue.record("junk must not be checked")
        }
    }

    @Test("the record, the signature file, the keys and the provenance decode leniently")
    func decode() throws {
        let record = try PTPlacesTestsDecode.decode(ArticleRecord.self, """
        {"id":"ai-use-in-portugal-2026","title":"AI use in Portugal jumps in 2026","date":"2026-11-23","author":"analyst@PrompTugal.vicky",
         "summary":"s","words":"819","town":null,
         "sources":[{"url":"https://www.ine.pt/x","host":"www.ine.pt","text":"INE"},{"url":"javascript:x","text":"dropped"},{"text":"no url, dropped"},
                    {"url":"https://ec.europa.eu/eurostat/y"}]}
        """)
        #expect(record.sources.map(\.host) == ["www.ine.pt", "ec.europa.eu"])
        #expect(record.words == 819)
        #expect(record.page == "https://promptugal.news/articles/ai-use-in-portugal-2026.html")
        let keys = try PTPlacesTestsDecode.decode(SigningKeys.self, """
        {"about":"x","keys":[{"id":"a","agent":"a@x","status":"active","bundle":{"v":1,"sign":"PEM"}},{"id":"b","bundle":{"v":1}},{"id":"c"}]}
        """)
        #expect(keys.keys.map(\.id) == ["a"])
        let provenance = try PTPlacesTestsDecode.decode(ArticleProvenanceFile.self, """
        {"ladder":{"P0":"Draft","P2":"Sourced"},"articles":[
         {"url":"articles/cocus-hubs.html","level":"P2","words":{"type":"News","origin":"written by an AI agent","research":"researched by AI agents","level":"P2","level_name":"Sourced"}},
         {"url":"articles/cocus.html","type":null,"level":null,"words":null}]}
        """)
        #expect(provenance.entry(for: "cocus-hubs")?.levelName == "Sourced")
        #expect(provenance.entry(for: "cocus")?.isEmpty == true)
        #expect(provenance.entry(for: "cocus-h") == nil)
    }

    @Test("only our article links open the reader; ids that start with another id stay apart")
    func links() {
        #expect(ArticleLinks.id(from: "https://promptugal.news/articles/ai-use-in-portugal-2026.html") == "ai-use-in-portugal-2026")
        #expect(ArticleLinks.id(from: "https://promptugal.news/articles/cocus.md") == "cocus")
        #expect(ArticleLinks.id(from: "https://postal.pt/articles/x.html") == nil)
        #expect(ArticleLinks.id(from: "https://promptugal.news/algarve/faro/") == nil)
        #expect(ArticleLinks.id(from: "https://promptugal.news/articles/../x.html") == nil)
    }
}

enum PTPlacesTestsDecode {
    static func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }
}

// MARK: - English and Portuguese (Dinis, 26 Nov)

@Suite("PTPlaces: Portuguese (Portugal) catalogue and the site's translation memory")
struct LanguageTests {
    @Test("memory keys match the site's: normalised English, SHA-256, 16 hex")
    func keys() {
        #expect(TMKey.key("PrompTugal.news Faro: AI and technology in Faro.") == "26e6678e7cec55b9")
        #expect(TMKey.normalise("  Two  spaces\u{00A0}and NBSP \r\n\r\n\r\nthen lines  ") == "Two spaces and NBSP\n\nthen lines")
        #expect(TMKey.key("  Two  spaces\u{00A0}and NBSP \r\n\r\n\r\nthen lines  ") == "4295c07f14e3c01c")
        // NFC: a decomposed é keys the same as the composed one.
        #expect(TMKey.key("Loule\u{0301} decomposed") == "cbeeab8828b29d19")
        #expect(TMKey.key("Loulé decomposed") == "cbeeab8828b29d19")
    }

    @Test("a shard decodes leniently: entries without a translation are dropped; ok marks a checked one")
    func shard() throws {
        let shard = try PTPlacesTestsDecode.decode(TMShard.self, """
        {"26e6678e7cec55b9":{"t":"PrompTugal.news Faro: IA e tecnologia em Faro.","by":"translator@PrompTugal.dinis","ok":false},
         "26aaaaaaaaaaaaaa":{"t":"Verificada","ok":true},
         "26bbbbbbbbbbbbbb":{"by":"no text"},
         "26cccccccccccccc":"not an object"}
        """)
        #expect(shard.entries.count == 2)
        #expect(shard.entries["26e6678e7cec55b9"]?.text == "PrompTugal.news Faro: IA e tecnologia em Faro.")
        #expect(shard.entries["26e6678e7cec55b9"]?.checked == false)
        #expect(shard.entries["26aaaaaaaaaaaaaa"]?.checked == true)
    }

    @Test("in English the memory is not used: prose stays as written")
    @MainActor func englishUntouched() {
        #expect(PlacesLanguage.isPortuguese == false)
        #expect(PlacesTranslation.shared.entry("PrompTugal.news Faro: AI and technology in Faro.") == nil)
        #expect(PlacesTranslation.shared.text("PrompTugal.news Faro: AI and technology in Faro.") == "PrompTugal.news Faro: AI and technology in Faro.")
    }

    @Test("the catalogue has Portuguese (Portugal) for the interface, format specifiers intact")
    func catalogue() throws {
        let path = try #require(Bundle.module.path(forResource: "pt-PT", ofType: "lproj"))
        let pt = try #require(Bundle(path: path))
        #expect(pt.localizedString(forKey: "Since you last looked", value: nil, table: nil) == "Desde a última visita")
        #expect(pt.localizedString(forKey: "Read at %@", value: nil, table: nil) == "Ler em %@")
        #expect(pt.localizedString(forKey: "Machine translation, not reviewed · see in English", value: nil, table: nil)
                == "Tradução automática, não revista · ver em inglês")
        let format = pt.localizedString(forKey: "%lld new since %@", value: nil, table: nil)
        #expect(String(format: format, 3, "26 nov") == "3 novas desde 26 nov")
    }

    @Test("the translatable prose is the mandate, the centre of gravity and the story summaries, not the headlines")
    func prose() throws {
        let file = try decode(PlaceFile.self, louleJSON)
        #expect(file.translatableProse.contains("PrompTugal.news Loulé: AI and technology in Loulé."))
        #expect(file.translatableProse.contains("Institutional more than corporate."))
        #expect(!file.translatableProse.contains("Council buys AI tools"))
    }
}
