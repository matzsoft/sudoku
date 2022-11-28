//
//  SudokuDocument.swift
//  Sudoku
//
//  Created by Mark Johnson on 9/18/22.
//

import SwiftUI
import UniformTypeIdentifiers

final class SudokuDocument: ReferenceFileDocument {
    typealias Snapshot = Data
    
    var puzzle:      SudokuPuzzle
    var drawer:      Drawer
    var undoManager: UndoManager?
    var solver:      SudokuPuzzle.Solver
    var speechQueue: [ SpeechCommand ] = []
    var speechDelegate: SpeechDelegate?
    lazy var synthesizer: NSSpeechSynthesizer = getSynthesizer
    
    @Published var selection: SudokuPuzzle.Cell?
    @Published var isShowingSolution = false
    @Published var isSpeaking = false
    @Published var updateCount = 0

    var levelInfo: SudokuPuzzle.Level {
        get { puzzle.levelInfo }
        set {
            puzzle = SudokuPuzzle( levelInfo: newValue )
            drawer = Drawer( levelInfo: newValue )
        }
    }
    var rows: [[SudokuPuzzle.Cell]] { isShowingSolution ? solver.puzzle.grid : puzzle.grid }
    var needsLevel: Bool { puzzle.levelInfo.level == SudokuPuzzle.empty.level }
    var levelDescription: String { levelInfo.label }
    var puzzleSize: CGFloat { drawer.puzzleSize }
    var cellSize: CGFloat { drawer.cellSize }

    init() {
        puzzle = SudokuPuzzle.empty
        drawer = Drawer( levelInfo: puzzle.levelInfo )
        solver = SudokuPuzzle.Solver( puzzle: puzzle )
    }

    static var readableContentTypes: [UTType] { [ .plainText ] }

    convenience init( configuration: ReadConfiguration ) throws {
        switch configuration.contentType {
        case .plainText:
            guard let data = configuration.file.regularFileContents,
                  let string = String( data: data, encoding: .utf8 )
            else {
                throw CocoaError( .fileReadCorruptFile )
            }
            try self.init( string: string )
        default:
            throw CocoaError( .fileReadUnsupportedScheme )
        }
    }
    
    init( string: String ) throws {
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
                    puzzle.grid[row][col].solved = index
                } else if symbol != "." {
                    puzzle.grid[row][col].conflict = true
                }
            }
        }
        solver = SudokuPuzzle.Solver( puzzle: puzzle )
    }
    
    func snapshot( contentType: UTType ) throws -> Data {
        puzzle.asString.data( using: .utf8 )!
    }
    
    func fileWrapper( snapshot: Data, configuration: WriteConfiguration ) throws -> FileWrapper {
        FileWrapper( regularFileWithContents: snapshot )
    }
    
    func fileWrapper( configuration: WriteConfiguration ) throws -> FileWrapper {
        let data = puzzle.asString.data( using: .utf8 )!
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
    
    @discardableResult func moveTo( row: Int, col: Int ) -> Bool {
        guard 0 <= row && row < rows.count else { return false }
        guard 0 <= col && col < rows[0].count else { return false }
        
        selection = rows[row][col]
        return true
    }
    
    func moveUp() -> Void {
        let limit = levelInfo.limit
        guard let selection = selection else { moveTo( row: limit - 1, col: limit - 1 ); return }
        if moveTo( row: selection.row - 1, col: selection.col ) { return }
        moveTo( row: levelInfo.limit - 1, col: selection.col )
    }
    
    func moveDown() -> Void {
        guard let selection = selection else { moveTo( row: 0, col: 0 ); return }
        if moveTo( row: selection.row + 1, col: selection.col ) { return }
        moveTo( row: 0, col: selection.col )
    }
    
    func moveLeft() -> Void {
        let limit = levelInfo.limit
        guard let selection = selection else { moveTo( row: limit - 1, col: limit - 1 ); return }
        if moveTo( row: selection.row, col: selection.col - 1 ) { return }
        if moveTo( row: selection.row - 1, col: limit - 1 ) { return }
        moveTo( row: limit - 1, col: limit - 1 )
    }

    func moveRight() -> Void {
        guard let selection = selection else { moveTo( row: 0, col: 0 ); return }
        if moveTo( row: selection.row, col: selection.col + 1 ) { return }
        if moveTo( row: selection.row + 1, col: 0 ) { return }
        moveTo( row: 0, col: 0 )
    }

    func setSolved(
        cell: SudokuPuzzle.Cell, newIndex: Int?,
        endCell: SudokuPuzzle.Cell, undoCell: SudokuPuzzle.Cell
    ) -> Void {
        let oldIndex = cell.solved
        guard newIndex != oldIndex else { return }
        
        cell.solved = newIndex
        selection = endCell
        undoManager?.registerUndo( withTarget: self ) { document in
            document.setSolved( cell: cell, newIndex: oldIndex, endCell: undoCell, undoCell: endCell )
        }
    }
    
    func togglePencil( cell: SudokuPuzzle.Cell, index: Int ) -> Void {
        if !cell.penciled.insert( index ).inserted {
            cell.penciled.remove( index )
        }
        updateCount += 1
        undoManager?.registerUndo( withTarget: self ) { document in
            document.togglePencil( cell: cell, index: index )
        }
    }
    
    func markConflicts() -> Int {
        solver = SudokuPuzzle.Solver( puzzle: puzzle )
        let conflicts = solver.findConflicts()
        
        updateCount += 1
        return puzzle.markConflicts( conflicts: conflicts )
    }
    
    func checkValidity() -> String {
        solver = SudokuPuzzle.Solver( puzzle: puzzle )
        do {
            if try solver.solve() {
                return "Puzzle has a solution."
            } else {
                return "No solution found."
            }
        } catch let error as SudokuPuzzle.Solver.SolverError {
            return error.description
        } catch {
            return "Unknown error detected."
        }
    }
    
    func showSolution() -> String? {
        solver = SudokuPuzzle.Solver( puzzle: puzzle )
        isShowingSolution = true
        do {
            if try solver.solve() {
                return nil
            } else {
                return "The solver is stumped."
            }
        } catch let error as SudokuPuzzle.Solver.SolverError {
            return error.description
        } catch {
            return "Unknown error detected."
        }
    }
    
    func hideSolution() -> Void {
        isShowingSolution = false
    }
}
