import SwiftUI
import UIKit

struct ShareCardView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var image: UIImage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.groupSpacing) {
                    ShareCard(stats: .init(model.state, today: model.today)).testID("share.card")
                    Text(L.t("share.cardNote")).font(.footnote).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                    if let image {
                        ShareLink(item: Image(uiImage: image), preview: SharePreview(L.t("app.name"), image: Image(uiImage: image))) {
                            Label(L.t("share.image"), systemImage: "square.and.arrow.up").font(.headline)
                        }.buttonStyle(PrimaryActionStyle()).testID("share.image")
                    }
                }
                .padding(18)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(L.t("share.title")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L.t("action.done")) { model.route = nil }.testID("share.done") } }
            .task(id: colorScheme) {
                let r = ImageRenderer(content: ShareCard(stats: .init(model.state, today: model.today))
                    .frame(width: 360).environment(\.colorScheme, colorScheme))
                r.scale = 3
                image = r.uiImage
            }
        }
    }
}

struct ShareStats: Equatable {
    var year: Int
    var people: Int
    var ideas: Int
    var bought: Int

    init(_ s: AppState, today: Day) {
        year = today.year
        people = s.people.count
        let all = s.people.flatMap(\.ideas)
        ideas = all.filter { $0.added.year == today.year }.count
        bought = all.filter { $0.boughtOn?.year == today.year }.count
    }
}

struct ShareCard: View {
    let stats: ShareStats

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                StatusPill(text: L.f("card.year", String(stats.year)), icon: "calendar")
                Spacer(minLength: 4)
                EmptyIllustration(scale: 0.85)
            }
            Text(L.f("card.big", stats.people, stats.ideas))
                .font(.system(.title, design: .rounded, weight: .bold)).monospacedDigit()
                .lineSpacing(2).fixedSize(horizontal: false, vertical: true)
            if stats.bought > 0 { StatusPill(text: L.f("card.bought", stats.bought), tone: .cream) }
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L.t("app.name")).font(.footnote.weight(.bold))
                    Text(Launch.hashtag).font(.caption).foregroundStyle(Theme.muted)
                }
                Spacer()
                if let qr = QR.image(Launch.storeURL.absoluteString) {
                    Image(uiImage: qr).interpolation(.none).resizable().frame(width: 58, height: 58)
                        .padding(4).background(.white, in: RoundedRectangle(cornerRadius: 6)).accessibilityHidden(true)
                }
            }
            .padding(.top, 6)
        }
        .foregroundStyle(Theme.ink)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.hero)
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.giftBorder, lineWidth: 3))
                .shadow(color: Theme.shadow, radius: 12, x: 0, y: 4)
        }
    }
}

struct MilestoneView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.groupSpacing) {
                HeroCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("10").font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .foregroundStyle(Theme.accentDeep).accessibilityHidden(true)
                        Text(L.t("milestone.title")).font(.title2.bold()).testID("milestone.title")
                        ProgressView(value: 1.0).tint(Theme.accentDeep).accessibilityHidden(true)
                        Text(L.t("milestone.body")).font(.subheadline).foregroundStyle(Theme.muted)
                    }
                }
                VStack(spacing: 10) {
                    PrimaryButton(title: L.t("milestone.share"), id: "milestone.share", icon: "square.and.arrow.up") {
                        model.route = nil
                        Task { try? await Task.sleep(for: .milliseconds(600)); model.route = .shareCard }
                    }
                    SecondaryButton(title: L.t("action.close"), id: "milestone.close", icon: "xmark") { model.route = nil }
                }
            }
            .padding(18)
        }
        .background(Theme.background.ignoresSafeArea())
        .presentationDetents([.medium])
    }
}
