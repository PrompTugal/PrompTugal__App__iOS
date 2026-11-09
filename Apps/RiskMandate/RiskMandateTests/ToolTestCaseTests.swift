import Foundation
import Testing
@testable import RiskMandate

@Suite("Shared tool-test cases (abp-tooltest/1)")
struct ToolTestCaseTests {
    @Test("all 13 bundled files from PrompTugal__App__Mobile read and validate")
    func bundledFilesRead() throws {
        let files = try ToolTestCatalogue.bundled()
        #expect(files.count == 13)
        #expect(files.allSatisfy { $0.format == "abp-tooltest/1" && $0.synthetic })
        let ids = files.flatMap(\.cases).map(\.id)
        #expect(ids.count == 40)
        #expect(Set(ids).count == ids.count, "case ids are unique across the catalogue")
        #expect(files.flatMap(\.cases).allSatisfy { $0.reference != nil && $0.wrong != nil })
    }

    @Test("a two-step case keeps its tools, fakes, checks and scripts")
    func twoStep() throws {
        let file = try #require(try ToolTestCatalogue.bundled().first { $0.kind == "two_step" })
        let c = try #require(file.cases.first { $0.id == "two-step-order" })
        #expect(c.tools.map(\.name) == ["lookup_order", "get_tracking", "cancel_order"])
        #expect(c.fakeTools["lookup_order"]?["returns"] == .string("ORD-4471"))
        #expect(c.steps == 4)
        let args = try #require(c.checks.first { $0.kind == "args_equal" })
        #expect(args.label == "uses the id the lookup returned")
        #expect(args.parameters["value"] == .string("ORD-4471"))
        #expect(c.reference?.steps.first?.calls.first?.arguments["customer"] == .string("Ana"))
        #expect(c.judges?.expect == "pass")
    }

    @Test("a conversation that already holds a tool call and its result reads")
    func toolMessages() throws {
        let file = try #require(try ToolTestCatalogue.bundled().first { $0.kind == "answer_after_result" })
        let msgs = file.cases[0].messages
        #expect(msgs.contains { $0.role == "assistant" && !($0.toolCalls ?? []).isEmpty })
        #expect(msgs.contains { $0.role == "tool" && $0.name != nil })
    }

    @Test("wrong format, unsynthetic data and unknown checks are refused")
    func refusals() {
        let base = #"{"format":"%@","version":"1","synthetic":%@,"kind":"k","title":"T","cases":[{"id":"a-1","tests":"t","messages":[{"role":"user","text":"hi"}],"tools":[],"fake_tools":{},"checks":[{"kind":"%@"}]}]}"#
        func data(_ f: String, _ s: String, _ k: String) -> Data {
            Data(String(format: base, f, s, k).utf8)
        }
        #expect(throws: ToolTestError.wrongFormat("other/1")) { try ToolTestCatalogue.decode(data("other/1", "true", "no_tool")) }
        #expect(throws: ToolTestError.notSynthetic("T")) { try ToolTestCatalogue.decode(data("abp-tooltest/1", "false", "no_tool")) }
        #expect(throws: ToolTestError.self) { try ToolTestCatalogue.decode(data("abp-tooltest/1", "true", "made_up")) }
        #expect(throws: Never.self) { try ToolTestCatalogue.decode(data("abp-tooltest/1", "true", "no_tool")) }
    }
}
