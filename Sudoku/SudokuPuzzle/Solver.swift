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
        // For cells not yet solved = mark it as changeable and set the penciled set from the available
        // sets of all the groups to which it belongs.
        init( puzzle: SudokuPuzzle ) {
            let newPuzzle = SudokuPuzzle( deepCopy: puzzle )
            let grid = newPuzzle.grid
            
            rows = grid.map { Group( .row, levelInfo: puzzle.levelInfo, cells: $0 ) }
            cols = ( 0 ..< puzzle.limit ).map { col in
                Group(
                    .col, levelInfo: puzzle.levelInfo,
                    cells: ( 0 ..< puzzle.limit ).map { row in grid[row][col] }
                )
            }
            blocks = ( 0 ..< puzzle.limit ).map { block in
                Group(
                    .block, levelInfo: puzzle.levelInfo,
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
        
        func validate() throws -> Void {
            for group in groups { try group.validate() }
        }
        
        // Note - I have found SudokuWiki.org to be a great resource for sample puzzles that illustrate
        // the various strategies.  They also have good explanations.  So I have decided to adopt their
        // nomenclature.
        func solve() throws -> Bool {
            while true {
                let solvedCount   = puzzle.solvedCount
                let penciledCount = puzzle.penciledCount
                var isStuck: Bool {
                    solvedCount == puzzle.solvedCount && penciledCount == puzzle.penciledCount
                }

                // Phase 1 - mark as solved all cells with only one possiblity.
                try nakedSingles()
                if puzzle.isSolved { return true }
                
                // Phase 2 - mark as solved all cells that have the only occurance of a symbol in its group.
                try hiddenSingles()
                if puzzle.isSolved { return true }

                // Phase 3 - process subsets of the available symbols within each group.
                try nakedAndHiddenSubsets()

                // Phase 4 - cross reference blocks against rows and columns.
                try intersectionRemoval()

                // Phase 5 - the X-Wing strategy.
                if isStuck { try xWing() }
                
                // Phase 6 - the Swordfish strategy.
                if isStuck { try swordfish() }

                // If no progess was made this loop then give up.
                if isStuck { return false }
            }
        }
        
        // Mark a cell as solved with a specific value.  This also includes emptying the penciled set
        // and reducing the available sets in all the relevant groups.
        func markSolved( cell: Cell, index: Int ) throws -> Void {
            cell.solved = index
            cell.penciled = []
            rows[ cell.row ].removeAvailable( index: index )
            cols[ cell.col ].removeAvailable( index: index )
            blocks[ cell.blockNumber ].removeAvailable( index: index )
            
            try validate()
        }
        
        // Mark all cells that have only a single member of the penciled set as solved.
        // Since finding one of these can create others, keep looping until there are no more.
        func nakedSingles() throws -> Void {
            while let cell = puzzle.cells.first( where: { $0.penciled.count == 1 } ) {
                try markSolved( cell: cell, index: cell.penciled.first! )
            }
        }
        
        // Mark as solved all cells that are unique, within one of its groups, in containing a
        // specific symbol.  Since finding one of these can create others, keep looping until there
        // are no more.
        func hiddenSingles() throws -> Void {
            while let group = groups.first( where: { $0.firstSingleton != nil } ) {
                let candidate = group.firstSingleton!
                let cell = group.cells.first { $0.penciled.contains( candidate ) }!
                
                try markSolved( cell: cell, index: candidate )
            }
        }
        
        // Any block that has all its occurences of a symbol within a single row (or column) means
        // that all occurences of that symbol can be removed from the other cells in the row (or
        // column).  Conversely any row (or column) that has all its occurences of a symbol within
        // a single block means that all occurences of that symbol can be removed from the other cells
        // in the block.  To avoid infinite loops, we loop once through the blocks and once through
        // all the rows and columns.  Also note that no cells will be marked solved by this action.
        func intersectionRemoval() throws -> Void {
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
                try validate()
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
                try validate()
            }
        }
        
        // For each group, examine all proper subsets of the available symbols with more than 1 element.
        // When a subset of n symbols has n unsolved cells with only elements of that subset, the other
        // unsolved cells can have the elements of the subset removed.  When a subset of n symbols has
        // only n unsolved cells that contain elements of the subset, all other symbols can be removed
        // from those cells.  Also note that no cells will be marked solved by this action.
        func nakedAndHiddenSubsets() throws -> Void {
            for group in groups {
                let unsolved = group.unsolved
                for subset in group.generateSubsets( upperBound: unsolved.count / 2 ) {
                    let naked = unsolved.filter { $0.penciled.subtracting( subset ).isEmpty }
                    if naked.count == subset.count {
                        unsolved.filter { !naked.contains( $0 ) }.forEach { $0.penciled.subtract( subset ) }
                    }
                    
                    let hidden = unsolved.filter { !$0.penciled.intersection( subset ).isEmpty }
                    if hidden.count == subset.count {
                        hidden.forEach { $0.penciled.formIntersection( subset ) }
                    }
                }
                try validate()
            }
        }
        
        // The X-Wing strategy involves finding 4 Cells that form the corners of a rectangle that meet
        // certain criteria.  All four must contain the same symbol.  Either the top and bottom rows of
        // the rectangle contain the only 2 occurances of the symbol or the left and right columns of the
        // rectangle contain the only 2 occurances of the symbol.  If the criteria are met, then the rows
        // and columns that bound the rectangle can be cleared of all other occurances of the symbol.
        // This is an expensive operation so it is only performed when other methods are not advancing
        // the solution.  Also note that no cells will be marked solved by this action.
        func xWing() throws -> Void {
            try xWingRows()
            try xWingCols()
            try validate()
        }
        
        func xWingRows() throws -> Void {
            let pairs = rows.findDoublets( minimum: 2 )
            let relavent = pairs.reduce( into: [ Int : [[[Cell]]] ]() ) { dict, pair in
                let ( candidate, list ) = pair
                list.subsequences( size: 2 ).filter {
                    $0[0][0].col == $0[1][0].col && $0[0][1].col == $0[1][1].col
                }.forEach {
                    dict[ candidate, default: [] ].append( $0 )
                }
            }
            for ( candidate, list ) in relavent {
                list.forEach{ corners in
                    cols[ corners[0][0].col ].removeAvailable(
                        index: candidate, exceptions: [ corners[0][0], corners[1][0] ]
                    )
                    cols[ corners[0][1].col ].removeAvailable(
                        index: candidate, exceptions: [ corners[0][1], corners[1][1] ]
                    )
                }
            }
        }
        
        func xWingCols() throws -> Void {
            let pairs = cols.findDoublets( minimum: 2 )
            let relavent = pairs.reduce( into: [ Int : [[[Cell]]] ]() ) { dict, pair in
                let ( candidate, list ) = pair
                list.subsequences( size: 2 ).filter {
                    $0[0][0].row == $0[1][0].row && $0[0][1].row == $0[1][1].row
                }.forEach {
                    dict[ candidate, default: [] ].append( $0 )
                }
            }
            for ( candidate, list ) in relavent {
                list.forEach{ corners in
                    rows[ corners[0][0].row ].removeAvailable(
                        index: candidate, exceptions: [ corners[0][0], corners[1][0] ]
                    )
                    rows[ corners[0][1].row ].removeAvailable(
                        index: candidate, exceptions: [ corners[0][1], corners[1][1] ]
                    )
                }
            }
        }
        
        // The Swordfish strategy involves finding a symbol that meets certain criteria.  There must
        // be 3 rows that contain only 2 occurances of that symbol.  The cells with the symbol must
        // also share columns such that the 1st and 2nd rows share a column, the 1st and 3rd rows share
        // a column, and the 2nd and 3rd rows share a column.  If the criteria are met, then the 3
        // columns can be cleared of all other occurances of the symbol.  This is an expensive operation
        // so it is only performed when other methods are not advancing the solution.  Also note that
        // no cells will be marked solved by this action.
        func swordfish() throws -> Void {
            let pairs = rows.findDoublets( minimum: 3 )
            let relavent = pairs.reduce( into: [ Int : [[[Cell]]] ]() ) { dict, pair in
                let ( candidate, list ) = pair
                list.subsequences( size: 3 ).filter {
                    $0[0][0].col == $0[1][0].col &&         // x    x
                    $0[0][1].col == $0[2][0].col &&         // x         x
                    $0[1][1].col == $0[2][1].col ||         //      x    x
                    
                    $0[0][0].col == $0[1][0].col &&         // x         x
                    $0[0][1].col == $0[2][1].col &&         // x    x
                    $0[1][1].col == $0[2][0].col ||         //      x    x
                    
                    $0[0][0].col == $0[2][0].col &&         // x    x
                    $0[0][1].col == $0[1][0].col &&         //      x    x
                    $0[1][1].col == $0[2][1].col ||         // x         x
                    
                    $0[0][0].col == $0[2][0].col &&         // x         x
                    $0[0][1].col == $0[1][1].col &&         //      x    x
                    $0[1][0].col == $0[2][1].col ||         // x    x
                    
                    $0[0][0].col == $0[2][1].col &&         //      x    x
                    $0[0][1].col == $0[1][1].col &&         // x         x
                    $0[1][0].col == $0[2][0].col ||         // x    x
                    
                    $0[0][0].col == $0[1][1].col &&         //      x    x
                    $0[0][1].col == $0[2][1].col &&         // x    x
                    $0[1][0].col == $0[2][0].col            // x         x
                }.forEach {
                    dict[ candidate, default: [] ].append( $0 )
                }
            }
            for ( candidate, list ) in relavent {
                list.forEach { rowSet in
                    let rowIndices = rowSet.reduce( into: Set<Int>() ) { $0.insert( $1[0].row ) }
                    let colIndices = rowSet.reduce( into: Set<Int>() ) { $0.insert( $1[0].col ) }
                    colIndices.forEach { colIndex in
                        cols[colIndex].unsolved.filter { !rowIndices.contains( $0.row ) }.forEach {
                            $0.penciled.remove( candidate )
                        }
                    }
                }
            }
            try validate()
        }
    }
}


extension SudokuPuzzle.Solver {    
    enum SolverError: Error, CustomStringConvertible {
        case excessAvailable( Group )
        case insufficientAvailable( Group )
        case excessPencilled( Group )
        case insufficientPencilled( Group )
        case inconsistentPencilled( Group )
        
        var description: String {
            switch self {
            case .excessAvailable( let group ):
                return "Too many symbols left in the available set for \(group)."
            case .insufficientAvailable( let group ):
                return "Not enough symbols left in the available set for \(group)."
            case .excessPencilled( let group ):
                return "The available set is smaller than the penciled union for \(group)."
            case .insufficientPencilled( let group ):
                return "The available set is larger than the penciled union for \(group)."
            case .inconsistentPencilled( let group ):
                return "The available set and penciled union for \(group)."
            }
        }
    }
}


extension Array {
    func subsequences( size: Int ) -> [[Element]] {
        subsequences( size: size, subsequence: [] )
    }
    
    func subsequences( size: Int, subsequence: [Element] ) -> [[Element]] {
        guard subsequence.count < size else { return [subsequence] }
        var result = [[Element]]()
        var remaining = self

        while !remaining.isEmpty {
            let next = remaining.removeFirst()
            let newSubsequence = remaining.subsequences( size: size, subsequence: subsequence + [next] )
            result.append( contentsOf: newSubsequence )
        }

        return result
    }
}
