//
//  SudokuPuzzleDrawer.swift
//  Sudoku
//
//  Created by Mark Johnson on 8/24/22.
//

import Foundation
import AppKit
import CoreText

extension SudokuPuzzle {
    struct Drawer {
        static let checkerboardLightColor = CGColor( red: 1, green: 1, blue: 1, alpha: 1 )
        static let checkerboardDarkColor  = CGColor( red: 0.90, green: 0.90, blue: 0.90, alpha: 1 )
        static let lineColor              = CGColor( red: 0, green: 0, blue: 0, alpha: 1 )
        static let textColor              = CGColor( red: 0, green: 0, blue: 0, alpha: 1 )
        
        static let fatLine      = CGFloat( 2.5 )
        static let thinLine     = CGFloat( 1.5 )
        static let cellMargin   = CGFloat( 2.5 )
        static let miniCellSize = CGFloat( 10 )
        static let penciledFont = setupFontAttributes( color: textColor, fontSize: miniCellSize )

        let cellSize:         CGFloat
        let cellInteriorSize: CGFloat
        let solvedFont:       CFDictionary

        static func setupFontAttributes( color: CGColor, fontSize: CGFloat ) -> CFDictionary {
            let fontAttributes = [
                String( kCTFontFamilyNameAttribute ) : "Arial",
                String( kCTFontStyleNameAttribute )  : "Regular",
                String( kCTFontSizeAttribute )       : fontSize
                ] as CFDictionary
            let fontDescriptor = CTFontDescriptorCreateWithAttributes( fontAttributes )
            let font           = CTFontCreateWithFontDescriptor( fontDescriptor, 0.0, nil )
            
            let attributes = [
                String( kCTFontAttributeName )            : font,
                String( kCTForegroundColorAttributeName ) : color
            ] as CFDictionary
            
            return attributes
        }
        
        static func makeContext( size: NSSize ) -> CGContext? {
            let nsImage = NSImage( size: size )
            let imageRep = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: Int( size.width ), pixelsHigh: Int( size.height ),
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: NSColorSpaceName.calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
            )!
            nsImage.addRepresentation( imageRep )
            let cgImage = nsImage.cgImage( forProposedRect: nil, context: nil, hints: nil )!
            return CGContext(
                data: nil,
                width: Int( cgImage.width ),
                height: Int( cgImage.height ),
                bitsPerComponent: cgImage.bitsPerComponent,
                bytesPerRow: 0,
                space: cgImage.colorSpace!,
                bitmapInfo: cgImage.bitmapInfo.rawValue
            )
        }
        
        init( level: Int ) {
            cellSize = Drawer.cellMargin * CGFloat( level + 1 ) + Drawer.miniCellSize * CGFloat( level )
            cellInteriorSize = cellSize - 2 * Drawer.cellMargin
            solvedFont = Drawer.setupFontAttributes(
                color: Drawer.textColor, fontSize: cellSize - 2 * Drawer.cellMargin )
        }
        
        func penciledRect( penciled: Int, puzzle: SudokuPuzzle ) -> CGRect {
            let skipOver = Drawer.miniCellSize + Drawer.cellMargin
            return CGRect(
                x: Drawer.cellMargin + CGFloat( penciled % puzzle.level ) * skipOver,
                y: Drawer.cellMargin + CGFloat( penciled / puzzle.level ) * skipOver,
                width: Drawer.miniCellSize, height: Drawer.miniCellSize
            )
        }
        
        func draw( symbol: Character, rect: CGRect, font: CFDictionary, context: CGContext ) -> Void {
            let symbol     = String( symbol ) as CFString
            let attrString = CFAttributedStringCreate( kCFAllocatorDefault, symbol, font )
            let line       = CTLineCreateWithAttributedString( attrString! )
            let textSize   = CTLineGetImageBounds( line, context )
            let position   = CGPoint(
                x: rect.minX + ( rect.width - textSize.width ) / 2,
                y: rect.minY + ( rect.height - textSize.height ) / 2
            )

            context.textPosition = position
            CTLineDraw( line, context )
        }
        
        func image( cell: Cell, puzzle: SudokuPuzzle, selection: Cell? ) -> NSImage {
            let width  = cellSize
            let height = cellSize

            guard let context = Drawer.makeContext( size: NSSize( width: width, height: height ) ) else {
                return NSImage( named: NSImage.cautionName )!
            }
            
            draw( cell: cell, puzzle: puzzle, selection: selection, context: context )
            return NSImage(
                cgImage: context.makeImage()!,
                size: NSSize( width: width, height: height )
            )
        }
        
        func draw( cell: Cell, puzzle: SudokuPuzzle, selection: Cell?, context: CGContext ) -> Void {
            if cell !== selection {
                if ( cell.blockRow + cell.blockCol ).isMultiple( of: 2 ) {
                    context.setFillColor( Drawer.checkerboardLightColor )
                } else {
                    context.setFillColor( Drawer.checkerboardDarkColor )
                }
                context.fill( CGRect( x: 0, y: 0, width: cellSize, height: cellSize ) )
            }
            
            if let solved = cell.solved {
                // Draw the solved number
                let symbol = puzzle.levelInfo.symbol( from: solved ) ?? "?"
                let rect   = CGRect(
                    x: Drawer.cellMargin, y: Drawer.cellMargin,
                    width: cellInteriorSize, height: cellInteriorSize
                )
                
                draw( symbol: symbol, rect: rect, font: solvedFont, context: context )
                return
            }
            
            if !cell.penciled.isEmpty {
                // Draw all the penciled.
                for penciled in cell.penciled {
                    let symbol = puzzle.levelInfo.symbol( from: penciled ) ?? "?"
                    let rect   = penciledRect( penciled: penciled, puzzle: puzzle )

                    draw( symbol: symbol, rect: rect, font: Drawer.penciledFont, context: context )
                }
                return
            }
        }
    }
}
