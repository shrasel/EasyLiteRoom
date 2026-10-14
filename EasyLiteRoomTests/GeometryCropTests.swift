//
//  GeometryCropTests.swift
//  EasyLiteRoomTests
//
//  Created by Shahjahan Rasel on 10/13/26.
//  Unit tests for non-destructive crop, straighten, resize calculations, and XMP round-trip.
//

import Testing
import Foundation
import CoreGraphics
@testable import EasyLiteRoom

struct GeometryCropTests {

    @Test func testGeometryDefaultsAndReset() {
        var geo = GeometryParameters()
        #expect(!geo.isCropped)
        #expect(geo.cropX == 0.0)
        #expect(geo.cropY == 0.0)
        #expect(geo.cropWidth == 1.0)
        #expect(geo.cropHeight == 1.0)
        #expect(geo.rotationAngle == 0.0)
        #expect(!geo.resizeEnabled)
        #expect(geo.scalePercent == 100.0)

        // Modify geometry
        geo.cropX = 0.2
        geo.cropY = 0.1
        geo.cropWidth = 0.6
        geo.cropHeight = 0.8
        geo.rotationAngle = 3.5
        geo.flipHorizontal = true
        #expect(geo.isCropped)

        geo.resetCrop()
        #expect(!geo.isCropped)
        #expect(geo.cropX == 0.0)
        #expect(geo.cropWidth == 1.0)
        #expect(geo.rotationAngle == 0.0)
        #expect(!geo.flipHorizontal)
    }

    @Test func testCropAspectRatioPresets() {
        let square = CropAspectRatio.square1x1.ratio(originalWidth: 4000, originalHeight: 3000)
        #expect(square == 1.0)

        let wide16x9 = CropAspectRatio.ratio16x9.ratio(originalWidth: 4000, originalHeight: 3000)
        #expect(wide16x9 != nil)
        #expect(abs((wide16x9 ?? 0) - (16.0 / 9.0)) < 1e-4)

        let freeform = CropAspectRatio.freeform.ratio(originalWidth: 4000, originalHeight: 3000)
        #expect(freeform == nil)

        let original = CropAspectRatio.original.ratio(originalWidth: 4000, originalHeight: 2000)
        #expect(original == 2.0)
    }

    @Test func testSetAspectRatioCentering() {
        var geo = GeometryParameters()
        // Start full frame for 4000x3000 (4:3 aspect)
        geo.setAspectRatio(.square1x1, imageWidth: 4000, imageHeight: 3000)

        // Square in a 4:3 photo: normalized width = 3000/4000 = 0.75, height = 1.0
        #expect(abs(geo.cropHeight - 1.0) < 1e-3)
        #expect(abs(geo.cropWidth - 0.75) < 1e-3)
        // Centered horizontally: cropX = (1.0 - 0.75) / 2 = 0.125
        #expect(abs(geo.cropX - 0.125) < 1e-3)
        #expect(abs(geo.cropY - 0.0) < 1e-3)
        #expect(geo.isCropped)
    }

    @Test func testComputedOutputDimensionsWithoutResize() {
        var geo = GeometryParameters()
        geo.cropX = 0.0
        geo.cropY = 0.0
        geo.cropWidth = 0.5
        geo.cropHeight = 0.5

        let dims = geo.computedOutputDimensions(sourceWidth: 4000, sourceHeight: 3000)
        #expect(dims.width == 2000)
        #expect(dims.height == 1500)

        // With scalePercent = 50%
        geo.scalePercent = 50.0
        let scaledDims = geo.computedOutputDimensions(sourceWidth: 4000, sourceHeight: 3000)
        #expect(scaledDims.width == 1000)
        #expect(scaledDims.height == 750)
    }

    @Test func testComputedOutputDimensionsWithResize() {
        var geo = GeometryParameters()
        geo.resizeEnabled = true
        geo.maintainAspectRatio = true
        geo.targetWidth = 1920
        geo.targetHeight = 1080

        // Source 4000x3000 (4:3) fitting inside 1920x1080 (16:9)
        // Aspect ratio locked should fit: width 1440, height 1080
        let dims = geo.computedOutputDimensions(sourceWidth: 4000, sourceHeight: 3000)
        #expect(dims.height == 1080)
        #expect(dims.width == 1440)

        // Without maintainAspectRatio, returns exact target dimensions
        geo.maintainAspectRatio = false
        let freeDims = geo.computedOutputDimensions(sourceWidth: 4000, sourceHeight: 3000)
        #expect(freeDims.width == 1920)
        #expect(freeDims.height == 1080)
    }

    @Test func testXMPCropRoundTrip() {
        var params = AdjustmentParameters()
        params.geometry.cropX = 0.15
        params.geometry.cropY = 0.20
        params.geometry.cropWidth = 0.70
        params.geometry.cropHeight = 0.60
        params.geometry.rotationAngle = -2.5

        #expect(params.geometry.isCropped)

        let xml = XMPCodec.exportToXMP(parameters: params)
        #expect(xml.contains("crs:HasCrop=\"True\""))
        #expect(xml.contains("crs:CropLeft=\"0.15\""))
        #expect(xml.contains("crs:CropTop=\"0.2\""))
        #expect(xml.contains("crs:CropAngle=\"-2.5\""))

        let parsed = XMPCodec.parseXMP(xmlString: xml)
        #expect(abs(parsed.geometry.cropX - 0.15) < 1e-3)
        #expect(abs(parsed.geometry.cropY - 0.20) < 1e-3)
        #expect(abs(parsed.geometry.cropWidth - 0.70) < 1e-3)
        #expect(abs(parsed.geometry.cropHeight - 0.60) < 1e-3)
        #expect(abs(parsed.geometry.rotationAngle - (-2.5)) < 1e-3)
        #expect(parsed.geometry.isCropped)
    }
}
