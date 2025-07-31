import Foundation

public enum PersistenceService {
    private static let key = "userProfile"

    public static func save(_ profile: UserProfile) {
        let data = try? JSONEncoder().encode(profile)
        UserDefaults.standard.set(data, forKey: key)
    }

    public static func loadProfile() -> UserProfile? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(UserProfile.self, from: data)
    }
}
