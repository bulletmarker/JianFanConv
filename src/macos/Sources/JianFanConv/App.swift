import SwiftUI
import AppKit

// One-time engine bootstrap. Guards against configuring the runtime twice.
enum EngineBootstrap {
    private(set) static var isDone = false

    static func perform() {
        guard !isDone else { return }
        isDone = true
        OpenCCEngine.shared.setRuntimeDirectory(OpenCCResources.directory())
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        EngineBootstrap.perform()
    }

    func applicationWillTerminate(_ notification: Notification) {
        OpenCCEngine.shared.shutdown()
    }
}

@main
struct JianFanConvApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("简繁转换") {
            MainView()
                .frame(minWidth: 760, minHeight: 480)
                .background(Theme.background.ignoresSafeArea())
        }
        .defaultSize(width: 1040, height: 660)
        .windowResizability(.contentMinSize)
    }
}
