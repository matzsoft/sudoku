//
//  ContentView.swift
//  Sudoku
//
//  Created by Mark Johnson on 9/18/22.
//

import SwiftUI

enum DocumentMode:    String, CaseIterable { case editing, solving }
enum AudioVerifyType: String, CaseIterable { case fromBeginning, fromSelection }

struct ContentView: View {
    @Environment( \.undoManager ) var undoManager
    @ObservedObject var document: SudokuDocument
    @State private var documentMode: DocumentMode = .editing
    @State private var audioVerifyType: AudioVerifyType = .fromBeginning

    var body: some View {
        document.undoManager = undoManager
        
        return HSplitView {
            ControlView( document: document, documentMode: $documentMode, audioVerifyType: $audioVerifyType )
                .frame( minWidth: 200, maxWidth: 200 )
                .padding()
            PuzzleView( document: document )
                .fixedSize()
                .toolbar {
                    ToolbarItemGroup( placement: .automatic ) {
                        Button( action: { document.audioVerify( type: audioVerifyType ) } ) {
                            Label( "Audio Verify", systemImage: "speaker.wave.3" )
                        }.disabled( document.isSpeaking )
                        if let undoManager = undoManager {
                            Button( action: undoManager.undo ) {
                                Label( "Undo", systemImage: "arrow.uturn.backward" )
                            }
                            .disabled( !undoManager.canUndo )

                            Button( action: undoManager.redo ) {
                                Label( "Redo", systemImage: "arrow.uturn.forward" )
                            }
                            .disabled( !undoManager.canRedo )
                        }
                    }
                }
        }
        .background( LinearGradient(
            gradient: Gradient(
                colors: [ .blue.opacity( 0.25 ), .cyan.opacity( 0.25 ), .green.opacity( 0.25 ) ]
            ),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
            )
        )
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView( document: SudokuDocument() )
    }
}


struct ControlView: View {
    @ObservedObject var document: SudokuDocument
    @Binding var documentMode: DocumentMode
    @Binding var audioVerifyType: AudioVerifyType
    @State private var showingConflictAlert = false
    @State private var conflictCount = 0
    
    var conflictMessage: String {
        if conflictCount == 0 { return "No conflicts found." }
        if conflictCount == 1 { return "One conflict found." }
        return "Found \(conflictCount) conflicts."
    }
    
    var body: some View {
        VStack( alignment: .leading, spacing: 10 ) {
            Label( "Mode", systemImage: "filemenu.and.selection" )
            Picker( "", selection: $documentMode ) {
                Text( "Editing" ).tag( DocumentMode.editing )
                Text( "Solving" ).tag( DocumentMode.solving )
            }.pickerStyle( RadioGroupPickerStyle() )
            Divider()
            Label( "Start Audio Verify From", systemImage: "speaker" )
            Picker( "", selection: $audioVerifyType ) {
                Text( "Beginning" ).tag( AudioVerifyType.fromBeginning )
                Text( "Selection" ).tag( AudioVerifyType.fromSelection )
            }.pickerStyle( RadioGroupPickerStyle() )
            Divider()
            Label( "Verify", systemImage: "checkmark.shield" )
            Button( "Check Conflicts" ) {
                conflictCount = document.markConflicts()
                showingConflictAlert = true
            }
            .alert( conflictMessage, isPresented: $showingConflictAlert ) {
                Button( "OK", role: .cancel ) { }
            }
            Button( "Check Validity" ) {}
            Button( "Show Solution" ) {}
        }
        .padding()
        .background( Color( red: 241 / 255, green: 241 / 255, blue: 241 / 255 ) )
        .cornerRadius( 15 )
    }
}


struct PuzzleView: View {
    @Environment( \.dismiss ) var dismiss
    @ObservedObject var document: SudokuDocument
    @State private var needsLevel = true
    @State private var window: NSWindow?

    var body: some View {
        VStack( alignment: .leading, spacing: 0 ) {
            ForEach( document.rows ) { row in
                HorizontalLine( document: document, row: row[0].row )
                HStack( alignment: .top, spacing: 0 ) {
                    ForEach( row ) { cell in
                        VerticalLine( document: document, col: cell.col )
                        Image( nsImage: document.image( cell: cell ) )
                            .onTapGesture { document.selection = cell }
                    }
                    VerticalLine( document: document, col: 0 )
                }
            }
            HorizontalLine( document: document, row: 0 )
            KeyDownTracker( document: document )
        }
        .padding()
        .background( WindowAccessor( window: $window ) )
        .confirmationDialog( "Puzzle Level", isPresented: $needsLevel ) {
            ForEach( SudokuPuzzle.supportedLevels, id: \.self ) { levelInfo in
                Button( levelInfo.label ) { document.levelInfo = levelInfo; needsLevel = false }
            }
            Button( "Cancel", role: .cancel, action: { dismiss(); window?.close() } )
        }
        message: {
            Text( "Select your puzzle size" )
        }
        .onAppear() {
            needsLevel = document.needsLevel
        }
    }
}


struct HorizontalLine: View {
    var document: SudokuDocument
    var row: Int

    var body: some View {
        Rectangle()
            .fill( .black )
            .frame( width: document.puzzleSize, height: document.dividerHeight( row: row ) )
    }
}


struct VerticalLine: View {
    var document: SudokuDocument
    var col: Int

    var body: some View {
        Rectangle()
            .fill( .black )
            .frame( width: document.dividerWidth( col: col ), height: document.cellSize )
    }
}


struct WindowAccessor: NSViewRepresentable {
    @Binding var window: NSWindow?
    
    func makeNSView( context: Context ) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.window = view.window
        }
        return view
    }
    
    func updateNSView( _ nsView: NSView, context: Context ) {}
}


struct KeyDownTracker: View {
    var document: SudokuDocument
    
    var body: some View {
        SudokuDocument.KeyDownTracker( document: document )
            .frame( maxWidth: 0, maxHeight: 0 )
    }
}
