import SwiftUI
import UIKit

enum VoiceTheme {
    static let ink = Color.primary
    static let muted = Color.secondary
    static let accent = adaptive(light: 0x7652D6, dark: 0xB8A5F5)
    static let background = adaptive(light: 0xF7F5FC, dark: 0x17151F)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x25212F)
    static let soft = adaptive(light: 0xEEE8FB, dark: 0x332A47)
    static let line = adaptive(light: 0xE6E1ED, dark: 0x3B3449)
    static let onAccent = adaptive(light: 0xFFFFFF, dark: 0x211932)
    static let rose = Color(red: 0.94, green: 0.86, blue: 0.94)
    static let lilac = Color(red: 0.72, green: 0.65, blue: 0.96)
    static let sky = Color(red: 0.83, green: 0.93, blue: 0.98)
    static let mint = Color(red: 0.88, green: 0.96, blue: 0.95)
    static let spacing: CGFloat = 22
    static let capsule: CGFloat = 18
    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((rgb >> 16) & 255) / 255,
                           green: CGFloat((rgb >> 8) & 255) / 255,
                           blue: CGFloat(rgb & 255) / 255, alpha: 1)
        })
    }
}
