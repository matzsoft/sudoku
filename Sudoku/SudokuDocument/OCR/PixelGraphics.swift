//
//  PixelGraphics.swift
//  SudokuStockpile
//
//  Created by Mark Johnson on 7/25/22.
//  Copyright © 2022 matzsoft. All rights reserved.
//

import Foundation
import AppKit

class PGImage {
    let cgImage: CGImage
    let context: CGContext
    let pixelData: CFData
    let scaleFactor: CGSize
    
    var size: CGSize { cgImage.size }
    var bounds: CGRect { CGRect( x: 0, y: 0, width: cgImage.width, height: cgImage.height ) }
    
    convenience init?( nsImage: NSImage ) {
        guard let cgImage = nsImage.cgImage( forProposedRect: nil, context: nil, hints: nil ) else {
            return nil
        }

        self.init( cgImage: cgImage, scaleFactor: nsImage.calculateScale( expandedSize: cgImage.size ) )
    }

    init?( cgImage: CGImage, scaleFactor: CGSize = CGSize( width: 1, height: 1 ) ) {
        self.cgImage = cgImage
        self.scaleFactor = scaleFactor
        
        if let pixelData = cgImage.dataProvider?.data {
            self.pixelData = pixelData
        } else {
            return nil
        }
        
        if let context = CGContext(
            data: nil,
            width: Int( cgImage.size.width ),
            height: Int( cgImage.size.height ),
            bitsPerComponent: cgImage.bitsPerComponent,
            bytesPerRow: 0,
            space: cgImage.colorSpace!,
            bitmapInfo: cgImage.bitmapInfo.rawValue
        ) {
            self.context = context
        } else {
            return nil
        }
        
        context.draw( cgImage, in: CGRect( x: 0, y: 0, width: context.width, height: context.height ) )
    }
    
    subscript( _ x: Int, _ y: Int ) -> Int {
        if y >= cgImage.height || x >= cgImage.width { return 255 }   // Kluge for now, white when out of range.
        let data: UnsafePointer<UInt8> = CFDataGetBytePtr( pixelData )
        let index = ( cgImage.height - 1 - y ) * cgImage.bytesPerRow + x * 4
        
        return Int( data[index] )
    }
    
    var nsImage: NSImage? {
        guard let newImage = context.makeImage() else { return nil }
        let adjustedSize = NSSize( width: context.width, height: context.height ).scaled( by: scaleFactor )
        
        return NSImage( cgImage: newImage, size: adjustedSize )
    }
    
    @discardableResult func drawX( color: CGColor ) -> PGImage {
        context.setStrokeColor( color )
        context.setLineWidth( 10 )
        context.move( to: CGPoint( x: 0, y: 0 ) )
        context.addLine(to: CGPoint( x: context.width, y: context.height ) )
        context.move( to: CGPoint( x: 0, y: context.height ) )
        context.addLine(to: CGPoint( x: context.width, y: 0 ) )
        context.drawPath( using: .fillStroke )
        
        return self
    }

    @discardableResult func draw( box: CGRect, color: CGColor ) -> PGImage {
        context.setStrokeColor( color )
        context.setLineWidth( 3 )

        context.setFillColor( color.copy( alpha: 0.2 )! )
        context.addRect( box )
        context.drawPath( using: .fillStroke )

        return self
    }

    @discardableResult func draw( boxes: [CGRect], color: CGColor ) -> PGImage {
        context.setStrokeColor( color )
        context.setLineWidth( 3 )

        context.setFillColor( color.copy( alpha: 0.2 )! )
        for box in boxes {
            context.addRect( box )
        }
        context.drawPath( using: .fillStroke )

        return self
    }

    @discardableResult func draw( lines: [PGOLine], color: CGColor ) -> PGImage {
        context.setStrokeColor( color )
        context.setLineWidth( 1 )
        context.setLineCap( .butt )
        context.setShouldAntialias( false )
        context.setAllowsAntialiasing( false )

        for line in lines {
            context.move( to: line.start )
            context.addLine( to: line.end )
        }
        context.drawPath( using: .fillStroke )

        return self
    }

    @discardableResult func write( to destinationURL: URL ) -> Bool {
        guard let nsImage = nsImage else { return false }
        return nsImage.pngWrite( to: destinationURL )
    }
}


struct PGOLine {
    let x: ClosedRange<Int>
    let y: ClosedRange<Int>
    
    var start: CGPoint { CGPoint( x: x.lowerBound, y: y.lowerBound ) }
    var end:   CGPoint { CGPoint( x: x.upperBound, y: y.upperBound ) }
    
    init( y: Int, start: Int, end: Int ) {
        self.x = start ... end
        self.y = y ... y
    }
    
    init( x: Int, start: Int, end: Int ) {
        self.x = x ... x
        self.y = start ... end
    }
    
    var length: CGFloat {
        if x.lowerBound == x.upperBound { return CGFloat( y.upperBound - y.lowerBound + 1 ) }
        return CGFloat( x.upperBound - x.lowerBound + 1 )
    }
}


struct PGRect {
    let x: ClosedRange<Int>
    let y: ClosedRange<Int>
    
    var cgRect: CGRect {
        CGRect(
            x: x.lowerBound, y: y.lowerBound,
            width: x.upperBound - x.lowerBound + 1, height: y.upperBound - y.lowerBound + 1
        )
    }
}
