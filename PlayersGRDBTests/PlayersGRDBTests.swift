//
//  PlayersGRDBTests.swift
//  PlayersGRDBTests
//
//  Created by ynom on 11/12/24.
//

import Testing
import GRDB
@testable import PlayersGRDB

struct PlayersGRDBTests {

    @Test func example() async throws {
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
    }

    /// Return an empty, in-memory, `AppDatabase`.
    private func makeEmptyTestDatabase() throws -> AppDatabase {
        let dbQueue = try DatabaseQueue(configuration: AppDatabase.makeConfiguration())
        return try AppDatabase(dbQueue)
    }
}
