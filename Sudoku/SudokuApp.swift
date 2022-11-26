//
//  SudokuApp.swift
//  Sudoku
//
//  Created by Mark Johnson on 9/18/22.
//

import SwiftUI

@main
struct SudokuApp: App {
    @State private var isImporting = false

    var body: some Scene {
        DocumentGroup( newDocument: SudokuDocument.init ) { file in
            ContentView( document: file.document )
        }
        .commands {
            CommandGroup( replacing: .importExport ) {
                Button( "Import" ) {
                    isImporting = true
                }
                .fileImporter(
                    isPresented: $isImporting,
                    allowedContentTypes: [ .png, .jpeg, .gif ],
                    allowsMultipleSelection: true
                ) { result in
                    do {
                        let urls = try result.get()
                        for url in urls {
                            let newURL = url.deletingPathExtension().appendingPathExtension( "txt" )
                            try make( text: newURL, from: url )
                        }
                    } catch {
                        print( error )
                    }
                }
            }
        }
    }
}

func make( text: URL, from graphics: URL ) throws -> Void {
    guard let image = NSImage( contentsOf: graphics ) else {
        throw CocoaError( .fileReadCorruptFile ) }
    let ocr = try OCR( from: image )
    let string = try ocr.puzzleString()
    try string.write( to: text, atomically: true, encoding: .utf8 )
    
    Task {
        try await NSDocumentController.shared.openDocument(
            withContentsOf: text, display: true )
    }
}
