//
//  Group.swift
//  Sudoku
//
//  Created by Mark Johnson on 10/24/22.
//

import Foundation

extension SudokuPuzzle.Solver {
    // There are many places in the Solver where rows, columns, and blocks are treated equivalently.
    // So the Group class is used to represent them.  Additionally Group supports the available property,
    // the set of values still available to be distributed.
    class Group: CustomStringConvertible {
        enum GroupType: String { case row, col = "column", block }
        
        let type:       GroupType
        var available = Set<Int>()
        let cells:      [SudokuPuzzle.Cell]

        var unsolved: [SudokuPuzzle.Cell] { cells.filter { $0.solved == nil } }
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
            unsolved.forEach { $0.penciled.remove( index ) }
        }
        
        func removeAvailable( index: Int, exceptions: [SudokuPuzzle.Cell] ) -> Void {
            unsolved.filter { !exceptions.contains( $0 ) }.forEach { $0.penciled.remove( index ) }
        }
        
        func markConflicts() -> Void {
            let solvedCells = cells.filter { $0.solved != nil }
            let used = solvedCells.reduce( into: [ Int : Int ]() ) { $0[ $1.solved!, default: 0 ] += 1 }
            let conflicts = Set( used.filter { $0.1 > 1 }.map { $0.0 } )
            
            solvedCells.filter { conflicts.contains( $0.solved! ) }.forEach { $0.conflict = true }
        }
        
        func validate() throws -> Void {
            let unsolved = unsolved
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
}

extension Array<SudokuPuzzle.Solver.Group> {
    func findDoublets( minimum: Int ) -> [ Int : [[SudokuPuzzle.Cell]] ] {
        reduce( into: [ Int : [[SudokuPuzzle.Cell]] ]() ) { dict, group in
            group.available.forEach { candidate in
                let matches = group.cells.filter { $0.penciled.contains( candidate ) }
                if matches.count == 2 {
                    dict[ candidate, default: [] ].append( matches )
                }
            }
        }.filter { $0.value.count >= minimum }
    }
}
