import SwiftUI

struct PersonView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let id: UUID

    var body: some View {
        if let p = model.person(id) {
            List {
                Section {
                    header(p).personListRow()
                }
                Section {
                    if p.wanted.isEmpty {
                        HeroCard {
                            Text(L.t("person.noWanted")).font(.subheadline).foregroundStyle(Theme.muted).testID("person.noWanted")
                        }
                        .personListRow()
                    }
                    ForEach(Array(p.wanted.enumerated()), id: \.element.id) { i, idea in
                        IdeaRow(idea: idea, done: false, id: "want.\(i)") { model.toggleBought(idea.id, of: p.id) } open: { model.route = .idea(p.id, idea.id) }
                            .personListRow()
                            .swipeActions { delete(idea, p) }
                    }
                    PrimaryButton(title: L.t("person.addIdea"), id: "person.addIdea", icon: "plus") {
                        model.route = .idea(p.id, nil)
                    }
                    .personListRow()
                } header: { SectionTitle(title: L.t("person.wanted")) }
                let waiting = p.waiting(model.today)
                if !waiting.isEmpty {
                    Section {
                        ForEach(Array(waiting.enumerated()), id: \.element.id) { i, idea in
                            IdeaRow(idea: idea, done: true, id: "bought.\(i)") { model.toggleBought(idea.id, of: p.id) } open: { model.route = .idea(p.id, idea.id) }
                                .personListRow()
                                .swipeActions { delete(idea, p) }
                        }
                    } header: { SectionTitle(title: L.t("person.waiting")) }
                }
                let given = p.given(model.today)
                if !given.isEmpty {
                    Section {
                        ForEach(given, id: \.year) { g in
                            VStack(alignment: .leading, spacing: 10) {
                                StatusPill(text: String(g.year), tone: .brown, icon: "calendar")
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(g.ideas) { idea in
                                        IconRow(icon: "gift.fill", tone: .brown) {
                                            HStack(spacing: 8) {
                                                Text(idea.title).font(.subheadline)
                                                Spacer(minLength: 0)
                                                Button { model.again(idea.id, of: p.id) } label: {
                                                    IconBadge(icon: "arrow.uturn.backward", circular: true, decorative: false)
                                                        .frame(width: 44, height: 44).contentShape(Rectangle())
                                                }.buttonStyle(.borderless).accessibilityLabel(L.t("idea.again"))
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(12).card().personListRow()
                            .testID("given.\(g.year)")
                        }
                    } header: { SectionTitle(title: L.t("person.given")) } footer: { Text(L.t("person.givenNote")) }
                }
                Section {
                    VStack(spacing: 10) {
                        ShareLink(item: L.f("transfer.hint", p.displayName) + "\n" + Transfer.code(for: p)) {
                            Label(L.t("person.sendFamily"), systemImage: "person.2")
                        }
                        .buttonStyle(SecondaryActionStyle()).testID("person.send")
                        SecondaryButton(title: L.t("person.shareCard"), id: "person.shareCard", icon: "square.and.arrow.up") {
                            model.route = .shareCard
                        }
                    }
                    .personListRow()
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(Theme.groupSpacing)
            .textCase(nil)
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { model.route = .person(p.id) } label: {
                        Label(L.t("action.edit"), systemImage: "pencil")
                    }.testID("person.edit")
                }
            }
        } else {
            VStack(spacing: 14) {
                EmptyIllustration()
                Text(L.t("person.gone")).foregroundStyle(Theme.muted)
                PrimaryButton(title: L.t("action.close"), id: "person.gone.close", icon: "chevron.backward") {
                    dismiss()
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background.ignoresSafeArea())
        }
    }

    private func header(_ p: Person) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Avatar(person: p, size: 48)
                Text(p.displayName).font(.title2.bold()).testID("person.title").accessibilityAddTraits(.isHeader)
            }
            if let o = p.nextOccasion(from: model.today) {
                let d = model.today.days(until: o.day)
                DaysChip(days: d, text: o.kind.name + " · " + o.day.monthDayLabel + " · " + DaysChip.label(d)).testID("person.next")
            } else {
                SecondaryButton(title: L.t("person.setDate"), id: "person.setDate", icon: "calendar.badge.plus") {
                    model.route = .person(p.id)
                }
            }
            let sizes = p.sizes.trimmingCharacters(in: .whitespacesAndNewlines)
            if !sizes.isEmpty {
                Button { model.route = .person(p.id) } label: {
                    IconRow(icon: "ruler", tone: .brown) {
                        Text(sizes).font(.footnote).foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.leading).lineLimit(3)
                    }
                }
                .buttonStyle(.plain).accessibilityLabel(L.t("person.sizes") + " " + sizes).testID("person.sizes")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func delete(_ idea: Idea, _ p: Person) -> some View {
        Button(role: .destructive) { model.deleteIdea(idea.id, of: p.id) } label: { Label(L.t("action.delete"), systemImage: "trash") }
    }
}

struct IdeaRow: View {
    let idea: Idea
    let done: Bool
    let id: String
    var toggle: () -> Void
    var open: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button(action: toggle) {
                IconBadge(icon: done ? "checkmark.circle.fill" : "circle", tone: done ? .olive : .berry, decorative: false)
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(done ? L.t("idea.unmark") : L.t("idea.markBought"))
            .testID(id + ".toggle")
            HStack(alignment: .top, spacing: 10) {
                if idea.hasPhoto, let img = Photos.image(idea.id) {
                    Image(uiImage: img).resizable().scaledToFill().frame(width: 38, height: 38)
                        .clipShape(RoundedRectangle(cornerRadius: 10)).accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(idea.title).font(.body.weight(.semibold)).strikethrough(done, color: Theme.muted).testID(id + ".title")
                    Text(sub).font(.footnote).foregroundStyle(Theme.muted).lineLimit(2)
                    StatusPill(text: done ? L.t("idea.statusBought") : L.t("idea.statusWanted"), tone: done ? .olive : .berry)
                }
                Spacer(minLength: 0)
                if !idea.price.isEmpty {
                    Text(idea.price).font(.subheadline.weight(.semibold)).monospacedDigit()
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .onTapGesture(perform: open)
        }
        .padding(10)
        .card()
    }

    private var sub: String {
        if done, let b = idea.boughtOn { return L.f("idea.boughtOn", b.monthDayLabel) }
        let parts = [idea.note.isEmpty ? nil : idea.note, idea.host].compactMap { $0 }
        return parts.isEmpty ? L.f("idea.addedOn", idea.added.monthDayLabel) : parts.joined(separator: " · ")
    }
}

private extension View {
    func personListRow() -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
    }
}
