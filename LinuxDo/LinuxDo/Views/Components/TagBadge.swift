//
//  TagBadge.swift
//  LinuxDo
//

import SwiftUI

struct TagBadge: View {
    let name: String
    var body: some View {
        Text(name)
            .font(DesignTypography.serifCaption2)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(.secondary.opacity(0.12)))
            .foregroundStyle(.secondary)
    }
}
