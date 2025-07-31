import XCTest
@testable import LifeCore

final class PersistenceServiceTests: XCTestCase {
    func testSaveAndLoadProfile_roundTrip() {
        // given
        let profile = UserProfile(
            birthDate: Date(timeIntervalSince1970: 1_700_000_000),
            gender: .female,
            answers: ["likesCats": AnyCodable(true)]
        )
        
        // when
        PersistenceService.save(profile)
        let loaded = PersistenceService.loadProfile()
        
        // then
        XCTAssertEqual(loaded?.birthDate, profile.birthDate)
        XCTAssertEqual(loaded?.gender, profile.gender)
        
        // clean up
        UserDefaults.standard.removeObject(forKey: "userProfile")
    }
}
