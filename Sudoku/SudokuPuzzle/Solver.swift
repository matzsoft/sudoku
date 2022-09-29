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
        var rows:   [Group]
        var cols:   [Group]
        var blocks: [Group]
        var groups: [Group]
        
        init( puzzle: SudokuPuzzle ) {
            let newPuzzle = SudokuPuzzle( deepCopy: puzzle )
            let grid = newPuzzle.grid
            
            rows = grid.map { Group( levelInfo: puzzle.levelInfo, cells: $0 ) }
            cols = ( 0 ..< puzzle.limit ).map { col in
                Group(
                    levelInfo: puzzle.levelInfo, cells: ( 0 ..< puzzle.limit ).map { row in grid[row][col] }
                )
            }
            blocks = ( 0 ..< puzzle.limit ).map { block in
                Group(
                    levelInfo: puzzle.levelInfo,
                    cells: newPuzzle.cells.filter( { $0.blockNumber == block } )
                )
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
            // Phase 1 - Set changeable and penciled for each cell.
            for cell in puzzle.cells {
                cell.changeable = cell.solved == nil
                if cell.solved != nil {
                    cell.penciled = []
                } else {
                    cell.penciled = rows[cell.row].available
                        .intersection( cols[cell.col].available )
                        .intersection( blocks[cell.blockNumber].available )
                }
            }
            
            // Phase 2 - all cells with only one possiblity get marked as solved.
            while let cell = puzzle.cells.first( where: { $0.penciled.count == 1 } ) {
                let index = cell.penciled.removeFirst()

                markSolved( cell: cell, index: index )
            }
            
            // Phase 3 - all groups with only one position for a symbol get that cell marked solved.
            while let group = groups.first( where: { $0.firstSingleton != nil } ) {
                let candidate = group.firstSingleton!
                let cell = group.cells.first { $0.penciled.contains( candidate ) }!
                
                markSolved( cell: cell, index: candidate )
            }
        }
        
        func markSolved( cell: Cell, index: Int ) -> Void {
            cell.solved = index
            cell.penciled = []
            rows[ cell.row ].removeAvailable( index: index )
            cols[ cell.col ].removeAvailable( index: index )
            blocks[ cell.blockNumber ].removeAvailable( index: index )
        }
    }
}


extension SudokuPuzzle.Solver {
    class Group {
        var available = Set<Int>()
        let cells:      [SudokuPuzzle.Cell]

        var firstSingleton: Int? {
            available.first { candidate in
                cells.filter { $0.penciled.contains( candidate ) }.count == 1
            }
        }
        
        init( levelInfo: SudokuPuzzle.Level, cells: [SudokuPuzzle.Cell] ) {
            self.cells = cells
            setAvailable( universalSet: levelInfo.fullSet )
        }
        
        func setAvailable( universalSet: Set<Int> ) -> Void {
            available = universalSet.subtracting( Set( cells.compactMap { $0.solved } ) )
        }
        
        func removeAvailable( index: Int ) -> Void {
            available.remove( index )
            cells.filter { $0.solved == nil }.forEach { $0.penciled.remove( index ) }
        }
        
        func markConflicts() -> Void {
            let solvedCells = cells.filter { $0.solved != nil }
            let used = solvedCells.reduce( into: [ Int : Int ]() ) { $0[ $1.solved!, default: 0 ] += 1 }
            let conflicts = Set( used.filter { $0.1 > 1 }.map { $0.0 } )
            
            solvedCells.filter { conflicts.contains( $0.solved! ) }.forEach { $0.conflict = true }
        }
    }
}
