# Contributing to EasyLiteRoom

Thank you for your interest in contributing to **EasyLiteRoom**! We are committed to building a world-class, high-performance, non-destructive RAW photo editor for macOS.

To protect the project, its users, and all contributors, we adhere to strict legal, architectural, and coding standards.

---

## 1. Clean-Room Policy (Crucial)

EasyLiteRoom is developed strictly following a **Clean-Room Engineering Methodology**:
- **Zero Proprietary Code**: You must not view, decompile, copy, or reference proprietary code, algorithms, or private headers from commercial photo editing software (such as Adobe Lightroom, Capture One, etc.).
- **Open Standards Only**: All mathematical models, color matrices, and pipeline stages must be derived from open standards, peer-reviewed academic literature (e.g., CIE color spaces, IEEE papers), or established open-source projects under compatible licenses (MIT, Apache 2.0, BSD).
- **Original Implementations**: All algorithms must be implemented from scratch in pure Swift, Metal Shading Language (MSL), or standard open-source C/C++ libraries (such as LibRaw).

---

## 2. Developer Certificate of Origin (DCO)

All commits to EasyLiteRoom must include a Signed-off-by trailer certifying that you have the legal right to submit the code under the project's MIT License.

You can automatically add this line to your commits using `git commit -s`:

```text
Signed-off-by: Jane Developer <jane@example.com>
```

By providing this sign-off, you certify the statements in [DCO.md](DCO.md).

---

## 3. Code Standards & Architecture

### Swift & Concurrency
- **Swift 6 Strict Concurrency**: All code must compile cleanly with `-strict-concurrency=complete` and produce zero concurrency warnings.
- **Value Semantics & Immutability**: All DAG nodes, edit states, and color profiles should use immutable structs and value types wherever feasible.
- **Documentation**: All public types, functions, and compute pipelines must include clear Swift documentation comments explaining their mathematical basis and units.

### Metal & Performance
- **Zero-Copy Memory**: Always use `MTLResourceStorageModeShared` on Apple Silicon for buffers shared between CPU and GPU.
- **120Hz Frame Budget**: All interactive shader kernels (Exposure, WB, Curves, Tonemapping) must execute in `< 8.33ms` on an Apple M1 or later.
- **Precision**: Image math in GPU shaders must use 32-bit floating point (`float`, `float3`, `float4`) inside working pipelines. Use half-precision (`half`) only for display rendering passes if memory bandwidth requires it.

---

## 4. Testing Requirements

No pull request will be accepted without adequate test coverage:
1. **Mathematical Unit Tests**: Pure mathematical functions (splines, color conversions, Kelvin calculations) must have 100% test coverage with edge-case tests.
2. **Headless Metal Compute Tests**: Every compute kernel must have a corresponding test validating its GPU output against a double-precision CPU reference calculation.
3. **No Memory Leaks**: All PRs modifying texture pipelines or caches must be verified clean of memory leaks using Xcode Instruments.

---

## 5. Development Workflow

1. Fork the repository and create your feature branch from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```
2. Commit your changes with clear, descriptive commit messages and DCO sign-off:
   ```bash
   git commit -s -m "feat(shaders): implement Bradford chromatic adaptation in Metal"
   ```
3. Ensure all tests pass:
   ```bash
   xcodebuild -scheme EasyLiteRoom -destination 'platform=macOS' test
   ```
4. Push to your fork and submit a Pull Request.
