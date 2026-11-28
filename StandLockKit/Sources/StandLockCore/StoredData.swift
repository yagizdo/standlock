import Foundation

/// Loads the blobs the app keeps in UserDefaults. A value this build cannot read (a case a newer
/// build added, or one damaged field) costs that value, not the whole blob, and the original bytes
/// go to `copyKey(for:)` before any save can write over them. Import stays strict: only this load
/// sets the lenient flag.
public enum StoredData {
    static let lenientKey = CodingUserInfoKey(rawValue: "StoredData.lenient")!

    public static func copyKey(for key: String) -> String { key + ".unreadable" }

    /// Strict first: a failure is the sign the bytes did not read cleanly, so they are copied,
    /// then read again with every fallback on.
    public static func load<T: Decodable>(_ type: T.Type, forKey key: String, in defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        if let value = try? JSONDecoder().decode(T.self, from: data) { return value }
        defaults.set(data, forKey: copyKey(for: key))
        let lenient = JSONDecoder()
        lenient.userInfo[lenientKey] = true
        return try? lenient.decode(T.self, from: data)
    }

    /// An array read one item at a time, so one unreadable item costs only that item.
    public static func loadEach<T: Decodable>(_ type: T.Type, forKey key: String, in defaults: UserDefaults) -> [T]? {
        load([Item<T>].self, forKey: key, in: defaults)?.compactMap(\.value)
    }

    /// A failed element does not advance an unkeyed container, so the lenient pass needs a wrapper
    /// that cannot fail. The strict pass rethrows, so the copy is still taken.
    private struct Item<T: Decodable>: Decodable {
        let value: T?

        init(from decoder: Decoder) throws {
            if decoder.readsStoredData {
                value = try? T(from: decoder)
            } else {
                value = try T(from: decoder)
            }
        }
    }
}

extension Decoder {
    /// True only while `StoredData` rereads a blob that a strict decode refused.
    var readsStoredData: Bool { userInfo[StoredData.lenientKey] as? Bool == true }
}

extension KeyedDecodingContainer {
    /// A missing key gives `fallback`; with `lenient`, so does a value this build cannot read.
    func decode<T: Decodable>(_ type: T.Type, forKey key: Key, fallback: T, lenient: Bool) throws -> T {
        if lenient { return (try? decodeIfPresent(type, forKey: key)) ?? fallback }
        return try decodeIfPresent(type, forKey: key) ?? fallback
    }
}
