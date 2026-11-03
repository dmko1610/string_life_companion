import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let probe  = AmplifierProcessMonitor()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        probe.start()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        probe.stop()
    }
}
