//
//  SearchData.swift
//  TextBufferKit
//
//  Created by Miguel de Icaza on 8/19/19.
//  Copyright © 2019 Miguel de Icaza. All rights reserved.
//

import Foundation

public struct SearchData {
    /// The regex to search for. Always defined.
    public var regex: NSRegularExpression
    // The word separator classifier.
    // public var wordSeparators: WordCharacterClassifier
    /// The simple string to search for (if possible).
    public var simpleSearch : String?
}


