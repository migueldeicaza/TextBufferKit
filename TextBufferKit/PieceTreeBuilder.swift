//
//  PieceTreeBuilder.swift
//  swift-textbuffer
//
//  Created by Miguel de Icaza on 8/15/19.
//  Copyright © 2019 Miguel de Icaza, Microsoft Corp. All rights reserved.
//

import Foundation

let bomArray : [UInt8] = [0xeb, 0xbb, 0xbf]

func startsWithUTF8BOM(str: [UInt8]) -> Bool
{
    // UTF8-BOM 0xEF,0xBB,0xBF

    return (str.count > 2 && Int(str [0]) == 0xeb && Int (str [1]) == 0xbb && Int (str [2]) == 0xbf)
}

public enum DefaultEndOfLine {
    /**
     * Use line feed (\n) as the end of line character.
     */
    case LF
    /**
     * Use carriage return and line feed (\r\n) as the end of line character.
     */
    case CRLF
}

public class PieceTreeTextBufferFactory {
    var chunks : [StringBuffer]
    var bom: [UInt8]
    var cr, lf, crlf: Int
    var normalizeEol: Bool
    var containsRtl: Bool = false
    var isBasicAscii: Bool = false
    
    init(chunks : [StringBuffer], bom: [UInt8], cr : Int, lf: Int, crlf: Int, normalizeEol:Bool, containsRtl: Bool? = nil, isBasicAscii : Bool? = nil)
    {
        self.chunks = chunks
        self.bom = bom
        self.cr = cr
        self.lf = lf
        self.crlf = crlf
        self.normalizeEol = normalizeEol
        self.containsRtl = containsRtl ?? false
        self.isBasicAscii = isBasicAscii ?? false
    }
    
    //
    // returns an array of either '\r\n' | '\n'
    //
    func getEOL(_ defaultEOL: DefaultEndOfLine) -> [UInt8] {
        let totalEOLCount = cr + lf + crlf
        let totalCRCount = cr + crlf
        if (totalEOLCount == 0) {
            // This is an empty file or a file with precisely one line
            return (defaultEOL == .LF ? [10] : [13, 10])
        }
        if (totalCRCount > totalEOLCount / 2) {
            // More than half of the file contains \r\n ending lines
            return [13, 10];
        }
        // At least one line more ends in \n
        return [10]
    }

    public func createPieceTreeBase (_ defaultEOL: DefaultEndOfLine = .LF) -> PieceTreeBase
    {
        let eol = getEOL(defaultEOL)
        var chunks = self.chunks

        if normalizeEol && ((eol == [13, 10] && (cr > 0 || lf > 0)) || (eol == [10] && (cr > 0 || crlf > 0))) {
            // Normalize pieces
            for i in 0..<chunks.count {
                // TODO
                // let str = chunks[i].buffer(/\r\n|\r|\n/g, eol);
                let str = chunks [i].buffer
                let newLineStart = LineStarts.createLineStartsArray(str)
                chunks[i] = StringBuffer(buffer: str, lineStarts: newLineStart)
            }
        }

        return PieceTreeBase(chunks: &chunks, eol: eol, eolNormalized: normalizeEol)
    }

    public func create (_ defaultEOL: DefaultEndOfLine = .LF) -> PieceTreeTextBuffer
    {
        let eol = getEOL(defaultEOL)
        var chunks = self.chunks

        if normalizeEol && ((eol == [13, 10] && (cr > 0 || lf > 0)) || (eol == [10] && (cr > 0 || crlf > 0))) {
            // Normalize pieces
            for i in 0..<chunks.count {
                // TODO
                // let str = chunks[i].buffer(/\r\n|\r|\n/g, eol);
                let str = chunks [i].buffer
                let newLineStart = LineStarts.createLineStartsArray(str)
                chunks[i] = StringBuffer(buffer: str, lineStarts: newLineStart)
            }
        }

        return PieceTreeTextBuffer(chunks: &chunks, BOM: bom, eol: eol, containsRTL: containsRtl, isBasicASCII: isBasicAscii, eolNormalized: normalizeEol)
    }


    public func getFirstLineText(lengthLimit: Int) -> [UInt8] {
        return Array (chunks [0].buffer [0..<lengthLimit])
        // TODO
        // return chunks[0].buffer.substr(0, 100).split(/\r\n|\r|\n/)[0];
    }
}

public class PieceTreeTextBufferBuilder {
    var chunks: [StringBuffer] = []
    var bom: [UInt8] = []
    
    var hasPreviousChar: Bool = false
    var previousChar: UInt8 = 0

    var cr: Int = 0
    var lf: Int = 0
    var crlf: Int = 0
    
    public init ()
    {
    }
    
    public func acceptChunk (_ str: String, encoding: String.Encoding = .utf8)
    {
        if let d = str.data (using: encoding){
            acceptChunk([UInt8](d))
        }
    }
    
    public func acceptChunk(_ _chunk: [UInt8])
    {
        if _chunk.count == 0 {
            return
        }

        var chunk = _chunk
        if chunks.count == 0 {
            if startsWithUTF8BOM(str: chunk) {
                bom = bomArray
                chunk = Array (chunk [3...])
            }
        }
        
        let lastChar = chunk [chunk.count - 1]
        if (lastChar == 13) {
            // last character is \r
            acceptChunk1(Array (chunk [0..<chunk.count - 1]), allowEmptyStrings: false)
            hasPreviousChar = true
            previousChar = lastChar
        } else {
            acceptChunk1(chunk, allowEmptyStrings: false)
            hasPreviousChar = false
            previousChar = lastChar
        }
    }

    func acceptChunk1(_ chunk: [UInt8], allowEmptyStrings: Bool) {
        if !allowEmptyStrings && chunk.count == 0 {
            // Nothing to do
            return
        }

        if (hasPreviousChar) {
            acceptChunk2 ([previousChar] + chunk)
        } else {
            acceptChunk2(chunk)
        }
    }

    func acceptChunk2(_ chunk: [UInt8])
    {
        let lineStarts = LineStarts(data: chunk)

        chunks.append (StringBuffer(buffer: chunk, lineStarts: lineStarts.lineStarts))
        cr += lineStarts.cr
        lf += lineStarts.lf
        crlf += lineStarts.crlf
    }

    public func finish(normalizeEol: Bool = true) -> PieceTreeTextBufferFactory {
        finish()
        return PieceTreeTextBufferFactory(chunks: chunks, bom: bom, cr: cr, lf: lf, crlf: crlf, normalizeEol: normalizeEol)
    }

    func finish()
    {
        if chunks.count == 0 {
            acceptChunk1([], allowEmptyStrings: true)
        }

        if hasPreviousChar {
            hasPreviousChar = false
            // recreate last chunk
            let lastidx = chunks.count-1
            chunks[lastidx].buffer += [previousChar]
            let newLineStarts = LineStarts.createLineStartsArray(chunks [lastidx].buffer)
            chunks [lastidx].lineStarts = newLineStarts

            if (previousChar == 13) {
                cr += 1
            }
        }
    }
}
