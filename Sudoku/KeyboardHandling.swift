//
//  KeyboardHandling.swift
//  Sudoku
//
//  Created by Mark Johnson on 9/19/22.
//

import Foundation
import SwiftUI
import AppKit

extension View {
    func keyTracking( onKeyDown: @escaping ( NSEvent ) -> Void ) -> some View  {
        KeyTrackingView( onKeyDown: onKeyDown ) { self }
    }
}

struct KeyTrackingView<Content>: View where Content: View {
    let onKeyDown: ( NSEvent ) -> Void
    let content: () -> Content

    init( onKeyDown: @escaping ( NSEvent ) -> Void, @ViewBuilder content: @escaping () -> Content ) {
        self.onKeyDown = onKeyDown
        self.content   = content
    }
    
    var body: some View {
        KeyTrackingRepresentable( onKeyDown: onKeyDown, content: content() )
    }
}

struct KeyTrackingRepresentable<Content>: NSViewRepresentable where Content: View {
    let onKeyDown: ( NSEvent ) -> Void
    let content:  Content
    
    func makeNSView( context: Context ) -> NSHostingView<Content> {
        return KeyTrackingNSHostingView( onKeyDown: onKeyDown, rootView: self.content )
    }
    
    func updateNSView( _ nsView: NSHostingView<Content>, context: Context ) {
    }

}

class KeyTrackingNSHostingView<Content>: NSHostingView<Content> where Content: View {
    let onKeyDown: ( NSEvent ) -> Void
    
    init( onKeyDown: @escaping ( NSEvent ) -> Void, rootView: Content ) {
        self.onKeyDown = onKeyDown
        super.init( rootView: rootView )
    }
    
    required init( rootView: Content ) {
        fatalError( "init(rootView:) has not been implemented" )
    }
    
    @objc required dynamic init?( coder aDecoder: NSCoder ) {
        fatalError( "init(coder:) has not been implemented" )
    }

    override func keyDown( with event: NSEvent ) -> Void {
        self.onKeyDown( event )
    }
}


// MARK: - The following is from xxxx

extension View {
    func trackingMouse(onMove: @escaping (NSPoint) -> Void) -> some View {
        TrackinAreaView(onMove: onMove) { self }
    }
}

struct TrackinAreaView<Content>: View where Content : View {
    let onMove: (NSPoint) -> Void
    let content: () -> Content
    
    init(onMove: @escaping (NSPoint) -> Void, @ViewBuilder content: @escaping () -> Content) {
        self.onMove = onMove
        self.content = content
    }
    
    var body: some View {
        TrackingAreaRepresentable(onMove: onMove, content: self.content())
    }
}

struct TrackingAreaRepresentable<Content>: NSViewRepresentable where Content: View {
    let onMove: (NSPoint) -> Void
    let content: Content
    
    func makeNSView(context: Context) -> NSHostingView<Content> {
        return TrackingNSHostingView(onMove: onMove, rootView: self.content)
    }
    
    func updateNSView(_ nsView: NSHostingView<Content>, context: Context) {
    }
}

class TrackingNSHostingView<Content>: NSHostingView<Content> where Content : View {
    let onMove: (NSPoint) -> Void
    
    init(onMove: @escaping (NSPoint) -> Void, rootView: Content) {
        self.onMove = onMove
        
        super.init(rootView: rootView)
        
        setupTrackingArea()
    }
    
    required init(rootView: Content) {
        fatalError("init(rootView:) has not been implemented")
    }
    
    @objc required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupTrackingArea() {
        let options: NSTrackingArea.Options = [.mouseMoved, .activeAlways, .inVisibleRect]
        self.addTrackingArea(NSTrackingArea.init(rect: .zero, options: options, owner: self, userInfo: nil))
    }
        
    override func mouseMoved(with event: NSEvent) {
        self.onMove(self.convert(event.locationInWindow, from: nil))
    }
}
