import Foundation

/// Per-user candidate ranking memory, persisted outside the app bundle.
public final class Learning {
    public static let shared = Learning()

    private struct Item: Codable {
        var count: Double
        var last: Double
    }

    private var items: [String: Item] = [:]
    private var fileURL: URL?
    private var dirty = false

    public init() {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Cantainput", isDirectory: true)
        var url: URL?
        if let base {
            try? fm.createDirectory(at: base, withIntermediateDirectories: true)
            url = base.appendingPathComponent("learning.json")
        }
        fileURL = url
        load()
    }

    private func id(_ code: String, _ text: String) -> String { code + "\u{1}" + text }

    private func load() {
        guard let fileURL, let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([String: Item].self, from: data) else { return }
        items = decoded
    }

    /// Test hook: point the store at a scratch file and forget in-memory state.
    public func redirectForTesting(to url: URL) {
        fileURL = url
        items = [:]
        dirty = false
    }

    public func save() {
        guard dirty, let fileURL else { return }
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: fileURL, options: .atomic)
            dirty = false
        }
    }

    /// Ranking bonus for a candidate given what the user typed.
    public func bonus(code: String, text: String) -> Double {
        guard let item = items[id(code, text)] else { return 0 }
        let days = (Date().timeIntervalSince1970 - item.last) / 86_400.0
        let decayed = item.count * exp(-max(0, days) / 60.0)
        return min(decayed, 12.0) * 60.0
    }

    public func record(code: String, text: String) {
        guard !code.isEmpty else { return }
        let key = id(code, text)
        var item = items[key] ?? Item(count: 0, last: 0)
        item.count += 1
        item.last = Date().timeIntervalSince1970
        items[key] = item
        dirty = true
    }

    /// Frequency floor learned for a candidate, used to surface it for shorter prefixes.
    public func learnedUses(text: String) -> Double {
        var total = 0.0
        for (key, item) in items where key.hasSuffix("\u{1}" + text) {
            total += item.count
        }
        return total
    }
}
