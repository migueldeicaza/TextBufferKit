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
    var lines: [String]?
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
    public var text: String
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

    //public func getLineFirstNonWhitespaceColumn(lineNumber: Int) ->  Int {
    //    let result = Strings.firstNonWhitespaceIndex(getLineContent(lineNumber))
    //    if (result === -1) {
    //        return 0
    //    }
    //    return result + 1
    //}

    //public func getLineLastNonWhitespaceColumn(lineNumber: Int) ->  Int {
    //    const result = Strings.lastNonWhitespaceIndex(getLineContent(lineNumber))
    //    if (result === -1) {
    //        return 0
    //    }
    //    return result + 2
    //}

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

//
//    func splitText (_ txt: String?) -> [String]?
//    {
//        if let txt2 = txt {
//            return txt2.split({ ch in
//                return ch == "\n" || "\r"
//            })
//        }
//        return nil
//    }
//    
//    public func applyEdits(rawOperations: [IIdentifiedSingleEditOperation], recordTrimAutoWhitespace: Bool) ->  ApplyEditsResult
//    {
//        var mightContainRTL = mightContainRTL
//        var canReduceOperations = true
//
//        var operations: [IValidatedEditOperation] = []
//        for i in 0..<rawOperations.count {
//            let op = rawOperations[i]
//            if (canReduceOperations && op.isTracked) {
//                canReduceOperations = false
//            }
//            let validatedRange = op.range
//            if (!mightContainRTL && op.text) {
//                // check if the new inserted text contains RTL
//                mightContainRTL = Strings.containsRTL(op.text)
//            }
//            if (!mightContainNonBasicASCII && op.text != nil) {
//                mightContainNonBasicASCII = !Strings.isBasicASCII(op.text)
//            }
//            operations[i] = IValidatedEditOperation(
//                sortIndex: i,
//                identifier: op.identifier,
//                range: validatedRange,
//                rangeOffset:  getOffsetAt(lineNumber: validatedRange.startLineNumber, column: validatedRange.startColumn),
//                rangeLength: getValueLengthInRange(range: validatedRange),
//                lines: splitText (op.text),
//                forceMoveMarkers: op.forceMoveMarkers,
//                isAutoWhitespaceEdit: op.isAutoWhitespaceEdit ?? false)
//                
//        }
//
//        // Sort operations ascending
//        operations.sort(PieceTreeTextBuffer._sortOpsAscending)
//
//        let hasTouchingRanges = false
//        for (let i = 0, count = operations.length - 1; i < count; i++) {
//            let rangeEnd = operations[i].range.getEndPosition()
//            let nextRangeStart = operations[i + 1].range.getStartPosition()
//
//            if (nextRangeStart.isBeforeOrEqual(rangeEnd)) {
//                if (nextRangeStart.isBefore(rangeEnd)) {
//                    // overlapping ranges
//                    throw new Error('Overlapping ranges are not allowed!')
//                }
//                hasTouchingRanges = true
//            }
//        }
//
//        if (canReduceOperations) {
//            operations = _reduceOperations(operations)
//        }
//
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
//    }
//
//    /**
//     * Transform operations such that they represent the same logic edit,
//     * but that they also do not cause OOM crashes.
//     */
//    private _reduceOperations(operations: IValidatedEditOperation[]) ->  IValidatedEditOperation[] {
//        if (operations.length < 1000) {
//            // We know from empirical testing that a thousand edits work fine regardless of their shape.
//            return operations
//        }
//
//        // At one point, due to how events are emitted and how each operation is handled,
//        // some operations can trigger a high amount of temporary String allocations,
//        // that will immediately get edited again.
//        // e.g. a formatter inserting ridiculous ammounts of \n on a model with a single line
//        // Therefore, the strategy is to collapse all the operations into a huge single edit operation
//        return [_toSingleEditOperation(operations)]
//    }
//
//    _toSingleEditOperation(operations: IValidatedEditOperation[]) ->  IValidatedEditOperation {
//        let forceMoveMarkers = false,
//            firstEditRange = operations[0].range,
//            lastEditRange = operations[operations.length - 1].range,
//            entireEditRange = new Range(firstEditRange.startLineNumber, firstEditRange.startColumn, lastEditRange.endLineNumber, lastEditRange.endColumn),
//            lastendLineNumber = firstEditRange.startLineNumber,
//            lastEndColumn = firstEditRange.startColumn,
//            result: String[] = []
//
//        for (let i = 0, len = operations.length; i < len; i++) {
//            let operation = operations[i],
//                range = operation.range
//
//            forceMoveMarkers = forceMoveMarkers || operation.forceMoveMarkers
//
//            // (1) -- Push old text
//            for (let lineNumber = lastendLineNumber; lineNumber < range.startLineNumber; lineNumber++) {
//                if (lineNumber === lastendLineNumber) {
//                    result.push(getLineContent(lineNumber).subString(lastEndColumn - 1))
//                } else {
//                    result.push('\n')
//                    result.push(getLineContent(lineNumber))
//                }
//            }
//
//            if (range.startLineNumber === lastendLineNumber) {
//                result.push(getLineContent(range.startLineNumber).subString(lastEndColumn - 1, range.startColumn - 1))
//            } else {
//                result.push('\n')
//                result.push(getLineContent(range.startLineNumber).subString(0, range.startColumn - 1))
//            }
//
//            // (2) -- Push new text
//            if (operation.lines) {
//                for (let j = 0, lenJ = operation.lines.length; j < lenJ; j++) {
//                    if (j !== 0) {
//                        result.push('\n')
//                    }
//                    result.push(operation.lines[j])
//                }
//            }
//
//            lastendLineNumber = operation.range.endLineNumber
//            lastEndColumn = operation.range.endColumn
//        }
//
//        return {
//            sortIndex: 0,
//            identifier: operations[0].identifier,
//            range: entireEditRange,
//            rangeOffset: getOffsetAt(entireEditRange.startLineNumber, entireEditRange.startColumn),
//            rangeLength: getValueLengthInRange(entireEditRange, EndOfLinePreference.TextDefined),
//            lines: result.join('').split('\n'),
//            forceMoveMarkers: forceMoveMarkers,
//            isAutoWhitespaceEdit: false
//        }
//    }
//
//    func _doApplyEdits(operations: [IValidatedEditOperation]) ->  [IInternalModelContentChange]
//    {
//        operations.sort(PieceTreeTextBuffer._sortOpsDescending)
//
//        let contentChanges: IInternalModelContentChange[] = []
//
//        // operations are from bottom to top
//        for (let i = 0; i < operations.length; i++) {
//            let op = operations[i]
//
//            const startLineNumber = op.range.startLineNumber
//            const startColumn = op.range.startColumn
//            const endLineNumber = op.range.endLineNumber
//            const endColumn = op.range.endColumn
//
//            if (startLineNumber === endLineNumber && startColumn === endColumn && (!op.lines || op.lines.length === 0)) {
//                // no-op
//                continue
//            }
//
//            const deletingLinesCnt = endLineNumber - startLineNumber
//            const insertingLinesCnt = (op.lines ? op.lines.length - 1 : 0)
//            const editingLinesCnt = Math.min(deletingLinesCnt, insertingLinesCnt)
//
//            const text = (op.lines ? op.lines.join(getEOL()) : '')
//
//            if (text) {
//                // replacement
//                pieceTree.delete(op.rangeOffset, op.rangeLength)
//                pieceTree.insert(op.rangeOffset, text, true)
//
//            } else {
//                // deletion
//                pieceTree.delete(op.rangeOffset, op.rangeLength)
//            }
//
//            if (editingLinesCnt < insertingLinesCnt) {
//                let newLinesContent: String[] = []
//                for (let j = editingLinesCnt + 1; j <= insertingLinesCnt; j++) {
//                    newLinesContent.push(op.lines![j])
//                }
//
//                newLinesContent[newLinesContent.length - 1] = getLineContent(startLineNumber + insertingLinesCnt - 1)
//            }
//
//            const contentChangeRange = new Range(startLineNumber, startColumn, endLineNumber, endColumn)
//            contentChanges.push({
//                range: contentChangeRange,
//                rangeLength: op.rangeLength,
//                text: text,
//                rangeOffset: op.rangeOffset,
//                forceMoveMarkers: op.forceMoveMarkers
//            })
//        }
//        return contentChanges
//    }
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
//    /**
//     * Assumes `operations` are validated and sorted ascending
//     */
//    public func static _getInverseEditRanges(operations: [IValidatedEditOperation]) ->  [Range] {
//        let result: Range[] = []
//
//        let prevOpendLineNumber: Int = 0
//        let prevOpEndColumn: Int = 0
//        let prevOp: IValidatedEditOperation | null = null
//        for (let i = 0, len = operations.length; i < len; i++) {
//            let op = operations[i]
//
//            let startLineNumber: Int
//            let startColumn: Int
//
//            if (prevOp) {
//                if (prevOp.range.endLineNumber === op.range.startLineNumber) {
//                    startLineNumber = prevOpendLineNumber
//                    startColumn = prevOpEndColumn + (op.range.startColumn - prevOp.range.endColumn)
//                } else {
//                    startLineNumber = prevOpendLineNumber + (op.range.startLineNumber - prevOp.range.endLineNumber)
//                    startColumn = op.range.startColumn
//                }
//            } else {
//                startLineNumber = op.range.startLineNumber
//                startColumn = op.range.startColumn
//            }
//
//            let resultRange: Range
//
//            if (op.lines && op.lines.length > 0) {
//                // the operation inserts something
//                let lineCount = op.lines.length
//                let firstLine = op.lines[0]
//                let lastLine = op.lines[lineCount - 1]
//
//                if (lineCount === 1) {
//                    // single line insert
//                    resultRange = new Range(startLineNumber, startColumn, startLineNumber, startColumn + firstLine.length)
//                } else {
//                    // multi line insert
//                    resultRange = new Range(startLineNumber, startColumn, startLineNumber + lineCount - 1, lastLine.length + 1)
//                }
//            } else {
//                // There is nothing to insert
//                resultRange = new Range(startLineNumber, startColumn, startLineNumber, startColumn)
//            }
//
//            prevOpendLineNumber = resultRange.endLineNumber
//            prevOpEndColumn = resultRange.endColumn
//
//            result.push(resultRange)
//            prevOp = op
//        }
//
//        return result
//    }
//
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
