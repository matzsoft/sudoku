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
