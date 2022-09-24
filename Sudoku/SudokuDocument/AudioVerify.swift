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
    
    func audioVerify() {
        if speechQueue.isEmpty {
            speechQueue = fillSpeechQueue()
        }
        isSpeaking = true
        
        let synthesizer = synthesizer       // Force creation of synthesizer, etc.
        
        speechDelegate!.speechSynthesizer( synthesizer, didFinishSpeaking: true )
    }
    
    func stopSpeaking() -> Bool {
        let wasSpeaking = isSpeaking
        
        isSpeaking = false
        return wasSpeaking
    }

    func fillSpeechQueue() -> [ SpeechCommand ] {
        var commands: [ SpeechCommand ] = []
        
        if rows.isEmpty {
            commands.append( SpeechCommand( row: 0, col: 0, string: "Puzzle is empty." ) )
        } else {
            for col in 0 ..< rows[0].count {
                commands.append( SpeechCommand( row: 0, col: col, string: "Column \(col+1)." ) )
                for row in 0 ..< rows.count {
                    let cell = rows[row][col]
                    let string = cell.speechString( puzzle: puzzle )
                    
                    commands.append( SpeechCommand( row: row, col: col, string: string ) )
                }
            }
        }

        var runStart: Int?
        var reduced: [ SpeechCommand ] = [ commands[0] ]

        commands.append( SpeechCommand( row: 0, col: 0, string: "dummy" ) )  // Acts as sentinel
        for index in 1 ..< commands.count {
            if commands[index-1].string == commands[index].string {
                if runStart == nil {
                    runStart = index - 1
                }
            } else {
                if let runIndex = runStart {
                    let runLength = index - runIndex
                    
                    runStart = nil
                    if runLength > 2 {
                        let newString = commands[runIndex].string + ", repeats \(runLength)"
                        
                        reduced.removeLast( runLength )
                        reduced.append( SpeechCommand( copy: commands[runIndex], string: newString ) )
                    }
                }
            }
            reduced.append( commands[index] )
        }
        
        reduced.removeLast()
        return reduced
    }
}
