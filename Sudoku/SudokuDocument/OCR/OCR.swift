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

    let xRuns = findRunsByRow( image: documentImage )
    let yRuns = findRunsByCol( image: documentImage )
//    let horz = findHorizontal( lines: xRuns )
//    let vert = findVertical( lines: yRuns )
    let horz = runHistogram( runs: xRuns )
    let vert = runHistogram( runs: yRuns )
    
//    let bounds = detectPuzzle( xRuns: xRuns, yRuns: yRuns )
//    let white = CGColor( red: 1, green: 1, blue: 1, alpha: 1 )
//    let garbage = eliminateGarbage( bounds: bounds, runs: xRuns + yRuns )
//    let basePath = "/Users/markj/Desktop/cells/"
//    let url = URL( fileURLWithPath: "\(basePath)puzzle.png" )
//    documentImage.draw( lines: garbage, color: white ).write( to: url )
    guard let cells = Grid( horizontal: horz, vertical: vert ) else {
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


func findRunsByRow( image: PGImage ) -> [[PGOLine]] {
    enum State { case black, white }
    let bounds = image.bounds
    let rangeY = Int( bounds.minY.rounded() ) ... Int( bounds.maxY.rounded() )
    return rangeY.map { y -> [PGOLine] in
        let rangeX = Int( bounds.minX.rounded() ) ... Int( bounds.maxX.rounded() )
        var state = State.white
        var start = 0
        var list = [PGOLine]()
        
        for x in rangeX {
            switch state {
            case .white:
                if image[x,y] < 128 {
                    start = x
                    state = .black
                }
            case .black:
                if image[x,y] > 127 {
                    state = .white
                    list.append( PGOLine( y: y, start: start, end: x - 1 ) )
                }
            }
        }
        
        if state == .black {
            list.append( PGOLine( y: y, start: start, end: rangeX.upperBound ) )
        }
        
        return list
    }.filter { !$0.isEmpty }
}


func findRunsByCol( image: PGImage ) -> [[PGOLine]] {
    enum State { case black, white }
    let bounds = image.bounds
    let rangeX = Int( bounds.minX.rounded() ) ... Int( bounds.maxX.rounded() )
    return rangeX.map { x -> [PGOLine] in
        let rangeY = Int( bounds.minY.rounded() ) ... Int( bounds.maxY.rounded() )
        var state = State.white
        var start = 0
        var list = [PGOLine]()
        
        for y in rangeY {
            switch state {
            case .white:
                if image[x,y] < 128 {
                    start = y
                    state = .black
                }
            case .black:
                if image[x,y] > 127 {
                    state = .white
                    list.append( PGOLine( x: x, start: start, end: y - 1 ) )
                }
            }
        }
        
        if state == .black {
            list.append( PGOLine( x: x, start: start, end: rangeY.upperBound ) )
        }
        
        return list
    }.filter { !$0.isEmpty }
}


func findHorizontal( /*image: PGImage,*/ lines: [[PGOLine]] ) -> [PGOLine] {
    let vertCount = findCount( lines: lines )
//    let white = CGColor( red: 1, green: 1, blue: 1, alpha: 1 )

    var index = 0
    var horizontal = [PGOLine]()
    var accumulator = RowAccumulator()

    while index < lines.count {
        while index < lines.count && lines[index].count != vertCount {
            accumulator.add( row: lines[index] )
            index += 1
        }
        horizontal.append( contentsOf: accumulator.results() )
//        if index < lines.count {
////            image.draw( lines: lines[index], color: white )
//        }
        
        while index < lines.count && lines[index].count == vertCount {
            index += 1
        }
        
        if index < lines.count && lines[index].count > vertCount {
            if index + 1 < lines.count && lines[index+1].count > vertCount {
                while index < lines.count && lines[index].count != vertCount {
                    index += 1
                }
                while index < lines.count && lines[index].count == vertCount {
                    index += 1
                }
            }
        }
        
//        if 0 < index && index < lines.count {
////            image.draw( lines: lines[index-1], color: white )
//        }
    }
    
    return horizontal
}


func findVertical( /*image: PGImage,*/ lines: [[PGOLine]] ) -> [PGOLine] {
    let horzCount = findCount( lines: lines )
//    let white = CGColor( red: 1, green: 1, blue: 1, alpha: 1 )

    var index = 0
    var vertical = [PGOLine]()
    var accumulator = ColAccumulator()

    while index < lines.count {
        while index < lines.count && lines[index].count != horzCount {
            accumulator.add( col: lines[index] )
            index += 1
        }
        vertical.append( contentsOf: accumulator.results() )
//        if index < lines.count {
////            image.draw( lines: lines[index], color: white )
//        }

        while index < lines.count && lines[index].count == horzCount {
            index += 1
        }
        
        if index < lines.count && lines[index].count > horzCount {
            if index + 1 < lines.count && lines[index+1].count > horzCount {
                while index < lines.count && lines[index].count != horzCount {
                    index += 1
                }
                while index < lines.count && lines[index].count == horzCount {
                    index += 1
                }
            }
        }
        
//        if 0 < index && index < lines.count {
////            image.draw( lines: lines[index-1], color: white )
//        }
    }
    
    return vertical
}


func findCount( lines: [[PGOLine]] ) -> Int {
    var last = 0
    
    for line in lines {
        if line.count != 1 && line.count == last { return last }
        last = line.count
    }
    
    return 666
}


func detectPuzzle( xRuns: [[PGOLine]], yRuns: [[PGOLine]] ) -> CGRect {
    let xLines = runHistogram( runs: xRuns )
    let yLines = runHistogram( runs: yRuns )
    let xMin = xLines.min( by: { $0.start.x < $1.start.x } )!.start.x
    let xMax = xLines.max( by: { $0.end.x < $1.end.x } )!.end.x
    let yMin = yLines.min( by: { $0.start.y < $1.start.y } )!.start.y
    let yMax = yLines.max( by: { $0.end.y < $1.end.y } )!.end.y
    
    return CGRect( x: xMin, y: yMin, width: xMax - xMin, height: yMax - yMin )
}

func runHistogram( runs: [[PGOLine]] ) -> [PGOLine] {
    let histogram = runs.reduce( into: [ CGFloat : [PGOLine] ]() ) { dict, line in
        line.forEach { dict[ $0.length, default: [] ].append( $0 ) }
    }
    return histogram.max(
        by: { $0.key * CGFloat( $0.value.count ) < $1.key * CGFloat( $1.value.count ) }
    )!.value
}

func eliminateGarbage( bounds: CGRect, runs: [[PGOLine]] ) -> [PGOLine] {
    return runs.flatMap { $0.filter{ !bounds.contains( $0.start ) && !bounds.contains( $0.end ) } }
}

@available(macOS 10.15, *)
func ocrCells( image: PGImage, grid: Grid ) -> String {
    let basePath = "/Users/markj/Desktop/cells/"
    image.write( to: URL( fileURLWithPath: "\(basePath)document.png" ) )
    let boxes = grid.cellGrid.map { row -> [CGRect] in
        row.map { $0.flipped( to: image.size ) }
    }
    
    let dork = boxes.enumerated().map { ( rowIndex, row ) in
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
    }
//    let dork = boxes.map { row in
//        row.map { rect in
//            ocrDetector( image: image, cellRect: rect )
//        }
//    }
    
    return dork.map { row in
        row.joined()
    }.joined( separator: "\n" )
}


@available(macOS 10.15, *)
func ocrDetector( image: PGImage, cellRect: CGRect, url: URL ) -> String {
    guard let cellImage = getCellImage( documentImage: image, cellRect: cellRect ) else { return "" }
    let ocrRequestHandler = VNImageRequestHandler( cgImage: cellImage )
    let ocrRequest = VNRecognizeTextRequest()

    writeCGImage( cellImage, to: url )
    do {
        try ocrRequestHandler.perform( [ ocrRequest ] )
    } catch {
        return "?"
    }
    
    guard let textBlocks = ocrRequest.results else { return "." }
    let retval = textBlocks.map { $0.topCandidates(1).first!.string }.joined()
    return retval
}


// Consider making an extension to CGImage.
@discardableResult func writeCGImage( _ image: CGImage, to destinationURL: URL ) -> Bool {
    guard let destination = CGImageDestinationCreateWithURL( destinationURL as CFURL, UTType.png.identifier as CFString, 1, nil )
    else { return false }
    
    CGImageDestinationAddImage( destination, image, nil )
    return CGImageDestinationFinalize( destination )
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


struct RowAccumulator {
    var start = Int.max
    var end = Int.min
    var lines = [PGOLine]()
    
    mutating func add( row: [PGOLine] ) -> Void {
        start = min( start, Int( row.first!.start.x.rounded() ) )
        end = max( end, Int( row.last!.end.x.rounded() ) )
        lines.append( PGOLine( y: Int( row.first!.start.y.rounded() ), start: start, end: end ) )
    }
    
    mutating func results() -> [PGOLine] {
        let results = lines.map { PGOLine( y: Int( $0.start.y.rounded() ), start: start, end: end ) }
        
        start = Int.max
        end = Int.min
        lines = []
        
        return results
    }
}


struct ColAccumulator {
    var start = Int.max
    var end = Int.min
    var lines = [PGOLine]()
    
    mutating func add( col: [PGOLine] ) -> Void {
        start = min( start, Int( col.first!.start.y.rounded() ) )
        end = max( end, Int( col.last!.end.y.rounded() ) )
        lines.append( PGOLine( x: Int( col.first!.start.x.rounded() ), start: start, end: end ) )
    }
    
    mutating func results() -> [PGOLine] {
        let results = lines.map { PGOLine( x: Int( $0.start.x.rounded() ), start: start, end: end ) }
        
        start = Int.max
        end = Int.min
        lines = []
        
        return results
    }
}


extension CGImage {
    var size: CGSize { return CGSize( width: width, height: height ) }
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
