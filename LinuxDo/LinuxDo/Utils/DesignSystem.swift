//
//  DesignSystem.swift
//  LinuxDo
//
//  统一设计系统：衬线字体 · 颜色 · 间距 · 圆角 · 卡片样式
//  复刻 fluxdo Material Design 3 视觉效果
//

import SwiftUI

// MARK: - Typography

enum DesignTypography {
    /// 衬线体：话题标题、帖子正文
    static let serifLargeTitle = Font.system(.largeTitle, design: .serif)
    static let serifTitle = Font.system(.title, design: .serif)
    static let serifTitle2 = Font.system(.title2, design: .serif)
    static let serifTitle3 = Font.system(.title3, design: .serif)
    static let serifHeadline = Font.system(.headline, design: .serif)
    static let serifBody = Font.system(.body, design: .serif)
    static let serifCallout = Font.system(.callout, design: .serif)
    static let serifSubheadline = Font.system(.subheadline, design: .serif)
    static let serifFootnote = Font.system(.footnote, design: .serif)
    static let serifCaption = Font.system(.caption, design: .serif)
    static let serifCaption2 = Font.system(.caption2, design: .serif)

    /// 等宽字体：代码块、技术内容
    static let monoCaption = Font.system(.caption, design: .monospaced)
    static let monoFootnote = Font.system(.footnote, design: .monospaced)
    static let monoBody = Font.system(.body, design: .monospaced)
}

// MARK: - Spacing

enum DesignSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 6
    static let md: CGFloat = 8
    static let lg: CGFloat = 12
    static let xl: CGFloat = 16
    static let xxl: CGFloat = 24
}

// MARK: - Corner Radius

enum DesignRadius {
    static let sm: CGFloat = 6
    static let md: CGFloat = 10
    static let lg: CGFloat = 12
    static let xl: CGFloat = 16
}

// MARK: - Card Style

struct DesignCard: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: DesignRadius.md)
                    .fill(isSelected
                        ? Color.accentColor.opacity(0.08)
                        : Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignRadius.md)
                    .stroke(isSelected
                        ? Color.accentColor.opacity(0.3)
                        : Color.clear,
                        lineWidth: 1)
            )
    }
}

extension View {
    func designCard(isSelected: Bool = false) -> some View {
        modifier(DesignCard(isSelected: isSelected))
    }
}

// MARK: - Read Opacity

/// 已读话题半透明效果（对齐 fluxdo fully read → opacity 0.5）
extension View {
    func readOpacity(_ isFullyRead: Bool) -> some View {
        self.opacity(isFullyRead ? 0.5 : 1.0)
    }
}

// MARK: - Section Header

struct DesignSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(DesignTypography.serifFootnote)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, DesignSpacing.lg)
    }
}

// MARK: - Stat Label

struct StatLabel: View {
    let icon: String
    let value: Int

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption2)
            Text(value.formatted(.number.notation(.compactName)))
                .font(DesignTypography.serifCaption2)
        }
        .foregroundStyle(.secondary)
    }
}
