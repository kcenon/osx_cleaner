import Foundation
import XCTest
@testable import OSXCleanerKit

final class TokenStoreTests: XCTestCase {
    func testKeychainTokenStoreSavesLoadsAndDeletesToken() throws {
        let keychain = InMemoryKeychainService()
        let store = KeychainTokenStore(keychain: keychain, service: "test.service")
        let agentId = UUID()

        try store.saveToken("secret-token", serverURL: "https://mgmt.example.com", agentId: agentId)

        XCTAssertEqual(
            try store.loadToken(serverURL: "https://mgmt.example.com", agentId: agentId),
            "secret-token"
        )
        XCTAssertNil(try store.loadToken(serverURL: "https://other.example.com", agentId: agentId))

        try store.deleteToken(serverURL: "https://mgmt.example.com", agentId: agentId)
        XCTAssertNil(try store.loadToken(serverURL: "https://mgmt.example.com", agentId: agentId))
    }

    func testKeychainTokenStoreRejectsEmptyToken() {
        let store = KeychainTokenStore(keychain: InMemoryKeychainService(), service: "test.service")

        XCTAssertThrowsError(
            try store.saveToken("", serverURL: "https://mgmt.example.com", agentId: UUID())
        ) { error in
            XCTAssertEqual(error as? TokenStoreError, .emptyToken)
        }
    }

    func testKeychainTokenStorePropagatesKeychainFailure() {
        let keychain = InMemoryKeychainService()
        keychain.saveError = TestTokenStoreError.keychainUnavailable
        let store = KeychainTokenStore(keychain: keychain, service: "test.service")

        XCTAssertThrowsError(
            try store.saveToken("secret-token", serverURL: "https://mgmt.example.com", agentId: UUID())
        ) { error in
            XCTAssertEqual(error as? TestTokenStoreError, .keychainUnavailable)
        }
    }

    func testAppConfigurationEncodingOmitsAuthToken() throws {
        let config = AppConfiguration(
            defaultSafetyLevel: 2,
            autoBackup: true,
            logLevel: "info",
            excludedPaths: [],
            showPerformanceWarnings: true,
            serverURL: "https://mgmt.example.com",
            agentId: UUID(),
            authToken: "secret-token"
        )

        let data = try JSONEncoder().encode(config)
        let json = String(data: data, encoding: .utf8) ?? ""

        XCTAssertFalse(json.contains("authToken"))
        XCTAssertFalse(json.contains("secret-token"))
    }

    func testAppConfigurationDecodesLegacyAuthTokenForMigration() throws {
        let agentId = UUID()
        let data = legacyConfigurationJSON(agentId: agentId, authToken: "legacy-token")

        let decoded = try JSONDecoder().decode(AppConfiguration.self, from: data)

        XCTAssertEqual(decoded.agentId, agentId)
        XCTAssertEqual(decoded.authToken, "legacy-token")
    }

    func testConfigurationServiceSaveMovesAuthTokenOutOfJSON() throws {
        let configURL = try makeTemporaryConfigURL()
        let tokenStore = InMemoryTokenStore()
        let service = ConfigurationService(configURL: configURL, tokenStore: tokenStore)
        let agentId = UUID()
        let config = AppConfiguration(
            defaultSafetyLevel: 2,
            autoBackup: true,
            logLevel: "info",
            excludedPaths: [],
            showPerformanceWarnings: true,
            serverURL: "https://mgmt.example.com",
            serverTimeout: 30,
            agentId: agentId,
            authToken: "secret-token"
        )

        try service.save(config)

        let json = try String(contentsOf: configURL, encoding: .utf8)
        XCTAssertFalse(json.contains("authToken"))
        XCTAssertFalse(json.contains("secret-token"))
        XCTAssertEqual(
            try tokenStore.loadToken(serverURL: "https://mgmt.example.com", agentId: agentId),
            "secret-token"
        )
    }

    func testConfigurationServiceLoadMigratesLegacyAuthToken() throws {
        let configURL = try makeTemporaryConfigURL()
        let tokenStore = InMemoryTokenStore()
        let service = ConfigurationService(configURL: configURL, tokenStore: tokenStore)
        let agentId = UUID()
        try legacyConfigurationJSON(agentId: agentId, authToken: "legacy-token").write(to: configURL)

        let loaded = try service.load()

        XCTAssertNil(loaded.authToken)
        XCTAssertEqual(
            try tokenStore.loadToken(serverURL: "https://mgmt.example.com", agentId: agentId),
            "legacy-token"
        )

        let migratedJSON = try String(contentsOf: configURL, encoding: .utf8)
        XCTAssertFalse(migratedJSON.contains("authToken"))
        XCTAssertFalse(migratedJSON.contains("legacy-token"))
    }

    func testConfigurationServiceLeavesLegacyConfigUntouchedWhenMigrationFails() throws {
        let configURL = try makeTemporaryConfigURL()
        let tokenStore = InMemoryTokenStore()
        tokenStore.saveError = TestTokenStoreError.keychainUnavailable
        let service = ConfigurationService(configURL: configURL, tokenStore: tokenStore)
        let agentId = UUID()
        try legacyConfigurationJSON(agentId: agentId, authToken: "legacy-token").write(to: configURL)

        XCTAssertThrowsError(try service.load())

        let originalJSON = try String(contentsOf: configURL, encoding: .utf8)
        XCTAssertTrue(originalJSON.contains("authToken"))
        XCTAssertTrue(originalJSON.contains("legacy-token"))
    }

    private func makeTemporaryConfigURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return directory.appendingPathComponent("config.json")
    }

    private func legacyConfigurationJSON(agentId: UUID, authToken: String) -> Data {
        Data(
            """
            {
              "defaultSafetyLevel": 2,
              "autoBackup": true,
              "logLevel": "info",
              "excludedPaths": [],
              "showPerformanceWarnings": true,
              "serverURL": "https://mgmt.example.com",
              "serverTimeout": 30,
              "agentId": "\(agentId.uuidString)",
              "authToken": "\(authToken)"
            }
            """.utf8
        )
    }
}

private enum TestTokenStoreError: Error, Equatable {
    case keychainUnavailable
}

private final class InMemoryKeychainService: KeychainServicing {
    var saveError: Error?

    private var storage: [String: Data] = [:]

    func data(service: String, account: String) throws -> Data? {
        storage[key(service: service, account: account)]
    }

    func save(_ data: Data, service: String, account: String) throws {
        if let saveError {
            throw saveError
        }
        storage[key(service: service, account: account)] = data
    }

    func delete(service: String, account: String) throws {
        storage.removeValue(forKey: key(service: service, account: account))
    }

    private func key(service: String, account: String) -> String {
        "\(service)|\(account)"
    }
}

private final class InMemoryTokenStore: ServerAuthTokenStoring {
    var saveError: Error?

    private var storage: [String: String] = [:]

    func loadToken(serverURL: String, agentId: UUID) throws -> String? {
        storage[key(serverURL: serverURL, agentId: agentId)]
    }

    func saveToken(_ token: String, serverURL: String, agentId: UUID) throws {
        if let saveError {
            throw saveError
        }
        storage[key(serverURL: serverURL, agentId: agentId)] = token
    }

    func deleteToken(serverURL: String, agentId: UUID) throws {
        storage.removeValue(forKey: key(serverURL: serverURL, agentId: agentId))
    }

    private func key(serverURL: String, agentId: UUID) -> String {
        "\(serverURL)|\(agentId.uuidString)"
    }
}
