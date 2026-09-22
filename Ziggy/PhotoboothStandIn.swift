//
//  PhotoboothStandIn.swift
//  Ziggy
//
//  A lens for a machine that hasn't got one.
//
//  Testing the booth takes two people in it at once, and a simulator has no
//  camera — so with one phone and one simulator there would be no way to try
//  the feature at all. This stands in for the simulator's side: it joins, it
//  counts down, and it hands up three frames like any other phone, so the
//  real device opposite sees a real partner and a real strip.
//
//  The whole file is behind `targetEnvironment(simulator)`. A device build
//  contains none of it, so there is no path by which a fake photograph can
//  reach a shipped app.
//

#if targetEnvironment(simulator)

import SwiftUI
import UIKit

enum PhotoboothStandIn {

    /// One frame, numbered, so the three shots of a strip are told apart and
    /// you can see at a glance that they arrived in the right order.
    static func frame(number: Int) -> UIImage {

        // 3:4, the shape the real camera hands back.
        let size = CGSize(width: 900, height: 1200)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in

            let c = ctx.cgContext

            // A different wash per shot, so a strip made of these reads as
            // three moments rather than one repeated.
            let pair = palette[(number - 1 + palette.count) % palette.count]
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [pair.0.cgColor, pair.1.cgColor] as CFArray,
                locations: [0, 1]
            ) {
                c.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )
            }

            if let ziggy = UIImage(named: "ziggy_loveeyes") {
                let side = size.width * 0.62
                ziggy.draw(in: CGRect(
                    x: (size.width - side) / 2,
                    y: size.height * 0.26,
                    width: side,
                    height: side
                ))
            }

            let style = NSMutableParagraphStyle()
            style.alignment = .center

            ("SIMULATOR" as NSString).draw(
                in: CGRect(x: 0, y: size.height * 0.10,
                           width: size.width, height: 80),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 54, weight: .black),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.92),
                    .paragraphStyle: style,
                    .kern: 6
                ]
            )

            ("shot \(number) of 3" as NSString).draw(
                in: CGRect(x: 0, y: size.height * 0.78,
                           width: size.width, height: 60),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 38, weight: .bold),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.85),
                    .paragraphStyle: style
                ]
            )
        }
    }

    private static let palette: [(UIColor, UIColor)] = [
        (UIColor(red: 0.98, green: 0.55, blue: 0.62, alpha: 1),
         UIColor(red: 0.62, green: 0.36, blue: 0.78, alpha: 1)),
        (UIColor(red: 0.38, green: 0.72, blue: 0.86, alpha: 1),
         UIColor(red: 0.22, green: 0.36, blue: 0.62, alpha: 1)),
        (UIColor(red: 0.98, green: 0.74, blue: 0.42, alpha: 1),
         UIColor(red: 0.85, green: 0.38, blue: 0.40, alpha: 1))
    ]

    /// What sits where the live preview would be.
    struct PreviewCard: View {

        @State private var pulse = false

        var body: some View {

            ZStack {

                LinearGradient(
                    colors: [Color(red: 0.24, green: 0.22, blue: 0.30),
                             Color(red: 0.13, green: 0.12, blue: 0.17)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )

                VStack(spacing: 10) {

                    Image(systemName: "camera.metering.unknown")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .scaleEffect(pulse ? 1.06 : 0.97)

                    Text("Stand-in lens")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))

                    Text("No camera here — this side will\nsend placeholder frames.")
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
        }
    }
}

#endif
