import Foundation

struct DeckDoc: Codable, Identifiable {
    var id: UUID
    var title: String
    var text: String
    var updated: Date
}

/// 文档存储：落在 UserDefaults，关掉 App 也还在
final class NotesStore {

    static let shared = NotesStore()

    private let key = "pocketdeck.docs.v1"
    private(set) var docs: [DeckDoc] = []

    private init() {
        load()
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let list = try? JSONDecoder().decode([DeckDoc].self, from: data),
           !list.isEmpty {
            docs = list
            return
        }
        docs = [
            DeckDoc(id: UUID(), title: "欢迎",
                    text: "用手机滑动移动光标，轻点一下就是单击。\n\n点到窗口标题栏上按住再滑动，就能拖窗口。\n\n点手机上的「键盘」，打出来的字会进到这篇笔记里。",
                    updated: Date())
        ]
        save()
    }

    func save() {
        if let data = try? JSONEncoder().encode(docs) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func doc(_ id: UUID?) -> DeckDoc? {
        guard let id else { return nil }
        return docs.first(where: { $0.id == id })
    }

    @discardableResult
    func create(title: String = "未命名", text: String = "") -> DeckDoc {
        let doc = DeckDoc(id: UUID(), title: title, text: text, updated: Date())
        docs.insert(doc, at: 0)
        save()
        return doc
    }

    func update(_ id: UUID, text: String? = nil, title: String? = nil) {
        guard let index = docs.firstIndex(where: { $0.id == id }) else { return }
        if let text { docs[index].text = text }
        if let title { docs[index].title = title }
        docs[index].updated = Date()
        save()
    }

    func append(_ id: UUID, _ text: String) {
        guard let index = docs.firstIndex(where: { $0.id == id }) else { return }
        docs[index].text += text
        docs[index].updated = Date()
        save()
    }

    func backspace(_ id: UUID) {
        guard let index = docs.firstIndex(where: { $0.id == id }), !docs[index].text.isEmpty else { return }
        docs[index].text.removeLast()
        docs[index].updated = Date()
        save()
    }

    func remove(_ id: UUID) {
        docs.removeAll { $0.id == id }
        save()
    }

    /// 列表按更新时间倒序
    func sorted() -> [DeckDoc] {
        docs.sorted { $0.updated > $1.updated }
    }
}
