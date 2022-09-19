//
//  SudokuDocument.swift
//  Sudoku
//
//  Created by Mark Johnson on 9/18/22.
//

import SwiftUI
import UniformTypeIdentifiers

struct SudokuDocument: FileDocument {
    var puzzle:    SudokuPuzzle
    var drawer:    Drawer
    var selection: SudokuPuzzle.Cell?

    var levelInfo: SudokuPuzzle.Level {
        get { puzzle.levelInfo }
        set {
            puzzle = SudokuPuzzle( levelInfo: newValue )
            drawer = Drawer( levelInfo: newValue )
        }
    }
    var needsLevel: Bool { puzzle.levelInfo.level == SudokuPuzzle.empty.level }
    var levelDescription: String { levelInfo.label }
    var rows: [[SudokuPuzzle.Cell]] { puzzle.rows }
    var puzzleSize: CGFloat { drawer.puzzleSize }
    var cellSize: CGFloat { drawer.cellSize }

    init() {
        puzzle = SudokuPuzzle.empty
        drawer = Drawer( levelInfo: puzzle.levelInfo )
    }

    static var readableContentTypes: [UTType] { [.text] }

    init( configuration: ReadConfiguration ) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String( data: data, encoding: .utf8 )
        else {
            throw CocoaError( .fileReadCorruptFile )
        }
        let lines = string.split( separator: "\n" )
        let level = Int( sqrt( Double( lines.count ) ) )
        
        guard let levelInfo = SudokuPuzzle.supportedLevels.first( where: { $0.level == level } ),
              level * level == lines.count,
              lines.allSatisfy( { $0.count == lines.count } )
        else {
            throw CocoaError( .fileReadCorruptFile )
        }
        puzzle = SudokuPuzzle( levelInfo: levelInfo )
        drawer = Drawer( levelInfo: levelInfo )
        for ( row, line ) in lines.enumerated() {
            for ( col, symbol ) in line.enumerated() {
                if let index = puzzle.levelInfo.index( from: symbol ) {
                    puzzle.rows[row][col].solved = index
                } else if symbol != "." {
                    throw CocoaError( .fileReadCorruptFile )
                }
            }
        }
    }
    
    func fileWrapper( configuration: WriteConfiguration ) throws -> FileWrapper {
        let data = "".data( using: .utf8 )!
        return .init( regularFileWithContents: data )
    }
    
    func dividerHeight( row: Int ) -> CGFloat {
        row.isMultiple( of: levelInfo.level ) ? Drawer.fatLine : Drawer.thinLine
    }
    
    func dividerWidth( col: Int ) -> CGFloat {
        col.isMultiple( of: levelInfo.level ) ? Drawer.fatLine : Drawer.thinLine
    }
    
    func image( cell: SudokuPuzzle.Cell ) -> NSImage {
        return drawer.image( cell: cell, selection: selection )
    }
    
    @discardableResult mutating func moveTo( row: Int, col: Int ) -> Bool {
        guard 0 <= row && row < rows.count else { return false }
        guard 0 <= col && col < rows[0].count else { return false }
        
        selection = rows[row][col]
        return true
    }
    
    mutating func moveCommand( direction: MoveCommandDirection ) -> Void {
        guard selection != nil else {
            guard moveTo( row: 0, col: 0 ) else { fatalError( "Cannot set selection" ) }
            return
        }
        
        switch direction {
        case .up:
            moveUp()
        case .down:
            moveDown()
        case .left:
            moveLeft()
        case .right:
            moveRight()
        @unknown default:
            NSSound.beep()
        }
    }

    mutating func moveUp() -> Void {
        guard let selection = selection else { return }
        if moveTo( row: selection.row - 1, col: selection.col ) { return }
        moveTo( row: levelInfo.limit - 1, col: selection.col )
    }
    
    mutating func moveDown() -> Void {
        guard let selection = selection else { return }
        if moveTo( row: selection.row + 1, col: selection.col ) { return }
        moveTo( row: 0, col: selection.col )
    }
    
    mutating func moveLeft() -> Void {
        guard let selection = selection else { return }
        let limit = levelInfo.limit
        if moveTo( row: selection.row, col: selection.col - 1 ) { return }
        if moveTo( row: selection.row - 1, col: limit - 1 ) { return }
        moveTo( row: limit - 1, col: limit - 1 )
    }

    mutating func moveRight() -> Void {
        guard let selection = selection else { return }
        if moveTo( row: selection.row, col: selection.col + 1 ) { return }
        if moveTo( row: selection.row + 1, col: 0 ) { return }
        moveTo( row: 0, col: 0 )
    }
}
