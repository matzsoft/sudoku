//
//  ContentView.swift
//  Sudoku
//
//  Created by Mark Johnson on 9/18/22.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: SudokuDocument
    @State private var needsLevel = true

    var body: some View {
        VStack( alignment: .leading, spacing: 0 ) {
            ForEach( document.rows ) { row in
                HStack( alignment: .top, spacing: 0 ) {
                    ForEach( row ) { cell in
                        Image( nsImage: document.image( cell: cell ) )
                            .onTapGesture { document.selection = cell }
                    }
                }
            }
        }
        .padding()
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
        }
        message: {
            Text( "Select your puzzle size" )
        }
        .focusable()
        .onAppear() {
            needsLevel = document.needsLevel
        }
        .onDisappear() {
        }
        .onMoveCommand { direction in
            document.moveCommand( direction: direction )
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView( document: .constant( SudokuDocument() ) )
    }
}
