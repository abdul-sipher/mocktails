import Foundation

/// A du'a, dhikr or verse with its source. `excerpt` marks text that is
/// part of a longer verse or supplication.
struct Dua: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let arabic: String
    let transliteration: String
    let meaning: String
    let reference: String
    let excerpt: Bool
    var category: String?
    /// Adhkar only: which set, and how many times.
    var set: String?
    var count: Int?
}

enum DuaCategory: String, CaseIterable, Identifiable {
    case distress, anger, forgiveness, knowledge, parents, travel, sleep, gratitude, illness, daily

    var id: String { rawValue }

    var title: String {
        switch self {
        case .distress:    return "Anxiety and distress"
        case .anger:       return "Anger"
        case .forgiveness: return "Forgiveness"
        case .knowledge:   return "Knowledge"
        case .parents:     return "Parents"
        case .travel:      return "Travel"
        case .sleep:       return "Sleep"
        case .gratitude:   return "Gratitude"
        case .illness:     return "Illness"
        case .daily:       return "Daily needs"
        }
    }

    var symbol: String {
        switch self {
        case .distress:    return "heart.text.square"
        case .anger:       return "flame"
        case .forgiveness: return "hands.sparkles"
        case .knowledge:   return "book"
        case .parents:     return "figure.2.and.child.holdinghands"
        case .travel:      return "airplane"
        case .sleep:       return "moon.zzz"
        case .gratitude:   return "sun.max"
        case .illness:     return "cross.case"
        case .daily:       return "sparkles"
        }
    }
}

enum AdhkarSet: String, CaseIterable, Identifiable {
    case afterSalah, morningEvening
    var id: String { rawValue }
    var title: String { self == .afterSalah ? "After salah" : "Morning and evening" }
}

/// Bundled du'as and adhkar (Resources/Duas.json), drafted for scholar review.
struct DuaLibrary {
    let duas: [Dua]
    let adhkar: [Dua]
    let status: String

    private struct File: Codable {
        let status: String
        let duas: [Dua]
        let adhkar: [Dua]
    }

    static func load(bundle: Bundle = .main) -> DuaLibrary {
        guard let url = bundle.url(forResource: "Duas", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data)
        else { return DuaLibrary(duas: [], adhkar: [], status: "") }
        return DuaLibrary(duas: file.duas, adhkar: file.adhkar, status: file.status)
    }

    func duas(in category: DuaCategory) -> [Dua] { duas.filter { $0.category == category.rawValue } }
    func adhkar(in set: AdhkarSet) -> [Dua] { adhkar.filter { $0.set == set.rawValue } }
    func dua(id: String) -> Dua? { (duas + adhkar).first { $0.id == id } }
}

/// Favourite du'a ids, on this watch.
enum DuaFavourites {
    static let key = "duaFavourites.v1"

    static func load(from d: UserDefaults = AppGroup.defaults) -> Set<String> {
        Set(d.stringArray(forKey: key) ?? [])
    }

    static func save(_ ids: Set<String>, to d: UserDefaults = AppGroup.defaults) {
        d.set(Array(ids).sorted(), forKey: key)
    }
}
