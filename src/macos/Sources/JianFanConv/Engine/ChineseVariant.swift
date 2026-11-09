import Foundation

/// Traditional-Chinese target variants exposed by the converter.
///
/// Mirrors the Windows `ChineseVariant` enum so the UI can share the same
/// raw values and iteration order.
enum ChineseVariant: Int, CaseIterable, Identifiable {
    case standard = 0
    case taiwan = 1
    case hongKong = 2

    var id: Int { rawValue }

    /// User-facing label shown in the segmented control.
    var title: String {
        switch self {
        case .standard:
            return "标准"
        case .taiwan:
            return "台湾"
        case .hongKong:
            return "香港"
        }
    }
}
