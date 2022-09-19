//
//  SudokuPuzzle.swift
//  Sudoku
//
//  Created by Mark Johnson on 8/22/22.
//

import Foundation
import AppKit
import SwiftUI

struct SudokuPuzzle {
    static let supportedLevels = [
        Level( level: 3, label: "9x9" ),
        Level( level: 4, label: "16x16" )
    ]
    
    let levelInfo: Level
    let level: Int
    let limit: Int
    let rows: [[Cell]]
    
    var cells: [Cell] { rows.flatMap { $0 } }
    var penciledCount: Int { cells.map { $0.penciled.count }.reduce( 0, + ) }
    
    var asString: String {
        rows.map { row -> String in
            let line = row.map { cell -> Character in
                cell.solved == nil ? "." : ( levelInfo.symbol( from: cell.solved! ) ?? "." )
            }
            return String( line )
        }.joined( separator: "\n" ) + "\n"
    }
    
    init( levelInfo: Level ) {
        self.levelInfo = levelInfo
        level = levelInfo.level
        limit = levelInfo.limit
        
        rows = ( 0 ..< levelInfo.limit ).map { row in
            ( 0 ..< levelInfo.limit ).map { col in
                Cell( levelInfo: levelInfo, row: row, col: col )
            }
        }
    }
}
