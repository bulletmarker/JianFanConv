import SwiftUI

// White rounded card with 1 px border, 40 pt header (title + counter + link)
// and a body area with 10 pt inner padding.
struct Card<Content: View>: View {
    let title: String
    let count: Int
    let actionTitle: String
    let action: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(title)
                    .font(Theme.cardHeaderFont)
                    .foregroundColor(Theme.textPrimary)
                Text("\(count) 字")
                    .font(Theme.counterFont)
                    .foregroundColor(Theme.textMuted)
                Spacer()
                LinkButton(title: actionTitle, action: action)
            }
            .padding(.horizontal, 16)
            .frame(height: 40)

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(10)
        }
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}

// Accent-colored text link with a soft hover pill, mirroring LinkButton.
struct LinkButton: View {
    let title: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Text(title)
            .font(Theme.linkFont)
            .foregroundColor(Theme.accent)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background {
                if hovering {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Theme.accentHover)
                }
            }
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .onTapGesture(perform: action)
            .accessibilityLabel(title)
            .accessibilityAddTraits(.isButton)
    }
}
