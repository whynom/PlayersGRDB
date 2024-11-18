//
//  PlayerListModel.swift
//  PlayersGRDB
//
//  Created by ynom on 11/18/24.
//

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
