//
//  ContentView.swift
//  Sudoku
//
//  Created by Mark Johnson on 9/18/22.
//

import SwiftUI

enum AudioVerifyType: String, CaseIterable {
    case fromBeginning, fromSelection
}

struct ContentView: View {
    @Environment( \.undoManager ) var undoManager
    @ObservedObject var document: SudokuDocument
    @State private var audioVerifyType: AudioVerifyType = .fromBeginning

    var body: some View {
        document.undoManager = undoManager
        
        return HSplitView {
            ControlView( audioVerifyType: $audioVerifyType )
                .frame( minWidth: 200 )
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
    }
}


struct ControlView: View {
    @Binding var audioVerifyType: AudioVerifyType
    
    var body: some View {
        VStack( alignment: .leading, spacing: 0 ) {
            Label( "Start Audio Verify From", systemImage: "speaker" )
            Rectangle()
                .fill( .clear )
                .frame( width: 10, height: 10 )
            Picker( "", selection: $audioVerifyType ) {
                Text( "Beginning" ).tag( AudioVerifyType.fromBeginning )
                Text( "Selection" ).tag( AudioVerifyType.fromSelection )
            }.pickerStyle( RadioGroupPickerStyle() )
        }
        .padding()
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
            SudokuDocument.KeyDownTracker( document: document )
                .frame( maxWidth: 0, maxHeight: 0 )
        }
        .padding()
        .background( WindowAccessor( window: $window ) )
        .background( LinearGradient(
            gradient: Gradient(
                colors: [ .blue.opacity( 0.25 ), .cyan.opacity( 0.25 ), .green.opacity( 0.25 ) ]
            ),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
            )
        )
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView( document: SudokuDocument() )
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
