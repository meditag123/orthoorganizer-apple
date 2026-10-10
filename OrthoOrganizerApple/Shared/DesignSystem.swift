import SwiftUI

enum OrthoTheme {
    static let navy = Color(red: 0.063, green: 0.165, blue: 0.263)
    static let teal = Color(red: 0.082, green: 0.435, blue: 0.400)
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
            .background(OrthoTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
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
                .font(.title3.weight(.semibold))
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
            .frame(maxWidth: 250, maxHeight: 58)
        .accessibilityLabel("OrthoOrganizer")
    }
}
