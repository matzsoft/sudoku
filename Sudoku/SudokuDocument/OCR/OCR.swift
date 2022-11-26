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

struct OCR {
    let originalImage: NSImage
    let documentImage: PGImage
    let baseURL:       URL
    
    init( from image: NSImage ) throws {
        guard #available( macOS 12.0, * ) else { throw CocoaError( .featureUnsupported ) }
        guard let bwImage = image.toBlackAndWhite(),
              let pgImage = PGImage( nsImage: bwImage ),
              let documentImage = OCR.documentDetector( image: pgImage )
        else { throw CocoaError( .fileReadCorruptFile ) }
        let desktop = FileManager.default.urls( for: .desktopDirectory, in: .userDomainMask )[0]
        
        self.originalImage = image
        self.documentImage = documentImage
        self.baseURL       = desktop.appendingPathComponent( "cells" )
    }
    
    @available( macOS 12.0, * )
    static func documentDetector( image: PGImage ) -> PGImage? {
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
    
    static func perspectiveCorrectedImage(
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
    
    func puzzleString() throws -> String {
        documentImage.write( to: baseURL.appendingPathComponent( "document.png" ) )
        
        guard let cells = Grid( image: documentImage ) else {
            throw CocoaError( .fileReadCorruptFile )
        }
        
        return ocrCells( grid: cells )
    }
    
    @available(macOS 10.15, *)
    func ocrCells( grid: Grid ) -> String {
        let boxes = grid.grid.map { row -> [CGRect] in
            row.map { $0.cgRect.flipped( to: documentImage.size ) }
        }
        
        return boxes.enumerated().map { ( rowIndex, row ) in
            row.enumerated().map { ( colIndex, box ) in
                let url = baseURL.appendingPathComponent( "cell\(rowIndex+1)\(colIndex+1).png" )
                let rawOCR = ocrDetector( cellRect: box, url: url )
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
    func ocrDetector( cellRect: CGRect, url: URL ) -> String {
        guard let cellImage = getCellImage( cellRect: cellRect ) else { return "" }
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

    func getCellImage( cellRect: CGRect ) -> CGImage? {
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
}
