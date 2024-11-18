import GRDB

struct Player: Equatable {
    var id: Int64?
    var name: String
    var score: Int
}

extension Player: Codable, FetchableRecord, MutablePersistableRecord {
    enum Columns {
        static let name = Column(CodingKeys.name)
        static let score = Column(CodingKeys.score)
    }
    
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

// Convenience access to player columns in this file
private typealias Columns = Player.Columns

extension DerivableRequest<Player> {
    func orderedByName() -> Self {
        order(Columns.name.collating(.localizedCaseInsensitiveCompare))
    }
    
    func orderedByScore() -> Self {
        order(
            Columns.score.desc,
            Columns.name.collating(.localizedCaseInsensitiveCompare))
    }
}
