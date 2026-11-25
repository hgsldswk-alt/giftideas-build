import Contacts
import ContactsUI
import PhotosUI
import SwiftUI
import UIKit

struct PersonEditor: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dynamicTypeSize) private var typeSize
    let id: UUID?
    @State private var draft = Person()
    @State private var loaded = false
    @State private var hasBirthday = false
    @State private var birthday = Date()
    @State private var hasAnniversary = false
    @State private var anniversary = Date()
    @State private var code = ""
    @State private var picking = false
    @State private var confirmDelete = false

    private var isNew: Bool { id == nil }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.groupSpacing) {
                        CardGroup(note: isNew ? L.t("person.contactsNote") : nil) {
                            IconRow(icon: "person.fill") {
                                HStack(spacing: 8) {
                                    TextField(L.t("person.namePrompt"), text: $draft.name).font(.headline)
                                        .submitLabel(.done).onSubmit(save).testID("personEditor.name")
                                    Button { picking = true } label: {
                                        IconBadge(icon: "person.crop.circle.badge.plus", tone: .brown, decorative: false)
                                            .frame(width: 44, height: 44).contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain).accessibilityLabel(L.t("person.fromContacts")).testID("personEditor.contacts")
                                }
                            }
                        }
                        .id("top")
                        CardGroup(title: L.t("person.dates")) {
                            IconRow(icon: "birthday.cake", tone: .berry) {
                                Toggle(L.t("occasion.birthday"), isOn: $hasBirthday).testID("personEditor.hasBirthday")
                            }
                            if hasBirthday {
                                DatePicker(L.t("person.whichDay"), selection: $birthday, displayedComponents: .date).testID("personEditor.birthday")
                            }
                            Divider()
                            IconRow(icon: "heart", tone: .brown) {
                                Toggle(L.t("occasion.anniversary"), isOn: $hasAnniversary)
                            }
                            if hasAnniversary {
                                DatePicker(L.t("person.whichDay"), selection: $anniversary, displayedComponents: .date)
                            }
                        }
                        CardGroup(title: L.t("person.holidays"), note: L.f("person.remindNote", model.state.leadDays)) {
                            ForEach(Holiday.allCases) { h in
                                IconRow(icon: "calendar", tone: .cream) {
                                    Toggle(isOn: Binding(get: { draft.holidays.contains(h) },
                                                         set: { on in if on { draft.holidays.append(h) } else { draft.holidays.removeAll { $0 == h } } })) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(L.t("holiday." + h.rawValue))
                                            if let d = h.next(onOrAfter: model.today) {
                                                Text(d.label).font(.caption).foregroundStyle(Theme.muted)
                                            }
                                        }
                                    }
                                    .testID("personEditor.holiday." + h.rawValue)
                                }
                            }
                        }
                        CardGroup(title: L.t("person.sizes"), note: L.t("person.sizesNote")) {
                            IconRow(icon: "ruler", tone: .brown) {
                                TextField(L.t("person.sizesPrompt"), text: $draft.sizes, axis: .vertical).lineLimit(1...4)
                                    .testID("personEditor.sizes")
                            }
                        }
                        if isNew {
                            CardGroup(title: L.t("person.codeHeader")) {
                                IconRow(icon: "doc.on.clipboard", tone: .brown) {
                                    let layout = typeSize.isAccessibilitySize
                                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                                        : AnyLayout(HStackLayout(alignment: .center, spacing: 8))
                                    layout {
                                        TextField(L.t("person.codePrompt"), text: $code, axis: .vertical).lineLimit(1...3)
                                            .textInputAutocapitalization(.never).autocorrectionDisabled().testID("personEditor.code")
                                        SecondaryButton(title: L.t("person.import"), id: "personEditor.import", icon: "tray.and.arrow.down") {
                                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                            if model.importCode(code) { model.route = nil } else { withAnimation { proxy.scrollTo("top", anchor: .top) } }
                                        }
                                        .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                        .fixedSize(horizontal: true, vertical: false)
                                    }
                                }
                            }
                        } else {
                            Button(role: .destructive) { confirmDelete = true } label: {
                                Label(L.t("person.delete"), systemImage: "trash").frame(minHeight: 44)
                            }.testID("personEditor.delete")
                        }
                    }
                    .padding(18)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                PrimaryButton(title: L.t("action.done"), id: "personEditor.done", icon: "checkmark", action: save)
                    .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .padding(.horizontal, 18).padding(.vertical, 8).background(Theme.background)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(isNew ? L.t("person.newTitle") : L.t("person.editTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("action.cancel")) { model.route = nil }.testID("personEditor.cancel")
                }
            }
            .alert(L.f("person.deleteConfirm", draft.displayName), isPresented: $confirmDelete) {
                Button(L.t("action.cancel"), role: .cancel) {}
                Button(L.t("action.delete"), role: .destructive) {
                    if let id { model.deletePerson(id) }
                    model.route = nil
                }
            }
            .sheet(isPresented: $picking) {
                ContactPicker { name, bday in
                    draft.name = name
                    if let bday { hasBirthday = true; birthday = bday }
                }
                .ignoresSafeArea()
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let id, let p = model.person(id) {
            draft = p
            if let b = p.birthday { hasBirthday = true; birthday = date(b) }
            if let a = p.anniversary { hasAnniversary = true; anniversary = date(a) }
        }
    }

    private func date(_ m: MonthDay) -> Date {
        Calendar.current.date(from: DateComponents(year: 2000, month: m.month, day: m.day, hour: 12)) ?? Date()
    }

    private func save() {
        guard !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        var p = draft
        p.sizes = Transfer.cleanSizes(p.sizes)
        p.birthday = hasBirthday ? MonthDay(Day(birthday)) : nil
        p.anniversary = hasAnniversary ? MonthDay(Day(anniversary)) : nil
        model.savePerson(p)
        if model.route == .person(id) { model.route = nil }
        if isNew, model.state.index(p.id) != nil { model.path = [p.id] }
    }
}

struct ContactPicker: UIViewControllerRepresentable {
    var picked: (String, Date?) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let c = CNContactPickerViewController()
        c.delegate = context.coordinator
        return c
    }
    func updateUIViewController(_ c: CNContactPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(picked) }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let picked: (String, Date?) -> Void
        init(_ picked: @escaping (String, Date?) -> Void) { self.picked = picked }
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            let name = CNContactFormatter.string(from: contact, style: .fullName) ?? contact.givenName
            var date: Date?
            if let b = contact.birthday, let m = b.month, let d = b.day {
                date = Calendar.current.date(from: DateComponents(year: b.year ?? 2000, month: m, day: d, hour: 12))
            }
            picked(name, date)
        }
    }
}

struct IdeaEditor: View {
    @EnvironmentObject private var model: AppModel
    let personID: UUID
    let ideaID: UUID?
    @State private var draft = Idea()
    @State private var target: UUID?
    @State private var loaded = false
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var preview: UIImage?

    private var isNew: Bool { ideaID == nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.groupSpacing) {
                    CardGroup {
                        IconRow(icon: "gift.fill", tone: .berry) {
                            TextField(L.t("idea.titlePrompt"), text: $draft.title, axis: .vertical)
                                .lineLimit(1...3).font(.headline).testID("idea.title")
                        }
                        Divider()
                        IconRow(icon: "tag", tone: .cream) {
                            TextField(L.t("idea.pricePrompt"), text: $draft.price).testID("idea.price")
                        }
                        Divider()
                        IconRow(icon: "link", tone: .brown) {
                            TextField(L.t("idea.linkPrompt"), text: $draft.link).keyboardType(.URL)
                                .textInputAutocapitalization(.never).autocorrectionDisabled().testID("idea.link")
                        }
                        Divider()
                        IconRow(icon: "note.text") {
                            TextField(L.t("idea.notePrompt"), text: $draft.note, axis: .vertical).lineLimit(1...4).testID("idea.note")
                        }
                    }
                    CardGroup {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Label(preview == nil ? L.t("idea.addPhoto") : L.t("idea.changePhoto"), systemImage: "photo")
                        }
                        .buttonStyle(SecondaryActionStyle())
                        if let preview {
                            Image(uiImage: preview).resizable().scaledToFit().frame(maxHeight: 200).clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        if let url = draft.linkURL {
                            Link(destination: url) { Label(L.t("idea.openLink"), systemImage: "arrow.up.right") }
                                .buttonStyle(SecondaryActionStyle())
                        }
                    }
                    if model.state.people.count > 1 {
                        CardGroup {
                            IconRow(icon: "person.fill") {
                                HStack {
                                    Text(L.t("idea.forWhom"))
                                    Spacer(minLength: 4)
                                    Picker(L.t("idea.forWhom"), selection: Binding(get: { target ?? personID }, set: { target = $0 })) {
                                        ForEach(model.state.people) { p in Text(p.displayName).tag(p.id) }
                                    }
                                    .labelsHidden().pickerStyle(.menu).testID("idea.forWhom")
                                }
                            }
                        }
                    }
                    if !isNew, let ideaID {
                        Button(role: .destructive) {
                            model.route = nil
                            model.deleteIdea(ideaID, of: personID)
                        } label: {
                            Label(L.t("action.delete"), systemImage: "trash").frame(minHeight: 44)
                        }
                        .testID("idea.delete")
                    }
                }
                .padding(18)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                PrimaryButton(title: L.t("action.done"), id: "idea.done", icon: "checkmark") {
                    model.route = nil
                    model.saveIdea(draft, of: personID, moveTo: target, photo: photoData, isNew: isNew)
                }
                .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.horizontal, 18).padding(.vertical, 8).background(Theme.background)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(isNew ? L.t("idea.newTitle") : L.t("idea.editTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("action.cancel")) { model.route = nil }.testID("idea.cancel")
                }
            }
            .onChange(of: photoItem) { _, item in
                Task {
                    guard let data = try? await item?.loadTransferable(type: Data.self) else { return }
                    photoData = data
                    preview = UIImage(data: data)
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                if let ideaID, let i = model.person(personID)?.ideas.first(where: { $0.id == ideaID }) {
                    draft = i
                    if i.hasPhoto { preview = Photos.image(i.id) }
                } else {
                    draft = Idea(added: model.today)
                }
            }
        }
    }
}
