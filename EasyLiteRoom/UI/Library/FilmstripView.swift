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

    public init(id: UUID = UUID(), title: String, image: NSImage?, isRAW: Bool = true, rating: Int = 0, url: URL? = nil) {
        self.id = id
        self.title = title
        self.image = image
        self.isRAW = isRAW
        self.rating = rating
        self.url = url
    }
}

public struct FilmstripView: View {
    let items: [FilmstripItem]
    @Binding var selectedId: UUID?
    var onSelect: (FilmstripItem) -> Void

    public init(
        items: [FilmstripItem],
        selectedId: Binding<UUID?>,
        onSelect: @escaping (FilmstripItem) -> Void
    ) {
        self.items = items
        self._selectedId = selectedId
        self.onSelect = onSelect
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
