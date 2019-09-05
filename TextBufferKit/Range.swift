//
//  Range.swift
//  swift-textbuffer
//
//  Created by Miguel de Icaza on 8/13/19.
//  Copyright 2019 Miguel de Icaza, Microsoft Corp
//  
//  Permission is hereby granted, free of charge, to any person obtaining
//  a copy of this software and associated documentation files (the
//  "Software"), to deal in the Software without restriction, including
//  without limitation the rights to use, copy, modify, merge, publish,
//  distribute, sublicense, and/or sell copies of the Software, and to
//  permit persons to whom the Software is furnished to do so, subject to
//  the following conditions:
//  
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//  
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
//  LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
//  OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
//  WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

import Foundation


/// A range in the editor. (startLineNumber,startColumn) is <= (endLineNumber,endColumn)
public struct Range {
    // negative if a < b
    // zero if a == b
    // positive if a > b
    public static func compareUsingEnds (_ a: Range, _ b: Range) -> Int {
        if (a.endLineNumber == b.endLineNumber) {
                if (a.endColumn == b.endColumn) {
                        if (a.startLineNumber == b.startLineNumber) {
                                return a.startColumn - b.startColumn;
                        }
                        return a.startLineNumber - b.startLineNumber;
                }
                return a.endColumn - b.endColumn;
        }
        return a.endLineNumber - b.endLineNumber;
    }
    
    /// Convenience method to not have to set all the parameter names
    public static func make (_ startLine: Int, _ startColumn: Int, _ endLine: Int, _ endColumn: Int) -> Range
    {
        return Range(startLineNumber: startLine, startColumn: startColumn, endLineNumber: endLine, endColumn: endColumn)
    }
    
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

    public func getEndPosition () -> Position
    {
        return Position(line: endLineNumber, column: endColumn)
    }
    
    public func getStartPosition() -> Position
    {
        return Position(line: startLineNumber, column: startColumn)
    }
}
