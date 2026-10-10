import AppKit

/// An sRGB color that can be parsed from hex strings and named colors.
public struct RGBAColor: Hashable, Sendable, CustomStringConvertible {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public static let black = RGBAColor(red: 0, green: 0, blue: 0)
    public static let white = RGBAColor(red: 1, green: 1, blue: 1)

    /// Named colors that match the system colors in light mode.
    public static let named: [String: RGBAColor] = [
        "black": .black,
        "white": .white,
        "red": .init(hex: 0xFF3B30),
        "orange": .init(hex: 0xFF9500),
        "yellow": .init(hex: 0xFFCC00),
        "green": .init(hex: 0x34C759),
        "mint": .init(hex: 0x00C7BE),
        "teal": .init(hex: 0x30B0C7),
        "cyan": .init(hex: 0x32ADE6),
        "blue": .init(hex: 0x007AFF),
        "indigo": .init(hex: 0x5856D6),
        "purple": .init(hex: 0xAF52DE),
        "pink": .init(hex: 0xFF2D55),
        "brown": .init(hex: 0xA2845E),
        "gray": .init(hex: 0x8E8E93),
    ]

    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            alpha: alpha
        )
    }

    /// Parses `#RGB`, `#RRGGBB`, `#RRGGBBAA` (the `#` is optional) or a name such as `blue`.
    public init?(string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespaces).lowercased()
        if let named = Self.named[trimmed] {
            self = named
            return
        }

        var hex = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        if hex.count == 3 {
            hex = hex.map { "\($0)\($0)" }.joined()
        }
        guard hex.count == 6 || hex.count == 8, let value = UInt64(hex, radix: 16) else { return nil }

        if hex.count == 8 {
            self.init(hex: UInt32(value >> 8), alpha: Double(value & 0xFF) / 255)
        } else {
            self.init(hex: UInt32(value))
        }
    }

    public var nsColor: NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    public var cgColor: CGColor {
        CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    public var description: String {
        let components = [red, green, blue].map { String(format: "%02X", Int(($0 * 255).rounded())) }.joined()
        return alpha < 1 ? "#\(components)\(String(format: "%02X", Int((alpha * 255).rounded())))" : "#\(components)"
    }
}
