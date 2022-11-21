//
//  Grid.swift
//  SudokuStockpile
//
//  Created by Mark Johnson on 7/23/22.
//  Copyright © 2022 matzsoft. All rights reserved.
//

import Foundation

class Grid {
    let rows: [ClosedRange<CGFloat>]
    let cols: [ClosedRange<CGFloat>]
    
//    init( rows: [ClosedRange<CGFloat>], cols: [ClosedRange<CGFloat>] ) {
//        self.rows = rows
//        self.cols = cols
//    }
    
    init?( horizontal: [PGOLine], vertical: [PGOLine] ) {
        guard !horizontal.isEmpty else { return nil }
        guard !vertical.isEmpty else { return nil }
        
        rows = findRows( horizontal: horizontal ).reversed()
        cols = findCols( vertical: vertical )
    }
    
    subscript( row: Int, col: Int ) -> CGRect {
        CGRect(
            x: rows[row].lowerBound, y: cols[col].lowerBound,
            width: cols[col].upperBound - cols[col].lowerBound,
            height: rows[row].upperBound - rows[row].lowerBound
        )
    }
    
    var cellGrid: [[CGRect]] {
        rows.map { row -> [CGRect] in
            cols.map { col -> CGRect in
                CGRect(
                    x: col.lowerBound, y: row.lowerBound,
                    width: col.upperBound - col.lowerBound, height: row.upperBound - row.lowerBound
                )
            }
        }
    }
    
    var cellList: [CGRect] {
        rows.flatMap { row -> [CGRect] in
            cols.map { col -> CGRect in
                CGRect(
                    x: col.lowerBound, y: row.lowerBound,
                    width: col.upperBound - col.lowerBound, height: row.upperBound - row.lowerBound
                )
            }
        }
    }
}


fileprivate func findRows( horizontal: [PGOLine] ) -> [ClosedRange<CGFloat>] {
    var rows = [ ClosedRange<CGFloat> ]()
    
    for index in horizontal.indices.dropLast() {
        if horizontal[index].start.y != horizontal[index+1].start.y - 1 {
            rows.append( horizontal[index].start.y + 1 ... horizontal[index+1].start.y - 1 )
        }
    }
    
    return rows
}


fileprivate func findCols( vertical: [PGOLine] ) -> [ClosedRange<CGFloat>] {
    var cols = [ ClosedRange<CGFloat> ]()
    
    for index in vertical.indices.dropLast() {
        if vertical[index].start.x != vertical[index+1].start.x - 1 {
            cols.append( vertical[index].start.x + 1 ... vertical[index+1].start.x - 1 )
        }
    }
    
    return cols
}
