import CoreGraphics
import Foundation

/// 하루 기록 증상 그래프의 칸 배치·칸 글자 단계·칸 테두리 색 (Figma '하루 기록 · 통증 점수 — 개발 전달' 6·7·8번).
/// 글자 폭은 화면이 재서 넘겨 줍니다 (이 계산은 글꼴을 모릅니다).
nonisolated enum RecordSymptomTreemap {
    /// 칸 글자 6단계. 크기는 디자인 시스템 텍스트 사다리 값만 씁니다.
    /// a~d: 이름 위·횟수 아래, e: 이름과 횟수를 한 줄에, f: 이름만 (마지막 수단)
    enum Tier: Int, CaseIterable, Comparable {
        case a, b, c, d, e, f
        var nameSize: CGFloat { [28, 24, 20, 16, 12, 12][rawValue] }
        var nameLineHeight: CGFloat { [36, 32, 28, 24, 16, 16][rawValue] }
        /// 따로 그리는 횟수 줄 (e·f는 없음)
        var countSize: CGFloat? { [20, 16, 14, 12, nil, nil][rawValue] }
        var countLineHeight: CGFloat { [28, 24, 20, 16, 0, 0][rawValue] }
        var score: Int { [0, 1, 2, 3, 6, 30][rawValue] }
        static func < (lhs: Tier, rhs: Tier) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    struct Label {
        let name: String
        /// 일은 횟수가 없습니다
        let count: String?
        /// e 단계 한 줄 글자
        var inline: String { count.map { "\(name)  \($0)" } ?? name }
    }

    struct Cell: Equatable {
        let rect: CGRect
        let tier: Tier
    }

    /// 글자 폭 재기: (글자, 크기, 굵게)
    typealias Measure = (String, CGFloat, Bool) -> CGFloat

    static let minimumCell = CGSize(width: 60, height: 36)
    static let countSpacing: CGFloat = 3

    /// weights는 많은 순으로 받습니다. 결과는 받은 순서 그대로입니다.
    /// (가) 넓이 비례 그대로와 (나) 최소 칸 60×36 보장을 둘 다 계산해 글자 단계 점수 합이 작은 쪽을 씁니다 (같으면 가).
    static func layout(weights: [Double], labels: [Label], in size: CGSize, measure: Measure) -> [Cell] {
        guard !weights.isEmpty, weights.count == labels.count, size.width > 0, size.height > 0 else { return [] }
        let bounds = CGRect(origin: .zero, size: size)
        let plain = squarify(weights, in: bounds)
        var bumped = weights, guarded = plain
        for _ in 0..<30 {
            let small = guarded.indices.filter {
                guarded[$0].width < minimumCell.width - 0.001 || guarded[$0].height < minimumCell.height - 0.001
            }
            if small.isEmpty { break }
            for index in small { bumped[index] *= 1.12 }
            guarded = squarify(bumped, in: bounds)
        }
        let plainTiers = tiers(plain, labels, measure)
        let guardedTiers = tiers(guarded, labels, measure)
        let score = { (tiers: [Tier]) in tiers.reduce(0) { $0 + $1.score } }
        let (rects, chosen) = score(guardedTiers) < score(plainTiers) ? (guarded, guardedTiers) : (plain, plainTiers)
        return zip(rects, chosen).map { Cell(rect: $0, tier: $1) }
    }

    /// 넓이 비례 타일링 (squarified treemap). 짧은 변을 따라 한 줄씩 채우고, 칸이 더 길쭉해지면 다음 줄로 넘깁니다.
    static func squarify(_ weights: [Double], in rect: CGRect) -> [CGRect] {
        let total = weights.reduce(0, +)
        guard total > 0 else { return weights.map { _ in .zero } }
        let areas = weights.map { $0 * Double(rect.width * rect.height) / total }
        var result: [CGRect] = []
        var remaining = rect
        var row: [Double] = []
        var index = 0
        while index < areas.count {
            let side = Double(min(remaining.width, remaining.height))
            if row.isEmpty || worst(row + [areas[index]], side: side) <= worst(row, side: side) {
                row.append(areas[index]); index += 1
            } else {
                result += place(row, in: &remaining); row = []
            }
        }
        return result + place(row, in: &remaining)
    }

    /// 줄 안에서 가장 길쭉한 칸의 비율 (1이 정사각형)
    private static func worst(_ row: [Double], side: Double) -> Double {
        let sum = row.reduce(0, +)
        return row.map { max(side * side * $0 / (sum * sum), sum * sum / (side * side * $0)) }.max() ?? .infinity
    }

    /// 넓은 쪽이 가로면 왼쪽에 세로 줄, 세로면 위에 가로 줄로 놓고 남은 자리를 줄입니다.
    private static func place(_ row: [Double], in remaining: inout CGRect) -> [CGRect] {
        let sum = row.reduce(0, +)
        guard sum > 0 else { return [] }
        var rects: [CGRect] = []
        if remaining.width >= remaining.height {
            let width = CGFloat(sum) / remaining.height
            var y = remaining.minY
            for area in row {
                let height = CGFloat(area) / width
                rects.append(CGRect(x: remaining.minX, y: y, width: width, height: height)); y += height
            }
            remaining = CGRect(x: remaining.minX + width, y: remaining.minY, width: max(remaining.width - width, 0), height: remaining.height)
        } else {
            let height = CGFloat(sum) / remaining.width
            var x = remaining.minX
            for area in row {
                let width = CGFloat(area) / height
                rects.append(CGRect(x: x, y: remaining.minY, width: width, height: height)); x += width
            }
            remaining = CGRect(x: remaining.minX, y: remaining.minY + height, width: remaining.width, height: max(remaining.height - height, 0))
        }
        return rects
    }

    /// 1) 칸마다 이름과 횟수가 둘 다 들어가는 첫 단계
    /// 2) 작은 칸이 큰 칸보다 큰 글씨를 쓰지 않게: 넓이가 더 큰 칸들이 쓴 가장 작은 단계보다 큰 단계를 막습니다.
    ///    넓이가 같은 칸끼리는 서로 막지 않습니다 (Figma 시안: 증상 5개의 식욕부진 87×150은 c, 피부발진 145×90은 a)
    static func tiers(_ rects: [CGRect], _ labels: [Label], _ measure: Measure) -> [Tier] {
        let fitted = zip(rects, labels).map { rect, label in
            Tier.allCases.first { fits(label, $0, in: rect.size, measure) } ?? .f
        }
        var tiers = fitted
        let areas = rects.map { $0.width * $0.height }
        for index in rects.indices {
            let larger = rects.indices.filter { areas[$0] > areas[index] + 0.5 }
            tiers[index] = ([fitted[index]] + larger.map { fitted[$0] }).max() ?? fitted[index]
        }
        return tiers
    }

    /// 재는 폭은 칸 폭 − 12, 재는 높이는 칸 높이 − 10
    static func fits(_ label: Label, _ tier: Tier, in size: CGSize, _ measure: Measure) -> Bool {
        let width = size.width - 12, height = size.height - 10
        switch tier {
        case .e: return measure(label.inline, tier.nameSize, true) <= width && tier.nameLineHeight <= height
        case .f: return measure(label.name, tier.nameSize, true) <= width && tier.nameLineHeight <= height
        default:
            let countFits = label.count.map { measure($0, tier.countSize ?? 0, false) <= width } ?? true
            let needed = tier.nameLineHeight + (label.count == nil ? 0 : countSpacing + tier.countLineHeight)
            return measure(label.name, tier.nameSize, true) <= width && countFits && needed <= height
        }
    }

    // MARK: - 테두리

    typealias RGB = (red: Double, green: Double, blue: Double)

    /// 칸 색에서 oklch로 위쪽(밝기 +6, 선명함 ×0.60)·아래쪽(밝기 −8, 선명함 ×1.05) 테두리 색을 만듭니다. 8색 모두 같은 값입니다.
    static func border(of fill: RGB) -> (top: RGB, bottom: RGB) {
        (adjust(fill, lightness: 0.06, chroma: 0.60), adjust(fill, lightness: -0.08, chroma: 1.05))
    }

    private static func adjust(_ color: RGB, lightness: Double, chroma: Double) -> RGB {
        let (l, a, b) = oklab(color)
        return srgb(l + lightness, a * chroma, b * chroma)
    }

    private static func oklab(_ color: RGB) -> (Double, Double, Double) {
        let (r, g, b) = (linear(color.red), linear(color.green), linear(color.blue))
        let l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
        let m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
        let s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
        return (0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
                1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
                0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)
    }

    /// 화면에 없는 색은 채널마다 0~1로 자릅니다
    private static func srgb(_ lightness: Double, _ a: Double, _ b: Double) -> RGB {
        let l = pow(lightness + 0.3963377774 * a + 0.2158037573 * b, 3)
        let m = pow(lightness - 0.1055613458 * a - 0.0638541728 * b, 3)
        let s = pow(lightness - 0.0894841775 * a - 1.2914855480 * b, 3)
        let channel = { (value: Double) in gamma(min(max(value, 0), 1)) }
        return (channel(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
                channel(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
                channel(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s))
    }

    private static func linear(_ value: Double) -> Double {
        value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }

    private static func gamma(_ value: Double) -> Double {
        value <= 0.0031308 ? 12.92 * value : 1.055 * pow(value, 1 / 2.4) - 0.055
    }
}
