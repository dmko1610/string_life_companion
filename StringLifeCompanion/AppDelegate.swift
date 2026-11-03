import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let probe  = AmplifierProbe()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        probe.start()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        probe.stop()
    }
}
