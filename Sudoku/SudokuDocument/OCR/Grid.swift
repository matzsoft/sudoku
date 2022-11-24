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
        
        let rows = Array( findRows( horizontal: xLines ).reversed() )
        let cols = findCols( vertical: yLines )
        let rowRuns = rows.map { row in xRuns.filter { row.overlaps( $0.y ) } }
        let colRuns = cols.map { col in yRuns.filter { col.overlaps( $0.x ) } }
        
        grid = ( 0 ..< rows.count ).map { rowIndex -> [PGRect] in
            ( 0 ..< cols.count ).map { colIndex -> PGRect in
                trim(
                    row: rows[rowIndex], col: cols[colIndex],
                    xRuns: rowRuns[rowIndex], yRuns: colRuns[colIndex]
                )
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


func trim( row: ClosedRange<Int>, col: ClosedRange<Int>, xRuns: [PGOLine], yRuns: [PGOLine] ) -> PGRect {
    var row = row
    var col = col
    let xRuns = xRuns.filter { row.contains( $0.y.lowerBound ) && col.overlaps( $0.x ) }
    let yRuns = yRuns.filter { col.contains( $0.x.lowerBound ) && row.overlaps( $0.y ) }
    var count = 0

    repeat {
        count = 0
        if yRuns.contains( where: { $0.x.lowerBound == col.lowerBound && $0.y.overlaps( row ) } ) {
            col = col.lowerBound + 1 ... col.upperBound
            count += 1
        }
        if yRuns.contains( where: { $0.x.lowerBound == col.upperBound && $0.y.overlaps( row ) } ) {
            col = col.lowerBound ... col.upperBound - 1
            count += 1
        }
        if xRuns.contains( where: { $0.y.lowerBound == row.lowerBound && $0.x.overlaps( col ) } ) {
            row = row.lowerBound + 1 ... row.upperBound
            count += 1
        }
        if xRuns.contains( where: { $0.y.lowerBound == row.upperBound && $0.x.overlaps( col ) } ) {
            row = row.lowerBound ... row.upperBound - 1
            count += 1
        }
    } while count > 0
    
    return PGRect( x: col, y: row )
}


fileprivate func findRunsByRow( image: PGImage ) -> [PGOLine] {
    enum State { case black, white }
    let bounds = image.bounds
    let rangeY = Int( bounds.minY.rounded() ) ... Int( bounds.maxY.rounded() )
    return rangeY.reduce( into: [PGOLine]() ) { list, y in
        let rangeX = Int( bounds.minX.rounded() ) ... Int( bounds.maxX.rounded() )
        var state = State.white
        var start = 0
        
        for x in rangeX {
            switch state {
            case .white:
                if image[x,y] < 128 {
                    start = x
                    state = .black
                }
            case .black:
                if image[x,y] > 127 {
                    state = .white
                    list.append( PGOLine( y: y, start: start, end: x - 1 ) )
                }
            }
        }
        
        if state == .black {
            list.append( PGOLine( y: y, start: start, end: rangeX.upperBound ) )
        }
    }
}


fileprivate func findRunsByCol( image: PGImage ) -> [PGOLine] {
    enum State { case black, white }
    let bounds = image.bounds
    let rangeX = Int( bounds.minX.rounded() ) ... Int( bounds.maxX.rounded() )
    return rangeX.reduce( into: [PGOLine]() ) { list, x in
        let rangeY = Int( bounds.minY.rounded() ) ... Int( bounds.maxY.rounded() )
        var state = State.white
        var start = 0
        
        for y in rangeY {
            switch state {
            case .white:
                if image[x,y] < 128 {
                    start = y
                    state = .black
                }
            case .black:
                if image[x,y] > 127 {
                    state = .white
                    list.append( PGOLine( x: x, start: start, end: y - 1 ) )
                }
            }
        }
        
        if state == .black {
            list.append( PGOLine( x: x, start: start, end: rangeY.upperBound ) )
        }
    }
}


fileprivate func runHistogram( runs: [PGOLine] ) -> [PGOLine] {
    runs.reduce( into: [ Int : [PGOLine] ]() ) { dict, run in
        dict[ run.length, default: [] ].append( run )
    }.max( by: { $0.key * $0.value.count < $1.key * $1.value.count } )!.value
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
