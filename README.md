# EasyLiteRoom 📷⚡

> A modern, open-source, non-destructive RAW photo editor engineered natively for macOS and Apple Silicon.

[![Platform: macOS](https://img.shields.io/badge/Platform-macOS%2015%2B-black?logo=apple&style=flat-square)](https://apple.com/macos)
[![Swift: 6.0](https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white&style=flat-square)](https://swift.org)
[![Graphics: Metal 3](https://img.shields.io/badge/Graphics-Metal%203-blue?style=flat-square)](https://developer.apple.com/metal)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg?style=flat-square)](LICENSE)
[![Clean-Room: Certified](https://img.shields.io/badge/Clean--Room-Certified-purple?style=flat-square)](CONTRIBUTING.md#clean-room-policy)

---

## Overview

**EasyLiteRoom** is a professional-grade, non-destructive RAW image editor built from the ground up to exploit the full power of Apple Silicon's Unified Memory Architecture, 120Hz ProMotion displays, and Metal 3 compute shaders.

Designed with a strict **Clean-Room implementation policy**, EasyLiteRoom uses open mathematical color models, standard CIE colorimetry, and transparent directed acyclic graph (DAG) pipelines to deliver uncompromising image quality without legal encumbrances.

---

## Key Features

- **32-Bit Floating-Point Linear Pipeline**: Edits occur in wide-gamut linear 32-bit float space (ProPhoto RGB / ACEScg), preventing color banding, posterization, and highlight clipping.
- **Directed Acyclic Graph (DAG) Engine**: Every slider adjustment compiles into an immutable mathematical operation node. The original RAW file is never altered.
- **Metal 3 Compute Acceleration**: GPU compute shaders deliver real-time 120 FPS slider feedback, interactive spline tone curves, and instant 4-channel histogram calculations.
- **Zero-Copy Apple Silicon Architecture**: Leverages unified memory (`MTLResourceStorageModeShared`) to share RAW demosaiced buffers directly between CPU and GPU without costly IPC serialization.
- **Clean-Room Color Science**:
  - Bradford Chromatic Adaptation Transform (CAT02/CAT16) for pristine White Balance adjustments.
  - Fritsch-Carlson Monotone Cubic Spline curves (guarantees monotonicity, eliminating ringing/overshoot).
  - Planckian Locus approximation for accurate Kelvin-to-xy correlated color temperature mapping.
- **Modern macOS Sequoia Interface**: Built with SwiftUI and AppKit, featuring native system translucency (`.ultraThinMaterial`), tactile scrub sliders with modifier scaling (`⌥` fine, `⇧` fast), and full keyboard navigation.
- **Non-Destructive Sidecar Persistence**: Edits are stored in high-performance local catalogs with real-time bidirectional `.xmp` sidecar synchronization.

---

## Architectural Blueprint

```
[RAW File (.ARW / .CR3 / .NEF / .DNG)]
                  │
                  ▼
         [RAW Decode Engine]
                  │
                  ▼ (Zero-Copy MTLBuffer)
    [Bayer Demosaicing (Metal 3)]
                  │
                  ▼ (Linear 32-bit Float)
     [ProPhoto RGB Working Space]
                  │
  ┌───────────────┴───────────────┐
  ▼                               ▼
[Bradford White Balance]    [Exposure / Bias (+/- 5 EV)]
  └───────────────┬───────────────┘
                  │
     [Contrast & Sigmoid Curve]
                  │
     [Fritsch-Carlson Spline LUT]
                  │
    [HSL Targeted Color Grading]
                  │
  ┌───────────────┴───────────────┐
  ▼                               ▼
[Atomic GPU Histogram]     [120Hz MTKView Viewport]
```

---

## System Requirements

- **Operating System**: macOS 15.0 (Sequoia) or later
- **Hardware**: Apple Silicon (M1/M2/M3/M4 series recommended) or Intel Mac with Metal 3 support
- **Developer Tools**: Xcode 16.0+ / Swift 6.0+

---

## Building from Source

1. **Clone the repository:**
   ```bash
   git clone https://github.com/shrasel/EasyLiteRoom.git
   cd EasyLiteRoom
   ```

2. **Open the project in Xcode:**
   ```bash
   xed .
   ```

3. **Or build from the command line:**
   ```bash
   xcodebuild -scheme EasyLiteRoom -destination 'platform=macOS' build
   ```

4. **Run the test suite:**
   ```bash
   xcodebuild -scheme EasyLiteRoom -destination 'platform=macOS' test
   ```

---

## Clean-Room Legal Strategy & DCO

To ensure complete legal independence and open-source integrity:
- **No Proprietary Code**: No code, binary assets, or reverse-engineered algorithms from commercial software are used.
- **Standard Math**: All color transformations, spline curves, and filters rely solely on public domain and established academic literature.
- **Developer Certificate of Origin (DCO)**: All contributions require a DCO sign-off (`git commit -s`). See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

---

## Contributing

We welcome contributions from graphics engineers, color scientists, and macOS developers! Please read our [CONTRIBUTING.md](CONTRIBUTING.md) and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) before submitting pull requests.

---

## License

EasyLiteRoom is released under the [MIT License](LICENSE).
Copyright (c) 2026 Shahjahan Rasel and Contributors.
