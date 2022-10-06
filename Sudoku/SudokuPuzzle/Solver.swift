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
        
        // Make a copy of the input puzzle.  Set up the rows, cols, blocks, and groups arrays.
        // Set up the invariants that will be maintained throughout the solution process.
        // Namely all cells in the puzzle copy are set as follows:
        // For cells marked solved - mark it as not changeable and empty its penciled set.
        // For cells not yet solved = mark it as changeable and set the pencilled set from the available
        // sets of all the groups to which it belongs.
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
            
            // Set changeable and penciled for each cell.
            for cell in self.puzzle.cells {
                cell.changeable = cell.solved == nil
                if cell.solved != nil {
                    cell.penciled = []
                } else {
                    cell.penciled = rows[cell.row].available
                        .intersection( cols[cell.col].available )
                        .intersection( blocks[cell.blockNumber].available )
                }
            }
        }
        
        func findConflicts() -> [Cell] {
            puzzle.cells.forEach { $0.conflict = false }
            groups.forEach { $0.markConflicts() }
            return puzzle.cells.filter { $0.conflict }
        }
        
        func solve() -> Bool {
            while true {
                let oldSolvedCount   = puzzle.solvedCount
                let oldPenciledCount = puzzle.penciledCount
                
                // Phase 1 - mark as solved all cells with only one possiblity.
                onePossiblity()
                if puzzle.isSolved { return true }
                
                // Phase 2 - mark as solved all cells that have the only occurance of a symbol in its group.
                onlyOccurrence()
                if puzzle.isSolved { return true }

                // Phase 3 - find sets of n cells that have identical penciled sets with n members.
                findIdenticalSets()

                // Phase 4 - cross reference blocks against rows and columns.
                crossReference()

                // If no progess was made this loop then give up.
                if oldSolvedCount == puzzle.solvedCount && oldPenciledCount == puzzle.penciledCount {
                    return false
                }
            }
        }
        
        // Mark a cell as solved with a specific value.  This also includes emptying the penciled set
        // and reducing the available sets in all the relevant groups.
        func markSolved( cell: Cell, index: Int ) -> Void {
            cell.solved = index
            cell.penciled = []
            rows[ cell.row ].removeAvailable( index: index )
            cols[ cell.col ].removeAvailable( index: index )
            blocks[ cell.blockNumber ].removeAvailable( index: index )
        }
        
        // Mark all cells that have only a single member of the penciled set as solved.
        // Since finding one of these can create others, keep looping until there are no more.
        func onePossiblity() -> Void {
            while let cell = puzzle.cells.first( where: { $0.penciled.count == 1 } ) {
                markSolved( cell: cell, index: cell.penciled.first! )
            }
        }
        
        // Mark as solved all cells that are unique, within one of its groups, in containing a
        // specific symbol.  Since finding one of these can create others, keep looping until there
        // are no more.
        func onlyOccurrence() -> Void {
            while let group = groups.first( where: { $0.firstSingleton != nil } ) {
                let candidate = group.firstSingleton!
                let cell = group.cells.first { $0.penciled.contains( candidate ) }!
                
                markSolved( cell: cell, index: candidate )
            }
        }
        
        // Any group that has a set of cells with identical penciled sets are checked to see if the
        // number of cells is equal to the count of the penciled sets.  If so, those values can be
        // removed from the penciled sets of all the other cells in the group.  Since the corrective
        // action does not negate the condition for that group we only loop through the groups once.
        // Also note that no cells will be marked solved by this action.
        func findIdenticalSets() -> Void {
            for group in groups {
                let universal = Set( group.cells )
                var remaining = universal
                
                while let candidate = remaining.first?.penciled {
                    let matches = group.cells.filter { $0.penciled == candidate }

                    if matches.count == candidate.count {
                        universal.subtracting( matches ).forEach { $0.penciled.subtract( candidate ) }
                    }
                    remaining.subtract( matches )
                }
            }
        }
        
        // Any block that has all its occurences of a symbol within a single row (or column) means
        // that all occurences of that symbol can be removed from the other cells in the row (or
        // column).  Conversely any row (or column) that has all its occurences of a symbol within
        // a single block means that all occurences of that symbol can be removed from the other cells
        // in the block.  To avoid infinite loops, we loop once through the blocks and once through
        // all the rows and columns.  Also note that no cells will be marked solved by this action.
        func crossReference() -> Void {
            // Cross reference each block against the rows and columns.
            for block in blocks {
                for candidate in block.available {
                    let cells = block.cells.filter { $0.penciled.contains( candidate ) }
                    let row   = cells[0].row
                    let col   = cells[0].col
                    
                    if cells.allSatisfy( { $0.row == row } ) {
                        rows[row].cells.filter { !cells.contains( $0 ) }.forEach {
                            $0.penciled.remove( candidate )
                        }
                    }
                    if cells.allSatisfy( { $0.col == col } ) {
                        cols[col].cells.filter { !cells.contains( $0 ) }.forEach {
                            $0.penciled.remove( candidate )
                        }
                    }
                }
            }
            
            // Cross reference each row and column against the blocks.
            for group in rows + cols {
                for candidate in group.available {
                    let cells = group.cells.filter { $0.penciled.contains( candidate ) }
                    let block = cells[0].blockNumber
                    
                    if cells.allSatisfy( { $0.blockNumber == block } ) {
                        blocks[block].cells.filter { !cells.contains( $0 ) }.forEach {
                            $0.penciled.remove( candidate )
                        }
                    }
                }
            }
        }
    }
}


extension SudokuPuzzle.Solver {
    // There are many places in the Solver where rows, columns, and blocks are treated equivalently.
    // So the Group class is used to represent them.  Additionally Group supports the available property,
    // the set of values still available to be distributed.
    class Group {
        var available = Set<Int>()
        let cells:      [SudokuPuzzle.Cell]

        var firstSingleton: Int? {
            available.first { candidate in
                cells.filter { $0.penciled.contains( candidate ) }.count == 1
            }
        }
        
        var pairs: [ Set<Int> ] {
            let list = Array( available )
            guard list.count > 1 else { return [] }
            
            return ( 0 ... list.count - 2 ).flatMap { first in
                ( first ... list.count - 1 ).map { second in
                    Set( [ list[first], list[second] ] )
                }
            }
        }
        
        var firstPair: Set<Int>? {
            pairs.first { pair in cells.filter { $0.penciled == pair }.count == 2 }
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
