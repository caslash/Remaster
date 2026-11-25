//
//  ArtworkGenerator.swift
//  Remaster
//
//  Created by Cameron Slash on 11/24/26.
//

#if DEBUG || PROFILING
import UIKit

nonisolated struct ArtworkGenerator {
    static let size = CGSize(width: 333, height: 500)

    private let renderer: UIGraphicsImageRenderer

    init() {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        renderer = UIGraphicsImageRenderer(size: Self.size, format: format)
    }

    func makeImageData(using rng: inout some RandomNumberGenerator) -> Data {
        renderer.jpegData(withCompressionQuality: 0.85) { ctx in
            let cg = ctx.cgContext
            drawBackground(in: cg, using: &rng)
            for _ in 0..<Int.random(in: 3...8, using: &rng) {
                drawShape(in: cg, using: &rng)
            }
        }
    }

    private func drawBackground(in cg: CGContext, using rng: inout some RandomNumberGenerator) {
        let w = Self.size.width, h = Self.size.height
        let baseHue = CGFloat.random(in: 0..<1, using: &rng)
        let colors = [
            color(hue: baseHue, using: &rng).cgColor,
            color(hue: (baseHue + .random(in: 0.08...0.4, using: &rng)).truncatingRemainder(dividingBy: 1), using: &rng).cgColor
        ] as CFArray

        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
        let options: CGGradientDrawingOptions = [.drawsBeforeStartLocation, .drawsAfterEndLocation]

        if Bool.random(using: &rng) {
            cg.drawLinearGradient(
                gradient,
                start: CGPoint(x: .random(in: 0...w, using: &rng), y: 0),
                end: CGPoint(x: .random(in: 0...w, using: &rng), y: h),
                options: options
            )
        } else {
            let center = CGPoint(x: .random(in: 0...w, using: &rng), y: .random(in: 0...h, using: &rng))
            cg.drawRadialGradient(gradient, startCenter: center, startRadius: 0,
                                  endCenter: center, endRadius: max(w, h), options: options)
        }
    }

    private func drawShape(in cg: CGContext, using rng: inout some RandomNumberGenerator) {
        let w = Self.size.width, h = Self.size.height
        let side = CGFloat.random(in: 40...220, using: &rng)
        let rect = CGRect(x: .random(in: -side/2...(w - side/2), using: &rng),
                          y: .random(in: -side/2...(h - side/2), using: &rng),
                          width: side,
                          height: side * .random(in: 0.5...1.5, using: &rng))

        let path: UIBezierPath
        switch Int.random(in: 0..<4, using: &rng) {
        case 0: path = UIBezierPath(ovalIn: rect)
        case 1: path = UIBezierPath(rect: rect)
        case 2: path = UIBezierPath(roundedRect: rect, cornerRadius: side * 0.2)
        default:
            path = UIBezierPath()
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.close()
        }

        cg.saveGState()
        cg.translateBy(x: rect.midX, y: rect.midY)
        cg.rotate(by: .random(in: 0..<(.pi * 2), using: &rng))
        cg.translateBy(x: -rect.midX, y: -rect.midY)

        let fill = color(hue: .random(in: 0..<1, using: &rng), using: &rng)
            .withAlphaComponent(.random(in: 0.25...0.8, using: &rng))
        fill.setFill()
        path.fill()

        if Bool.random(using: &rng) {
            UIColor.white.withAlphaComponent(0.6).setStroke()
            path.lineWidth = .random(in: 2...8, using: &rng)
            path.stroke()
        }
        cg.restoreGState()
    }

    private func color(hue: CGFloat, using rng: inout some RandomNumberGenerator) -> UIColor {
        UIColor(hue: hue,
                saturation: .random(in: 0.5...0.9, using: &rng),
                brightness: .random(in: 0.5...0.95, using: &rng),
                alpha: 1)
    }
}
#endif
