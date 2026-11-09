import Foundation

/// Errors surfaced by the OpenCC wrapper.
///
/// The C API reports failures through a sentinel handle and a global
/// `opencc_error()` string, so the Swift layer translates both into a single
/// localized error type.
enum OpenCCError: LocalizedError {
    case openFailed(path: String, reason: String?)
    case convertFailed

    var errorDescription: String? {
        switch self {
        case let .openFailed(path, reason):
            if let reason = reason, !reason.isEmpty {
                return "OpenCC 打开配置失败：\(path)（\(reason)）"
            }
            return "OpenCC 打开配置失败：\(path)"
        case .convertFailed:
            return "OpenCC 转换失败（opencc_convert_utf8 返回空）"
        }
    }
}

/// Thin Swift wrapper around one OpenCC converter instance.
///
/// The underlying C API is not thread-safe. `OpenCCEngine` owns the single
/// serialization lock and only creates/uses these instances while holding it;
/// code that instantiates `OpenCC` directly must serialize its own calls.
final class OpenCC {
    /// `opencc_open` returns `(opencc_t)-1` to signal failure, so the raw
    /// pointer value can be non-NULL and still be invalid.
    private static let invalidHandle = UnsafeMutableRawPointer(bitPattern: -1)!

    private var handle: UnsafeMutableRawPointer?
    private let configPath: String

    init(configPath: String) throws {
        self.configPath = configPath

        let opened: UnsafeMutableRawPointer? = configPath.withCString { opencc_open($0) }
        guard let opened = opened, opened != OpenCC.invalidHandle else {
            throw OpenCCError.openFailed(path: configPath, reason: OpenCC.readError())
        }

        self.handle = opened
    }

    /// Converts a UTF-8 string, passing the exact byte count to the engine.
    func convert(_ text: String) throws -> String {
        if text.isEmpty { return "" }
        guard let handle = handle, handle != OpenCC.invalidHandle else {
            throw OpenCCError.convertFailed
        }

        let utf8 = Array(text.utf8)
        var converted: UnsafeMutablePointer<CChar>?

        utf8.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            converted = base.withMemoryRebound(to: CChar.self, capacity: buffer.count) { pointer in
                opencc_convert_utf8(handle, pointer, buffer.count)
            }
        }

        guard let result = converted else {
            throw OpenCCError.convertFailed
        }
        defer { opencc_convert_utf8_free(result) }

        return String(cString: result)
    }

    /// Releases the native instance. Safe to call more than once.
    func close() {
        guard let handle = handle else { return }
        self.handle = nil
        if handle != OpenCC.invalidHandle {
            opencc_close(handle)
        }
    }

    deinit {
        close()
    }

    /// Reads the last OpenCC error message.
    ///
    /// `opencc_error()` is the only non-thread-safe C entry point, so callers
    /// must invoke this while holding the same lock used for open/convert.
    private static func readError() -> String? {
        guard let pointer = opencc_error() else { return nil }
        let message = String(cString: pointer)
        return message.isEmpty ? nil : message
    }
}
