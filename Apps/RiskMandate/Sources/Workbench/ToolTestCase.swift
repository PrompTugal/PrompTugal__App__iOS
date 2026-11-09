import Foundation

// Reader for the shared tool-test cases, format `abp-tooltest/1`, defined in
// PrompTugal/PrompTugal__App__Mobile scenarios/tool-tests/README.md and schema.json.
// The same files drive Android's Workbench; Swift field names follow the JSON (snake_case
// mapped to camelCase). Only reading and validating the files lives here; the checker and
// the runner come with Stage B.

struct ToolTestFile: Decodable, Equatable, Sendable {
    static let format = "abp-tooltest/1"

    let format: String
    let version: String
    let synthetic: Bool
    let kind: String
    let title: String
    let judges: [ToolTestJudgeLayer]?
    let cases: [ToolTestCase]
}

/// A file-level judge layer: `code`, `local` or `cloud`.
struct ToolTestJudgeLayer: Decodable, Equatable, Sendable {
    let layer: String
    let model: String?
    let promptRef: String?

    enum CodingKeys: String, CodingKey { case layer, model, promptRef = "prompt_ref" }
}

struct ToolTestCase: Decodable, Equatable, Sendable, Identifiable {
    let id: String
    let tests: String
    let system: String?
    let messages: [ToolTestMessage]
    let tools: [ToolTestTool]
    let fakeTools: [String: JSONValue]
    let checks: [ToolTestCheck]
    let maxSteps: Int?
    let reference: ToolTestScript?
    let wrong: ToolTestScript?
    let judges: ToolTestCaseJudge?

    /// Model turns allowed: default 3, at most 6.
    var steps: Int { min(max(maxSteps ?? 3, 1), 6) }

    enum CodingKeys: String, CodingKey {
        case id, tests, system, messages, tools, checks, reference, wrong, judges
        case fakeTools = "fake_tools", maxSteps = "max_steps"
    }
}

struct ToolTestMessage: Decodable, Equatable, Sendable {
    let role: String
    let text: String
    let name: String?
    let toolCalls: [ToolTestCall]?

    enum CodingKeys: String, CodingKey { case role, text, name, toolCalls = "tool_calls" }
}

struct ToolTestTool: Decodable, Equatable, Sendable {
    let name: String
    let description: String
    let parameters: JSONValue
}

struct ToolTestCall: Decodable, Equatable, Sendable {
    let name: String
    let arguments: [String: JSONValue]
}

/// A check: its `kind` plus its parameters, kept as JSON so new kinds still read.
struct ToolTestCheck: Decodable, Equatable, Sendable {
    let kind: String
    let label: String?
    let parameters: [String: JSONValue]

    init(from decoder: Decoder) throws {
        var all = try [String: JSONValue](from: decoder)
        guard let kind = all.removeValue(forKey: "kind")?.string else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "A check needs a kind"))
        }
        self.kind = kind
        self.label = all.removeValue(forKey: "label")?.string
        self.parameters = all
    }
}

/// A scripted run (`reference` must pass every check, `wrong` must fail one).
struct ToolTestScript: Decodable, Equatable, Sendable {
    struct Step: Decodable, Equatable, Sendable {
        let text: String
        let calls: [ToolTestCall]
    }
    let steps: [Step]
}

struct ToolTestCaseJudge: Decodable, Equatable, Sendable {
    let ask: String
    let expect: String
}

enum ToolTestError: LocalizedError, Equatable {
    case wrongFormat(String)
    case notSynthetic(String)
    case invalid(String)

    var errorDescription: String? {
        switch self {
        case .wrongFormat(let f): "Not an abp-tooltest/1 file (format \(f))."
        case .notSynthetic(let t): "\(t) is not marked synthetic."
        case .invalid(let why): why
        }
    }
}

enum ToolTestCatalogue {
    /// The PrompTugal__App__Mobile commit the bundled files were copied from (scripts/apps/sync-tool-tests.sh).
    static let sourceCommit = "7433286"
    static let checkKinds: Set<String> = [
        "tool_called", "tools_called_in_order", "args_valid", "args_equal", "no_tool",
        "no_unoffered_tool", "value_absent", "answers_after_result", "max_calls",
        "answer_contains", "answer_absent", "answer_max_chars", "answer_lines",
        "answer_json_only", "answer_number_between", "answer_grounded",
    ]

    static func decode(_ data: Data) throws -> ToolTestFile {
        let file = try JSONDecoder().decode(ToolTestFile.self, from: data)
        try validate(file)
        return file
    }

    /// The rules the README states that a reader can check without running a model.
    static func validate(_ file: ToolTestFile) throws {
        guard file.format == ToolTestFile.format else { throw ToolTestError.wrongFormat(file.format) }
        guard file.synthetic else { throw ToolTestError.notSynthetic(file.title) }
        for c in file.cases {
            guard c.id.range(of: "^[a-z0-9-]+$", options: .regularExpression) != nil else {
                throw ToolTestError.invalid("Case id \(c.id) must be lowercase letters, digits and hyphens.")
            }
            guard c.tools.count <= 5 else { throw ToolTestError.invalid("\(c.id): more than 5 tools.") }
            guard Set(c.fakeTools.keys) == Set(c.tools.map(\.name)) else {
                throw ToolTestError.invalid("\(c.id): fake_tools must have exactly one entry per offered tool.")
            }
            guard c.messages.first?.role == "user" else { throw ToolTestError.invalid("\(c.id): the first message must be the user's.") }
            guard (c.maxSteps ?? 3) <= 6 else { throw ToolTestError.invalid("\(c.id): max_steps is at most 6.") }
            for check in c.checks where !checkKinds.contains(check.kind) {
                throw ToolTestError.invalid("\(c.id): unknown check kind \(check.kind).")
            }
        }
    }

    /// Every bundled case file, sorted by name.
    static func bundled(in bundle: Bundle = .main) throws -> [ToolTestFile] {
        // Xcode copies the files flat into the bundle; also look in ToolTests/ in case that changes.
        let found = (bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? [])
            + (bundle.urls(forResourcesWithExtension: "json", subdirectory: "ToolTests") ?? [])
        let urls = found
            .filter { $0.lastPathComponent.range(of: "^[0-9]{2}_", options: .regularExpression) != nil }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        return try urls.map { try decode(Data(contentsOf: $0)) }
    }
}
