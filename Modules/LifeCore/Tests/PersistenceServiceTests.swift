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
        XCTAssertEqual(loaded?.gender, profile.gender)

        // Also check answers
        let loadedLikesCats = loaded?.answers["likesCats"]?.value as? Bool
        XCTAssertEqual(loadedLikesCats, true)
        
        // clean up
        UserDefaults.standard.removeObject(forKey: "userProfile")
    }
}
