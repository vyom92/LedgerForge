// LedgerForge
// DevelopmentDatabaseProfilePreferences.swift

#if DEBUG
import Foundation

protocol DevelopmentDatabaseProfilePreferenceAuthority: AnyObject {
    var rememberedDevelopmentProfile: RememberedDevelopmentDatabaseProfile { get set }
    var rememberedMigrationSourceVersion: Int { get set }
}

final class DevelopmentDatabaseProfilePreferences: DevelopmentDatabaseProfilePreferenceAuthority {
    static let rememberedProfileKey = "developmentDatabase.rememberedProfile"
    static let rememberedMigrationSourceVersionKey = "developmentDatabase.rememberedMigrationSourceVersion"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var rememberedDevelopmentProfile: RememberedDevelopmentDatabaseProfile {
        get {
            guard let rawValue = defaults.string(forKey: Self.rememberedProfileKey),
                  let profile = RememberedDevelopmentDatabaseProfile(rawValue: rawValue) else {
                return .persistentDebug
            }
            return profile
        }
        set {
            defaults.set(newValue.rawValue, forKey: Self.rememberedProfileKey)
        }
    }

    var rememberedMigrationSourceVersion: Int {
        get {
            let value = defaults.integer(forKey: Self.rememberedMigrationSourceVersionKey)
            guard DevelopmentDatabaseProfile.registeredHistoricalSourceVersions.contains(value) else {
                return DevelopmentDatabaseProfile.defaultHistoricalSourceVersion
            }
            return value
        }
        set {
            guard DevelopmentDatabaseProfile.registeredHistoricalSourceVersions.contains(newValue) else {
                defaults.removeObject(forKey: Self.rememberedMigrationSourceVersionKey)
                return
            }
            defaults.set(newValue, forKey: Self.rememberedMigrationSourceVersionKey)
        }
    }
}
#endif
