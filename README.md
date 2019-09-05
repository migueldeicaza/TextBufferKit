TextBufferKit - a port of the vscode-textbuffer code to Swift

Documented here:

https://code.visualstudio.com/blogs/2018/03/23/text-buffer-reimplementation

Based on the code here:

https://github.com/Microsoft/vscode-textbuffer

Plus the VSCode extensions, that include a higher-level API, and the text matching:

https://github.com/Microsoft/vscode

One significant difference from the original implementation is that
this uses bytes rather than characters for storage, so it is necessary
to create strings and characters out of the UTF8 representation.xs