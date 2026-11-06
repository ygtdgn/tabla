import Testing
@testable import UtilCore

@Suite struct DurationMillisecondsTests {
    @Test func convertsSecondsAndFractions() {
        #expect(Duration.milliseconds(250).inMilliseconds == 250)
        #expect(Duration.seconds(2).inMilliseconds == 2000)
        #expect(Duration.microseconds(1500).inMilliseconds == 1.5)
        #expect(Duration.zero.inMilliseconds == 0)
    }
}
