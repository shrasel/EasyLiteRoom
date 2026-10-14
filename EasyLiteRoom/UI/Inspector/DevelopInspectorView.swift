//
//  DevelopInspectorView.swift
//  EasyLiteRoom
//
//  Created by Shahjahan Rasel on 10/13/26.
//  Modern macOS develop inspector with precision adjustment controls, live histogram, and tone curve.
//

import SwiftUI

public struct DevelopInspectorView: View {
    @Binding var parameters: AdjustmentParameters
    let histogramData: HistogramData
    var onReset: () -> Void

    public init(
        parameters: Binding<AdjustmentParameters>,
        histogramData: HistogramData,
        onReset: @escaping () -> Void
    ) {
        self._parameters = parameters
        self.histogramData = histogramData
        self.onReset = onReset
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {

                // Header
                HStack {
                    Label("Develop", systemImage: "slider.horizontal.3")
                        .font(.system(size: 13, weight: .bold))
                    Spacer()
                    Button("Reset All") {
                        onReset()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .help("Reset all adjustments to default")
                }

                // Live GPU Histogram Component
                HistogramView(data: histogramData)

                // Tone Curve Section
                GroupBox(label: sectionHeader(title: "Tone Curve", icon: "waveform.path")) {
                    InteractiveToneCurve(knots: $parameters.toneCurveKnots)
                        .padding(.top, 4)
                }

                // White Balance Section
                GroupBox(label: sectionHeader(title: "White Balance", icon: "sun.max.fill")) {
                    VStack(spacing: 8) {
                        PrecisionSlider(
                            title: "Temp",
                            value: $parameters.temperature,
                            range: 2000...12000,
                            defaultValue: 5500,
                            step: 50,
                            unit: "K",
                            valueFormatter: { String(format: "%.0f", $0) }
                        )

                        PrecisionSlider(
                            title: "Tint",
                            value: $parameters.tint,
                            range: -100...100,
                            defaultValue: 0,
                            step: 1
                        )
                    }
                    .padding(.top, 4)
                }

                // Tone Section
                GroupBox(label: sectionHeader(title: "Tone", icon: "circle.lefthalf.filled")) {
                    VStack(spacing: 8) {
                        PrecisionSlider(
                            title: "Exposure",
                            value: $parameters.exposure,
                            range: -5.0...5.0,
                            defaultValue: 0.0,
                            step: 0.05,
                            unit: "EV",
                            valueFormatter: { String(format: $0 >= 0 ? "+%.2f" : "%.2f", $0) }
                        )

                        PrecisionSlider(
                            title: "Contrast",
                            value: $parameters.contrast,
                            range: -100...100,
                            defaultValue: 0,
                            step: 1
                        )

                        PrecisionSlider(
                            title: "Highlights",
                            value: $parameters.highlights,
                            range: -100...100,
                            defaultValue: 0,
                            step: 1
                        )

                        PrecisionSlider(
                            title: "Shadows",
                            value: $parameters.shadows,
                            range: -100...100,
                            defaultValue: 0,
                            step: 1
                        )

                        PrecisionSlider(
                            title: "Whites",
                            value: $parameters.whites,
                            range: -100...100,
                            defaultValue: 0,
                            step: 1
                        )

                        PrecisionSlider(
                            title: "Blacks",
                            value: $parameters.blacks,
                            range: -100...100,
                            defaultValue: 0,
                            step: 1
                        )
                    }
                    .padding(.top, 4)
                }

                // Presence Section
                GroupBox(label: sectionHeader(title: "Presence", icon: "paintpalette.fill")) {
                    VStack(spacing: 8) {
                        PrecisionSlider(
                            title: "Vibrance",
                            value: $parameters.vibrance,
                            range: -100...100,
                            defaultValue: 0,
                            step: 1
                        )

                        PrecisionSlider(
                            title: "Saturation",
                            value: $parameters.saturation,
                            range: -100...100,
                            defaultValue: 0,
                            step: 1
                        )
                    }
                    .padding(.top, 4)
                }
            }
            .padding(14)
        }
        .frame(width: 300)
        .background(.ultraThinMaterial)
    }

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(Color.accentColor)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
        }
    }
}
