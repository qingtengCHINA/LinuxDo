//
//  CategoryBadge.swift
//  LinuxDo
//

import SwiftUI

struct CategoryBadge: View {
    let name: String
    let colorHex: String

    var body: some View {
        Text(name)
            .font(DesignTypography.serifCaption2).fontWeight(.medium)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(catColor))
            .foregroundStyle(.white)
    }

    private var catColor: Color { Color(hex: colorHex) ?? .accentColor }
}

extension Color {
    init?(hex: String) {
        var s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        guard s.count == 6, let i = UInt64(s, radix: 16) else { return nil }
        self.init(red: Double((i >> 16) & 0xFF)/255, green: Double((i >> 8) & 0xFF)/255, blue: Double(i & 0xFF)/255)
    }
}
