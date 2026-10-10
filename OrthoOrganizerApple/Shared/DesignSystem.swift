import SwiftUI

enum OrthoTheme {
    static let navy = Color(red: 0.063, green: 0.165, blue: 0.263)
    static let teal = Color(red: 0.082, green: 0.435, blue: 0.400)
    static let mint = Color(red: 0.84, green: 0.95, blue: 0.92)
    static let mintBorder = Color(red: 0.70, green: 0.88, blue: 0.84)
    static let ink = Color(red: 0.11, green: 0.15, blue: 0.19)
    static let muted = Color(red: 0.38, green: 0.44, blue: 0.49)
    static let canvas = Color(red: 0.955, green: 0.968, blue: 0.975)
    static let card = Color.white
    static let divider = Color.black.opacity(0.08)

    static func accent(for theme: String) -> Color {
        switch theme {
        case "slate": return Color(red: 0.18, green: 0.37, blue: 0.62)
        case "forest": return Color(red: 0.13, green: 0.48, blue: 0.32)
        case "burgundy": return Color(red: 0.55, green: 0.16, blue: 0.25)
        case "amber": return Color(red: 0.68, green: 0.40, blue: 0.08)
        default: return teal
        }
    }
}

struct OrthoCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(OrthoTheme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(OrthoTheme.divider, lineWidth: 1)
            }
    }
}

struct OrthoSectionHeader: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(OrthoTheme.ink)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(OrthoTheme.muted)
            }
        }
    }
}

struct OrthoBadge: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

struct OrthoLogo: View {
    var body: some View {
        Image("OrthoLogo")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 280, maxHeight: 76)
            .accessibilityLabel("OrthoOrganizer")
    }
}

/// The square mark used in the mobile/tablet header, matching the Android
/// header instead of shrinking the full wordmark into a tiny image.
struct OrthoMark: View {
    var body: some View {
        Image("OrthoMark")
            .resizable()
            .scaledToFit()
            .frame(width: 54, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .accessibilityLabel("OrthoOrganizer")
    }
}

struct OrthoHeader: View {
    let title: String
    let onMenu: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HeaderButton(systemImage: "line.3.horizontal", action: onMenu)
            HStack(spacing: 12) {
                OrthoMark()
                Text(title)
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .foregroundStyle(OrthoTheme.navy)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HeaderButton(systemImage: "arrow.clockwise", action: onRefresh)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(OrthoTheme.canvas)
    }
}

private struct HeaderButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(OrthoTheme.navy)
                .frame(width: 56, height: 56)
                .background(OrthoTheme.mint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(OrthoTheme.mintBorder, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}
