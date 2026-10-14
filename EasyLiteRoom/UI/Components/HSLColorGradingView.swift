//
//  HSLColorGradingView.swift
//  EasyLiteRoom
//
//  Created by Shahjahan Rasel on 10/13/26.
//  8-band photographic HSL color grading UI with color-coded scrub sliders.
//

import SwiftUI

public enum HSLTargetMode: String, CaseIterable, Identifiable {
    case saturation = "Saturation"
    case luminance = "Luminance"
    case hue = "Hue"

    public var id: String { rawValue }
}

public struct HSLColorGradingView: View {
    @Binding var hsl: HSLParameters
    @State private var selectedMode: HSLTargetMode = .saturation

    public init(hsl: Binding<HSLParameters>) {
        self._hsl = hsl
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Mode Picker: Hue | Saturation | Luminance
            Picker("Mode", selection: $selectedMode) {
                ForEach(HSLTargetMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 4)

            // 8 Color Sliders
            VStack(spacing: 6) {
                hslRow(title: "Red", color: .red, binding: targetBinding(for: \.red))
                hslRow(title: "Orange", color: .orange, binding: targetBinding(for: \.orange))
                hslRow(title: "Yellow", color: .yellow, binding: targetBinding(for: \.yellow))
                hslRow(title: "Green", color: .green, binding: targetBinding(for: \.green))
                hslRow(title: "Aqua", color: .teal, binding: targetBinding(for: \.aqua))
                hslRow(title: "Blue", color: .blue, binding: targetBinding(for: \.blue))
                hslRow(title: "Purple", color: .purple, binding: targetBinding(for: \.purple))
                hslRow(title: "Magenta", color: .pink, binding: targetBinding(for: \.magenta))
            }

            HStack {
                Spacer()
                Button("Reset HSL") {
                    hsl = HSLParameters()
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            }
            .padding(.top, 2)
        }
    }

    private func targetBinding(for keyPath: WritableKeyPath<HSLParameters, HSLAdjustment>) -> Binding<Float> {
        switch selectedMode {
        case .hue:
            return Binding(
                get: { hsl[keyPath: keyPath].hue },
                set: { hsl[keyPath: keyPath].hue = $0 }
            )
        case .saturation:
            return Binding(
                get: { hsl[keyPath: keyPath].saturation },
                set: { hsl[keyPath: keyPath].saturation = $0 }
            )
        case .luminance:
            return Binding(
                get: { hsl[keyPath: keyPath].luminance },
                set: { hsl[keyPath: keyPath].luminance = $0 }
            )
        }
    }

    private func hslRow(title: String, color: Color, binding: Binding<Float>) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)

            PrecisionSlider(
                title: title,
                value: binding,
                range: -100...100,
                defaultValue: 0,
                step: 1
            )
        }
    }
}
