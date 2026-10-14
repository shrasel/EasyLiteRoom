//
//  GlassBackground.swift
//  EasyLiteRoom
//
//  Created by Shahjahan Rasel on 10/13/26.
//  Modern macOS Sequoia translucent glass styling.
//

import SwiftUI

public struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat

    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 3)
            )
    }
}

public extension View {
    func glassCard(cornerRadius: CGFloat = 10) -> some View {
        self.modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }
}
