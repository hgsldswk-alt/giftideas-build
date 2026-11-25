import SwiftUI
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(Theme.background)
        Task { await show() }
    }

    private func show() async {
        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        let title = items.compactMap { $0.attributedContentText?.string }.first { !$0.isEmpty }
        var url: URL?
        var text: String?
        for p in items.flatMap({ $0.attachments ?? [] }) {
            if url == nil, p.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                url = await load(p, UTType.url) as? URL
            }
            if text == nil, p.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                text = await load(p, UTType.plainText) as? String
            }
        }
        let state = Store.load() ?? AppState()
        let today = Day.today
        let host = UIHostingController(rootView: ShareSaveView(
            draft: ShareParse.draft(title: title, url: url, text: text),
            people: state.sorted(today),
            onSave: { draft, personID in Self.save(draft, to: personID, today: today) },
            onCancel: { [weak self] in self?.extensionContext?.completeRequest(returningItems: nil) }))
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }

    static func save(_ draft: ShareParse.Draft, to personID: UUID, today: Day) {
        var state = Store.load() ?? AppState()
        var idea = Idea(title: draft.title, price: draft.price, link: draft.link, added: today)
        if idea.linkURL == nil { idea.link = "" }
        state.addIdea(idea, to: personID)
        try? Store.save(state)
    }

    private func load(_ p: NSItemProvider, _ type: UTType) async -> NSSecureCoding? {
        await withCheckedContinuation { done in
            p.loadItem(forTypeIdentifier: type.identifier, options: nil) { item, _ in done.resume(returning: item) }
        }
    }
}
