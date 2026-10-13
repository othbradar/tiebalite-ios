#if DEBUG
actor FavoriteFixtureRepository: FavoriteRepositoryProtocol {
    private var values: [String: [ThreadFavorite]] = [:]
    private var fails = false
    func replace(_ entries: [ThreadFavorite], account: String = "9") { values[account] = entries }
    func setFailure(_ value: Bool) { fails = value }
    func page(offset: Int, account: String) async throws -> FavoritePage {
        if fails { throw FavoriteFailure.invalidData }
        let entries = values[account] ?? []
        return .init(entries: Array(entries.dropFirst(offset).prefix(20)), nextOffset: offset + 20 < entries.count ? offset + 20 : nil)
    }
    func save(_ entry: ThreadFavorite, account: String) async throws {
        if fails { throw FavoriteFailure.rejected(4) }
        values[account, default: []].removeAll { $0.id == entry.id }
        values[account, default: []].insert(entry, at: 0)
    }
    func remove(_ threadID: Int64, account: String) async throws {
        if fails { throw FavoriteFailure.rejected(4) }
        values[account, default: []].removeAll { $0.id == threadID }
    }
}
#endif
