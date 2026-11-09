import SwiftUI

// 52 pt white toolbar with a 1 px bottom border: direction switch, region
// switch and the local-phrases toggle.
struct ToolbarView: View {
    @Binding var s2t: Bool
    @Binding var variant: ChineseVariant
    @Binding var localPhrases: Bool

    var body: some View {
        HStack(spacing: 24) {
            SegmentedControl(
                labels: ["简 → 繁", "繁 → 简"],
                selectedIndex: directionIndex,
                minSegmentWidth: 96,
                accessibilityLabel: "方向切换"
            )
            SegmentedControl(
                labels: ChineseVariant.allCases.map { $0.title },
                selectedIndex: variantIndex,
                minSegmentWidth: 64,
                accessibilityLabel: "繁体地区"
            )
            PhraseToggle(isOn: $localPhrases, isEnabled: variant != .standard)
            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(height: 52)
        .background(Theme.cardBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)
        }
    }

    private var directionIndex: Binding<Int> {
        Binding(
            get: { s2t ? 0 : 1 },
            set: { s2t = ($0 == 0) }
        )
    }

    private var variantIndex: Binding<Int> {
        Binding(
            get: { variant.rawValue },
            set: { variant = ChineseVariant(rawValue: $0) ?? .standard }
        )
    }
}

// Custom checkbox mirroring the Windows FlatCheckBox: 16 pt rounded box,
// accent fill with a white check when on, muted label when disabled.
struct PhraseToggle: View {
    @Binding var isOn: Bool
    let isEnabled: Bool

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            box
            Text("地区用词")
                .font(Theme.controlFont)
                .foregroundColor(isEnabled ? Theme.textBody : Theme.textMuted)
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture {
            if isEnabled {
                isOn.toggle()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("地区用词")
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
        .accessibilityDisabled(!isEnabled)
    }

    private var box: some View {
        let on = isOn && isEnabled
        return RoundedRectangle(cornerRadius: 4)
            .fill(boxFill(on: on))
            .frame(width: 16, height: 16)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(on ? Theme.accent : Theme.border, lineWidth: 1)
            )
            .overlay {
                if on {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            }
    }

    private func boxFill(on: Bool) -> Color {
        if on { return Theme.accent }
        if hovering && isEnabled { return Theme.hover }
        return Theme.cardBackground
    }
}
