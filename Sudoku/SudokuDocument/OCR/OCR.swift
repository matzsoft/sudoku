//
//  OCR.swift
//  Sudoku
//
//  Created by Mark Johnson on 11/17/22.
//

import Foundation
import Cocoa
import Vision
import UniformTypeIdentifiers

func puzzleString( from image: NSImage ) throws -> String {
    guard #available( macOS 12.0, * ) else { throw CocoaError( .featureUnsupported ) }
    guard let bwImage = image.toBlackAndWhite(),
          let pgImage = PGImage( nsImage: bwImage ),
          let documentImage = documentDetector( image: pgImage )
    else { throw CocoaError( .fileReadCorruptFile ) }

    guard let cells = Grid( image: documentImage ) else {
        throw CocoaError( .fileReadCorruptFile )
    }
    
    return ocrCells( image: documentImage, grid: cells )
}

@available( macOS 12.0, * )
func documentDetector( image: PGImage ) -> PGImage? {
    let documentRequestHandler = VNImageRequestHandler( cgImage: image.cgImage )
    let documentDetectionRequest = VNDetectDocumentSegmentationRequest()
    do {
        try documentRequestHandler.perform( [ documentDetectionRequest ] )
    } catch {
        print( error )
        return nil
    }

    let convertedImage = CIImage( cgImage: image.cgImage )
    guard let document = documentDetectionRequest.results?.first,
          let documentImage = perspectiveCorrectedImage( from: convertedImage, rectangleObservation: document ) else {
        print( "Unable to get document image." )
        return nil
    }

    return PGImage( cgImage: documentImage, scaleFactor: image.scaleFactor )
}


public func perspectiveCorrectedImage(
    from inputImage: CIImage,
    rectangleObservation: VNRectangleObservation
) -> CGImage? {
    let imageSize = inputImage.extent.size
    
    // Verify detected rectangle is valid.
    let boundingBox = rectangleObservation.boundingBox.scaled( to: imageSize )
    guard inputImage.extent.contains( boundingBox )
    else { print( "invalid detected rectangle" ); return nil }
    
    let croppedImage = inputImage.cropped( to: boundingBox )

    return CIContext( options: nil ).createCGImage( inputImage, from: croppedImage.extent )
}


@available(macOS 10.15, *)
func ocrCells( image: PGImage, grid: Grid ) -> String {
    let basePath = "/Users/markj/Desktop/cells/"
    image.write( to: URL( fileURLWithPath: "\(basePath)document.png" ) )
    let boxes = grid.grid.map { row -> [CGRect] in
        row.map { $0.cgRect.flipped( to: image.size ) }
    }
    
    return boxes.enumerated().map { ( rowIndex, row ) in
        row.enumerated().map { ( colIndex, box ) in
            let url = URL( fileURLWithPath: "\(basePath)cell\(rowIndex+1)\(colIndex+1).png" )
            let rawOCR = ocrDetector( image: image, cellRect: box, url: url )
            switch rawOCR {
            case "T":
                return "1"
            case "":
                return "."
            default:
                return rawOCR
            }
        }
    }.map { row in
        row.joined()
    }.joined( separator: "\n" )
}


@available(macOS 10.15, *)
func ocrDetector( image: PGImage, cellRect: CGRect, url: URL ) -> String {
    guard let cellImage = getCellImage( documentImage: image, cellRect: cellRect ) else { return "" }
    let ocrRequestHandler = VNImageRequestHandler( cgImage: cellImage )
    let ocrRequest = VNRecognizeTextRequest()

    cellImage.write( to: url )
    do {
        try ocrRequestHandler.perform( [ ocrRequest ] )
    } catch {
        return "?"
    }
    
    guard let textBlocks = ocrRequest.results else { return "." }
    let retval = textBlocks.map { $0.topCandidates(1).first!.string }.joined()
    return retval
}


func getCellImage( documentImage: PGImage, cellRect: CGRect ) -> CGImage? {
    guard let rawImage = documentImage.cgImage.cropping( to: cellRect ) else { return nil }
    guard let context = CGContext(
        data: nil,
        width: Int( 2 * rawImage.size.width ),
        height: Int( 2 * rawImage.size.height ),
        bitsPerComponent: rawImage.bitsPerComponent,
        bytesPerRow: 0,
        space: rawImage.colorSpace!,
        bitmapInfo: rawImage.bitmapInfo.rawValue
    ) else {
        return nil
    }
    
    context.setFillColor( CGColor( red: 1, green: 1, blue: 1, alpha: 1 ) )
    context.setLineWidth( 0 )
    context.addRect( CGRect( x: 0, y: 0, width: context.width, height: context.height ) )
    context.drawPath( using: .fillStroke )
    
    let rawRect = CGRect(
        x: rawImage.width / 2, y: rawImage.height / 2, width: rawImage.width, height: rawImage.height )
    context.draw( rawImage, in: rawRect )
    
    return context.makeImage()
}


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
