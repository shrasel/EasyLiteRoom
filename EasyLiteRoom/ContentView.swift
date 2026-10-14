//
//  ContentView.swift
//  EasyLiteRoom
//
//  Created by Shahjahan Rasel on 10/13/26.
//  Main application workspace combining 120Hz canvas and develop inspector.
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
                    showSplitComparison: $showSplitComparison
                )

                Divider()

                // Trailing Develop Inspector
                DevelopInspectorView(
                    parameters: $parameters,
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
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return
        }

        let width = cgImage.width
        let height = cgImage.height

        guard let inTex = MetalDevice.shared.makeTexture(width: width, height: height),
              let outTex = MetalDevice.shared.makeTexture(width: width, height: height) else {
            return
        }

        // Upload CGImage to inTex in 32-bit float
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        var rawBytes = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &rawBytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Convert to linear 32-bit float
        var floatPixels = [Float](repeating: 0.0, count: width * height * 4)
        for i in 0..<(width * height * 4) {
            floatPixels[i] = WorkingColorSpace.sRGB.toLinear(Float(rawBytes[i]) / 255.0)
        }

        let region = MTLRegionMake2D(0, 0, width, height)
        let bytesPerRow = width * 4 * MemoryLayout<Float>.size
        floatPixels.withUnsafeBytes { ptr in
            inTex.replace(region: region, mipmapLevel: 0, withBytes: ptr.baseAddress!, bytesPerRow: bytesPerRow)
        }

        self.inputTexture = inTex
        self.outputTexture = outTex

        if let orig = TextureGenerator.makeNSImage(from: inTex) {
            self.originalImage = orig
        }

        updatePipeline()
    }
}

#Preview {
    ContentView()
}
