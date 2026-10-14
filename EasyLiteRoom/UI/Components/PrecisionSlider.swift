//
//  PrecisionSlider.swift
//  EasyLiteRoom
//
//  Created by Shahjahan Rasel on 10/13/26.
//  Tactile macOS precision slider with fine scrub modifiers and zero-notch snap.
//

import SwiftUI
import AppKit

public struct PrecisionSlider: View {
    let title: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let defaultValue: Float
    let step: Float
    let unit: String
    let valueFormatter: (Float) -> String

    @State private var isHovered: Bool = false
    @State private var isEditingDirectly: Bool = false
    @State private var editText: String = ""

    public init(
        title: String,
        value: Binding<Float>,
        range: ClosedRange<Float>,
        defaultValue: Float = 0.0,
        step: Float = 1.0,
        unit: String = "",
        valueFormatter: ((Float) -> String)? = nil
    ) {
        self.title = title
        self._value = value
        self.range = range
        self.defaultValue = defaultValue
        self.step = step
        self.unit = unit
        self.valueFormatter = valueFormatter ?? { val in
            if abs(val) < 1e-4 { return "0" }
            return String(format: val > 0 ? "+%.2f" : "%.2f", val)
        }
    }

    private var normalizedProgress: Double {
        let total = Double(range.upperBound - range.lowerBound)
        guard total > 0 else { return 0.5 }
        return Double(value - range.lowerBound) / total
    }

    private var hasCenterNotch: Bool {
        range.lowerBound < 0 && range.upperBound > 0
    }

    public var body: some View {
        VStack(spacing: 4) {
            HStack {
                // Title with double-click reset
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                            value = defaultValue
                        }
                    }
                    .help("Double-click to reset to default (\(defaultValue))")

                Spacer()

                // Value readout with inline text editing
                if isEditingDirectly {
                    TextField("", text: $editText)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .textFieldStyle(.plain)
                        .frame(width: 55)
                        .multilineTextAlignment(.trailing)
                        .onSubmit {
                            if let parsed = Float(editText) {
                                value = max(range.lowerBound, min(range.upperBound, parsed))
                            }
                            isEditingDirectly = false
                        }
                        .onExitCommand {
                            isEditingDirectly = false
                        }
                } else {
                    Text(valueFormatter(value) + (unit.isEmpty ? "" : " \(unit)"))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(value != defaultValue ? .primary : .secondary)
                        .onTapGesture {
                            editText = String(format: "%.2f", value)
                            isEditingDirectly = true
                        }
                }
            }

            // Custom tactile slider track
            GeometryReader { geometry in
                let width = geometry.size.width
                let thumbX = CGFloat(normalizedProgress) * width

                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(nsColor: .separatorColor).opacity(0.35))
                        .frame(height: 5)

                    // Center notch marker if bidirectional
                    if hasCenterNotch {
                        let centerRatio = Double(-range.lowerBound) / Double(range.upperBound - range.lowerBound)
                        let centerX = CGFloat(centerRatio) * width

                        Rectangle()
                            .fill(Color.secondary.opacity(0.4))
                            .frame(width: 1.5, height: 7)
                            .position(x: centerX, y: 2.5)

                        // Active fill bar originating from center
                        let barStart = min(centerX, thumbX)
                        let barWidth = abs(thumbX - centerX)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.accentColor.opacity(0.85))
                            .frame(width: barWidth, height: 4)
                            .offset(x: barStart)
                    } else {
                        // Standard left-to-right fill
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.accentColor.opacity(0.85))
                            .frame(width: max(0, thumbX), height: 4)
                    }

                    // Thumb
                    Circle()
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                        .frame(width: 11, height: 11)
                        .offset(x: max(0, min(width - 11, thumbX - 5.5)))
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let flags = NSEvent.modifierFlags
                            var sensitivity: Float = 1.0

                            // ⌥ Option key = 0.2x Fine Scrubbing
                            if flags.contains(.option) {
                                sensitivity = 0.2
                            } else if flags.contains(.shift) {
                                // ⇧ Shift key = 2.5x Fast Scrubbing
                                sensitivity = 2.5
                            }

                            let ratio = Float(gesture.location.x / width)
                            let targetValue = range.lowerBound + ratio * (range.upperBound - range.lowerBound)

                            let delta = (targetValue - value) * sensitivity
                            var updated = value + delta
                            updated = max(range.lowerBound, min(range.upperBound, updated))

                            // Snap to center notch if close
                            if hasCenterNotch && abs(updated) < (step * 0.75) {
                                updated = 0.0
                            }

                            value = updated
                        }
                )
            }
            .frame(height: 12)
        }
        .padding(.vertical, 2)
    }
}
