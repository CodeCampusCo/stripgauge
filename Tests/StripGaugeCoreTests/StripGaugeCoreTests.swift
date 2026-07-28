import Foundation
import Testing

@testable import StripGaugeCore

private let noon = Date(timeIntervalSince1970: 1_785_248_000)
private let nowSeconds = Int(noon.timeIntervalSince1970)
private let liveWindow = nowSeconds + 3_600
private let endedWindow = nowSeconds - 3_600

// MARK: - Parsing Claude Code's payload

@Test func parsesBothRateLimitWindows() throws {
    let json = """
    {"rate_limits":{"five_hour":{"used_percentage":23.5,"resets_at":1738425600},
     "seven_day":{"used_percentage":41.2,"resets_at":1738857600}},
     "context_window":{"used_percentage":8},"session_id":"abc123"}
    """
    let input = try StatuslineInput.decode(Data(json.utf8))

    #expect(input.rateLimits?.fiveHour?.usedPercentage == 23.5)
    #expect(input.rateLimits?.fiveHour?.resetsAt == 1_738_425_600)
    #expect(input.rateLimits?.sevenDay?.usedPercentage == 41.2)
    #expect(input.contextPercent == 8)
    #expect(input.sessionId == "abc123")
}

@Test func toleratesAbsentRateLimits() throws {
    // A session before its first API response, or a plan that reports no limits.
    let input = try StatuslineInput.decode(Data(#"{"model":{"display_name":"Opus"}}"#.utf8))
    let state = input.state(at: noon)

    #expect(state.fiveHour.isEmpty)
    #expect(state.sevenDay.isEmpty)
    #expect(state.worstPercent(now: noon) == nil)
}

@Test func toleratesOneWindowMissing() throws {
    let json = #"{"rate_limits":{"five_hour":{"used_percentage":12}}}"#
    let state = try StatuslineInput.decode(Data(json.utf8)).state(at: noon)

    #expect(state.fiveHour.percent == 12)
    #expect(state.sevenDay.isEmpty)
}

@Test func ignoresUnknownFields() throws {
    let json = #"{"future_field":{"nested":true},"rate_limits":{"seven_day":{"used_percentage":5}}}"#
    let state = try StatuslineInput.decode(Data(json.utf8)).state(at: noon)

    #expect(state.sevenDay.percent == 5)
}

// MARK: - Reconciling observations from concurrent sessions

@Test func aReadingFromAnEndedWindowLosesToALiveOne() {
    // The bug this exists to prevent: a session left open for hours keeps
    // republishing the percentage from its last API response, which belongs to a
    // five-hour window that has since rolled over. Observed 2026-07-28 as the
    // gauge flickering between 3% and 55% every few seconds.
    let stale = WindowReading(percent: 55, resetsAt: endedWindow)
    let live = WindowReading(percent: 3, resetsAt: liveWindow)

    #expect(WindowReading.preferred(stale, over: live, now: nowSeconds) == live)
    #expect(WindowReading.preferred(live, over: stale, now: nowSeconds) == live)
}

@Test func aNewWindowWinsEvenThoughItsNumberIsLower() {
    // A reset drops usage from 55% to 0%; that is the true value, not a regression.
    let before = WindowReading(percent: 55, resetsAt: liveWindow)
    let after = WindowReading(percent: 0, resetsAt: liveWindow + 18_000)

    #expect(WindowReading.preferred(after, over: before, now: nowSeconds) == after)
}

@Test func withinOneWindowTheLargerNumberWins() {
    // Two sessions both active: the higher figure came from the later response,
    // because usage only accumulates until the window resets.
    let older = WindowReading(percent: 12, resetsAt: liveWindow)
    let newer = WindowReading(percent: 19, resetsAt: liveWindow)

    #expect(WindowReading.preferred(older, over: newer, now: nowSeconds) == newer)
    #expect(WindowReading.preferred(newer, over: older, now: nowSeconds) == newer)
}

@Test func anEndedWindowShowsNothingRatherThanItsLastNumber() {
    let ended = WindowReading(percent: 55, resetsAt: endedWindow)

    #expect(ended.livePercent(now: nowSeconds) == nil)
    #expect(ended.hasExpired(now: nowSeconds))
}

@Test func aReadingWithoutAResetTimeIsStillUsable() {
    // Older Claude Code versions may omit resets_at; a number is better than none.
    let undated = WindowReading(percent: 42, resetsAt: nil)

    #expect(undated.livePercent(now: nowSeconds) == 42)
    #expect(WindowReading.preferred(undated, over: .unknown, now: nowSeconds) == undated)
}

@Test func freshSessionWithoutRateLimitsKeepsPublishedNumbers() {
    let published = GaugeState(
        fiveHour: WindowReading(percent: 24, resetsAt: liveWindow),
        sevenDay: WindowReading(percent: 41, resetsAt: liveWindow),
        updatedAt: noon
    )
    let empty = GaugeState(fiveHour: .unknown, sevenDay: .unknown, updatedAt: noon)

    let merged = empty.merged(over: published, now: noon)

    #expect(merged.fiveHour.percent == 24)
    #expect(merged.sevenDay.percent == 41)
    #expect(merged.updatedAt == nowSeconds)
}

@Test func staleStateOnDiskContributesNothing() {
    let ancient = GaugeState(
        fiveHour: WindowReading(percent: 24, resetsAt: liveWindow),
        sevenDay: WindowReading(percent: 41, resetsAt: liveWindow),
        updatedAt: noon.addingTimeInterval(TimeInterval(-GaugeState.staleAfter - 1))
    )
    let empty = GaugeState(fiveHour: .unknown, sevenDay: .unknown, updatedAt: noon)

    let merged = empty.merged(over: ancient, now: noon)

    #expect(merged.fiveHour.isEmpty)
    #expect(merged.sevenDay.isEmpty)
}

// MARK: - Storage

@Test func stateSurvivesEncodeDecode() throws {
    let original = GaugeState(
        fiveHour: WindowReading(percent: 23.5, resetsAt: liveWindow),
        sevenDay: WindowReading(percent: 41.2, resetsAt: liveWindow),
        updatedAt: noon
    )

    #expect(try GaugeStore.decode(try GaugeStore.encode(original)) == original)
}

@Test func timestampSurvivesJSONExactly() throws {
    // A floating-point timestamp round-tripped differently on different
    // Foundation versions: green locally, red on CI. Whole seconds cannot.
    let state = GaugeState(
        fiveHour: .unknown,
        sevenDay: .unknown,
        updatedAt: Date(timeIntervalSince1970: 1_785_228_593.227181)
    )

    #expect(state.updatedAt == 1_785_228_593)
    #expect(try GaugeStore.decode(try GaugeStore.encode(state)).updatedAt == state.updatedAt)
}

@Test func stalenessFollowsTheClock() {
    let fresh = GaugeState(fiveHour: .unknown, sevenDay: .unknown, updatedAt: noon)

    #expect(!fresh.isStale(now: noon.addingTimeInterval(TimeInterval(GaugeState.staleAfter - 1))))
    #expect(fresh.isStale(now: noon.addingTimeInterval(TimeInterval(GaugeState.staleAfter + 1))))
}

// MARK: - Labels

@Test func rowsFitTheSlot() {
    let rows = Label.rows(fiveHour: 23.5, sevenDay: 41.2)

    #expect(rows.top == "5h 24%")
    #expect(rows.bottom == "7d 41%")
}

@Test func worstCaseRowStillFits() {
    let rows = Label.rows(fiveHour: 100, sevenDay: 100)

    // Seven characters is the measured budget for the 55.5 pt slot at 10 pt.
    #expect(rows.top == "5h 100%")
    #expect(rows.bottom == "7d 100%")
}

@Test func missingWindowRendersPlaceholder() {
    let rows = Label.rows(fiveHour: nil, sevenDay: 41)

    #expect(rows.top == "5h —")
    #expect(rows.bottom == "7d 41%")
}

@Test func statuslineDropsContextWhenAbsent() {
    #expect(Label.statusline(fiveHour: 24, sevenDay: 41, context: 12) == "5h 24% · 7d 41% · ctx 12%")
    #expect(Label.statusline(fiveHour: 24, sevenDay: 41, context: nil) == "5h 24% · 7d 41%")
}

@Test(arguments: [
    (0.0, Severity.normal),
    (59.9, Severity.normal),
    (60.0, Severity.warning),
    (84.9, Severity.warning),
    (85.0, Severity.alert),
    (100.0, Severity.alert),
])
func severityThresholds(percent: Double, expected: Severity) {
    #expect(Severity.of(percent) == expected)
}

@Test func severityIsDrivenByTheWorseWindow() {
    let state = GaugeState(
        fiveHour: WindowReading(percent: 10, resetsAt: liveWindow),
        sevenDay: WindowReading(percent: 92, resetsAt: liveWindow),
        updatedAt: noon
    )

    #expect(Severity.of(state.worstPercent(now: noon)) == .alert)
}
