import XCTest
@testable import LifeCore

@available(iOS 15.0, *)
final class LifeExpectancyCalculatorTests: XCTestCase {
    func testCalculate_BaseProfile_ReturnsExpectedValue() {
        // given a fixed birth date
        let calendar = Calendar.iso8601
        let birthDate = calendar.date(from: DateComponents(year: 1990, month: 1, day: 1))!
        let profile = UserProfile(birthDate: birthDate, gender: .other)
        let calculator = LifeExpectancyCalculator()

        // when
        let result = calculator.calculate(for: profile)

        // then - expect 80 minus current age
        let age = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
        let expected = max(80.0 - Double(age), 0)
        XCTAssertEqual(result, expected, accuracy: 0.001)
    }
}
