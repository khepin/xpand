import Foundation
import JavaScriptCore

final class JSEngine {
    private let context: JSContext
    private let config: JSValue

    init(configPath: String) throws {
        guard FileManager.default.fileExists(atPath: configPath) else {
            throw XpandError.configNotFound(configPath)
        }

        let source = try String(contentsOfFile: configPath, encoding: .utf8)
        context = JSContext()!

        // Register env() helper
        let envBlock: @convention(block) (String) -> String = { name in
            ProcessInfo.processInfo.environment[name] ?? ""
        }
        context.setObject(envBlock, forKeyedSubscript: "env" as NSString)

        // Register shell() helper
        let shellBlock: @convention(block) (String) -> String = { cmd in
            let proc = Process()
            let pipe = Pipe()
            proc.executableURL = URL(fileURLWithPath: "/bin/bash")
            proc.arguments = ["-c", cmd]
            proc.standardOutput = pipe
            proc.standardError = FileHandle.nullDevice
            try? proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return (String(data: data, encoding: .utf8) ?? "").trimmingCharacters(in: .newlines)
        }
        context.setObject(shellBlock, forKeyedSubscript: "shell" as NSString)

        // Exception handler
        context.exceptionHandler = { _, exception in
            if let ex = exception {
                fputs("xpand: JS error: \(ex)\n", stderr)
            }
        }

        guard let result = context.evaluateScript(source), !result.isUndefined else {
            throw XpandError.configEvalFailed
        }
        config = result
    }

    var triggers: [String] {
        guard let keys = config.toDictionary()?.keys else { return [] }
        return keys.compactMap { $0 as? String }
    }

    func expand(trigger: String) -> String? {
        guard let value = config.forProperty(trigger) else { return nil }

        if value.isString {
            return value.toString()
        }

        if value.isObject {
            let result = value.call(withArguments: [])
            return result?.toString()
        }

        return nil
    }
}

enum XpandError: Error, CustomStringConvertible {
    case configNotFound(String)
    case configEvalFailed

    var description: String {
        switch self {
        case .configNotFound(let path):
            return "Config file not found: \(path)"
        case .configEvalFailed:
            return "Failed to evaluate config file"
        }
    }
}
