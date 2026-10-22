import Foundation
import XCTest
@testable import PokePackBar

@MainActor
final class ServerCredentialStoreTests: XCTestCase {
    private func configuration(account: UUID = UUID(), device: UUID = UUID(),
                               server: String = "https://ppb-api.wonyangs.com") -> RemoteGameConfiguration {
        .init(baseURL: URL(string: server)!, accountID: account, deviceID: device)
    }

    private func credential(_ config: RemoteGameConfiguration, token: String = "synthetic-token") -> ServerCredential {
        .init(access_token: token, account_id: config.accountID, device_id: config.deviceID,
              email: "fixture@example.invalid", expires_at: 0)
    }

    private func withRoot(_ operation: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ppb-credentials-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        try operation(root)
    }

    func testFileLifecycleNeverQueriesKeychain() throws {
        try withRoot { root in
            let config = configuration()
            KeychainReader.resetQueryCountForTesting()
            XCTAssertNil(try ServerCredentialStore.load(config, root: root))
            try ServerCredentialStore.save(credential(config), configuration: config, root: root)
            XCTAssertEqual(try ServerCredentialStore.load(config, root: root)?.access_token, "synthetic-token")
            // A second load models a new app process/build with the same storage path.
            XCTAssertEqual(try ServerCredentialStore.load(config, root: root)?.expires_at, 0)
            try ServerCredentialStore.save(credential(config, token: "replacement"), configuration: config, root: root)
            XCTAssertEqual(try ServerCredentialStore.load(config, root: root)?.access_token, "replacement")
            try ServerCredentialStore.remove(config, root: root)
            try ServerCredentialStore.remove(config, root: root)
            XCTAssertNil(try ServerCredentialStore.load(config, root: root))
            XCTAssertEqual(KeychainReader.queryCount, 0)
        }
    }

    func testPermissionsAndStoredFields() throws {
        try withRoot { root in
            let config = configuration()
            try ServerCredentialStore.save(credential(config), configuration: config, root: root)
            let file = ServerCredentialStore.fileURL(config, root: root)
            let files = FileManager.default
            XCTAssertEqual(try files.attributesOfItem(atPath: root.path)[.posixPermissions] as? Int, 0o700)
            XCTAssertEqual(try files.attributesOfItem(atPath: file.path)[.posixPermissions] as? Int, 0o600)
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
            XCTAssertEqual(Set(object.keys), ["access_token", "account_id", "device_id", "email", "expires_at"])
            XCTAssertNil(object["password"])
        }
    }

    func testServerAccountAndDeviceIsolation() throws {
        try withRoot { root in
            let first = configuration()
            let others = [configuration(account: first.accountID), configuration(device: first.deviceID),
                          configuration(account: first.accountID, device: first.deviceID, server: "https://other.example.invalid")]
            try ServerCredentialStore.save(credential(first), configuration: first, root: root)
            for config in others {
                XCTAssertNotEqual(first.storageKey, config.storageKey)
                XCTAssertNil(try ServerCredentialStore.load(config, root: root))
                try ServerCredentialStore.save(credential(config, token: "other"), configuration: config, root: root)
            }
            try ServerCredentialStore.remove(first, root: root)
            for config in others {
                XCTAssertEqual(try ServerCredentialStore.load(config, root: root)?.access_token, "other")
            }
        }
    }

    func testMismatchedCredentialsDoNotReplaceExistingFile() throws {
        try withRoot { root in
            let config = configuration()
            try ServerCredentialStore.save(credential(config), configuration: config, root: root)
            let before = try Data(contentsOf: ServerCredentialStore.fileURL(config, root: root))
            for invalid in [credential(configuration(account: config.accountID)),
                            credential(configuration(device: config.deviceID)), credential(config, token: "")] {
                XCTAssertThrowsError(try ServerCredentialStore.save(invalid, configuration: config, root: root))
                XCTAssertEqual(try Data(contentsOf: ServerCredentialStore.fileURL(config, root: root)), before)
            }
        }
    }

    func testDamagedAndMismatchedFilesFailWithoutKeychainFallback() throws {
        try withRoot { root in
            let config = configuration()
            try ServerCredentialStore.save(credential(config), configuration: config, root: root)
            let file = ServerCredentialStore.fileURL(config, root: root)
            KeychainReader.resetQueryCountForTesting()
            for bytes in [Data("not-json".utf8), try JSONEncoder().encode(credential(configuration()))] {
                try bytes.write(to: file)
                XCTAssertThrowsError(try ServerCredentialStore.load(config, root: root))
                var reads = 0
                XCTAssertThrowsError(try ServerCredentialStore.importLegacy(config, root: root, read: { _ in
                    reads += 1
                    return self.credential(config)
                }))
                XCTAssertEqual(reads, 0)
            }
            XCTAssertEqual(KeychainReader.queryCount, 0)
        }
    }

    func testOnlyExplicitImportReadsLegacyAndPreservesExpiryMetadata() throws {
        try withRoot { root in
            let config = configuration()
            var reads = 0
            XCTAssertNil(try ServerCredentialStore.load(config, root: root))
            let imported = try ServerCredentialStore.importLegacy(config, root: root, read: { _ in
                reads += 1
                return self.credential(config)
            })
            XCTAssertEqual(imported?.expires_at, 0)
            XCTAssertEqual(reads, 1)
            XCTAssertEqual(try ServerCredentialStore.load(config, root: root)?.access_token, "synthetic-token")
            _ = try ServerCredentialStore.importLegacy(config, root: root, read: { _ in
                reads += 1
                return self.credential(config, token: "stale")
            })
            XCTAssertEqual(reads, 1)
            try ServerCredentialStore.remove(config, root: root)
            XCTAssertNil(try ServerCredentialStore.load(config, root: root), "Logout must not resurrect the old Keychain session")
            XCTAssertEqual(reads, 1)
        }
    }

    func testMissingDeniedAndMismatchedLegacyLeaveNoFile() throws {
        try withRoot { root in
            let config = configuration()
            XCTAssertNil(try ServerCredentialStore.importLegacy(config, root: root, read: { _ in nil }))
            XCTAssertThrowsError(try ServerCredentialStore.importLegacy(config, root: root, read: { _ in
                throw ServerLoginFailure(message: "synthetic denied")
            }))
            XCTAssertThrowsError(try ServerCredentialStore.importLegacy(config, root: root, read: { _ in
                self.credential(self.configuration())
            }))
            XCTAssertNil(try ServerCredentialStore.load(config, root: root))
        }
    }

    func testFailedWritePreservesExistingNonDirectory() throws {
        try withRoot { root in
            try Data("not-a-directory".utf8).write(to: root)
            let config = configuration()
            XCTAssertThrowsError(try ServerCredentialStore.save(credential(config), configuration: config, root: root))
            XCTAssertEqual(try Data(contentsOf: root), Data("not-a-directory".utf8))
        }
    }
}
