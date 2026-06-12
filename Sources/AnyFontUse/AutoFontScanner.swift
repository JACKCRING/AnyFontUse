import Foundation
import CoreText
import CoreGraphics

/// 单个字体文件被解析出的元信息。
struct ScannedFont: Sendable, Hashable {
    let url: URL
    let postScriptName: String
    let familyName: String
    let weight: AnyFontWeight
    let isItalic: Bool
}

/// 自动扫描 `Bundle` 内的字体文件，提取字族 / 权重 / 斜体信息。
///
/// 识别策略（按可信度从高到低）：
/// 1. 读 OS/2 表的 `usWeightClass`（直接给出 100~1000，最权威，对齐 CSS）。
/// 2. 字体 PostScript 名里的关键字（`Thin`, `Bold`, `ExtraBold`...）。
/// 3. CoreText 的 `kCTFontWeightTrait`（−1.0 ~ 1.0 的归一值）。
enum AutoFontScanner {

    static let supportedExtensions = ["ttf", "otf", "ttc", "otc"]

    /// 扫描指定 bundle 下所有支持的字体文件。
    static func scan(bundle: Bundle) -> [ScannedFont] {
        var urls: Set<URL> = []
        for ext in supportedExtensions {
            if let found = bundle.urls(forResourcesWithExtension: ext, subdirectory: nil) {
                urls.formUnion(found)
            }
        }
        return urls.flatMap { describe(at: $0) }
    }

    /// 解析单个字体文件（TTC/OTC 可能含多个字体）。
    static func describe(at url: URL) -> [ScannedFont] {
        guard let array = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
              !array.isEmpty else {
            return []
        }
        // OS/2 表只能从整文件读到一份；多 face 时回退到 trait
        let usWeightClass = readUsWeightClass(url: url)
        return array.compactMap { describe(descriptor: $0, url: url, usWeightClass: usWeightClass, faceCount: array.count) }
    }

    private static func describe(
        descriptor: CTFontDescriptor,
        url: URL,
        usWeightClass: Int?,
        faceCount: Int
    ) -> ScannedFont? {
        let psName = (CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String)
            ?? url.deletingPathExtension().lastPathComponent
        let familyName = (CTFontDescriptorCopyAttribute(descriptor, kCTFontFamilyNameAttribute) as? String)
            ?? psName

        let traits = (CTFontDescriptorCopyAttribute(descriptor, kCTFontTraitsAttribute) as? [String: Any]) ?? [:]
        let traitWeight = (traits[kCTFontWeightTrait as String] as? CGFloat) ?? 0
        let slant = (traits[kCTFontSlantTrait as String] as? CGFloat) ?? 0
        let symbolic = (traits[kCTFontSymbolicTrait as String] as? UInt32) ?? 0
        let isItalic = abs(slant) > 0.05
            || (symbolic & UInt32(CTFontSymbolicTraits.italicTrait.rawValue)) != 0
            || psName.lowercased().contains("italic")
            || psName.lowercased().contains("oblique")

        // 优先级：usWeightClass（OS/2 表，字体自己声明的 CSS 权重，最权威）
        //       > PostScript 名字关键字
        //       > CoreText weight trait
        let weight: AnyFontWeight
        if faceCount == 1, let cls = usWeightClass {
            weight = AnyFontWeight(cls)
        } else if let nameWeight = parseWeightFromName(psName) {
            weight = nameWeight
        } else {
            weight = AnyFontWeight(mapTraitToCSSWeight(traitWeight))
        }

        return ScannedFont(
            url: url,
            postScriptName: psName,
            familyName: familyName,
            weight: weight,
            isItalic: isItalic
        )
    }

    // MARK: - OS/2 usWeightClass

    private static func readUsWeightClass(url: URL) -> Int? {
        guard let provider = CGDataProvider(url: url as CFURL),
              let cgFont = CGFont(provider) else { return nil }
        // 'O''S''/''2' = 0x4F532F32
        let tag: UInt32 = 0x4F_53_2F_32
        guard let table = cgFont.table(for: tag) as Data? else { return nil }
        guard table.count >= 6 else { return nil }
        let value: UInt16 = table.withUnsafeBytes { ptr in
            UInt16(bigEndian: ptr.load(fromByteOffset: 4, as: UInt16.self))
        }
        let v = Int(value)
        return (v > 0 && v <= 1000) ? v : nil
    }

    // MARK: - PostScript 名字关键字解析

    /// 注意：必须按「更长 / 更具体」的关键字优先匹配，避免 "ExtraBold" 被 "Bold" 抢先。
    /// 命名遵循 CSS 标准：Thin=100, ExtraLight=200, Light=300, ..., Black=900。
    private static let nameMappings: [(String, AnyFontWeight)] = [
        ("ultralight", .ultraLight),    // 100
        ("ultrathin",  .ultraLight),    // 100
        ("hairline",   .ultraLight),    // 100
        ("extralight", .thin),          // 200
        ("extrathin",  .ultraLight),    // 100
        ("demibold",   .semibold),      // 600
        ("semibold",   .semibold),      // 600
        ("extrabold",  .heavy),         // 800
        ("ultrabold",  .heavy),         // 800
        ("medium",     .medium),        // 500
        ("regular",    .regular),       // 400
        ("normal",     .regular),       // 400
        ("book",       .regular),       // 400
        ("light",      .light),         // 300
        ("heavy",      .heavy),         // 800
        ("black",      .black),         // 900
        ("thin",       .ultraLight),    // 100（CSS 标准；Apple 系命名认为是 200，但 OS/2 表会先一步覆盖此判断）
        ("bold",       .bold),          // 700
    ]

    private static func parseWeightFromName(_ name: String) -> AnyFontWeight? {
        let lower = name.lowercased()
        for (keyword, weight) in nameMappings where lower.contains(keyword) {
            return weight
        }
        return nil
    }

    // MARK: - CoreText weight trait → CSS

    private static let traitAnchors: [(CGFloat, Int)] = [
        (-0.8, 100), (-0.6, 200), (-0.4, 300),
        ( 0.0, 400), ( 0.23, 500), ( 0.3, 600),
        ( 0.4, 700), ( 0.56, 800), ( 0.62, 900),
    ]

    private static func mapTraitToCSSWeight(_ trait: CGFloat) -> Int {
        traitAnchors.min(by: { abs($0.0 - trait) < abs($1.0 - trait) })?.1 ?? 400
    }
}
