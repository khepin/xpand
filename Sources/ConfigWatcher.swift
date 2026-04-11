import Foundation

final class ConfigWatcher {
    private let configPath: String
    private var sources: [DispatchSourceFileSystemObject] = []
    private var lastModified: Date?
    private let onChange: () -> Void

    init(configPath: String, onChange: @escaping () -> Void) {
        self.configPath = configPath
        self.onChange = onChange
        self.lastModified = modificationDate()
    }

    func start() {
        // Collect unique directories to watch: the symlink's parent AND the real file's parent
        var directories: [String] = []
        let symlinkDir = (configPath as NSString).deletingLastPathComponent
        directories.append(symlinkDir)

        if let realPath = try? FileManager.default.destinationOfSymbolicLink(atPath: configPath) {
            let resolved = realPath.hasPrefix("/")
                ? realPath
                : (symlinkDir as NSString).appendingPathComponent(realPath)
            let realDir = (resolved as NSString).deletingLastPathComponent
            if realDir != symlinkDir {
                directories.append(realDir)
                print("xpand: config is symlinked, watching \(realDir) too")
            }
        }

        for dir in directories {
            let fd = open(dir, O_EVTONLY)
            guard fd >= 0 else {
                fputs("xpand: warning: could not watch \(dir)\n", stderr)
                continue
            }

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .attrib],
                queue: .main
            )

            source.setEventHandler { [weak self] in
                self?.checkForChanges()
            }

            source.setCancelHandler {
                close(fd)
            }

            source.resume()
            sources.append(source)
        }
    }

    private func checkForChanges() {
        let newDate = modificationDate()
        guard newDate != lastModified else { return }
        lastModified = newDate
        print("xpand: config changed, reloading…")
        onChange()
    }

    private func modificationDate() -> Date? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: configPath) else {
            return nil
        }
        return attrs[.modificationDate] as? Date
    }
}
