//
//  LibraryInspectorView.swift
//  EasyLiteRoom
//
//  Created by Shahjahan Rasel on 10/14/26.
//  Lightroom Classic style right-panel inspector for Library mode: Quick Develop, Metadata & Culling.
//

import SwiftUI
import AppKit

public struct LibraryInspectorView: View {
    @Binding var parameters: AdjustmentParameters
    let metadata: EXIFMetadata?
    let currentURL: URL?
    let selectedItem: FilmstripItem?
    var onSetRating: ((Int) -> Void)? = nil
    var onToggleFavorite: (() -> Void)? = nil
    var onExport: () -> Void

    @State private var isQuickDevelopExpanded: Bool = true
    @State private var isMetadataExpanded: Bool = true

    public init(
        parameters: Binding<AdjustmentParameters>,
        metadata: EXIFMetadata?,
        currentURL: URL?,
        selectedItem: FilmstripItem?,
        onSetRating: ((Int) -> Void)? = nil,
        onToggleFavorite: (() -> Void)? = nil,
        onExport: @escaping () -> Void
    ) {
        self._parameters = parameters
        self.metadata = metadata
        self.currentURL = currentURL
        self.selectedItem = selectedItem
        self.onSetRating = onSetRating
        self.onToggleFavorite = onToggleFavorite
        self.onExport = onExport
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {

                // MARK: - Quick Develop Panel
                DisclosureGroup(
                    isExpanded: $isQuickDevelopExpanded,
                    content: {
                        VStack(spacing: 10) {
                            // White Balance Presets
                            HStack {
                                Text("White Balance")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 85, alignment: .leading)

                                Menu {
                                    Button("As Shot") {
                                        parameters.temperature = 5500
                                        parameters.tint = 0
                                    }
                                    Button("Daylight (5500K)") {
                                        parameters.temperature = 5500
                                        parameters.tint = 5
                                    }
                                    Button("Cloudy (6500K)") {
                                        parameters.temperature = 6500
                                        parameters.tint = 8
                                    }
                                    Button("Tungsten (3200K)") {
                                        parameters.temperature = 3200
                                        parameters.tint = 0
                                    }
                                    Button("Fluorescent (4000K)") {
                                        parameters.temperature = 4000
                                        parameters.tint = -10
                                    }
                                } label: {
                                    Text("Custom")
                                        .font(.system(size: 11))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .menuStyle(.borderlessButton)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            }

                            // Quick Exposure Step Buttons
                            HStack {
                                Text("Exposure")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 85, alignment: .leading)

                                HStack(spacing: 3) {
                                    quickStepButton("-1.0") { parameters.exposure -= 1.0 }
                                    quickStepButton("-0.3") { parameters.exposure -= 0.33 }
                                    quickStepButton("+0.3") { parameters.exposure += 0.33 }
                                    quickStepButton("+1.0") { parameters.exposure += 1.0 }
                                }
                            }

                            // Quick Contrast
                            HStack {
                                Text("Contrast")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 85, alignment: .leading)

                                HStack(spacing: 4) {
                                    quickStepButton("-5") { parameters.contrast = max(-100, parameters.contrast - 5) }
                                    quickStepButton("+5") { parameters.contrast = min(100, parameters.contrast + 5) }
                                }
                            }

                            // Quick Vibrance
                            HStack {
                                Text("Vibrance")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 85, alignment: .leading)

                                HStack(spacing: 4) {
                                    quickStepButton("-5") { parameters.vibrance = max(-100, parameters.vibrance - 5) }
                                    quickStepButton("+5") { parameters.vibrance = min(100, parameters.vibrance + 5) }
                                }
                            }

                            Button("Reset Tone") {
                                parameters.exposure = 0.0
                                parameters.contrast = 0.0
                                parameters.highlights = 0.0
                                parameters.shadows = 0.0
                                parameters.whites = 0.0
                                parameters.blacks = 0.0
                                parameters.vibrance = 0.0
                                parameters.saturation = 0.0
                            }
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                        }
                        .padding(.top, 6)
                    },
                    label: {
                        HStack {
                            Text("Quick Develop")
                                .font(.system(size: 12, weight: .bold))
                            Spacer()
                        }
                    }
                )
                .padding(.horizontal, 12)

                Divider()

                // MARK: - Metadata Panel (Lightroom Classic Layout)
                DisclosureGroup(
                    isExpanded: $isMetadataExpanded,
                    content: {
                        VStack(spacing: 7) {
                            metadataRow("File Name", currentURL?.lastPathComponent ?? (selectedItem?.title ?? "None"))
                            metadataRow("Folder", currentURL?.deletingLastPathComponent().lastPathComponent ?? "Catalog")
                            metadataRow("Capture Date", formattedCaptureDate)
                            metadataRow("File Dimensions", dimensionsString)
                            metadataRow("Current Dimensions", dimensionsString)

                            if let meta = metadata, !meta.cameraModel.isEmpty {
                                metadataRow("Camera", "\(meta.cameraMake) \(meta.cameraModel)".trimmingCharacters(in: .whitespaces))
                            }
                            if let meta = metadata, !meta.lensModel.isEmpty {
                                metadataRow("Lens", meta.lensModel)
                            }
                            if let meta = metadata, meta.iso > 0 {
                                metadataRow("Exposure", "\(meta.shutterSpeed) • \(String(format: "f/%.1f", meta.aperture)) • ISO \(meta.iso)")
                            }

                            // Rating in Metadata
                            HStack(alignment: .top) {
                                Text("Rating")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 110, alignment: .leading)

                                HStack(spacing: 2) {
                                    ForEach(1...5, id: \.self) { star in
                                        Image(systemName: star <= (selectedItem?.rating ?? 0) ? "star.fill" : "star")
                                            .font(.system(size: 11))
                                            .foregroundStyle(star <= (selectedItem?.rating ?? 0) ? .yellow : .secondary.opacity(0.4))
                                            .onTapGesture {
                                                if selectedItem?.rating == star {
                                                    onSetRating?(0)
                                                } else {
                                                    onSetRating?(star)
                                                }
                                            }
                                    }
                                }
                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                        .padding(.top, 6)
                    },
                    label: {
                        HStack {
                            Text("Metadata")
                                .font(.system(size: 12, weight: .bold))
                            Spacer()
                        }
                    }
                )
                .padding(.horizontal, 12)

                Spacer(minLength: 20)

                // Bottom Export Button
                VStack(spacing: 8) {
                    Button {
                        onExport()
                    } label: {
                        Label("Export Photo...", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .padding(.vertical, 10)
        }
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.95))
    }

    private var formattedCaptureDate: String {
        guard let meta = metadata else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: meta.captureDate)
    }

    private var dimensionsString: String {
        guard let meta = metadata, meta.width > 0, meta.height > 0 else {
            return "1024 x 768"
        }
        return "\(meta.width) x \(meta.height)"
    }

    private func quickStepButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func metadataRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)

            Text(value)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 1)
    }
}
