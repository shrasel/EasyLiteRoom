//
//  DevelopInspectorView.swift
//  EasyLiteRoom
//
//  Created by Shahjahan Rasel on 10/13/26.
//  Modern macOS develop inspector with precision adjustment controls, crop & straighten, resize options, live histogram, and tone curve.
//

import SwiftUI

public struct DevelopInspectorView: View {
    @Binding var parameters: AdjustmentParameters
    @Binding var isCropActive: Bool
    let histogramData: HistogramData
    var imageSize: CGSize?
    var onReset: () -> Void

    public init(
        parameters: Binding<AdjustmentParameters>,
        isCropActive: Binding<Bool>,
        histogramData: HistogramData,
        imageSize: CGSize? = nil,
        onReset: @escaping () -> Void
    ) {
        self._parameters = parameters
        self._isCropActive = isCropActive
        self.histogramData = histogramData
        self.imageSize = imageSize
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

                // MARK: - Crop & Straighten Section
                GroupBox(label: sectionHeader(title: "Crop & Straighten", icon: "crop")) {
                    VStack(alignment: .leading, spacing: 10) {
                        // Toggle interactive crop tool in canvas
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                isCropActive.toggle()
                            }
                        } label: {
                            Label(
                                isCropActive ? "Finish Cropping" : "Interactive Crop Tool",
                                systemImage: isCropActive ? "checkmark.circle.fill" : "crop"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(isCropActive ? .accentColor : .secondary.opacity(0.18))
                        .controlSize(.regular)

                        // Aspect Ratio Preset
                        HStack {
                            Text("Aspect")
                                .frame(width: 60, alignment: .leading)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)

                            Picker("", selection: Binding(
                                get: { parameters.geometry.aspectRatio },
                                set: { newPreset in
                                    let w = imageSize?.width ?? 1920
                                    let h = imageSize?.height ?? 1080
                                    parameters.geometry.setAspectRatio(newPreset, imageWidth: w, imageHeight: h)
                                }
                            )) {
                                ForEach(CropAspectRatio.allCases) { ratio in
                                    Text(ratio.rawValue).tag(ratio)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        // Straighten Angle Slider (-45° to +45°)
                        PrecisionSlider(
                            title: "Straighten",
                            value: $parameters.geometry.rotationAngle,
                            range: -45.0...45.0,
                            defaultValue: 0.0,
                            step: 0.1,
                            unit: "°",
                            valueFormatter: { String(format: $0 >= 0 ? "+%.1f°" : "%.1f°", $0) }
                        )

                        // Flip & Orientation
                        HStack(spacing: 6) {
                            Button {
                                parameters.geometry.flipHorizontal.toggle()
                            } label: {
                                Label("Flip H", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                                    .font(.system(size: 10, weight: .medium))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(parameters.geometry.flipHorizontal ? .accentColor : .primary)
                            .controlSize(.small)

                            Button {
                                parameters.geometry.flipVertical.toggle()
                            } label: {
                                Label("Flip V", systemImage: "arrow.up.and.down.righttriangle.up.righttriangle.down")
                                    .font(.system(size: 10, weight: .medium))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(parameters.geometry.flipVertical ? .accentColor : .primary)
                            .controlSize(.small)

                            Button {
                                withAnimation {
                                    parameters.geometry.resetCrop()
                                }
                            } label: {
                                Image(systemName: "arrow.uturn.backward")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help("Reset Crop to full uncropped dimensions")
                            .disabled(!parameters.geometry.isCropped)
                        }
                    }
                    .padding(.top, 4)
                }

                // MARK: - Tone Curve Section
                GroupBox(label: sectionHeader(title: "Tone Curve", icon: "waveform.path")) {
                    InteractiveToneCurve(knots: $parameters.toneCurveKnots)
                        .padding(.top, 4)
                }

                // MARK: - White Balance Section
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

                // MARK: - Tone Section
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

                // MARK: - Presence Section
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

                // MARK: - HSL Color Grading Section
                GroupBox(label: sectionHeader(title: "Color Grading (HSL)", icon: "swatchpalette.fill")) {
                    HSLColorGradingView(hsl: $parameters.hsl)
                        .padding(.top, 4)
                }

                // MARK: - Detail Section
                GroupBox(label: sectionHeader(title: "Detail & Optics", icon: "sparkles")) {
                    VStack(spacing: 8) {
                        PrecisionSlider(
                            title: "Sharpening",
                            value: $parameters.detail.sharpening,
                            range: 0...100,
                            defaultValue: 0,
                            step: 1,
                            valueFormatter: { String(format: "%.0f", $0) }
                        )

                        PrecisionSlider(
                            title: "Noise Reduction",
                            value: $parameters.detail.noiseReduction,
                            range: 0...100,
                            defaultValue: 0,
                            step: 1,
                            valueFormatter: { String(format: "%.0f", $0) }
                        )
                    }
                    .padding(.top, 4)
                }

                // MARK: - Resize & Resolution Section
                GroupBox(label: sectionHeader(title: "Resize & Resolution", icon: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Enable Output Resizing", isOn: $parameters.geometry.resizeEnabled)
                            .font(.system(size: 11, weight: .medium))

                        if parameters.geometry.resizeEnabled {
                            // Target Width & Height
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Width (px)")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                    TextField("W", value: $parameters.geometry.targetWidth, format: .number)
                                        .textFieldStyle(.roundedBorder)
                                        .controlSize(.small)
                                        .onChange(of: parameters.geometry.targetWidth) { _, newW in
                                            if parameters.geometry.maintainAspectRatio && newW > 0 {
                                                let srcW = Double(imageSize?.width ?? 1920) * Double(parameters.geometry.cropWidth)
                                                let srcH = Double(imageSize?.height ?? 1080) * Double(parameters.geometry.cropHeight)
                                                if srcW > 0 {
                                                    parameters.geometry.targetHeight = max(1, Int(round(Double(newW) * (srcH / srcW))))
                                                }
                                            }
                                        }
                                }

                                Button {
                                    parameters.geometry.maintainAspectRatio.toggle()
                                } label: {
                                    Image(systemName: parameters.geometry.maintainAspectRatio ? "link" : "link.badge.slash")
                                        .font(.system(size: 12))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(parameters.geometry.maintainAspectRatio ? Color.accentColor : .secondary)
                                .padding(.top, 14)
                                .help(parameters.geometry.maintainAspectRatio ? "Aspect ratio locked" : "Free dimensions")

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Height (px)")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                    TextField("H", value: $parameters.geometry.targetHeight, format: .number)
                                        .textFieldStyle(.roundedBorder)
                                        .controlSize(.small)
                                        .onChange(of: parameters.geometry.targetHeight) { _, newH in
                                            if parameters.geometry.maintainAspectRatio && newH > 0 {
                                                let srcW = Double(imageSize?.width ?? 1920) * Double(parameters.geometry.cropWidth)
                                                let srcH = Double(imageSize?.height ?? 1080) * Double(parameters.geometry.cropHeight)
                                                if srcH > 0 {
                                                    parameters.geometry.targetWidth = max(1, Int(round(Double(newH) * (srcW / srcH))))
                                                }
                                            }
                                        }
                                }
                            }

                            // Quick preset chips
                            HStack(spacing: 6) {
                                ForEach([1080, 1920, 2560, 3840], id: \.self) { standardWidth in
                                    Button("\(standardWidth)p") {
                                        parameters.geometry.targetWidth = standardWidth
                                        let srcW = Double(imageSize?.width ?? 1920) * Double(parameters.geometry.cropWidth)
                                        let srcH = Double(imageSize?.height ?? 1080) * Double(parameters.geometry.cropHeight)
                                        if srcW > 0 {
                                            parameters.geometry.targetHeight = max(1, Int(round(Double(standardWidth) * (srcH / srcW))))
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)
                                    .font(.system(size: 9))
                                }
                            }

                            Divider()
                        }

                        // Percentage Scale Slider
                        PrecisionSlider(
                            title: "Scale",
                            value: $parameters.geometry.scalePercent,
                            range: 10.0...200.0,
                            defaultValue: 100.0,
                            step: 1.0,
                            unit: "%",
                            valueFormatter: { String(format: "%.0f%%", $0) }
                        )

                        // Quick Scale Percentage Chips
                        HStack(spacing: 5) {
                            ForEach([25.0, 50.0, 75.0, 100.0, 150.0, 200.0], id: \.self) { pct in
                                Button(String(format: "%.0f%%", pct)) {
                                    parameters.geometry.scalePercent = Float(pct)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                                .font(.system(size: 9))
                                .tint(abs(Double(parameters.geometry.scalePercent) - pct) < 0.5 ? .accentColor : .primary)
                            }
                        }

                        // Output Resolution Readout
                        let srcW = Int(imageSize?.width ?? 1920)
                        let srcH = Int(imageSize?.height ?? 1080)
                        let finalDims = parameters.geometry.computedOutputDimensions(sourceWidth: srcW, sourceHeight: srcH)
                        let mp = Double(finalDims.width * finalDims.height) / 1_000_000.0

                        HStack {
                            Text("Output:")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            Text("\(finalDims.width) × \(finalDims.height) px • \(String(format: "%.1f", mp)) MP")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color.accentColor)
                            Spacer()

                            Button {
                                parameters.geometry.resetResize()
                            } label: {
                                Image(systemName: "arrow.uturn.backward")
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .help("Reset Resize Settings")
                        }
                        .padding(.top, 2)
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
