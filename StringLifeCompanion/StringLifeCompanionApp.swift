import SwiftUI

@main
struct StringLifeCompanionApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    var body: some Scene {
        MenuBarExtra("String Life Companion", systemImage: "guitars") {
            CompanionMenuContent(appDelegate: appDelegate)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct CompanionMenuContent: View {
    @ObservedObject var appDelegate: AppDelegate

    var body: some View {
        Group {
            if let coordinator = appDelegate.coordinator {
                ContentView(coordinator: coordinator)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("String Life Companion")
                        .font(.headline)

                    Text(appDelegate.startupError ?? "Companion is starting.")
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .padding()
                .frame(width: 300)
            }
        }
    }
}
