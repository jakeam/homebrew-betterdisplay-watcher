// Launches BetterDisplay when a physical external monitor is connected and
// quits it when the last one is disconnected. Event-driven (no polling).
//
// Build:  swiftc -O -swift-version 5 display-watcher.swift -o "BetterDisplay Watcher"
// Check:  "./BetterDisplay Watcher" --status

import AppKit
import CoreGraphics
import IOKit

let appPath = "/Applications/BetterDisplay.app"
let settleDelay: TimeInterval = 3  // displays flap during connect/wake; wait for them to settle

func log(_ message: String) {
    let stamp = ISO8601DateFormatter().string(from: Date())
    print("\(stamp) \(message)")
    fflush(stdout)
}

// A physical monitor on Apple Silicon has a DCPAVServiceProxy with Location "External".
// Virtual displays (e.g. BetterDisplay dummies) never create one.
func hasExternalDisplayPort() -> Bool {
    var iterator: io_iterator_t = 0
    guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("DCPAVServiceProxy"), &iterator) == KERN_SUCCESS else {
        return false
    }
    defer { IOObjectRelease(iterator) }

    var found = false
    var service = IOIteratorNext(iterator)
    while service != 0 {
        let location = IORegistryEntryCreateCFProperty(service, "Location" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? String
        if location == "External" { found = true }
        IOObjectRelease(service)
        service = IOIteratorNext(iterator)
    }
    return found
}

func hasNonBuiltinDisplay() -> Bool {
    var count: UInt32 = 0
    CGGetOnlineDisplayList(0, nil, &count)
    var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
    CGGetOnlineDisplayList(count, &ids, &count)
    return ids.prefix(Int(count)).contains { CGDisplayIsBuiltin($0) == 0 }
}

// Require both signals so a virtual display alone, or a stale port entry alone, doesn't count.
func externalMonitorConnected() -> Bool {
    hasExternalDisplayPort() && hasNonBuiltinDisplay()
}

func runningBetterDisplay() -> [NSRunningApplication] {
    let target = URL(fileURLWithPath: appPath).standardizedFileURL
    return NSWorkspace.shared.runningApplications.filter { $0.bundleURL?.standardizedFileURL == target }
}

func launchBetterDisplay() {
    guard runningBetterDisplay().isEmpty else { return }
    let config = NSWorkspace.OpenConfiguration()
    config.activates = false
    NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: appPath), configuration: config) { _, error in
        log(error.map { "launch failed: \($0.localizedDescription)" } ?? "launched BetterDisplay")
    }
}

func quitBetterDisplay() {
    let apps = runningBetterDisplay()
    guard !apps.isEmpty else { return }
    apps.forEach { $0.terminate() }
    log("quit BetterDisplay")
}

if CommandLine.arguments.contains("--status") {
    print("external display port: \(hasExternalDisplayPort())")
    print("non-built-in display:  \(hasNonBuiltinDisplay())")
    print("monitor connected:     \(externalMonitorConnected())")
    print("BetterDisplay running: \(!runningBetterDisplay().isEmpty)")
    exit(0)
}

// Display reconfiguration callbacks are only delivered to a process running
// NSApplication; a bare RunLoop never receives them. .prohibited keeps it out of the Dock.
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

var lastConnected = externalMonitorConnected()
log("started; external monitor connected: \(lastConnected)")
lastConnected ? launchBetterDisplay() : quitBetterDisplay()

var pendingCheck: DispatchWorkItem?

func scheduleCheck() {
    pendingCheck?.cancel()
    let work = DispatchWorkItem {
        let connected = externalMonitorConnected()
        guard connected != lastConnected else { return }
        lastConnected = connected
        log("external monitor connected: \(connected)")
        connected ? launchBetterDisplay() : quitBetterDisplay()
    }
    pendingCheck = work
    DispatchQueue.main.asyncAfter(deadline: .now() + settleDelay, execute: work)
}

CGDisplayRegisterReconfigurationCallback({ _, flags, _ in
    if !flags.contains(.beginConfigurationFlag) { scheduleCheck() }
}, nil)

app.run()
