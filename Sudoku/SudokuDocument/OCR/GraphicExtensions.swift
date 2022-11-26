//
//  GraphicExtensions.swift
//  Sudoku
//
//  Created by Mark Johnson on 11/26/22.
//

import Foundation
import Cocoa
import UniformTypeIdentifiers

extension CGImage {
    var size: CGSize { return CGSize( width: width, height: height ) }

    @discardableResult func write( to destinationURL: URL ) -> Bool {
        guard let destination = CGImageDestinationCreateWithURL( destinationURL as CFURL, UTType.png.identifier as CFString, 1, nil )
        else { return false }
        
        CGImageDestinationAddImage( destination, self, nil )
        return CGImageDestinationFinalize( destination )
    }
}


extension CGSize {
    func scaled( by: CGSize ) -> CGSize { CGSize( width: width * by.width, height: height * by.height ) }
}


extension CGRect {
    func scaled( to size: CGSize ) -> CGRect {
        CGRect(
            x: self.origin.x * size.width, y: self.origin.y * size.height,
            width: self.size.width * size.width, height: self.size.height * size.height
        )
    }

    func flipped( to size: CGSize ) -> CGRect {
        CGRect(
            x: self.origin.x, y: size.height - ( self.origin.y + self.height ),
            width: self.size.width, height: self.size.height
        )
    }
}


extension NSImage {
    func calculateScale( expandedSize: CGSize ) -> CGSize {
        CGSize( width: size.width / expandedSize.width, height: size.height / expandedSize.height )
    }

    func toBlackAndWhite() -> NSImage? {
        guard let cgImage = cgImage( forProposedRect: nil, context: nil, hints: nil ) else { return nil }
        let ciImage = CIImage( cgImage: cgImage )
        let grayImage = ciImage.applyingFilter( "CIPhotoEffectNoir" )
        let bwParams: [String: Any] = [ "InputThreshold": 0.25 ]
        let bwImage = grayImage.applyingFilter( "CIColorThreshold", parameters: bwParams )
        guard let cgImage = CIContext( options: nil ).createCGImage( bwImage, from: bwImage.extent ) else {
            return nil
        }
        return NSImage( cgImage: cgImage, size: size )
    }

    var pngData: Data? {
        guard let tiffRepresentation = tiffRepresentation else { return nil }
        guard let bitmapImage = NSBitmapImageRep( data: tiffRepresentation ) else { return nil }
        return bitmapImage.representation( using: .png, properties: [:] )
    }

    @discardableResult func pngWrite( to url: URL, options: Data.WritingOptions = .atomic ) -> Bool {
        do {
            try pngData?.write( to: url, options: options )
            return true
        } catch {
            print( error )
            return false
        }
    }
}
