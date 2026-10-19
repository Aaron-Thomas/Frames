import SwiftUI

extension Photo {
    var placeholderColor: Color {
        guard let color, color.count == 7, color.hasPrefix("#"), let value = Int(color.dropFirst(), radix: 16) else {
            return Color(.secondarySystemFill)
        }
        return Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
