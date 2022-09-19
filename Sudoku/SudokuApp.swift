//
//  SudokuApp.swift
//  Sudoku
//
//  Created by Mark Johnson on 9/18/22.
//

import SwiftUI

@main
struct SudokuApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: SudokuDocument()) { file in
            ContentView(document: file.$document)
        }
    }
}
