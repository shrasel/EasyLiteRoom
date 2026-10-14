//
//  ContentView.swift
//  EasyLiteRoom
//
//  Created by Shahjahan Rasel on 10/13/26.
//  Main application workspace combining Adobe Lightroom Classic layout: Top module switcher, Navigator, Catalog, 120Hz canvas with bottom toolbar, Filmstrip, and Dual-mode Right Inspector (Histogram + Develop / Quick Develop & Metadata).
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
    @State private var workspaceMode: Int = 1 // 0 = Develop, 1 = Library, 2 = Export (Default to Library matching Lightroom Classic)
    @State private var isCropActive: Bool = false
    @State private var selectedSidebarItem: SidebarItem? = .allPhotos

    @State private var zoomScale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var isGridView: Bool = false
    @State private var isLeftPanelExpanded: Bool = true
    @State private var isRightPanelExpanded: Bool = true

    private var filteredCatalogItems: [FilmstripItem] {
        guard let selection = selectedSidebarItem else { return filmstripItems }
        switch selection {
        case .allPhotos:
            return filmstripItems
        case .recentlyAdded:
            let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
            let recent = filmstripItems.filter { $0.dateAdded >= cutoff }
            return recent.isEmpty ? filmstripItems : recent
        case .favorites:
            return filmstripItems.filter { $0.isFavorite || $0.rating >= 4 }
        case .colorChecker:
            return filmstripItems.filter { $0.title.contains("Color Calibration") || $0.title.contains("ColorChecker") }
        }
    }

    private var selectedFilmstripItem: FilmstripItem? {
        filmstripItems.first(where: { $0.id == selectedFilmstripId })
    }

    private var currentRating: Int {
        selectedFilmstripItem?.rating ?? 0
    }

    private var currentIsFavorite: Bool {
        selectedFilmstripItem?.isFavorite ?? false
    }

    private var currentTitle: String {
        currentPhotoURL?.lastPathComponent ?? (selectedFilmstripItem?.title ?? "Untitled")
    }

    private var recentItemsCount: Int {
        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        return filmstripItems.filter { $0.dateAdded >= cutoff }.count
    }

    private var favoriteItemsCount: Int {
        return filmstripItems.filter { $0.isFavorite || $0.rating >= 4 }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Lightroom Classic Top Header
            lightroomHeaderBar

            Divider()

            // MARK: - 3-Column Professional Photography Layout
            HStack(spacing: 0) {

                // 1. LEFT PANEL: Navigator + Catalog + Import/Export Actions
                if isLeftPanelExpanded {
                    VStack(spacing: 0) {
                        // Navigator mini-map with zoom modes (FIT | 100% | 200%)
                        NavigatorView(
                            image: renderedImage ?? originalImage,
                            orientationRotation: parameters.geometry.orientationRotation,
                            zoomScale: $zoomScale,
                            panOffset: $panOffset
                        )

                        Divider()

                        // Catalog section
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.secondary)
                                Text("Catalog")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(nsColor: .windowBackgroundColor))

                            Divider()

                            List(selection: $selectedSidebarItem) {
                                SidebarRow(
                                    title: "All Photographs",
                                    systemImage: "photo.stack",
                                    count: filmstripItems.count,
                                    isSelected: selectedSidebarItem == .allPhotos
                                ) {
                                    handleSidebarSelection(.allPhotos)
                                }
                                .tag(SidebarItem.allPhotos)

                                SidebarRow(
                                    title: "Recently Added",
                                    systemImage: "clock",
                                    count: recentItemsCount,
                                    isSelected: selectedSidebarItem == .recentlyAdded
                                ) {
                                    handleSidebarSelection(.recentlyAdded)
                                }
                                .tag(SidebarItem.recentlyAdded)

                                SidebarRow(
                                    title: "Favorites",
                                    systemImage: "heart.fill",
                                    iconColor: .red,
                                    count: favoriteItemsCount,
                                    isSelected: selectedSidebarItem == .favorites
                                ) {
                                    handleSidebarSelection(.favorites)
                                }
                                .tag(SidebarItem.favorites)

                                SidebarRow(
                                    title: "Color Calibration Chart",
                                    systemImage: "checkerboard.rectangle",
                                    iconColor: .blue,
                                    isSelected: selectedSidebarItem == .colorChecker
                                ) {
                                    handleSidebarSelection(.colorChecker)
                                }
                                .tag(SidebarItem.colorChecker)
                            }
                            .listStyle(.sidebar)
                        }

                        Divider()

                        // Bottom Actions: Import... & Export... (Side by Side matching Lightroom Classic)
                        HStack(spacing: 8) {
                            Button {
                                openImageFile()
                            } label: {
                                Text("Import...")
                                    .font(.system(size: 11, weight: .medium))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)

                            Button {
                                showExportSheet = true
                            } label: {
                                Text("Export...")
                                    .font(.system(size: 11, weight: .medium))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                        }
                        .padding(10)
                        .background(Color(nsColor: .windowBackgroundColor))
                    }
                    .frame(width: 230)

                    Divider()
                }

                // 2. CENTER WORKSPACE: Canvas (Loupe / Grid) + Bottom Toolbar + Filmstrip
                VStack(spacing: 0) {
                    if isGridView {
                        // Grid Catalog View
                        LibraryGridView(
                            items: filteredCatalogItems,
                            selectedId: $selectedFilmstripId,
                            collectionTitle: selectedSidebarItem?.title ?? "All Photographs",
                            onOpenPhoto: { item in
                                selectedFilmstripId = item.id
                                if item.title.contains("Color Calibration") || item.title.contains("ColorChecker") {
                                    loadColorCheckerChart()
                                } else if let url = item.url {
                                    loadPhoto(from: url)
                                }
                                isGridView = false
                            },
                            onImport: {
                                openImageFile()
                            },
                            onToggleFavorite: { item in
                                toggleFavorite(for: item.id)
                            },
                            onSetRating: { item, rating in
                                setRating(for: item.id, rating: rating)
                            }
                        )
                    } else {
                        // Loupe Single Photo View with Lightroom Canvas Bottom Toolbar
                        DevelopCanvasView(
                            image: renderedImage,
                            originalImage: originalImage,
                            metadata: metadata,
                            showSplitComparison: $showSplitComparison,
                            isCropActive: $isCropActive,
                            parameters: $parameters,
                            zoomScale: $zoomScale,
                            panOffset: $panOffset,
                            rating: currentRating,
                            isFavorite: currentIsFavorite,
                            currentTitle: currentTitle,
                            totalPhotos: filteredCatalogItems.count,
                            isGridView: isGridView,
                            onToggleGridView: {
                                isGridView.toggle()
                            },
                            onSetRating: { rating in
                                if let id = selectedFilmstripId {
                                    setRating(for: id, rating: rating)
                                }
                            },
                            onToggleFavorite: {
                                if let id = selectedFilmstripId {
                                    toggleFavorite(for: id)
                                }
                            }
                        )
                    }

                    Divider()

                    // Bottom Filmstrip
                    FilmstripView(
                        items: filteredCatalogItems,
                        selectedId: $selectedFilmstripId,
                        onSelect: { item in
                            selectedFilmstripId = item.id
                            if item.title.contains("Color Calibration") || item.title.contains("ColorChecker") {
                                loadColorCheckerChart()
                            } else if let url = item.url {
                                loadPhoto(from: url)
                            }
                        },
                        onToggleFavorite: { item in
                            toggleFavorite(for: item.id)
                        },
                        onSetRating: { item, rating in
                            setRating(for: item.id, rating: rating)
                        }
                    )
                }

                // 3. RIGHT PANEL: Dual-mode Inspector (Develop adjustments OR Library Quick Develop/Metadata)
                if isRightPanelExpanded {
                    Divider()

                    VStack(spacing: 0) {
                        if workspaceMode == 0 {
                            // DEVELOP MODE: Full Develop Inspector (Includes Histogram at top)
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
                        } else {
                            // LIBRARY MODE: Permanent Top Histogram + Quick Develop + Metadata Panel
                            VStack(spacing: 0) {
                                // Live GPU Histogram Component pinned at top
                                HistogramView(data: histogramData)
                                    .padding(.horizontal, 12)
                                    .padding(.top, 10)
                                    .padding(.bottom, 6)

                                Divider()

                                LibraryInspectorView(
                                    parameters: $parameters,
                                    metadata: metadata,
                                    currentURL: currentPhotoURL,
                                    selectedItem: selectedFilmstripItem,
                                    onSetRating: { rating in
                                        if let id = selectedFilmstripId {
                                            setRating(for: id, rating: rating)
                                        }
                                    },
                                    onToggleFavorite: {
                                        if let id = selectedFilmstripId {
                                            toggleFavorite(for: id)
                                        }
                                    },
                                    onExport: {
                                        showExportSheet = true
                                    }
                                )
                            }
                        }
                    }
                    .frame(width: 290)
                }
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

    // MARK: - Lightroom Classic Top Header Bar
    private var lightroomHeaderBar: some View {
        HStack(spacing: 16) {
            // Left: Logo & Identity
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color(red: 0.12, green: 0.14, blue: 0.18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .strokeBorder(Color.blue.opacity(0.6), lineWidth: 1)
                        )
                    Text("Lr")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 0.25, green: 0.70, blue: 1.0))
                }
                .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 0) {
                    Text("EasyLiteRoom")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.primary)
                    Text(workspaceMode == 1 ? "Catalog - Library" : "Catalog - Develop")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Center: Lightroom Module Switcher Tabs (Library | Develop | Export)
            HStack(spacing: 24) {
                moduleTab(title: "Library", mode: 1)
                moduleTab(title: "Develop", mode: 0)
                moduleTab(title: "Export", mode: 2)
            }

            Spacer()

            // Right: Presets & Split View Tools
            HStack(spacing: 10) {
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
                        .font(.system(size: 11, weight: .medium))
                }
                .menuStyle(.borderlessButton)
                .controlSize(.small)

                Button {
                    showSplitComparison.toggle()
                } label: {
                    Image(systemName: showSplitComparison ? "square.split.2x1.fill" : "square.split.2x1")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(showSplitComparison ? Color.accentColor : Color.secondary)
                .help("Toggle Split Before/After (Y)")

                Divider().frame(height: 14)

                // Panel Collapse Toggles
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isLeftPanelExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isLeftPanelExpanded ? "sidebar.left" : "sidebar.left")
                        .font(.system(size: 11))
                        .foregroundStyle(isLeftPanelExpanded ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .help("Toggle Left Panel")

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isRightPanelExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isRightPanelExpanded ? "sidebar.right" : "sidebar.right")
                        .font(.system(size: 11))
                        .foregroundStyle(isRightPanelExpanded ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .help("Toggle Right Panel")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func moduleTab(title: String, mode: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if mode == 2 {
                    showExportSheet = true
                } else {
                    workspaceMode = mode
                    if mode == 0 {
                        isGridView = false
                    }
                }
            }
        } label: {
            VStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: workspaceMode == mode ? .bold : .medium))
                    .foregroundStyle(workspaceMode == mode ? Color.white : Color.secondary)

                Rectangle()
                    .fill(workspaceMode == mode ? Color.white : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
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
            let initialItem = FilmstripItem(
                title: "Color Calibration Chart",
                image: orig,
                isRAW: true,
                rating: 5,
                url: nil,
                dateAdded: Date(),
                isFavorite: true
            )
            self.filmstripItems = [initialItem]
            self.selectedFilmstripId = initialItem.id
        }

        updatePipeline()
    }

    private func handleSidebarSelection(_ item: SidebarItem) {
        selectedSidebarItem = item
        switch item {
        case .allPhotos, .recentlyAdded, .favorites:
            break
        case .colorChecker:
            loadColorCheckerChart()
        }
    }

    private func loadColorCheckerChart() {
        if let existing = filmstripItems.first(where: { $0.title.contains("Color Calibration") || $0.title.contains("ColorChecker") }) {
            selectedFilmstripId = existing.id
            if let tex = TextureGenerator.makeTestChartTexture(width: 1024, height: 768) {
                self.inputTexture = tex
                self.outputTexture = MetalDevice.shared.makeTexture(width: 1024, height: 768)
                self.originalImage = existing.image
                self.metadata = .sample
                self.currentPhotoURL = nil
                self.parameters = .default
                self.isCropActive = false
                updatePipeline()
            }
            return
        }

        guard let tex = TextureGenerator.makeTestChartTexture(width: 1024, height: 768) else { return }
        self.inputTexture = tex
        self.outputTexture = MetalDevice.shared.makeTexture(width: 1024, height: 768)
        self.metadata = .sample
        self.currentPhotoURL = nil
        self.parameters = .default
        self.isCropActive = false

        if let orig = TextureGenerator.makeNSImage(from: tex) {
            self.originalImage = orig
            let item = FilmstripItem(
                title: "Color Calibration Chart",
                image: orig,
                isRAW: true,
                rating: 5,
                url: nil,
                dateAdded: Date(),
                isFavorite: true
            )
            self.filmstripItems.append(item)
            self.selectedFilmstripId = item.id
        }

        updatePipeline()
    }

    private func toggleFavorite(for id: UUID) {
        if let index = filmstripItems.firstIndex(where: { $0.id == id }) {
            filmstripItems[index].isFavorite.toggle()
        }
    }

    private func setRating(for id: UUID, rating: Int) {
        if let index = filmstripItems.firstIndex(where: { $0.id == id }) {
            filmstripItems[index].rating = rating
            if rating >= 4 {
                filmstripItems[index].isFavorite = true
            }
        }
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
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false

        if panel.runModal() == .OK {
            for url in panel.urls {
                loadPhoto(from: url)
            }
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

            if let existingIndex = filmstripItems.firstIndex(where: { $0.url == url }) {
                self.selectedFilmstripId = filmstripItems[existingIndex].id
            } else if let orig = TextureGenerator.makeNSImage(from: decoded.texture) {
                self.originalImage = orig
                let newItem = FilmstripItem(
                    title: url.lastPathComponent,
                    image: orig,
                    isRAW: true,
                    rating: 0,
                    url: url,
                    dateAdded: Date(),
                    isFavorite: false
                )
                self.filmstripItems.append(newItem)
                self.selectedFilmstripId = newItem.id
            }

            // Reset zoom to fit for new photo
            zoomScale = 1.0
            panOffset = .zero

            updatePipeline()
        } catch {
            print("Failed to decode image from \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }
}

public enum SidebarItem: String, Hashable, CaseIterable, Identifiable {
    case allPhotos = "all_photos"
    case recentlyAdded = "recently_added"
    case favorites = "favorites"
    case colorChecker = "color_checker"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .allPhotos: return "All Photographs"
        case .recentlyAdded: return "Recently Added"
        case .favorites: return "Favorites"
        case .colorChecker: return "Color Calibration Chart"
        }
    }
}

fileprivate struct SidebarRow: View {
    let title: String
    let systemImage: String
    var iconColor: Color? = nil
    var count: Int? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundStyle(iconColor ?? (isSelected ? .primary : .secondary))
                    .frame(width: 18)

                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(.primary)

                Spacer()

                if let count = count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
}
