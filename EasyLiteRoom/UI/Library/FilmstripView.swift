//
//  FilmstripView.swift
//  EasyLiteRoom
//
//  Created by Shahjahan Rasel on 10/13/26.
//  Horizontal bottom thumbnail filmstrip for rapid photo selection.
//

import SwiftUI
import AppKit

public struct FilmstripItem: Identifiable, @unchecked Sendable, Equatable {
    public let id: UUID
    public let title: String
    public let image: NSImage?
    public let isRAW: Bool
    public var rating: Int
    public let url: URL?
    public var dateAdded: Date
    public var isFavorite: Bool

    public init(
        id: UUID = UUID(),
        title: String,
        image: NSImage?,
        isRAW: Bool = true,
        rating: Int = 0,
        url: URL? = nil,
        dateAdded: Date = Date(),
        isFavorite: Bool = false
    ) {
        self.id = id
        self.title = title
        self.image = image
        self.isRAW = isRAW
        self.rating = rating
        self.url = url
        self.dateAdded = dateAdded
        self.isFavorite = isFavorite || (rating >= 4)
    }

    public static func == (lhs: FilmstripItem, rhs: FilmstripItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.isRAW == rhs.isRAW &&
        lhs.rating == rhs.rating &&
        lhs.url == rhs.url &&
        lhs.isFavorite == rhs.isFavorite
    }
}

public struct FilmstripView: View {
    let items: [FilmstripItem]
    @Binding var selectedId: UUID?
    var onSelect: (FilmstripItem) -> Void
    var onToggleFavorite: ((FilmstripItem) -> Void)? = nil
    var onSetRating: ((FilmstripItem, Int) -> Void)? = nil

    public init(
        items: [FilmstripItem],
        selectedId: Binding<UUID?>,
        onSelect: @escaping (FilmstripItem) -> Void,
        onToggleFavorite: ((FilmstripItem) -> Void)? = nil,
        onSetRating: ((FilmstripItem, Int) -> Void)? = nil
    ) {
        self.items = items
        self._selectedId = selectedId
        self.onSelect = onSelect
        self.onToggleFavorite = onToggleFavorite
        self.onSetRating = onSetRating
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 8) {
                ForEach(items) { item in
                    let isSelected = selectedId == item.id

                    VStack(spacing: 4) {
                        ZStack(alignment: .bottomLeading) {
                            if let img = item.image {
                                Image(nsImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 55)
                                    .clipped()
                            } else {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 80, height: 55)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .foregroundStyle(.secondary)
                                    )
                            }

                            // Favorite Indicator badge
                            if item.isFavorite {
                                VStack {
                                    HStack {
                                        Spacer()
                                        Image(systemName: "heart.fill")
                                            .font(.system(size: 8))
                                            .foregroundStyle(.red)
                                            .padding(3)
                                            .background(.ultraThinMaterial)
                                            .clipShape(Circle())
                                    }
                                    Spacer()
                                }
                                .padding(2)
                            }

                            // RAW badge
                            if item.isRAW {
                                Text("RAW")
                                    .font(.system(size: 8, weight: .bold))
                                    .padding(.horizontal, 3)
                                    .padding(.vertical, 1)
                                    .background(Color.black.opacity(0.65))
                                    .foregroundStyle(.white)
                                    .cornerRadius(2)
                                    .padding(3)
                            }
                        }
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(isSelected ? Color.accentColor : Color.white.opacity(0.15), lineWidth: isSelected ? 2 : 0.5)
                        )
                        .shadow(color: isSelected ? Color.accentColor.opacity(0.4) : Color.clear, radius: 4)

                        Text(item.title)
                            .font(.system(size: 9, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? .primary : .secondary)
                            .lineLimit(1)
                            .frame(width: 80)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedId = item.id
                        onSelect(item)
                    }
                    .contextMenu {
                        Button {
                            selectedId = item.id
                            onSelect(item)
                        } label: {
                            Label("Develop Photo", systemImage: "slider.horizontal.3")
                        }

                        Button {
                            onToggleFavorite?(item)
                        } label: {
                            Label(item.isFavorite ? "Remove Favorite" : "Mark as Favorite", systemImage: item.isFavorite ? "heart.slash" : "heart.fill")
                        }

                        Menu("Set Rating") {
                            ForEach(1...5, id: \.self) { star in
                                Button("\(star) Stars") {
                                    onSetRating?(item, star)
                                }
                            }
                            Divider()
                            Button("Clear Rating") {
                                onSetRating?(item, 0)
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
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(height: 80)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(Color.white.opacity(0.1)),
            alignment: .top
        )
    }
}
