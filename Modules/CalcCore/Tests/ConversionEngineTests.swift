@testable import CalcCore
import XCTest

// MARK: - Conversion Engine Tests

@available(iOS 15.0, *)
final class ConversionEngineTests: XCTestCase {
    // MARK: - Test Data

    private let testHourlyWage: Double = 20.0
    private let testPrice: Double = 10.0
    private let expectedMinutes: Double = 30.0 // (10 / 20) * 60 = 30

    // MARK: - Conversion Tests

    func testConvertToWorkTime_ValidInputs_ReturnsCorrectMinutes() {
        // Given
        let price = 15.0
        let hourlyWage = 30.0
        let expectedMinutes = 30.0 // (15 / 30) * 60 = 30

        // When
        let result = ConversionEngine.convertToWorkTime(price: price, hourlyWage: hourlyWage)

        // Then
        XCTAssertEqual(result, expectedMinutes, accuracy: 0.1)
    }

    func testConvertToWorkTime_ZeroWage_ReturnsZero() {
        // Given
        let price = 10.0
        let hourlyWage = 0.0

        // When
        let result = ConversionEngine.convertToWorkTime(price: price, hourlyWage: hourlyWage)

        // Then
        XCTAssertEqual(result, 0.0)
    }

    func testConvertToWorkTime_NegativeWage_ReturnsZero() {
        // Given
        let price = 10.0
        let hourlyWage = -5.0

        // When
        let result = ConversionEngine.convertToWorkTime(price: price, hourlyWage: hourlyWage)

        // Then
        XCTAssertEqual(result, 0.0)
    }

    func testConvertToPrice_ValidInputs_ReturnsCorrectPrice() {
        // Given
        let minutes = 60.0
        let hourlyWage = 25.0
        let expectedPrice = 25.0 // (60 / 60) * 25 = 25

        // When
        let result = ConversionEngine.convertToPrice(minutes: minutes, hourlyWage: hourlyWage)

        // Then
        XCTAssertEqual(result, expectedPrice, accuracy: 0.01)
    }

    // MARK: - Rounding Tests

    func testConvertToWorkTime_LessThanOneHour_RoundsToNearestTenth() {
        // Given
        let price = 5.33
        let hourlyWage = 20.0
        let expectedMinutes = 16.0 // (5.33 / 20) * 60 = 15.99, rounded to 16.0

        // When
        let result = ConversionEngine.convertToWorkTime(price: price, hourlyWage: hourlyWage)

        // Then
        XCTAssertEqual(result, expectedMinutes, accuracy: 0.1)
    }

    func testConvertToWorkTime_MoreThanOneHour_RoundsToNearestMinute() {
        // Given
        let price = 25.5
        let hourlyWage = 20.0
        let expectedMinutes = 77.0 // (25.5 / 20) * 60 = 76.5, rounded to 77

        // When
        let result = ConversionEngine.convertToWorkTime(price: price, hourlyWage: hourlyWage)

        // Then
        XCTAssertEqual(result, expectedMinutes, accuracy: 1.0)
    }

    // MARK: - Formatting Tests

    func testFormatWorkTime_LessThanOneMinute_ShowsDecimal() {
        // Given
        let minutes = 0.5

        // When
        let result = ConversionEngine.formatWorkTime(minutes)

        // Then
        XCTAssertEqual(result, "0.5m")
    }

    func testFormatWorkTime_LessThanOneHour_ShowsMinutes() {
        // Given
        let minutes = 45.0

        // When
        let result = ConversionEngine.formatWorkTime(minutes)

        // Then
        XCTAssertEqual(result, "45m")
    }

    func testFormatWorkTime_ExactlyOneHour_ShowsHours() {
        // Given
        let minutes = 60.0

        // When
        let result = ConversionEngine.formatWorkTime(minutes)

        // Then
        XCTAssertEqual(result, "1h")
    }

    func testFormatWorkTime_HoursAndMinutes_ShowsBoth() {
        // Given
        let minutes = 90.0

        // When
        let result = ConversionEngine.formatWorkTime(minutes)

        // Then
        XCTAssertEqual(result, "1h 30m")
    }

    func testFormatWorkTime_MultipleHours_ShowsCorrectFormat() {
        // Given
        let minutes = 150.0

        // When
        let result = ConversionEngine.formatWorkTime(minutes)

        // Then
        XCTAssertEqual(result, "2h 30m")
    }

    // MARK: - Cat State Tests

    func testCatState_LessThanFiveMinutes_ReturnsPounce() {
        // Given
        let minutes = 3.0

        // When
        let result = ConversionEngine.catState(for: minutes)

        // Then
        XCTAssertEqual(result, .pounce)
    }

    func testCatState_FiveToTwentyNineMinutes_ReturnsRun() {
        // Given
        let minutes = 15.0

        // When
        let result = ConversionEngine.catState(for: minutes)

        // Then
        XCTAssertEqual(result, .run)
    }

    func testCatState_ThirtyToOneHundredNineteenMinutes_ReturnsWalk() {
        // Given
        let minutes = 60.0

        // When
        let result = ConversionEngine.catState(for: minutes)

        // Then
        XCTAssertEqual(result, .walk)
    }

    func testCatState_OneHundredTwentyMinutesOrMore_ReturnsSleep() {
        // Given
        let minutes = 180.0

        // When
        let result = ConversionEngine.catState(for: minutes)

        // Then
        XCTAssertEqual(result, .sleep)
    }

    // MARK: - Edge Cases

    func testConvertToWorkTime_VerySmallPrice_HandlesCorrectly() {
        // Given
        let price = 0.01
        let hourlyWage = 100.0
        let expectedMinutes = 0.0 // (0.01 / 100) * 60 = 0.006, rounded to 0.0

        // When
        let result = ConversionEngine.convertToWorkTime(price: price, hourlyWage: hourlyWage)

        // Then
        XCTAssertEqual(result, expectedMinutes, accuracy: 0.1)
    }

    func testConvertToWorkTime_VeryLargePrice_HandlesCorrectly() {
        // Given
        let price = 10000.0
        let hourlyWage = 10.0
        let expectedMinutes = 60000.0 // (10000 / 10) * 60 = 60000

        // When
        let result = ConversionEngine.convertToWorkTime(price: price, hourlyWage: hourlyWage)

        // Then
        XCTAssertEqual(result, expectedMinutes, accuracy: 1.0)
    }

    func testConvertToWorkTime_VerySmallWage_HandlesCorrectly() {
        // Given
        let price = 1.0
        let hourlyWage = 0.01
        let expectedMinutes = 6000.0 // (1 / 0.01) * 60 = 6000

        // When
        let result = ConversionEngine.convertToWorkTime(price: price, hourlyWage: hourlyWage)

        // Then
        XCTAssertEqual(result, expectedMinutes, accuracy: 1.0)
    }
}

// MARK: - Cat State Tests

@available(iOS 15.0, *)
final class CatStateTests: XCTestCase {
    func testCatStateFrameRates() {
        XCTAssertEqual(CatState.sleep.frameRate, 2.0)
        XCTAssertEqual(CatState.walk.frameRate, 4.0)
        XCTAssertEqual(CatState.run.frameRate, 6.0)
        XCTAssertEqual(CatState.pounce.frameRate, 8.0)
    }

    func testCatStateDescriptions() {
        XCTAssertEqual(CatState.sleep.description, "Cat curled up, eyes shut")
        XCTAssertEqual(CatState.walk.description, "Cat strolling")
        XCTAssertEqual(CatState.run.description, "Cat trotting fast")
        XCTAssertEqual(CatState.pounce.description, "Cat jumping & meowing")
    }

    func testCatStateThresholds() {
        XCTAssertEqual(CatState.sleep.threshold, "≥ 120 min")
        XCTAssertEqual(CatState.walk.threshold, "30 – 119 min")
        XCTAssertEqual(CatState.run.threshold, "5 – 29 min")
        XCTAssertEqual(CatState.pounce.threshold, "< 5 min")
    }

    func testAllCatStates() {
        let allStates = CatState.allCases
        XCTAssertEqual(allStates.count, 4)
        XCTAssertTrue(allStates.contains(.sleep))
        XCTAssertTrue(allStates.contains(.walk))
        XCTAssertTrue(allStates.contains(.run))
        XCTAssertTrue(allStates.contains(.pounce))
    }
}
