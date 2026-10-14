//
//  ContentView.swift
//  EasyLiteRoom
//
//  Created by Shahjahan Rasel on 10/13/26.
//  Main application workspace combining 120Hz canvas, develop inspector, live histogram, and RAW engine.
//

import SwiftUI
import Metal
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var parameters: AdjustmentParameters = .default
    @State private var originalImage: NSImage?
    @State private var renderedImage: NSImage?
    @State private var showSplitComparison: Bool = false
    @State private var inputTexture: MTLTexture?
    @State private var outputTexture: MTLTexture?
    @State private var histogramData: HistogramData = .empty
    @State private var metadata: EXIFMetadata? = .sample
    @State private var splineLUT: [Float] = []
    @State private var isProcessing: Bool = false

    var body: some View {
        NavigationSplitView {
            // Sidebar: Library / Collections placeholder
            VStack(alignment: .leading, spacing: 14) {
                Text("Library")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                List {
                    Section("Catalog") {
                        Label("All Photos", systemImage: "photo.stack")
                            .badge(1)
                        Label("Recently Added", systemImage: "clock")
                        Label("Favorites", systemImage: "heart")
                    }

                    Section("Calibration") {
                        Label("ColorChecker Chart", systemImage: "checkerboard.rectangle")
                    }
                }
                .listStyle(.sidebar)

                Spacer()

                // File Open Button
                Button {
                    openImageFile()
                } label: {
                    Label("Import RAW / Photo", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .padding(14)
            }
            .frame(minWidth: 200, idealWidth: 220)
        } detail: {
            HStack(spacing: 0) {
                // Central Develop Canvas
                DevelopCanvasView(
                    image: renderedImage,
                    originalImage: originalImage,
                    metadata: metadata,
                    showSplitComparison: $showSplitComparison
                )

                Divider()

                // Trailing Develop Inspector
                DevelopInspectorView(
                    parameters: $parameters,
                    histogramData: histogramData,
                    onReset: {
                        parameters = .default
                        updatePipeline()
                    }
                )
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .principal) {
                Picker("Workspace", selection: .constant(0)) {
                    Text("Library").tag(1)
                    Text("Develop").tag(0)
                    Text("Export").tag(2)
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Button("Default Neutral") {
                        parameters = .default
                        updatePipeline()
                    }
                    Divider()
                    Button("Golden Hour (+Temp, +Exposure)") {
                        parameters.temperature = 6800
                        parameters.tint = 8
                        parameters.exposure = 0.45
                        parameters.vibrance = 15
                        updatePipeline()
                    }
                    Button("Cool Nordic Cinema (-Temp, +Contrast)") {
                        parameters.temperature = 4600
                        parameters.tint = -6
                        parameters.contrast = 25
                        parameters.saturation = -10
                        updatePipeline()
                    }
                    Button("High Key Portrait (+Highlights, -Contrast)") {
                        parameters.exposure = 0.65
                        parameters.highlights = -20
                        parameters.shadows = 25
                        parameters.vibrance = 12
                        updatePipeline()
                    }
                    Divider()
                    Button("Subtle S-Curve (Rich Contrast)") {
                        parameters.toneCurveKnots = [
                            SplinePoint(x: 0.0, y: 0.0),
                            SplinePoint(x: 0.25, y: 0.18),
                            SplinePoint(x: 0.75, y: 0.82),
                            SplinePoint(x: 1.0, y: 1.0)
                        ]
                        updatePipeline()
                    }
                } label: {
                    Label("Presets", systemImage: "wand.and.stars")
                }

                Button {
                    showSplitComparison.toggle()
                } label: {
                    Label("Split View", systemImage: "square.split.2x1")
                }
            }
        }
        .task {
            setupInitialImage()
        }
        .onChange(of: parameters) { _, _ in
            updatePipeline()
        }
    }

    private func setupInitialImage() {
        // Generate high-precision synthetic photographic color chart
        guard let tex = TextureGenerator.makeTestChartTexture(width: 1024, height: 768) else { return }
        self.inputTexture = tex
        self.outputTexture = MetalDevice.shared.makeTexture(width: 1024, height: 768)
        self.metadata = .sample

        // Generate baseline unadjusted NSImage
        if let orig = TextureGenerator.makeNSImage(from: tex) {
            self.originalImage = orig
        }

        updatePipeline()
    }

    private func updatePipeline() {
        guard let input = inputTexture, let output = outputTexture else { return }

        // Compute spline LUT using Fritsch-Carlson monotone cubic spline
        let spline = FritschCarlsonSpline(knots: parameters.toneCurveKnots)
        let lut = spline.generateLUT256()

        do {
            try MetalDevice.shared.processImage(
                input: input,
                output: output,
                parameters: parameters,
                lut: lut
            )

            // Compute live 4-channel GPU histogram
            if let hist = try? MetalDevice.shared.computeHistogram(for: output) {
                self.histogramData = hist
            }

            if let result = TextureGenerator.makeNSImage(from: output) {
                self.renderedImage = result
            }
        } catch {
            print("Metal render error: \(error.localizedDescription)")
        }
    }

    private func openImageFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .rawImage]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            loadPhoto(from: url)
        }
    }

    private func loadPhoto(from url: URL) {
        do {
            let decoded = try RAWDecoder.decode(url: url)
            self.inputTexture = decoded.texture
            self.outputTexture = MetalDevice.shared.makeTexture(width: decoded.width, height: decoded.height)
            self.metadata = decoded.metadata

            if let orig = TextureGenerator.makeNSImage(from: decoded.texture) {
                self.originalImage = orig
            }

            updatePipeline()
        } catch {
            print("Failed to decode image from \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }
}

#Preview {
    ContentView()
}
