import SwiftUI

// 64 pt white header with a 1 px bottom border: title + subtitle on the
// left, pin + clear buttons on the right.
struct HeaderBar: View {
    let isPinned: Bool
    let onTogglePin: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("简繁转换")
                    .font(Theme.titleFont)
                    .foregroundColor(Theme.textPrimary)
                Text("OpenCC 本地离线")
                    .font(Theme.subtitleFont)
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
            FlatButton(title: "置顶", isActive: isPinned, action: onTogglePin)
            FlatButton(title: "清空", action: onClear)
        }
        .padding(.horizontal, 20)
        .frame(height: 64)
        .background(Theme.cardBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)
        }
    }
}

// Neutral filled button with hover state, mirroring the Windows FlatButton.
struct FlatButton: View {
    let title: String
    var isActive: Bool = false
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Text(title)
            .font(Theme.controlFont)
            .foregroundColor(isActive ? .white : Theme.textBody)
            .padding(.horizontal, 16)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? Theme.accent : (hovering ? Theme.hover : Theme.background))
            )
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .onTapGesture(perform: action)
            .accessibilityLabel(title)
            .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : [.isButton])
    }
}
