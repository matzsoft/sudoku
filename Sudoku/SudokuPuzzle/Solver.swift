//
//  Solver.swift
//  Sudoku
//
//  Created by Mark Johnson on 9/27/22.
//

import Foundation

extension SudokuPuzzle {
    struct Solver {
        class Group {
            var theSet = Set<Int>()
            let cells:  [Cell]

            init( cells: [Cell] ) {
                self.cells = cells
                setUsed()
            }
            
            func setUsed() -> Void {
                theSet = Set( cells.compactMap { $0.solved } )
            }
            
            func addUsed( index: Int ) -> Void {
                theSet.insert( index )
                cells.filter { $0.solved == nil }.forEach { $0.penciled.remove( index ) }
            }
            
            func markConflicts() -> Void {
                let solvedCells = cells.filter { $0.solved != nil }
                let used = solvedCells.reduce( into: [ Int : Int ]() ) { $0[ $1.solved!, default: 0 ] += 1 }
                let conflicts = Set( used.filter { $0.1 > 1 }.map { $0.0 } )
                
                solvedCells.filter { conflicts.contains( $0.solved! ) }.forEach { $0.conflict = true }
            }
        }
        
        var puzzle: SudokuPuzzle
        var rows:   [Group]
        var cols:   [Group]
        var blocks: [Group]
        var groups: [Group]
        
        init( puzzle: SudokuPuzzle ) {
            let newPuzzle = SudokuPuzzle( deepCopy: puzzle )
            let grid = newPuzzle.grid
            
            rows = grid.map { Group( cells: $0 ) }
            cols = ( 0 ..< puzzle.limit ).map { col in
                Group( cells: ( 0 ..< puzzle.limit ).map { row in grid[row][col] } )
            }
            blocks = ( 0 ..< puzzle.limit ).map {
                block in Group( cells: newPuzzle.cells.filter( { $0.blockNumber == block } ) )
            }
            self.puzzle = newPuzzle
            groups = rows + cols + blocks
        }
        
        func findConflicts() -> [Cell] {
            puzzle.cells.forEach { $0.conflict = false }
            groups.forEach { $0.markConflicts() }
            return puzzle.cells.filter { $0.conflict }
        }
        
        func solve() -> Void {
            for cell in puzzle.cells {
                cell.changeable = cell.solved == nil
                if cell.solved != nil {
                    cell.penciled = Set()
                } else {
                    cell.penciled = puzzle.levelInfo.fullSet
                        .subtracting( rows[cell.row].theSet )
                        .subtracting( cols[cell.col].theSet )
                        .subtracting( blocks[cell.blockNumber].theSet )
                }
            }
            
            while let cell = puzzle.cells.first( where: { $0.penciled.count == 1 } ) {
                let index = cell.penciled.removeFirst()

                cell.solved = index
                rows[ cell.row ].addUsed( index: index )
                cols[ cell.col ].addUsed( index: index )
                blocks[ cell.blockNumber ].addUsed( index: index )
            }
            
//            let wango = groups.first(where: { })
        }
    }
}
