import Foundation

/// 描述一个字体文件资源。
///
/// - `fileName`：不带扩展名的文件名（如 `"Inter-Thin"`）。
/// - `fileExtension`：扩展名，常见为 `"ttf"` 或 `"otf"`。
/// - `postScriptName`：传入字体的 PostScript 名（SwiftUI `.custom` 实际用的就是它）。
///   留空时会在注册时自动从字体文件里嗅探。
public struct AnyFontResource: Sendable, Hashable {

    public let fileName: String
    public let fileExtension: String
    public let postScriptName: String?

    public init(
        fileName: String,
        fileExtension: String = "ttf",
        postScriptName: String? = nil
    ) {
        self.fileName = fileName
        self.fileExtension = fileExtension
        self.postScriptName = postScriptName
    }
}
