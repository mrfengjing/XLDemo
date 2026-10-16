import SwiftUI

@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var mobile = "8186008872"
    @State private var isLoading = false
    @State private var log = DemoLog.shared

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("发送验证码")
                            .font(.largeTitle.bold())
                        Text("POST /auth/v3.1/user/sendVerifiyCode")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("手机号")
                            .font(.headline)
                        TextField("10 位数字，例如 8186008872", text: $mobile)
                            .textFieldStyle(.roundedBorder)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            .textInputAutocapitalization(.never)
                            #endif
                        Button(action: { Task { await send() } }) {
                            if isLoading {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("发送验证码")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isLoading)
                    }

                    if !log.steps.isEmpty {
                        Text("执行步骤")
                            .font(.headline)
                        ForEach(log.steps) { step in
                            stepRow(step)
                                .id(step.id)
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: 760, alignment: .leading)
            }
            .onChange(of: log.steps) { _, steps in
                guard let last = steps.last else { return }
                withAnimation {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func send() async {
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await VerifyCodeClient.send(mobile: mobile.trimmingCharacters(in: .whitespacesAndNewlines))
        } catch {
            let log = DemoLog.shared
            if log.steps.allSatisfy({ $0.status != .failure }) {
                let id = await log.begin("完成请求")
                log.finish(id, detail: error.localizedDescription, success: false)
            }
        }
    }

    private func stepRow(_ step: LogStep) -> some View {
        let tint = color(for: step.status)
        return HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.15))
                if step.status == .running {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: step.status == .success ? "checkmark" : "xmark")
                        .font(.caption.bold())
                        .foregroundStyle(tint)
                }
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 8) {
                Text(headline(for: step))
                    .font(.headline)
                if !step.detail.isEmpty {
                    Text(step.detail)
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(step.status == .running ? 0.08 : 0.04), in: RoundedRectangle(cornerRadius: 12))
    }

    private func headline(for step: LogStep) -> String {
        switch step.status {
        case .running:
            "正在\(step.title)"
        case .success:
            "已\(step.title)"
        case .failure:
            "\(step.title)失败"
        }
    }

    private func color(for status: LogStep.Status) -> Color {
        switch status {
        case .running:
            .blue
        case .success:
            .green
        case .failure:
            .red
        }
    }
}

#Preview {
    ContentView()
}
