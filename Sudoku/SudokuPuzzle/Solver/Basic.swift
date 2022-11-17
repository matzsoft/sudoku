//
//  Basic.swift
//  Sudoku
//
//  Created by Mark Johnson on 11/17/22.
//  Contains the Basic Solver strategies.

import Foundation

extension SudokuPuzzle.Solver {
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
        func hiddenSingleton( group: Group ) throws -> Bool {
            guard let candidate = group.firstSingleton else { return false }
            let cell = group.cells.first { $0.penciled.contains( candidate ) }!
            
            try markSolved( cell: cell, index: candidate )
            return true
        }
        while try groups.first( where: hiddenSingleton ) != nil {}
    }
    
    // Any box that has all its occurences of a symbol within a single row (or column) means
    // that all occurences of that symbol can be removed from the other cells in the row (or
    // column).  Conversely any row (or column) that has all its occurences of a symbol within
    // a single box means that all occurences of that symbol can be removed from the other cells
    // in the box.  To avoid infinite loops, we loop once through the boxes and once through
    // all the rows and columns.  Also note that no cells will be marked solved by this action.
    func intersectionRemoval() throws -> Void {
        // Cross reference each box against the rows and columns.
        for box in boxes {
            for candidate in box.available {
                let cells = box.cells.filter { $0.penciled.contains( candidate ) }
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
        
        // Cross reference each row and column against the boxes.
        for group in rows + cols {
            for candidate in group.available {
                let cells = group.cells.filter { $0.penciled.contains( candidate ) }
                let box = cells[0].box
                
                if cells.allSatisfy( { $0.box == box } ) {
                    boxes[box].cells.filter { !cells.contains( $0 ) }.forEach {
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
}
