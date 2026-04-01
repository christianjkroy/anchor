import Foundation
import CryptoKit
import Security
import CommonCrypto
import UIKit

struct EncryptionService {
    private static let keychainAccount = "com.anchor.encryption-key"

    // MARK: - Key Derivation

    static func deriveAndStoreKey(userID: String) throws {
        guard let saltData = userID.data(using: .utf8),
              let passphraseData = devicePassphrase().data(using: .utf8) else {
            throw EncryptionError.keyDerivationFailed
        }
        let key = try deriveKey(passphrase: passphraseData, salt: saltData)
        try storeKeyInKeychain(key)
    }

    static func retrieveKey() throws -> SymmetricKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            throw EncryptionError.keyNotFound
        }
        return SymmetricKey(data: data)
    }

    // MARK: - Encrypt / Decrypt

    static func encrypt(_ data: Data) throws -> Data {
        let key = try retrieveKey()
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw EncryptionError.encryptionFailed
        }
        return combined
    }

    static func decrypt(_ data: Data) throws -> Data {
        let key = try retrieveKey()
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }

    static func encryptString(_ string: String) throws -> Data {
        guard let data = string.data(using: .utf8) else { throw EncryptionError.encryptionFailed }
        return try encrypt(data)
    }

    static func decryptToString(_ data: Data) throws -> String {
        let decrypted = try decrypt(data)
        guard let string = String(data: decrypted, encoding: .utf8) else { throw EncryptionError.decryptionFailed }
        return string
    }

    // MARK: - Private helpers

    private static func deriveKey(passphrase: Data, salt: Data) throws -> SymmetricKey {
        // PBKDF2-SHA256, 100,000 iterations, 32 bytes (256-bit)
        var derivedKey = Data(count: 32)
        let result = derivedKey.withUnsafeMutableBytes { derivedKeyBytes in
            passphrase.withUnsafeBytes { passphraseBytes in
                salt.withUnsafeBytes { saltBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passphraseBytes.baseAddress, passphrase.count,
                        saltBytes.baseAddress, salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        100_000,
                        derivedKeyBytes.baseAddress, 32
                    )
                }
            }
        }
        guard result == kCCSuccess else { throw EncryptionError.keyDerivationFailed }
        return SymmetricKey(data: derivedKey)
    }

    private static func storeKeyInKeychain(_ key: SymmetricKey) throws {
        var keyData = Data(count: 32)
        key.withUnsafeBytes { keyData = Data($0) }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: keyData
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw EncryptionError.keychainWriteFailed }
    }

    private static func devicePassphrase() -> String {
        UIDevice.current.identifierForVendor?.uuidString ?? "anchor-default-device-passphrase"
    }

    // MARK: - Errors

    enum EncryptionError: LocalizedError {
        case keyDerivationFailed
        case keyNotFound
        case encryptionFailed
        case decryptionFailed
        case keychainWriteFailed

        var errorDescription: String? {
            switch self {
            case .keyDerivationFailed: return "Could not derive encryption key."
            case .keyNotFound: return "Encryption key not found. Please sign in again."
            case .encryptionFailed: return "Encryption failed."
            case .decryptionFailed: return "Decryption failed."
            case .keychainWriteFailed: return "Could not store key in Keychain."
            }
        }
    }
}
