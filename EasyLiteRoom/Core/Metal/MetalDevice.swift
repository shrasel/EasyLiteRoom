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

        guard let library = try? device.makeDefaultLibrary(bundle: Bundle.main) ?? device.makeDefaultLibrary() else {
            throw MetalDeviceError.libraryNotFound
        }

        guard let function = library.makeFunction(name: functionName) else {
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
