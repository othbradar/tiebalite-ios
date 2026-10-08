import CoreTelephony
import Foundation
import GeneratedProtobuf
import Testing
@testable import TiebaLite

@MainActor
struct U08NativeRuntimeContextTests {
    @Test func replyIncludesEventDayAndRecomputesItForTheNextExplicitRequest() throws {
        var day = "20261008"
        let runtime = NativeWriteAppRuntime(systemUserAgent: "Fixture WebKit", readEventDay: { day })
        var parameters = NativeWriteCommonParameters()
        var metrics = runtime.requestMetrics
        let business = ["tid": "101", "content": "fixture"]
        for expected in ["20261008", "20261009"] {
            day = expected
            let context = try runtime.context(for: .reply, authorization: .init(bduss: "fx", stoken: "fy"), account: nil)
            let fields = parameters.prepare(context.common, business: business, metrics: &metrics)
            #expect(fields["event_day"] == expected)
            let data = try NativeWriteRequestEncoder.encode(kind: .threadReply, business: business, common: fields)
            let request = try TiebaNativeWrite_PostRequest(serializedBytes: data)
            #expect(request.data.common.eventDay == expected)
        }
    }

    @Test func eventDayPreservesNativeWeekYearAndUsesTheLocalDay() throws {
        let date = try #require(ISO8601DateFormatter().date(from: "2019-12-30T17:00:00Z"))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        #expect(NativeWriteEventDay.value(at: date, using: formatter) == "20201230")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        #expect(NativeWriteEventDay.value(at: date, using: formatter) == "20201231")
        // The provider must not replace the selected locale/calendar/time zone.
        formatter.locale = Locale(identifier: "en_GB")
        let january = try #require(ISO8601DateFormatter().date(from: "2021-01-01T12:00:00Z"))
        #expect(NativeWriteEventDay.value(at: january, using: formatter) == "20200101")
    }

    @Test func accountAndTBSPreparationReceiveTheSameDateProvider() throws {
        let runtime = NativeWriteAppRuntime(systemUserAgent: "Fixture WebKit", readEventDay: { "20261008" })
        let authorization = SessionAuthorization(bduss: "fx", stoken: "fy")
        var parameters = NativeWriteCommonParameters()
        var metrics = runtime.requestMetrics
        let account = try runtime.context(for: .account, authorization: authorization, account: nil)
        let loginForm = try parameters.prepareAccount(account.common, authorization: authorization,
                                                      firstLogin: false, metrics: &metrics)
        let tbs = try runtime.context(for: .tbs, authorization: authorization, account: nil)
        let tbsForm = try parameters.prepareTBS(tbs.common, authorization: authorization, metrics: &metrics)
        #expect(loginForm["event_day"] == "20261008")
        #expect(tbsForm["event_day"] == "20261008")
    }

    @Test func languageAndClientLogSequenceMatchNativeRules() {
        #expect(NativeWriteLanguageHeader.value(["zh-Hans-CN", "en-US", "ja", "fr", "de", "es", "ko"])
                == "zh-Hans-CN;q=1, en-US;q=0.9, ja;q=0.8, fr;q=0.7, de;q=0.6, es;q=0.5")
        #expect(NativeWriteLanguageHeader.value([]).isEmpty)
        var sequence = NativeWriteClientLogID()
        #expect(sequence.next(timestamp: 1_000.999) == 1_000_001)
        #expect(sequence.next(timestamp: 2_000) == 1_000_002)
    }

    @Test func radioMappingUsesTheActiveInterface() {
        #expect(NativeWriteNetworkEnvironment.radioType(CTRadioAccessTechnologyNR) == "5")
        #expect(NativeWriteNetworkEnvironment.radioType(CTRadioAccessTechnologyLTE) == "4")
        #expect(NativeWriteNetworkEnvironment.radioType(CTRadioAccessTechnologyWCDMA) == "3")
        #expect(NativeWriteNetworkEnvironment.radioType(CTRadioAccessTechnologyEdge) == "2")
        #expect(NativeWriteNetworkEnvironment.radioType(nil) == "0")
    }

    @Test func networkSnapshotRefreshesBeforeEachSendWithoutInventingSDKValues() async throws {
        var network = "1"
        let runtime = NativeWriteAppRuntime(systemUserAgent: "Fixture WebKit", readNetworkType: { network })
        try await runtime.prepare()
        let wifi = try runtime.context(for: .reply, authorization: .init(bduss: "fx", stoken: "fy"), account: nil)
        #expect(wifi.common.dynamicValues.networkType == "1" && wifi.http.timeout == 10)
        network = "4"
        try await runtime.prepare()
        let cellular = try runtime.context(for: .reply, authorization: .init(bduss: "fx", stoken: "fy"), account: nil)
        #expect(cellular.common.dynamicValues.networkType == "4" && cellular.http.timeout == 25)
        #expect(cellular.http.clientLogID == wifi.http.clientLogID + 1)
        #expect(cellular.common.staticValues.cuid == nil && cellular.common.dynamicValues.opaqueSDKValue == nil)
    }
}
