//
//  TextBufferKitTests.swift
//  TextBufferKitTests
//
//  Created by Miguel de Icaza on 8/16/19.
//  Copyright © 2019 Miguel de Icaza. All rights reserved.
//

import XCTest
@testable import TextBufferKit

public func toBytes (_ str: String) -> [UInt8]
{
    
    if let d = str.data (using: .utf8){
        return ([UInt8](d))
    }
    return []
}

public func toBytes (_ strs: [String]) -> [[UInt8]]
{
    var result: [[UInt8]] = []
    
    for str in strs {
        result.append (toBytes (str))
    }
    return result
}

public func toStr (_ arr: [UInt8]) -> String
{
    return String(bytes: arr, encoding: .utf8)!
}

class TextBufferKitTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        let builder = PieceTreeTextBufferBuilder()

        builder.acceptChunk("abc\n")
        builder.acceptChunk("def")
        let factory = builder.finish(normalizeEol: true)
        let pieceTree = factory.create(DefaultEndOfLine.LF).getPieceTree()

        XCTAssertEqual(pieceTree.lineCount, 2)
        XCTAssertEqual(pieceTree.getLineContent (1), toBytes ("abc"))
        XCTAssertEqual(pieceTree.getLineContent(2), toBytes ("def"))
        pieceTree.insert(1, [65])
        
        XCTAssertEqual(pieceTree.lineCount, 2)
        XCTAssertEqual(pieceTree.getLineContent (1), toBytes ("aAbc"))
        XCTAssertEqual(pieceTree.getLineContent(2), toBytes ("def"))
    }
    
    // More:
    // https://raw.githubusercontent.com/microsoft/vscode/master/src/vs/editor/test/common/model/pieceTreeTextBuffer/pieceTreeTextBuffer.test.ts

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
