//
//  PieceTreeTextBuffer.swift
//  TextBufferKit
//
//  Created by Miguel de Icaza on 8/16/19.
//  Copyright © 2019 Miguel de Icaza. All rights reserved.
//
// https://github.com/microsoft/vscode/blob/master/src/vs/editor/common/model/pieceTreeTextBuffer/pieceTreeTextBuffer.ts
import Foundation

struct IValidatedEditOperation {
    var sortIndex: Int
    var identifier: ISingleEditOperationIdentifier?
    var range: Range
    var rangeOffset: Int
    var rangeLength: Int
    var lines: [[UInt8]]?
    var forceMoveMarkers: Bool
    var isAutoWhitespaceEdit: Bool
}

/// An identifier for a single edit operation.
public struct ISingleEditOperationIdentifier {
    /// Identifier major
    public var major : Int
    /// Identifier minor
    public var minor : Int
}

public struct IIdentifiedSingleEditOperation {
    /// An identifier associated with this single edit operation.
    public var identifier : ISingleEditOperationIdentifier
    /// The range to replace. This can be empty to emulate a simple insert.
    public var range: Range
    /// The text to replace with. This can be null to emulate a simple delete.
    public var text: String?
    /// This indicates that this operation has "insert" semantics.
    /// This indicates that this operation has "insert" semantics.
    public var forceMoveMarkers: Bool
    /// This indicates that this operation is inserting automatic whitespace
    /// that can be removed on next model edit operation if `config.trimAutoWhitespace` is true.
    public var isAutoWhitespaceEdit: Bool?
    /// This indicates that this operation is in a set of operations that are tracked and should not be "simplified".
    var isTracked : Bool
}

public enum EndOfLinePreference {
    /// Use the end of line character identified in the text buffer.
    case TextDefined
    /// Use line feed (\n) as the end of line character.
    case LF
    /// Use carriage return and line feed (\r\n) as the end of line character.
    case CRLF
}

public struct ApplyEditsResult {
    public var reverseEdits: [IIdentifiedSingleEditOperation]
    // public var rawChanges: [ModelRawChange]
    // public var changes: [IInternalModelContentChange]
    public var trimAutoWhitespaceLineNumbers: [Int]
}

class PieceTreeTextBuffer {
    var pieceTree: PieceTreeBase
    public private(set) var bom: [UInt8]
    public private(set) var mightContainRTL: Bool
    public private(set) var mightContainNonBasicASCII: Bool
    public var eol : [UInt8] {
        get { pieceTree.eol }
        set {
            if newValue == [10] || newValue == [10, 13] {
                pieceTree.eol = newValue
            }
        }
    }

    init(chunks: inout [StringBuffer], BOM: [UInt8], eol: [UInt8], containsRTL: Bool, isBasicASCII: Bool, eolNormalized: Bool)
    {
        self.bom = BOM
        self.mightContainNonBasicASCII = !isBasicASCII
        self.mightContainRTL = containsRTL
        self.pieceTree = PieceTreeBase(chunks: &chunks, eol: eol, eolNormalized: eolNormalized)
    }

    // #region TextBuffer
    public static func == (left:PieceTreeTextBuffer, right: PieceTreeTextBuffer) -> Bool
    {
        if (left.bom != right.bom) {
            return false
        }
        if (left.eol != right.eol) {
            return false
        }
        return PieceTreeBase.equal (left: left.pieceTree, right: right.pieceTree)
    }
       
    public func createSnapshot (preserveBOM: Bool) ->  PieceTreeSnapshot
    {
        return pieceTree.createSnapshot(bom: preserveBOM ? bom : [])
    }

    public func getOffsetAt(lineNumber: Int, column: Int) ->  Int
    {
        return pieceTree.getOffsetAt(lineNumber, column)
    }

    public func getPositionAt(offset: Int) ->  Position
    {
        return pieceTree.getPositionAt(offset)
    }

    public func getRangeAt(start: Int, length: Int) ->  Range
    {
        let end = start + length
        let startPosition = getPositionAt(offset: start)
        let endPosition = getPositionAt(offset: end)
        return Range(startLineNumber: startPosition.line, startColumn: startPosition.column, endLineNumber: endPosition.line, endColumn: endPosition.column)
    }

    public func getValueInRange(range: Range, eol: EndOfLinePreference = EndOfLinePreference.TextDefined) ->  [UInt8] {
    
        if range.isEmpty() {
            return []
        }
        let lineEnding = _getEndOfLine(eol: eol)
        return pieceTree.getValueInRange(range: range, eol: lineEnding)
    }

    public func getValueLengthInRange(range: Range, eol: EndOfLinePreference = EndOfLinePreference.TextDefined) ->  Int
    {
        if range.isEmpty() {
            return 0
        }

        if range.startLineNumber == range.endLineNumber {
            return (range.endColumn - range.startColumn)
        }

        let startOffset = getOffsetAt(lineNumber: range.startLineNumber, column: range.startColumn)
        let endOffset = getOffsetAt(lineNumber: range.endLineNumber, column: range.endColumn)
        return endOffset - startOffset
    }

    public func getLength() ->  Int {
        return pieceTree.length
    }

    public func getLineCount() ->  Int {
        return pieceTree.lineCount
    }

    public func getLinesContent() -> [ArraySlice<UInt8>] {
        return pieceTree.getLinesContent()
    }

    public func getLineContent(lineNumber: Int) ->  [UInt8] {
        return pieceTree.getLineContent(lineNumber)
    }

    public func getLineCharCode(lineNumber: Int, index: Int) ->  UInt8 {
        return pieceTree.getLineCharCode(lineNumber: lineNumber, index: index)
    }

    public func getLineLength(lineNumber: Int) ->  Int {
        return pieceTree.getLineLength(lineNumber: lineNumber)
    }

    public func getLineMinColumn(lineNumber: Int) ->  Int {
        return 1
    }

    public func getLineMaxColumn(lineNumber: Int) ->  Int {
        return getLineLength(lineNumber: lineNumber) + 1
    }

    static func firstNonWhitespaceIndex (_ str: [UInt8]) -> Int
    {
        let top = str.count
        var i = 0
        while i < top {
            let code = str [i]
            if code != 32 /* space */ && code != 9 /* tab */ {
                return i
            }
            i += 1
        }
        return -1
    }
    
    func getLineFirstNonWhitespaceColumn(lineNumber: Int) ->  Int {
        let result = Self.firstNonWhitespaceIndex(getLineContent(lineNumber: lineNumber))
        if result == -1 {
            return 0
        }
        return result + 1
    }
    
    static func lastNonWhitespaceIndex(_ str: [UInt8], startIndex: Int = -1) -> Int
    {
        for i in (0..<(startIndex == -1 ? str.count-1 : startIndex)).reversed() {
            let code = str [i]
            if code != 32 /* space */ && code != 9 /* TAB */ {
                return i
            }
        }
        return -1
    }

    public func getLineLastNonWhitespaceColumn(lineNumber: Int) ->  Int {
        let result = Self.lastNonWhitespaceIndex(getLineContent(lineNumber: lineNumber))
        if result == -1 {
            return 0
        }
        return result + 2
    }

    func _getEndOfLine(eol: EndOfLinePreference) ->  [UInt8] {
        switch (eol) {
            case EndOfLinePreference.LF:
                return [10]
            case EndOfLinePreference.CRLF:
                return [13, 10]
            case EndOfLinePreference.TextDefined:
                return self.eol
        }
        return [10]
    }


    func splitText (_ txt: String?) -> [[UInt8]]?
    {
        if let txt2 = txt {
            let normalized = txt2.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n");
            let split = normalized.split (separator: "\n").map({sub in String (sub)})
            var result : [[UInt8]] = []
            for line in split {
                result.append (Array(line.utf8))
            }
        }
        return nil
    }
    
    static func containsRTL (_ str: String) -> Bool
    {
        // TODO: needs to scan the string to determine if it contains RTL characters.
        return false
    }
    
    static func isBasicASCII (_ str: String) -> Bool
    {
        for c in str {
            if let a = c.asciiValue {
                if !(a == 9 /* TAB */ || a == 10 || a == 13 || (a >= 0x20 && a <= 0x7e)) {
                    return false
                }
            } else {
                return false
            }
        }
        return true
    }
    
    public enum UsageError : Error {
        case overlappingRanges
    }
    
    public func applyEdits(rawOperations: [IIdentifiedSingleEditOperation], recordTrimAutoWhitespace: Bool) throws ->  ApplyEditsResult
    {
        var mightContainRTL = self.mightContainRTL
        var canReduceOperations = true

        var operations: [IValidatedEditOperation] = []
        for i in 0..<rawOperations.count {
            let op = rawOperations[i]
            if (canReduceOperations && op.isTracked) {
                canReduceOperations = false
            }
            let validatedRange = op.range
            if let optext = op.text {
                if !mightContainRTL {
                    // check if the new inserted text contains RTL
                    mightContainRTL = Self.containsRTL(optext)
                }
                if !mightContainNonBasicASCII {
                    mightContainNonBasicASCII = !Self.isBasicASCII(optext)
                }
            }
            operations[i] = IValidatedEditOperation(
                sortIndex: i,
                identifier: op.identifier,
                range: validatedRange,
                rangeOffset:  getOffsetAt(lineNumber: validatedRange.startLineNumber, column: validatedRange.startColumn),
                rangeLength: getValueLengthInRange(range: validatedRange),
                lines: splitText (op.text),
                forceMoveMarkers: op.forceMoveMarkers,
                isAutoWhitespaceEdit: op.isAutoWhitespaceEdit ?? false)
                
        }

        // Sort operations ascending
        operations.sort(by: { a, b in
            let r = Range.compareUsingEnds(a.range, b.range)
            if (r == 0) {
                return (a.sortIndex - b.sortIndex) < 0
            }
            return r < 0
        })

        var hasTouchingRanges = false
        for i in 0..<operations.count-1 {
            let rangeEnd = operations[i].range.getEndPosition()
            let nextRangeStart = operations[i + 1].range.getStartPosition()

            if (nextRangeStart.isBeforeOrEqual(rangeEnd)) {
                if (nextRangeStart.isBefore(rangeEnd)) {
                    // overlapping ranges
                    throw UsageError.overlappingRanges
                }
                hasTouchingRanges = true
            }
        }

        if (canReduceOperations) {
            operations = _reduceOperations(operations: operations)
        }

//        // Delta encode operations
//        let reverseRanges = PieceTreeTextBuffer._getInverseEditRanges(operations)
//        let newTrimAutoWhitespaceCandidates: { lineNumber: Int, oldContent: String }[] = []
//
//        for (let i = 0; i < operations.length; i++) {
//            let op = operations[i]
//            let reverseRange = reverseRanges[i]
//
//            if (recordTrimAutoWhitespace && op.isAutoWhitespaceEdit && op.range.isEmpty()) {
//                // Record already the future line Ints that might be auto whitespace removal candidates on next edit
//                for (let lineNumber = reverseRange.startLineNumber; lineNumber <= reverseRange.endLineNumber; lineNumber++) {
//                    let currentLineContent = ''
//                    if (lineNumber === reverseRange.startLineNumber) {
//                        currentLineContent = getLineContent(op.range.startLineNumber)
//                        if (Strings.firstNonWhitespaceIndex(currentLineContent) !== -1) {
//                            continue
//                        }
//                    }
//                    newTrimAutoWhitespaceCandidates.push({ lineNumber: lineNumber, oldContent: currentLineContent })
//                }
//            }
//        }
//
//        let reverseOperations: IReverseSingleEditOperation[] = []
//        for (let i = 0; i < operations.length; i++) {
//            let op = operations[i]
//            let reverseRange = reverseRanges[i]
//
//            reverseOperations[i] = {
//                sortIndex: op.sortIndex,
//                identifier: op.identifier,
//                range: reverseRange,
//                text: getValueInRange(op.range),
//                forceMoveMarkers: op.forceMoveMarkers
//            }
//        }
//
//        // Can only sort reverse operations when the order is not significant
//        if (!hasTouchingRanges) {
//            reverseOperations.sort((a, b) => a.sortIndex - b.sortIndex)
//        }
//
//        mightContainRTL = mightContainRTL
//        mightContainNonBasicASCII = mightContainNonBasicASCII
//
//        const contentChanges = _doApplyEdits(operations)
//
//        let trimAutoWhitespacelineNumbers: Int[] | null = null
//        if (recordTrimAutoWhitespace && newTrimAutoWhitespaceCandidates.length > 0) {
//            // sort line Ints auto whitespace removal candidates for next edit descending
//            newTrimAutoWhitespaceCandidates.sort((a, b) => b.lineNumber - a.lineNumber)
//
//            trimAutoWhitespacelineNumbers = []
//            for (let i = 0, len = newTrimAutoWhitespaceCandidates.length; i < len; i++) {
//                let lineNumber = newTrimAutoWhitespaceCandidates[i].lineNumber
//                if (i > 0 && newTrimAutoWhitespaceCandidates[i - 1].lineNumber === lineNumber) {
//                    // Do not have the same line Int twice
//                    continue
//                }
//
//                let prevContent = newTrimAutoWhitespaceCandidates[i].oldContent
//                let lineContent = getLineContent(lineNumber)
//
//                if (lineContent.length === 0 || lineContent === prevContent || Strings.firstNonWhitespaceIndex(lineContent) !== -1) {
//                    continue
//                }
//
//                trimAutoWhitespacelineNumbers.push(lineNumber)
//            }
//        }
//
//        return new ApplyEditsResult(
//            reverseOperations,
//            contentChanges,
//            trimAutoWhitespacelineNumbers
//        )
    }

    /**
     * Transform operations such that they represent the same logic edit,
     * but that they also do not cause OOM crashes.
     */
    func _reduceOperations(operations: [IValidatedEditOperation]) ->  [IValidatedEditOperation] {
        if operations.count < 1000 {
            // We know from empirical testing that a thousand edits work fine regardless of their shape.
            return operations
        }

        // At one point, due to how events are emitted and how each operation is handled,
        // some operations can trigger a high amount of temporary String allocations,
        // that will immediately get edited again.
        // e.g. a formatter inserting ridiculous ammounts of \n on a model with a single line
        // Therefore, the strategy is to collapse all the operations into a huge single edit operation
        return [_toSingleEditOperation(operations)]
    }

    func _toSingleEditOperation(_ operations: [IValidatedEditOperation]) -> IValidatedEditOperation
    {
        var forceMoveMarkers = false
        let firstEditRange = operations[0].range
        let lastEditRange = operations[operations.count - 1].range
        let entireEditRange = Range(startLineNumber: firstEditRange.startLineNumber, startColumn: firstEditRange.startColumn, endLineNumber: lastEditRange.endLineNumber, endColumn: lastEditRange.endColumn)
        var lastendLineNumber = firstEditRange.startLineNumber
        var lastEndColumn = firstEditRange.startColumn
        var result: [UInt8] = []

        for operation in operations {
            let range = operation.range

            forceMoveMarkers = forceMoveMarkers || operation.forceMoveMarkers

            // (1) -- Push old text
            for lineNumber in lastendLineNumber..<range.startLineNumber {
                if (lineNumber == lastendLineNumber) {
                    result.append(contentsOf: getLineContent(lineNumber: lineNumber) [(lastEndColumn-1)...])
                } else {
                    result.append (10)
                    result.append(contentsOf: getLineContent(lineNumber: lineNumber))
                }
            }

            if (range.startLineNumber == lastendLineNumber) {
                result.append (contentsOf: getLineContent(lineNumber: range.startLineNumber) [(lastEndColumn - 1)..<(range.startColumn - 1)])
            } else {
                result.append (10)
                result.append(contentsOf: getLineContent(lineNumber: range.startLineNumber) [0..<(range.startColumn - 1)])
            }

            // (2) -- Push new text
            if let oplines = operation.lines {
                var j = 0
                let lenJ = oplines.count
                while j < lenJ {
                    if (j != 0) {
                        result.append (10)
                    }
                    result.append(contentsOf: oplines[j])
                    j += 1
                }
            }

            lastendLineNumber = operation.range.endLineNumber
            lastEndColumn = operation.range.endColumn
        }

        let llines = result.split(separator: 10, maxSplits: Int.max, omittingEmptySubsequences: false).map ({ Array ($0) })
        
        return IValidatedEditOperation (sortIndex: 0,
                                        identifier: operations [0].identifier,
                                        range: entireEditRange,
                                        rangeOffset: getOffsetAt(lineNumber: entireEditRange.startLineNumber, column: entireEditRange.startColumn),
                                        rangeLength: getValueLengthInRange(range: entireEditRange),
                                        lines: llines,
                                        forceMoveMarkers: forceMoveMarkers,
                                        isAutoWhitespaceEdit: false)
    }

    struct IInternalModelContentChange {
        var range: Range
        var rangeOffset: Int
        var rangeLength: Int
        var text: [UInt8]
        var forceMoveMarkers: Bool
    }
    
    func _doApplyEdits(operations: inout [IValidatedEditOperation]) -> [IInternalModelContentChange]
    {
        operations.sort(by: { a, b in
            let r = Range.compareUsingEnds(a.range, b.range)
            if (r == 0) {
                return (a.sortIndex - b.sortIndex) > 0
            }
            return r > 0
        })

        var contentChanges: [IInternalModelContentChange] = []

        // operations are from bottom to top
        for op in operations {
            let startLineNumber = op.range.startLineNumber
            let startColumn = op.range.startColumn
            let endLineNumber = op.range.endLineNumber
            let endColumn = op.range.endColumn

            if startLineNumber == endLineNumber && startColumn == endColumn && (op.lines != nil || op.lines!.count == 0) {
                // no-op
                continue
            }

            let deletingLinesCnt = endLineNumber - startLineNumber
            let insertingLinesCnt = (op.lines != nil ? op.lines!.count - 1 : 0)
            let editingLinesCnt = min(deletingLinesCnt, insertingLinesCnt)

            let text : [UInt8] = (op.lines != nil ? Array (op.lines!.joined(separator: eol)) : [])

            if text.count > 0 {
                // replacement
                pieceTree.delete(offset: op.rangeOffset, cnt: op.rangeLength)
                pieceTree.insert(offset: op.rangeOffset, value: text, eolNormalized: true)

            } else {
                // deletion
                pieceTree.delete(offset: op.rangeOffset, cnt: op.rangeLength)
            }

            if (editingLinesCnt < insertingLinesCnt) {
                var newLinesContent: [[UInt8]] = []
                for j in (editingLinesCnt + 1)..<insertingLinesCnt {
                    newLinesContent.append (op.lines![j])
                }

                newLinesContent[newLinesContent.count - 1] = getLineContent(lineNumber: startLineNumber + insertingLinesCnt - 1)
            }

            let contentChangeRange = Range(startLineNumber: startLineNumber, startColumn: startColumn, endLineNumber: endLineNumber, endColumn: endColumn)
            contentChanges.append(IInternalModelContentChange(
                range: contentChangeRange,
                rangeOffset: op.rangeOffset,
                rangeLength: op.rangeLength,
                text: text,
                forceMoveMarkers: op.forceMoveMarkers
            ))
        }
        return contentChanges
    }
//
//    func findMatchesLineByLine(searchRange: Range, searchData: SearchData, captureMatches: Bool, limitResultCount: Int) ->  [FindMatch]
//    {
//        return pieceTree.findMatchesLineByLine(searchRange, searchData, captureMatches, limitResultCount)
//    }
//
//    // #endregion
//
//    // #region helper
//    // testing purpose.
//    public func getPieceTree() ->  PieceTreeBase {
//        return pieceTree
//    }
//    
    /**
     * Assumes `operations` are validated and sorted ascending
     */
    public static func _getInverseEditRanges(operations: [IValidatedEditOperation]) ->  [Range] {
        var result: [Range] = []
        var prevOpendLineNumber: Int = 0
        var prevOpEndColumn: Int = 0
        var prevOpNil: IValidatedEditOperation? = nil
        for op in operations {
            var startLineNumber: Int
            var startColumn: Int

            if let prevOp = prevOpNil {
                if prevOp.range.endLineNumber == op.range.startLineNumber {
                    startLineNumber = prevOpendLineNumber
                    startColumn = prevOpEndColumn + (op.range.startColumn - prevOp.range.endColumn)
                } else {
                    startLineNumber = prevOpendLineNumber + (op.range.startLineNumber - prevOp.range.endLineNumber)
                    startColumn = op.range.startColumn
                }
            } else {
                startLineNumber = op.range.startLineNumber
                startColumn = op.range.startColumn
            }

            var resultRange: Range

            if op.lines != nil && op.lines!.count > 0{
                let oplines = op.lines!
                let lineCount = oplines.count
                // the operation inserts something
                let firstLine = oplines[0]
                let lastLine = oplines[lineCount - 1]

                if lineCount == 1 {
                    // single line insert
                    resultRange = Range(startLineNumber: startLineNumber, startColumn: startColumn, endLineNumber: startLineNumber, endColumn: startColumn + firstLine.count)
                } else {
                    // multi line insert
                    resultRange = Range(startLineNumber: startLineNumber, startColumn: startColumn, endLineNumber: startLineNumber + lineCount - 1, endColumn: lastLine.count + 1)
                }
            } else {
                // There is nothing to insert
                resultRange = Range(startLineNumber: startLineNumber, startColumn: startColumn, endLineNumber: startLineNumber, endColumn: startColumn)
            }

            prevOpendLineNumber = resultRange.endLineNumber
            prevOpEndColumn = resultRange.endColumn

            result.append (resultRange)
            prevOpNil = op
        }

        return result
    }

//    func static _sortOpsAscending(a: IValidatedEditOperation, b: IValidatedEditOperation) ->  Int
//    {
//        let r = Range.compareRangesUsingEnds(a.range, b.range)
//        if (r === 0) {
//            return a.sortIndex - b.sortIndex
//        }
//        return r
//    }
//
//    func static _sortOpsDescending(a: IValidatedEditOperation, b: IValidatedEditOperation) ->  Int
//    {
//        let r = Range.compareRangesUsingEnds(a.range, b.range)
//        if (r === 0) {
//            return b.sortIndex - a.sortIndex
//        }
//        return -r
//    }
//    #endif
}
