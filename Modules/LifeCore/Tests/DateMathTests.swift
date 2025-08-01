import XCTest

final class DateMathTests: XCTestCase {
    func testLeapYearBoundary() {
        let calendar = Calendar.iso8601
        let birth = calendar.date(from: DateComponents(year: 1992, month: 2, day: 29))!
        let target = calendar.date(from: DateComponents(year: 2025, month: 3, day: 1))!
        let age = calendar.dateComponents([.year], from: birth, to: target).year
        XCTAssertEqual(age, 33)
    }
}
