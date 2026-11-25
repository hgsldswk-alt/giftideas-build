import Foundation

enum Transfer {
    static let prefix = "GFT1:"
    static let maxIdeas = 100
    static let maxSizes = 300

    static func cleanSizes(_ s: String) -> String {
        String(s.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxSizes))
    }

    struct Item: Codable, Equatable { var t: String; var p: String?; var u: String? }
    struct Payload: Codable, Equatable { var n: String; var i: [Item]; var s: String? = nil }

    static func code(for person: Person, onlyWanted: Bool = true) -> String {
        let src = onlyWanted ? person.wanted : person.ideas
        let items = src.prefix(maxIdeas).map { Item(t: $0.title, p: $0.price.isEmpty ? nil : $0.price, u: $0.linkURL?.absoluteString) }
        let data = (try? JSONEncoder().encode(Payload(n: person.name, i: Array(items), s: Self.cleanSizes(person.sizes).isEmpty ? nil : Self.cleanSizes(person.sizes)))) ?? Data()
        return prefix + data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }

    static func person(from text: String, today: Day = .today) throws -> Person {
        guard let r = text.range(of: prefix) else { throw GiftError.badCode }
        var body = String(text[r.upperBound...].prefix { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") })
        guard !body.isEmpty, body.count < 60_000 else { throw GiftError.badCode }
        body = body.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while body.count % 4 != 0 { body += "=" }
        guard let data = Data(base64Encoded: body), let p = try? JSONDecoder().decode(Payload.self, from: data) else {
            throw GiftError.badCode
        }
        let name = String(p.n.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        guard !name.isEmpty else { throw GiftError.badCode }
        var person = Person(name: name)
        person.holidays = []
        person.sizes = cleanSizes(p.s ?? "")
        for item in p.i.prefix(maxIdeas) {
            let title = String(item.t.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
            guard !title.isEmpty else { continue }
            var idea = Idea(title: title, price: String((item.p ?? "").prefix(20)), added: today)
            let link = String((item.u ?? "").prefix(500))
            idea.link = link
            if idea.linkURL == nil { idea.link = "" }
            person.ideas.append(idea)
        }
        return person
    }
}

enum ShareParse {
    struct Draft: Equatable { var title = ""; var price = ""; var link = "" }

    static func draft(title: String?, url: URL?, text: String?) -> Draft {
        var d = Draft()
        let body = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if let url, ["http", "https"].contains(url.scheme?.lowercased() ?? "") { d.link = url.absoluteString }
        if d.link.isEmpty, let found = firstURL(in: body) { d.link = found.absoluteString }
        let lines = body.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && firstURL(in: $0)?.absoluteString != $0 }
        let raw = (title?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? lines.first ?? ""
        d.title = cleanTitle(raw)
        if d.title.isEmpty, let host = URL(string: d.link)?.host { d.title = host.replacingOccurrences(of: "www.", with: "") }
        d.price = price(in: [title ?? "", body].joined(separator: "\n")) ?? ""
        return d
    }

    static func cleanTitle(_ s: String) -> String {
        var t = s.replacingOccurrences(of: #"https?://\S+"#, with: "", options: .regularExpression)
        for sep in [" | ", " - ", " – ", " — ", "：", " :: "] {
            if let r = t.range(of: sep, options: .backwards) {
                let tail = t[r.upperBound...].lowercased()
                if tail.count <= 24, ["amazon", "walmart", "target", "etsy", "ebay", "best buy", ".com", "淘宝", "天猫", "京东", "拼多多", "楽天", "shop", "store"].contains(where: { tail.contains($0) }) {
                    t = String(t[..<r.lowerBound])
                }
            }
        }
        t = t.replacingOccurrences(of: #"^(Amazon\.com\s*:\s*)"#, with: "", options: [.regularExpression, .caseInsensitive])
        t = t.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
        return String(t.prefix(80))
    }

    static func price(in s: String) -> String? {
        let patterns = [
            #"(?:US\$|CA\$|A\$|HK\$|NT\$|\$|¥|￥|€|£)\s?\d{1,3}(?:[,，]\d{3})*(?:[.,]\d{1,2})?"#,
            #"\d{1,3}(?:[,，]\d{3})*(?:\.\d{1,2})?\s?(?:元|円|块)"#
        ]
        for p in patterns {
            if let r = s.range(of: p, options: .regularExpression) {
                return String(s[r]).replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "，", with: ",")
            }
        }
        return nil
    }

    static func firstURL(in s: String) -> URL? {
        guard let det = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let ns = s as NSString
        return det.matches(in: s, range: NSRange(location: 0, length: ns.length))
            .compactMap(\.url).first { ["http", "https"].contains($0.scheme?.lowercased() ?? "") }
    }
}

enum CSVExport {
    static func text(_ state: AppState, today: Day) -> String {
        var rows = [["Person", "Idea", "Price", "Link", "Note", "Status", "Added", "Bought for"]]
        for p in state.people {
            for i in p.ideas {
                let status = i.boughtFor == nil ? "wanted" : i.given(on: today) ? "given" : "bought"
                rows.append([p.name, i.title, i.price, i.link, i.note, status, i.added.iso, i.boughtFor?.iso ?? ""])
            }
        }
        return "\u{FEFF}" + rows.map { $0.map(cell).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
    }

    static func cell(_ s: String) -> String {
        var v = s
        if let f = v.first, "=+-@\t\r".contains(f) { v = "'" + v }
        if v.contains(where: { ",\"\n\r".contains($0) }) { v = "\"" + v.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        return v
    }
}
