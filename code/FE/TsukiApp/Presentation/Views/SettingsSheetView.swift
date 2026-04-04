import SwiftUI

struct SettingsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("provider") private var provider = "mock"
    @AppStorage("requestTimeout") private var timeout: Double = 10
    @AppStorage("shortcutEnabled") private var shortcutEnabled = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("设置")
                .font(.system(size: 16, weight: .bold, design: .monospaced))

            Picker("Provider", selection: $provider) {
                Text("mock").tag("mock")
            }

            HStack {
                Text("超时")
                Slider(value: $timeout, in: 3 ... 30, step: 1)
                Text("\(Int(timeout))s")
                    .frame(width: 40, alignment: .trailing)
            }

            Toggle("启用 Cmd+Enter", isOn: $shortcutEnabled)

            HStack {
                Spacer()
                Button("关闭") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}
