import CommonCrypto
import Foundation

enum AESCipher {
    /// AES-CBC + PKCS7。16 字节密钥为 AES-128，32 字节为 AES-256。IV 取密钥前 16 字节。
    static func encrypt(_ plain: String, key: String) -> String? {
        guard let data = plain.data(using: .utf8),
              let encrypted = crypt(data, key: key, operation: CCOperation(kCCEncrypt)) else {
            return nil
        }
        return encrypted.base64EncodedString()
    }

    static func decrypt(_ encoded: String, key: String) -> String? {
        let trimmed = encoded
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        guard let data = Data(base64Encoded: trimmed),
              let decrypted = crypt(data, key: key, operation: CCOperation(kCCDecrypt)),
              let text = String(data: decrypted, encoding: .utf8) else {
            return nil
        }
        return text
    }

    private static func crypt(_ data: Data, key: String, operation: CCOperation) -> Data? {
        let keyData = Data(key.utf8)
        let keySize = keyData.count
        guard keySize == kCCKeySizeAES128 || keySize == kCCKeySizeAES256 else {
            return nil
        }
        let ivData = Data(keyData.prefix(kCCBlockSizeAES128))
        var output = Data(count: data.count + kCCBlockSizeAES128)
        var outputLength = 0

        let status: CCCryptorStatus = output.withUnsafeMutableBytes { outputBytes in
            data.withUnsafeBytes { dataBytes in
                keyData.withUnsafeBytes { keyBytes in
                    ivData.withUnsafeBytes { ivBytes in
                        CCCrypt(
                            operation,
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress,
                            keySize,
                            ivBytes.baseAddress,
                            dataBytes.baseAddress,
                            data.count,
                            outputBytes.baseAddress,
                            outputBytes.count,
                            &outputLength
                        )
                    }
                }
            }
        }

        guard status == kCCSuccess else { return nil }
        return output.prefix(outputLength)
    }
}
