// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import XCTest
@testable import OSXCleanerKit

/// Security-focused tests for `JWTProvider` after migration to swift-crypto.
///
/// Validates the two properties that the hand-rolled implementation could not
/// guarantee on its own:
///   - Algorithm confirmation (`alg: HS256` only, `alg: none` and other
///     algorithms rejected at header parse time).
///   - Constant-time signature comparison via `HMAC.isValidAuthenticationCode`.
final class JWTProviderSecurityTests: XCTestCase {

    private let secret = "test-secret-key-for-jwt-signing-32chars"
    private let issuer = "test-issuer"

    private func makeProvider(audience: String? = nil) -> JWTProvider {
        let config = JWTProviderConfig(
            secret: secret,
            issuer: issuer,
            audience: audience,
            accessTokenDuration: 3600,
            refreshTokenDuration: 86400
        )
        return JWTProvider(configuration: config)
    }

    private func makeUser(role: Role = .operator) -> User {
        User(username: "tester", email: "tester@example.com", role: role)
    }

    // MARK: - Round-trip

    func testSignAndVerify_RoundTripsPayload() async throws {
        let provider = makeProvider()
        let user = makeUser(role: .admin)

        let token = try await provider.generateToken(for: user, tokenType: .access)
        let claims = try await provider.validate(token: token)

        XCTAssertEqual(claims.sub, user.id.uuidString)
        XCTAssertEqual(claims.username, user.username)
        XCTAssertEqual(claims.role, .admin)
        XCTAssertEqual(claims.tokenType, .access)
        XCTAssertEqual(claims.iss, issuer)
    }

    // MARK: - Expiration

    func testExpiredToken_Rejected() async throws {
        let provider = makeProvider()
        let user = makeUser()

        // Negative expiresIn pushes exp into the past.
        let token = try await provider.generateToken(
            for: user,
            tokenType: .access,
            expiresIn: -60
        )

        await XCTAssertThrowsErrorAsync(try await provider.validate(token: token)) { error in
            XCTAssertEqual(error as? JWTError, .tokenExpired)
        }
    }

    // MARK: - Signature tampering

    func testTamperedSignature_Rejected() async throws {
        let provider = makeProvider()
        let user = makeUser()
        let token = try await provider.generateToken(for: user, tokenType: .access)

        let parts = token.split(separator: ".").map(String.init)
        XCTAssertEqual(parts.count, 3)
        // Flip the signature to a different (but well-formed base64URL) value.
        let tampered = "\(parts[0]).\(parts[1]).AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"

        await XCTAssertThrowsErrorAsync(try await provider.validate(token: tampered)) { error in
            XCTAssertEqual(error as? JWTError, .invalidSignature)
        }
    }

    func testTamperedPayload_Rejected() async throws {
        let provider = makeProvider()
        let user = makeUser(role: .viewer)
        let token = try await provider.generateToken(for: user, tokenType: .access)

        // Swap the claims segment with a forged one carrying escalated role.
        // The signature no longer matches the new payload, so HMAC verification
        // must fail regardless of the payload contents.
        let forgedClaimsJSON = #"{"iss":"test-issuer","sub":"00000000-0000-0000-0000-000000000000","aud":null,"exp":\#(Int(Date().timeIntervalSince1970) + 3600),"iat":\#(Int(Date().timeIntervalSince1970)),"nbf":null,"jti":"forged","role":"admin","username":"attacker","email":null,"tokenType":"access"}"#
        let forgedClaimsBase64 = base64URLEncode(Data(forgedClaimsJSON.utf8))
        let parts = token.split(separator: ".").map(String.init)
        let tampered = "\(parts[0]).\(forgedClaimsBase64).\(parts[2])"

        await XCTAssertThrowsErrorAsync(try await provider.validate(token: tampered)) { error in
            XCTAssertEqual(error as? JWTError, .invalidSignature)
        }
    }

    // MARK: - Algorithm confusion

    func testAlgNone_Rejected() async throws {
        let provider = makeProvider()
        // Construct an unsigned token with alg:none — the classic
        // algorithm-confusion attack.
        let header = #"{"alg":"none","typ":"JWT"}"#
        let claims = """
        {"iss":"\(issuer)","sub":"\(UUID().uuidString)","aud":null,\
        "exp":\(Int(Date().timeIntervalSince1970) + 3600),\
        "iat":\(Int(Date().timeIntervalSince1970)),\
        "nbf":null,"jti":"\(UUID().uuidString)","role":"admin",\
        "username":"attacker","email":null,"tokenType":"access"}
        """
        let token = "\(base64URLEncode(Data(header.utf8))).\(base64URLEncode(Data(claims.utf8)))."

        await XCTAssertThrowsErrorAsync(try await provider.validate(token: token)) { error in
            guard case .unsupportedAlgorithm(let alg) = error as? JWTError else {
                XCTFail("Expected .unsupportedAlgorithm, got \(error)")
                return
            }
            XCTAssertEqual(alg, "none")
        }
    }

    func testUnsupportedAlgorithm_Rejected() async throws {
        let provider = makeProvider()
        // Declared HS384 while the actual signature is still HS256; the header
        // check must fail before any signature verification is attempted.
        let header = #"{"alg":"HS384","typ":"JWT"}"#
        let claims = #"{"iss":"\#(issuer)","sub":"x","aud":null,"exp":9999999999,"iat":0,"nbf":null,"jti":"x","role":"admin","username":"x","email":null,"tokenType":"access"}"#
        let token = "\(base64URLEncode(Data(header.utf8))).\(base64URLEncode(Data(claims.utf8))).ignored"

        await XCTAssertThrowsErrorAsync(try await provider.validate(token: token)) { error in
            guard case .unsupportedAlgorithm = error as? JWTError else {
                XCTFail("Expected .unsupportedAlgorithm, got \(error)")
                return
            }
        }
    }

    // MARK: - Malformed tokens

    func testMalformedToken_Rejected() async throws {
        let provider = makeProvider()

        for malformed in ["", "only.two", "a.b.c.d", "not-a-jwt"] {
            await XCTAssertThrowsErrorAsync(try await provider.validate(token: malformed))
        }
    }

    // MARK: - Revocation

    func testRevokedToken_Rejected() async throws {
        let provider = makeProvider()
        let user = makeUser()
        let token = try await provider.generateToken(for: user, tokenType: .refresh)

        let claims = try await provider.validate(token: token)
        await provider.revoke(tokenId: claims.jti)

        await XCTAssertThrowsErrorAsync(try await provider.validate(token: token)) { error in
            XCTAssertEqual(error as? JWTError, .invalidToken)
        }
    }

    // MARK: - Helpers

    private func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Async throwing assertion helper

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line,
    _ errorHandler: (_ error: Error) -> Void = { _ in }
) async {
    do {
        _ = try await expression()
        XCTFail(message().isEmpty ? "Expected error, got success" : message(), file: file, line: line)
    } catch {
        errorHandler(error)
    }
}
