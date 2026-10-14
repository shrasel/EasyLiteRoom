//
//  ExportSheetView.swift
//  EasyLiteRoom
//
//  Created by Shahjahan Rasel on 10/13/26.
//  Modern macOS modal export sheet with format, color space, and quality controls.
//

import SwiftUI
import Metal
import AppKit

public struct ExportSheetView: View {
    let inputTexture: MTLTexture?
    let parameters: AdjustmentParameters
    @Binding var isPresented: Bool

    @State private var configuration = ExportConfiguration()
    @State private var isExporting: Bool = false
    @State private var errorMessage: String? = nil
    @State private var exportSuccess: Bool = false

    public init(
        inputTexture: MTLTexture?,
        parameters: AdjustmentParameters,
        isPresented: Binding<Bool>
    ) {
        self.inputTexture = inputTexture
        self.parameters = parameters
        self._isPresented = isPresented
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Label("Export Photo", systemImage: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
            }

            Divider()

            // Format & Quality Box
            GroupBox(label: Text("File Settings").font(.system(size: 12, weight: .semibold))) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Format")
                            .frame(width: 80, alignment: .leading)
                            .foregroundStyle(.secondary)
                        Picker("", selection: $configuration.format) {
                            ForEach(ExportFormat.allCases) { fmt in
                                Text(fmt.rawValue).tag(fmt)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    if configuration.format == .jpeg {
                        HStack {
                            Text("Quality")
                                .frame(width: 80, alignment: .leading)
                                .foregroundStyle(.secondary)
                            Slider(value: $configuration.jpegQuality, in: 10...100, step: 1)
                            Text(String(format: "%.0f%%", configuration.jpegQuality))
                                .font(.system(size: 11, design: .monospaced))
                                .frame(width: 40)
                        }
                    }

                    HStack {
                        Text("Color Space")
                            .frame(width: 80, alignment: .leading)
                            .foregroundStyle(.secondary)
                        Picker("", selection: $configuration.colorSpace) {
                            Text("sRGB (Standard Web)").tag(WorkingColorSpace.sRGB)
                            Text("Display P3 (Wide Gamut)").tag(WorkingColorSpace.displayP3)
                            Text("ProPhoto RGB (Archival)").tag(WorkingColorSpace.proPhotoRGB)
                        }
                        .pickerStyle(.menu)
                    }
                }
                .padding(.top, 4)
            }

            // Image Dimensions Info
            if let tex = inputTexture {
                HStack {
                    Text("Resolution:")
                        .foregroundStyle(.secondary)
                    Text("\(tex.width) × \(tex.height) px (Full Sensor Resolution)")
                        .fontWeight(.medium)
                    Spacer()
                }
                .font(.system(size: 11))
                .padding(.horizontal, 4)
            }

            if let err = errorMessage {
                Text(err)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }

            Spacer()

            // Footer Buttons
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                if isExporting {
                    ProgressView()
                        .controlSize(.small)
                }

                Button("Export...") {
                    triggerSavePanel()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(isExporting || inputTexture == nil)
            }
        }
        .padding(20)
        .frame(width: 440, height: 320)
    }

    private func triggerSavePanel() {
        guard let tex = inputTexture else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [configuration.format.utType]
        panel.nameFieldStringValue = "EasyLiteRoom_Export.\(configuration.format.fileExtension)"
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let destinationURL = panel.url {
            isExporting = true
            errorMessage = nil

            Task {
                do {
                    try await ImageExporter.export(
                        input: tex,
                        parameters: parameters,
                        configuration: configuration,
                        destinationURL: destinationURL
                    )
                    await MainActor.run {
                        isExporting = false
                        isPresented = false
                    }
                } catch {
                    await MainActor.run {
                        isExporting = false
                        errorMessage = "Export failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
}
