# Remaking the GRDB demo app

The GRDB Players demo app is fantastic for learning the basics of GRDB.  Going through it helped me a lot but for me to really understand the demo app (not all of GRDB) I felt like rebuilding it step by step would be very helpful.  I'm attempting to rebuild it by commits so that each commit adds another step so one can go through by commit and understand each piece.

This readme will also attempt to explain to some degree each step, especially ones that confused me.

The best place to start is always the beginnig.

---

## The basics
### The first thing we need is a test we want to pass.

``` swift
import Testing
import GRDB
@testable import PlayersGRDB

struct PlayersGRDBTests {

    @Test func insert() throws {
        // Given an empty database
        let appDatabase = try makeEmptyTestDatabase()

        // When we insert a player
        var insertedPlayer = Player(name: "Arthur", score: 1000)
        try appDatabase.savePlayer(&insertedPlayer)

        // Then the inserted player has an id
        #expect(insertedPlayer.id != nil)

        // Then the inserted player exists in the database
        let fetchedPlayer = try appDatabase.reader.read(Player.fetchOne)

        #expect(fetchedPlayer == insertedPlayer)

    }

    /// Return an empty, in-memory, `AppDatabase`.
    private func makeEmptyTestDatabase() throws -> AppDatabase {
        let dbQueue = try DatabaseQueue(configuration: AppDatabase.makeConfiguration())
        return try AppDatabase(dbQueue)
    }
}
```

This just tests that we can make an empty database and insert a record into it.

Of course just adding that to our tests files, pretty much every one of those lines will fail, so let's attempt to start getting rid of those errors.

### The beginnings of the =AppDatabase= class.

``` swift
import Foundation
import GRDB

final class AppDatabase: Sendable {

    private let dbWriter: any DatabaseWriter

    init(_ dbWriter: any GRDB.DatabaseWriter) throws {
        self.dbWriter = dbWriter
        try migrator.migrate(dbWriter)
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

#if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
#endif

        migrator.registerMigration("v1") { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("score", .integer).notNull()
            }
        }

        return migrator
    }
}
```

### AppDatabase =makeConfiguration= function

``` swift
extension AppDatabase {
    static func makeConfiguration(_ config: Configuration = Configuration()) -> Configuration {
        return config
    }
}
```

###  `Player` model

``` swift
import GRDB

struct Player: Equatable {
    var id: Int64?
    var name: String
    var score: Int
}
```

### Necessary player conformance

In our first test, we wish to be able to save a player to our database, so we need the type to conform to `Codable` `FetchableRecord` and `MutablePersistableRecord`.  This also defines our table columns and gives us the `didInsert` function.

``` swift
extension Player: Codable, FetchableRecord, MutablePersistableRecord {
    enum Columns {
        static let name = Column(CodingKeys.name)
        static let score = Column(CodingKeys.score)
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
```

### Last error to clear, we need a reader

``` swift
let fetchedPlayer = try appDatabase.reader.read(Player.fetchOne) // Value of type 'AppDatabase' has no member 'reader'
```

``` swift
private func makeEmptyTestDatabase() throws -> AppDatabase {
    let dbQueue = try DatabaseQueue(configuration: AppDatabase.makeConfiguration())
    return try AppDatabase(dbQueue)
}
```

### Our tests pass
Our original tests are now passing and we've gained the following capabilities:

1. Make a (empty) database
``` swift
let appDatabase = try makeEmptyTestDatabase()
```

2. Insert a record
``` swift
var insertedPlayer = Player(name: "Arthur", score: 1000)
```

3. Save a record
``` swift
try appDatabase.savePlayer(&insertedPlayer)
```

4. Read a record
``` swift
let fetchedPlayer = try appDatabase.reader.read(Player.fetchOne)
```


---
