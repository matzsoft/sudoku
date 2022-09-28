//
//  SudokuCell.swift
//  Sudoku
//
//  Created by Mark Johnson on 8/22/22.
//

import Foundation

extension SudokuPuzzle {
    class Cell: Hashable, Identifiable {
        static func == ( lhs: SudokuPuzzle.Cell, rhs: SudokuPuzzle.Cell ) -> Bool {
            return lhs.row == rhs.row && lhs.col == rhs.col
        }
        
        func hash( into hasher: inout Hasher ) {
            hasher.combine( row )
            hasher.combine( col )
        }

        let row:         Int
        let col:         Int
        let blockRow:    Int
        let blockCol:    Int
        let blockNumber: Int
        let blockIndex:  Int
        var solved:      Int?
        var penciled =   Set<Int>()
        var fixed =      false
        var conflict =   false

        init( levelInfo: Level, solved: Int? = nil, penciled: Set<Int> = [], row: Int, col: Int ) {
            self.row         = row
            self.col         = col
            self.blockRow    = row / levelInfo.level
            self.blockCol    = col / levelInfo.level
            self.blockNumber = blockRow * levelInfo.level + blockCol
            self.blockIndex  = row % levelInfo.level * levelInfo.level + col % levelInfo.level
            self.solved      = solved
            self.penciled    = penciled
        }
        
        func speechString( puzzle: SudokuPuzzle ) -> String {
            guard let solved = solved else { return "dot" }
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
