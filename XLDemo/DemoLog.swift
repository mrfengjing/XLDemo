import Darwin
import Foundation
import Observation

struct LogStep: Identifiable, Equatable {
    let id: Int
    var title: String
    var status: Status
    var detail: String

    enum Status: Equatable {
        case running
        case success
        case failure
    }
}

@Observable
final class DemoLog {
    static let shared = DemoLog()

    private(set) var steps: [LogStep] = []
    private var nextID = 0
    private let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    func reset() {
        steps = []
        nextID = 0
        write("----------")
    }

    func begin(_ title: String) async -> Int {
        nextID += 1
        let id = nextID
        steps.append(LogStep(id: id, title: title, status: .running, detail: ""))
        write("")
        write("步骤 \(id) 正在\(title)")
        try? await Task.sleep(for: .milliseconds(180))
        return id
    }

    func finish(_ id: Int, detail: String, success: Bool = true) {
        guard let index = steps.firstIndex(where: { $0.id == id }) else { return }
        steps[index].status = success ? .success : .failure
        steps[index].detail = detail
        let verb = success ? "已" : "未能"
        write("步骤 \(id) \(verb)\(steps[index].title)")
        if !detail.isEmpty {
            write(detail)
        }
    }

    private func write(_ message: String) {
        let stamp = time.string(from: Date())
        for line in message.components(separatedBy: "\n") {
            fputs("[\(stamp)] \(line)\n", stderr)
            fflush(stderr)
        }
    }
}
