import SwiftUI

// MARK: - Environment

private struct AnyFontFamilyEnvironmentKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

public extension EnvironmentValues {
    /// 当前视图层默认使用的字族。`anyFontUse(...)` 没显式传 `family:` 时会读它。
    var anyFontFamily: String? {
        get { self[AnyFontFamilyEnvironmentKey.self] }
        set { self[AnyFontFamilyEnvironmentKey.self] = newValue }
    }
}

public extension View {
    /// 把当前视图子树默认的字族切到指定字族。
    ///
    /// 优先级（从高到低）：
    /// 1. `anyFontUse(..., family: "...")` 显式传入；
    /// 2. 视图链上最近一次 `.anyFontFamily("...")`；
    /// 3. `AnyFontManager.shared.defaultFamily`。
    ///
    /// 用法示例：
    /// ```swift
    /// VStack {
    ///     Text("正文").anyFontUse(size: 16)                                   // Inter
    ///     Text("代码").anyFontUse(size: 16, family: "JetBrains Mono")          // 局部覆盖
    /// }
    /// .anyFontFamily("Inter")
    /// ```
    func anyFontFamily(_ family: String?) -> some View {
        environment(\.anyFontFamily, family)
    }
}

// MARK: - Modifier

/// SwiftUI 修饰符：根据已注册的字体，按权重渲染指定字号的文本。
public struct AnyFontUseModifier: ViewModifier {

    let size: CGFloat
    let weight: AnyFontWeight
    let family: String?

    @Environment(\.anyFontFamily) private var environmentFamily

    public func body(content: Content) -> some View {
        let resolvedFamily = family ?? environmentFamily
        if let psName = AnyFontManager.shared.postScriptName(for: weight, family: resolvedFamily) {
            content.font(.custom(psName, size: size))
        } else {
            // 没有注册自定义字体时，回退到系统字体并保留权重。
            content.font(.system(size: size).weight(weight.systemWeight))
        }
    }
}

public extension View {

    /// 应用「任意自定义字体」。
    ///
    /// - Parameters:
    ///   - size:   字号（pt）。
    ///   - weight: 权重，支持数值字面量（如 `100`）或语义命名（如 `.thin`）。默认 `.regular`。
    ///   - family: 指定字族；为空时按视图链上的 `.anyFontFamily(...)` → `AnyFontManager.shared.defaultFamily` 顺序解析。
    ///
    /// ```swift
    /// Text("hello").anyFontUse(size: 24, weight: 100)
    /// Text("hello").anyFontUse(size: 24, weight: .thin)
    /// Text("hello").anyFontUse(size: 24, weight: .bold, family: "Inter")
    /// ```
    func anyFontUse(
        size: CGFloat,
        weight: AnyFontWeight = .regular,
        family: String? = nil
    ) -> some View {
        modifier(AnyFontUseModifier(size: size, weight: weight, family: family))
    }
}
