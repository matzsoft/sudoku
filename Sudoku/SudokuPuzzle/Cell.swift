//
//  SudokuCell.swift
//  Sudoku
//
//  Created by Mark Johnson on 8/22/22.
//

import Foundation

extension SudokuPuzzle {
    class Cell: Hashable, Identifiable, CustomStringConvertible {
        let row:         Int
        let col:         Int
        let boxRow:      Int
        let boxCol:      Int
        let box:         Int
        let boxIndex:    Int
        var solved:      Int?
        var penciled =   Set<Int>()
        var changeable = false
        var conflict =   false
        var canSee:      Set<Cell>?

        var description: String { "cell[\(row+1),\(col+1)]" }

        init( levelInfo: Level, solved: Int? = nil, penciled: Set<Int> = [], row: Int, col: Int ) {
            self.row         = row
            self.col         = col
            self.boxRow      = row / levelInfo.level
            self.boxCol      = col / levelInfo.level
            self.box         = boxRow * levelInfo.level + boxCol
            self.boxIndex    = row % levelInfo.level * levelInfo.level + col % levelInfo.level
            self.solved      = solved
            self.penciled    = penciled
        }
        
        static func == ( lhs: SudokuPuzzle.Cell, rhs: SudokuPuzzle.Cell ) -> Bool {
            return lhs.row == rhs.row && lhs.col == rhs.col
        }
        
        func hash( into hasher: inout Hasher ) {
            hasher.combine( row )
            hasher.combine( col )
        }
        
        func speechString( puzzle: SudokuPuzzle ) -> String {
            guard let solved = solved else { return conflict ? "unknown" : "dot" }
            guard let character = puzzle.levelInfo.symbol( from: solved ) else { return "dot" }
            return String( character )
        }
    }
}

extension Array: Identifiable where Element: Hashable {
    public var id: Int {
        self[0].hashValue
    }
}
