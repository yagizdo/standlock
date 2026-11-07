import Foundation

/// A small picture written as text, one character per pixel. The palette gives each drawn
/// character a `0xRRGGBB` colour; any other character, such as `.`, is transparent.
public struct PixelSprite: Sendable {
    public let rows: [[Character]]
    public let palette: [Character: UInt]

    public init(_ rows: [String], palette: [Character: UInt]) {
        self.rows = rows.map(Array.init)
        self.palette = palette
    }
}

/// One row segment of a single colour, so a view draws one rectangle per run, not per pixel.
public struct PixelRun: Equatable, Sendable {
    public let x: Int
    public let y: Int
    public let length: Int
    public let color: UInt
}

/// A `width` x `height` picture that sprites are stamped onto. A nil pixel is transparent.
public struct PixelGrid: Equatable, Sendable {
    public let width: Int
    public let height: Int
    private var pixels: [UInt?]

    public init(width: Int, height: Int, fill: (_ x: Int, _ y: Int) -> UInt? = { _, _ in nil }) {
        self.width = width
        self.height = height
        pixels = (0..<height).flatMap { y in (0..<width).map { x in fill(x, y) } }
    }

    public subscript(x x: Int, y y: Int) -> UInt? {
        pixels[y * width + x]
    }

    /// Draws `sprite` with its top left corner at `x`, `y`. Pixels that fall outside are dropped,
    /// so a sprite can drift in from an edge.
    public mutating func stamp(_ sprite: PixelSprite, x: Int, y: Int) {
        for (row, characters) in sprite.rows.enumerated() {
            let gridY = y + row
            guard gridY >= 0, gridY < height else { continue }
            for (column, character) in characters.enumerated() {
                let gridX = x + column
                guard gridX >= 0, gridX < width, let color = sprite.palette[character] else { continue }
                pixels[gridY * width + gridX] = color
            }
        }
    }

    public var runs: [PixelRun] {
        var runs: [PixelRun] = []
        for y in 0..<height {
            var x = 0
            while x < width {
                guard let color = self[x: x, y: y] else {
                    x += 1
                    continue
                }
                var end = x + 1
                while end < width, self[x: end, y: y] == color { end += 1 }
                runs.append(PixelRun(x: x, y: y, length: end - x, color: color))
                x = end
            }
        }
        return runs
    }
}
