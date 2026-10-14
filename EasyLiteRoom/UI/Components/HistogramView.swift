//
//  HistogramView.swift
//  EasyLiteRoom
//
//  Created by Shahjahan Rasel on 10/13/26.
//  Real-time 4-channel GPU histogram view with shadow and highlight clipping indicators.
//

import SwiftUI

public enum HistogramChannel: String, CaseIterable, Identifiable {
    case all = "RGB"
    case red = "R"
    case green = "G"
    case blue = "B"
    case lum = "Lum"

    public var id: String { rawValue }
}

public struct HistogramView: View {
    let data: HistogramData
    @State private var selectedChannel: HistogramChannel = .all

    public init(data: HistogramData) {
        self.data = data
    }

    public var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Background dark rounded container with subtle grid
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.45))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                    )

                // Grid lines (quartiles)
                GeometryReader { geo in
                    Path { path in
                        let w = geo.size.width
                        let h = geo.size.height
                        // 25%, 50%, 75%
                        for q in [0.25, 0.50, 0.75] {
                            let x = w * q
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: h))
                        }
                    }
                    .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                }

                // Histogram Paths
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height

                    if selectedChannel == .all || selectedChannel == .red {
                        channelArea(bins: data.red, width: w, height: h)
                            .fill(LinearGradient(colors: [Color.red.opacity(0.55), Color.red.opacity(0.15)], startPoint: .top, endPoint: .bottom))
                    }
                    if selectedChannel == .all || selectedChannel == .green {
                        channelArea(bins: data.green, width: w, height: h)
                            .fill(LinearGradient(colors: [Color.green.opacity(0.55), Color.green.opacity(0.15)], startPoint: .top, endPoint: .bottom))
                    }
                    if selectedChannel == .all || selectedChannel == .blue {
                        channelArea(bins: data.blue, width: w, height: h)
                            .fill(LinearGradient(colors: [Color.blue.opacity(0.55), Color.blue.opacity(0.15)], startPoint: .top, endPoint: .bottom))
                    }
                    if selectedChannel == .all || selectedChannel == .lum {
                        channelArea(bins: data.luminance, width: w, height: h)
                            .stroke(Color.white.opacity(0.85), lineWidth: 1.0)
                    }
                }

                // Clipping Indicators (Shadow on Left, Highlight on Right)
                HStack {
                    // Shadow clipping indicator
                    Image(systemName: "triangle.fill")
                        .rotationEffect(.degrees(-90))
                        .font(.system(size: 8))
                        .foregroundStyle(data.shadowClipped ? Color.blue : Color.white.opacity(0.2))
                        .help(data.shadowClipped ? "Shadow clipping detected (pure black)" : "Shadows unclipped")
                        .padding(6)

                    Spacer()

                    // Highlight clipping indicator
                    Image(systemName: "triangle.fill")
                        .rotationEffect(.degrees(90))
                        .font(.system(size: 8))
                        .foregroundStyle(data.highlightClipped ? Color.red : Color.white.opacity(0.2))
                        .help(data.highlightClipped ? "Highlight clipping detected (blown whites)" : "Highlights unclipped")
                        .padding(6)
                }
            }
            .frame(height: 85)

            // Channel Selector Bar
            HStack(spacing: 8) {
                ForEach(HistogramChannel.allCases) { channel in
                    Button {
                        selectedChannel = channel
                    } label: {
                        Text(channel.rawValue)
                            .font(.system(size: 9, weight: selectedChannel == channel ? .bold : .medium, design: .monospaced))
                            .foregroundStyle(selectedChannel == channel ? .primary : .secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(selectedChannel == channel ? Color.white.opacity(0.15) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Text("256 Bins • 32-bit Float")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func channelArea(bins: [Float], width: CGFloat, height: CGFloat) -> Path {
        var path = Path()
        guard bins.count == 256 else { return path }

        let step = width / 255.0
        path.move(to: CGPoint(x: 0, y: height))

        for i in 0..<256 {
            let x = CGFloat(i) * step
            let y = height - (CGFloat(bins[i]) * height * 0.95)
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: width, y: height))
        path.closeSubpath()
        return path
    }
}
