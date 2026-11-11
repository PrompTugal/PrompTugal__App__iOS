import Foundation
import Testing
@testable import RiskMandate

@Suite("Workbench metrics")
struct RunMetricsTests {
    @Test("tokens per second counts the tokens after the first, over the time after the first")
    func speedAfterFirstToken() {
        let m = RunMetrics(timeToFirstToken: 0.5, total: 2.5, tokens: 41, tokensAreEstimated: true)
        #expect(m.tokensPerSecond == 20)
    }

    @Test("a single chunk falls back to tokens over total time")
    func singleChunk() {
        let m = RunMetrics(timeToFirstToken: 1, total: 1, tokens: 10, tokensAreEstimated: true)
        #expect(m.tokensPerSecond == 10)
    }

    @Test("no tokens, no speed")
    func empty() {
        #expect(RunMetrics(timeToFirstToken: nil, total: 1, tokens: 0, tokensAreEstimated: true).tokensPerSecond == nil)
        #expect(RunMetrics(timeToFirstToken: nil, total: 0, tokens: 5, tokensAreEstimated: true).tokensPerSecond == nil)
    }

    @Test("the estimate is about four characters a token")
    func estimate() {
        #expect(TokenEstimate.tokens(in: "") == 0)
        #expect(TokenEstimate.tokens(in: "a") == 1)
        #expect(TokenEstimate.tokens(in: String(repeating: "x", count: 400)) == 100)
    }

    @Test("the clock keeps the first chunk and measures to the end")
    func clock() {
        let start = ContinuousClock.Instant.now
        var clock = RunClock(start: start)
        clock.markChunk(at: start.advanced(by: .milliseconds(250)))
        clock.markChunk(at: start.advanced(by: .milliseconds(900)))
        let m = clock.finish(text: String(repeating: "x", count: 40), at: start.advanced(by: .seconds(2)))
        #expect(abs((m.timeToFirstToken ?? 0) - 0.25) < 1e-9)
        #expect(abs(m.total - 2) < 1e-9)
        #expect(m.tokens == 10)
        #expect(m.tokensAreEstimated)
    }
}

@Suite("Workbench without a model")
@MainActor
struct WorkbenchUnavailableTests {
    @Test("an unavailable model cannot run, and running does nothing")
    func unavailable() async {
        let model = WorkbenchModel(status: .unavailable("no Apple Intelligence"))
        #expect(!model.canRun)
        await model.run()
        #expect(model.answer.isEmpty)
        #expect(model.metrics == nil)
        #expect(model.error == nil)
    }

    @Test("an empty prompt cannot run")
    func emptyPrompt() {
        let model = WorkbenchModel(status: .available)
        model.prompt = "  \n"
        #expect(!model.canRun)
    }

    @Test("asking for the status never crashes, with or without Apple Intelligence")
    func statusIsReadable() {
        _ = OnDeviceModel.status
    }
}
