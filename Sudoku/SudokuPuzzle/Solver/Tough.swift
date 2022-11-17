//
//  Tough.swift
//  Sudoku
//
//  Created by Mark Johnson on 11/17/22.
//  Contains the Tough Solver strategies.
//

import Foundation

extension SudokuPuzzle.Solver {
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
        let pairs = rows.findClusters( of: 2 ... 2, minimumCount: 2 )
        let relavent = pairs.reduce( into: [ Int : [[[SudokuPuzzle.Cell]]] ]() ) { dict, pair in
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
        let pairs = rows.findClusters( of: 2 ... 2, minimumCount: 2 )
        let relavent = pairs.reduce( into: [ Int : [[[SudokuPuzzle.Cell]]] ]() ) { dict, pair in
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
    // be 3 rows that contain 2 or 3 occurances of that symbol.  The cells with the symbol must
    // also share columns such that all the cells (there will be between 6 and 9 cells) lie within
    // the same 3 columns.  If the criteria are met, then the 3 columns can be cleared of all other
    // occurances of the symbol.  Note that this also applies switching rows and columns.  This is
    // an expensive operation so it is only performed when other methods are not advancing the
    // solution.  Also note that no cells will be marked solved by this action.
    func swordfish() throws -> Void {
        try swordfishRows()
        try swordfishCols()
        try validate()
    }
    
    func swordfishRows() throws -> Void {
        let pairs = rows.findClusters( of: 2 ... 3, minimumCount: 2 )
        let relavent = pairs.reduce( into: [ Int : [[[SudokuPuzzle.Cell]]] ]() ) { dict, pair in
            let ( candidate, list ) = pair
            list.subsequences( size: 3 ).filter {
                $0.reduce( Set<Int>() ) {
                    $0.union( $1.reduce( into: Set<Int>() ) { $0.insert( $1.col ) } )
                }.count == 3
            }.forEach {
                dict[ candidate, default: [] ].append( $0 )
            }
        }
        for ( candidate, list ) in relavent {
            list.forEach { rowSet in
                let rowIndices = rowSet.reduce( into: Set<Int>() ) { $0.insert( $1[0].row ) }
                let colIndices = rowSet.reduce( Set<Int>() ) {
                    $0.union( $1.reduce( into: Set<Int>() ) { $0.insert( $1.col ) } )
                }
                colIndices.forEach { colIndex in
                    cols[colIndex].unsolved.filter { !rowIndices.contains( $0.row ) }.forEach {
                        $0.penciled.remove( candidate )
                    }
                }
            }
        }
    }
    
    func swordfishCols() throws -> Void {
        let pairs = cols.findClusters( of: 2 ... 3, minimumCount: 2 )
        let relavent = pairs.reduce( into: [ Int : [[[SudokuPuzzle.Cell]]] ]() ) { dict, pair in
            let ( candidate, list ) = pair
            list.subsequences( size: 3 ).filter {
                $0.reduce( Set<Int>() ) {
                    $0.union( $1.reduce( into: Set<Int>() ) { $0.insert( $1.row ) } )
                }.count == 3
            }.forEach {
                dict[ candidate, default: [] ].append( $0 )
            }
        }
        for ( candidate, list ) in relavent {
            list.forEach { colSet in
                let colIndices = colSet.reduce( into: Set<Int>() ) { $0.insert( $1[0].col ) }
                let rowIndices = colSet.reduce( Set<Int>() ) {
                    $0.union( $1.reduce( into: Set<Int>() ) { $0.insert( $1.row ) } )
                }
                rowIndices.forEach { rowIndex in
                    rows[rowIndex].unsolved.filter { !colIndices.contains( $0.col ) }.forEach {
                        $0.penciled.remove( candidate )
                    }
                }
            }
        }
    }
    
    // The Y-Wing strategy requires 3 cells with 2 penciled candidates per cell.  The cells must
    // match XY, XZ, and YZ.  XY must be able to see XZ and YZ.  It is irrelevant whether XZ and
    // YZ can see each other.  This configuration implies that at least one of XZ and YZ will solve
    // to Z.  So any cell that can be seen by both XZ and YZ can have Z eliminated from its penciled
    // set.  As a consequece, we can work with a set of candidates that are all the cells with a
    // penciled count of 2.  But when a Y-Wing is found and some penciled entries are removed, the
    // candidates is potentially invalidated and it is best to return at that point.  This is an
    // expensive operation so it is only performed when other methods are not advancing the
    // solution.  Also note that no cells will be marked solved by this action.
    func yWing() throws -> Void {
        let candidates = Set( puzzle.cells.filter { $0.penciled.count == 2 } )
        
        for candidate in candidates {
            guard let possibles = candidate.canSee?.intersection( candidates ) else { continue }
            guard possibles.count > 1 else { continue }
            let pincers = possibles.filter { $0.penciled.intersection( candidate.penciled ).count == 1 }
            guard pincers.count > 1 else { continue }
            
            let penciled = pincers.reduce( into: [ Int : [SudokuPuzzle.Cell] ]() ) { dict, cell in
                let other = cell.penciled.subtracting( candidate.penciled )
                dict[ other.first!, default: [] ].append( cell )
            }.filter { !candidate.penciled.contains( $0.key ) && $0.value.count > 1 }
                .mapValues { $0.subsequences( size: 2 ).filter { $0[0].penciled != $0[1].penciled } }
            if penciled.isEmpty { continue }
            
            for ( removal, pairs ) in penciled {
                for pair in pairs {
                    let removees = pair.reduce( Set( puzzle.cells ) ) {
                        $0.intersection( $1.canSee! )
                    }.subtracting( [ candidate ] )
                    
                    removees.forEach { $0.penciled.remove( removal ) }
                    if madeProgress {
                        try validate()
                        return
                    }
                }
            }
        }
    }
    
    // The Single's Chains strategy relies on the fact that whenever a group has a symbol that
    // appears in exactly two cell's pencilled sets, one of those cells will be solved with that
    // symbol and the other not.  The strategy finds all such pairs for each symbol and then links
    // the pairs into chains.  A chain is a network of cells in which if any cell is solved with
    // that symbol its neighbors can be eliminated.  The chain is stored as 2 sets, the greens and
    // the blues.  If any of the green cells is solved with the symbol, then they all are and the
    // blues can all be elimanted.  The reverse also holds of course.
    //
    // Once a chain as been identified there are 2 ways to eliminate possibilities:
    // Rule 4 - any cell that can see a green cell and a blue cell can have the symbol elimated
    // from its penciled set.
    // Rule 2 - any group that has more than 1 cell of either color can have the symbol removed
    // from the penciled set of all those cells.
    //
    // But when a Single's Chain is found and some penciled entries are removed, the all set and
    // the pairs set are potentially invalidated so it is best to return at that point.  This is an
    // expensive operation so it is only performed when other methods are not advancing the
    // solution.  Also note that no cells will be marked solved by this action.
    func singlesChains() throws -> Void {
        for index in 0 ..< puzzle.limit {
            let all = Set( puzzle.cells.filter { $0.penciled.contains( index ) } )
            var pairs = groups.reduce( into: Set<Set<SudokuPuzzle.Cell>>() ) { pairs, group in
                let matches = group.unsolved.filter { $0.penciled.contains( index ) }
                if matches.count == 2 { pairs.insert( Set( matches ) ) }
            }
            
            while let start = pairs.first {
                pairs.removeFirst()
                var greens = Set( [ start.first! ] )
                var blues = start.subtracting( greens )
                
                while let next = pairs.first(
                    where: { !$0.intersection( greens ).isEmpty || !$0.intersection( blues ).isEmpty } )
                {
                    pairs.remove( next )
                    let green = next.intersection( greens )
                    let blue = next.intersection( blues )
                    guard green.count < 2 else { throw SolverError.inconsistentBiLocation( green ) }
                    guard blue.count < 2 else { throw SolverError.inconsistentBiLocation( blue ) }
                    
                    if green.count == 1 {
                        if blue.isEmpty {
                            blues.formUnion( next.subtracting( green ) )
                        }
                    } else if blue.count == 1 {
                        greens.formUnion( next.subtracting( blue ) )
                    }
                }
                let candidates = all.subtracting( greens ).subtracting( blues )
                for candidate in candidates {
                    guard let canSee = candidate.canSee else { continue }
                            
                    if !canSee.intersection( greens ).isEmpty && !canSee.intersection( blues ).isEmpty {
                        candidate.penciled.remove( index )
                    }
                }
                for group in groups {
                    let green = Set( group.unsolved ).intersection( greens )
                    let blue = Set( group.unsolved ).intersection( blues )
                    
                    if green.count > 1 { green.forEach { $0.penciled.remove( index ) } }
                    if blue.count > 1 { blue.forEach { $0.penciled.remove( index ) } }
                }
                if madeProgress {
                    try validate()
                    return
                }
            }
        }
    }
}
