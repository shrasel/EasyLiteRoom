//
//  ContentView.swift
//  EasyLiteRoom
//
//  Created by Shahjahan Rasel on 10/13/26.
//  Main application workspace combining 120Hz canvas, develop inspector, live histogram, RAW engine, and Filmstrip.
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
    @State private var filmstripItems: [FilmstripItem] = []
    @State private var selectedFilmstripId: UUID? = nil
    @State private var showExportSheet: Bool = false
    @State private var currentPhotoURL: URL? = nil
    @State private var isProcessing: Bool = false
    @State private var workspaceMode: Int = 0 // 0 = Develop, 1 = Library, 2 = Export
    @State private var isCropActive: Bool = false

    var body: some View {
        NavigationSplitView {
            // Sidebar: Library / Collections
            VStack(alignment: .leading, spacing: 14) {
                Text("Library")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                List {
                    Section("Catalog") {
                        Label("All Photos", systemImage: "photo.stack")
                            .badge(max(1, filmstripItems.count))
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
            if workspaceMode == 1 {
                // Workspace: Full Catalog Library Grid
                LibraryGridView(
                    items: filmstripItems,
                    selectedId: $selectedFilmstripId,
                    onOpenPhoto: { item in
                        selectedFilmstripId = item.id
                        if let url = item.url {
                            loadPhoto(from: url)
                        }
                        workspaceMode = 0
                    },
                    onImport: {
                        openImageFile()
                    }
                )
            } else {
                // Workspace: Develop Room
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        // Central Develop Canvas
                        DevelopCanvasView(
                            image: renderedImage,
                            originalImage: originalImage,
                            metadata: metadata,
                            showSplitComparison: $showSplitComparison,
                            isCropActive: $isCropActive,
                            parameters: $parameters
                        )

                        Divider()

                        // Trailing Develop Inspector
                        DevelopInspectorView(
                            parameters: $parameters,
                            isCropActive: $isCropActive,
                            histogramData: histogramData,
                            imageSize: renderedImage?.size,
                            onReset: {
                                parameters = .default
                                isCropActive = false
                                updatePipeline()
                            }
                        )
                    }

                    // Horizontal Bottom Filmstrip
                    FilmstripView(
                        items: filmstripItems,
                        selectedId: $selectedFilmstripId,
                        onSelect: { item in
                            selectedFilmstripId = item.id
                            if let url = item.url {
                                loadPhoto(from: url)
                            }
                        }
                    )
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Workspace", selection: $workspaceMode) {
                    Label("Library", systemImage: "square.grid.2x2").tag(1)
                    Label("Develop", systemImage: "slider.horizontal.3").tag(0)
                    Label("Export", systemImage: "square.and.arrow.up").tag(2)
                }
                .pickerStyle(.segmented)
                .frame(width: 260)
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
                        parameters.hsl.orange.saturation = 20
                        parameters.hsl.yellow.luminance = 15
                        updatePipeline()
                    }
                    Button("Cool Nordic Cinema (-Temp, +Contrast)") {
                        parameters.temperature = 4600
                        parameters.tint = -6
                        parameters.contrast = 25
                        parameters.saturation = -10
                        parameters.hsl.blue.saturation = 15
                        parameters.hsl.blue.hue = -5
                        updatePipeline()
                    }
                    Button("Punchy Landscape (Rich Greens & Aquas)") {
                        parameters.contrast = 15
                        parameters.vibrance = 20
                        parameters.hsl.green.saturation = 30
                        parameters.hsl.green.luminance = -10
                        parameters.hsl.blue.saturation = 25
                        parameters.detail.sharpening = 40
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
                .help("Color grading presets")

                Button {
                    showSplitComparison.toggle()
                } label: {
                    Label("Split View", systemImage: showSplitComparison ? "square.split.2x1.fill" : "square.split.2x1")
                }
                .tint(showSplitComparison ? .accentColor : .primary)
                .help("Toggle Before/After comparison view")

                Button {
                    showExportSheet = true
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .keyboardShortcut("e", modifiers: .command)
                .help("Export photo (⌘E)")
            }
        }
        .onChange(of: workspaceMode) { _, newMode in
            if newMode == 2 {
                showExportSheet = true
                workspaceMode = 0
            }
        }
        .sheet(isPresented: $showExportSheet) {
            ExportSheetView(
                inputTexture: inputTexture,
                parameters: parameters,
                isPresented: $showExportSheet
            )
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
            let initialItem = FilmstripItem(title: "Color Calibration Chart", image: orig, isRAW: true, rating: 5)
            self.filmstripItems = [initialItem]
            self.selectedFilmstripId = initialItem.id
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
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            self.currentPhotoURL = url
            let decoded = try RAWDecoder.decode(url: url)
            self.inputTexture = decoded.texture
            self.outputTexture = MetalDevice.shared.makeTexture(width: decoded.width, height: decoded.height)
            self.metadata = decoded.metadata

            // Automatically load XMP sidecar if present
            if let sidecar = XMPCodec.loadSidecar(for: url) {
                self.parameters = sidecar
            } else {
                self.parameters = .default
            }

            if let orig = TextureGenerator.makeNSImage(from: decoded.texture) {
                self.originalImage = orig
                let newItem = FilmstripItem(title: url.lastPathComponent, image: orig, isRAW: true, rating: 0, url: url)
                self.filmstripItems.append(newItem)
                self.selectedFilmstripId = newItem.id
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
