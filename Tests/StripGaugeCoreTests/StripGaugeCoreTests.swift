import Foundation
import Testing

@testable import StripGaugeCore

// MARK: - Parsing Claude Code's payload

@Test func parsesBothRateLimitWindows() throws {
    let json = """
    {"rate_limits":{"five_hour":{"used_percentage":23.5,"resets_at":1738425600},
     "seven_day":{"used_percentage":41.2,"resets_at":1738857600}},
     "context_window":{"used_percentage":8}}
    """
    let input = try StatuslineInput.decode(Data(json.utf8))

    #expect(input.rateLimits?.fiveHour?.usedPercentage == 23.5)
    #expect(input.rateLimits?.sevenDay?.usedPercentage == 41.2)
    #expect(input.contextPercent == 8)
}

@Test func toleratesAbsentRateLimits() throws {
    // What a session looks like before its first API response, or on a plan
    // that reports no rate limits at all.
    let input = try StatuslineInput.decode(Data(#"{"model":{"display_name":"Opus"}}"#.utf8))
    let state = input.state()

    #expect(state.fiveHourPercent == nil)
    #expect(state.sevenDayPercent == nil)
    #expect(state.worstPercent == nil)
}

@Test func toleratesOneWindowMissing() throws {
    let json = #"{"rate_limits":{"five_hour":{"used_percentage":12}}}"#
    let state = try StatuslineInput.decode(Data(json.utf8)).state()

    #expect(state.fiveHourPercent == 12)
    #expect(state.sevenDayPercent == nil)
    #expect(state.worstPercent == 12)
}

@Test func ignoresUnknownFields() throws {
    // Claude Code keeps adding fields; none of them should break decoding.
    let json = #"{"future_field":{"nested":true},"rate_limits":{"seven_day":{"used_percentage":5}}}"#
    let state = try StatuslineInput.decode(Data(json.utf8)).state()

    #expect(state.sevenDayPercent == 5)
}

// MARK: - State round trip

@Test func stateSurvivesEncodeDecode() throws {
    let original = GaugeState(fiveHourPercent: 23.5, sevenDayPercent: 41.2, updatedAt: Date())
    let restored = try GaugeStore.decode(try GaugeStore.encode(original))

    #expect(restored == original)
}

@Test func stalenessFollowsTheClock() {
    let now = Date(timeIntervalSince1970: 1_000_000)
    let fresh = GaugeState(fiveHourPercent: 1, sevenDayPercent: 1, updatedAt: now)

    #expect(!fresh.isStale(now: now.addingTimeInterval(TimeInterval(GaugeState.staleAfter - 1))))
    #expect(fresh.isStale(now: now.addingTimeInterval(TimeInterval(GaugeState.staleAfter + 1))))
}

@Test func timestampSurvivesJSONExactly() throws {
    // A floating-point timestamp round-tripped differently on different
    // Foundation versions: green locally, red on CI. Whole seconds cannot.
    let state = GaugeState(
        fiveHourPercent: nil,
        sevenDayPercent: nil,
        updatedAt: Date(timeIntervalSince1970: 1_785_228_593.227181)
    )

    #expect(state.updatedAt == 1_785_228_593)
    #expect(try GaugeStore.decode(try GaugeStore.encode(state)).updatedAt == state.updatedAt)
}

// MARK: - Merging across concurrent sessions

@Test func freshSessionWithoutRateLimitsKeepsPublishedNumbers() {
    // A second Claude Code session starts and reports no rate limits yet. It
    // must not blank the gauge for the session that already has numbers.
    let now = Date(timeIntervalSince1970: 1_000_000)
    let published = GaugeState(fiveHourPercent: 24, sevenDayPercent: 41, updatedAt: now)
    let empty = GaugeState(fiveHourPercent: nil, sevenDayPercent: nil, updatedAt: now)

    let merged = empty.merged(over: published, now: now)

    #expect(merged.fiveHourPercent == 24)
    #expect(merged.sevenDayPercent == 41)
    #expect(merged.updatedAt == Int(now.timeIntervalSince1970))
}

@Test func newerNumbersWin() {
    let now = Date(timeIntervalSince1970: 1_000_000)
    let published = GaugeState(fiveHourPercent: 24, sevenDayPercent: 41, updatedAt: now)
    let fresher = GaugeState(fiveHourPercent: 31, sevenDayPercent: nil, updatedAt: now)

    let merged = fresher.merged(over: published, now: now)

    #expect(merged.fiveHourPercent == 31)
    #expect(merged.sevenDayPercent == 41)
}

@Test func staleNumbersAreNotResurrected() {
    let then = Date(timeIntervalSince1970: 1_000_000)
    let ancient = GaugeState(fiveHourPercent: 24, sevenDayPercent: 41, updatedAt: then)
    let now = then.addingTimeInterval(TimeInterval(GaugeState.staleAfter + 1))
    let empty = GaugeState(fiveHourPercent: nil, sevenDayPercent: nil, updatedAt: now)

    let merged = empty.merged(over: ancient, now: now)

    #expect(merged.fiveHourPercent == nil)
    #expect(merged.sevenDayPercent == nil)
}

// MARK: - Labels

@Test func rowsFitTheSlot() {
    let state = GaugeState(fiveHourPercent: 23.5, sevenDayPercent: 41.2, updatedAt: Date())
    let rows = Label.rows(state)

    #expect(rows.top == "5h 24%")
    #expect(rows.bottom == "7d 41%")
    // Six characters is the measured budget for the 55.5 pt slot at 10 pt.
    #expect(rows.top.count <= 7)
    #expect(rows.bottom.count <= 7)
}

@Test func worstCaseRowStillFits() {
    let state = GaugeState(fiveHourPercent: 100, sevenDayPercent: 100, updatedAt: Date())
    let rows = Label.rows(state)

    #expect(rows.top == "5h 100%")
    #expect(rows.bottom == "7d 100%")
}

@Test func missingWindowRendersPlaceholder() {
    let state = GaugeState(fiveHourPercent: nil, sevenDayPercent: 41, updatedAt: Date())
    let rows = Label.rows(state)

    #expect(rows.top == "5h —")
    #expect(rows.bottom == "7d 41%")
}

@Test func statuslineDropsContextWhenAbsent() {
    let state = GaugeState(fiveHourPercent: 24, sevenDayPercent: 41, updatedAt: Date())

    #expect(Label.statusline(state, contextPercent: 12) == "5h 24% · 7d 41% · ctx 12%")
    #expect(Label.statusline(state, contextPercent: nil) == "5h 24% · 7d 41%")
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
    let state = GaugeState(fiveHourPercent: 10, sevenDayPercent: 92, updatedAt: Date())

    #expect(Severity.of(state.worstPercent) == .alert)
}
