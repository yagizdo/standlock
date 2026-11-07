import SwiftUI
import StandLockCore

/// Draws a `PixelGrid` with square pixels of `pixel` points, one rectangle per run of a colour.
struct PixelGridView: View {
    let grid: PixelGrid
    var pixel: CGFloat = 4

    var body: some View {
        Canvas { context, _ in
            for run in grid.runs {
                let rect = CGRect(
                    x: CGFloat(run.x) * pixel,
                    y: CGFloat(run.y) * pixel,
                    width: CGFloat(run.length) * pixel,
                    height: pixel
                )
                context.fill(Path(rect), with: .color(Color(hex: run.color)))
            }
        }
        .frame(width: CGFloat(grid.width) * pixel, height: CGFloat(grid.height) * pixel)
    }
}
