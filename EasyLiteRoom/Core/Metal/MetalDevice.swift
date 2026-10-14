//
//  MetalDevice.swift
//  EasyLiteRoom
//
//  Created by Shahjahan Rasel on 10/13/26.
//  Metal device, command queue, and compute pipeline manager.
//

import Foundation
import Metal
import CoreGraphics

public final class MetalDevice: @unchecked Sendable {
    public static let shared = MetalDevice()

    public let device: MTLDevice
    public let commandQueue: MTLCommandQueue
    private var pipelineStates: [String: MTLComputePipelineState] = [:]
    private let lock = NSLock()

    private init() {
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            fatalError("EasyLiteRoom requires an Apple Silicon or Metal 3 compatible GPU.")
        }
        guard let queue = defaultDevice.makeCommandQueue() else {
            fatalError("Failed to initialize Metal command queue.")
        }
        self.device = defaultDevice
        self.commandQueue = queue
    }

    /// Retrieves or compiles a compute pipeline state for a given shader function name.
    public func pipelineState(named functionName: String) throws -> MTLComputePipelineState {
        lock.lock()
        defer { lock.unlock() }

        if let existing = pipelineStates[functionName] {
            return existing
        }

        var library: MTLLibrary?
        if let mainLib = try? device.makeDefaultLibrary(bundle: Bundle.main) {
            library = mainLib
        } else if let bundleLib = try? device.makeDefaultLibrary(bundle: Bundle(for: MetalDevice.self)) {
            library = bundleLib
        } else if let defaultLib = device.makeDefaultLibrary() {
            library = defaultLib
        }

        guard let validLibrary = library else {
            throw MetalDeviceError.libraryNotFound
        }

        guard let function = validLibrary.makeFunction(name: functionName) else {
            throw MetalDeviceError.functionNotFound(functionName)
        }

        let pipeline = try device.makeComputePipelineState(function: function)
        pipelineStates[functionName] = pipeline
        return pipeline
    }

    /// Creates a 32-bit floating point Metal texture allocated in shared unified memory.
    public func makeTexture(width: Int, height: Int, format: MTLPixelFormat = .rgba32Float) -> MTLTexture? {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: format,
            width: max(1, width),
            height: max(1, height),
            mipmapped: false
        )
        desc.usage = [.shaderRead, .shaderWrite, .renderTarget]
        desc.storageMode = .shared
        return device.makeTexture(descriptor: desc)
    }

    /// Executes the develop adjustment compute kernel synchronously on the GPU.
    public func processImage(
        input: MTLTexture,
        output: MTLTexture,
        parameters: AdjustmentParameters,
        lut: [Float]
    ) throws {
        let pipeline = try pipelineState(named: "develop_adjustments_kernel")

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw MetalDeviceError.commandBufferCreationFailed
        }

        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(input, index: 0)
        encoder.setTexture(output, index: 1)

        var uniforms = GPUAdjustmentUniforms(from: parameters)
        encoder.setBytes(&uniforms, length: MemoryLayout<GPUAdjustmentUniforms>.size, index: 0)

        lut.withUnsafeBytes { ptr in
            encoder.setBytes(ptr.baseAddress!, length: ptr.count, index: 1)
        }

        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroups = MTLSize(
            width: (input.width + threadgroupSize.width - 1) / threadgroupSize.width,
            height: (input.height + threadgroupSize.height - 1) / threadgroupSize.height,
            depth: 1
        )

        encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }

    /// Computes a 4-channel 256-bin histogram (R, G, B, Luminance) using Metal compute kernels.
    public func computeHistogram(for texture: MTLTexture) throws -> HistogramData {
        let clearPipeline = try pipelineState(named: "clear_histogram_kernel")
        let computePipeline = try pipelineState(named: "compute_histogram_kernel")

        guard let buffer = device.makeBuffer(length: 1024 * MemoryLayout<UInt32>.size, options: .storageModeShared),
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw MetalDeviceError.commandBufferCreationFailed
        }

        // 1. Clear histogram buffer
        encoder.setComputePipelineState(clearPipeline)
        encoder.setBuffer(buffer, offset: 0, index: 0)
        let clearGroupSize = MTLSize(width: min(256, clearPipeline.maxTotalThreadsPerThreadgroup), height: 1, depth: 1)
        let clearGroups = MTLSize(width: (1024 + clearGroupSize.width - 1) / clearGroupSize.width, height: 1, depth: 1)
        encoder.dispatchThreadgroups(clearGroups, threadsPerThreadgroup: clearGroupSize)

        // 2. Compute histogram
        encoder.setComputePipelineState(computePipeline)
        encoder.setTexture(texture, index: 0)
        encoder.setBuffer(buffer, offset: 0, index: 0)

        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroups = MTLSize(
            width: (texture.width + threadgroupSize.width - 1) / threadgroupSize.width,
            height: (texture.height + threadgroupSize.height - 1) / threadgroupSize.height,
            depth: 1
        )
        encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // Read results directly from shared memory
        let counts = buffer.contents().bindMemory(to: UInt32.self, capacity: 1024)

        // Find max count in interior bins (1..254) to prevent clipping spikes from flattening graph
        var maxCount: UInt32 = 1
        for i in 0..<1024 {
            let bin = i % 256
            if bin > 0 && bin < 255 {
                maxCount = max(maxCount, counts[i])
            }
        }

        let normFactor = max(Float(maxCount), 1.0)
        var r = [Float](repeating: 0.0, count: 256)
        var g = [Float](repeating: 0.0, count: 256)
        var b = [Float](repeating: 0.0, count: 256)
        var lum = [Float](repeating: 0.0, count: 256)

        for i in 0..<256 {
            r[i] = min(1.0, Float(counts[i]) / normFactor)
            g[i] = min(1.0, Float(counts[256 + i]) / normFactor)
            b[i] = min(1.0, Float(counts[512 + i]) / normFactor)
            lum[i] = min(1.0, Float(counts[768 + i]) / normFactor)
        }

        let totalPixels = Float(texture.width * texture.height)
        let shadowClipCount = counts[768] // Lum bin 0
        let highlightClipCount = counts[768 + 255] // Lum bin 255

        let shadowClipped = (Float(shadowClipCount) / totalPixels) > 0.002
        let highlightClipped = (Float(highlightClipCount) / totalPixels) > 0.002

        return HistogramData(
            red: r,
            green: g,
            blue: b,
            luminance: lum,
            shadowClipped: shadowClipped,
            highlightClipped: highlightClipped
        )
    }
}

public struct HistogramData: Sendable {
    public var red: [Float]
    public var green: [Float]
    public var blue: [Float]
    public var luminance: [Float]
    public var shadowClipped: Bool
    public var highlightClipped: Bool

    public static let empty = HistogramData(
        red: Array(repeating: 0.0, count: 256),
        green: Array(repeating: 0.0, count: 256),
        blue: Array(repeating: 0.0, count: 256),
        luminance: Array(repeating: 0.0, count: 256),
        shadowClipped: false,
        highlightClipped: false
    )
}

public enum MetalDeviceError: LocalizedError {
    case libraryNotFound
    case functionNotFound(String)
    case commandBufferCreationFailed

    public var errorDescription: String? {
        switch self {
        case .libraryNotFound:
            return "Metal shader library could not be loaded."
        case .functionNotFound(let name):
            return "Compute kernel '\(name)' was not found in the Metal library."
        case .commandBufferCreationFailed:
            return "Failed to create a Metal command buffer or compute encoder."
        }
    }
}
