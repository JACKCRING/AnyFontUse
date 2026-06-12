import Foundation
import SwiftUI

/// 字体权重值，参考 CSS font-weight 设计：取值通常在 1 ~ 1000 之间。
///
/// 同时支持两种写法：
///
/// ```swift
/// Text("hi").anyFontUse(size: 24, weight: 100)   // 数值字面量
/// Text("hi").anyFontUse(size: 24, weight: .thin) // 语义命名
/// ```
public struct AnyFontWeight: Sendable, Hashable, ExpressibleByIntegerLiteral, CustomStringConvertible {

    /// 数值（建议 1 ~ 1000，参考 CSS font-weight）。
    public let rawValue: Int

    public init(_ rawValue: Int) {
        self.rawValue = rawValue
    }

    public init(integerLiteral value: Int) {
        self.rawValue = value
    }

    public var description: String { "AnyFontWeight(\(rawValue))" }

    // MARK: - 命名权重（与 CSS / SwiftUI Font.Weight 对齐）

    public static let ultraLight = AnyFontWeight(100)
    public static let thin       = AnyFontWeight(200)
    public static let light      = AnyFontWeight(300)
    public static let regular    = AnyFontWeight(400)
    public static let medium     = AnyFontWeight(500)
    public static let semibold   = AnyFontWeight(600)
    public static let bold       = AnyFontWeight(700)
    public static let heavy      = AnyFontWeight(800)
    public static let black      = AnyFontWeight(900)

    /// 映射到 SwiftUI 的 `Font.Weight`，作为系统字体回退用。
    public var systemWeight: Font.Weight {
        switch rawValue {
        case ..<150: return .ultraLight
        case ..<250: return .thin
        case ..<350: return .light
        case ..<450: return .regular
        case ..<550: return .medium
        case ..<650: return .semibold
        case ..<750: return .bold
        case ..<850: return .heavy
        default:     return .black
        }
    }
}
