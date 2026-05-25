// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation
import Security

/// Storage for server authentication token material.
public protocol ServerAuthTokenStoring {
    func loadToken(serverURL: String, agentId: UUID) throws -> String?
    func saveToken(_ token: String, serverURL: String, agentId: UUID) throws
    func deleteToken(serverURL: String, agentId: UUID) throws
}

/// Minimal Keychain wrapper protocol used by ``KeychainTokenStore``.
public protocol KeychainServicing {
    func data(service: String, account: String) throws -> Data?
    func save(_ data: Data, service: String, account: String) throws
    func delete(service: String, account: String) throws
}

public enum TokenStoreError: LocalizedError, Equatable {
    case emptyToken
    case invalidTokenData
    case keychainFailure(operation: String, status: OSStatus)

    public var errorDescription: String? {
        switch self {
        case .emptyToken:
            return "Cannot store an empty server auth token"
        case .invalidTokenData:
            return "Stored server auth token is not valid UTF-8"
        case .keychainFailure(let operation, let status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
            return "Could not \(operation) server auth token in Keychain: \(message)"
        }
    }
}

/// Keychain-backed server auth token store.
public final class KeychainTokenStore: ServerAuthTokenStoring {
    public static let defaultService = "com.osxcleaner.server.auth"

    private let keychain: KeychainServicing
    private let service: String

    public init(
        keychain: KeychainServicing = SystemKeychainService(),
        service: String = KeychainTokenStore.defaultService
    ) {
        self.keychain = keychain
        self.service = service
    }

    public func loadToken(serverURL: String, agentId: UUID) throws -> String? {
        let account = accountName(serverURL: serverURL, agentId: agentId)
        guard let data = try keychain.data(service: service, account: account) else {
            return nil
        }

        guard let token = String(data: data, encoding: .utf8) else {
            throw TokenStoreError.invalidTokenData
        }
        return token
    }

    public func saveToken(_ token: String, serverURL: String, agentId: UUID) throws {
        guard !token.isEmpty else {
            throw TokenStoreError.emptyToken
        }

        let account = accountName(serverURL: serverURL, agentId: agentId)
        let data = Data(token.utf8)
        try keychain.save(data, service: service, account: account)
    }

    public func deleteToken(serverURL: String, agentId: UUID) throws {
        let account = accountName(serverURL: serverURL, agentId: agentId)
        try keychain.delete(service: service, account: account)
    }

    private func accountName(serverURL: String, agentId: UUID) -> String {
        "\(serverURL)|\(agentId.uuidString)"
    }
}

/// Production Keychain implementation backed by the Security framework.
public final class SystemKeychainService: KeychainServicing {
    public init() {}

    public func data(service: String, account: String) throws -> Data? {
        var query = baseQuery(service: service, account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            return item as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw TokenStoreError.keychainFailure(operation: "read", status: status)
        }
    }

    public func save(_ data: Data, service: String, account: String) throws {
        let query = baseQuery(service: service, account: account)
        let attributes = [kSecValueData as String: data]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw TokenStoreError.keychainFailure(operation: "save", status: addStatus)
            }
        default:
            throw TokenStoreError.keychainFailure(operation: "save", status: updateStatus)
        }
    }

    public func delete(service: String, account: String) throws {
        let status = SecItemDelete(baseQuery(service: service, account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw TokenStoreError.keychainFailure(operation: "delete", status: status)
        }
    }

    private func baseQuery(service: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
