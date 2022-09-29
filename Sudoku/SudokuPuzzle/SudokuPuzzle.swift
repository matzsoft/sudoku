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
    static let empty = SudokuPuzzle( levelInfo: Level( level: 0, label: "Empty" ) )
    
    let levelInfo: Level
    let level:     Int
    let limit:     Int
    let grid:      [[Cell]]
    
    var cells: [Cell] { grid.flatMap { $0 } }
    
    var asString: String {
        grid.map { row -> String in
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
        
        grid = ( 0 ..< levelInfo.limit ).map { row in
            ( 0 ..< levelInfo.limit ).map { col in
                Cell( levelInfo: levelInfo, row: row, col: col )
            }
        }
    }
    
    init( deepCopy from: SudokuPuzzle ) {
        levelInfo = from.levelInfo
        level = from.level
        limit = from.limit
        
        grid = from.grid.map { row in
            row.map { cell in
                Cell(
                    levelInfo: from.levelInfo, solved: cell.solved, penciled: cell.penciled,
                    row: cell.row, col: cell.col
                )
            }
        }
    }
    
    func markConflicts( conflicts: [Cell] ) -> Int {
        cells.forEach { $0.conflict = false }
        conflicts.forEach { grid[$0.row][$0.col].conflict = true }
        return conflicts.count
    }
}
