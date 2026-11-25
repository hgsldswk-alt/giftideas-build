import SwiftUI
import UIKit

private func hex(_ light: UInt32, dark: UInt32? = nil) -> Color {
    Color(uiColor: UIColor { traits in
        let value = traits.userInterfaceStyle == .dark ? dark ?? light : light
        return UIColor(red: CGFloat((value >> 16) & 0xFF) / 255,
                       green: CGFloat((value >> 8) & 0xFF) / 255,
                       blue: CGFloat(value & 0xFF) / 255, alpha: 1)
    })
}

enum Theme {
    static let accent = hex(0x86A04B)
    static let berry = hex(0xD9637A)
    static let cream = hex(0xF3D9A4)
    static let brown = hex(0xB07A52)
    static let primary = hex(0x56692B)
    static let accentDeep = hex(0x4F6129, dark: 0xC7D999)
    static let accentSoft = hex(0xEBF0E0, dark: 0x343F27)
    static let background = hex(0xFBF6EF, dark: 0x211D19)
    static let paper = hex(0xFFFFFF, dark: 0x2D2823)
    static let ink = hex(0x3A2E2C, dark: 0xF6EDE3)
    static let avatarInk = hex(0x20140E)
    static let muted = hex(0x6E605B, dark: 0xD2C0B6)
    static let line = hex(0xEBDFD3, dark: 0x4C4039)
    static let hero = LinearGradient(colors: [hex(0xDCE8C4, dark: 0x38472B), hex(0xF7F5E9, dark: 0x2F2E25)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing)
    static let giftBorder = LinearGradient(colors: [accent, accentSoft, cream],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
    static let shadow = Color.black.opacity(0.07)
    static let groupSpacing: CGFloat = 22

    private static let avatars: [DesignTone] = [.olive, .berry, .brown, .cream, .olive]
    static func avatar(_ index: Int) -> DesignTone {
        avatars[((index % avatars.count) + avatars.count) % avatars.count]
    }
}

enum DesignTone {
    case olive, berry, cream, brown

    var color: Color {
        switch self {
        case .olive: Theme.accent
        case .berry: Theme.berry
        case .cream: Theme.cream
        case .brown: Theme.brown
        }
    }

    var surface: Color {
        switch self {
        case .olive: Theme.accentSoft
        case .berry: hex(0xFAE8EC, dark: 0x4D2C36)
        case .cream: hex(0xFAEFD7, dark: 0x4C3C22)
        case .brown: hex(0xF5E7DA, dark: 0x4A3528)
        }
    }

    var ink: Color {
        switch self {
        case .olive: Theme.accentDeep
        case .berry: hex(0x963C54, dark: 0xFFB9C7)
        case .cream: hex(0x755313, dark: 0xF3D9A4)
        case .brown: hex(0x75472C, dark: 0xF0BF9E)
        }
    }
}

extension View {
    func testID(_ id: String) -> some View { accessibilityIdentifier(id) }

    func card(_ radius: CGFloat = 18) -> some View {
        background {
            RoundedRectangle(cornerRadius: radius)
                .fill(Theme.paper)
                .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(Theme.line))
                .shadow(color: Theme.shadow, radius: 12, x: 0, y: 4)
        }
    }
}

struct SectionTitle: View {
    let title: String
    var body: some View {
        Text(title).font(.headline).foregroundStyle(Theme.muted)
            .accessibilityAddTraits(.isHeader)
    }
}

struct CardGroup<Content: View>: View {
    var title: String? = nil
    var note: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title { SectionTitle(title: title) }
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
            if let note { Text(note).font(.footnote).foregroundStyle(Theme.muted) }
        }
    }
}

struct IconBadge: View {
    let icon: String
    var tone: DesignTone = .olive
    var size: CGFloat = 38
    var circular = false
    var decorative = true

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.43, weight: .semibold))
            .foregroundStyle(tone.ink)
            .frame(width: size, height: size)
            .background(tone.surface, in: RoundedRectangle(cornerRadius: circular ? size / 2 : 12))
            .accessibilityHidden(decorative)
    }
}

struct IconRow<Content: View>: View {
    let icon: String
    var tone: DesignTone = .olive
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 12) {
            IconBadge(icon: icon, tone: tone)
            content.frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 44)
    }
}

struct IconTile: View {
    let title: String
    let icon: String
    var tone: DesignTone = .olive

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                IconBadge(icon: icon, tone: tone, circular: true)
                Text(title).font(.subheadline.weight(.semibold)).fixedSize()
            }
            VStack(alignment: .leading, spacing: 6) {
                IconBadge(icon: icon, tone: tone, circular: true)
                Text(title).font(.subheadline.weight(.semibold))
            }
        }
        .foregroundStyle(Theme.ink)
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .card()
        .contentShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct StatusPill: View {
    let text: String
    var tone: DesignTone = .olive
    var icon: String?

    var body: some View {
        HStack(spacing: 5) {
            if let icon { Image(systemName: icon).accessibilityHidden(true) }
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption.weight(.semibold)).monospacedDigit()
        .padding(.horizontal, 9).padding(.vertical, 5)
        .foregroundStyle(tone.ink).background(tone.surface, in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

struct EmptyIllustration: View {
    var symbol = "gift.fill"
    var scale: CGFloat = 1

    var body: some View {
        ZStack {
            Circle().fill(Theme.accent.opacity(0.20))
                .frame(width: 68 * scale, height: 68 * scale)
            Image(systemName: symbol)
                .font(.system(size: 32 * scale, weight: .semibold))
                .foregroundStyle(Theme.accentDeep)
                .rotationEffect(.degrees(-9))
            Image(systemName: "heart.fill")
                .font(.system(size: 13 * scale, weight: .semibold))
                .foregroundStyle(Theme.berry)
                .frame(width: 30 * scale, height: 30 * scale)
                .background(DesignTone.berry.surface, in: Circle())
                .offset(x: 32 * scale, y: -27 * scale)
            Image(systemName: "sparkle")
                .font(.system(size: 13 * scale, weight: .semibold))
                .foregroundStyle(Theme.primary)
                .frame(width: 25 * scale, height: 25 * scale)
                .background(Theme.cream, in: Circle())
                .offset(x: -32 * scale, y: 25 * scale)
        }
        .frame(width: 98 * scale, height: 88 * scale)
        .accessibilityHidden(true)
    }
}

struct HeroCard<Content: View>: View {
    var symbol = "gift.fill"
    @ViewBuilder var content: Content
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 8))
        layout {
            content.frame(maxWidth: .infinity, alignment: .leading)
            EmptyIllustration(symbol: symbol)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.hero)
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.giftBorder.opacity(0.75)))
                .shadow(color: Theme.shadow, radius: 12, x: 0, y: 4)
        }
    }
}

struct Avatar: View {
    let person: Person
    var size: CGFloat = 40
    var body: some View {
        let tone = Theme.avatar(person.color)
        Text(person.initial)
            .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
            .foregroundStyle(Theme.avatarInk)
            .lineLimit(1).minimumScaleFactor(0.65)
            .frame(width: size, height: size).background(tone.color, in: Circle())
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "gift.fill")
                    .font(.system(size: max(7, size * 0.21), weight: .semibold))
                    .foregroundStyle(tone.ink)
                    .frame(width: size * 0.42, height: size * 0.42)
                    .background(Theme.paper, in: Circle())
                    .overlay(Circle().strokeBorder(Theme.line))
                    .offset(x: 3, y: 2)
            }
            .accessibilityHidden(true)
    }
}

struct DaysChip: View {
    let days: Int
    var text: String
    var body: some View {
        StatusPill(text: text, tone: days <= 14 ? .berry : .cream)
    }

    static func label(_ days: Int) -> String {
        days == 0 ? L.t("days.today") : days == 1 ? L.t("days.tomorrow") : L.f("days.left", days)
    }
}

struct PrimaryActionStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(enabled ? Color.white : Theme.muted)
            .background(enabled ? Theme.primary : Theme.accentSoft, in: RoundedRectangle(cornerRadius: 14))
            .contentShape(RoundedRectangle(cornerRadius: 14))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct SecondaryActionStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.subheadline.weight(.semibold))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(enabled ? Theme.accentDeep : Theme.muted)
            .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 14))
            .contentShape(RoundedRectangle(cornerRadius: 14))
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

struct PrimaryButton: View {
    var title: String
    var id: String
    var icon: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
        }
        .buttonStyle(PrimaryActionStyle()).testID(id)
    }
}

struct SecondaryButton: View {
    var title: String
    var id: String
    var icon: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
        }
        .buttonStyle(SecondaryActionStyle()).testID(id)
    }
}

struct ShareSaveView: View {
    @State var draft: ShareParse.Draft
    let people: [Person]
    var onSave: (ShareParse.Draft, UUID) -> Void
    var onCancel: () -> Void
    @State private var savedTo: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.groupSpacing) {
                    CardGroup {
                        IconRow(icon: "gift.fill", tone: .berry) {
                            TextField(L.t("idea.titlePrompt"), text: $draft.title, axis: .vertical).lineLimit(1...3)
                                .font(.headline).testID("share.title")
                        }
                        Divider()
                        IconRow(icon: "tag", tone: .cream) {
                            VStack(alignment: .leading, spacing: 4) {
                                TextField(L.t("idea.pricePrompt"), text: $draft.price).testID("share.price")
                                if let host = URL(string: draft.link)?.host {
                                    Text(host.replacingOccurrences(of: "www.", with: ""))
                                        .font(.footnote).foregroundStyle(Theme.muted).lineLimit(1)
                                }
                            }
                        }
                    }
                    if let savedTo {
                        HeroCard(symbol: "checkmark.circle.fill") {
                            Text(L.f("share.saved", savedTo)).font(.headline)
                                .foregroundStyle(Theme.accentDeep).testID("share.done")
                        }
                    } else if people.isEmpty {
                        CardGroup {
                            VStack(spacing: 12) {
                                EmptyIllustration()
                                Text(L.t("share.noPeople")).font(.subheadline).foregroundStyle(Theme.muted)
                                    .multilineTextAlignment(.center).testID("share.empty")
                                PrimaryButton(title: L.t("action.cancel"), id: "share.cancel", icon: "xmark", action: onCancel)
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionTitle(title: L.t("share.pick"))
                            FlowChips(people: people) { p in
                                let t = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !t.isEmpty else { return }
                                onSave(draft, p.id)
                                savedTo = p.displayName
                            }
                        }
                    }
                    Text(L.t("share.privacy")).font(.footnote).foregroundStyle(Theme.muted)
                }
                .padding(18)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(L.t("share.navTitle")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !people.isEmpty {
                        Button(savedTo == nil ? L.t("action.cancel") : L.t("action.done")) { onCancel() }.testID("share.cancel")
                    }
                }
            }
        }
        .tint(Theme.accentDeep)
    }
}

struct FlowChips: View {
    let people: [Person]
    var pick: (Person) -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: typeSize.isAccessibilitySize ? 1 : 2)
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(people) { p in
                Button { pick(p) } label: {
                    HStack(spacing: 10) {
                        Avatar(person: p, size: 36)
                        Text(p.displayName).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    .card()
                    .contentShape(RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(.plain).testID("share.person.\(p.displayName)")
            }
        }
    }
}
