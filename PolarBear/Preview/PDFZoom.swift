//
//  PDFZoom.swift
//  PolarBear
//

import Foundation

/// How large the PDF is shown: fitted to the panel's width, or a fixed percentage.
enum PDFZoom: Hashable {
    case fit
    case percent(Int)

    static let presets = [50, 75, 100, 125, 150, 200, 400]
    private static let steps = [25, 50, 75, 100, 125, 150, 200, 300, 400, 500]

    init(percent: Int?) {
        self = percent.map { .percent($0) } ?? .fit
    }

    var percent: Int? {
        if case .percent(let value) = self { value } else { nil }
    }

    /// The next larger step, starting from `current` percent (the live scale when fitted).
    static func larger(than current: Int) -> PDFZoom {
        .percent(steps.first { $0 > current } ?? steps[steps.count - 1])
    }

    static func smaller(than current: Int) -> PDFZoom {
        .percent(steps.last { $0 < current } ?? steps[0])
    }
}
