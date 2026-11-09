import SwiftUI

// 30 pt status strip: conversion status on the left, engine badge on the right.
struct StatusBar: View {
    let status: String

    var body: some View {
        HStack {
            Text(status)
                .font(Theme.subtitleFont)
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
            Text("OpenCC · 离线")
                .font(Theme.subtitleFont)
                .foregroundColor(Theme.textMuted)
        }
        .padding(.horizontal, 20)
        .frame(height: 30)
        .background(Theme.background)
    }
}
