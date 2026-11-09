import Foundation

/// Process-wide OpenCC gateway.
///
/// Resolution of direction/variant/phrases to a config file lives here (the
/// single source of truth, mirroring `OpenCCEngine.ResolveConfig` on Windows).
/// One lazily opened `OpenCC` instance is cached per config filename and every
/// open/convert/close is serialized by one `NSLock`, because the C API is not
/// thread-safe.
final class OpenCCEngine {
    static let shared = OpenCCEngine()

    private let lock = NSLock()
    private var runtimeDirectory: String?
    private var instances: [String: OpenCC] = [:]

    private init() {}

    /// Points the engine at the directory that holds the `.json` configs and
    /// `.ocd2` dictionaries. Already-cached instances keep their handles.
    func setRuntimeDirectory(_ path: String) {
        lock.lock()
        defer { lock.unlock() }
        runtimeDirectory = path
    }

    /// Maps direction, variant and phrase mode to an OpenCC config filename.
    static func resolveConfig(s2t: Bool, variant: ChineseVariant, localPhrases: Bool) -> String {
        switch variant {
        case .taiwan:
            if s2t { return localPhrases ? "s2twp.json" : "s2tw.json" }
            return localPhrases ? "tw2sp.json" : "tw2s.json"
        case .hongKong:
            if s2t { return localPhrases ? "s2hkp.json" : "s2hk.json" }
            return localPhrases ? "hk2sp.json" : "hk2s.json"
        case .standard:
            return s2t ? "s2t.json" : "t2s.json"
        }
    }

    /// Converts `text`. Empty input short-circuits to an empty string.
    func convert(_ text: String, s2t: Bool, variant: ChineseVariant, localPhrases: Bool) throws -> String {
        if text.isEmpty { return "" }

        let config = OpenCCEngine.resolveConfig(s2t: s2t, variant: variant, localPhrases: localPhrases)

        lock.lock()
        defer { lock.unlock() }

        guard let directory = runtimeDirectory else {
            throw OpenCCError.openFailed(path: config, reason: "OpenCC 运行时目录尚未初始化")
        }

        let engine: OpenCC
        if let cached = instances[config] {
            engine = cached
        } else {
            let path = (directory as NSString).appendingPathComponent(config)
            let opened = try OpenCC(configPath: path)
            instances[config] = opened
            engine = opened
        }

        return try engine.convert(text)
    }

    /// Closes every cached instance. The engine can be reused afterwards.
    func shutdown() {
        lock.lock()
        defer { lock.unlock() }
        for engine in instances.values {
            engine.close()
        }
        instances.removeAll()
    }
}
