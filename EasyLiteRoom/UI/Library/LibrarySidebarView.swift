//
//  LibrarySidebarView.swift
//  EasyLiteRoom
//
//  Created by Shahjahan Rasel on 10/14/26.
//  Lightroom Classic Library left sidebar: Navigator, Catalog, Folders, Collections, Publish Services, and Import/Export actions.
//

import SwiftUI
import AppKit

public struct LibrarySidebarView: View {
    let renderedImage: NSImage?
    let originalImage: NSImage?
    let orientationRotation: Int
    @Binding var zoomScale: CGFloat
    @Binding var panOffset: CGSize

    let filmstripItems: [FilmstripItem]
    @Binding var selectedSidebarItem: SidebarItem?
    let lastImportCount: Int
    let favoriteItemsCount: Int

    var onImport: () -> Void
    var onExport: () -> Void
    var onSelectFolder: ((URL) -> Void)? = nil
    var onAddFolder: (() -> Void)? = nil

    // Section collapse states matching Lightroom Classic
    @State private var isNavigatorExpanded: Bool = true
    @State private var isCatalogExpanded: Bool = true
    @State private var isFoldersExpanded: Bool = true
    @State private var isCollectionsExpanded: Bool = true
    @State private var isPublishServicesExpanded: Bool = true

    // Sub-items expansion
    @State private var isDriveExpanded: Bool = true
    @State private var isSmartCollectionsExpanded: Bool = false

    // Filter fields
    @State private var folderFilter: String = ""
    @State private var collectionFilter: String = ""

    // Publish service destinations
    @State private var hardDrivePublishPath: String? = nil
    @State private var showHardDriveSetupAlert: Bool = false
    @State private var showAdobeStockAlert: Bool = false
    @State private var showFlickrAlert: Bool = false
    @State private var showCreateCollectionAlert: Bool = false
    @State private var newCollectionName: String = ""

    // User added folders
    @State private var customFolderURLs: [URL] = []

    public init(
        renderedImage: NSImage?,
        originalImage: NSImage?,
        orientationRotation: Int = 0,
        zoomScale: Binding<CGFloat>,
        panOffset: Binding<CGSize>,
        filmstripItems: [FilmstripItem],
        selectedSidebarItem: Binding<SidebarItem?>,
        lastImportCount: Int = 1,
        favoriteItemsCount: Int = 0,
        onImport: @escaping () -> Void,
        onExport: @escaping () -> Void,
        onSelectFolder: ((URL) -> Void)? = nil,
        onAddFolder: (() -> Void)? = nil
    ) {
        self.renderedImage = renderedImage
        self.originalImage = originalImage
        self.orientationRotation = orientationRotation
        self._zoomScale = zoomScale
        self._panOffset = panOffset
        self.filmstripItems = filmstripItems
        self._selectedSidebarItem = selectedSidebarItem
        self.lastImportCount = lastImportCount
        self.favoriteItemsCount = favoriteItemsCount
        self.onImport = onImport
        self.onExport = onExport
        self.onSelectFolder = onSelectFolder
        self.onAddFolder = onAddFolder
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 1. Top Section: Navigator Mini-Map
            if isNavigatorExpanded {
                NavigatorView(
                    image: renderedImage ?? originalImage,
                    orientationRotation: orientationRotation,
                    zoomScale: $zoomScale,
                    panOffset: $panOffset
                )
            } else {
                collapsedSectionHeader("Navigator", isExpanded: $isNavigatorExpanded)
            }

            Divider()

            // 2. Scrollable Middle Panels (Catalog, Folders, Collections, Publish Services)
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    // MARK: - Section: Catalog
                    catalogSection

                    Divider()

                    // MARK: - Section: Folders
                    foldersSection

                    Divider()

                    // MARK: - Section: Collections
                    collectionsSection

                    Divider()

                    // MARK: - Section: Publish Services
                    publishServicesSection
                }
            }

            Divider()

            // 3. Pinned Bottom Actions: Import... & Export...
            HStack(spacing: 8) {
                Button(action: onImport) {
                    Text("Import...")
                        .font(.system(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Button(action: onExport) {
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
        .frame(width: 245)
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("Set Up Hard Drive Publish Service", isPresented: $showHardDriveSetupAlert) {
            Button("Choose Destination...") {
                chooseHardDriveDestination()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Select a local directory on your Macintosh HD to publish and export full-resolution photos directly.")
        }
        .alert("Adobe Stock Publishing", isPresented: $showAdobeStockAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Adobe Stock contributor publishing service is ready. Connect your Adobe Creative Cloud ID to submit photo assets directly.")
        }
        .alert("Flickr Publishing", isPresented: $showFlickrAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Flickr photo stream sync service. Authenticate your Flickr account to publish photo photostreams.")
        }
        .alert("New Collection", isPresented: $showCreateCollectionAlert) {
            TextField("Collection Name", text: $newCollectionName)
            Button("Create") {
                if !newCollectionName.isEmpty {
                    selectedSidebarItem = .collection(name: newCollectionName)
                    newCollectionName = ""
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a name for the new collection.")
        }
    }

    // MARK: - Catalog Section
    private var catalogSection: some View {
        VStack(spacing: 0) {
            sectionHeader(
                title: "Catalog",
                isExpanded: $isCatalogExpanded
            )

            if isCatalogExpanded {
                VStack(spacing: 1) {
                    sidebarRow(
                        title: "All Photographs",
                        count: filmstripItems.count,
                        isSelected: selectedSidebarItem == .allPhotos
                    ) {
                        selectedSidebarItem = .allPhotos
                    }

                    sidebarRow(
                        title: "All Synced Photographs",
                        count: 0,
                        isSelected: selectedSidebarItem == .allSynced
                    ) {
                        selectedSidebarItem = .allSynced
                    }

                    sidebarRow(
                        title: "Quick Collection +",
                        count: favoriteItemsCount,
                        isSelected: selectedSidebarItem == .quickCollection || selectedSidebarItem == .favorites
                    ) {
                        selectedSidebarItem = .quickCollection
                    }

                    sidebarRow(
                        title: "Previous Import",
                        count: max(1, lastImportCount),
                        isSelected: selectedSidebarItem == .previousImport || selectedSidebarItem == .recentlyAdded
                    ) {
                        selectedSidebarItem = .previousImport
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Folders Section
    private var foldersSection: some View {
        VStack(spacing: 0) {
            sectionHeader(
                title: "Folders",
                isExpanded: $isFoldersExpanded,
                plusAction: {
                    selectFolderFromDisk()
                }
            )

            if isFoldersExpanded {
                VStack(spacing: 4) {
                    // Filter Folders Bar
                    filterBar(placeholder: "Filter Folders", text: $folderFilter)

                    // Volume / Drive Header: 🟩 Macintosh HD  [20.5 / 494 GB] ▼
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            isDriveExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            // Green volume status square
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Color.green)
                                .frame(width: 8, height: 8)

                            Text("Macintosh HD")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.primary)

                            Spacer()

                            // Disk usage stats
                            Text(systemDiskUsageString)
                                .font(.system(size: 9, weight: .regular, design: .monospaced))
                                .foregroundStyle(.secondary)

                            Image(systemName: isDriveExpanded ? "arrowtriangle.down.fill" : "arrowtriangle.right.fill")
                                .font(.system(size: 7))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    // Subfolders under Macintosh HD
                    if isDriveExpanded {
                        VStack(spacing: 1) {
                            ForEach(displayFolders, id: \.path) { folder in
                                let isSelected = isFolderSelected(folder.name, path: folder.path)

                                Button {
                                    selectedSidebarItem = .folder(name: folder.name, path: folder.path)
                                    onSelectFolder?(folder.url)
                                } label: {
                                    HStack(spacing: 6) {
                                        // Indentation
                                        Spacer().frame(width: 14)

                                        Image(systemName: "folder")
                                            .font(.system(size: 10))
                                            .foregroundStyle(isSelected ? .white : .secondary)

                                        Text(folder.name)
                                            .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                                            .foregroundStyle(isSelected ? .white : .primary)
                                            .lineLimit(1)

                                        Spacer()

                                        Text("\(folder.count)")
                                            .font(.system(size: 10, weight: .regular))
                                            .foregroundStyle(isSelected ? .white : .secondary)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 3)
                                    .background(isSelected ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.8) : Color.clear)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.vertical, 3)
            }
        }
    }

    // MARK: - Collections Section
    private var collectionsSection: some View {
        VStack(spacing: 0) {
            sectionHeader(
                title: "Collections",
                isExpanded: $isCollectionsExpanded,
                plusAction: {
                    showCreateCollectionAlert = true
                }
            )

            if isCollectionsExpanded {
                VStack(spacing: 4) {
                    // Filter Collections Bar
                    filterBar(placeholder: "Filter Collections", text: $collectionFilter)

                    // Smart Collections Sub-folder
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            isSmartCollectionsExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isSmartCollectionsExpanded ? "arrowtriangle.down.fill" : "arrowtriangle.right.fill")
                                .font(.system(size: 7))
                                .foregroundStyle(.secondary)
                                .frame(width: 10)

                            Image(systemName: "folder.badge.gearshape")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)

                            Text("Smart Collections")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(.primary)

                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if isSmartCollectionsExpanded {
                        VStack(spacing: 1) {
                            smartCollectionRow(
                                title: "Five Stars",
                                systemIcon: "star.fill",
                                count: filmstripItems.filter { $0.rating == 5 }.count
                            )

                            smartCollectionRow(
                                title: "Past Month",
                                systemIcon: "calendar",
                                count: filmstripItems.count
                            )

                            smartCollectionRow(
                                title: "Recently Modified",
                                systemIcon: "slider.horizontal.3",
                                count: max(1, lastImportCount)
                            )
                        }
                    }
                }
                .padding(.vertical, 3)
            }
        }
    }

    // MARK: - Publish Services Section
    private var publishServicesSection: some View {
        VStack(spacing: 0) {
            sectionHeader(
                title: "Publish Services",
                isExpanded: $isPublishServicesExpanded,
                plusAction: {
                    showHardDriveSetupAlert = true
                }
            )

            if isPublishServicesExpanded {
                VStack(spacing: 2) {
                    // 1. Hard Drive
                    publishServiceRow(
                        title: "Hard Drive",
                        icon: AnyView(
                            Image(systemName: "externaldrive.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        ),
                        statusText: hardDrivePublishPath != nil ? "Configured" : "Set Up...",
                        isSelected: isPublishServiceSelected("Hard Drive")
                    ) {
                        if hardDrivePublishPath == nil {
                            showHardDriveSetupAlert = true
                        } else {
                            selectedSidebarItem = .publishService(name: "Hard Drive")
                        }
                    } onSetup: {
                        chooseHardDriveDestination()
                    }

                    // 2. Adobe Stock
                    publishServiceRow(
                        title: "Adobe Stock",
                        icon: AnyView(
                            ZStack {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
                                    .frame(width: 15, height: 14)
                                Text("St")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(Color.red)
                            }
                        ),
                        statusText: "Set Up...",
                        isSelected: isPublishServiceSelected("Adobe Stock")
                    ) {
                        showAdobeStockAlert = true
                    } onSetup: {
                        showAdobeStockAlert = true
                    }

                    // 3. Flickr
                    publishServiceRow(
                        title: "Flickr",
                        icon: AnyView(
                            HStack(spacing: 2) {
                                Circle().fill(Color.blue).frame(width: 5, height: 5)
                                Circle().fill(Color.pink).frame(width: 5, height: 5)
                            }
                        ),
                        statusText: "Set Up...",
                        isSelected: isPublishServiceSelected("Flickr")
                    ) {
                        showFlickrAlert = true
                    } onSetup: {
                        showFlickrAlert = true
                    }

                    // 4. Find More Services Online...
                    Button {
                        if let url = URL(string: "https://exchange.adobe.com/creativecloud.html") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Text("Find More Services Online...")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.top, 4)
                    .padding(.bottom, 6)
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Reusable Row Components

    private func sidebarRow(
        title: String,
        count: Int,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)

                Spacer()

                Text("\(count)")
                    .font(.system(size: 10, weight: isSelected ? .bold : .regular))
                    .foregroundStyle(isSelected ? .white : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(isSelected ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.85) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func smartCollectionRow(
        title: String,
        systemIcon: String,
        count: Int
    ) -> some View {
        let isSelected = selectedSidebarItem == .collection(name: title)

        return Button {
            selectedSidebarItem = .collection(name: title)
        } label: {
            HStack(spacing: 6) {
                Spacer().frame(width: 14)

                Image(systemName: systemIcon)
                    .font(.system(size: 9))
                    .foregroundStyle(isSelected ? .white : .secondary)

                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? .white : .primary)

                Spacer()

                Text("\(count)")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(isSelected ? .white : .secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(isSelected ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.8) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func publishServiceRow(
        title: String,
        icon: AnyView,
        statusText: String,
        isSelected: Bool,
        action: @escaping () -> Void,
        onSetup: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 6) {
            Button(action: action) {
                HStack(spacing: 6) {
                    icon.frame(width: 16)

                    Text(title)
                        .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .lineLimit(1)

                    Spacer()
                }
            }
            .buttonStyle(.plain)

            Button(action: onSetup) {
                Text(statusText)
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 2.5, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(isSelected ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.8) : Color.clear)
    }

    // MARK: - Section Header Component
    private func sectionHeader(
        title: String,
        isExpanded: Binding<Bool>,
        plusAction: (() -> Void)? = nil
    ) -> some View {
        HStack(spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isExpanded.wrappedValue.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)

                    Text(title)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.primary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            if let onPlus = plusAction {
                Button(action: onPlus) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .help("Add \(title)")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func collapsedSectionHeader(_ title: String, isExpanded: Binding<Bool>) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                isExpanded.wrappedValue.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Search/Filter Bar Component
    private func filterBar(placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)

            TextField(placeholder, text: text)
                .font(.system(size: 10))
                .textFieldStyle(.plain)

            if !text.wrappedValue.isEmpty {
                Button {
                    text.wrappedValue = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.black.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        .padding(.horizontal, 8)
    }

    // MARK: - Helper Computations

    private var systemDiskUsageString: String {
        let fileURL = URL(fileURLWithPath: "/")
        do {
            let values = try fileURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
            if let totalBytes = values.volumeTotalCapacity,
               let freeBytes = values.volumeAvailableCapacityForImportantUsage {
                let totalGB = Double(totalBytes) / 1_000_000_000.0
                let freeGB = Double(freeBytes) / 1_000_000_000.0
                return String(format: "%.1f / %.0f GB", freeGB, totalGB)
            }
        } catch {}
        return "20.5 / 494 GB"
    }

    private struct FolderEntry: Identifiable {
        let name: String
        let path: String
        let url: URL
        let count: Int

        var id: String { path }
    }

    private var displayFolders: [FolderEntry] {
        var folders: [FolderEntry] = []
        var countsByFolder: [String: (url: URL, count: Int)] = [:]

        for item in filmstripItems {
            if let url = item.url {
                let dir = url.deletingLastPathComponent()
                let name = dir.lastPathComponent
                let existing = countsByFolder[name]?.count ?? 0
                countsByFolder[name] = (dir, existing + 1)
            }
        }

        for customURL in customFolderURLs {
            let name = customURL.lastPathComponent
            if countsByFolder[name] == nil {
                countsByFolder[name] = (customURL, 0)
            }
        }

        if countsByFolder.isEmpty {
            let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: "/Users/\(NSUserName())/Desktop")
            folders.append(FolderEntry(name: "Desktop", path: desktopURL.path, url: desktopURL, count: max(1, filmstripItems.count)))
        } else {
            for (name, pair) in countsByFolder {
                folders.append(FolderEntry(name: name, path: pair.url.path, url: pair.url, count: pair.count))
            }
        }

        if !folderFilter.isEmpty {
            return folders.filter { $0.name.localizedCaseInsensitiveContains(folderFilter) }
        }
        return folders.sorted { $0.count > $1.count }
    }

    private func isFolderSelected(_ name: String, path: String) -> Bool {
        if case .folder(let selName, let selPath) = selectedSidebarItem {
            return selName == name || selPath == path
        }
        return false
    }

    private func isPublishServiceSelected(_ name: String) -> Bool {
        if case .publishService(let selName) = selectedSidebarItem {
            return selName == name
        }
        return false
    }

    private func selectFolderFromDisk() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Folder"
        panel.message = "Choose a folder to add to EasyLiteRoom Folders"

        if panel.runModal() == .OK, let selectedURL = panel.url {
            if !customFolderURLs.contains(selectedURL) {
                customFolderURLs.append(selectedURL)
            }
            selectedSidebarItem = .folder(name: selectedURL.lastPathComponent, path: selectedURL.path)
            onSelectFolder?(selectedURL)
        }
    }

    private func chooseHardDriveDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Set Destination"
        panel.message = "Choose a folder on your Hard Drive to publish photos"

        if panel.runModal() == .OK, let selectedURL = panel.url {
            hardDrivePublishPath = selectedURL.path
            selectedSidebarItem = .publishService(name: "Hard Drive")
            onSelectFolder?(selectedURL)
        }
    }
}
