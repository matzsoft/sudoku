//
//  Solver.swift
//  Sudoku
//
//  Created by Mark Johnson on 9/27/22.
//

import Foundation

extension SudokuPuzzle {
    struct Solver {
        var puzzle: SudokuPuzzle
        
        init( puzzle: SudokuPuzzle ) {
            self.puzzle = SudokuPuzzle( deepCopy: puzzle )
        }
        
        mutating func solve() -> Void {
            for row   in 0 ..< puzzle.limit { puzzle.rows[row].setUsed() }
            for col   in 0 ..< puzzle.limit { puzzle.cols[col].setUsed() }
            for block in 0 ..< puzzle.limit { puzzle.blocks[block].setUsed() }
            for cell in puzzle.cells        { cell.changeable = cell.solved == nil }
            
            for cell in puzzle.cells {
                cell.penciled = puzzle.levelInfo.fullSet
                    .subtracting( puzzle.rows[cell.row].theSet )
                    .subtracting( puzzle.cols[cell.col].theSet )
                    .subtracting( puzzle.blocks[cell.blockNumber].theSet )
            }
            
            while let cell = puzzle.cells.first( where: { $0.solved == nil && $0.penciled.count == 1 } ) {
                let index = cell.penciled.first!
                
                cell.solved = index
                puzzle.rows[ cell.row ].addUsed( index: index )
                puzzle.cols[ cell.col ].addUsed( index: index )
                puzzle.blocks[ cell.blockNumber ].addUsed( index: index )
            }
        }
    }
}
