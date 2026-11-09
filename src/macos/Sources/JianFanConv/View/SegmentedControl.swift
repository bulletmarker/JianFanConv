import SwiftUI

// N-segment switch mirroring the Windows custom painted SegmentedControl:
// 36 pt tall, white container, 1 px border, 8 pt corner radius, selected
// segment filled with the accent color, hover pill inset by 2 pt.
struct SegmentedControl: View {
    let labels: [String]
    @Binding var selectedIndex: Int
    var minSegmentWidth: CGFloat = 96
    var accessibilityLabel: String = ""

    @State private var hoveredIndex: Int? = nil
    @FocusState private var keyboardFocused: Bool

    var body: some View {
        HStack(spacing: 0) {
            ForEach(labels.indices, id: \.self) { index in
                segment(for: index)
            }
        }
        .frame(height: 36)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Theme.border, lineWidth: 1)
        )
        .focusable(true)
        .focusEffectDisabled()
        .onMoveCommand { direction in
            switch direction {
            case .left where selectedIndex > 0:
                selectedIndex -= 1
            case .right where selectedIndex < labels.count - 1:
                selectedIndex += 1
            default:
                break
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(labels.indices.contains(selectedIndex) ? labels[selectedIndex] : "")
    }

    @ViewBuilder
    private func segment(for index: Int) -> some View {
        let isSelected = index == selectedIndex
        Text(labels[index])
            .font(Theme.controlFont)
            .foregroundColor(isSelected ? .white : Theme.textBody)
            .padding(.horizontal, 12)
            .frame(minWidth: minSegmentWidth, minHeight: 36)
            .contentShape(Rectangle())
            .background {
                if isSelected {
                    Rectangle().fill(Theme.accent)
                } else if hoveredIndex == index {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Theme.hover)
                        .padding(2)
                }
            }
            .onHover { hovering in
                if hovering {
                    hoveredIndex = index
                } else if hoveredIndex == index {
                    hoveredIndex = nil
                }
            }
            .onTapGesture {
                if selectedIndex != index {
                    selectedIndex = index
                }
            }
    }
}
