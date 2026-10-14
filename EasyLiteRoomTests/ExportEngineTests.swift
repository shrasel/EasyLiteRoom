//
//  ExportEngineTests.swift
//  EasyLiteRoomTests
//
//  Created by Shahjahan Rasel on 10/13/26.
//

import Testing
import Metal
import ImageIO
@testable import EasyLiteRoom

struct ExportEngineTests {

    @Test func testJPEGExport() async throws {
        let width = 128
        let height = 96
        guard let tex = TextureGenerator.makeTestChartTexture(width: width, height: height) else {
            Issue.record("Failed to create test texture.")
            return
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_export_\(UUID().uuidString).jpg")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        var config = ExportConfiguration()
        config.format = .jpeg
        config.jpegQuality = 90.0
        config.colorSpace = .sRGB

        try await ImageExporter.export(
            input: tex,
            parameters: .default,
            configuration: config,
            destinationURL: tempURL
        )

        #expect(FileManager.default.fileExists(atPath: tempURL.path))

        // Read back and verify image dimensions
        guard let source = CGImageSourceCreateWithURL(tempURL as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            Issue.record("Could not read exported JPEG image properties.")
            return
        }

        let pixelWidth = properties[kCGImagePropertyPixelWidth] as? Int
        let pixelHeight = properties[kCGImagePropertyPixelHeight] as? Int

        #expect(pixelWidth == width)
        #expect(pixelHeight == height)
    }

    @Test func testTIFF16BitExport() async throws {
        let width = 64
        let height = 64
        guard let tex = TextureGenerator.makeTestChartTexture(width: width, height: height) else {
            Issue.record("Failed to create test texture.")
            return
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_export_\(UUID().uuidString).tiff")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        var config = ExportConfiguration()
        config.format = .tiff
        config.colorSpace = .displayP3

        try await ImageExporter.export(
            input: tex,
            parameters: .default,
            configuration: config,
            destinationURL: tempURL
        )

        #expect(FileManager.default.fileExists(atPath: tempURL.path))

        guard let source = CGImageSourceCreateWithURL(tempURL as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            Issue.record("Could not read exported TIFF image properties.")
            return
        }

        let pixelWidth = properties[kCGImagePropertyPixelWidth] as? Int
        let pixelHeight = properties[kCGImagePropertyPixelHeight] as? Int

        #expect(pixelWidth == width)
        #expect(pixelHeight == height)
    }
}
