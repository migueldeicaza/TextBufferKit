//
//  Position.swift
//  swift-textbuffer
//
//  Created by Miguel de Icaza on 8/13/19.
//  Copyright © 2019 Miguel de Icaza, Microsoft Corp. All rights reserved.
//

import Foundation

public struct Position {
    var line: Int
    var column: Int
    
    public func isBeforeOrEqual (_ other: Position) -> Bool
    {
        return Self.isBeforeOrEqual(self, other);
    }
    
    public static func isBeforeOrEqual (_ lhs : Position, _ rhs: Position) -> Bool
    {
        if lhs.line < rhs.line {
            return true
        }
        if rhs.column < lhs.column {
            return false
        }
        return lhs.column <= rhs.column
    }
   
    public func isBefore (_ other: Position) -> Bool
    {
        return Self.isBefore(self, other)
    }
    
    public static func isBefore(_ lhs: Position, _ rhs: Position) -> Bool {
        if lhs.line < rhs.line {
            return true
        }
        if rhs.line < lhs.line {
            return false
        }
        return lhs.column < rhs.column
    }
}
