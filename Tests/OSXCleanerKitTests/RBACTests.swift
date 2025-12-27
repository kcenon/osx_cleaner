import XCTest
@testable import OSXCleanerKit

final class RBACTests: XCTestCase {

    // MARK: - Test Fixtures

    private var jwtProvider: JWTProvider!
    private var accessController: AccessController!

    override func setUp() async throws {
        let jwtConfig = JWTProviderConfig(
            secret: "test-secret-key-for-jwt-signing-32chars",
            issuer: "test-issuer",
            accessTokenDuration: 3600,
            refreshTokenDuration: 86400
        )
        jwtProvider = JWTProvider(configuration: jwtConfig)

        let accessConfig = AccessControllerConfig(
            logAllAccess: true,
            logDeniedAccess: true,
            maxAuditEntries: 1000
        )
        accessController = AccessController(
            configuration: accessConfig,
            jwtProvider: jwtProvider
        )
    }

    // MARK: - Role Tests

    func testRoleHierarchy() {
        XCTAssertEqual(Role.admin.hierarchyLevel, 100)
        XCTAssertEqual(Role.operator.hierarchyLevel, 50)
        XCTAssertEqual(Role.viewer.hierarchyLevel, 10)
    }

    func testRoleHasAtLeastPrivilegesOf() {
        XCTAssertTrue(Role.admin.hasAtLeastPrivilegesOf(.admin))
        XCTAssertTrue(Role.admin.hasAtLeastPrivilegesOf(.operator))
        XCTAssertTrue(Role.admin.hasAtLeastPrivilegesOf(.viewer))

        XCTAssertFalse(Role.operator.hasAtLeastPrivilegesOf(.admin))
        XCTAssertTrue(Role.operator.hasAtLeastPrivilegesOf(.operator))
        XCTAssertTrue(Role.operator.hasAtLeastPrivilegesOf(.viewer))

        XCTAssertFalse(Role.viewer.hasAtLeastPrivilegesOf(.admin))
        XCTAssertFalse(Role.viewer.hasAtLeastPrivilegesOf(.operator))
        XCTAssertTrue(Role.viewer.hasAtLeastPrivilegesOf(.viewer))
    }

    func testRoleDisplayNames() {
        XCTAssertEqual(Role.admin.displayName, "Administrator")
        XCTAssertEqual(Role.operator.displayName, "Operator")
        XCTAssertEqual(Role.viewer.displayName, "Viewer")
    }

    // MARK: - Permission Tests

    func testAdminHasAllPermissions() {
        for permission in Permission.allCases {
            XCTAssertTrue(Role.admin.hasPermission(permission),
                         "Admin should have permission: \(permission.rawValue)")
        }
    }

    func testOperatorPermissions() {
        // Should have
        XCTAssertTrue(Role.operator.hasPermission(.viewAgents))
        XCTAssertTrue(Role.operator.hasPermission(.registerAgents))
        XCTAssertTrue(Role.operator.hasPermission(.viewPolicies))
        XCTAssertTrue(Role.operator.hasPermission(.createPolicies))
        XCTAssertTrue(Role.operator.hasPermission(.deployPolicies))
        XCTAssertTrue(Role.operator.hasPermission(.viewReports))
        XCTAssertTrue(Role.operator.hasPermission(.viewAuditLogs))

        // Should not have
        XCTAssertFalse(Role.operator.hasPermission(.unregisterAgents))
        XCTAssertFalse(Role.operator.hasPermission(.deletePolicies))
        XCTAssertFalse(Role.operator.hasPermission(.viewUsers))
        XCTAssertFalse(Role.operator.hasPermission(.createUsers))
        XCTAssertFalse(Role.operator.hasPermission(.manageRoles))
    }

    func testViewerPermissions() {
        // Should have
        XCTAssertTrue(Role.viewer.hasPermission(.viewAgents))
        XCTAssertTrue(Role.viewer.hasPermission(.viewPolicies))
        XCTAssertTrue(Role.viewer.hasPermission(.viewReports))
        XCTAssertTrue(Role.viewer.hasPermission(.viewAuditLogs))

        // Should not have
        XCTAssertFalse(Role.viewer.hasPermission(.registerAgents))
        XCTAssertFalse(Role.viewer.hasPermission(.createPolicies))
        XCTAssertFalse(Role.viewer.hasPermission(.deployPolicies))
        XCTAssertFalse(Role.viewer.hasPermission(.viewUsers))
    }

    func testPermissionCategories() {
        XCTAssertEqual(Permission.viewAgents.category, .agents)
        XCTAssertEqual(Permission.registerAgents.category, .agents)

        XCTAssertEqual(Permission.viewPolicies.category, .policies)
        XCTAssertEqual(Permission.deployPolicies.category, .policies)

        XCTAssertEqual(Permission.viewReports.category, .reports)
        XCTAssertEqual(Permission.exportReports.category, .reports)

        XCTAssertEqual(Permission.viewAuditLogs.category, .audit)

        XCTAssertEqual(Permission.viewUsers.category, .users)
        XCTAssertEqual(Permission.manageRoles.category, .users)

        XCTAssertEqual(Permission.viewConfig.category, .system)
        XCTAssertEqual(Permission.updateConfig.category, .system)
    }

    // MARK: - User Tests

    func testUserCreation() {
        let user = User(
            username: "testuser",
            email: "test@example.com",
            role: .operator
        )

        XCTAssertEqual(user.username, "testuser")
        XCTAssertEqual(user.email, "test@example.com")
        XCTAssertEqual(user.role, .operator)
        XCTAssertTrue(user.isActive)
        XCTAssertNil(user.lastLoginAt)
    }

    func testUserPermissionChecking() {
        let activeUser = User(
            username: "operator",
            email: "op@example.com",
            role: .operator,
            isActive: true
        )

        XCTAssertTrue(activeUser.hasPermission(.viewAgents))
        XCTAssertFalse(activeUser.hasPermission(.viewUsers))
    }

    func testDisabledUserHasNoPermissions() {
        let disabledUser = User(
            username: "disabled",
            email: "disabled@example.com",
            role: .admin,
            isActive: false
        )

        XCTAssertFalse(disabledUser.hasPermission(.viewAgents))
        XCTAssertFalse(disabledUser.hasPermission(.viewUsers))
    }

    func testUserHasAllPermissions() {
        let admin = User(
            username: "admin",
            email: "admin@example.com",
            role: .admin
        )

        let requiredPermissions: Set<Permission> = [.viewAgents, .registerAgents]
        XCTAssertTrue(admin.hasAllPermissions(requiredPermissions))

        let viewer = User(
            username: "viewer",
            email: "viewer@example.com",
            role: .viewer
        )
        XCTAssertFalse(viewer.hasAllPermissions(requiredPermissions))
    }

    func testUserHasAnyPermission() {
        let viewer = User(
            username: "viewer",
            email: "viewer@example.com",
            role: .viewer
        )

        let permissions: Set<Permission> = [.viewAgents, .registerAgents]
        XCTAssertTrue(viewer.hasAnyPermission(permissions))

        let adminOnlyPermissions: Set<Permission> = [.viewUsers, .createUsers]
        XCTAssertFalse(viewer.hasAnyPermission(adminOnlyPermissions))
    }

    // MARK: - JWT Provider Tests

    func testTokenGeneration() async throws {
        let user = User(
            username: "testuser",
            email: "test@example.com",
            role: .operator
        )

        let tokenPair = try await jwtProvider.generateTokenPair(for: user)

        XCTAssertFalse(tokenPair.accessToken.isEmpty)
        XCTAssertFalse(tokenPair.refreshToken.isEmpty)
        XCTAssertNotEqual(tokenPair.accessToken, tokenPair.refreshToken)
        XCTAssertGreaterThan(tokenPair.accessTokenExpiresAt, Date())
        XCTAssertGreaterThan(tokenPair.refreshTokenExpiresAt, tokenPair.accessTokenExpiresAt)
    }

    func testTokenValidation() async throws {
        let user = User(
            username: "testuser",
            email: "test@example.com",
            role: .operator
        )

        let tokenPair = try await jwtProvider.generateTokenPair(for: user)
        let claims = try await jwtProvider.validate(token: tokenPair.accessToken)

        XCTAssertEqual(claims.sub, user.id.uuidString)
        XCTAssertEqual(claims.username, user.username)
        XCTAssertEqual(claims.role, user.role)
        XCTAssertEqual(claims.tokenType, .access)
        XCTAssertFalse(claims.isExpired)
    }

    func testInvalidTokenRejected() async {
        do {
            _ = try await jwtProvider.validate(token: "invalid.token.here")
            XCTFail("Should have thrown an error")
        } catch let error as JWTError {
            XCTAssertTrue(error == .invalidToken || error == .decodingFailed ||
                         error == .invalidSignature)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testTokenRevocation() async throws {
        let user = User(
            username: "testuser",
            email: "test@example.com",
            role: .operator
        )

        let tokenPair = try await jwtProvider.generateTokenPair(for: user)

        // Validate before revocation
        _ = try await jwtProvider.validate(token: tokenPair.accessToken)

        // Get token ID and revoke
        let claims = try await jwtProvider.validate(token: tokenPair.accessToken)
        await jwtProvider.revoke(tokenId: claims.jti)

        // Validation should now fail
        do {
            _ = try await jwtProvider.validate(token: tokenPair.accessToken)
            XCTFail("Should have thrown an error for revoked token")
        } catch let error as JWTError {
            XCTAssertEqual(error, .invalidToken)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testRefreshToken() async throws {
        let user = User(
            username: "testuser",
            email: "test@example.com",
            role: .operator
        )

        let originalPair = try await jwtProvider.generateTokenPair(for: user)

        // Small delay to ensure different timestamps
        try await Task.sleep(nanoseconds: 100_000_000)

        let newPair = try await jwtProvider.refresh(
            token: originalPair.refreshToken,
            user: user
        )

        XCTAssertNotEqual(newPair.accessToken, originalPair.accessToken)
        XCTAssertNotEqual(newPair.refreshToken, originalPair.refreshToken)
    }

    func testRefreshWithAccessTokenFails() async {
        let user = User(
            username: "testuser",
            email: "test@example.com",
            role: .operator
        )

        do {
            let tokenPair = try await jwtProvider.generateTokenPair(for: user)
            _ = try await jwtProvider.refresh(token: tokenPair.accessToken, user: user)
            XCTFail("Should have thrown an error")
        } catch let error as JWTError {
            XCTAssertEqual(error, .invalidClaim("tokenType"))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Access Controller Tests

    func testAccessGrantedWithValidToken() async throws {
        let user = User(
            username: "operator",
            email: "op@example.com",
            role: .operator
        )

        let tokenPair = try await jwtProvider.generateTokenPair(for: user)

        let request = AccessRequest(
            token: tokenPair.accessToken,
            resource: "/api/v1/agents",
            method: "GET"
        )

        let result = await accessController.validate(request)

        XCTAssertTrue(result.granted)
        XCTAssertEqual(result.userId, user.id)
        XCTAssertEqual(result.username, user.username)
        XCTAssertEqual(result.role, user.role)
    }

    func testAccessDeniedWithoutToken() async throws {
        let request = AccessRequest(
            token: nil,
            resource: "/api/v1/agents",
            method: "GET"
        )

        let result = await accessController.validate(request)

        XCTAssertFalse(result.granted)
        if case .unauthorized = result.denialReason {
            // Expected
        } else {
            XCTFail("Expected unauthorized error")
        }
    }

    func testAccessDeniedWithInsufficientPermissions() async throws {
        let viewer = User(
            username: "viewer",
            email: "viewer@example.com",
            role: .viewer
        )

        let tokenPair = try await jwtProvider.generateTokenPair(for: viewer)

        let request = AccessRequest(
            token: tokenPair.accessToken,
            resource: "/api/v1/agents/register",
            method: "POST"
        )

        let result = await accessController.validate(request)

        XCTAssertFalse(result.granted)
        if case .forbidden(let permission) = result.denialReason {
            XCTAssertEqual(permission, .registerAgents)
        } else {
            XCTFail("Expected forbidden error with registerAgents permission")
        }
    }

    func testAdminAccessToUserManagement() async throws {
        let admin = User(
            username: "admin",
            email: "admin@example.com",
            role: .admin
        )

        let tokenPair = try await jwtProvider.generateTokenPair(for: admin)

        let request = AccessRequest(
            token: tokenPair.accessToken,
            resource: "/api/v1/users",
            method: "POST"
        )

        let result = await accessController.validate(request)

        XCTAssertTrue(result.granted)
        XCTAssertEqual(result.role, .admin)
    }

    func testOperatorDeniedFromUserManagement() async throws {
        let op = User(
            username: "operator",
            email: "op@example.com",
            role: .operator
        )

        let tokenPair = try await jwtProvider.generateTokenPair(for: op)

        let request = AccessRequest(
            token: tokenPair.accessToken,
            resource: "/api/v1/users",
            method: "POST"
        )

        let result = await accessController.validate(request)

        XCTAssertFalse(result.granted)
    }

    func testPublicEndpointAccessible() async throws {
        let request = AccessRequest(
            token: nil,
            resource: "/api/v1/health",
            method: "GET"
        )

        let result = await accessController.validate(request)

        XCTAssertTrue(result.granted)
    }

    func testAuditLogging() async throws {
        let user = User(
            username: "testuser",
            email: "test@example.com",
            role: .viewer
        )

        let tokenPair = try await jwtProvider.generateTokenPair(for: user)

        // Make a few requests
        for _ in 1...3 {
            let request = AccessRequest(
                token: tokenPair.accessToken,
                resource: "/api/v1/agents",
                method: "GET"
            )
            _ = await accessController.validate(request)
        }

        // Check audit log
        let auditEntries = await accessController.recentAuditEntries(limit: 10)
        XCTAssertGreaterThanOrEqual(auditEntries.count, 3)

        // Entries should be in reverse chronological order
        for i in 1..<auditEntries.count {
            XCTAssertGreaterThanOrEqual(
                auditEntries[i-1].timestamp,
                auditEntries[i].timestamp
            )
        }
    }

    func testAuditLogForDeniedAccess() async throws {
        let request = AccessRequest(
            token: nil,
            resource: "/api/v1/policies",
            method: "POST",
            clientIP: "192.168.1.100"
        )

        _ = await accessController.validate(request)

        let deniedEntries = await accessController.deniedAccessAttempts(limit: 10)
        XCTAssertGreaterThanOrEqual(deniedEntries.count, 1)

        let lastDenied = deniedEntries.first!
        XCTAssertFalse(lastDenied.granted)
        XCTAssertEqual(lastDenied.resource, "/api/v1/policies")
        XCTAssertEqual(lastDenied.clientIP, "192.168.1.100")
    }

    // MARK: - JWT Claims Tests

    func testJWTClaimsValidity() {
        let now = Int(Date().timeIntervalSince1970)

        let validClaims = JWTClaims(
            iss: "test",
            sub: UUID().uuidString,
            exp: now + 3600,
            role: .viewer,
            username: "test"
        )
        XCTAssertTrue(validClaims.isValid)
        XCTAssertFalse(validClaims.isExpired)

        let expiredClaims = JWTClaims(
            iss: "test",
            sub: UUID().uuidString,
            exp: now - 100,
            role: .viewer,
            username: "test"
        )
        XCTAssertFalse(expiredClaims.isValid)
        XCTAssertTrue(expiredClaims.isExpired)
    }

    func testJWTClaimsNotBefore() {
        let now = Int(Date().timeIntervalSince1970)

        let futureClaims = JWTClaims(
            iss: "test",
            sub: UUID().uuidString,
            exp: now + 3600,
            nbf: now + 1000,
            role: .viewer,
            username: "test"
        )
        XCTAssertFalse(futureClaims.isValid)
    }

    // MARK: - Access Policy Tests

    func testAccessPolicyMatching() {
        let policy = AccessPolicy(
            resourcePattern: "/api/v1/agents/{id}",
            methods: ["GET", "DELETE"],
            requiredPermissions: [.viewAgents]
        )

        XCTAssertTrue(policy.matches(resource: "/api/v1/agents/123", method: "GET"))
        XCTAssertTrue(policy.matches(resource: "/api/v1/agents/abc", method: "DELETE"))
        XCTAssertFalse(policy.matches(resource: "/api/v1/agents/123", method: "POST"))
        XCTAssertFalse(policy.matches(resource: "/api/v1/agents", method: "GET"))
    }

    func testAccessPolicyWildcardMatching() {
        let policy = AccessPolicy(
            resourcePattern: "/api/v1/reports/*",
            methods: ["GET"],
            requiredPermissions: [.viewReports]
        )

        XCTAssertTrue(policy.matches(resource: "/api/v1/reports/fleet", method: "GET"))
        XCTAssertTrue(policy.matches(resource: "/api/v1/reports/agent/123", method: "GET"))
        XCTAssertFalse(policy.matches(resource: "/api/v1/policies", method: "GET"))
    }

    // MARK: - Session Management Tests

    func testSessionCaching() async throws {
        let user = User(
            username: "testuser",
            email: "test@example.com",
            role: .operator
        )

        let tokenPair = try await jwtProvider.generateTokenPair(for: user)

        // Make a request to cache session
        let request = AccessRequest(
            token: tokenPair.accessToken,
            resource: "/api/v1/agents",
            method: "GET"
        )
        _ = await accessController.validate(request)

        // Check session is cached
        let session = await accessController.session(for: user.id)
        XCTAssertNotNil(session)
        XCTAssertEqual(session?.username, user.username)
    }

    func testSessionInvalidation() async throws {
        let user = User(
            username: "testuser",
            email: "test@example.com",
            role: .operator
        )

        let tokenPair = try await jwtProvider.generateTokenPair(for: user)

        // Cache session
        let request = AccessRequest(
            token: tokenPair.accessToken,
            resource: "/api/v1/agents",
            method: "GET"
        )
        _ = await accessController.validate(request)

        // Invalidate session
        await accessController.invalidateSession(for: user.id)

        // Session should be removed
        let session = await accessController.session(for: user.id)
        XCTAssertNil(session)
    }

    // MARK: - Permission Check Tests

    func testCheckPermission() async throws {
        let user = User(
            username: "operator",
            email: "op@example.com",
            role: .operator
        )

        let tokenPair = try await jwtProvider.generateTokenPair(for: user)

        let hasViewAgents = await accessController.checkPermission(
            token: tokenPair.accessToken,
            permission: .viewAgents
        )
        XCTAssertTrue(hasViewAgents)

        let hasViewUsers = await accessController.checkPermission(
            token: tokenPair.accessToken,
            permission: .viewUsers
        )
        XCTAssertFalse(hasViewUsers)
    }

    func testCheckRole() async throws {
        let op = User(
            username: "operator",
            email: "op@example.com",
            role: .operator
        )

        let tokenPair = try await jwtProvider.generateTokenPair(for: op)

        let isViewer = await accessController.checkRole(
            token: tokenPair.accessToken,
            minimumRole: .viewer
        )
        XCTAssertTrue(isViewer)

        let isOperator = await accessController.checkRole(
            token: tokenPair.accessToken,
            minimumRole: .operator
        )
        XCTAssertTrue(isOperator)

        let isAdmin = await accessController.checkRole(
            token: tokenPair.accessToken,
            minimumRole: .admin
        )
        XCTAssertFalse(isAdmin)
    }
}
