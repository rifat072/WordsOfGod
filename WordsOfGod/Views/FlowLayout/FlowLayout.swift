//
//  FlowLayout.swift
//  WordsOfGod
//
//  Created by Rifat on 21/10/26.
//

import SwiftUI

struct FlowLayout: Layout {
    var hSpacing: CGFloat = 8
    var vSpacing: CGFloat = 8
    var centersRows = false

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal.width ?? .infinity, subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let points = arrange(bounds.width, subviews).points
        for (index, point) in points.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y),
                                  proposal: .unspecified)
        }
    }

    private func arrange(_ maxWidth: CGFloat, _ subviews: Subviews) -> (points: [CGPoint], size: CGSize) {
        var rows: [[(index: Int, size: CGSize)]] = [[]]
        var rowWidth: CGFloat = 0
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth > 0, rowWidth + size.width > maxWidth {
                rows.append([])
                rowWidth = 0
            }
            rows[rows.count - 1].append((index, size))
            rowWidth += size.width + hSpacing
        }

        let widths = rows.map { row in row.reduce(0) { $0 + $1.size.width } + hSpacing * CGFloat(max(row.count - 1, 0)) }
        let usedWidth = widths.max() ?? 0
        let containerWidth = maxWidth.isFinite ? maxWidth : usedWidth

        var points = Array(repeating: CGPoint.zero, count: subviews.count)
        var y: CGFloat = 0
        for (row, width) in zip(rows, widths) {
            var x = centersRows ? (containerWidth - width) / 2 : 0
            let rowHeight = row.map(\.size.height).max() ?? 0
            for item in row {
                points[item.index] = CGPoint(x: x, y: y + (rowHeight - item.size.height) / 2)
                x += item.size.width + hSpacing
            }
            y += rowHeight + vSpacing
        }
        return (points, CGSize(width: centersRows ? containerWidth : usedWidth, height: max(y - vSpacing, 0)))
    }
}
