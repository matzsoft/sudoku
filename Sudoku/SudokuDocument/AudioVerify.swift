//
//  AudioVerify.swift
//  Sudoku
//
//  Created by Mark Johnson on 8/31/22.
//

import Foundation
import SwiftUI

extension SudokuDocument {
    struct SpeechCommand {
        let row: Int
        let col: Int
        let string: String
        
        init( row: Int, col: Int, string: String ) {
            self.row = row
            self.col = col
            self.string = string
        }
        
        init( copy from: SpeechCommand, string: String ) {
            self.row = from.row
            self.col = from.col
            self.string = string
        }
    }

    class SpeechDelegate: NSObject, NSSpeechSynthesizerDelegate {
        let document: SudokuDocument
        
        internal init( document: SudokuDocument ) {
            self.document = document
        }
        
        func speechSynthesizer( _ sender: NSSpeechSynthesizer, didFinishSpeaking finishedSpeaking: Bool ) {
            guard document.isSpeaking else { return }
            guard !document.speechQueue.isEmpty else {
                document.isSpeaking = false
                return
            }
            
            let command = document.speechQueue.removeFirst()
            
            if document.moveTo( row: command.row, col: command.col ) {
    //            viewController?.view.needsDisplay = true
            }
            
            sender.startSpeaking( command.string )
        }
    }

    var getSynthesizer: NSSpeechSynthesizer {
        let synthesizer = NSSpeechSynthesizer()
        let voices = NSSpeechSynthesizer.availableVoices
        let desiredVoiceName = "com.apple.speech.synthesis.voice.Alex"
        let desiredVoice = NSSpeechSynthesizer.VoiceName( rawValue: desiredVoiceName )
        
        if let voice = voices.first( where: { $0 == desiredVoice } ) {
            synthesizer.setVoice( voice )
        }
        
        synthesizer.usesFeedbackWindow = true
        speechDelegate = SpeechDelegate( document: self )
        synthesizer.delegate = speechDelegate
        return synthesizer
    }
    
    func audioVerify( type: AudioVerifyType ) {
        if speechQueue.isEmpty {
            speechQueue = fillSpeechQueue( type: type )
        }
        isSpeaking = true
        
        let synthesizer = synthesizer       // Force creation of synthesizer, etc.
        
        speechDelegate!.speechSynthesizer( synthesizer, didFinishSpeaking: true )
    }
    
    func stopSpeaking() -> Bool {
        let wasSpeaking = isSpeaking
        
        isSpeaking = false
        speechQueue = []
        return wasSpeaking
    }

    func speechStartCol( type: AudioVerifyType ) -> Int? {
        switch type {
        case .fromBeginning:
            return 0
        case .fromSelection:
            guard let selection = selection else { return nil }
            return selection.col
        }
    }
    
    func fillSpeechQueue( type: AudioVerifyType ) -> [ SpeechCommand ] {
        var commands: [ SpeechCommand ] = []
        
        if rows.isEmpty {
            commands.append( SpeechCommand( row: 0, col: 0, string: "Puzzle is empty." ) )
        } else {
            guard let startCol = speechStartCol( type: type ) else { NSSound.beep(); return [] }
            
            for col in startCol ..< rows[0].count {
                var dotRow: Int?
                
                commands.append( SpeechCommand( row: 0, col: col, string: "Column \(col+1)." ) )
                for row in 0 ..< rows.count {
                    let string = rows[row][col].speechString( puzzle: puzzle )
                    
                    if string == "dot" {
                        if dotRow == nil { dotRow = row }
                    } else {
                        if let dotRow = dotRow {
                            let dotCount = row - dotRow
                            let dotString = dotCount < 4
                                ? Array( repeating: "dot", count: dotCount ).joined( separator: " " )
                                : "dot by \(dotCount)"
                            commands.append( SpeechCommand( row: dotRow, col: col, string: dotString ) )
                        }
                        commands.append( SpeechCommand( row: row, col: col, string: string ) )
                        dotRow = nil
                    }
                }
            }
        }

        return commands
    }
}
