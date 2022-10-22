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
        
        func solve() throws -> Bool {
            while true {
                let solvedCount   = puzzle.solvedCount
                let penciledCount = puzzle.penciledCount
                var isStuck: Bool {
                    solvedCount == puzzle.solvedCount && penciledCount == puzzle.penciledCount
                }

                // Phase 1 - mark as solved all cells with only one possiblity.
                try onePossiblity()
                if puzzle.isSolved { return true }
                
                // Phase 2 - mark as solved all cells that have the only occurance of a symbol in its group.
                try onlyOccurrence()
                if puzzle.isSolved { return true }

                // Phase 3 - find sets of n cells that have identical penciled sets with n members.
                try findIdenticalSets()

                // Phase 4 - cross reference blocks against rows and columns.
                try crossReference()

                // Phase 5 - process subsets of the available symbols within each group.
                if isStuck { try handleSubsets() }

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
        func onePossiblity() throws -> Void {
            while let cell = puzzle.cells.first( where: { $0.penciled.count == 1 } ) {
                try markSolved( cell: cell, index: cell.penciled.first! )
            }
        }
        
        // Mark as solved all cells that are unique, within one of its groups, in containing a
        // specific symbol.  Since finding one of these can create others, keep looping until there
        // are no more.
        func onlyOccurrence() throws -> Void {
            while let group = groups.first( where: { $0.firstSingleton != nil } ) {
                let candidate = group.firstSingleton!
                let cell = group.cells.first { $0.penciled.contains( candidate ) }!
                
                try markSolved( cell: cell, index: candidate )
            }
        }
        
        // Any group that has a set of cells with identical penciled sets are checked to see if the
        // number of cells is equal to the count of the penciled sets.  If so, those values can be
        // removed from the penciled sets of all the other cells in the group.  Since the corrective
        // action does not negate the condition for that group we only loop through the groups once.
        // Also note that no cells will be marked solved by this action.
        func findIdenticalSets() throws -> Void {
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
                try validate()
            }
        }
        
        // Any block that has all its occurences of a symbol within a single row (or column) means
        // that all occurences of that symbol can be removed from the other cells in the row (or
        // column).  Conversely any row (or column) that has all its occurences of a symbol within
        // a single block means that all occurences of that symbol can be removed from the other cells
        // in the block.  To avoid infinite loops, we loop once through the blocks and once through
        // all the rows and columns.  Also note that no cells will be marked solved by this action.
        func crossReference() throws -> Void {
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
        // from those cells.  This is an expensive operation so it is only performed when other methods
        // are not advancing the solution.  Also note that no cells will be marked solved by this action.
        func handleSubsets() throws -> Void {
            for group in groups {
                for subset in group.generateSubsets() {
                    let unsolved = group.cells.filter { $0.solved == nil }
                    let lonely = unsolved.filter { $0.penciled.subtracting( subset ).isEmpty }
                    if lonely.count == subset.count {
                        unsolved.filter { !lonely.contains( $0 ) }.forEach { $0.penciled.subtract( subset ) }
                    }
                    
                    let crowded = unsolved.filter { !$0.penciled.intersection( subset ).isEmpty }
                    if crowded.count == subset.count {
                        crowded.forEach { $0.penciled.formIntersection( subset ) }
                    }
                }
                try validate()
            }
        }
    }
}


extension SudokuPuzzle.Solver {
    // There are many places in the Solver where rows, columns, and blocks are treated equivalently.
    // So the Group class is used to represent them.  Additionally Group supports the available property,
    // the set of values still available to be distributed.
    class Group: CustomStringConvertible {
        enum GroupType: String { case row, col = "column", block }
        
        let type:       GroupType
        var available = Set<Int>()
        let cells:      [SudokuPuzzle.Cell]

        var description: String {
            switch type {
            case .row:
                return "row \(cells[0].row+1)"
            case .col:
                return "column \(cells[0].col+1)"
            case .block:
                return "block \(cells[0].blockNumber+1)"
            }
        }
        
        var firstSingleton: Int? {
            available.first { candidate in
                cells.filter { $0.penciled.contains( candidate ) }.count == 1
            }
        }
        
        init( _ type: GroupType, levelInfo: SudokuPuzzle.Level, cells: [SudokuPuzzle.Cell] ) {
            self.type  = type
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
        
        func validate() throws -> Void {
            let unsolved = cells.filter { $0.solved == nil }
            if available.count < unsolved.count {
                throw SolverError.excessAvailable( self ) }
            if available.count > unsolved.count {
                throw SolverError.insufficientAvailable( self ) }
            
            let penciled = unsolved.reduce( Set<Int>() ) { $0.union( $1.penciled ) }
            if available.count < penciled.count {
                throw SolverError.excessPencilled( self ) }
            if available.count > penciled.count {
                throw SolverError.insufficientPencilled( self ) }
            if available != penciled {
                throw SolverError.inconsistentPencilled( self ) }
        }
        
        func generateSubsets() -> [Set<Int>] {
            guard available.count > 2 else { return [] }
            return ( 2 ..< available.count ).flatMap { size in
                generateSubsets( size: size, subset: Set<Int>(), candidates: available )
            }
        }
        
        func generateSubsets( size: Int, subset: Set<Int>, candidates: Set<Int> ) -> [Set<Int>] {
            guard subset.count < size else { return [subset] }
            var result = [Set<Int>]()
            var remaining = candidates

            while !remaining.isEmpty {
                let next = remaining.removeFirst()
                result.append(
                    contentsOf: generateSubsets(
                        size: size, subset: subset.union( Set( [ next ] ) ), candidates: remaining
                    )
                )
            }

            return result
        }
    }
    
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
