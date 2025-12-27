// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation
import Logging

// MARK: - JWT Errors

/// Errors that can occur during JWT operations
public enum JWTError: LocalizedError, Equatable {
    case invalidToken
    case tokenExpired
    case invalidSignature
    case missingClaim(String)
    case invalidClaim(String)
    case encodingFailed
    case decodingFailed

    public var errorDescription: String? {
        switch self {
        case .invalidToken:
            return "Invalid JWT token format"
        case .tokenExpired:
            return "JWT token has expired"
        case .invalidSignature:
            return "JWT signature verification failed"
        case .missingClaim(let claim):
            return "Missing required claim: \(claim)"
        case .invalidClaim(let claim):
            return "Invalid claim value: \(claim)"
        case .encodingFailed:
            return "Failed to encode JWT"
        case .decodingFailed:
            return "Failed to decode JWT"
        }
    }

    public static func == (lhs: JWTError, rhs: JWTError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidToken, .invalidToken),
             (.tokenExpired, .tokenExpired),
             (.invalidSignature, .invalidSignature),
             (.encodingFailed, .encodingFailed),
             (.decodingFailed, .decodingFailed):
            return true
        case (.missingClaim(let l), .missingClaim(let r)),
             (.invalidClaim(let l), .invalidClaim(let r)):
            return l == r
        default:
            return false
        }
    }
}

// MARK: - JWT Header

/// JWT header structure
public struct JWTHeader: Codable, Sendable {
    /// Algorithm used for signing
    public let alg: String

    /// Token type
    public let typ: String

    public init(alg: String = "HS256", typ: String = "JWT") {
        self.alg = alg
        self.typ = typ
    }
}

// MARK: - JWT Claims

/// Standard JWT claims with custom extensions for RBAC
public struct JWTClaims: Codable, Sendable {

    // MARK: - Standard Claims

    /// Issuer
    public let iss: String

    /// Subject (user ID)
    public let sub: String

    /// Audience
    public let aud: String?

    /// Expiration time (Unix timestamp)
    public let exp: Int

    /// Issued at (Unix timestamp)
    public let iat: Int

    /// Not before (Unix timestamp)
    public let nbf: Int?

    /// JWT ID
    public let jti: String

    // MARK: - Custom Claims

    /// User's role
    public let role: Role

    /// Username
    public let username: String

    /// User's email
    public let email: String?

    /// Token type (access or refresh)
    public let tokenType: TokenType

    // MARK: - Initialization

    public init(
        iss: String,
        sub: String,
        aud: String? = nil,
        exp: Int,
        iat: Int = Int(Date().timeIntervalSince1970),
        nbf: Int? = nil,
        jti: String = UUID().uuidString,
        role: Role,
        username: String,
        email: String? = nil,
        tokenType: TokenType = .access
    ) {
        self.iss = iss
        self.sub = sub
        self.aud = aud
        self.exp = exp
        self.iat = iat
        self.nbf = nbf
        self.jti = jti
        self.role = role
        self.username = username
        self.email = email
        self.tokenType = tokenType
    }

    // MARK: - Computed Properties

    /// Whether the token is expired
    public var isExpired: Bool {
        Int(Date().timeIntervalSince1970) > exp
    }

    /// Whether the token is valid (not expired and nbf satisfied)
    public var isValid: Bool {
        let now = Int(Date().timeIntervalSince1970)
        if now > exp { return false }
        if let nbf = nbf, now < nbf { return false }
        return true
    }

    /// Expiration date
    public var expirationDate: Date {
        Date(timeIntervalSince1970: TimeInterval(exp))
    }

    /// Issue date
    public var issueDate: Date {
        Date(timeIntervalSince1970: TimeInterval(iat))
    }
}

// MARK: - Token Type

/// Type of JWT token
public enum TokenType: String, Codable, Sendable {
    /// Short-lived access token
    case access

    /// Long-lived refresh token
    case refresh
}

// MARK: - Token Pair

/// A pair of access and refresh tokens
public struct TokenPair: Codable, Sendable {
    /// Access token for API authentication
    public let accessToken: String

    /// Refresh token for obtaining new access tokens
    public let refreshToken: String

    /// Access token expiration time
    public let accessTokenExpiresAt: Date

    /// Refresh token expiration time
    public let refreshTokenExpiresAt: Date

    public init(
        accessToken: String,
        refreshToken: String,
        accessTokenExpiresAt: Date,
        refreshTokenExpiresAt: Date
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.accessTokenExpiresAt = accessTokenExpiresAt
        self.refreshTokenExpiresAt = refreshTokenExpiresAt
    }
}

// MARK: - JWT Provider Configuration

/// Configuration for the JWT provider
public struct JWTProviderConfig: Sendable {
    /// Secret key for signing tokens
    public let secret: String

    /// Token issuer
    public let issuer: String

    /// Token audience
    public let audience: String?

    /// Access token validity duration in seconds
    public let accessTokenDuration: TimeInterval

    /// Refresh token validity duration in seconds
    public let refreshTokenDuration: TimeInterval

    public init(
        secret: String,
        issuer: String = "osx-cleaner-server",
        audience: String? = nil,
        accessTokenDuration: TimeInterval = 3600,        // 1 hour
        refreshTokenDuration: TimeInterval = 604800      // 7 days
    ) {
        self.secret = secret
        self.issuer = issuer
        self.audience = audience
        self.accessTokenDuration = accessTokenDuration
        self.refreshTokenDuration = refreshTokenDuration
    }
}

// MARK: - JWT Provider

/// Actor responsible for JWT token generation and validation
public actor JWTProvider {

    // MARK: - Properties

    private let configuration: JWTProviderConfig
    private let logger: Logger

    /// Revoked token IDs (jti)
    private var revokedTokens: Set<String> = []

    /// Maximum revoked tokens to store (for memory management)
    private let maxRevokedTokens: Int = 10000

    // MARK: - Initialization

    public init(configuration: JWTProviderConfig) {
        self.configuration = configuration
        self.logger = Logger(label: "com.osxcleaner.jwt-provider")
    }

    // MARK: - Token Generation

    /// Generate a token pair for a user
    public func generateTokenPair(for user: User) throws -> TokenPair {
        let now = Date()

        let accessToken = try generateToken(
            for: user,
            tokenType: .access,
            expiresIn: configuration.accessTokenDuration
        )

        let refreshToken = try generateToken(
            for: user,
            tokenType: .refresh,
            expiresIn: configuration.refreshTokenDuration
        )

        logger.info("Generated token pair", metadata: [
            "userId": "\(user.id)",
            "username": "\(user.username)",
            "role": "\(user.role.rawValue)"
        ])

        return TokenPair(
            accessToken: accessToken,
            refreshToken: refreshToken,
            accessTokenExpiresAt: now.addingTimeInterval(configuration.accessTokenDuration),
            refreshTokenExpiresAt: now.addingTimeInterval(configuration.refreshTokenDuration)
        )
    }

    /// Generate a single token
    public func generateToken(
        for user: User,
        tokenType: TokenType,
        expiresIn: TimeInterval? = nil
    ) throws -> String {
        let now = Int(Date().timeIntervalSince1970)
        let duration = expiresIn ?? (tokenType == .access
            ? configuration.accessTokenDuration
            : configuration.refreshTokenDuration)

        let claims = JWTClaims(
            iss: configuration.issuer,
            sub: user.id.uuidString,
            aud: configuration.audience,
            exp: now + Int(duration),
            iat: now,
            nbf: now,
            role: user.role,
            username: user.username,
            email: user.email,
            tokenType: tokenType
        )

        return try encode(claims: claims)
    }

    // MARK: - Token Validation

    /// Validate a token and return its claims
    public func validate(token: String) throws -> JWTClaims {
        let claims = try decode(token: token)

        // Check if token is revoked
        if revokedTokens.contains(claims.jti) {
            logger.warning("Attempted to use revoked token", metadata: [
                "jti": "\(claims.jti)"
            ])
            throw JWTError.invalidToken
        }

        // Check expiration
        if claims.isExpired {
            logger.debug("Token expired", metadata: [
                "jti": "\(claims.jti)",
                "exp": "\(claims.exp)"
            ])
            throw JWTError.tokenExpired
        }

        // Check not before
        if let nbf = claims.nbf {
            let now = Int(Date().timeIntervalSince1970)
            if now < nbf {
                throw JWTError.invalidToken
            }
        }

        // Check issuer
        if claims.iss != configuration.issuer {
            throw JWTError.invalidClaim("iss")
        }

        // Check audience if configured
        if let expectedAudience = configuration.audience {
            if claims.aud != expectedAudience {
                throw JWTError.invalidClaim("aud")
            }
        }

        return claims
    }

    /// Refresh an access token using a refresh token
    public func refresh(token: String, user: User) throws -> TokenPair {
        let claims = try validate(token: token)

        // Ensure it's a refresh token
        guard claims.tokenType == .refresh else {
            throw JWTError.invalidClaim("tokenType")
        }

        // Revoke the old refresh token
        revoke(tokenId: claims.jti)

        // Generate new token pair
        return try generateTokenPair(for: user)
    }

    // MARK: - Token Revocation

    /// Revoke a token by its ID
    public func revoke(tokenId: String) {
        revokedTokens.insert(tokenId)

        // Memory management: remove oldest if over limit
        if revokedTokens.count > maxRevokedTokens {
            // In production, would use a proper LRU cache
            revokedTokens.removeFirst()
        }

        logger.debug("Token revoked", metadata: ["jti": "\(tokenId)"])
    }

    /// Revoke a token by extracting its ID
    public func revoke(token: String) throws {
        let claims = try decode(token: token)
        revoke(tokenId: claims.jti)
    }

    /// Check if a token ID is revoked
    public func isRevoked(tokenId: String) -> Bool {
        revokedTokens.contains(tokenId)
    }

    /// Clear all revoked tokens (use with caution)
    public func clearRevokedTokens() {
        revokedTokens.removeAll()
        logger.info("Cleared all revoked tokens")
    }

    // MARK: - Token Statistics

    /// Number of revoked tokens currently tracked
    public var revokedTokenCount: Int {
        revokedTokens.count
    }

    // MARK: - Private Methods

    private func encode(claims: JWTClaims) throws -> String {
        let header = JWTHeader()

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970

        guard let headerData = try? encoder.encode(header),
              let claimsData = try? encoder.encode(claims) else {
            throw JWTError.encodingFailed
        }

        let headerBase64 = base64URLEncode(headerData)
        let claimsBase64 = base64URLEncode(claimsData)

        let signatureInput = "\(headerBase64).\(claimsBase64)"
        let signature = sign(signatureInput)

        return "\(signatureInput).\(signature)"
    }

    private func decode(token: String) throws -> JWTClaims {
        let parts = token.split(separator: ".").map(String.init)
        guard parts.count == 3 else {
            throw JWTError.invalidToken
        }

        let headerBase64 = parts[0]
        let claimsBase64 = parts[1]
        let signature = parts[2]

        // Verify signature
        let signatureInput = "\(headerBase64).\(claimsBase64)"
        let expectedSignature = sign(signatureInput)

        guard signature == expectedSignature else {
            throw JWTError.invalidSignature
        }

        // Decode claims
        guard let claimsData = base64URLDecode(claimsBase64) else {
            throw JWTError.decodingFailed
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        do {
            return try decoder.decode(JWTClaims.self, from: claimsData)
        } catch {
            throw JWTError.decodingFailed
        }
    }

    private func sign(_ input: String) -> String {
        guard let inputData = input.data(using: .utf8),
              let keyData = configuration.secret.data(using: .utf8) else {
            return ""
        }

        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))

        // HMAC-SHA256
        keyData.withUnsafeBytes { keyBytes in
            inputData.withUnsafeBytes { inputBytes in
                CCHmac(
                    CCHmacAlgorithm(kCCHmacAlgSHA256),
                    keyBytes.baseAddress,
                    keyData.count,
                    inputBytes.baseAddress,
                    inputData.count,
                    &hash
                )
            }
        }

        return base64URLEncode(Data(hash))
    }

    private func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func base64URLDecode(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if necessary
        let paddingLength = (4 - base64.count % 4) % 4
        base64 += String(repeating: "=", count: paddingLength)

        return Data(base64Encoded: base64)
    }
}

// MARK: - CommonCrypto Bridge

import Darwin

private let CC_SHA256_DIGEST_LENGTH: Int32 = 32

@_silgen_name("CCHmac")
private func CCHmac(
    _ algorithm: CCHmacAlgorithm,
    _ key: UnsafeRawPointer?,
    _ keyLength: Int,
    _ data: UnsafeRawPointer?,
    _ dataLength: Int,
    _ macOut: UnsafeMutableRawPointer?
)

private typealias CCHmacAlgorithm = UInt32
private let kCCHmacAlgSHA256: CCHmacAlgorithm = 2
