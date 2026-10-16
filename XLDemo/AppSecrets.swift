import Foundation

enum AppSecrets {
    static var apiKey: String { reveal(apiKeyBytes) }
    static var tokenKey: String { reveal(tokenKeyBytes) }
    static var encryptName: String { reveal(encryptNameBytes) }
    static var headName: String { reveal(headNameBytes) }
    static var alias: String { reveal(aliasBytes) }

    static func masked(_ value: String) -> String {
        guard value.count > 4 else {
            return String(repeating: "*", count: max(value.count, 1))
        }
        let hiddenCount = value.count - 4
        return "\(value.prefix(2))\(String(repeating: "*", count: hiddenCount))\(value.suffix(2))"
    }

    private static let mask: UInt8 = 0x5A
    private static let apiKeyBytes: [UInt8] = [0x0F, 0x32, 0x6F, 0x1F, 0x20, 0x32, 0x00, 0x35, 0x12, 0x2E, 0x0F, 0x2A, 0x2B, 0x09, 0x1B, 0x18]
    private static let tokenKeyBytes: [UInt8] = [0x2F, 0x22, 0x3D, 0x3C, 0x20, 0x0A, 0x1E, 0x17, 0x39, 0x11, 0x69, 0x6F, 0x18, 0x2D, 0x28, 0x68, 0x0C, 0x62, 0x35, 0x6A, 0x36, 0x03, 0x3F, 0x6C, 0x08, 0x11, 0x38, 0x03, 0x0B, 0x22, 0x2C, 0x2E]
    private static let encryptNameBytes: [UInt8] = [0x09, 0x16, 0x1D, 0x0A, 0x08, 0x0F, 0x0E, 0x15]
    private static let headNameBytes: [UInt8] = [0x10, 0x15, 0x1D, 0x1D, 0x12, 0x02, 0x0D]
    private static let aliasBytes: [UInt8] = [0x2D, 0x2F, 0x34, 0x33, 0x2C, 0x3F, 0x28, 0x29, 0x3B, 0x36]

    private static func reveal(_ bytes: [UInt8]) -> String {
        String(bytes: bytes.map { $0 ^ mask }, encoding: .utf8) ?? ""
    }
}
