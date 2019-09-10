//
//  TreeBse.swift
//  swift-textbuffer
//
//  Created by Miguel de Icaza on 8/10/19.
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

enum NodeColor {
    case black
    case red
}

public class TreeNode : CustomDebugStringConvertible {
    var parent: TreeNode?
    var left: TreeNode?
    var right: TreeNode?
    var color: NodeColor

    // Piece
    var piece: Piece
    var size_left : Int // size of the left subtree (not inorder)
    var lf_left : Int // line feeds cnt in the left subtree (not in order)

    init (_ piece: Piece, _ color: NodeColor) {
        self.piece = piece
        self.color = color
        self.size_left = 0;
        self.lf_left = 0;
        self.parent = nil
        self.left = nil
        self.right = nil
        self.parent = self
        self.left = self
        self.right = self
        
    }

    public var debugDescription: String {
        if self === TreeNode.SENTINEL {
            return "SENTINEL"
        }
        let l = left === TreeNode.SENTINEL ? "(left:S)" : "(left)"
        let r = right === TreeNode.SENTINEL ? "(right:S)" : "(right)"
        return "Color \(color) size_left \(size_left) \(l) \(r)"
    }
    
    static var SENTINEL: TreeNode = TreeNode(Piece(bufferIndex: 0, start: BufferCursor(line: 0,column: 0), end: BufferCursor(line: 0, column: 0), length: 0, lineFeedCount: 0), .black);
    
    public func next() -> TreeNode {
        if (right !== TreeNode.SENTINEL) {
            return leftest (right!)
        }

        var node: TreeNode = self

        while (node.parent !== TreeNode.SENTINEL) {
            if (node.parent!.left === node) {
                break
            }

            node = node.parent!
        }

        if (node.parent === TreeNode.SENTINEL) {
            return TreeNode.SENTINEL
        } else {
            return node.parent!
        }
    }

    public func prev() -> TreeNode {
        if (left !== TreeNode.SENTINEL) {
            return righttest(left!)
        }

        var node: TreeNode = self

        while (node.parent !== TreeNode.SENTINEL) {
            if (node.parent!.right === node) {
                break
            }

            node = node.parent!
        }

        if (node.parent === TreeNode.SENTINEL) {
            return TreeNode.SENTINEL
        } else {
            return node.parent!
        }
    }

    public func detach()
    {
        //parent = nil
        //left = nil
        //right = nil
    }
}


func leftest (_ _node: TreeNode) -> TreeNode {
    var node = _node
    while (node.left! !== TreeNode.SENTINEL) {
        node = node.left!
    }
    return node
}

func righttest (_ _node: TreeNode) -> TreeNode {
    var node = _node
    while (node.right! !== TreeNode.SENTINEL) {
        node = node.right!
    }
    return node
}

func calculateSize(_ node: TreeNode) -> Int {
    if (node === TreeNode.SENTINEL){
        return 0
    }
    return node.size_left + node.piece.length + calculateSize(node.right!)
}

func calculateLF (_ node: TreeNode) -> Int {
    if (node === TreeNode.SENTINEL){
        return 0
    }
    return node.lf_left + node.piece.lineFeedCount + calculateLF(node.right!)
}

func resetSentinel() {
    TreeNode.SENTINEL.parent = TreeNode.SENTINEL
}

func leftRotate(_ tree: PieceTreeBase, _ x: TreeNode) {
    let y = x.right!

    // fix size_left
    y.size_left += x.size_left + (x.piece.length)
    y.lf_left += x.lf_left + (x.piece.lineFeedCount)
    x.right = y.left!

    if (y.left !== TreeNode.SENTINEL) {
        y.left!.parent = x
    }
    y.parent = x.parent
    if (x.parent === TreeNode.SENTINEL) {
        tree.root = y
    } else if (x.parent!.left === x) {
        x.parent!.left = y
    } else {
        x.parent!.right = y
    }
    y.left = x
    x.parent = y
}

func rightRotate(_ tree: PieceTreeBase, _ y: TreeNode) {
    guard let x = y.left else {
        assert(true)
        return
    }
    
    y.left = x.right
    if (x.right !== TreeNode.SENTINEL) {
        x.right!.parent = y
    }
    x.parent = y.parent

    // fix size_left
    y.size_left -= x.size_left + (x.piece.length)
    y.lf_left -= x.lf_left + (x.piece.lineFeedCount)

    if (y.parent === TreeNode.SENTINEL) {
        tree.root = x
    } else if (y === y.parent!.right) {
        y.parent!.right = x
    } else {
        y.parent!.left = x
    }

    x.right = y
    y.parent = x
}

func rbDelete(_ tree: PieceTreeBase, _ z: TreeNode) {
    var x: TreeNode
    var y: TreeNode

    if (z.left === TreeNode.SENTINEL) {
        y = z
        x = y.right!
    } else if (z.right === TreeNode.SENTINEL) {
        y = z
        x = y.left!
    } else {
        y = leftest(z.right!)
        x = y.right!
    }

    if (y === tree.root) {
        tree.root = x

        // if x is null, we are removing the only node
        x.color = .black
        z.detach()
        resetSentinel()
        tree.root.parent = TreeNode.SENTINEL

        return
    }

    let yWasRed = (y.color == .red)

    if (y === y.parent!.left) {
        y.parent!.left = x
    } else {
        y.parent!.right = x
    }

    if (y === z) {
        x.parent = y.parent
        recomputeTreeMetadata(tree, x)
    } else {
        if (y.parent === z) {
            x.parent = y
        } else {
            x.parent = y.parent
        }

        // as we make changes to x's hierarchy, update size_left of subtree first
        recomputeTreeMetadata(tree, x)

        y.left = z.left
        y.right = z.right
        y.parent = z.parent
        y.color = z.color

        if (z === tree.root) {
            tree.root = y
        } else {
            if (z === z.parent!.left) {
                z.parent!.left = y
            } else {
                z.parent!.right = y
            }
        }

        if (y.left !== TreeNode.SENTINEL) {
            y.left!.parent = y
        }
        if (y.right !== TreeNode.SENTINEL) {
            y.right!.parent = y
        }
        // update metadata
        // we replace z with y, so in this sub tree, the length change is z.item.length
        y.size_left = z.size_left
        y.lf_left = z.lf_left
        recomputeTreeMetadata(tree, y)
    }

    z.detach();

    if (x.parent!.left === x) {
        let newSizeLeft = calculateSize(x)
        let newLFLeft = calculateLF(x)
        if (newSizeLeft != x.parent!.size_left || newLFLeft != x.parent!.lf_left) {
            let delta = newSizeLeft - x.parent!.size_left
            let lf_delta = newLFLeft - x.parent!.lf_left
            x.parent!.size_left = newSizeLeft
            x.parent!.lf_left = newLFLeft
            updateTreeMetadata(tree, x.parent!, delta, lf_delta)
        }
    }

    recomputeTreeMetadata(tree, x.parent!)

    if (yWasRed) {
        resetSentinel()
        return
    }

    // RB-DELETE-FIXUP
    var w: TreeNode
    while (x !== tree.root && x.color == .black) {
        if (x === x.parent!.left) {
            w = x.parent!.right!

            if (w.color == .red) {
                w.color = .black
                x.parent!.color = .red
                leftRotate(tree, x.parent!)
                w = x.parent!.right!
            }

            if (w.left!.color == .black && w.right!.color == .black) {
                w.color = .red
                x = x.parent!
            } else {
                if (w.right!.color == .black) {
                    w.left!.color = .black
                    w.color = .red
                    rightRotate(tree, w)
                    w = x.parent!.right!
                }

                w.color = x.parent!.color
                x.parent!.color = .black
                w.right!.color = .black
                leftRotate(tree, x.parent!)
                x = tree.root
            }
        } else {
            w = x.parent!.left!

            if (w.color == .red) {
                w.color = .black
                x.parent!.color = .red
                rightRotate(tree, x.parent!)
                w = x.parent!.left!
            }

            if (w.left!.color == .black && w.right!.color == .black) {
                w.color = .red
                x = x.parent!

            } else {
                if (w.left!.color == .black) {
                    w.right!.color = .black
                    w.color = .red
                    leftRotate(tree, w)
                    w = x.parent!.left!
                }

                w.color = x.parent!.color
                x.parent!.color = .black
                w.left!.color = .black
                rightRotate(tree, x.parent!)
                x = tree.root
            }
        }
    }
    x.color = .black
    resetSentinel()
}

func fixInsert(_ tree: PieceTreeBase,  _ _x: TreeNode) {
    var x = _x
    recomputeTreeMetadata(tree, x)

    while (x !== tree.root && x.parent!.color == .red) {
        if (x.parent === x.parent!.parent!.left) {
            let y = x.parent!.parent!.right!

            if (y.color == .red) {
                x.parent!.color = .black
                y.color = .black
                x.parent!.parent!.color = .red
                x = x.parent!.parent!
            } else {
                if (x === x.parent!.right) {
                    x = x.parent!
                    leftRotate(tree, x)
                }

                x.parent!.color = .black
                x.parent!.parent!.color = .red
                rightRotate(tree, x.parent!.parent!)
            }
        } else {
            let y = x.parent!.parent!.left!

            if (y.color == .red) {
                x.parent!.color = .black
                y.color = .black
                x.parent!.parent!.color = .red
                x = x.parent!.parent!
            } else {
                if (x === x.parent!.left) {
                    x = x.parent!
                    rightRotate(tree, x)
                }
                x.parent!.color = .black
                x.parent!.parent!.color = .red
                leftRotate(tree, x.parent!.parent!)
            }
        }
    }

    tree.root.color = .black
}

func updateTreeMetadata(_ tree: PieceTreeBase, _ _x: TreeNode, _ delta: Int, _ lineFeedCountDelta: Int) {
    var x = _x
    // node length change or line feed count change
    while (x !== tree.root && x !== TreeNode.SENTINEL) {
        if (x.parent!.left === x) {
            x.parent!.size_left += delta
            x.parent!.lf_left += lineFeedCountDelta
        }

        x = x.parent!
    }
}

func recomputeTreeMetadata(_ tree: PieceTreeBase, _ _x: TreeNode) {
    var x = _x
    var delta = 0
    var lf_delta = 0;
    if (x === tree.root) {
        return;
    }

    if (delta == 0) {
        // go upwards till the node whose left subtree is changed.
        while (x !== tree.root && x === x.parent!.right) {
            x = x.parent!
        }

        if (x === tree.root) {
            // well, it means we add a node to the end (inorder)
            return
        }

        // x is the node whose right subtree is changed.
        x = x.parent!

        delta = calculateSize(x.left!) - x.size_left
        lf_delta = calculateLF(x.left!) - x.lf_left
        x.size_left += delta
        x.lf_left += lf_delta
    }

    // go upwards till root. O(logN)
    while (x !== tree.root && (delta != 0 || lf_delta != 0)) {
        if (x.parent!.left === x) {
            x.parent!.size_left += delta
            x.parent!.lf_left += lf_delta
        }

        x = x.parent!
    }
}
