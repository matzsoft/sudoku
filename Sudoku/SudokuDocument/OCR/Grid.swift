//
//  Grid.swift
//  SudokuStockpile
//
//  Created by Mark Johnson on 7/23/22.
//  Copyright © 2022 matzsoft. All rights reserved.
//

import Foundation

class Grid {
    let grid: [[PGRect]]
    
    init?( image: PGImage ) {
        let xRuns  = findRunsByRow( image: image )
        let yRuns  = findRunsByCol( image: image )
        let xLines = runHistogram( runs: xRuns )
        let yLines = runHistogram( runs: yRuns )
        
        guard !xLines.isEmpty else { return nil }
        guard !yLines.isEmpty else { return nil }
        
        let rows = findRows( horizontal: xLines ).reversed()
        let cols = findCols( vertical: yLines )
        
        grid = rows.map { row -> [PGRect] in
            cols.map { col -> PGRect in
                PGRect( x: col.lowerBound ... col.upperBound, y: row.lowerBound ... row.upperBound )
            }
        }
    }
    
    subscript( row: Int, col: Int ) -> PGRect {
        grid[row][col]
    }
    
    var cellList: [PGRect] {
        grid.flatMap { $0 }
    }
}


fileprivate func findRows( horizontal: [PGOLine] ) -> [ClosedRange<Int>] {
    var rows = [ ClosedRange<Int> ]()
    
    for index in horizontal.indices.dropLast() {
        if horizontal[index].start.y != horizontal[index+1].start.y - 1 {
            rows.append( horizontal[index].y.lowerBound + 1 ... horizontal[index+1].y.lowerBound - 1 )
        }
    }
    
    return rows
}


fileprivate func findCols( vertical: [PGOLine] ) -> [ClosedRange<Int>] {
    var cols = [ ClosedRange<Int> ]()
    
    for index in vertical.indices.dropLast() {
        if vertical[index].start.x != vertical[index+1].start.x - 1 {
            cols.append( vertical[index].x.lowerBound + 1 ... vertical[index+1].x.lowerBound - 1 )
        }
    }
    
    return cols
}
