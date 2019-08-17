//
//  Range.swift
//  swift-textbuffer
//
//  Created by Miguel de Icaza on 8/13/19.
//  Copyright © 2019 Miguel de Icaza, Microsoft Corp. All rights reserved.
//

import Foundation


/// A range in the editor. (startLineNumber,startColumn) is <= (endLineNumber,endColumn)
public struct Range {
    /// Line number on which the range starts (starts at 1).
    public var startLineNumber: Int
    /// Column on which the range starts in line `startLineNumber` (starts at 1).
    public var startColumn: Int
    /// Line number on which the range ends.
    public var endLineNumber: Int
    /// Column on which the range ends in line `endLineNumber`.
    public var endColumn : Int
    
    public func isEmpty() ->Bool
    {
        startLineNumber == endLineNumber && startColumn == endColumn
    }
}
