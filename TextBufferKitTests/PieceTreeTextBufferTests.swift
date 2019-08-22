//
//  PieceTreeTextBufferTests.swift
//  TextBufferKitTests
//
//  Created by Miguel de Icaza on 8/19/19.
//  Copyright © 2019 Miguel de Icaza. All rights reserved.
//
// Well, Swift does not really deal well with "\r\n", "\r" and "\n" injected into
// the stream, in a few places concatenating those strings become no-ops, like:
// var str = "\r\r\n\r\r\n\n\n\r\r\n\n\r\n\r\n\r\r\r"
// str = str.substring(0, 15) + "\n\r\r\r" + str.substring(15)
// After this, "str" will have the same value as before.
//
// Tests prefixed with BYTES_ need to be rewritten with the byte api, to avoid
// Swift's curious string handling with \r \n
//
import XCTest
import Foundation
@testable import TextBufferKit

extension String {

    func substring (_ start: Int, _ end: Int) -> String
    {
        //
        // This is coded this way, because the documented:
        // let sidx = str.index (str.startIndex, offsetBy: start)
        // let eix = str.index (str.startIndex, offsetBy: end)
        // let result = self[sidx..<eidx] produces the expected [sidx,eidx) range for strings
        // but produces [sidx,eidx] range when the string contains "\r\r\n\n"
        let j = toBytes (self)
        return toStr (Array (j [start..<end]))
    }

    func substring (_ start: Int) -> String
    {
        if start > self.count {
            return ""
        }
        // This used to be coded like this:
        // return String (self [self.index(self.startIndex, offsetBy: start)...])
        // But swift decided that for the string "\r\r\n", the substring(2) is not "\n" but ""
        let j = toBytes (self)
        return toStr (Array (j [start...]))
    }
}
class PieceTreeTextBufferTests: XCTestCase {

    let alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ\r\n"

    func randomChar() -> Character {
        return Array (alphabet)[Int.random (in: 0..<alphabet.count)]
    }

    func randomStr(_ _len: Int? = nil) -> String
    {
        let len = _len != nil ? _len! : 10
        var result : String = ""
        
        for _ in 0..<len {
            result.append(randomChar ())
        }
        return result
    }

    func trimLineFeed(_ text: [UInt8]) -> [UInt8] {
        let tc = text.count
        if tc == 0 {
            return text
        }

        if tc == 1 {
            if (
                text [tc - 1] == 10 ||
                text [tc - 1] == 13
            ) {
                return []
            }
            return text
        }

        if text[tc - 1] == 10 {
            if text [tc - 2] == 13 {
                return Array (text [0..<(tc-2)])
            }
            return Array (text [0..<(tc-1)])
        }

        if text [tc - 1] == 13 {
            return Array (text [0..<(tc-1)])
        }

        return text
    }

    //#region Assertion

    // This splits using the rules of TextBuffer, which considers
    // \r\n, \r or \n a line separator.   The first instance is a single
    // line separator, not two.
    func splitStringNewlines (_ str: String) -> [String]
    {
        let lines = PieceTreeBase.splitBufferInLines (toBytes (str))
        var result : [String] = []
        for x in lines {
            result.append (toStr (x))
        }
        return result
    }
    
    func testLinesContent(_ str: String, _ pieceTable: PieceTreeBase)
    {
        let lines = splitStringNewlines(str)
        
        if pieceTable.lineCount != lines.count {
            _ = 1
        }
        XCTAssertEqual(pieceTable.lineCount, lines.count)
        XCTAssertEqual(pieceTable.getLines(), str)
        for i in 0..<lines.count {
            XCTAssertEqual(pieceTable.getLineContent(i + 1), toBytes (lines[i]))
            XCTAssertEqual(
                trimLineFeed(
                    pieceTable.getValueInRange(
                        range: Range.make (
                            i + 1,
                            1,
                            i + 1,
                            lines[i].count + (i == lines.count - 1 ? 1 : 2)
                        )
                    )
                ),
                toBytes (lines[i])
            )
        }
    }

    func testLineStarts(_ str: String, _ pieceTable: PieceTreeBase) {
//        let lineStarts = [0]
//
//        // Reset regex to search from the beginning
//        let _regex = new RegExp(/\r\n|\r|\n/g)
//        _regex.lastIndex = 0
//        let prevMatchStartIndex = -1
//        let prevMatchLength = 0
//
//        let m: RegExpExecArray | null
//        do {
//            if (prevMatchStartIndex + prevMatchLength === str.count) {
//                // Reached the end of the line
//                break
//            }
//
//            m = _regex.exec(str)
//            if (!m) {
//                break
//            }
//
//            const matchStartIndex = m.index
//            const matchLength = m[0].count
//
//            if (
//                matchStartIndex === prevMatchStartIndex &&
//                matchLength === prevMatchLength
//            ) {
//                // Exit early if the regex matches the same range twice
//                break
//            }
//
//            prevMatchStartIndex = matchStartIndex
//            prevMatchLength = matchLength
//
//            lineStarts.push(matchStartIndex + matchLength)
//        } while (m)
//
//        for (let i = 0 i < lineStarts.count i++) {
//            assert.deepEqual(
//                pieceTable.getPositionAt(lineStarts[i]),
//                new Position(i + 1, 1)
//            )
//            XCTAssertEqual(pieceTable.getOffsetAt(i + 1, 1), lineStarts[i])
//        }
//
//        for (let i = 1 i < lineStarts.count i++) {
//            let pos = pieceTable.getPositionAt(lineStarts[i] - 1)
//            XCTAssertEqual(
//                pieceTable.getOffsetAt(pos.lineNumber, pos.column),
//                lineStarts[i] - 1
//            )
//        }
    }

    func createTextBuffer(_ val: [String], _ normalizeEOL: Bool = true) -> PieceTreeBase
    {
        let bufferBuilder = PieceTreeTextBufferBuilder()
        for chunk in val {
            bufferBuilder.acceptChunk(chunk)
        }
        let factory = bufferBuilder.finish(normalizeEol: normalizeEOL)
        return factory.create(.LF).getPieceTree()
    }
    

    func assertTreeInvariants(_ T: PieceTreeBase)
    {
        XCTAssertTrue(TreeNode.SENTINEL.color == .black)
        XCTAssertTrue(TreeNode.SENTINEL.parent === TreeNode.SENTINEL)
        XCTAssertTrue(TreeNode.SENTINEL.left === TreeNode.SENTINEL)
        XCTAssertTrue(TreeNode.SENTINEL.right === TreeNode.SENTINEL)
        XCTAssertEqual(TreeNode.SENTINEL.size_left, 0)
        XCTAssertEqual(TreeNode.SENTINEL.lf_left, 0)
        assertValidTree(T)
    }

    func depth(_ n: TreeNode) ->  Int {
        if (n === TreeNode.SENTINEL) {
            // The leafs are black
            return 1
        }
        XCTAssertEqual(depth(n.left!), depth(n.right!))
        return (n.color == .black ? 1 : 0) + depth(n.left!)
    }

    @discardableResult
    func assertValidNode(_ n: TreeNode) ->  (size: Int, lf_cnt: Int) {
        if (n === TreeNode.SENTINEL) {
            return (size: 0, lf_cnt: 0)
        }

        XCTAssertNotNil(n.left)
        XCTAssertNotNil(n.right)
        let l = n.left!
        let r = n.right!

        if (n.color == .red) {
            XCTAssertEqual(l.color, .black)
            XCTAssertEqual(r.color, .black)
        }

        let actualLeft = assertValidNode(l)
        XCTAssertEqual(actualLeft.lf_cnt, n.lf_left)
        XCTAssertEqual(actualLeft.size, n.size_left)
        let actualRight = assertValidNode(r)

        return (size: n.size_left + n.piece.length + actualRight.size, lf_cnt: n.lf_left + n.piece.lineFeedCount + actualRight.lf_cnt )
    }

    func assertValidTree(_ T: PieceTreeBase)
    {
        if (T.root === TreeNode.SENTINEL) {
            return
        }
        XCTAssertEqual(T.root.color, .black)
        XCTAssertEqual(depth(T.root.left!), depth(T.root.right!))
        assertValidNode (T.root)
    }

    func testInserts ()
    {
        let pt = createTextBuffer([""])

        pt.insert(0, "AAA")
        XCTAssertEqual(pt.getLines(), "AAA")
        pt.insert(0, "BBB")
        XCTAssertEqual(pt.getLines(), "BBBAAA")
        pt.insert(6, "CCC")
        XCTAssertEqual(pt.getLines(), "BBBAAACCC")
        pt.insert(5, "DDD")
        XCTAssertEqual(pt.getLines(), "BBBAADDDACCC")
        assertTreeInvariants(pt)
    }
    
    func testDeletes ()
    {
        let pt = createTextBuffer(["012345678"])
        pt.delete(offset: 8, cnt: 1)
        XCTAssertEqual(pt.getLines(), "01234567")
        pt.delete(offset: 0, cnt: 1)
        XCTAssertEqual(pt.getLines(), "1234567")
        pt.delete(offset: 5, cnt: 1)
        XCTAssertEqual(pt.getLines(), "123457")
        pt.delete(offset: 5, cnt: 1)
        XCTAssertEqual(pt.getLines(), "12345")
        pt.delete(offset: 0, cnt: 5)
        XCTAssertEqual(pt.getLines(), "")
        assertTreeInvariants(pt)
    }
    
    func testBasicInsertDelete ()
    {
            let pieceTable = createTextBuffer([
                "This is a document with some text."
            ])

        pieceTable.insert(34, toBytes ("This is some more text to insert at offset 34."))
        XCTAssertEqual(
            pieceTable.getLines(),
            "This is a document with some text.This is some more text to insert at offset 34."
        )
        print (pieceTable.getLines())
        assertTreeInvariants(pieceTable)
        pieceTable.delete(offset: 42, cnt: 5)
        assertTreeInvariants(pieceTable)
        XCTAssertEqual(
            pieceTable.getLines(),
            "This is a document with some text.This is more text to insert at offset 34."
        )
        assertTreeInvariants(pieceTable)
    }

    func testRandom1 ()
    {
        let pieceTable = createTextBuffer([""])
        pieceTable.insert(0, "ceLPHmFzvCtFeHkCBej ")
        XCTAssertEqual(pieceTable.getLines(), "ceLPHmFzvCtFeHkCBej ")
        pieceTable.insert(8, "gDCEfNYiBUNkSwtvB K ")
        XCTAssertEqual(pieceTable.getLines(), "ceLPHmFzgDCEfNYiBUNkSwtvB K vCtFeHkCBej ")
        pieceTable.insert(38, "cyNcHxjNPPoehBJldLS ")
        XCTAssertEqual(pieceTable.getLines(), "ceLPHmFzgDCEfNYiBUNkSwtvB K vCtFeHkCBecyNcHxjNPPoehBJldLS j ")
        pieceTable.insert(59, "ejMx\nOTgWlbpeDExjOk ")
        XCTAssertEqual(pieceTable.getLines(), "ceLPHmFzgDCEfNYiBUNkSwtvB K vCtFeHkCBecyNcHxjNPPoehBJldLS jejMx\nOTgWlbpeDExjOk  ")
        assertTreeInvariants(pieceTable)
    }

    func testRandom2 ()
    {
        var str = ""
        let pieceTable = createTextBuffer([""])
        pieceTable.insert(0, "VgPG ")
        str = str.substring(0, 0) + "VgPG " + str.substring(0)
        pieceTable.insert(2, "DdWF ")
        str = str.substring(0, 2) + "DdWF " + str.substring(2)
        pieceTable.insert(0, "hUJc ")
        str = str.substring(0, 0) + "hUJc " + str.substring(0)
        pieceTable.insert(8, "lQEq ")
        str = str.substring(0, 8) + "lQEq " + str.substring(8)
        pieceTable.insert(10, "Gbtp ")
        str = str.substring(0, 10) + "Gbtp " + str.substring(10)

        XCTAssertEqual(pieceTable.getLines(), str)
        assertTreeInvariants(pieceTable)
    }
    
    func testRandom3 ()
    {
        var str = ""
        let pieceTable = createTextBuffer([""])
        pieceTable.insert(0, "gYSz")
        str = str.substring(0, 0) + "gYSz" + str.substring(0)
        pieceTable.insert(1, "mDQe")
        str = str.substring(0, 1) + "mDQe" + str.substring(1)
        pieceTable.insert(1, "DTMQ")
        str = str.substring(0, 1) + "DTMQ" + str.substring(1)
        pieceTable.insert(2, "GGZB")
        str = str.substring(0, 2) + "GGZB" + str.substring(2)
        pieceTable.insert(12, "wXpq")
        str = str.substring(0, 12) + "wXpq" + str.substring(12)
        XCTAssertEqual(pieceTable.getLines(), str)
    }

    func testDelete1 ()
    {
        var str = ""
        let pieceTable = createTextBuffer([""])

        pieceTable.insert(0, "vfb")
        str = str.substring(0, 0) + "vfb" + str.substring(0)
        XCTAssertEqual(pieceTable.getLines(), str)
        pieceTable.insert(0, "zRq")
        str = str.substring(0, 0) + "zRq" + str.substring(0)
        XCTAssertEqual(pieceTable.getLines(), str)

        pieceTable.delete(offset: 5, cnt: 1)
        str = str.substring(0, 5) + str.substring(5 + 1)
        XCTAssertEqual(pieceTable.getLines(), str)

        pieceTable.insert(1, "UNw")
        str = str.substring(0, 1) + "UNw" + str.substring(1)
        XCTAssertEqual(pieceTable.getLines(), str)

        pieceTable.delete(offset: 4, cnt: 3)
        str = str.substring(0, 4) + str.substring(4 + 3)
        XCTAssertEqual(pieceTable.getLines(), str)

        pieceTable.delete(offset: 1, cnt: 4)
        str = str.substring(0, 1) + str.substring(1 + 4)
        XCTAssertEqual(pieceTable.getLines(), str)

        pieceTable.delete(offset: 0, cnt: 1)
        str = str.substring(0, 0) + str.substring(0 + 1)
        XCTAssertEqual(pieceTable.getLines(), str)
        assertTreeInvariants(pieceTable)
    }

    func testRandomDelete2 ()
    {
        var str = ""
        let pieceTable = createTextBuffer([""])

        pieceTable.insert(0, "IDT")
        str = str.substring(0, 0) + "IDT" + str.substring(0)
        pieceTable.insert(3, "wwA")
        str = str.substring(0, 3) + "wwA" + str.substring(3)
        pieceTable.insert(3, "Gnr")
        str = str.substring(0, 3) + "Gnr" + str.substring(3)
        pieceTable.delete(offset: 6, cnt: 3)
        str = str.substring(0, 6) + str.substring(6 + 3)
        pieceTable.insert(4, "eHp")
        str = str.substring(0, 4) + "eHp" + str.substring(4)
        pieceTable.insert(1, "UAi")
        str = str.substring(0, 1) + "UAi" + str.substring(1)
        pieceTable.insert(2, "FrR")
        str = str.substring(0, 2) + "FrR" + str.substring(2)
        pieceTable.delete(offset: 6, cnt: 7)
        str = str.substring(0, 6) + str.substring(6 + 7)
        pieceTable.delete(offset: 3, cnt: 5)
        str = str.substring(0, 3) + str.substring(3 + 5)
        XCTAssertEqual(pieceTable.getLines(), str)
        assertTreeInvariants(pieceTable)
    }

    func testRandomeDelete3 ()
    {
        var str = ""
        let pieceTable = createTextBuffer([""])
        pieceTable.insert(0, "PqM")
        str = str.substring(0, 0) + "PqM" + str.substring(0)
        pieceTable.delete(offset: 1, cnt: 2)
        str = str.substring(0, 1) + str.substring(1 + 2)
        pieceTable.insert(1, "zLc")
        str = str.substring(0, 1) + "zLc" + str.substring(1)
        pieceTable.insert(0, "MEX")
        str = str.substring(0, 0) + "MEX" + str.substring(0)
        pieceTable.insert(0, "jZh")
        str = str.substring(0, 0) + "jZh" + str.substring(0)
        pieceTable.insert(8, "GwQ")
        str = str.substring(0, 8) + "GwQ" + str.substring(8)
        pieceTable.delete(offset: 5, cnt: 6)
        str = str.substring(0, 5) + str.substring(5 + 6)
        pieceTable.insert(4, "ktw")
        str = str.substring(0, 4) + "ktw" + str.substring(4)
        pieceTable.insert(5, "GVu")
        str = str.substring(0, 5) + "GVu" + str.substring(5)
        pieceTable.insert(9, "jdm")
        str = str.substring(0, 9) + "jdm" + str.substring(9)
        pieceTable.insert(15, "na\n")
        str = str.substring(0, 15) + "na\n" + str.substring(15)
        pieceTable.delete(offset: 5, cnt: 8)
        str = str.substring(0, 5) + str.substring(5 + 8)
        pieceTable.delete(offset: 3, cnt: 4)
        str = str.substring(0, 3) + str.substring(3 + 4)
        XCTAssertEqual(pieceTable.getLines(), str)
        assertTreeInvariants(pieceTable)
    }

    func testRandomInsertDeleteBug1 ()
    {
        var str = "a"
        let pieceTable = createTextBuffer(["a"])
        
        pieceTable.delete(offset: 0, cnt: 1)
        str = str.substring(0, 0) + str.substring(0 + 1)
        XCTAssertEqual(pieceTable.getLines(), str)
        
        pieceTable.insert(0, "\r\r\n\n")
        str = str.substring(0, 0) + "\r\r\n\n" + str.substring(0)
        XCTAssertEqual(pieceTable.getLines(), str)
        
        pieceTable.delete(offset: 3, cnt: 1)
        str = str.substring(0, 3) + str.substring(3 + 1)
        XCTAssertEqual(pieceTable.getLines(), str)
        
        pieceTable.insert(2, "\n\n\ra")
        str = str.substring(0, 2) + "\n\n\ra" + str.substring(2)
        XCTAssertEqual(pieceTable.getLines(), str)
        
        pieceTable.delete(offset: 4, cnt: 3)
        str = str.substring(0, 4) + str.substring(4 + 3)
        XCTAssertEqual(pieceTable.getLines(), str)
        
        pieceTable.insert(2, "\na\r\r")
        str = str.substring(0, 2) + "\na\r\r" + str.substring(2)
        XCTAssertEqual(pieceTable.getLines(), str)
        pieceTable.insert(6, "\ra\n\n")
        str = str.substring(0, 6) + "\ra\n\n" + str.substring(6)
        XCTAssertEqual(pieceTable.getLines(), str)
        
        pieceTable.insert(0, "aa\n\n")
        str = str.substring(0, 0) + "aa\n\n" + str.substring(0)
        XCTAssertEqual(pieceTable.getLines(), str)
        
        pieceTable.insert(5, "\n\na\r")
        str = str.substring(0, 5) + "\n\na\r" + str.substring(5)
        let lines = pieceTable.getLines()
        
        // If I inline "pieceTable.getLines" below, the result breaks!
        XCTAssertEqual(lines, str)
        
        assertTreeInvariants(pieceTable)
    }
    
    func testRandomInsertDeleteBug2 ()
    {
        //test("random insert/delete \\r bug 2", () => {
        var str = "a"
        let pieceTable = createTextBuffer(["a"])
        pieceTable.insert(1, "\naa\r")
        str = str.substring(0, 1) + "\naa\r" + str.substring(1)
        pieceTable.delete(offset: 0, cnt: 4)
        str = str.substring(0, 0) + str.substring(0 + 4)
        pieceTable.insert(1, "\r\r\na")
        str = str.substring(0, 1) + "\r\r\na" + str.substring(1)
        pieceTable.insert(2, "\n\r\ra")
        str = str.substring(0, 2) + "\n\r\ra" + str.substring(2)
        pieceTable.delete(offset: 4, cnt: 1)
        str = str.substring(0, 4) + str.substring(4 + 1)
        pieceTable.insert(8, "\r\n\r\r")
        str = str.substring(0, 8) + "\r\n\r\r" + str.substring(8)
        pieceTable.insert(7, "\n\n\na")
        str = str.substring(0, 7) + "\n\n\na" + str.substring(7)
        pieceTable.insert(13, "a\n\na")
        str = str.substring(0, 13) + "a\n\na" + str.substring(13)
        pieceTable.delete(offset: 17, cnt: 3)
        str = str.substring(0, 17) + str.substring(17 + 3)
        pieceTable.insert(2, "a\ra\n")
        str = str.substring(0, 2) + "a\ra\n" + str.substring(2)

        XCTAssertEqual(pieceTable.getLines(), str)
        assertTreeInvariants(pieceTable)
    }

    func testRandomInsertDeleteBug3 ()
    {
        // test("random insert/delete \\r bug 3", () => {
        var str = "a"
        let pieceTable = createTextBuffer(["a"])
        pieceTable.insert(0, "\r\na\r")
        str = str.substring(0, 0) + "\r\na\r" + str.substring(0)
        pieceTable.delete(offset: 2, cnt: 3)
        str = str.substring(0, 2) + str.substring(2 + 3)
        pieceTable.insert(2, "a\r\n\r")
        str = str.substring(0, 2) + "a\r\n\r" + str.substring(2)
        pieceTable.delete(offset: 4, cnt: 2)
        str = str.substring(0, 4) + str.substring(4 + 2)
        pieceTable.insert(4, "a\n\r\n")
        str = str.substring(0, 4) + "a\n\r\n" + str.substring(4)
        pieceTable.insert(1, "aa\n\r")
        str = str.substring(0, 1) + "aa\n\r" + str.substring(1)
        pieceTable.insert(7, "\na\r\n")
        str = str.substring(0, 7) + "\na\r\n" + str.substring(7)
        pieceTable.insert(5, "\n\na\r")
        str = str.substring(0, 5) + "\n\na\r" + str.substring(5)
        pieceTable.insert(10, "\r\r\n\r")
        str = str.substring(0, 10) + "\r\r\n\r" + str.substring(10)
        XCTAssertEqual(pieceTable.getLines(), str)
        pieceTable.delete(offset: 21, cnt: 3)
        str = str.substring(0, 21) + str.substring(21 + 3)

        XCTAssertEqual(pieceTable.getLines(), str)
        assertTreeInvariants(pieceTable)
    }
    
    func testRandomInsertDeleteBug4 ()
    {
        //test("random insert/delete \\r bug 4s", () => {
        var str = "a"
        let pieceTable = createTextBuffer(["a"])
        pieceTable.delete(offset: 0, cnt: 1)
        str = str.substring(0, 0) + str.substring(0 + 1)
        pieceTable.insert(0, "\naaa")
        str = str.substring(0, 0) + "\naaa" + str.substring(0)
        pieceTable.insert(2, "\n\naa")
        str = str.substring(0, 2) + "\n\naa" + str.substring(2)
        pieceTable.delete(offset: 1, cnt: 4)
        str = str.substring(0, 1) + str.substring(1 + 4)
        pieceTable.delete(offset: 3, cnt: 1)
        str = str.substring(0, 3) + str.substring(3 + 1)
        pieceTable.delete(offset: 1, cnt: 2)
        str = str.substring(0, 1) + str.substring(1 + 2)
        pieceTable.delete(offset: 0, cnt: 1)
        str = str.substring(0, 0) + str.substring(0 + 1)
        pieceTable.insert(0, "a\n\n\r")
        str = str.substring(0, 0) + "a\n\n\r" + str.substring(0)
        pieceTable.insert(2, "aa\r\n")
        str = str.substring(0, 2) + "aa\r\n" + str.substring(2)
        pieceTable.insert(3, "a\naa")
        str = str.substring(0, 3) + "a\naa" + str.substring(3)

        XCTAssertEqual(pieceTable.getLines(), str)
        assertTreeInvariants(pieceTable)
    }
    
    func testRandomInsertDeleteBug5 ()
    {
        // test("random insert/delete \\r bug 5", () => {
        var str = ""
        let pieceTable = createTextBuffer([""])
        pieceTable.insert(0, "\n\n\n\r")
        str = str.substring(0, 0) + "\n\n\n\r" + str.substring(0)
        XCTAssertEqual(pieceTable.getLines(), str)
        
        pieceTable.insert(1, "\n\n\n\r")
        str = str.substring(0, 1) + "\n\n\n\r" + str.substring(1)
        XCTAssertEqual(pieceTable.getLines(), str)
        
        pieceTable.insert(2, "\n\r\r\r")
        str = str.substring(0, 2) + "\n\r\r\r" + str.substring(2)
        XCTAssertEqual(pieceTable.getLines(), str)
        
        pieceTable.insert(8, "\n\r\n\r")
        str = str.substring(0, 8) + "\n\r\n\r" + str.substring(8)
        XCTAssertEqual(pieceTable.getLines(), str)
        
        pieceTable.delete(offset: 5, cnt: 2)
        str = str.substring(0, 5) + str.substring(5 + 2)
        XCTAssertEqual(pieceTable.getLines(), str)
        
        pieceTable.insert(4, "\n\r\r\r")
        str = str.substring(0, 4) + "\n\r\r\r" + str.substring(4)
        XCTAssertEqual(pieceTable.getLines(), str)
        
        pieceTable.insert(8, "\n\n\n\r")
        str = str.substring(0, 8) + "\n\n\n\r" + str.substring(8)
        XCTAssertEqual(pieceTable.getLines(), str)
        
        pieceTable.delete(offset: 0, cnt: 7)
        str = str.substring(0, 0) + str.substring(0 + 7)
        XCTAssertEqual(pieceTable.getLines(), str)
        
        pieceTable.insert(1, "\r\n\r\r")
        str = str.substring(0, 1) + "\r\n\r\r" + str.substring(1)
        XCTAssertEqual(pieceTable.getLines(), str)
        
        pieceTable.insert(15, "\n\r\r\r")
        var bstr = toBytes (str)
        bstr = bstr [0..<15] + [10,13,13,13] + bstr[15...]
        str = str.substring(0, 15) + "\n\r\r\r" + str.substring(15)
        XCTAssertEqual(pieceTable.getLinesRawContent (), bstr)
        
        assertTreeInvariants(pieceTable)
    }
    
    func testPrefixSumForLineFeed ()
    {
        let pieceTable = createTextBuffer(["1\n2\n3\n4"])

        XCTAssertEqual(pieceTable.lineCount, 4)
        XCTAssertEqual(pieceTable.getPositionAt(0), Position(line: 1, column: 1))
        XCTAssertEqual(pieceTable.getPositionAt(1), Position(line: 1, column: 2))
        XCTAssertEqual(pieceTable.getPositionAt(2), Position(line: 2, column: 1))
        XCTAssertEqual(pieceTable.getPositionAt(3), Position(line: 2, column: 2))
        XCTAssertEqual(pieceTable.getPositionAt(4), Position(line: 3, column: 1))
        XCTAssertEqual(pieceTable.getPositionAt(5), Position(line: 3, column: 2))
        XCTAssertEqual(pieceTable.getPositionAt(6), Position(line: 4, column: 1))

        XCTAssertEqual(pieceTable.getOffsetAt(1, 1), 0)
        XCTAssertEqual(pieceTable.getOffsetAt(1, 2), 1)
        XCTAssertEqual(pieceTable.getOffsetAt(2, 1), 2)
        XCTAssertEqual(pieceTable.getOffsetAt(2, 2), 3)
        XCTAssertEqual(pieceTable.getOffsetAt(3, 1), 4)
        XCTAssertEqual(pieceTable.getOffsetAt(3, 2), 5)
        XCTAssertEqual(pieceTable.getOffsetAt(4, 1), 6)
        assertTreeInvariants(pieceTable)
    }

    func testAppend1 ()
    {
        let pieceTable = createTextBuffer(["a\nb\nc\nde"])
        pieceTable.insert(8, "fh\ni\njk")

        XCTAssertEqual(pieceTable.lineCount, 6)
        XCTAssertEqual(pieceTable.getPositionAt(9), Position(line: 4, column: 4))
        XCTAssertEqual(pieceTable.getOffsetAt(1, 1), 0)
        assertTreeInvariants(pieceTable)
    }

    func testInsert1 ()
    {
        let pieceTable = createTextBuffer(["a\nb\nc\nde"])
        pieceTable.insert(7, "fh\ni\njk")

        XCTAssertEqual(pieceTable.lineCount, 6)
        XCTAssertEqual(pieceTable.getPositionAt(6), Position(line: 4, column: 1))
        XCTAssertEqual(pieceTable.getPositionAt(7), Position(line: 4, column: 2))
        XCTAssertEqual(pieceTable.getPositionAt(8), Position(line: 4, column: 3))
        XCTAssertEqual(pieceTable.getPositionAt(9), Position(line: 4, column: 4))
        XCTAssertEqual(pieceTable.getPositionAt(12), Position(line: 6, column: 1))
        XCTAssertEqual(pieceTable.getPositionAt(13), Position(line: 6, column: 2))
        XCTAssertEqual(pieceTable.getPositionAt(14), Position(line: 6, column: 3))

        XCTAssertEqual(pieceTable.getOffsetAt(4, 1), 6)
        XCTAssertEqual(pieceTable.getOffsetAt(4, 2), 7)
        XCTAssertEqual(pieceTable.getOffsetAt(4, 3), 8)
        XCTAssertEqual(pieceTable.getOffsetAt(4, 4), 9)
        XCTAssertEqual(pieceTable.getOffsetAt(6, 1), 12)
        XCTAssertEqual(pieceTable.getOffsetAt(6, 2), 13)
        XCTAssertEqual(pieceTable.getOffsetAt(6, 3), 14)
        assertTreeInvariants(pieceTable)
    }

    func testDelete2 ()
    {
        let pieceTable = createTextBuffer(["a\nb\nc\ndefh\ni\njk"])
        pieceTable.delete(offset: 7, cnt: 2)

        XCTAssertEqual(pieceTable.getLines(), "a\nb\nc\ndh\ni\njk")
        XCTAssertEqual(pieceTable.lineCount, 6)
        XCTAssertEqual(pieceTable.getPositionAt(6), Position(line: 4, column: 1))
        XCTAssertEqual(pieceTable.getPositionAt(7), Position(line: 4, column: 2))
        XCTAssertEqual(pieceTable.getPositionAt(8), Position(line: 4, column: 3))
        XCTAssertEqual(pieceTable.getPositionAt(9), Position(line: 5, column: 1))
        XCTAssertEqual(pieceTable.getPositionAt(11), Position(line: 6, column: 1))
        XCTAssertEqual(pieceTable.getPositionAt(12), Position(line: 6, column: 2))
        XCTAssertEqual(pieceTable.getPositionAt(13), Position(line: 6, column: 3))

        XCTAssertEqual(pieceTable.getOffsetAt(4, 1), 6)
        XCTAssertEqual(pieceTable.getOffsetAt(4, 2), 7)
        XCTAssertEqual(pieceTable.getOffsetAt(4, 3), 8)
        XCTAssertEqual(pieceTable.getOffsetAt(5, 1), 9)
        XCTAssertEqual(pieceTable.getOffsetAt(6, 1), 11)
        XCTAssertEqual(pieceTable.getOffsetAt(6, 2), 12)
        XCTAssertEqual(pieceTable.getOffsetAt(6, 3), 13)
        assertTreeInvariants(pieceTable)
    }

    func testAddPlusDelete1 ()
    {
        let pieceTable = createTextBuffer(["a\nb\nc\nde"])
        pieceTable.insert(8, "fh\ni\njk")
        pieceTable.delete(offset: 7, cnt: 2)

        XCTAssertEqual(pieceTable.getLines(), "a\nb\nc\ndh\ni\njk")
        XCTAssertEqual(pieceTable.lineCount, 6)
        XCTAssertEqual(pieceTable.getPositionAt(6), Position(line: 4, column: 1))
        XCTAssertEqual(pieceTable.getPositionAt(7), Position(line: 4, column: 2))
        XCTAssertEqual(pieceTable.getPositionAt(8), Position(line: 4, column: 3))
        XCTAssertEqual(pieceTable.getPositionAt(9), Position(line: 5, column: 1))
        XCTAssertEqual(pieceTable.getPositionAt(11), Position(line: 6, column: 1))
        XCTAssertEqual(pieceTable.getPositionAt(12), Position(line: 6, column: 2))
        XCTAssertEqual(pieceTable.getPositionAt(13), Position(line: 6, column: 3))

        XCTAssertEqual(pieceTable.getOffsetAt(4, 1), 6)
        XCTAssertEqual(pieceTable.getOffsetAt(4, 2), 7)
        XCTAssertEqual(pieceTable.getOffsetAt(4, 3), 8)
        XCTAssertEqual(pieceTable.getOffsetAt(5, 1), 9)
        XCTAssertEqual(pieceTable.getOffsetAt(6, 1), 11)
        XCTAssertEqual(pieceTable.getOffsetAt(6, 2), 12)
        XCTAssertEqual(pieceTable.getOffsetAt(6, 3), 13)
        assertTreeInvariants(pieceTable)
    }

    func testInsertBug1 ()
    {
        // insert random bug 1: prefixSumComputer.removeValues(start, cnt) cnt is 1 based.
        var str = ""
        let pieceTable = createTextBuffer([""])
        pieceTable.insert(0, " ZX \n Z\nZ\n YZ\nY\nZXX ")
        str =
            str.substring(0, 0) +
            " ZX \n Z\nZ\n YZ\nY\nZXX " +
            str.substring(0)
        pieceTable.insert(14, "X ZZ\nYZZYZXXY Y XY\n ")
        str =
            str.substring(0, 14) + "X ZZ\nYZZYZXXY Y XY\n " + str.substring(14)

        XCTAssertEqual(pieceTable.getLines(), str)
        testLineStarts(str, pieceTable)
        assertTreeInvariants(pieceTable)
    }
    

    func testInsertBug2 ()
    {
        // insert random bug 2: prefixSumComputer initialize does not do deep copy of UInt32Array.
        var str = ""
        let pieceTable = createTextBuffer([""])
        pieceTable.insert(0, "ZYZ\nYY XY\nX \nZ Y \nZ ")
        str =
            str.substring(0, 0) + "ZYZ\nYY XY\nX \nZ Y \nZ " + str.substring(0)
        pieceTable.insert(3, "XXY \n\nY Y YYY  ZYXY ")
        str = str.substring(0, 3) + "XXY \n\nY Y YYY  ZYXY " + str.substring(3)

        XCTAssertEqual(pieceTable.getLines(), str)
        testLineStarts(str, pieceTable)
        assertTreeInvariants(pieceTable)
    }

    func testDeleteBug1 ()
    {
        // delete random bug 1: I forgot to update the lineFeedCount when deletion is on one single piece.
        let pieceTable = createTextBuffer([""])
        pieceTable.insert(0, "ba\na\nca\nba\ncbab\ncaa ")
        pieceTable.insert(13, "cca\naabb\ncac\nccc\nab ")
        pieceTable.delete(offset: 5, cnt: 8)
        pieceTable.delete(offset: 30, cnt: 2)
        pieceTable.insert(24, "cbbacccbac\nbaaab\n\nc ")
        pieceTable.delete(offset: 29, cnt: 3)
        pieceTable.delete(offset: 23, cnt: 9)
        pieceTable.delete(offset: 21, cnt: 5)
        pieceTable.delete(offset: 30, cnt: 3)
        pieceTable.insert(3, "cb\nac\nc\n\nacc\nbb\nb\nc ")
        pieceTable.delete(offset: 19, cnt: 5)
        pieceTable.insert(18, "\nbb\n\nacbc\ncbb\nc\nbb\n ")
        pieceTable.insert(65, "cbccbac\nbc\n\nccabba\n ")
        pieceTable.insert(77, "a\ncacb\n\nac\n\n\n\n\nabab ")
        pieceTable.delete(offset: 30, cnt: 9)
        pieceTable.insert(45, "b\n\nc\nba\n\nbbbba\n\naa\n ")
        pieceTable.insert(82, "ab\nbb\ncabacab\ncbc\na ")
        pieceTable.delete(offset: 123, cnt: 9)
        pieceTable.delete(offset: 71, cnt: 2)
        pieceTable.insert(33, "acaa\nacb\n\naa\n\nc\n\n\n\n ")

        let str = pieceTable.getLines()
        testLineStarts(str, pieceTable)
        assertTreeInvariants(pieceTable)
    }

    func testDeleteBugRbTree1 ()
    {
        //delete random bug rb tree 1
        var str = ""
        let pieceTable = createTextBuffer([str])
        pieceTable.insert(0, "YXXZ\n\nYY\n")
        str = str.substring(0, 0) + "YXXZ\n\nYY\n" + str.substring(0)
        pieceTable.delete(offset: 0, cnt: 5)
        str = str.substring(0, 0) + str.substring(0 + 5)
        pieceTable.insert(0, "ZXYY\nX\nZ\n")
        str = str.substring(0, 0) + "ZXYY\nX\nZ\n" + str.substring(0)
        pieceTable.insert(10, "\nXY\nYXYXY")
        str = str.substring(0, 10) + "\nXY\nYXYXY" + str.substring(10)
        testLineStarts(str, pieceTable)
        assertTreeInvariants(pieceTable)
    }

    func testDeleteBugRbTree2 ()
    {
        var str = ""
        let pieceTable = createTextBuffer([str])
        pieceTable.insert(0, "YXXZ\n\nYY\n")
        str = str.substring(0, 0) + "YXXZ\n\nYY\n" + str.substring(0)
        pieceTable.insert(0, "ZXYY\nX\nZ\n")
        str = str.substring(0, 0) + "ZXYY\nX\nZ\n" + str.substring(0)
        pieceTable.insert(10, "\nXY\nYXYXY")
        str = str.substring(0, 10) + "\nXY\nYXYXY" + str.substring(10)
        pieceTable.insert(8, "YZXY\nZ\nYX")
        str = str.substring(0, 8) + "YZXY\nZ\nYX" + str.substring(8)
        pieceTable.insert(12, "XX\nXXYXYZ")
        str = str.substring(0, 12) + "XX\nXXYXYZ" + str.substring(12)
        pieceTable.delete(offset: 0, cnt: 4)
        str = str.substring(0, 0) + str.substring(0 + 4)

        testLineStarts(str, pieceTable)
        assertTreeInvariants(pieceTable)
    }

    func testDeleteBugRb3 ()
    {
        //        test("delete random bug rb tree 3", () => {
        var str = ""
        let pieceTable = createTextBuffer([str])
        pieceTable.insert(0, "YXXZ\n\nYY\n")
        str = str.substring(0, 0) + "YXXZ\n\nYY\n" + str.substring(0)
        pieceTable.delete(offset: 7, cnt: 2)
        str = str.substring(0, 7) + str.substring(7 + 2)
        pieceTable.delete(offset: 6, cnt: 1)
        str = str.substring(0, 6) + str.substring(6 + 1)
        pieceTable.delete(offset: 0, cnt: 5)
        str = str.substring(0, 0) + str.substring(0 + 5)
        pieceTable.insert(0, "ZXYY\nX\nZ\n")
        str = str.substring(0, 0) + "ZXYY\nX\nZ\n" + str.substring(0)
        pieceTable.insert(10, "\nXY\nYXYXY")
        str = str.substring(0, 10) + "\nXY\nYXYXY" + str.substring(10)
        pieceTable.insert(8, "YZXY\nZ\nYX")
        str = str.substring(0, 8) + "YZXY\nZ\nYX" + str.substring(8)
        pieceTable.insert(12, "XX\nXXYXYZ")
        str = str.substring(0, 12) + "XX\nXXYXYZ" + str.substring(12)
        pieceTable.delete(offset: 0, cnt: 4)
        str = str.substring(0, 0) + str.substring(0 + 4)
        pieceTable.delete(offset: 30, cnt: 3)
        str = str.substring(0, 30) + str.substring(30 + 3)

        testLineStarts(str, pieceTable)
        assertTreeInvariants(pieceTable)
    }

    func testOffset2PositionTests ()
    {
//    suite("offset 2 position", () => {
//        test("random tests bug 1", () => {
        var str = ""
        let pieceTable = createTextBuffer([""])
        pieceTable.insert(0, "huuyYzUfKOENwGgZLqn ")
        str = str.substring(0, 0) + "huuyYzUfKOENwGgZLqn " + str.substring(0)
        pieceTable.delete(offset: 18, cnt: 2)
        str = str.substring(0, 18) + str.substring(18 + 2)
        pieceTable.delete(offset: 3, cnt: 1)
        str = str.substring(0, 3) + str.substring(3 + 1)
        pieceTable.delete(offset: 12, cnt: 4)
        str = str.substring(0, 12) + str.substring(12 + 4)
        pieceTable.insert(3, "hMbnVEdTSdhLlPevXKF ")
        str = str.substring(0, 3) + "hMbnVEdTSdhLlPevXKF " + str.substring(3)
        pieceTable.delete(offset: 22, cnt: 8)
        str = str.substring(0, 22) + str.substring(22 + 8)
        pieceTable.insert(4, "S umSnYrqOmOAV\nEbZJ ")
        str = str.substring(0, 4) + "S umSnYrqOmOAV\nEbZJ " + str.substring(4)

        testLineStarts(str, pieceTable)
        assertTreeInvariants(pieceTable)
    }

    func getContentInRange ()
    {
        let pieceTable = createTextBuffer(["a\nb\nc\nde"])
        pieceTable.insert(8, "fh\ni\njk")
        pieceTable.delete(offset: 7, cnt: 2)
        // "a\nb\nc\ndh\ni\njk"

        XCTAssertEqual(toStr (pieceTable.getValueInRange(range: Range(startLineNumber: 1, startColumn: 1, endLineNumber: 1, endColumn: 3))), "a\n")
        XCTAssertEqual(toStr (pieceTable.getValueInRange(range: Range(startLineNumber: 2, startColumn: 1, endLineNumber: 2, endColumn: 3))), "b\n")
        XCTAssertEqual(toStr (pieceTable.getValueInRange(range: Range(startLineNumber: 3, startColumn: 1, endLineNumber: 3, endColumn: 3))), "c\n")
        XCTAssertEqual(toStr (pieceTable.getValueInRange(range: Range(startLineNumber: 4, startColumn: 1, endLineNumber: 4, endColumn: 4))), "dh\n")
        XCTAssertEqual(toStr (pieceTable.getValueInRange(range: Range(startLineNumber: 5, startColumn: 1, endLineNumber: 5, endColumn: 3))), "i\n")
        XCTAssertEqual(toStr (pieceTable.getValueInRange(range: Range(startLineNumber: 6, startColumn: 1, endLineNumber: 6, endColumn: 3))), "jk")
        assertTreeInvariants(pieceTable)
    }

    func testValueInRange ()
    {
        //        test("random test value in range", () => {
        var str = ""
        let pieceTable = createTextBuffer([str])

        pieceTable.insert(0, "ZXXY")
        str = str.substring(0, 0) + "ZXXY" + str.substring(0)
        pieceTable.insert(1, "XZZY")
        str = str.substring(0, 1) + "XZZY" + str.substring(1)
        pieceTable.insert(5, "\nX\n\n")
        str = str.substring(0, 5) + "\nX\n\n" + str.substring(5)
        pieceTable.insert(3, "\nXX\n")
        str = str.substring(0, 3) + "\nXX\n" + str.substring(3)
        pieceTable.insert(12, "YYYX")
        str = str.substring(0, 12) + "YYYX" + str.substring(12)

        testLinesContent(str, pieceTable)
        assertTreeInvariants(pieceTable)
    }
    
    func testRandomTestValueInRangeException ()
    {
        // test("random test value in range exception", () => {
        var str = ""
        let pieceTable = createTextBuffer([str])

        pieceTable.insert(0, "XZ\nZ")
        str = str.substring(0, 0) + "XZ\nZ" + str.substring(0)
        pieceTable.delete(offset: 0, cnt: 3)
        str = str.substring(0, 0) + str.substring(0 + 3)
        pieceTable.delete(offset: 0, cnt: 1)
        str = str.substring(0, 0) + str.substring(0 + 1)
        pieceTable.insert(0, "ZYX\n")
        str = str.substring(0, 0) + "ZYX\n" + str.substring(0)
        pieceTable.delete(offset: 0, cnt: 4)
        str = str.substring(0, 0) + str.substring(0 + 4)

        pieceTable.getValueInRange(range: Range(startLineNumber: 1, startColumn: 1, endLineNumber: 1, endColumn: 1))
        assertTreeInvariants(pieceTable)
    }
    
    func testRandomTestsBug1 ()
    {
        // test("random tests bug 1", () => {
        var str = ""
        let pieceTable = createTextBuffer([""])
        pieceTable.insert(0, "huuyYzUfKOENwGgZLqn ")
        str = str.substring(0, 0) + "huuyYzUfKOENwGgZLqn " + str.substring(0)
        pieceTable.delete(offset: 18, cnt: 2)
        str = str.substring(0, 18) + str.substring(18 + 2)
        pieceTable.delete(offset: 3, cnt: 1)
        str = str.substring(0, 3) + str.substring(3 + 1)
        pieceTable.delete(offset: 12, cnt: 4)
        str = str.substring(0, 12) + str.substring(12 + 4)
        pieceTable.insert(3, "hMbnVEdTSdhLlPevXKF ")
        str = str.substring(0, 3) + "hMbnVEdTSdhLlPevXKF " + str.substring(3)
        pieceTable.delete(offset: 22, cnt: 8)
        str = str.substring(0, 22) + str.substring(22 + 8)
        pieceTable.insert(4, "S umSnYrqOmOAV\nEbZJ ")
        str = str.substring(0, 4) + "S umSnYrqOmOAV\nEbZJ " + str.substring(4)
        testLinesContent(str, pieceTable)
        assertTreeInvariants(pieceTable)
    }

    func testRandomTestsBug2 ()
    {
        // test("random tests bug 2", () => {
        var str = ""
        let pieceTable = createTextBuffer([""])
        pieceTable.insert(0, "xfouRDZwdAHjVXJAMV\n ")
        str = str.substring(0, 0) + "xfouRDZwdAHjVXJAMV\n " + str.substring(0)
        pieceTable.insert(16, "dBGndxpFZBEAIKykYYx ")
        str = str.substring(0, 16) + "dBGndxpFZBEAIKykYYx " + str.substring(16)
        pieceTable.delete(offset: 7, cnt: 6)
        str = str.substring(0, 7) + str.substring(7 + 6)
        pieceTable.delete(offset: 9, cnt: 7)
        str = str.substring(0, 9) + str.substring(9 + 7)
        pieceTable.delete(offset: 17, cnt: 6)
        str = str.substring(0, 17) + str.substring(17 + 6)
        pieceTable.delete(offset: 0, cnt: 4)
        str = str.substring(0, 0) + str.substring(0 + 4)
        pieceTable.insert(9, "qvEFXCNvVkWgvykahYt ")
        str = str.substring(0, 9) + "qvEFXCNvVkWgvykahYt " + str.substring(9)
        pieceTable.delete(offset: 4, cnt: 6)
        str = str.substring(0, 4) + str.substring(4 + 6)
        pieceTable.insert(11, "OcSChUYT\nzPEBOpsGmR ")
        str =
            str.substring(0, 11) + "OcSChUYT\nzPEBOpsGmR " + str.substring(11)
        pieceTable.insert(15, "KJCozaXTvkE\nxnqAeTz ")
        str =
            str.substring(0, 15) + "KJCozaXTvkE\nxnqAeTz " + str.substring(15)

        testLinesContent(str, pieceTable)
        assertTreeInvariants(pieceTable)
    }
    
    func testGetLineContent ()
    {
        // test("get line content", () => {
        let pieceTable = createTextBuffer(["1"])
        XCTAssertEqual(pieceTable.getLineRawContent(1), toBytes ("1"))
        pieceTable.insert(1, "2")
        XCTAssertEqual(pieceTable.getLineRawContent(1), toBytes ("12"))
        assertTreeInvariants(pieceTable)
    }
    
    func testGetLineContentBasic ()
    {
        // test("get line content basic", () => {
        let pieceTable = createTextBuffer(["1\n2\n3\n4"])
        XCTAssertEqual(pieceTable.getLineRawContent(1), toBytes ("1\n"))
        XCTAssertEqual(pieceTable.getLineRawContent(2), toBytes ("2\n"))
        XCTAssertEqual(pieceTable.getLineRawContent(3), toBytes ("3\n"))
        XCTAssertEqual(pieceTable.getLineRawContent(4), toBytes ("4"))
        assertTreeInvariants(pieceTable)
    }
    
    func testGetLineContentAfterInsertDeletes ()
    {
        // test("get line content after inserts/deletes", () => {
        let pieceTable = createTextBuffer(["a\nb\nc\nde"])
        pieceTable.insert(8, "fh\ni\njk")
        pieceTable.delete(offset: 7, cnt: 2)
        // "a\nb\nc\ndh\ni\njk"

        XCTAssertEqual(pieceTable.getLineRawContent(1), toBytes ("a\n"))
        XCTAssertEqual(pieceTable.getLineRawContent(2), toBytes ("b\n"))
        XCTAssertEqual(pieceTable.getLineRawContent(3), toBytes ("c\n"))
        XCTAssertEqual(pieceTable.getLineRawContent(4), toBytes ("dh\n"))
        XCTAssertEqual(pieceTable.getLineRawContent(5), toBytes ("i\n"))
        XCTAssertEqual(pieceTable.getLineRawContent(6), toBytes ("jk"))
        assertTreeInvariants(pieceTable)
    }

    func testRandom10 ()
    {
        // test("random 1", () => {
        var str = ""
        let pieceTable = createTextBuffer([""])

        pieceTable.insert(0, "J eNnDzQpnlWyjmUu\ny ")
        str = str.substring(0, 0) + "J eNnDzQpnlWyjmUu\ny " + str.substring(0)
        pieceTable.insert(0, "QPEeRAQmRwlJqtZSWhQ ")
        str = str.substring(0, 0) + "QPEeRAQmRwlJqtZSWhQ " + str.substring(0)
        pieceTable.delete(offset: 5, cnt: 1)
        str = str.substring(0, 5) + str.substring(5 + 1)

        testLinesContent(str, pieceTable)
        assertTreeInvariants(pieceTable)
    }
    
    func testRandom12 ()
    {
        // test("random 2", () => {
        var str = ""
        let pieceTable = createTextBuffer([""])
        pieceTable.insert(0, "DZoQ tglPCRHMltejRI ")
        str = str.substring(0, 0) + "DZoQ tglPCRHMltejRI " + str.substring(0)
        pieceTable.insert(10, "JRXiyYqJ qqdcmbfkKX ")
        str = str.substring(0, 10) + "JRXiyYqJ qqdcmbfkKX " + str.substring(10)
        pieceTable.delete(offset: 16, cnt: 3)
        str = str.substring(0, 16) + str.substring(16 + 3)
        pieceTable.delete(offset: 25, cnt: 1)
        str = str.substring(0, 25) + str.substring(25 + 1)
        pieceTable.insert(18, "vH\nNlvfqQJPm\nSFkhMc ")
        str = str.substring(0, 18) + "vH\nNlvfqQJPm\nSFkhMc " + str.substring(18)

        testLinesContent(str, pieceTable)
        assertTreeInvariants(pieceTable)
    }

    func testCRLF_deleteCRinCRLF1 ()
    {
        let pieceTable = createTextBuffer([""], false)
        pieceTable.insert(0, "a\r\nb")
        pieceTable.delete(offset: 0, cnt: 2)

        XCTAssertEqual(pieceTable.lineCount, 2)
        assertTreeInvariants(pieceTable)
    }
    
    func testCRLF_deleteCRinCRLF2 ()
    {
        //        test("delete CR in CRLF 2", () => {
        let pieceTable = createTextBuffer([""], false)
        pieceTable.insert(0, "a\r\nb")
        pieceTable.delete(offset: 2, cnt: 2)

        XCTAssertEqual(pieceTable.lineCount, 2)
        assertTreeInvariants(pieceTable)
    }

//        test("random bug 1", () => {
//            var str = ""
//            let pieceTable = createTextBuffer([""], false)
//            pieceTable.insert(0, "\n\n\r\r")
//            str = str.substring(0, 0) + "\n\n\r\r" + str.substring(0)
//            pieceTable.insert(1, "\r\n\r\n")
//            str = str.substring(0, 1) + "\r\n\r\n" + str.substring(1)
//            pieceTable.delete(5, 3)
//            str = str.substring(0, 5) + str.substring(5 + 3)
//            pieceTable.delete(2, 3)
//            str = str.substring(0, 2) + str.substring(2 + 3)
//
//            let lines = str.split(/\r\n|\r|\n/)
//            XCTAssertEqual(pieceTable.lineCount, lines.count)
//            assertTreeInvariants(pieceTable)
//        })
//        test("random bug 2", () => {
//            var str = ""
//            let pieceTable = createTextBuffer([""], false)
//
//            pieceTable.insert(0, "\n\r\n\r")
//            str = str.substring(0, 0) + "\n\r\n\r" + str.substring(0)
//            pieceTable.insert(2, "\n\r\r\r")
//            str = str.substring(0, 2) + "\n\r\r\r" + str.substring(2)
//            pieceTable.delete(4, 1)
//            str = str.substring(0, 4) + str.substring(4 + 1)
//
//            let lines = str.split(/\r\n|\r|\n/)
//            XCTAssertEqual(pieceTable.lineCount, lines.count)
//            assertTreeInvariants(pieceTable)
//        })
//        test("random bug 3", () => {
//            var str = ""
//            let pieceTable = createTextBuffer([""], false)
//
//            pieceTable.insert(0, "\n\n\n\r")
//            str = str.substring(0, 0) + "\n\n\n\r" + str.substring(0)
//            pieceTable.delete(2, 2)
//            str = str.substring(0, 2) + str.substring(2 + 2)
//            pieceTable.delete(0, 2)
//            str = str.substring(0, 0) + str.substring(0 + 2)
//            pieceTable.insert(0, "\r\r\r\r")
//            str = str.substring(0, 0) + "\r\r\r\r" + str.substring(0)
//            pieceTable.insert(2, "\r\n\r\r")
//            str = str.substring(0, 2) + "\r\n\r\r" + str.substring(2)
//            pieceTable.insert(3, "\r\r\r\n")
//            str = str.substring(0, 3) + "\r\r\r\n" + str.substring(3)
//
//            let lines = str.split(/\r\n|\r|\n/)
//            XCTAssertEqual(pieceTable.lineCount, lines.count)
//            assertTreeInvariants(pieceTable)
//        })
//        test("random bug 4", () => {
//            var str = ""
//            let pieceTable = createTextBuffer([""], false)
//
//            pieceTable.insert(0, "\n\n\n\n")
//            str = str.substring(0, 0) + "\n\n\n\n" + str.substring(0)
//            pieceTable.delete(3, 1)
//            str = str.substring(0, 3) + str.substring(3 + 1)
//            pieceTable.insert(1, "\r\r\r\r")
//            str = str.substring(0, 1) + "\r\r\r\r" + str.substring(1)
//            pieceTable.insert(6, "\r\n\n\r")
//            str = str.substring(0, 6) + "\r\n\n\r" + str.substring(6)
//            pieceTable.delete(5, 3)
//            str = str.substring(0, 5) + str.substring(5 + 3)
//
//            testLinesContent(str, pieceTable)
//            assertTreeInvariants(pieceTable)
//        })
//        test("random bug 5", () => {
//            var str = ""
//            let pieceTable = createTextBuffer([""], false)
//
//            pieceTable.insert(0, "\n\n\n\n")
//            str = str.substring(0, 0) + "\n\n\n\n" + str.substring(0)
//            pieceTable.delete(3, 1)
//            str = str.substring(0, 3) + str.substring(3 + 1)
//            pieceTable.insert(0, "\n\r\r\n")
//            str = str.substring(0, 0) + "\n\r\r\n" + str.substring(0)
//            pieceTable.insert(4, "\n\r\r\n")
//            str = str.substring(0, 4) + "\n\r\r\n" + str.substring(4)
//            pieceTable.delete(4, 3)
//            str = str.substring(0, 4) + str.substring(4 + 3)
//            pieceTable.insert(5, "\r\r\n\r")
//            str = str.substring(0, 5) + "\r\r\n\r" + str.substring(5)
//            pieceTable.insert(12, "\n\n\n\r")
//            str = str.substring(0, 12) + "\n\n\n\r" + str.substring(12)
//            pieceTable.insert(5, "\r\r\r\n")
//            str = str.substring(0, 5) + "\r\r\r\n" + str.substring(5)
//            pieceTable.insert(20, "\n\n\r\n")
//            str = str.substring(0, 20) + "\n\n\r\n" + str.substring(20)
//
//            testLinesContent(str, pieceTable)
//            assertTreeInvariants(pieceTable)
//        })
//        test("random bug 6", () => {
//            var str = ""
//            let pieceTable = createTextBuffer([""], false)
//
//            pieceTable.insert(0, "\n\r\r\n")
//            str = str.substring(0, 0) + "\n\r\r\n" + str.substring(0)
//            pieceTable.insert(4, "\r\n\n\r")
//            str = str.substring(0, 4) + "\r\n\n\r" + str.substring(4)
//            pieceTable.insert(3, "\r\n\n\n")
//            str = str.substring(0, 3) + "\r\n\n\n" + str.substring(3)
//            pieceTable.delete(4, 8)
//            str = str.substring(0, 4) + str.substring(4 + 8)
//            pieceTable.insert(4, "\r\n\n\r")
//            str = str.substring(0, 4) + "\r\n\n\r" + str.substring(4)
//            pieceTable.insert(0, "\r\n\n\r")
//            str = str.substring(0, 0) + "\r\n\n\r" + str.substring(0)
//            pieceTable.delete(4, 0)
//            str = str.substring(0, 4) + str.substring(4 + 0)
//            pieceTable.delete(8, 4)
//            str = str.substring(0, 8) + str.substring(8 + 4)
//
//            testLinesContent(str, pieceTable)
//            assertTreeInvariants(pieceTable)
//        })
//        test("random bug 8", () => {
//            var str = ""
//            let pieceTable = createTextBuffer([""], false)
//
//            pieceTable.insert(0, "\r\n\n\r")
//            str = str.substring(0, 0) + "\r\n\n\r" + str.substring(0)
//            pieceTable.delete(1, 0)
//            str = str.substring(0, 1) + str.substring(1 + 0)
//            pieceTable.insert(3, "\n\n\n\r")
//            str = str.substring(0, 3) + "\n\n\n\r" + str.substring(3)
//            pieceTable.insert(7, "\n\n\r\n")
//            str = str.substring(0, 7) + "\n\n\r\n" + str.substring(7)
//
//            testLinesContent(str, pieceTable)
//            assertTreeInvariants(pieceTable)
//        })
//        test("random bug 7", () => {
//            var str = ""
//            let pieceTable = createTextBuffer([""], false)
//
//            pieceTable.insert(0, "\r\r\n\n")
//            str = str.substring(0, 0) + "\r\r\n\n" + str.substring(0)
//            pieceTable.insert(4, "\r\n\n\r")
//            str = str.substring(0, 4) + "\r\n\n\r" + str.substring(4)
//            pieceTable.insert(7, "\n\r\r\r")
//            str = str.substring(0, 7) + "\n\r\r\r" + str.substring(7)
//            pieceTable.insert(11, "\n\n\r\n")
//            str = str.substring(0, 11) + "\n\n\r\n" + str.substring(11)
//            testLinesContent(str, pieceTable)
//            assertTreeInvariants(pieceTable)
//        })
//
//        test("random bug 10", () => {
//            var str = ""
//            let pieceTable = createTextBuffer([""], false)
//
//            pieceTable.insert(0, "qneW")
//            str = str.substring(0, 0) + "qneW" + str.substring(0)
//            pieceTable.insert(0, "YhIl")
//            str = str.substring(0, 0) + "YhIl" + str.substring(0)
//            pieceTable.insert(0, "qdsm")
//            str = str.substring(0, 0) + "qdsm" + str.substring(0)
//            pieceTable.delete(7, 0)
//            str = str.substring(0, 7) + str.substring(7 + 0)
//            pieceTable.insert(12, "iiPv")
//            str = str.substring(0, 12) + "iiPv" + str.substring(12)
//            pieceTable.insert(9, "V\rSA")
//            str = str.substring(0, 9) + "V\rSA" + str.substring(9)
//
//            testLinesContent(str, pieceTable)
//            assertTreeInvariants(pieceTable)
//        })
//
//        test("random bug 9", () => {
//            var str = ""
//            let pieceTable = createTextBuffer([""], false)
//
//            pieceTable.insert(0, "\n\n\n\n")
//            str = str.substring(0, 0) + "\n\n\n\n" + str.substring(0)
//            pieceTable.insert(3, "\n\r\n\r")
//            str = str.substring(0, 3) + "\n\r\n\r" + str.substring(3)
//            pieceTable.insert(2, "\n\r\n\n")
//            str = str.substring(0, 2) + "\n\r\n\n" + str.substring(2)
//            pieceTable.insert(0, "\n\n\r\r")
//            str = str.substring(0, 0) + "\n\n\r\r" + str.substring(0)
//            pieceTable.insert(3, "\r\r\r\r")
//            str = str.substring(0, 3) + "\r\r\r\r" + str.substring(3)
//            pieceTable.insert(3, "\n\n\r\r")
//            str = str.substring(0, 3) + "\n\n\r\r" + str.substring(3)
//
//            testLinesContent(str, pieceTable)
//            assertTreeInvariants(pieceTable)
//        })
//    })

    // suite("centralized lineStarts with CRLF", () => {
    
    func testDeleteCRinCRLF1 ()
    {
        let pieceTable = createTextBuffer(["a\r\nb"], false)
        pieceTable.delete(offset: 2, cnt: 2)
        XCTAssertEqual(pieceTable.lineCount, 2)
        assertTreeInvariants(pieceTable)
    }
    
    func testDeleteCRinCRLf2 ()
    {
        //test("delete CR in CRLF 2", () => {
        let pieceTable = createTextBuffer(["a\r\nb"])
        pieceTable.delete(offset: 0, cnt: 2)

        XCTAssertEqual(pieceTable.lineCount, 2)
        assertTreeInvariants(pieceTable)
    }

    func testCentralized_Random1 ()
    {
        // test("random bug 1", () => {
        var str = "\n\n\r\r"
        let pieceTable = createTextBuffer(["\n\n\r\r"], false)
        pieceTable.insert(1, "\r\n\r\n")
        str = str.substring(0, 1) + "\r\n\r\n" + str.substring(1)
        pieceTable.delete(offset: 5, cnt: 3)
        str = str.substring(0, 5) + str.substring(5 + 3)
        pieceTable.delete(offset: 2, cnt: 3)
        str = str.substring(0, 2) + str.substring(2 + 3)

        // TODO: split
        // let lines = str.split(/\r,\n|\r|\n/)
        // XCTAssertEqual(pieceTable.lineCount, lines.count)
        assertTreeInvariants(pieceTable)
    }
    
    func testCentralized_random2 ()
    {
        // test("random bug 2", () => {
        var str = "\n\r\n\r"
        let pieceTable = createTextBuffer(["\n\r\n\r"], false)

        pieceTable.insert(2, "\n\r\r\r")
        str = str.substring(0, 2) + "\n\r\r\r" + str.substring(2)
        pieceTable.delete(offset: 4, cnt: 1)
        str = str.substring(0, 4) + str.substring(4 + 1)

        // TODO: split
        // let lines = str.split(/\r,\n|\r|\n/)
        //XCTAssertEqual(pieceTable.lineCount, lines.count)
        assertTreeInvariants(pieceTable)
    }

    func testCentralized_random3 ()
    {
        // test("random bug 3", () => {
        var str = "\n\n\n\r"
        let pieceTable = createTextBuffer(["\n\n\n\r"], false)

        pieceTable.delete(offset: 2, cnt: 2)
        str = str.substring(0, 2) + str.substring(2 + 2)
        pieceTable.delete(offset: 0, cnt: 2)
        str = str.substring(0, 0) + str.substring(0 + 2)
        pieceTable.insert(0, "\r\r\r\r")
        str = str.substring(0, 0) + "\r\r\r\r" + str.substring(0)
        pieceTable.insert(2, "\r\n\r\r")
        str = str.substring(0, 2) + "\r\n\r\r" + str.substring(2)
        pieceTable.insert(3, "\r\r\r\n")
        str = str.substring(0, 3) + "\r\r\r\n" + str.substring(3)

        // TODO: Split
        // let lines = str.split(/\r,\n|\r|\n/)
        //XCTAssertEqual(pieceTable.lineCount, lines.count)
        assertTreeInvariants(pieceTable)
    }

    func BYTES_testCentralized_random4 ()
    {
        // test("random bug 4", () => {
        var str = "\n\n\n\n"
        let pieceTable = createTextBuffer(["\n\n\n\n"], false)

        pieceTable.delete(offset: 3, cnt: 1)
        str = str.substring(0, 3) + str.substring(3 + 1)
        pieceTable.insert(1, "\r\r\r\r")
        str = str.substring(0, 1) + "\r\r\r\r" + str.substring(1)
        pieceTable.insert(6, "\r\n\n\r")
        str = str.substring(0, 6) + "\r\n\n\r" + str.substring(6)
        pieceTable.delete(offset: 5, cnt: 3)
        str = str.substring(0, 5) + str.substring(5 + 3)

        testLinesContent(str, pieceTable)
        assertTreeInvariants(pieceTable)
    }

    func BYTES_testCentralized_testrandom5 ()
    {
        // ("random bug 5", () => {
        var str = "\n\n\n\n"
        let pieceTable = createTextBuffer(["\n\n\n\n"], false)

        pieceTable.delete(offset: 3, cnt: 1)
        str = str.substring(0, 3) + str.substring(3 + 1)
        pieceTable.insert(0, "\n\r\r\n")
        str = str.substring(0, 0) + "\n\r\r\n" + str.substring(0)
        pieceTable.insert(4, "\n\r\r\n")
        str = str.substring(0, 4) + "\n\r\r\n" + str.substring(4)
        pieceTable.delete(offset: 4, cnt: 3)
        str = str.substring(0, 4) + str.substring(4 + 3)
        pieceTable.insert(5, "\r\r\n\r")
        str = str.substring(0, 5) + "\r\r\n\r" + str.substring(5)
        pieceTable.insert(12, "\n\n\n\r")
        str = str.substring(0, 12) + "\n\n\n\r" + str.substring(12)
        pieceTable.insert(5, "\r\r\r\n")
        str = str.substring(0, 5) + "\r\r\r\n" + str.substring(5)
        pieceTable.insert(20, "\n\n\r\n")
        str = str.substring(0, 20) + "\n\n\r\n" + str.substring(20)

        testLinesContent(str, pieceTable)
        assertTreeInvariants(pieceTable)
    }

    func BYTES_testCentralized_random6 ()
    {
        // test("random bug 6", () => {
        var str = "\n\r\r\n"
        let pieceTable = createTextBuffer(["\n\r\r\n"], false)

        pieceTable.insert(4, "\r\n\n\r")
        str = str.substring(0, 4) + "\r\n\n\r" + str.substring(4)
        pieceTable.insert(3, "\r\n\n\n")
        str = str.substring(0, 3) + "\r\n\n\n" + str.substring(3)
        pieceTable.delete(offset: 4, cnt: 8)
        str = str.substring(0, 4) + str.substring(4 + 8)
        pieceTable.insert(4, "\r\n\n\r")
        str = str.substring(0, 4) + "\r\n\n\r" + str.substring(4)
        pieceTable.insert(0, "\r\n\n\r")
        str = str.substring(0, 0) + "\r\n\n\r" + str.substring(0)
        pieceTable.delete(offset: 4, cnt: 0)
        str = str.substring(0, 4) + str.substring(4 + 0)
        pieceTable.delete(offset: 8, cnt: 4)
        str = str.substring(0, 8) + str.substring(8 + 4)

        testLinesContent(str, pieceTable)
        assertTreeInvariants(pieceTable)
    }

    func BYTES_testCentralized_random7 ()
    {
        // test("random bug 7", () => {
        var str = "\r\n\n\r"
        let pieceTable = createTextBuffer(["\r\n\n\r"], false)

        pieceTable.delete(offset: 1, cnt: 0)
        str = str.substring(0, 1) + str.substring(1 + 0)
        pieceTable.insert(3, "\n\n\n\r")
        str = str.substring(0, 3) + "\n\n\n\r" + str.substring(3)
        pieceTable.insert(7, "\n\n\r\n")
        str = str.substring(0, 7) + "\n\n\r\n" + str.substring(7)

        testLinesContent(str, pieceTable)
        assertTreeInvariants(pieceTable)
    }

    func BYES_testCentralized_random8 ()
    {
        // test("random bug 8", () => {
        var str = "\r\r\n\n"
        let pieceTable = createTextBuffer(["\r\r\n\n"], false)

        pieceTable.insert(4, "\r\n\n\r")
        str = str.substring(0, 4) + "\r\n\n\r" + str.substring(4)
        pieceTable.insert(7, "\n\r\r\r")
        str = str.substring(0, 7) + "\n\r\r\r" + str.substring(7)
        pieceTable.insert(11, "\n\n\r\n")
        str = str.substring(0, 11) + "\n\n\r\n" + str.substring(11)
        testLinesContent(str, pieceTable)
        assertTreeInvariants(pieceTable)
    }

    func testCentralized_random9 ()
    {
        // test("random bug 9", () => {
        var str = "qneW"
        let pieceTable = createTextBuffer(["qneW"], false)

        pieceTable.insert(0, "YhIl")
        str = str.substring(0, 0) + "YhIl" + str.substring(0)
        pieceTable.insert(0, "qdsm")
        str = str.substring(0, 0) + "qdsm" + str.substring(0)
        pieceTable.delete(offset: 7, cnt: 0)
        str = str.substring(0, 7) + str.substring(7 + 0)
        pieceTable.insert(12, "iiPv")
        str = str.substring(0, 12) + "iiPv" + str.substring(12)
        pieceTable.insert(9, "V\rSA")
        str = str.substring(0, 9) + "V\rSA" + str.substring(9)

        testLinesContent(str, pieceTable)
        assertTreeInvariants(pieceTable)
    }

    func BYTES_testCentralized_random10 ()
    {
        // test("random bug 10", () => {
        var str = "\n\n\n\n"
        let pieceTable = createTextBuffer(["\n\n\n\n"], false)

        pieceTable.insert(3, "\n\r\n\r")
        str = str.substring(0, 3) + "\n\r\n\r" + str.substring(3)
        pieceTable.insert(2, "\n\r\n\n")
        str = str.substring(0, 2) + "\n\r\n\n" + str.substring(2)
        pieceTable.insert(0, "\n\n\r\r")
        str = str.substring(0, 0) + "\n\n\r\r" + str.substring(0)
        pieceTable.insert(3, "\r\r\r\r")
        str = str.substring(0, 3) + "\r\r\r\r" + str.substring(3)
        pieceTable.insert(3, "\n\n\r\r")
        str = str.substring(0, 3) + "\n\n\r\r" + str.substring(3)

        testLinesContent(str, pieceTable)
        assertTreeInvariants(pieceTable)
    }

    func testCentralized_randomchunk1 ()
    {
        // test("random chunk bug 1", () => {
        let pieceTable = createTextBuffer(["\n\r\r\n\n\n\r\n\r"], false)
        var str = "\n\r\r\n\n\n\r\n\r"
        pieceTable.delete(offset: 0, cnt: 2)
        str = str.substring(0, 0) + str.substring(0 + 2)
        pieceTable.insert(1, "\r\r\n\n")
        str = str.substring(0, 1) + "\r\r\n\n" + str.substring(1)
        pieceTable.insert(7, "\r\r\r\r")
        str = str.substring(0, 7) + "\r\r\r\r" + str.substring(7)

        XCTAssertEqual(pieceTable.getLines(), str)
        testLineStarts(str, pieceTable)
        assertTreeInvariants(pieceTable)
    }

    func BYTES_testCentralized_randomchunkbug2 ()
    {
        // test("random chunk bug 2", () => {
        let pieceTable = createTextBuffer([
            "\n\r\n\n\n\r\n\r\n\r\r\n\n\n\r\r\n\r\n"
        ], false)
        var str = "\n\r\n\n\n\r\n\r\n\r\r\n\n\n\r\r\n\r\n"
        pieceTable.insert(16, "\r\n\r\r")
        str = str.substring(0, 16) + "\r\n\r\r" + str.substring(16)
        pieceTable.insert(13, "\n\n\r\r")
        str = str.substring(0, 13) + "\n\n\r\r" + str.substring(13)
        pieceTable.insert(19, "\n\n\r\n")
        str = str.substring(0, 19) + "\n\n\r\n" + str.substring(19)
        pieceTable.delete(offset: 5, cnt: 0)
        str = str.substring(0, 5) + str.substring(5 + 0)
        pieceTable.delete(offset: 11, cnt: 2)
        str = str.substring(0, 11) + str.substring(11 + 2)

        XCTAssertEqual(pieceTable.getLines(), str)
        testLineStarts(str, pieceTable)
        assertTreeInvariants(pieceTable)
    }

    func BYTES_testCentralized_randomchunnkbug3 ()
    {
        // test("random chunk bug 3", () => {
        let pieceTable = createTextBuffer(["\r\n\n\n\n\n\n\r\n"], false)
        var str = "\r\n\n\n\n\n\n\r\n"
        pieceTable.insert(4, "\n\n\r\n\r\r\n\n\r")
        str = str.substring(0, 4) + "\n\n\r\n\r\r\n\n\r" + str.substring(4)
        pieceTable.delete(offset: 4, cnt: 4)
        str = str.substring(0, 4) + str.substring(4 + 4)
        pieceTable.insert(11, "\r\n\r\n\n\r\r\n\n")
        str = str.substring(0, 11) + "\r\n\r\n\n\r\r\n\n" + str.substring(11)
        pieceTable.delete(offset: 1, cnt: 2)
        str = str.substring(0, 1) + str.substring(1 + 2)

        XCTAssertEqual(pieceTable.getLines(), str)
        testLineStarts(str, pieceTable)
        assertTreeInvariants(pieceTable)
    }

    func testCentralized_randomchunkbug4 ()
    {
        // test("random chunk bug 4", () => {
        let pieceTable = createTextBuffer(["\n\r\n\r"], false)
        var str = "\n\r\n\r"
        pieceTable.insert(4, "\n\n\r\n")
        str = str.substring(0, 4) + "\n\n\r\n" + str.substring(4)
        pieceTable.insert(3, "\r\n\n\n")
        str = str.substring(0, 3) + "\r\n\n\n" + str.substring(3)

        XCTAssertEqual(pieceTable.getLines(), str)
        testLineStarts(str, pieceTable)
        assertTreeInvariants(pieceTable)
    }

//
//    suite("random is unsupervised", () => {
//        test("splitting large change buffer", function () {
//            let pieceTable = createTextBuffer([""], false)
//            var str = ""
//
//            pieceTable.insert(0, "WUZ\nXVZY\n")
//            str = str.substring(0, 0) + "WUZ\nXVZY\n" + str.substring(0)
//            pieceTable.insert(8, "\r\r\nZXUWVW")
//            str = str.substring(0, 8) + "\r\r\nZXUWVW" + str.substring(8)
//            pieceTable.delete(10, 7)
//            str = str.substring(0, 10) + str.substring(10 + 7)
//            pieceTable.delete(10, 1)
//            str = str.substring(0, 10) + str.substring(10 + 1)
//            pieceTable.insert(4, "VX\r\r\nWZVZ")
//            str = str.substring(0, 4) + "VX\r\r\nWZVZ" + str.substring(4)
//            pieceTable.delete(11, 3)
//            str = str.substring(0, 11) + str.substring(11 + 3)
//            pieceTable.delete(12, 4)
//            str = str.substring(0, 12) + str.substring(12 + 4)
//            pieceTable.delete(8, 0)
//            str = str.substring(0, 8) + str.substring(8 + 0)
//            pieceTable.delete(10, 2)
//            str = str.substring(0, 10) + str.substring(10 + 2)
//            pieceTable.insert(0, "VZXXZYZX\r")
//            str = str.substring(0, 0) + "VZXXZYZX\r" + str.substring(0)
//
//            XCTAssertEqual(pieceTable.getLines(), str)
//
//            testLineStarts(str, pieceTable)
//            testLinesContent(str, pieceTable)
//            assertTreeInvariants(pieceTable)
//        })

    func testRandomInsertDelete ()
    {
        //        test("random insert delete", function () {

        var str = ""
        let pieceTable = createTextBuffer([str], false)

        // let output = ""
        for _ in 0..<1000 {
            if Int.random(in:0..<10) < 6 {
                // insert
                let text = randomStr(100)
                let pos = Int.random (in:0..<(str.count+1))
                pieceTable.insert(pos, text)
                str = str.substring(0, pos) + text + str.substring(pos)
                // output += `pieceTable.insert(${pos}, "${text.replace(/\n/g, "\\n").replace(/\r/g, "\\r")}")\n`
                // output += `str = str.substring(0, ${pos}) + "${text.replace(/\n/g, "\\n").replace(/\r/g, "\\r")}" + str.substring(${pos})\n`
            } else {
                // delete
                let pos = str.count == 0 ? 0 : Int.random (in: 0..<str.count)
                let length = min(
                    str.count - pos,
                    Int.random (in:0..<10))
                
                pieceTable.delete(offset: pos, cnt: length)
                str = str.substring(0, pos) + str.substring(pos + length)
                // output += `pieceTable.delete(${pos}, ${length})\n`
                // output += `str = str.substring(0, ${pos}) + str.substring(${pos} + ${length})\n`

            }
        }
        // console.log(output)

        XCTAssertEqual(pieceTable.getLines(), str)

        testLineStarts(str, pieceTable)
        testLinesContent(str, pieceTable)
        assertTreeInvariants(pieceTable)
    }
    
    func testRandomChunks ()
    {
        // test("random chunks", function () {

        var chunks: [String] = []
        for _ in 0..<5 {
            chunks.append (randomStr(1000))
        }

        let pieceTable = createTextBuffer(chunks, false)
        var str = chunks.joined(separator: "")

        for _ in 0..<1000 {
            if Int.random (in: 0...10) < 6 {
                // insert
                let text = randomStr(100)
                let pos = Int.random (in: 0...str.count)
                pieceTable.insert(pos, text)
                str = str.substring(0, pos) + text + str.substring(pos)
            } else {
                // delete
                let pos = Int.random (in: 0..<str.count)
                let length = min(
                    str.count - pos,
                    Int.random (in: 0...10)
                )
                pieceTable.delete(offset: pos, cnt: length)
                str = str.substring(0, pos) + str.substring(pos + length)
            }
        }

        XCTAssertEqual(pieceTable.getLines(), str)
        testLineStarts(str, pieceTable)
        testLinesContent(str, pieceTable)
        assertTreeInvariants(pieceTable)
    }
    
//
//        test("random chunks 2", function () {
//            this.timeout(500000)
//            let chunks: string[] = []
//            chunks.push(randomStr(1000))
//
//            let pieceTable = createTextBuffer(chunks, false)
//            let str = chunks.join("")
//
//            for (let i = 0 i < 50 i++) {
//                if (Math.random() < 0.6) {
//                    // insert
//                    let text = randomStr(30)
//                    let pos = randomInt(str.count + 1)
//                    pieceTable.insert(pos, text)
//                    str = str.substring(0, pos) + text + str.substring(pos)
//                } else {
//                    // delete
//                    let pos = randomInt(str.count)
//                    let length = Math.min(
//                        str.count - pos,
//                        Math.floor(Math.random() * 10)
//                    )
//                    pieceTable.delete(pos, length)
//                    str = str.substring(0, pos) + str.substring(pos + length)
//                }
//                testLinesContent(str, pieceTable)
//            }
//
//            XCTAssertEqual(pieceTable.getLines(), str)
//            testLineStarts(str, pieceTable)
//            testLinesContent(str, pieceTable)
//            assertTreeInvariants(pieceTable)
//        })
//    })
//
//    suite("buffer api", () => {
//        test("equal", () => {
//            let a = createTextBuffer(["abc"])
//            let b = createTextBuffer(["ab", "c"])
//            let c = createTextBuffer(["abd"])
//            let d = createTextBuffer(["abcd"])
//
//            assert(a.equal(b))
//            assert(!a.equal(c))
//            assert(!a.equal(d))
//        })
//
//        test("equal 2, empty buffer", () => {
//            let a = createTextBuffer([""])
//            let b = createTextBuffer([""])
//
//            assert(a.equal(b))
//        })
//
//        test("equal 3, empty buffer", () => {
//            let a = createTextBuffer(["a"])
//            let b = createTextBuffer([""])
//
//            assert(!a.equal(b))
//        })
//
//        test("getLineCharCode - issue #45735", () => {
//            let pieceTable = createTextBuffer(["LINE1\nline2"])
//            XCTAssertEqual(pieceTable.getLineCharCode(1, 0), "L".charCodeAt(0), "L")
//            XCTAssertEqual(pieceTable.getLineCharCode(1, 1), "I".charCodeAt(0), "I")
//            XCTAssertEqual(pieceTable.getLineCharCode(1, 2), "N".charCodeAt(0), "N")
//            XCTAssertEqual(pieceTable.getLineCharCode(1, 3), "E".charCodeAt(0), "E")
//            XCTAssertEqual(pieceTable.getLineCharCode(1, 4), "1".charCodeAt(0), "1")
//            XCTAssertEqual(pieceTable.getLineCharCode(1, 5), "\n".charCodeAt(0), "\\n")
//            XCTAssertEqual(pieceTable.getLineCharCode(2, 0), "l".charCodeAt(0), "l")
//            XCTAssertEqual(pieceTable.getLineCharCode(2, 1), "i".charCodeAt(0), "i")
//            XCTAssertEqual(pieceTable.getLineCharCode(2, 2), "n".charCodeAt(0), "n")
//            XCTAssertEqual(pieceTable.getLineCharCode(2, 3), "e".charCodeAt(0), "e")
//            XCTAssertEqual(pieceTable.getLineCharCode(2, 4), "2".charCodeAt(0), "2")
//        })
//
//
//        test("getLineCharCode - issue #47733", () => {
//            let pieceTable = createTextBuffer(["", "LINE1\n", "line2"])
//            XCTAssertEqual(pieceTable.getLineCharCode(1, 0), "L".charCodeAt(0), "L")
//            XCTAssertEqual(pieceTable.getLineCharCode(1, 1), "I".charCodeAt(0), "I")
//            XCTAssertEqual(pieceTable.getLineCharCode(1, 2), "N".charCodeAt(0), "N")
//            XCTAssertEqual(pieceTable.getLineCharCode(1, 3), "E".charCodeAt(0), "E")
//            XCTAssertEqual(pieceTable.getLineCharCode(1, 4), "1".charCodeAt(0), "1")
//            XCTAssertEqual(pieceTable.getLineCharCode(1, 5), "\n".charCodeAt(0), "\\n")
//            XCTAssertEqual(pieceTable.getLineCharCode(2, 0), "l".charCodeAt(0), "l")
//            XCTAssertEqual(pieceTable.getLineCharCode(2, 1), "i".charCodeAt(0), "i")
//            XCTAssertEqual(pieceTable.getLineCharCode(2, 2), "n".charCodeAt(0), "n")
//            XCTAssertEqual(pieceTable.getLineCharCode(2, 3), "e".charCodeAt(0), "e")
//            XCTAssertEqual(pieceTable.getLineCharCode(2, 4), "2".charCodeAt(0), "2")
//        })
//    })
//
//    suite("search offset cache", () => {
//        test("render white space exception", () => {
//            let pieceTable = createTextBuffer(["class Name{\n\t\n\t\t\tget() {\n\n\t\t\t}\n\t\t}"])
//            let str = "class Name{\n\t\n\t\t\tget() {\n\n\t\t\t}\n\t\t}"
//
//            pieceTable.insert(12, "s")
//            str = str.substring(0, 12) + "s" + str.substring(12)
//
//            pieceTable.insert(13, "e")
//            str = str.substring(0, 13) + "e" + str.substring(13)
//
//            pieceTable.insert(14, "t")
//            str = str.substring(0, 14) + "t" + str.substring(14)
//
//            pieceTable.insert(15, "()")
//            str = str.substring(0, 15) + "()" + str.substring(15)
//
//            pieceTable.delete(16, 1)
//            str = str.substring(0, 16) + str.substring(16 + 1)
//
//            pieceTable.insert(17, "()")
//            str = str.substring(0, 17) + "()" + str.substring(17)
//
//            pieceTable.delete(18, 1)
//            str = str.substring(0, 18) + str.substring(18 + 1)
//
//            pieceTable.insert(18, "}")
//            str = str.substring(0, 18) + "}" + str.substring(18)
//
//            pieceTable.insert(12, "\n")
//            str = str.substring(0, 12) + "\n" + str.substring(12)
//
//            pieceTable.delete(12, 1)
//            str = str.substring(0, 12) + str.substring(12 + 1)
//
//            pieceTable.delete(18, 1)
//            str = str.substring(0, 18) + str.substring(18 + 1)
//
//            pieceTable.insert(18, "}")
//            str = str.substring(0, 18) + "}" + str.substring(18)
//
//            pieceTable.delete(17, 2)
//            str = str.substring(0, 17) + str.substring(17 + 2)
//
//            pieceTable.delete(16, 1)
//            str = str.substring(0, 16) + str.substring(16 + 1)
//
//            pieceTable.insert(16, ")")
//            str = str.substring(0, 16) + ")" + str.substring(16)
//
//            pieceTable.delete(15, 2)
//            str = str.substring(0, 15) + str.substring(15 + 2)
//
//            let content = pieceTable.getLines()
//            assert(content === str)
//        })
//
//        test("Line breaks replacement is not necessary when EOL is normalized", () => {
//            let pieceTable = createTextBuffer(["abc"])
//            let str = "abc"
//
//            pieceTable.insert(3, "def\nabc")
//            str = str + "def\nabc"
//
//            testLineStarts(str, pieceTable)
//            testLinesContent(str, pieceTable)
//            assertTreeInvariants(pieceTable)
//        })
//
//        test("Line breaks replacement is not necessary when EOL is normalized 2", () => {
//            let pieceTable = createTextBuffer(["abc\n"])
//            let str = "abc\n"
//
//            pieceTable.insert(4, "def\nabc")
//            str = str + "def\nabc"
//
//            testLineStarts(str, pieceTable)
//            testLinesContent(str, pieceTable)
//            assertTreeInvariants(pieceTable)
//        })
//
//        test("Line breaks replacement is not necessary when EOL is normalized 3", () => {
//            let pieceTable = createTextBuffer(["abc\n"])
//            let str = "abc\n"
//
//            pieceTable.insert(2, "def\nabc")
//            str = str.substring(0, 2) + "def\nabc" + str.substring(2)
//
//            testLineStarts(str, pieceTable)
//            testLinesContent(str, pieceTable)
//            assertTreeInvariants(pieceTable)
//        })
//
//        test("Line breaks replacement is not necessary when EOL is normalized 4", () => {
//            let pieceTable = createTextBuffer(["abc\n"])
//            let str = "abc\n"
//
//            pieceTable.insert(3, "def\nabc")
//            str = str.substring(0, 3) + "def\nabc" + str.substring(3)
//
//            testLineStarts(str, pieceTable)
//            testLinesContent(str, pieceTable)
//            assertTreeInvariants(pieceTable)
//        })
//
//    })
//
//    function getValueInSnapshot(snapshot: ITextSnapshot) {
//        let ret = ""
//        let tmp = snapshot.read()
//
//        while (tmp !== null) {
//            ret += tmp
//            tmp = snapshot.read()
//        }
//
//        return ret
//    }
//    suite("snapshot", () => {
//        test("bug #45564, piece tree pieces should be immutable", () => {
//            const model = TextModel.createFromString("\n")
//            model.applyEdits([
//                {
//                    range: new Range(2, 1, 2, 1),
//                    text: "!"
//                }
//            ])
//            const snapshot = model.createSnapshot()
//            const snapshot1 = model.createSnapshot()
//            XCTAssertEqual(model.getLinesContent().join("\n"), getValueInSnapshot(snapshot))
//
//            model.applyEdits([
//                {
//                    range: new Range(2, 1, 2, 2),
//                    text: ""
//                }
//            ])
//            model.applyEdits([
//                {
//                    range: new Range(2, 1, 2, 1),
//                    text: "!"
//                }
//            ])
//
//            XCTAssertEqual(model.getLinesContent().join("\n"), getValueInSnapshot(snapshot1))
//        })
//
//        test("immutable snapshot 1", () => {
//            const model = TextModel.createFromString("abc\ndef")
//            const snapshot = model.createSnapshot()
//            model.applyEdits([
//                {
//                    range: new Range(2, 1, 2, 4),
//                    text: ""
//                }
//            ])
//
//            model.applyEdits([
//                {
//                    range: new Range(1, 1, 2, 1),
//                    text: "abc\ndef"
//                }
//            ])
//
//            XCTAssertEqual(model.getLinesContent().join("\n"), getValueInSnapshot(snapshot))
//        })
//
//        test("immutable snapshot 2", () => {
//            const model = TextModel.createFromString("abc\ndef")
//            const snapshot = model.createSnapshot()
//            model.applyEdits([
//                {
//                    range: new Range(2, 1, 2, 1),
//                    text: "!"
//                }
//            ])
//
//            model.applyEdits([
//                {
//                    range: new Range(2, 1, 2, 2),
//                    text: ""
//                }
//            ])
//
//            XCTAssertEqual(model.getLinesContent().join("\n"), getValueInSnapshot(snapshot))
//        })
//
//        test("immutable snapshot 3", () => {
//            const model = TextModel.createFromString("abc\ndef")
//            model.applyEdits([
//                {
//                    range: new Range(2, 4, 2, 4),
//                    text: "!"
//                }
//            ])
//            const snapshot = model.createSnapshot()
//            model.applyEdits([
//                {
//                    range: new Range(2, 5, 2, 5),
//                    text: "!"
//                }
//            ])
//
//            assert.notEqual(model.getLinesContent().join("\n"), getValueInSnapshot(snapshot))
//        })
//    })
//
//    suite("chunk based search", () => {
//        test("#45892. For some cases, the buffer is empty but we still try to search", () => {
//            let pieceTree = createTextBuffer([""])
//            pieceTree.delete(0, 1)
//            let ret = pieceTree.findMatchesLineByLine(new Range(1, 1, 1, 1), new SearchData(/abc/, new WordCharacterClassifier(",./"), "abc"), true, 1000)
//            XCTAssertEqual(ret.count, 0)
//        })
//
//        test("#45770. FindInNode should not cross node boundary.", () => {
//            let pieceTree = createTextBuffer([
//                [
//                    "balabalababalabalababalabalaba",
//                    "balabalababalabalababalabalaba",
//                    "",
//                    "* [ ] task1",
//                    "* [x] task2 balabalaba",
//                    "* [ ] task 3"
//                ].join("\n")
//            ])
//            pieceTree.delete(0, 62)
//            pieceTree.delete(16, 1)
//
//            pieceTree.insert(16, " ")
//            let ret = pieceTree.findMatchesLineByLine(new Range(1, 1, 4, 13), new SearchData(/\[/gi, new WordCharacterClassifier(",./"), "["), true, 1000)
//            XCTAssertEqual(ret.count, 3)
//
//            assert.deepEqual(ret[0].range, new Range(2, 3, 2, 4))
//            assert.deepEqual(ret[1].range, new Range(3, 3, 3, 4))
//            assert.deepEqual(ret[2].range, new Range(4, 3, 4, 4))
//        })
//
//        test("search searching from the middle", () => {
//            let pieceTree = createTextBuffer([
//                [
//                    "def",
//                    "dbcabc"
//                ].join("\n")
//            ])
//            pieceTree.delete(4, 1)
//            let ret = pieceTree.findMatchesLineByLine(new Range(2, 3, 2, 6), new SearchData(/a/gi, null, "a"), true, 1000)
//            XCTAssertEqual(ret.count, 1)
//            assert.deepEqual(ret[0].range, new Range(2, 3, 2, 4))
//
//            pieceTree.delete(4, 1)
//            ret = pieceTree.findMatchesLineByLine(new Range(2, 2, 2, 5), new SearchData(/a/gi, null, "a"), true, 1000)
//            XCTAssertEqual(ret.count, 1)
//            assert.deepEqual(ret[0].range, new Range(2, 2, 2, 3))
//        })
//    })

}
