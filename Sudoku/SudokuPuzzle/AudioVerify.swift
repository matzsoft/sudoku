//
//  AudioVerify.swift
//  Sudoku
//
//  Created by Mark Johnson on 8/31/22.
//

import Foundation

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

extension SudokuPuzzle {
    func audioVerify() -> [ SpeechCommand ] {
        var commands: [ SpeechCommand ] = []
        
        if rows.isEmpty {
            commands.append( SpeechCommand( row: 0, col: 0, string: "Puzzle is empty." ) )
        } else {
            for col in 0 ..< rows[0].count {
                commands.append( SpeechCommand( row: 0, col: col, string: "Column \(col+1)." ) )
                for row in 0 ..< rows.count {
                    let cell = rows[row][col]
                    let string = cell.speechString( puzzle: self )
                    
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
