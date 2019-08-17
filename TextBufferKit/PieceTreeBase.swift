//
//  PieceTreeBase.swift
//  swift-textbuffer
//
//  Created by Miguel de Icaza on 8/10/19.
//  Copyright © 2019 Miguel de Icaza, Microsoft Corp. All rights reserved.
//

import Foundation

/**
 * Tracks the offset for each start of a line created from a byte array
 */
struct LineStarts {
    /// Offsets for each line start
    public var lineStarts: [Int]
    /// Number of carriage returns found
    public var cr : Int
    /// Number of line feeds found
    public var lf : Int
    /// Number of carriage returns followed by line feeds found
    public var crlf : Int
    /// Whether this file contains simple ascii characters (tab, and chars 32 to 127) or not
    public var isBasicAscii : Bool

    /**
     * Given a byte array containing the text buffer, create an array pointing to the
     * beginning of each line -- where lines are considered those immediately after a
     * \r\n or a \n
     */
    public static func createLineStartsArray (_ data : [UInt8]) -> [Int]
    {
        var result : [Int] = [0]
        
        var i = 0
        let len = data.count
        while i < data.count {
            let chr = data [i]
            if chr == 13 {
                if (i+1) < len && data [i+1] == 10 {
                    // \r\n case
                    result.append (i + 2)
                    i += 1 // skip \n
                } else {
                    // \r .. case
                    result.append (i + 1)
                }
            } else if chr == 10 {
                result.append (i + 1)
            }
            i += 1
        }
        return result
    }
    
    /**
     * Creates a LineStarts structure from the given byte array
     */
    public init (data : [UInt8])
    {
        var result : [Int] = [0]
        var cr = 0
        var lf = 0
        var crlf = 0
        var isBasicAscii = true
        
        var i = 0
        let len = data.count
        while i < data.count {
            let chr = data [i]
            if chr == 13 {
                if (i+1) < len && data [i+1] == 10 {
                    // \r\n case
                    crlf += 1
                    result.append (i + 2)
                    i += 1 // skip \n
                } else {
                    cr += 1
                    // \r .. case
                    result.append (i + 1)
                }
            } else if chr == 10 {
                lf += 1
                result.append(i+1)
            } else {
                if isBasicAscii {
                    if chr != 8 && (chr < 32 || chr > 126) {
                        isBasicAscii = false
                    }
                }
            }
            i += 1
        }
        lineStarts = result
        self.cr = cr
        self.lf = lf
        self.crlf = crlf
        self.isBasicAscii = isBasicAscii
    }

}

struct PieceIndex {
    /// Piece index
    var node: TreeNode
    /// Remainder in current piece
    var remainder : Int
    /// Node start offset in document
    var nodeStartOffset : Int
}


struct NodePosition {
    /// Piece Index
    var node: TreeNode
    /// remainer in current piece.
    var remainder: Int
    /// node start offset in document.
    var nodeStartOffset: Int
}

struct CacheEntry {
    var node: TreeNode
    var nodeStartLineNumber: Int?
    var nodeStartOffset: Int
    
    init (node: TreeNode, nodeStartLineNumber: Int?, nodeStartOffset: Int)
    {
        self.node = node
        self.nodeStartLineNumber = nodeStartLineNumber
        self.nodeStartOffset = nodeStartOffset
    }
    
    init (_ np: NodePosition)
    {
        self.node = np.node
        self.nodeStartLineNumber = nil
        self.nodeStartOffset = np.nodeStartOffset
    }
}

struct BufferCursor {
    /// Line number in current buffer
    var line : Int
    /// Column number in current buffer
    var column : Int
}

public struct StringBuffer {
    var buffer : [UInt8]
    var lineStarts : [Int]
}

public struct Piece {
    var bufferIndex : Int
    var start : BufferCursor
    var end : BufferCursor
    var length : Int
    var lineFeedCount : Int
}

public struct PieceTreeSnapshot {
    var pieces : [Piece]
    var index : Int
    var tree : PieceTreeBase
    var bom : [UInt8]
    
    public init (tree: PieceTreeBase, bom: [UInt8])
    {
        pieces = []
        self.tree = tree
        self.bom = bom
        index = 0
        if tree.root !== TreeNode.SENTINEL{
            tree.iterate(node: tree.root, callback: { node in
                if node !== TreeNode.SENTINEL {
                    self.pieces.append(node.piece)
                }
                return true
            })
        }
    }
    
    public mutating func read() -> [UInt8]?  {
        if pieces.count == 0 {
            if index == 0 {
                index += 1
                return bom
            } else {
                return nil
            }
        }

        if index > pieces.count - 1 {
            return nil
        }

        let idx  = index
        index += 1
        if index == 0 {
            return bom + tree.getPieceContent(piece: pieces[idx])
        }
        return tree.getPieceContent(piece: pieces[idx])
    }
}

class PieceTreeSearchCache {
    var limit: Int
    var cache: [CacheEntry]
    
    public init (limit: Int)
    {
        self.limit = limit
        cache = []
    }
    
    public func get (offset: Int) -> CacheEntry? {
        for node in cache.reversed() {
            if (node.nodeStartOffset <= offset) && ((node.nodeStartOffset + node.node.piece.length) >= offset) {
                return node
            }
        }
        return nil
    }

    public func get2 (lineNumber: Int) -> CacheEntry? {
        for node in cache.reversed() {
            if let nodeStartLineNumber = node.nodeStartLineNumber {
                if nodeStartLineNumber < lineNumber && nodeStartLineNumber + (node.node.piece.lineFeedCount) >= lineNumber {
                    return node
                }
            }
        }
        return nil
    }

    /// Adds the element to the cache
    public func set (_ nodePosition: CacheEntry) {
        if cache.count >= limit {
            cache.removeFirst()
        }
        cache.append(nodePosition)
    }
    
    public func validate(offset: Int) {
        var hasInvalidVal = false
        var tmp: [CacheEntry?] = cache;
        let top = tmp.count
        var i = 0
        
        while i < top {
            let nodePos = tmp[i]!
            if nodePos.node.parent == nil || nodePos.nodeStartOffset >= offset {
                tmp[i] = nil
                hasInvalidVal = true;
            }
            i += 1
        }

        if hasInvalidVal {
            var newArr: [CacheEntry] = [];
            for entry in tmp {
                if let valid = entry {
                    newArr.append (valid)
                }
            }

            cache = newArr
        }
    }
}

let AverageBufferSize = 64*1024

public class PieceTreeBase {
    var root: TreeNode = TreeNode.SENTINEL
    var buffers: [StringBuffer] = [StringBuffer (buffer: [], lineStarts: [])]
    public private(set) var lineCount : Int = 1
    public private(set) var length: Int = 0
    public var eol: [UInt8] = [10] {
        didSet {
            eolLength = eol.count
            normalizeEol()
        }
    }
    var eolLength: Int = 1
    var eolNormalized: Bool = true
    var lastChangeBufferPos: BufferCursor = BufferCursor(line: 0, column: 0)
    var searchCache: PieceTreeSearchCache = PieceTreeSearchCache(limit: 1)
    var lastVisitedLine: (lineNumber: Int, value: [UInt8]) = (0, [])
    
    /// Initializes the PieceTreeBase
    /// - Parameter eol: must be a String either "\n" or "\r\n"
    ///
    public init (chunks: inout [StringBuffer], eol: [UInt8], eolNormalized : Bool)
    {
        create(chunks: &chunks, eol: eol, eolNormalized: eolNormalized)
    }

    func create (chunks: inout [StringBuffer], eol: [UInt8], eolNormalized : Bool)
    {
        buffers = [StringBuffer(buffer: [], lineStarts: [0])]
        lineCount = 1
        length = 0
        self.eol = eol
        eolLength = eol.count
        self.eolNormalized = eolNormalized
        
        var lastNode : TreeNode? = nil
        var i = 0
        let top = chunks.count
        while i < top {
            if chunks[i].buffer.count > 0 {
                if chunks[i].lineStarts.count == 0 {
                    chunks[i].lineStarts = LineStarts.createLineStartsArray (chunks[i].buffer);
                }

                let piece = Piece(bufferIndex: i+1,
                                  start: BufferCursor(line: 0, column: 0),
                                  end: BufferCursor(line: chunks[i].lineStarts.count - 1, column: chunks[i].buffer.count - chunks[i].lineStarts[chunks[i].lineStarts.count - 1]),
                                  length: chunks[i].buffer.count, lineFeedCount: chunks[i].lineStarts.count - 1)
                
                buffers.append (chunks[i]);
                lastNode = rbInsertRight (lastNode, piece)
            }
            i += 1
        }
        searchCache = PieceTreeSearchCache(limit: 1)
        lastVisitedLine = (0, [])
        computeBufferMetadata()
    }
    
    func normalizeEol ()
    {
        // TODO
    }
    
    public func createSnapshot(bom: [UInt8]) -> PieceTreeSnapshot {
        return PieceTreeSnapshot(tree: self, bom: bom);
    }
    
    public static func equal (left: PieceTreeBase, right: PieceTreeBase) -> Bool
    {
        if left.length != right.length {
            return false
        }
        if left.lineCount != right.lineCount {
            return false
        }
    
        let ret = left.iterate(node: left.root, callback: { node in
            if node === TreeNode.SENTINEL {
                return true
            }
            let str = left.getNodeContent(node)
            let len = str.count
            if let startPosition = right.nodeAt(0) {
                if let endPosition = right.nodeAt(len) {
                    let val = right.getValueInRange2(startPosition, endPosition);

                    return str == val
                }
            }
            return false
        })

        return ret;
    }
    
    public func getOffsetAt(_ _lineNumber: Int, _ column: Int)-> Int {
        var leftLen = 0; // inorder
        var lineNumber = _lineNumber
        var x = root

        while x !== TreeNode.SENTINEL {
            if x.left !== TreeNode.SENTINEL && x.lf_left + 1 >= lineNumber {
                x = x.left!
            } else if x.lf_left + x.piece.lineFeedCount + 1 >= lineNumber {
                leftLen += x.size_left
                // lineNumber >= 2
                let accumualtedValInCurrentIndex = getAccumulatedValue(node: x, index: lineNumber - x.lf_left - 2)
                return leftLen + accumualtedValInCurrentIndex + column - 1
            } else {
                lineNumber -= x.lf_left + x.piece.lineFeedCount
                leftLen += x.size_left + x.piece.length
                x = x.right!
            }
        }

        return leftLen
    }

    public func getPositionAt(_ _offset: Int) -> Position {
        var offset = max (0, _offset)

        var x = root
        var lfCount = 0;
        let originalOffset = offset

        while x !== TreeNode.SENTINEL {
            if x.size_left != 0 && x.size_left >= offset {
                x = x.left!
            } else if x.size_left + x.piece.length >= offset {
                let out = getIndexOf(node: x, accumulatedValue: offset - x.size_left)

                lfCount += x.lf_left + out.index

                if out.index == 0 {
                    let lineStartOffset = getOffsetAt(lfCount + 1, 1)
                    let column = originalOffset - lineStartOffset
                    return Position(line: lfCount+1, column: column+1)
                }

                return Position(line: lfCount + 1, column: out.remainder + 1)
            } else {
                offset -= x.size_left + x.piece.length;
                lfCount += x.lf_left + x.piece.lineFeedCount

                if x.right === TreeNode.SENTINEL {
                    // last node
                    let lineStartOffset = getOffsetAt(lfCount + 1, 1);
                    let column = originalOffset - offset - lineStartOffset;
                    return Position(line: lfCount + 1, column: column + 1);
                } else {
                    x = x.right!
                }
            }
        }

        return Position(line: 1, column: 1)
    }

    public func getValueInRange(range: Range, eol _eol: [UInt8]?) -> [UInt8] {
        if range.startLineNumber == range.endLineNumber && range.startColumn == range.endColumn {
            return []
        }

        if let startPosition = nodeAt2(line: range.startLineNumber, col: range.startColumn) {
            if let endPosition = nodeAt2(line: range.endLineNumber, col: range.endColumn) {
                let value = getValueInRange2(startPosition, endPosition)
            
                if let eol = _eol {
                    // TODO
                    // if (eol !== self.eol || !eolNormalized) {
                    //
                    //     return value.replace(/\r\n|\r|\n/g, eol);
                    // }
                    //
                    // if (eol === getEOL() && _EOLNormalized) {
                    //     if (eol === '\r\n') {
                    //
                    //     }
                    //     return value;
                    // }
                    // return value.replace(/\r\n|\r|\n/g, eol);
                }
                return value
            }
        }
        return []
    }

    func getValueInRange2(_ startPosition: NodePosition, _ endPosition: NodePosition) -> [UInt8] {
        if startPosition.node === endPosition.node {
            let node = startPosition.node
            let buffer = buffers[node.piece.bufferIndex].buffer
            let startOffset = offsetInBuffer(node.piece.bufferIndex, node.piece.start)
            return Array (buffer [(startOffset + startPosition.remainder)..<(startOffset + endPosition.remainder)])
        }

        var x = startPosition.node
        var buffer = buffers[x.piece.bufferIndex].buffer
        let startOffset = offsetInBuffer(x.piece.bufferIndex, x.piece.start)
        var ret = Array (buffer [(startOffset + startPosition.remainder)..<(startOffset + x.piece.length)])

        x = x.next()
        while x !== TreeNode.SENTINEL {
            buffer = buffers [x.piece.bufferIndex].buffer
            let startOffset = offsetInBuffer(x.piece.bufferIndex, x.piece.start)

            if x === endPosition.node {
                ret += Array (buffer [startOffset..<(startOffset + endPosition.remainder)])
                break;
            } else {
                ret += Array (buffer[startOffset..<x.piece.length])
            }

            x = x.next()
        }

        return ret
    }
    
    public func getLinesContent() -> [ArraySlice <UInt8>]
    {
        // TODO
        // return getContentOfSubTree(root).split(/\r\n|\r|\n/);
        
        return Array (getContentOfSubTree(node: root).split(separator: 10 /* LF */))
    }
    
    
    public func getLineContent(_ lineNumber: Int) -> [UInt8] {
        if lastVisitedLine.lineNumber == lineNumber {
            return lastVisitedLine.value
        }

        lastVisitedLine.lineNumber = lineNumber

        if lineNumber == lineCount {
            lastVisitedLine.value = getLineRawContent(lineNumber)
        } else if eolNormalized {
            lastVisitedLine.value = getLineRawContent (lineNumber, eolLength)
        } else {
            var l = getLineRawContent(lineNumber)
            let len = l.count
            if len > 1 {
                if len > 2 && l [len-2] == 13 && l [len-1] == 10 {
                    l.removeLast(2)
                } else if l [len-1] == 10 || l [len-1] == 13 {
                    l.removeLast()
                }
            }
            lastVisitedLine.value = l
            
            // lastVisitedLine.value = getLineRawContent(lineNumber).replace(/(\r\n|\r|\n)$/, '');
        }

        return lastVisitedLine.value
    }
    
    public func getLineCharCode(lineNumber: Int, index: Int) -> UInt8
    {
        guard let nodePos = nodeAt2(line: lineNumber, col: index + 1) else {
            return 0
        }
        if nodePos.remainder == nodePos.node.piece.length {
            // the char we want to fetch is at the head of next node.
            let matchingNode = nodePos.node.next()
            if matchingNode === TreeNode.SENTINEL {
                return 0
            }

            let buffer = buffers[matchingNode.piece.bufferIndex]
            let startOffset = offsetInBuffer(matchingNode.piece.bufferIndex, matchingNode.piece.start)
            return buffer.buffer [startOffset]
        } else {
            let buffer = buffers[nodePos.node.piece.bufferIndex]
            let startOffset = offsetInBuffer(nodePos.node.piece.bufferIndex, nodePos.node.piece.start)
            let targetOffset = startOffset + nodePos.remainder

            return buffer.buffer [targetOffset]
        }
    }
    
    public func getLineLength(lineNumber: Int) -> Int
    {
        if lineNumber == lineCount {
            let startOffset = getOffsetAt(lineNumber, 1)
            return length - startOffset
        }
        return getOffsetAt(lineNumber + 1, 1) - getOffsetAt(lineNumber, 1) - eolLength
    }
    
    
    func insert(offset: Int, value _value: [UInt8], eolNormalized: Bool = false)
    {
        var value = _value
        self.eolNormalized = self.eolNormalized && eolNormalized;
        lastVisitedLine.lineNumber = 0
        lastVisitedLine.value = [];

        if root !== TreeNode.SENTINEL {
            let nodePosition = nodeAt (offset)!
            
            var node = nodePosition.node
            let remainder = nodePosition.remainder
            let nodeStartOffset = nodePosition.nodeStartOffset
            
            let piece = node.piece
            let bufferIndex = piece.bufferIndex
            let insertPosInBuffer = positionInBuffer(node: node, remainder: remainder)
            if node.piece.bufferIndex == 0 &&
                piece.end.line == lastChangeBufferPos.line &&
                piece.end.column == lastChangeBufferPos.column &&
                (nodeStartOffset + piece.length == offset) &&
                value.count < AverageBufferSize
            {
                // changed buffer
                appendToNode(node: &node, value: &value)
                computeBufferMetadata()
                return
            }

            if nodeStartOffset == offset {
                insertContentToNodeLeft(value: &value, node: &node)
                searchCache.validate(offset: offset)
            } else if nodeStartOffset + node.piece.length > offset {
                // we are inserting into the middle of a node.
                var nodesToDel: [TreeNode] = []
                var newRightPiece = Piece (
                     bufferIndex: piece.bufferIndex,
                           start: insertPosInBuffer,
                             end: piece.end,
                          length: offsetInBuffer(bufferIndex, piece.end) - offsetInBuffer(bufferIndex, insertPosInBuffer),
                          lineFeedCount: getLineFeedCount(bufferIndex: piece.bufferIndex, start: insertPosInBuffer, end: piece.end))

                if shouldCheckCRLF() && endWithCR(value) {
                    let headOfRight = nodeCharCodeAt(node, remainder)

                    if headOfRight == 10 /* LF */ {
                        let newStart = BufferCursor(line: newRightPiece.start.line + 1, column: 0)
                        newRightPiece = Piece(
                              bufferIndex: newRightPiece.bufferIndex,
                                    start: newStart,
                                      end: newRightPiece.end,
                                   length: newRightPiece.length - 1,
                                lineFeedCount:getLineFeedCount(bufferIndex: newRightPiece.bufferIndex, start: newStart, end: newRightPiece.end))

                        value += [10 /*LF*/]
                    }
                }

                // reuse node for content before insertion point.
                if shouldCheckCRLF() && startWithLF(value) {
                    let tailOfLeft = nodeCharCodeAt(node, remainder - 1);
                    if tailOfLeft == 13 /* CR */ {
                        let previousPos = positionInBuffer(node: node, remainder: remainder - 1)
                        deleteNodeTail(node: &node, pos: previousPos)
                        value = [13] + value

                        if node.piece.length == 0 {
                            nodesToDel.append(node)
                        }
                    } else {
                        deleteNodeTail(node: &node, pos: insertPosInBuffer)
                    }
                } else {
                    deleteNodeTail(node: &node, pos: insertPosInBuffer)
                }

                let newPieces = createNewPieces(value)
                if newRightPiece.length > 0 {
                    let _ = rbInsertRight(node, newRightPiece)
                }

                var tmpNode = node
                for k in 0..<newPieces.count {
                    tmpNode = rbInsertRight (tmpNode, newPieces[k])
                }
                deleteNodes(nodesToDel)
            } else {
                insertContentToNodeRight(value: &value, node: node)
            }
        } else {
            // insert new node
            let pieces = createNewPieces(value)
            var node = rbInsertLeft(node: nil, p: pieces[0])

            for k in 1..<pieces.count {
                node = rbInsertRight(node, pieces[k])
            }
        }

        // todo, this is too brutal. Total line feed count should be updated the same way as lf_left.
        computeBufferMetadata()
    }
    
    func delete(offset: Int, cnt: Int)
    {
        lastVisitedLine.lineNumber = 0
        lastVisitedLine.value = []

        if cnt <= 0 || root === TreeNode.SENTINEL {
            return
        }

        guard let startPosition = nodeAt(offset) else {
            return
        }
        guard let endPosition = nodeAt(offset + cnt) else {
            return
        }
        var startNode = startPosition.node
        var endNode = endPosition.node

        if startNode === endNode {
            let startSplitPosInBuffer = positionInBuffer(node: startNode, remainder: startPosition.remainder)
            let endSplitPosInBuffer = positionInBuffer(node: startNode, remainder: endPosition.remainder)

            if startPosition.nodeStartOffset == offset {
                if cnt == startNode.piece.length { // delete node
                    var next = startNode.next()
                    rbDelete(self, startNode)
                    validateCRLFWithPrevNode(nextNode: &next)
                    computeBufferMetadata()
                    return
                }
                deleteNodeHead(node: &startNode, pos: endSplitPosInBuffer)
                searchCache.validate(offset: offset)
                validateCRLFWithPrevNode(nextNode: &startNode)
                computeBufferMetadata()
                return
            }

            if startPosition.nodeStartOffset + startNode.piece.length == offset + cnt {
                deleteNodeTail(node: &startNode, pos: startSplitPosInBuffer)
                validateCRLFWithNextNode(node: &startNode)
                computeBufferMetadata();
                return;
            }

            // delete content in the middle, this node will be splitted to nodes
            shrinkNode(node: &startNode, start: startSplitPosInBuffer, end: endSplitPosInBuffer);
            computeBufferMetadata();
            return;
        }

        var nodesToDel: [TreeNode] = []

        let startSplitPosInBuffer = positionInBuffer(node: startNode, remainder: startPosition.remainder)
        deleteNodeTail(node: &startNode, pos: startSplitPosInBuffer)
        searchCache.validate(offset: offset)
        if (startNode.piece.length == 0) {
            nodesToDel.append(startNode)
        }

        // update last touched node
        let endSplitPosInBuffer = positionInBuffer(node: endNode, remainder: endPosition.remainder)
        deleteNodeHead(node: &endNode, pos: endSplitPosInBuffer);
        if endNode.piece.length == 0 {
            nodesToDel.append(endNode);
        }

        // delete nodes in between
        let secondNode = startNode.next()
        var node = secondNode
        while node !== TreeNode.SENTINEL && node !== endNode {
            nodesToDel.append(node)
            node = node.next()
        }

        var prev = startNode.piece.length == 0 ? startNode.prev() : startNode
        deleteNodes(nodesToDel)
        validateCRLFWithNextNode(node: &prev)
        computeBufferMetadata()
    }
    
    func insertContentToNodeLeft(value: inout [UInt8], node: inout TreeNode)
    {
        // we are inserting content to the beginning of node
        var nodesToDel: [TreeNode] = []
        if shouldCheckCRLF() && endWithCR(value) && startWithLF(node) {
            // move `\n` to new node.

            let piece = node.piece
            let newStart = BufferCursor (line: piece.start.line + 1, column: 0)
            let nPiece = Piece(bufferIndex: piece.bufferIndex, start: newStart, end: piece.end, length: piece.length-1, lineFeedCount: getLineFeedCount(bufferIndex: piece.bufferIndex, start: newStart, end: piece.end))

            node.piece = nPiece

            value += [10 /*LF*/]
            updateTreeMetadata (self, &node, -1, -1)

            if node.piece.length == 0 {
                nodesToDel.append(node)
            }
        }

        let newPieces = createNewPieces(value)
        var newNode = rbInsertLeft(node: node, p: newPieces[newPieces.count - 1])
        for k in (0..<newPieces.count - 2).reversed () {
            newNode = rbInsertLeft(node: newNode, p: newPieces[k])
        }
        validateCRLFWithPrevNode(nextNode: &newNode)
        deleteNodes(nodesToDel)
    }
    
    func insertContentToNodeRight(value: inout [UInt8], node: TreeNode)
    {
        if adjustCarriageReturnFromNext(value: &value, node: node) {
            // move \n to the new node.
            value += [10 /*LF*/]
        }

        let newPieces = createNewPieces(value)
        var newNode = rbInsertRight(node, newPieces[0])
        var tmpNode = newNode

        for k in 1..<newPieces.count {
            tmpNode = rbInsertRight(tmpNode, newPieces[k])
        }

        validateCRLFWithPrevNode(nextNode: &newNode)
    }
    
    func positionInBuffer(node: TreeNode, remainder: Int) -> BufferCursor {
        let piece = node.piece
        let bufferIndex = node.piece.bufferIndex
        let lineStarts = buffers[bufferIndex].lineStarts

        let startOffset = lineStarts[piece.start.line] + piece.start.column

        let offset = startOffset + remainder

        // binary search offset between startOffset and endOffset
        var low = piece.start.line
        var high = piece.end.line

        var mid = 0;
        var midStop = 0;
        var midStart = 0;

        while low <= high {
            mid = low + ((high - low) / 2) | 0
            midStart = lineStarts[mid]

            if mid == high {
                break
            }

            midStop = lineStarts[mid + 1]

            if offset < midStart {
                high = mid - 1
            } else if offset >= midStop {
                low = mid + 1
            } else {
                break
            }
        }

        return BufferCursor(line: mid, column: offset - midStart)
    }
    
    func getLineFeedCount(bufferIndex: Int, start: BufferCursor, end: BufferCursor) -> Int
    {
        // we don't need to worry about start: abc\r|\n, or abc|\r, or abc|\n, or abc|\r\n doesn't change the fact that, there is one line break after start.
        // now let's take care of end: abc\r|\n, if end is in between \r and \n, we need to add line feed count by 1
        if end.column == 0 {
            return end.line - start.line
        }

        let lineStarts = buffers[bufferIndex].lineStarts
        if end.line == lineStarts.count - 1 { // it means, there is no \n after end, otherwise, there will be one more lineStart.
            return end.line - start.line
        }

        let nextLineStartOffset = lineStarts[end.line + 1]
        let endOffset = lineStarts[end.line] + end.column
        if nextLineStartOffset > endOffset + 1 { // there are more than 1 character after end, which means it can't be \n
            return end.line - start.line
        }
        // endOffset + 1 === nextLineStartOffset
        // character at endOffset is \n, so we check the character before first
        // if character at endOffset is \r, end.column is 0 and we can't get here.
        let previousCharOffset = endOffset - 1; // end.column > 0 so it's okay.
        let buffer = buffers[bufferIndex].buffer

        if buffer [previousCharOffset] == 13 {
            return end.line - start.line + 1
        } else {
            return end.line - start.line
        }
    }
    
    func offsetInBuffer(_ bufferIndex: Int, _ cursor: BufferCursor) -> Int
    {
        let lineStarts = buffers[bufferIndex].lineStarts
        return lineStarts[cursor.line] + cursor.column
    }
    
    func deleteNodes(_ nodes: [TreeNode])
    {
        for node in nodes {
            rbDelete (self, node)
        }
    }
    
    func createNewPieces(_ _text: [UInt8]) -> [Piece]
    {
        var text = _text[0..<_text.count]
        
        if text.count > AverageBufferSize {
            // the content is large, operations like subString, charCode becomes slow
            // so here we split it into smaller chunks, just like what we did for CR/LF normalization
            var newPieces: [Piece] = []
            while text.count > AverageBufferSize {
                let lastChar = Int (text [AverageBufferSize - 1])
                var splitText: [UInt8]
                
                // TODO: This code has some half-cooked code that does Unicode here
                if lastChar == 13 || (lastChar >= 0xD800 && lastChar <= 0xDBFF) {
                    // last character is \r or a high surrogate => keep it back
                    splitText = Array (text [0..<(AverageBufferSize - 1)])
                    text = text [(AverageBufferSize - 1)...]
                } else {
                    splitText = Array (text [0..<AverageBufferSize])
                    text = text[AverageBufferSize...]
                }

                let lineStarts = LineStarts.createLineStartsArray(Array (splitText))
                newPieces.append(Piece(bufferIndex: buffers.count, start: BufferCursor(line: 0, column: 0), end: BufferCursor(line: lineStarts.count-1, column: splitText.count - lineStarts[lineStarts.count-1]), length: splitText.count, lineFeedCount: lineStarts.count-1))
                buffers.append(StringBuffer(buffer: splitText, lineStarts: lineStarts));
            }

            let lineStarts = LineStarts.createLineStartsArray (Array(text))
            newPieces.append(Piece(bufferIndex: buffers.count, start: BufferCursor(line: 0, column: 0), end: BufferCursor(line: lineStarts.count-1, column: text.count - lineStarts[lineStarts.count-1]), length: text.count, lineFeedCount: lineStarts.count-1))
            buffers.append(StringBuffer(buffer: Array (text), lineStarts: lineStarts))

            return newPieces
        }

        var startOffset = buffers[0].buffer.count
        var lineStarts = LineStarts.createLineStartsArray(_text)

        var start = lastChangeBufferPos
        if buffers[0].lineStarts[buffers[0].lineStarts.count - 1] == startOffset
            && startOffset != 0
            && startWithLF(_text)
            && endWithCR(buffers[0].buffer) // todo, we can check _lastChangeBufferPos's column as it's the last one
         {
            lastChangeBufferPos = BufferCursor(line: lastChangeBufferPos.line, column: lastChangeBufferPos.column + 1)
            start = lastChangeBufferPos

            for i in 0..<lineStarts.count {
                lineStarts[i] += startOffset + 1
            }

            buffers[0].lineStarts = buffers[0].lineStarts + lineStarts [1...]
            buffers[0].buffer += [95 /* _ */] + _text
            startOffset += 1
        } else {
            if startOffset != 0 {
                for i in 0..<lineStarts.count {
                    lineStarts[i] += startOffset
                }
            }
            buffers[0].lineStarts = buffers[0].lineStarts + lineStarts [1...]
            buffers[0].buffer += _text
        }

        let endOffset = buffers[0].buffer.count
        let endIndex = buffers[0].lineStarts.count - 1
        let endColumn = endOffset - buffers[0].lineStarts[endIndex]
        let endPos = BufferCursor (line: endIndex, column: endColumn)
        let newPiece = Piece(bufferIndex: 0, start: start, end: endPos, length: endOffset-startOffset, lineFeedCount: getLineFeedCount(bufferIndex: 0, start: start, end: endPos))
        lastChangeBufferPos = endPos
        return [newPiece]
    }
    
    func getLinesRawContent() -> [UInt8]
    {
        return getContentOfSubTree(node: root)
    }

    func getLineRawContent(_ _lineNumber: Int, _ endOffset: Int = 0) -> [UInt8]
    {
        var lineNumber = _lineNumber
        var x = root

        var ret : [UInt8] = [];

        if let cache = searchCache.get2(lineNumber: lineNumber) {
            x = cache.node
            let prevAccumualtedValue = getAccumulatedValue(node: x, index: lineNumber - (cache.nodeStartLineNumber ?? 0) - 1)
            let buffer = buffers[x.piece.bufferIndex].buffer
            let startOffset = offsetInBuffer(x.piece.bufferIndex, x.piece.start)
            if (cache.nodeStartLineNumber ?? 0) + x.piece.lineFeedCount == lineNumber {
                ret = Array (buffer [(startOffset+prevAccumualtedValue)..<(startOffset + x.piece.length)])
            } else {
                let accumualtedValue = getAccumulatedValue(node: x, index: lineNumber - (cache.nodeStartLineNumber ?? 0))
                return Array (buffer [(startOffset + prevAccumualtedValue)..<(startOffset + accumualtedValue - endOffset)])
            }
        } else {
            var nodeStartOffset = 0
            let originalLineNumber = lineNumber
            while x !== TreeNode.SENTINEL {
                if x.left !== TreeNode.SENTINEL && x.lf_left >= lineNumber - 1 {
                    x = x.left!
                } else if x.lf_left + x.piece.lineFeedCount > lineNumber - 1 {
                    let prevAccumualtedValue = getAccumulatedValue(node: x, index: lineNumber - x.lf_left - 2)
                    let accumualtedValue = getAccumulatedValue(node: x, index: lineNumber - x.lf_left - 1)
                    let buffer = buffers[x.piece.bufferIndex].buffer
                    let startOffset = offsetInBuffer(x.piece.bufferIndex, x.piece.start)
                    nodeStartOffset += x.size_left
                    searchCache.set(CacheEntry(node: x, nodeStartLineNumber: originalLineNumber - (lineNumber - 1 - x.lf_left), nodeStartOffset: nodeStartOffset))
                    return Array (buffer[(startOffset + prevAccumualtedValue)..<(startOffset + accumualtedValue - endOffset)])
                } else if x.lf_left + x.piece.lineFeedCount == lineNumber - 1 {
                    let prevAccumualtedValue = getAccumulatedValue(node: x, index: lineNumber - x.lf_left - 2)
                    let buffer = buffers[x.piece.bufferIndex].buffer
                    let startOffset = offsetInBuffer(x.piece.bufferIndex, x.piece.start)

                    ret = Array (buffer[(startOffset + prevAccumualtedValue)..<(startOffset + x.piece.length)])
                    break;
                } else {
                    lineNumber -= x.lf_left + x.piece.lineFeedCount
                    nodeStartOffset += x.size_left + x.piece.length
                    x = x.right!
                }
            }
        }
        // search in order, to find the node contains end column
        x = x.next()
        while x !== TreeNode.SENTINEL {
            let buffer = buffers[x.piece.bufferIndex].buffer

            if x.piece.lineFeedCount > 0 {
                let accumualtedValue = getAccumulatedValue(node: x, index: 0)
                let startOffset = offsetInBuffer(x.piece.bufferIndex, x.piece.start)

                ret += Array (buffer[startOffset..<(startOffset + accumualtedValue - endOffset)])
                return ret
            } else {
                let startOffset = offsetInBuffer(x.piece.bufferIndex, x.piece.start)
                ret += Array (buffer [startOffset..<x.piece.length])
            }

            x = x.next()
        }

        return ret
    }
    
    func computeBufferMetadata ()
    {
            var x = root
            var lfCnt = 1
            var len = 0;

            while x !== TreeNode.SENTINEL {
                lfCnt += x.lf_left + x.piece.lineFeedCount
                len += x.size_left + x.piece.length
                x = x.right!
            }

            lineCount = lfCnt
            length = len
            searchCache.validate(offset: length)
    }

    func getIndexOf(node: TreeNode, accumulatedValue: Int) -> (index: Int, remainder: Int ) {
        let piece = node.piece
        let pos = positionInBuffer(node: node, remainder: accumulatedValue)
        let lineCnt = pos.line - piece.start.line

        if offsetInBuffer(piece.bufferIndex, piece.end) - offsetInBuffer(piece.bufferIndex, piece.start) == accumulatedValue {
            // we are checking the end of this node, so a CRLF check is necessary.
            let realLineCnt = getLineFeedCount(bufferIndex: node.piece.bufferIndex, start: piece.start, end: pos)
            if realLineCnt != lineCnt {
                // aha yes, CRLF
                return (index: realLineCnt, remainder: 0)
            }
        }

        return (index: lineCnt, remainder: pos.column)
    }
    
    func getAccumulatedValue(node: TreeNode, index: Int) -> Int {
        if index < 0 {
            return 0
        }
        let piece = node.piece
        let lineStarts = buffers[piece.bufferIndex].lineStarts
        let expectedLineStartIndex = piece.start.line + index + 1
        if expectedLineStartIndex > piece.end.line {
            return lineStarts[piece.end.line] + piece.end.column - lineStarts[piece.start.line] - piece.start.column
        } else {
            return lineStarts[expectedLineStartIndex] - lineStarts[piece.start.line] - piece.start.column
        }
    }
    
    func deleteNodeTail(node: inout TreeNode, pos: BufferCursor)
    {
        let piece = node.piece
        let originalLFCnt = piece.lineFeedCount
        let originalEndOffset = offsetInBuffer(piece.bufferIndex, piece.end)

        let newEnd = pos
        let newEndOffset = offsetInBuffer(piece.bufferIndex, newEnd)
        let newLineFeedCnt = getLineFeedCount(bufferIndex: piece.bufferIndex, start: piece.start, end: newEnd)

        let lf_delta = newLineFeedCnt - originalLFCnt
        let size_delta = newEndOffset - originalEndOffset
        let newLength = piece.length + size_delta

        node.piece = Piece(bufferIndex: piece.bufferIndex, start: piece.start, end: newEnd, length: newLength, lineFeedCount: newLineFeedCnt)

        updateTreeMetadata(self, &node, size_delta, lf_delta)
    }
    
    func deleteNodeHead(node: inout TreeNode, pos: BufferCursor)
    {
        let piece = node.piece
        let originalLFCnt = piece.lineFeedCount
        let originalStartOffset = offsetInBuffer(piece.bufferIndex, piece.start)

        let newStart = pos
        let newLineFeedCnt = getLineFeedCount(bufferIndex: piece.bufferIndex, start: newStart, end: piece.end)
        let newStartOffset = offsetInBuffer(piece.bufferIndex, newStart)
        let lf_delta = newLineFeedCnt - originalLFCnt
        let size_delta = originalStartOffset - newStartOffset
        let newLength = piece.length + size_delta
        node.piece = Piece(bufferIndex: piece.bufferIndex, start: newStart, end: piece.end, length: newLength, lineFeedCount: newLineFeedCnt)

        updateTreeMetadata(self, &node, size_delta, lf_delta);
    }
    
    func shrinkNode(node: inout TreeNode, start: BufferCursor, end: BufferCursor)
    {
        let piece = node.piece
        let originalStartPos = piece.start
        let originalEndPos = piece.end

        // old piece, originalStartPos, start
        let oldLength = piece.length
        let oldLFCnt = piece.lineFeedCount
        let newEnd = start
        let newLineFeedCnt = getLineFeedCount(bufferIndex: piece.bufferIndex, start: piece.start, end: newEnd)
        let newLength = offsetInBuffer(piece.bufferIndex, start) - offsetInBuffer(piece.bufferIndex, originalStartPos);

        node.piece = Piece(bufferIndex: piece.bufferIndex, start: piece.start, end: newEnd, length: newLength, lineFeedCount: newLineFeedCnt)

        updateTreeMetadata(self, &node, newLength - oldLength, newLineFeedCnt - oldLFCnt)

        // new right piece, end, originalEndPos
        let newPiece = Piece(bufferIndex: piece.bufferIndex, start: end, end: originalEndPos, length: offsetInBuffer(piece.bufferIndex, originalEndPos) - offsetInBuffer(piece.bufferIndex, end), lineFeedCount:getLineFeedCount(bufferIndex: piece.bufferIndex, start: end, end: originalEndPos))

        var newNode = rbInsertRight(node, newPiece)
        validateCRLFWithPrevNode(nextNode: &newNode)
    }
    
    func appendToNode(node: inout TreeNode, value: inout [UInt8]) {
        if adjustCarriageReturnFromNext(value: &value, node: node) {
            value += [10]
        }

        let hitCRLF = shouldCheckCRLF() && startWithLF(value) && endWithCR(node)
        let startOffset = buffers[0].buffer.count
        buffers[0].buffer += value
        var lineStarts = LineStarts.createLineStartsArray (value)
        for i in 0..<lineStarts.count {
            lineStarts[i] += startOffset
        }
        if hitCRLF {
            let prevStartOffset = buffers[0].lineStarts[buffers[0].lineStarts.count - 2]
            let _ = buffers [0].lineStarts.popLast()
        
            // _lastChangeBufferPos is already wrong
            lastChangeBufferPos = BufferCursor (line: lastChangeBufferPos.line - 1, column: startOffset - prevStartOffset)
        }

        buffers[0].lineStarts = buffers[0].lineStarts + Array (lineStarts [1...])
        let endIndex = buffers[0].lineStarts.count - 1
        let endColumn = buffers[0].buffer.count - buffers[0].lineStarts[endIndex]
        let newEnd = BufferCursor(line: endIndex, column: endColumn)
        let newLength = node.piece.length + value.count
        let oldLineFeedCount = node.piece.lineFeedCount
        let newLineFeedCount = getLineFeedCount(bufferIndex: 0, start: node.piece.start, end: newEnd)
        let lf_delta = newLineFeedCount - oldLineFeedCount;

        node.piece = Piece(bufferIndex: node.piece.bufferIndex, start: node.piece.start, end: newEnd, length: newLength, lineFeedCount: newLineFeedCount)
        lastChangeBufferPos = newEnd
        updateTreeMetadata(self, &node, value.count, lf_delta)
    }
    
    func nodeAt(_ _offset: Int) -> NodePosition?
    {
        var offset = _offset
        var x = root
        if let cache = searchCache.get(offset: offset) {
            return NodePosition (node: cache.node, remainder: offset - cache.nodeStartOffset, nodeStartOffset: cache.nodeStartOffset)
        }

        var nodeStartOffset = 0

        while x !== TreeNode.SENTINEL {
            if x.size_left > offset {
                x = x.left!
            } else if x.size_left + x.piece.length >= offset {
                nodeStartOffset += x.size_left
                let ret = NodePosition(node: x, remainder: offset - x.size_left, nodeStartOffset: nodeStartOffset)
                searchCache.set(CacheEntry (ret))
                return ret
            } else {
                offset -= x.size_left + x.piece.length
                nodeStartOffset += x.size_left + x.piece.length
                x = x.right!
            }
        }

        return nil
    }

    func nodeAt2(line _lineNumber: Int, col _column: Int) -> NodePosition?
    {
        var column = _column
        var lineNumber = _lineNumber
        var x = root
        var nodeStartOffset = 0

        while x !== TreeNode.SENTINEL {
            if x.left !== TreeNode.SENTINEL && x.lf_left >= lineNumber - 1 {
                x = x.left!
            } else if x.lf_left + x.piece.lineFeedCount > lineNumber - 1 {
                let prevAccumualtedValue = getAccumulatedValue(node: x, index: lineNumber - x.lf_left - 2)
                let accumualtedValue = getAccumulatedValue(node: x, index: lineNumber - x.lf_left - 1)
                nodeStartOffset += x.size_left

                return NodePosition(node: x, remainder: min(prevAccumualtedValue+column-1, accumualtedValue), nodeStartOffset: nodeStartOffset)
            } else if x.lf_left + x.piece.lineFeedCount == lineNumber - 1 {
                let prevAccumualtedValue = getAccumulatedValue(node: x, index: lineNumber - x.lf_left - 2)
                if prevAccumualtedValue + column - 1 <= x.piece.length {
                    return NodePosition(node: x, remainder: prevAccumualtedValue+column-1, nodeStartOffset: nodeStartOffset)
                } else {
                    column -= x.piece.length - prevAccumualtedValue
                    break
                }
            } else {
                lineNumber -= x.lf_left + x.piece.lineFeedCount
                nodeStartOffset += x.size_left + x.piece.length
                x = x.right!
            }
        }

        // search in order, to find the node contains position.column
        x = x.next();
        while x !== TreeNode.SENTINEL {

            if x.piece.lineFeedCount > 0 {
                let accumualtedValue = getAccumulatedValue(node: x, index: 0)
                let nodeStartOffset = offsetOfNode(x)
                return NodePosition(node: x, remainder: min(column-1, accumualtedValue), nodeStartOffset: nodeStartOffset)
            } else {
                if x.piece.length >= column - 1 {
                    let nodeStartOffset = offsetOfNode(x)
                    return NodePosition(node: x, remainder: column-1, nodeStartOffset: nodeStartOffset)
                } else {
                    column -= x.piece.length
                }
            }

            x = x.next();
        }

        return nil
    }
    
    func nodeCharCodeAt(_ node: TreeNode, _ offset: Int) -> Int {
        if node.piece.lineFeedCount < 1 {
            return -1
        }
        let buffer = buffers[node.piece.bufferIndex]
        let newOffset = offsetInBuffer(node.piece.bufferIndex, node.piece.start) + offset
        return Int(buffer.buffer [newOffset])
    }

    func offsetOfNode(_ _node: TreeNode) -> Int {
        var node = _node
        var pos = node.size_left
        while node !== root {
            if node.parent!.right === node {
                pos += node.parent!.size_left + node.parent!.piece.length
            }

            node = node.parent!
        }

        return pos;
    }
    
    func shouldCheckCRLF() -> Bool {
        return !(eolNormalized && eol == [10]);
    }
    
    func startWithLF(_ val: [UInt8]) -> Bool
    {
        return val [0] == 10
    }

    func startWithLF(_ val: TreeNode) -> Bool
    {
        if val === TreeNode.SENTINEL || val.piece.lineFeedCount == 0 {
            return false
        }

        let piece = val.piece
        let lineStarts = buffers[piece.bufferIndex].lineStarts
        let line = piece.start.line
        let startOffset = lineStarts[line] + piece.start.column
        if line == (lineStarts.count - 1) {
            // last line, so there is no line feed at the end of this line
            return false
        }
        let nextLineOffset = lineStarts[line + 1]
        if nextLineOffset > startOffset + 1 {
            return false
        }
        return buffers[piece.bufferIndex].buffer [startOffset] == 10
    }
    
    func endWithCR(_ val: [UInt8]) -> Bool {
        return val[val.count - 1] == 13
    }

    func endWithCR(_ val: TreeNode) -> Bool {
        if val === TreeNode.SENTINEL || val.piece.lineFeedCount == 0 {
            return false
        }

        return nodeCharCodeAt(val, val.piece.length - 1) == 13
    }

    func validateCRLFWithPrevNode(nextNode: inout TreeNode)
    {
        if shouldCheckCRLF() && startWithLF(nextNode) {
            var node = nextNode.prev()
            if endWithCR(node) {
                fixCRLF(prev: &node, next: &nextNode)
            }
        }
    }
    
    func validateCRLFWithNextNode(node: inout TreeNode)
    {
        if shouldCheckCRLF() && endWithCR(node) {
            var nextNode = node.next()
            if startWithLF(nextNode) {
                fixCRLF(prev: &node, next: &nextNode)
            }
        }
    }

    func fixCRLF(prev: inout TreeNode, next: inout TreeNode)
    {
        var nodesToDel: [TreeNode] = []
        // update node
        let lineStarts = buffers[prev.piece.bufferIndex].lineStarts
        let newEnd: BufferCursor
        
        if prev.piece.end.column == 0 {
            // it means, last line ends with \r, not \r\n
            newEnd = BufferCursor (line: prev.piece.end.line - 1, column: lineStarts[prev.piece.end.line] - lineStarts[prev.piece.end.line - 1] - 1 )
        } else {
            // \r\n
            newEnd = BufferCursor (line: prev.piece.end.line, column: prev.piece.end.column - 1)
        }

        let prevNewLength = prev.piece.length - 1
        let prevNewLFCnt = prev.piece.lineFeedCount - 1
        prev.piece = Piece(bufferIndex: prev.piece.bufferIndex, start: prev.piece.start, end: newEnd, length: prevNewLength, lineFeedCount: prevNewLFCnt)

        updateTreeMetadata(self, &prev, -1, -1);
        if (prev.piece.length == 0) {
            nodesToDel.append(prev)
        }

        // update nextNode
        let newStart = BufferCursor (line: next.piece.start.line + 1, column: 0)
        let newLength = next.piece.length - 1
        let newLineFeedCnt = getLineFeedCount(bufferIndex: next.piece.bufferIndex, start: newStart, end: next.piece.end)
        next.piece = Piece(bufferIndex: next.piece.bufferIndex, start: newStart, end: next.piece.end, length: newLength, lineFeedCount: newLineFeedCnt)

        updateTreeMetadata(self, &next, -1, -1)
        if (next.piece.length == 0) {
            nodesToDel.append(next)
        }

        // create new piece which contains \r\n
        let pieces = createNewPieces([13 /*CR*/, 10 /*LF*/])
        let _ = rbInsertRight(prev, pieces[0])
        // delete empty nodes

        for node in nodesToDel {
            rbDelete(self, node)
        }
    }
    
    func adjustCarriageReturnFromNext(value: inout [UInt8], node: TreeNode) -> Bool {
        if shouldCheckCRLF() && endWithCR(value) {
            var nextNode = node.next()
            if startWithLF(nextNode) {
                // move `\n` forward
                value += [10 /*LF*/]

                if nextNode.piece.length == 1 {
                    rbDelete(self, nextNode)
                } else {
                    let piece = nextNode.piece
                    let newStart: BufferCursor = BufferCursor(line: piece.start.line + 1, column: 0)
                    let newLength = piece.length - 1
                    let newLineFeedCount = getLineFeedCount(bufferIndex: piece.bufferIndex, start: newStart, end: piece.end)
                    nextNode.piece = Piece(bufferIndex: piece.bufferIndex, start: newStart, end: piece.end, length: newLength, lineFeedCount: newLineFeedCount)
                    updateTreeMetadata(self, &nextNode, -1, -1)
                }
                return true
            }
        }

        return false
    }
    
    @discardableResult
    func iterate(node: TreeNode, callback: (_ node: TreeNode) -> Bool) -> Bool {
        if node === TreeNode.SENTINEL {
            return callback(TreeNode.SENTINEL);
        }

        let leftRet = iterate(node: node.left!, callback: callback);
        if !leftRet {
            return leftRet;
        }

        return callback(node) && iterate(node: node.right!, callback: callback);
    }
    
    func getNodeContent(_ node: TreeNode) -> [UInt8]
    {
        if node === TreeNode.SENTINEL {
            return []
        }
        let buffer = buffers [node.piece.bufferIndex]
        let piece = node.piece
        let startOffset = offsetInBuffer(piece.bufferIndex, piece.start)
        let endOffset = offsetInBuffer(piece.bufferIndex, piece.end)
        return Array (buffer.buffer [startOffset..<endOffset])
    }
    
    func getPieceContent(piece: Piece) -> [UInt8] {
        
        let buffer = buffers[piece.bufferIndex]
        let startOffset = offsetInBuffer(piece.bufferIndex, piece.start)
        let endOffset = offsetInBuffer(piece.bufferIndex, piece.end)
        let currentContent = buffer.buffer [startOffset..<endOffset]
        return Array (currentContent)
    }
    
    /**
     *      node              node
     *     /  \              /  \
     *    a   b    <----   a    b
     *                     /
     *                    z
     */
    func rbInsertRight (_ node: TreeNode?, _ p: Piece) -> TreeNode {
        var z = TreeNode(p, .red)
        z.left = TreeNode.SENTINEL
        z.right = TreeNode.SENTINEL
        z.parent = TreeNode.SENTINEL
        z.size_left = 0
        z.lf_left = 0

        let x = root
        if x === TreeNode.SENTINEL {
            root = z
            z.color = .black
        } else if node!.right === TreeNode.SENTINEL {
            node!.right = z
            z.parent = node!
        } else {
            let nextNode = leftest(node!.right!)
            nextNode.left = z
            z.parent = nextNode
        }

        fixInsert(self, z)
        return z
    }
    
    
    /**
     *      node              node
     *     /  \              /  \
     *    a   b     ---->   a    b
     *               \
     *               z
     */
    func rbInsertLeft(node: TreeNode?, p: Piece) -> TreeNode {
        var z = TreeNode(p, .red)
        z.left = TreeNode.SENTINEL
        z.right = TreeNode.SENTINEL
        z.parent = TreeNode.SENTINEL
        z.size_left = 0
        z.lf_left = 0

        if root === TreeNode.SENTINEL {
            root = z
            z.color = .black
        } else if node!.left === TreeNode.SENTINEL {
            node!.left = z
            z.parent = node!
        } else {
            let prevNode = righttest(node!.left!) // a
            prevNode.right = z
            z.parent = prevNode
        }

        fixInsert(self, z);
        return z
    }
    
    func getContentOfSubTree(node: TreeNode) -> [UInt8] {
        var str : [UInt8] = []

        iterate(node: node, callback: { node in
            str += getNodeContent(node)
            return true
        });

        return str
    }
}
