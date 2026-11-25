import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var code = ""
    @State private var csv: URL?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.groupSpacing) {
                    CardGroup(title: L.t("settings.purchase")) {
                        IconRow(icon: "gift.fill", tone: .cream) {
                            Text(status).font(.subheadline).testID("settings.status")
                        }
                        if !model.state.entitlement.purchasedPro {
                            SecondaryButton(title: L.t("settings.unlock"), id: "settings.unlock", icon: "lock.open") {
                                open(.paywall)
                            }
                        }
                    }
                    CardGroup(title: L.t("settings.reminders"), note: L.t("settings.remindNote")) {
                        IconRow(icon: "bell", tone: .berry) {
                            let leadLabel = L.f("settings.lead", model.state.leadDays)
                            Stepper(value: Binding(get: { model.state.leadDays }, set: { model.setLead($0) }), in: AppState.leadRange) {
                                Text(leadLabel).monospacedDigit()
                            }
                            .accessibilityLabel(leadLabel)
                            .testID("settings.lead")
                        }
                        if model.notificationsDenied {
                            Text(L.t("settings.denied")).font(.footnote).foregroundStyle(DesignTone.berry.ink)
                                .testID("settings.denied")
                            Button {
                                if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) }
                            } label: {
                                Label(L.t("settings.openSettings"), systemImage: "gearshape")
                            }
                            .buttonStyle(SecondaryActionStyle())
                        }
                    }
                    CardGroup(title: L.t("person.codeHeader")) {
                        IconRow(icon: "doc.on.clipboard", tone: .brown) {
                            TextField(L.t("person.codePrompt"), text: $code, axis: .vertical).lineLimit(1...3)
                                .textInputAutocapitalization(.never).autocorrectionDisabled().testID("settings.code")
                        }
                        SecondaryButton(title: L.t("person.import"), id: "settings.import", icon: "tray.and.arrow.down") {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            if model.importCode(code) { code = ""; model.route = nil }
                        }
                        .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    CardGroup(title: L.t("settings.share")) {
                        Button { open(.shareCard) } label: {
                            IconRow(icon: "square.and.arrow.up", tone: .berry) { Text(L.t("person.shareCard")) }
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).testID("settings.shareCard")
                        if let csv {
                            Divider()
                            ShareLink(item: csv) {
                                IconRow(icon: "tablecells") { Text(L.t("settings.export")) }.contentShape(Rectangle())
                            }
                            .buttonStyle(.plain).testID("settings.export")
                        }
                        Divider()
                        ShareLink(item: L.t("settings.tellText") + " " + Launch.storeURL.absoluteString) {
                            IconRow(icon: "heart", tone: .cream) { Text(L.t("settings.tell")) }.contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    CardGroup(note: L.t("settings.privacy")) {
                        Link(destination: Launch.placeholderURL) {
                            IconRow(icon: "hand.raised", tone: .brown) { Text(L.t("settings.support")) }
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(18)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(L.t("settings.title")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L.t("action.done")) { model.route = nil }.testID("settings.done") } }
            .task { csv = writeCSV() }
        }
    }

    private var status: String {
        if model.state.entitlement.purchasedPro { return L.t("pay.owned") }
        if model.hasPro { return L.f("pay.until", Day(model.state.entitlement.trialEnd).label) }
        return L.f("pay.expired", Launch.freeLimit)
    }

    private func writeCSV() -> URL? {
        guard !model.state.people.isEmpty else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(L.t("settings.csvName") + ".csv")
        do { try CSVExport.text(model.state, today: model.today).write(to: url, atomically: true, encoding: .utf8); return url } catch { return nil }
    }

    private func open(_ route: Route) {
        model.route = nil
        Task { try? await Task.sleep(for: .milliseconds(600)); model.route = route }
    }
}

struct PaywallView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var store: StoreModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.groupSpacing) {
                    HeroCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L.t("pay.title")).font(.title2.bold())
                            Text(L.t("pay.once")).font(.subheadline).foregroundStyle(Theme.muted)
                        }
                    }
                    CardGroup {
                        IconRow(icon: "checkmark.seal", tone: .olive) {
                            Text(model.state.entitlement.purchasedPro ? L.t("pay.owned") : model.hasPro
                                 ? L.f("pay.until", Day(model.state.entitlement.trialEnd).label) : L.f("pay.expired", Launch.freeLimit))
                                .font(.headline).testID("paywall.status")
                        }
                        Divider()
                        IconRow(icon: "person.3.fill", tone: .berry) { Text(L.t("pay.unlimited")) }
                        IconRow(icon: "lock", tone: .brown) { Text(L.t("pay.keep")) }
                        IconRow(icon: "hand.raised", tone: .cream) { Text(L.t("pay.noAds")) }
                    }
                    VStack(spacing: 10) {
                        if !model.state.entitlement.purchasedPro {
                            if let product = store.pro {
                                PrimaryButton(title: L.f("pay.buy", product.displayPrice), id: "paywall.buy", icon: "lock.open") {
                                    Task { await store.buy(product, update: model.applyPurchase) }
                                }.disabled(store.busy)
                            } else if Launch.testing {
                                PrimaryButton(title: L.f("pay.buy", "US$2.99"), id: "paywall.buy", icon: "lock.open") {}.disabled(true)
                            } else {
                                PrimaryButton(title: L.t("pay.load"), id: "paywall.load", icon: "arrow.clockwise") { Task { await store.load() } }
                            }
                            if model.state.entitlement.trialClaimedAt == nil, model.hasPro {
                                SecondaryButton(title: L.t("pay.claim"), id: "paywall.claim", icon: "calendar") {
                                    if let trial = store.trial { Task { await store.buy(trial, update: model.applyPurchase) } }
                                    else { Task { await store.load() } }
                                }.disabled(store.busy)
                            }
                        }
                        SecondaryButton(title: L.t("pay.restore"), id: "paywall.restore", icon: "arrow.counterclockwise") {
                            Task { await store.restore(model.applyPurchase) }
                        }
                        .disabled(store.busy)
                        if store.busy { ProgressView() }
                        if let n = store.notice { Text(n).font(.footnote).foregroundStyle(Theme.muted).testID("paywall.notice") }
                    }
                }.padding(18)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L.t("action.close")) { model.route = nil }.testID("paywall.close") } }
            .task { await store.load() }
        }
    }
}
