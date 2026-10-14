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
    var onOpenPhoto: (FilmstripItem) -> Void
    var onImport: () -> Void

    @State private var filterQuery: String = ""
    @State private var minRating: Int = 0

    public init(
        items: [FilmstripItem],
        selectedId: Binding<UUID?>,
        onOpenPhoto: @escaping (FilmstripItem) -> Void,
        onImport: @escaping () -> Void
    ) {
        self.items = items
        self._selectedId = selectedId
        self.onOpenPhoto = onOpenPhoto
        self.onImport = onImport
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
                .frame(maxWidth: 260)

                // Rating filter picker
                Picker("Min Rating", selection: $minRating) {
                    Text("All Stars").tag(0)
                    Text("★ 1+").tag(1)
                    Text("★ 3+").tag(3)
                    Text("★ 5").tag(5)
                }
                .pickerStyle(.menu)
                .frame(width: 110)

                Spacer()

                Text("\(filteredItems.count) of \(items.count) photos")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

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
                            Text("Drag files or click to browse")
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

fileprivate struct LibraryPhotoCard: View {
    let item: FilmstripItem
    let isSelected: Bool
    var onSelect: () -> Void
    var onDoubleTap: () -> Void

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

                // RAW Badge
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

                // Quick Develop Action Button on hover
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

            // Details
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= item.rating ? "star.fill" : "star")
                            .font(.system(size: 9))
                            .foregroundStyle(star <= item.rating ? .yellow : .secondary.opacity(0.3))
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
    }
}
