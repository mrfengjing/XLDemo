import Foundation

struct VerifyCodeReport: Equatable {
    var plainHeader: String
    var plainBody: String
    var encryptedHeader: String
    var encryptedBody: String
    var rawResponse: String
    var decryptedResponse: String
}

enum VerifyCodeError: LocalizedError {
    case encryptionFailed
    case invalidResponse
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            return "请求加密失败"
        case .invalidResponse:
            return "响应无法解密"
        case .transport(let message):
            return message
        }
    }
}

enum VerifyCodeClient {
    private static let sendVerifyCodePath = "/auth/v3.1/user/sendVerifiyCode"

    private static var packageName: String {
        Bundle.main.bundleIdentifier ?? ""
    }

    static func send(mobile: String) async throws -> VerifyCodeReport {
        let log = DemoLog.shared
        log.reset()

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let apiKey = AppSecrets.apiKey
        let tokenKey = AppSecrets.tokenKey
        let encryptName = AppSecrets.encryptName
        let headName = AppSecrets.headName
        let alias = AppSecrets.alias
        let header: [String: String] = [
            "sourceChannel": DeviceIdentity.sourceChannel,
            "packageName": packageName,
            "version": version,
            "adid": DeviceIdentity.adid,
            "idfa": DeviceIdentity.idfa,
            "idfv": DeviceIdentity.idfv,
            "userId": "",
            "uuId": "",
        ]
        let parameters: [String: String] = [
            "type": "text",
            "mobile": mobile,
        ]

        let prepareID = await log.begin("读取包名、版本和密钥")
        log.finish(prepareID, detail: """
        手机号: \(mobile.isEmpty ? "(空)" : mobile)
        版本: \(version)
        packageName: \(packageName.isEmpty ? "(空)" : packageName)
        alias: \(AppSecrets.masked(alias))
        headName: \(AppSecrets.masked(headName))
        encryptName: \(AppSecrets.masked(encryptName))
        apiKey/tokenKey 已脱敏，长度 \(apiKey.count)/\(tokenKey.count)
        """)

        let plainID = await log.begin("组装请求头和参数明文")
        guard let plainHeader = jsonString(header),
              let plainBody = jsonString(parameters) else {
            log.finish(plainID, detail: "JSON 序列化失败", success: false)
            throw VerifyCodeError.encryptionFailed
        }
        let prettyHeader = prettyJSON(plainHeader)
        let prettyBody = prettyJSON(plainBody)
        log.finish(plainID, detail: "请求头\n\(prettyHeader)\n\n参数\n\(prettyBody)")

        let headerCipherID = await log.begin("加密请求头")
        guard let encryptedHeader = AESCipher.encrypt(plainHeader, key: tokenKey) else {
            log.finish(headerCipherID, detail: "请求头加密失败", success: false)
            throw VerifyCodeError.encryptionFailed
        }
        log.finish(headerCipherID, detail: encryptedHeader)

        let bodyCipherID = await log.begin("加密请求参数")
        guard let encryptedBody = AESCipher.encrypt(plainBody, key: apiKey) else {
            log.finish(bodyCipherID, detail: "请求参数加密失败", success: false)
            throw VerifyCodeError.encryptionFailed
        }
        log.finish(bodyCipherID, detail: encryptedBody)

        let body = formBody(name: encryptName, value: encryptedBody)
        let endpoint = APIEndpoint(
            path: sendVerifyCodePath,
            method: .post,
            headers: [
                "Content-Type": "application/x-www-form-urlencoded",
                "packageName": alias,
                headName: encryptedHeader,
            ],
            body: body.data(using: .utf8)
        )
        let sendID = await log.begin("发送验证码请求")
        let result: APIResponse
        do {
            result = try await APIEnvironment.client.send(endpoint)
        } catch {
            log.finish(sendID, detail: error.localizedDescription, success: false)
            throw VerifyCodeError.transport(error.localizedDescription)
        }

        let raw = String(data: result.data, encoding: .utf8) ?? ""
        let headerText = result.headers.keys.sorted().map { "\($0): \(result.headers[$0] ?? "")" }.joined(separator: "\n")
        let responseDetail = """
        \(endpoint.method.rawValue) \(result.url.absoluteString)
        HTTP \(result.statusCode)，\(result.data.count) 字节，耗时 \(result.elapsedMilliseconds) ms
        \(headerText)

        原始响应
        \(raw.isEmpty ? "(空)" : raw)
        """
        guard (200..<300).contains(result.statusCode) else {
            log.finish(sendID, detail: responseDetail, success: false)
            throw VerifyCodeError.transport("请求失败（HTTP \(result.statusCode)）\n\(raw)")
        }
        log.finish(sendID, detail: responseDetail)

        let decryptID = await log.begin("解密响应")
        guard let decrypted = AESCipher.decrypt(raw, key: apiKey) else {
            log.finish(decryptID, detail: "响应无法解密", success: false)
            throw VerifyCodeError.invalidResponse
        }
        let pretty = prettyJSON(decrypted)
        log.finish(decryptID, detail: pretty)
        return VerifyCodeReport(
            plainHeader: prettyJSON(plainHeader),
            plainBody: prettyJSON(plainBody),
            encryptedHeader: encryptedHeader,
            encryptedBody: encryptedBody,
            rawResponse: raw,
            decryptedResponse: pretty
        )
    }

    private static func jsonString(_ dictionary: [String: String]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: dictionary) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private static func prettyJSON(_ json: String) -> String {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .sortedKeys]
              ),
              let text = String(data: pretty, encoding: .utf8) else {
            return json
        }
        return text
    }

    /// `+`、`/`、`=` 必须百分号编码，否则表单会把 `+` 当成空格。
    private static func formBody(name: String, value: String) -> String {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._")
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: allowed) ?? name
        let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
        return "\(encodedName)=\(encodedValue)"
    }
}
