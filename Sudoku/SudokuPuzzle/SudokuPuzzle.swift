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
    struct Group {
        var theSet = Set<Int>()
        let cells: [Cell]
        
        mutating func setUsed() -> Void {
            theSet = Set( cells.compactMap { $0.solved } )
        }
        
        mutating func addUsed( index: Int ) -> Void {
            theSet.insert( index )
            cells.filter { $0.solved == nil }.forEach { $0.penciled.remove( index ) }
        }
    }
    
    static let supportedLevels = [
        Level( level: 3, label: "9x9" ),
        Level( level: 4, label: "16x16" )
    ]
    static let empty = SudokuPuzzle( levelInfo: Level( level: 0, label: "Empty" ) )
    
    let levelInfo: Level
    let level:     Int
    let limit:     Int
    let grid:      [[Cell]]
    var rows:      [Group]
    var cols:      [Group]
    var blocks:    [Group]
    
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
        
        let grid = ( 0 ..< levelInfo.limit ).map { row in
            ( 0 ..< levelInfo.limit ).map { col in
                Cell( levelInfo: levelInfo, row: row, col: col )
            }
        }
        let cells = grid.flatMap { $0 }
        
        self .grid = grid
        rows = ( 0 ..< levelInfo.limit ).map {
            row in Group( cells: cells.filter( { $0.row == row } ) )
        }
        cols = ( 0 ..< levelInfo.limit ).map {
            col in Group( cells: cells.filter( { $0.col == col } ) )
        }
        blocks = ( 0 ..< levelInfo.limit ).map {
            block in Group( cells: cells.filter( { $0.blockNumber == block } ) )
        }
    }
    
    init( deepCopy from: SudokuPuzzle ) {
        levelInfo = from.levelInfo
        level = from.level
        limit = from.limit
        
        let grid = from.grid.map { row in
            row.map { cell in
                Cell(
                    levelInfo: from.levelInfo, solved: cell.solved, penciled: cell.penciled,
                    row: cell.row, col: cell.col
                )
            }
        }
        let cells = grid.flatMap { $0 }
        
        self .grid = grid
        rows = ( 0 ..< levelInfo.limit ).map {
            row in Group( cells: cells.filter( { $0.row == row } ) )
        }
        cols = ( 0 ..< levelInfo.limit ).map {
            col in Group( cells: cells.filter( { $0.col == col } ) )
        }
        blocks = ( 0 ..< levelInfo.limit ).map {
            block in Group( cells: cells.filter( { $0.blockNumber == block } ) )
        }
    }
    
    func markConflicts() -> Int {
        cells.forEach { $0.conflict = false }
        rows.forEach { markConflicts( group: $0 ) }
        cols.forEach { markConflicts( group: $0 ) }
        blocks.forEach { markConflicts( group: $0 ) }
        return cells.filter { $0.conflict }.count
    }
    
    func markConflicts( group: Group ) -> Void {
        let solvedCells = group.cells.filter { $0.solved != nil }
        let used = solvedCells.reduce( into: [ Int : Int ]() ) { $0[ $1.solved!, default: 0 ] += 1 }
        let conflicts = Set( used.filter { $0.1 > 1 }.map { $0.0 } )
        
        solvedCells.filter { conflicts.contains( $0.solved! ) }.forEach { $0.conflict = true }
    }
}
