import Foundation
import CoreText
import CoreGraphics

/// 集中管理项目中导入的字体：注册到系统、维护「字族 -> 权重 -> PostScript 名」的索引。
///
/// 默认开启 **自动模式**：把 `.ttf` / `.otf` 拖进 App target 后什么都不用配，
/// 第一次调用 `.anyFontUse(...)` 时库会自动扫描 `Bundle.main` 并完成注册。
///
/// 如需精细控制，调用 `register(family:weights:)` 显式注册；
/// 显式注册的条目优先级高于自动识别的同名条目。
public final class AnyFontManager: @unchecked Sendable {

    /// 全局共享实例。
    public static let shared = AnyFontManager()

    private let lock = NSLock()
    private var registry: [String: [Int: String]] = [:]   // family -> weight -> PostScript name
    private var registeredURLs: Set<URL> = []
    private var _defaultFamily: String?

    private var _autoBootstrapEnabled: Bool = true
    private var _autoBootstrapBundles: [Bundle] = [.main]
    private var _didAutoBootstrap: Bool = false

    private init() {}

    // MARK: - 默认字族

    /// 当 `anyFontUse` 不显式传入 `family:` 时使用的字族。
    /// 自动模式下，若用户没设置，会在 bootstrap 完成后自动选权重最丰富的字族。
    public var defaultFamily: String? {
        get { lock.withLock { _defaultFamily } }
        set { lock.withLock { _defaultFamily = newValue } }
    }

    // MARK: - 自动扫描配置

    /// 是否启用自动扫描。默认 `true`。需要在第一次查询字体之前设置才有效。
    public var autoBootstrapEnabled: Bool {
        get { lock.withLock { _autoBootstrapEnabled } }
        set { lock.withLock { _autoBootstrapEnabled = newValue } }
    }

    /// 自动扫描的 bundle 列表。默认 `[.main]`。
    /// 如果字体打包在某个 SPM 资源包里，可加入 `[.module]` 等。
    public var autoBootstrapBundles: [Bundle] {
        get { lock.withLock { _autoBootstrapBundles } }
        set { lock.withLock { _autoBootstrapBundles = newValue } }
    }

    /// 立即扫描指定 bundle 并把识别到的字体注册进来。可重复调用，重复字体会被忽略。
    /// 调用方一般不需要显式触发——首次使用 `anyFontUse(...)` 时库会自动调用。
    public func autoRegisterFonts(in bundle: Bundle = .main) {
        applyScannedFonts(AutoFontScanner.scan(bundle: bundle))
    }

    /// 内部使用：第一次查询字体时触发一次。
    func bootstrapIfNeeded() {
        let bundlesToScan: [Bundle] = lock.withLock {
            guard _autoBootstrapEnabled, !_didAutoBootstrap else { return [] }
            _didAutoBootstrap = true
            return _autoBootstrapBundles
        }
        guard !bundlesToScan.isEmpty else { return }
        for bundle in bundlesToScan {
            applyScannedFonts(AutoFontScanner.scan(bundle: bundle))
        }
    }

    // MARK: - 显式注册

    /// 注册一个字族，权重 -> 文件名（默认扩展名 `ttf`）。最常用的简易接口。
    public func register(
        family: String,
        weights: [AnyFontWeight: String],
        fileExtension: String = "ttf",
        bundle: Bundle = .main
    ) {
        let resources = weights.reduce(into: [AnyFontWeight: AnyFontResource]()) { acc, pair in
            acc[pair.key] = AnyFontResource(fileName: pair.value, fileExtension: fileExtension)
        }
        register(family: family, weights: resources, bundle: bundle)
    }

    /// 注册一个字族，权重 -> `AnyFontResource`，可以为不同权重指定不同扩展名 / PostScript 名。
    public func register(
        family: String,
        weights: [AnyFontWeight: AnyFontResource],
        bundle: Bundle = .main
    ) {
        var psMap: [Int: String] = [:]

        for (weight, resource) in weights {
            guard let url = bundle.url(
                forResource: resource.fileName,
                withExtension: resource.fileExtension
            ) else {
                print("[AnyFontUse] 找不到字体文件: \(resource.fileName).\(resource.fileExtension) in \(bundle)")
                continue
            }

            registerFontURLIfNeeded(url)

            let psName = resource.postScriptName
                ?? Self.detectPostScriptName(at: url)
                ?? resource.fileName
            psMap[weight.rawValue] = psName
        }

        lock.withLock {
            var existing = registry[family] ?? [:]
            for (k, v) in psMap { existing[k] = v }   // 显式注册覆盖已有条目
            registry[family] = existing
            if _defaultFamily == nil { _defaultFamily = family }
        }
    }

    /// 仅注册一个字体文件，不绑定字族 / 权重——适合只有单文件的场景。
    /// - Returns: 实际可用于 `Font.custom` 的 PostScript 名（注册失败时返回 nil）。
    @discardableResult
    public func registerSingleFont(
        fileName: String,
        fileExtension: String = "ttf",
        bundle: Bundle = .main
    ) -> String? {
        guard let url = bundle.url(forResource: fileName, withExtension: fileExtension) else {
            print("[AnyFontUse] 找不到字体文件: \(fileName).\(fileExtension)")
            return nil
        }
        registerFontURLIfNeeded(url)
        return Self.detectPostScriptName(at: url) ?? fileName
    }

    // MARK: - 查询

    /// 根据权重 + 字族获取最合适的 PostScript 名。
    /// 当传入权重未精确注册时，返回数值上最接近的已注册权重。
    public func postScriptName(
        for weight: AnyFontWeight,
        family: String? = nil
    ) -> String? {
        bootstrapIfNeeded()
        return lock.withLock {
            let resolvedFamily = family ?? _defaultFamily
            guard let resolvedFamily, let map = registry[resolvedFamily], !map.isEmpty else {
                return nil
            }
            if let exact = map[weight.rawValue] { return exact }
            let target = weight.rawValue
            let nearestKey = map.keys.min { abs($0 - target) < abs($1 - target) }
            return nearestKey.flatMap { map[$0] }
        }
    }

    /// 列出当前已注册的所有字族名。（会触发一次自动扫描）
    public var registeredFamilies: [String] {
        bootstrapIfNeeded()
        return lock.withLock { Array(registry.keys).sorted() }
    }

    /// 列出指定字族里已知的所有权重数值（升序）。
    public func registeredWeights(in family: String) -> [Int] {
        bootstrapIfNeeded()
        return lock.withLock {
            (registry[family] ?? [:]).keys.sorted()
        }
    }

    // MARK: - 内部

    /// 把扫描结果合入 registry。已存在的条目不会被覆盖（显式注册优先）。
    private func applyScannedFonts(_ scanned: [ScannedFont]) {
        // 当前版本暂不处理斜体；它们仍会被 CTFontManager 注册，可以通过 Font.custom 直接使用。
        for font in scanned {
            registerFontURLIfNeeded(font.url)
        }

        lock.withLock {
            for font in scanned where !font.isItalic {
                var map = registry[font.familyName] ?? [:]
                if map[font.weight.rawValue] == nil {
                    map[font.weight.rawValue] = font.postScriptName
                }
                registry[font.familyName] = map
            }
            // 默认字族：选权重最多的；并列时按字族名字典序最小。
            if _defaultFamily == nil, !registry.isEmpty {
                _defaultFamily = registry
                    .max { lhs, rhs in
                        if lhs.value.count != rhs.value.count {
                            return lhs.value.count < rhs.value.count
                        }
                        return lhs.key > rhs.key
                    }?.key
            }
        }
    }

    private func registerFontURLIfNeeded(_ url: URL) {
        let alreadyRegistered: Bool = lock.withLock { registeredURLs.contains(url) }
        guard !alreadyRegistered else { return }

        var error: Unmanaged<CFError>?
        let ok = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        if !ok {
            // 105 = kCTFontManagerErrorAlreadyRegistered，忽略即可
            if let cfError = error?.takeRetainedValue(),
               CFErrorGetCode(cfError) != 105 {
                print("[AnyFontUse] 字体注册失败 \(url.lastPathComponent): \(cfError)")
                return
            }
        }
        lock.withLock { _ = registeredURLs.insert(url) }
    }

    /// 从字体文件里读取 PostScript 名。
    private static func detectPostScriptName(at url: URL) -> String? {
        guard let provider = CGDataProvider(url: url as CFURL),
              let cgFont = CGFont(provider),
              let name = cgFont.postScriptName as String?
        else { return nil }
        return name
    }
}
