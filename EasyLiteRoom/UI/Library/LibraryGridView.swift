//
//  LibraryGridView.swift
//  EasyLiteRoom
//
//  Created by Shahjahan Rasel on 10/13/26.
//  Full responsive catalog grid view for the Library workspace mode.
//

import SwiftUI
import AppKit

public struct LibraryGridView: View {
    let items: [FilmstripItem]
    @Binding var selectedId: UUID?
    var collectionTitle: String = "All Photos"
    var onOpenPhoto: (FilmstripItem) -> Void
    var onImport: () -> Void
    var onToggleFavorite: ((FilmstripItem) -> Void)? = nil
    var onSetRating: ((FilmstripItem, Int) -> Void)? = nil

    @State private var filterQuery: String = ""
    @State private var minRating: Int = 0

    public init(
        items: [FilmstripItem],
        selectedId: Binding<UUID?>,
        collectionTitle: String = "All Photos",
        onOpenPhoto: @escaping (FilmstripItem) -> Void,
        onImport: @escaping () -> Void,
        onToggleFavorite: ((FilmstripItem) -> Void)? = nil,
        onSetRating: ((FilmstripItem, Int) -> Void)? = nil
    ) {
        self.items = items
        self._selectedId = selectedId
        self.collectionTitle = collectionTitle
        self.onOpenPhoto = onOpenPhoto
        self.onImport = onImport
        self.onToggleFavorite = onToggleFavorite
        self.onSetRating = onSetRating
    }

    private var filteredItems: [FilmstripItem] {
        items.filter { item in
            let matchesQuery = filterQuery.isEmpty || item.title.localizedCaseInsensitiveContains(filterQuery)
            let matchesRating = item.rating >= minRating
            return matchesQuery && matchesRating
        }
    }

    private let columns = [
        GridItem(.adaptive(minimum: 180, maximum: 240), spacing: 18)
    ]

    public var body: some View {
        VStack(spacing: 0) {
            // Library Header Bar
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(collectionTitle)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("\(filteredItems.count) of \(items.count) photos")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search catalog...", text: $filterQuery)
                        .textFieldStyle(.plain)
                    if !filterQuery.isEmpty {
                        Button {
                            filterQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .frame(maxWidth: 240)

                // Rating filter picker
                Picker("Min Rating", selection: $minRating) {
                    Text("All Stars").tag(0)
                    Text("★ 1+").tag(1)
                    Text("★ 3+").tag(3)
                    Text("★ 5").tag(5)
                }
                .pickerStyle(.menu)
                .frame(width: 110)

                Button {
                    onImport()
                } label: {
                    Label("Import Photos...", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Photo Grid Content
            if filteredItems.isEmpty {
                VStack(spacing: 14) {
                    Spacer()
                    Image(systemName: collectionTitle.contains("Favorite") ? "heart.slash" : "photo.on.rectangle.angled")
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(.secondary)

                    Text(collectionTitle.contains("Favorite") ? "No Favorite Photos Yet" : "No Photos in this Collection")
                        .font(.system(size: 15, weight: .semibold))

                    Text(collectionTitle.contains("Favorite") ? "Click the heart icon on any photo in your catalog to add it to Favorites." : "Import RAW or JPEG photos to start developing.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)

                    Button {
                        onImport()
                    } label: {
                        Label("Import RAW / Photo", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .padding(.top, 6)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .underPageBackgroundColor))
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 18) {
                        // Import Tile Card
                        Button {
                            onImport()
                        } label: {
                            VStack(spacing: 10) {
                                Image(systemName: "plus.rectangle.on.rectangle")
                                    .font(.system(size: 32, weight: .light))
                                    .foregroundStyle(.secondary)
                                Text("Import RAW / Photo")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.primary)
                                Text("Click to browse files")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 160)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                            )
                        }
                        .buttonStyle(.plain)

                        // Photo Cards
                        ForEach(filteredItems) { item in
                            LibraryPhotoCard(
                                item: item,
                                isSelected: selectedId == item.id,
                                onSelect: {
                                    selectedId = item.id
                                },
                                onDoubleTap: {
                                    selectedId = item.id
                                    onOpenPhoto(item)
                                },
                                onToggleFavorite: {
                                    onToggleFavorite?(item)
                                },
                                onSetRating: { rating in
                                    onSetRating?(item, rating)
                                }
                            )
                        }
                    }
                    .padding(20)
                }
                .background(Color(nsColor: .underPageBackgroundColor))
            }
        }
    }
}

fileprivate struct LibraryPhotoCard: View {
    let item: FilmstripItem
    let isSelected: Bool
    var onSelect: () -> Void
    var onDoubleTap: () -> Void
    var onToggleFavorite: () -> Void
    var onSetRating: (Int) -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                // Image Thumbnail
                if let image = item.image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 130)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    Rectangle()
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .frame(height: 130)
                        .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                // RAW Badge (Top Left)
                if item.isRAW {
                    Text("RAW")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.75))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .padding(6)
                }

                // Favorite Heart Button (Top Right)
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            onToggleFavorite()
                        } label: {
                            Image(systemName: item.isFavorite ? "heart.fill" : "heart")
                                .font(.system(size: 11))
                                .foregroundStyle(item.isFavorite ? .red : .white)
                                .padding(5)
                                .background(.black.opacity(item.isFavorite ? 0.7 : (isHovered ? 0.5 : 0.001)))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(6)
                    }
                    Spacer()
                }

                // Quick Develop Action Button on hover (Bottom Right)
                if isHovered {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button {
                                onDoubleTap()
                            } label: {
                                Label("Develop", systemImage: "slider.horizontal.3")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.mini)
                            .padding(6)
                        }
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : (isHovered ? Color.secondary.opacity(0.4) : Color.clear), lineWidth: 2)
            )

            // Details & Interactive Rating
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    ForEach(1...5, id: \.self) { star in
                        Button {
                            if item.rating == star {
                                onSetRating(0) // Clear rating
                            } else {
                                onSetRating(star)
                            }
                        } label: {
                            Image(systemName: star <= item.rating ? "star.fill" : "star")
                                .font(.system(size: 9))
                                .foregroundStyle(star <= item.rating ? .yellow : .secondary.opacity(0.35))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(isSelected ? 0.8 : (isHovered ? 0.5 : 0.2)))
        )
        .onHover { isHovered = $0 }
        .onTapGesture { onSelect() }
        .simultaneousGesture(
            TapGesture(count: 2).onEnded { onDoubleTap() }
        )
        .contextMenu {
            Button {
                onDoubleTap()
            } label: {
                Label("Open in Develop", systemImage: "slider.horizontal.3")
            }

            Button {
                onToggleFavorite()
            } label: {
                Label(item.isFavorite ? "Remove from Favorites" : "Mark as Favorite", systemImage: item.isFavorite ? "heart.slash" : "heart.fill")
            }

            Menu("Set Rating") {
                ForEach(1...5, id: \.self) { star in
                    Button("\(star) Stars") {
                        onSetRating(star)
                    }
                }
                Divider()
                Button("Clear Rating") {
                    onSetRating(0)
                }
            }

            if let url = item.url {
                Divider()
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            }
        }
    }
}
