import AppKit
import Foundation

// --- Resolve paths ---
let configDir = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".config/xpand")
let configPath = configDir.appendingPathComponent("xpand.js").path

let soundPath: String? = {
    // Look for thunk.wav next to the executable
    let execDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
    let candidate = execDir.appendingPathComponent("thunk.wav").path
    if FileManager.default.fileExists(atPath: candidate) { return candidate }
    // Fallback: project root (for development)
    let devCandidate = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // Sources
        .deletingLastPathComponent() // project root
        .appendingPathComponent("thunk.wav").path
    if FileManager.default.fileExists(atPath: devCandidate) { return devCandidate }
    return nil
}()

// --- Check accessibility ---
let trusted = AXIsProcessTrustedWithOptions(
    [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
)
guard trusted else {
    fputs("""
    xpand: Accessibility permission required.
    Grant permission in System Settings > Privacy & Security > Accessibility,
    then re-run xpand.

    """, stderr)
    exit(1)
}

// --- Load config ---
let engine: JSEngine
do {
    engine = try JSEngine(configPath: configPath)
} catch {
    fputs("xpand: \(error)\n", stderr)
    exit(1)
}

let triggers = engine.triggers
guard !triggers.isEmpty else {
    fputs("xpand: no triggers found in config\n", stderr)
    exit(1)
}

if let sp = soundPath {
    print("xpand: sound loaded from \(sp)")
} else {
    print("xpand: warning: thunk.wav not found, running without sound")
}

// --- Handle SIGINT ---
signal(SIGINT) { _ in
    print("\nxpand: bye")
    exit(0)
}

// --- Start listening ---
let expander = Expander(engine: engine, soundPath: soundPath)
let listener = KeyListener(triggers: triggers, expander: expander)

if !listener.start() {
    fputs("xpand: failed to create event tap — is Accessibility permission granted?\n", stderr)
    exit(1)
}
