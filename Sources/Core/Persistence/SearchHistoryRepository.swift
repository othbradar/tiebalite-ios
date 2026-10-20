import Foundation

protocol SearchHistoryRepository: Sendable {
    func load() async -> [String]
    func record(_ keyword: SearchKeyword) async -> [String]
    func clear() async -> [String]
}

/// Device-local recent keywords only; no results, accounts or credentials are persisted.
actor LocalSearchHistoryRepository: SearchHistoryRepository {
    private static let key = "dev.tiebalite.search.forum-history.v1"
    private let persists: Bool
    private let suiteName: String?
    private var memory: [String] = []

    init(persists: Bool = false, suiteName: String? = nil) {
        self.persists = persists
        self.suiteName = suiteName
    }

    func load() -> [String] {
        let values = persists ? defaults.stringArray(forKey: Self.key) ?? [] : memory
        var seen = Set<String>()
        return Array(values.compactMap { SearchKeyword($0)?.rawValue }.filter { seen.insert($0).inserted }.prefix(20))
    }

    func record(_ keyword: SearchKeyword) -> [String] {
        save(Array(([keyword.rawValue] + load().filter { $0 != keyword.rawValue }).prefix(20)))
    }

    func clear() -> [String] { save([]) }

    private func save(_ values: [String]) -> [String] {
        memory = values
        if persists { defaults.set(values, forKey: Self.key) }
        return values
    }

    private var defaults: UserDefaults {
        suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }
}
