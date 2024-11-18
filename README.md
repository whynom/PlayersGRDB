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


## Tests to update a database and delete all `Player` records
### Update test

This added and passed immediately

``` swift
    @Test func update() throws {
        // Given a database that contains a player
        let appDatabase = try makeEmptyTestDatabase()
        var insertedPlayer = Player(name: "Arthur", score: 1000)
        try appDatabase.savePlayer(&insertedPlayer)
        
        // When we update a player
        var updatedPlayer = insertedPlayer
        updatedPlayer.name = "Barbara"
        updatedPlayer.score = 0
        try appDatabase.savePlayer(&updatedPlayer)
        
        // Then the player is updated
        let fetchedPlayer = try appDatabase.reader.read(Player.fetchOne)
        #expect(fetchedPlayer == updatedPlayer)
    }
```

### Delete All test

Here we run into a bit of a snafu because haven't defined `delteAllPlayers`
``` swift
    @Test func deleteAll() throws {
        // Given a database that contains a player
        let appDatabase = try makeEmptyTestDatabase()
        var player = Player(name: "Arthur", score: 1000)
        try appDatabase.savePlayer(&player)
        
        // When we delete all players
        try appDatabase.deleteAllPlayers() //Value of type 'AppDatabase' has no member 'deleteAllPlayers'
        
        // Then no player exists
        let count = try appDatabase.reader.read(Player.fetchCount(_:))
        #expect(count == 0)
    }
```

So, all we have to do is add it to our `AppDatabase` type in the extension code block that has `savePlayer`

``` swift
extension AppDatabase {
    
    ...

    /// Delete all players
    func deleteAllPlayers() throws {
        try dbWriter.write { db in
            _ = try Player.deleteAll(db)
        }
    }
}
```


## `PlayerListModel` and its tests
### The testing helper functions

These functions will be used in our tests for the `PlayerListModel`.  The first just makes an empty database and the second `pullUntil` keeps checking for an outcome that runs asynchronously to see if the outcome is ever accomplished.

``` swift
    /// Return an empty, in-memory, `AppDatabase`.
    private func makeEmptyTestDatabase() throws -> AppDatabase {
        let dbQueue = try DatabaseQueue(configuration: AppDatabase.makeConfiguration())
        return try AppDatabase(dbQueue)
    }

    /// Convenience method that loops until a condition is met.
    private func pollUntil(condition: @escaping @MainActor () async -> Bool) async throws {
        try await confirmation { confirmation in
            while true {
                if await condition() {
                    confirmation()
                    return
                } else {
                    try await Task.sleep(for: .seconds(0.01))
                }
            }
        }
    }
```
### The `observation_grabs_current_database_state` test

This tests to make sure the observer looking for changes in the database indeed sees the change in the database.  It has a very unsurprising error in the test because we haven't made our `PlayerListModel` yet.

``` swift
    @Test(.timeLimit(.minutes(1)))
    @MainActor func observation_grabs_current_database_state() async throws {
        // Given a PlayerListModel on a database that contains one player
        let appDatabase = try makeEmptyTestDatabase()
        var player = Player(name: "Arthur", score: 1000)
        try appDatabase.savePlayer(&player)
        let model = PlayerListModel(appDatabase: appDatabase) /// Cannot find 'PlayerListModel' in scope
        
        // When the model starts observing the database
        model.observePlayers()
        
        // Then the model eventually has one player.
        try await pollUntil { model.players.count == 1 }
    }
```

### The `PlayerListModel`

Generally speaking, when I'm breaking down a demo like this, I like to add the minimal amount of copying of code to get whatever step I'm at working.  I do this so that when I get to another step and things break, I can add more code to the original model and see exactly what it does and where it works.  In this case, I want to add the minimal amount of code necessary to pass this test.

``` swift
    @Test(.timeLimit(.minutes(1)))
    @MainActor func observation_grabs_current_database_state() async throws {
        // Given a PlayerListModel on a database that contains one player
        let appDatabase = try makeEmptyTestDatabase()
        var player = Player(name: "Arthur", score: 1000)
        try appDatabase.savePlayer(&player)
        let model = PlayerListModel(appDatabase: appDatabase) /// Cannot find 'PlayerListModel' in scope
        
        // When the model starts observing the database
        model.observePlayers()
        
        // Then the model eventually has one player.
        try await pollUntil { model.players.count == 1 }
    }
```

We aren't quite passing the test yet, but we've gotten rid of the first error we encountered because this type now initializes with an `AppDatabase`.  It doesn't do anything with it but there error is gone.  Unsurprisingly, we get two new errors popping up in our test.

``` swift
    @Test(.timeLimit(.minutes(1)))
    @MainActor func observation_grabs_current_database_state() async throws {
        // Given a PlayerListModel on a database that contains one player
        let appDatabase = try makeEmptyTestDatabase()
        var player = Player(name: "Arthur", score: 1000)
        try appDatabase.savePlayer(&player)
        let model = PlayerListModel(appDatabase: appDatabase) 
        
        // When the model starts observing the database
        model.observePlayers() // Value of type 'PlayerListModel' has no member 'observePlayers'
        
        // Then the model eventually has one player.
        try await pollUntil { model.players.count == 1 } //Value of type 'PlayerListModel' has no member 'players'
    }
```

### `observePlayesrs` function
Let's take care of that first one by adding `observePlayers`.  Whenever the `ordering` variable changes, we fetch the updated database, of course, the problem is we don't have `ordering` in our `PlayerListModel` yet.  Let's take care of that.

``` swift
    /// Start observing the database.
    func observePlayers() {
        // We observe all players, sorted according to `ordering`.
        let observation = ValueObservation.tracking { [ordering] db in
            switch ordering {
            case .byName:
                try Player.all().orderedByName().fetchAll(db)
            case .byScore:
                try Player.all().orderedByScore().fetchAll(db)
            }
        }
        
        // Start observing the database.
        // Previous observation, if any, is cancelled.
        cancellable = observation.start(in: appDatabase.reader) { error in
            // Handle error
        } onChange: { [unowned self] players in
            self.players = players
        }
    }
```

This does get rid of our error in the test because we've added `obervePlayers` but now this function has a lot of errors itself because it's calling several things that don't exist yet in our minimal `PlayerListModel`

#### Ordering
Firstly, let's add the `Ordering` enum and the computed variable `ordering`.  Whenever the `ordering` variable changes the `observePlayers` function runs.

``` swift
    enum Ordering {
        case byName
        case byScore
    }
    
    /// The player ordering
    var ordering = Ordering.byScore {
        didSet { observePlayers() }
    }
```

#### The `players` array
This is the array in which we store all `players` whenever we update our database with the `observePlayers` function.

``` swift
    /// The players.
    ///
    /// The array remains empty until `observePlayers()` is called.
    var players: [Player] = []
```

#### The `orderedByName` and `orderedByScore` functions
We ended up extending the `DerivableRequest` protocol to get access to these functions in project.  I'm not really super familiar with the protocol, but it looks like it's having to do with databases. We put this in our `Player` file because that's what the demo app did and seems like a pretty logical way to organize everything.

``` swift
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
```

With this we run into a lot of errors having to do with the fact that we haven't defined `Columns` yet, so let's do so.  It's just an alias to make things a little easier to read.

``` swift
// Convenience access to player columns in this file
private typealias Columns = Player.Columns
```

#### Cancellable
Finally, we never added the `cancellable` variable because it never popped up an error until now.   Here it is.

``` swift
    @ObservationIgnored private var cancellable: AnyDatabaseCancellable?
```

#### Finally, everything looks good.
Our test is passing so we've slayed this dragon.  One last showing of our completed `PlayerListModel`, `Player.swift` file as it is and our `PlayerListModelTests`.

`PlayerListModel`
``` swift
import Foundation
import GRDB

@Observable @MainActor final class PlayerListModel {
    
    private let appDatabase: AppDatabase
    
    init(appDatabase: AppDatabase) {
        self.appDatabase = appDatabase
    }
    
    enum Ordering {
        case byName
        case byScore
    }
    
    /// The player ordering
    var ordering = Ordering.byScore {
        didSet { observePlayers() }
    }
    
    
    /// The players.
    ///
    /// The array remains empty until `observePlayers()` is called.
    var players: [Player] = []
    
    @ObservationIgnored private var cancellable: AnyDatabaseCancellable?

    /// Start observing the database.
    func observePlayers() {
        // We observe all players, sorted according to `ordering`.
        let observation = ValueObservation.tracking { [ordering] db in
            switch ordering {
            case .byName:
                try Player.all().orderedByName().fetchAll(db)
            case .byScore:
                try Player.all().orderedByScore().fetchAll(db)
            }
        }
        
        // Start observing the database.
        // Previous observation, if any, is cancelled.
        cancellable = observation.start(in: appDatabase.reader) { error in
            // Handle error
        } onChange: { [unowned self] players in
            self.players = players
        }
    }
}
```

`Player`
``` swift
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
```

`PlayerListModelTests`
``` swift
import Testing
import GRDB
@testable import PlayersGRDB

struct PlayerListModelTests {

    @Test(.timeLimit(.minutes(1)))
    @MainActor func observation_grabs_current_database_state() async throws {
        // Given a PlayerListModel on a database that contains one player
        let appDatabase = try makeEmptyTestDatabase()
        var player = Player(name: "Arthur", score: 1000)
        try appDatabase.savePlayer(&player)
        let model = PlayerListModel(appDatabase: appDatabase)
        
        // When the model starts observing the database
        model.observePlayers()
        
        // Then the model eventually has one player.
        try await pollUntil { model.players.count == 1 }
    }
    
    
    /// Return an empty, in-memory, `AppDatabase`.
    private func makeEmptyTestDatabase() throws -> AppDatabase {
        let dbQueue = try DatabaseQueue(configuration: AppDatabase.makeConfiguration())
        return try AppDatabase(dbQueue)
    }

    /// Convenience method that loops until a condition is met.
    private func pollUntil(condition: @escaping @MainActor () async -> Bool) async throws {
        try await confirmation { confirmation in
            while true {
                if await condition() {
                    confirmation()
                    return
                } else {
                    try await Task.sleep(for: .seconds(0.01))
                }
            }
        }
    }
}
```
