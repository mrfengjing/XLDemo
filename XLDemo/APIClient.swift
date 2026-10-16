import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
}

struct APIEndpoint {
    var path: String
    var method: HTTPMethod
    var headers: [String: String] = [:]
    var body: Data?
    var timeout: TimeInterval = 20
}

struct APIResponse {
    var url: URL
    var statusCode: Int
    var headers: [String: String]
    var data: Data
    var elapsedMilliseconds: Int
}

enum APIError: LocalizedError {
    case invalidURL
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "接口地址无效"
        case .transport(let message):
            return message
        }
    }
}

enum APIEnvironment {
    static let baseURL = URL(string: "http://101.132.90.7:10018")!
    static let client = APIClient(baseURL: baseURL)
}

struct APIClient {
    var baseURL: URL
    var session: URLSession = .shared

    func send(_ endpoint: APIEndpoint) async throws -> APIResponse {
        guard let url = url(for: endpoint.path) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = endpoint.timeout
        for (field, value) in endpoint.headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        request.httpBody = endpoint.body

        let started = Date()
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        let http = response as? HTTPURLResponse
        let status = http?.statusCode ?? -1
        let elapsed = Int(Date().timeIntervalSince(started) * 1000)
        let headers = http?.allHeaderFields.reduce(into: [String: String]()) { result, item in
            result["\(item.key)"] = "\(item.value)"
        } ?? [:]
        return APIResponse(
            url: url,
            statusCode: status,
            headers: headers,
            data: data,
            elapsedMilliseconds: elapsed
        )
    }

    private func url(for path: String) -> URL? {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        let suffix = path.hasPrefix("/") ? path : "/" + path
        components.path = components.path + suffix
        return components.url
    }
}
