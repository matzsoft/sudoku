//
//  SudokuDocument.swift
//  Sudoku
//
//  Created by Mark Johnson on 9/18/22.
//

import SwiftUI
import UniformTypeIdentifiers

struct SudokuDocument: FileDocument {
    var puzzle: SudokuPuzzle?
    var selection: SudokuPuzzle.Cell?

    var levelInfo: SudokuPuzzle.Level? {
        get { puzzle?.levelInfo }
        set { puzzle = SudokuPuzzle( levelInfo: newValue! ) }
    }
    var needsLevel: Bool { levelInfo == nil }
    var levelDescription: String { levelInfo?.label ?? "No level for the puzzle." }
    var rows: [[SudokuPuzzle.Cell]] { puzzle?.rows ?? [] }

    init() {
    }

    static var readableContentTypes: [UTType] { [.text] }

    init( configuration: ReadConfiguration ) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String( data: data, encoding: .utf8 )
        else {
            throw CocoaError( .fileReadCorruptFile )
        }
    }
    
    func fileWrapper( configuration: WriteConfiguration ) throws -> FileWrapper {
        let data = "".data( using: .utf8 )!
        return .init( regularFileWithContents: data )
    }
    
    func image( cell: SudokuPuzzle.Cell ) -> NSImage {
        guard let puzzle = puzzle else { return NSImage( named: NSImage.cautionName )! }
        return puzzle.drawer.image( cell: cell, puzzle: puzzle, selection: selection )
    }
    
    @discardableResult mutating func moveTo( row: Int, col: Int ) -> Bool {
        guard 0 <= row && row < rows.count else { return false }
        guard 0 <= col && col < rows[0].count else { return false }
        
        selection = rows[row][col]
        return true
    }
    
    mutating func moveCommand( direction: MoveCommandDirection ) -> Void {
        guard puzzle != nil else { fatalError( "No puzzle available" ) }
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
        guard let limit = levelInfo?.limit else { return }
        if moveTo( row: selection.row - 1, col: selection.col ) { return }
        moveTo( row: limit - 1, col: selection.col )
    }
    
    mutating func moveDown() -> Void {
        guard let selection = selection else { return }
        if moveTo( row: selection.row + 1, col: selection.col ) { return }
        moveTo( row: 0, col: selection.col )
    }
    
    mutating func moveLeft() -> Void {
        guard let selection = selection else { return }
        guard let limit = levelInfo?.limit else { return }
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
