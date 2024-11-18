//
//  PlayerListModelTests.swift
//  PlayersGRDBTests
//
//  Created by ynom on 11/18/24.
//

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
