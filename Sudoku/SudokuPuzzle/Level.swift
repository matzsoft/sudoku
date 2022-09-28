//
//  SudokuPuzzleLevel.swift
//  Sudoku
//
//  Created by Mark Johnson on 8/24/22.
//

import Foundation

extension SudokuPuzzle {
    struct Level: Hashable {
        internal init( level: Int, label: String ) {
            self.level = level
            self.limit = level * level
            self.label = label
            fullSet    = Set( 0 ..< limit )
        }
                
        let level:   Int
        let limit:   Int
        let label:   String
        let fullSet: Set<Int>
        
        func index( from symbol: Character ) -> Int? {
            if level < 4 {
                guard let index = Int( String( symbol ) ) else { return nil }
                guard index > 0 else { return nil }
                return index - 1
            }
            
            guard let index = Int( String( symbol ), radix: limit ) else { return nil }
            return index
        }
        
        func symbol( from index: Int ) -> Character? {
            guard 0 <= index && index < limit else { return nil }
            if level < 4 {
                return Character( String( index + 1 ) )
            }
            
            return Character( String( index, radix: limit, uppercase: true ) )
        }
        
        func isValid( symbol: Character ) -> Bool {
            return index( from: symbol ) != nil
        }
    }
}
