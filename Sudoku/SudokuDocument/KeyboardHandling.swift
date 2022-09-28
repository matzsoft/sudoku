//
//  KeyboardHandling.swift
//  Sudoku
//
//  Created by Mark Johnson on 9/19/22.
//

import Foundation
import SwiftUI
import AppKit

extension SudokuDocument {
    struct KeyDownTracker: NSViewRepresentable {
        var document: SudokuDocument
        
        func makeNSView( context: Context ) -> NSView {
            let view = KeyDownView( document: document )

            DispatchQueue.main.async { // wait till next event cycle
                view.window?.makeFirstResponder( view )
            }
            return view
        }
        
        func updateNSView( _ nsView: NSView, context: Context ) {}
    }

    class KeyDownView: NSView {
        let document: SudokuDocument
        
        internal init( document: SudokuDocument ) {
            self.document = document
            super.init( frame: NSRect.zero )
        }
        
        required init?( coder: NSCoder ) {
            fatalError( "init(coder:) has not been implemented" )
        }
        
        override var acceptsFirstResponder: Bool { return true }
        
        override func keyDown( with event: NSEvent ) {
            if !document.handleControl( event: event ) {
                interpretKeyEvents( [ event ] )
            }
        }
        
        override func insertText( _ insertString: Any ) {
            guard let string = insertString as? String else { NSSound.beep(); return }
            guard string.count == 1 else { NSSound.beep(); return }

            if !document.insertText( character: string.uppercased().first! ) {
                NSSound.beep()
            }
        }
        
        #if false
        // Enable this to see what commands are produced by each key press.
        override func doCommand( by selector: Selector ) {
            Swift.print( "Got command = '\(selector)'" )
            super.doCommand( by: selector )
        }
        #endif
        
        override func moveLeft( _ sender: Any? )                    { document.moveLeft() }
        override func moveRight( _ sender: Any? )                   { document.moveRight() }
        override func moveUp( _ sender: Any? )                      { document.moveUp() }
        override func moveDown( _ sender: Any? )                    { document.moveDown() }
        override func scrollToBeginningOfDocument( _ sender: Any? ) { document.processHome() }
        override func scrollToEndOfDocument( _ sender: Any? )       { document.processEnd() }
        override func insertBacktab( _ sender: Any? )               { document.processBackTab() }
        override func insertTab( _ sender: Any? )                   { document.processTab() }
        override func insertNewline( _ sender: Any? )               { document.processNewLine() }

        override func deleteBackward( _ sender: Any? ) {
            if !document.processDeleteBackward() { NSSound.beep() }
        }
        override func deleteForward( _ sender: Any? ) {
            if !document.processDeleteForward() { NSSound.beep() }
        }
        override func cancelOperation( _ sender: Any? ) {
            if !document.processCancel() { NSSound.beep() }
        }
    }

    func insertText( character: Character ) -> Bool {
        if isShowingSolution { return false }
        guard let selection = selection else { return false }
        if let index = levelInfo.index( from: character ) {
            moveRight()
            setSolved( cell: selection, newIndex: index, endCell: self.selection!, undoCell: selection )
            return true
        }

        if character == "." || character == " " {
            return processDeleteForward()
        }
        
        return false
    }
    
    func handleControl( event: NSEvent ) -> Bool {
        if isShowingSolution { return false }
        guard let selection = selection else { return false }
        guard selection.solved == nil else { return false }
        guard event.modifierFlags.contains( .control ) else { return false }
        guard let characters = event.charactersIgnoringModifiers else { return false }
        guard characters.count == 1 else { return false }

        let character = characters.uppercased().first!
        
        guard let index = levelInfo.index( from: character ) else { return false }

        togglePencil( cell: selection, index: index )
        return true
    }
    
    func processTab() -> Void {
        guard let selection = selection else { moveTo( row: 0, col: 0 ); return }
        let newCol = ( selection.col + levelInfo.level ) / levelInfo.level * levelInfo.level
        if !moveTo( row: selection.row, col: newCol ) {
            moveTo( row: selection.row, col: 0 )
            moveDown()
        }
    }
    
    func processBackTab() -> Void {
        guard let selection = selection else {
            moveTo( row: levelInfo.limit - 1, col: levelInfo.limit - levelInfo.level )
            return
        }
        
        if selection.col > 0 {
            let newCol = ( selection.col - 1 ) / levelInfo.level * levelInfo.level
            moveTo( row: selection.row, col: newCol )
        } else {
            moveTo( row: selection.row, col: levelInfo.limit - levelInfo.level )
            moveUp()
        }
    }
    
    func processDeleteBackward() -> Bool {
        if isShowingSolution { return false }
        guard let selection = selection else { return false }
        moveLeft()
        setSolved( cell: self.selection!, newIndex: nil, endCell: self.selection!, undoCell: selection )
        return true
    }
    
    func processDeleteForward() -> Bool {
        if isShowingSolution { return false }
        guard let selection = selection else { return false }
        moveRight()
        setSolved( cell: selection, newIndex: nil, endCell: self.selection!, undoCell: selection )
        return true
    }
    
    func processNewLine() -> Void {
        guard let selection = selection else { moveTo( row: 0, col: 0 ); return }
        moveTo( row: selection.row, col: 0 )
        moveDown()
    }
    
    func processCancel() -> Bool {
        if isShowingSolution { return false }
        return stopSpeaking()
    }
    
    func processHome() -> Void {
        moveTo( row: 0, col: 0 )
    }
    
    func processEnd() -> Void {
        moveTo( row: levelInfo.limit - 1, col: levelInfo.limit - 1 )
    }
}
