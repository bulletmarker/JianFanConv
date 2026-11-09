import Foundation

/// Locates the OpenCC runtime assets (configs + dictionaries).
enum OpenCCResources {
    /// Returns the asset directory in this order:
    /// 1. `JIANFAN_OPENCC_DIR` environment override (non-empty).
    /// 2. `Contents/Resources/opencc` inside the app bundle, if it exists.
    /// 3. `<cwd>/vendor/opencc` for running straight from a source checkout.
    static func directory() -> String {
        if let override = ProcessInfo.processInfo.environment["JIANFAN_OPENCC_DIR"], !override.isEmpty {
            return override
        }

        if let resourceURL = Bundle.main.resourceURL {
            let bundled = resourceURL.appendingPathComponent("opencc").path
            if FileManager.default.fileExists(atPath: bundled) {
                return bundled
            }
        }

        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("vendor")
            .appendingPathComponent("opencc")
            .path
    }
}
