//
//  Solver.swift
//  Sudoku
//
//  Created by Mark Johnson on 9/27/22.
//

import Foundation

extension SudokuPuzzle {
    class Solver {
        var puzzle:        SudokuPuzzle
        var rows:          [Group]
        var cols:          [Group]
        var boxes:         [Group]
        var groups:        [Group]
        var solvedCount:   Int
        var penciledCount: Int

        var strategies = [Strategy]()

        // Make a copy of the input puzzle.  Set up the rows, cols, boxes, and groups arrays.
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
            boxes = ( 0 ..< puzzle.limit ).map { box in
                Group(
                    .box, levelInfo: puzzle.levelInfo,
                    cells: newPuzzle.cells.filter( { $0.box == box } )
                )
            }
            self.puzzle = newPuzzle
            groups = rows + cols + boxes
            
            // Set changeable and penciled for each cell.
            for cell in self.puzzle.cells {
                cell.changeable = cell.solved == nil
                if cell.solved != nil {
                    cell.penciled = []
                } else {
                    cell.penciled = rows[cell.row].available
                        .intersection( cols[cell.col].available )
                        .intersection( boxes[cell.box].available )
                }
                cell.canSee = Set( rows[cell.row].cells + cols[cell.col].cells + boxes[cell.box].cells ).subtracting( [ cell ] )
            }

            solvedCount   = self.puzzle.solvedCount
            penciledCount = self.puzzle.penciledCount

            strategies = [
                Strategy( "Naked Singles",            nakedSingles,         canSolve: true, restart: false ),
                Strategy( "Hidden Singles",           hiddenSingles,        canSolve: true                 ),
                Strategy( "Naked and Hidden Subsets", nakedAndHiddenSubsets                                ),
                Strategy( "Intersection Removal",     intersectionRemoval                                  ),
                Strategy( "X-Wing",                   xWing                                                ),
                Strategy( "Swordfish",                swordfish                                            ),
                Strategy( "Y-Wing",                   yWing                                                ),
                Strategy( "Single's Chains",          singlesChains                                        ),
            ]
        }
        
        func markProgress() -> Void {
            solvedCount   = puzzle.solvedCount
            penciledCount = puzzle.penciledCount
        }
        
        var madeProgress: Bool {
            solvedCount != puzzle.solvedCount || penciledCount != puzzle.penciledCount
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
            repeat {
                markProgress()
                for strategy in strategies {
                    try strategy.method()
                    if strategy.canSolve && puzzle.isSolved { return true }
                    if strategy.restart && madeProgress { break }
                }
            } while madeProgress
            return false
        }
        
        // Mark a cell as solved with a specific value.  This also includes emptying the penciled set
        // and reducing the available sets in all the relevant groups.
        func markSolved( cell: Cell, index: Int ) throws -> Void {
            cell.solved = index
            cell.penciled = []
            rows[ cell.row ].removeAvailable( index: index )
            cols[ cell.col ].removeAvailable( index: index )
            boxes[ cell.box ].removeAvailable( index: index )
            
            try validate()
        }
    }
}


extension SudokuPuzzle.Solver {
    struct Strategy {
        let label:    String
        let method:   () throws -> Void
        let canSolve: Bool
        let restart:  Bool

        init(
            _ label: String, _ method: @escaping () throws -> Void,
            canSolve: Bool = false, restart: Bool = true
        ) {
            self.label    = label
            self.method   = method
            self.canSolve = canSolve
            self.restart  = restart
        }
    }
    
    enum SolverError: Error, CustomStringConvertible {
        case excessAvailable( Group )
        case insufficientAvailable( Group )
        case excessPencilled( Group )
        case insufficientPencilled( Group )
        case inconsistentPencilled( Group )
        case inconsistentBiLocation( Set<SudokuPuzzle.Cell> )
        
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
            case .inconsistentBiLocation( let set ):
                let list = Array( set )
                return "Inconsistent bi-location link between \(list[0]) and \(list[1])."
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
