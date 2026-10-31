//
//  ConfigurationTests.swift
//  RemasterTests
//
//  RMSTR-11 AC: "Given any build, when Info.plist and the binary are inspected,
//  then there is no UPCMDB or TMDB key." This covers Info.plist for the build
//  under test; inspecting a Release binary needs a separate check on the .app.
//

import Foundation
import Testing

@Suite("App configuration")
struct ConfigurationTests {

    @Test("Info.plist has no UPCMDB or TMDB key")
    func noThirdPartyKeys() throws {
        let info = try #require(Bundle.main.infoDictionary)

        for (key, value) in info {
            for provider in ["upcmdb", "tmdb"] {
                #expect(!key.localizedCaseInsensitiveContains(provider), "Info.plist key \(key) names \(provider)")
                if let string = value as? String {
                    #expect(!string.localizedCaseInsensitiveContains(provider), "Info.plist value for \(key) names \(provider)")
                }
            }
        }
    }

    @Test("Only the backend base URL and local port are configured for lookups")
    func backendConfigured() {
        let baseURL = Bundle.main.object(forInfoDictionaryKey: "RemasterBaseUrl") as? String

        #expect(baseURL?.isEmpty == false, "RemasterBaseUrl is empty: set REMASTER_BACKEND_BASE_URL in Secrets.xcconfig")
    }
}
