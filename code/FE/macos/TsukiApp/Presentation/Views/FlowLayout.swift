import SwiftUI

struct FlowLayout: Layout {
    let spacing: CGFloat
    let rowSpacing: CGFloat

    init(spacing: CGFloat, rowSpacing: CGFloat) {
        self.spacing = spacing
        self.rowSpacing = rowSpacing
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let bounds = computeRows(proposal: proposal, subviews: subviews)
        return CGSize(width: proposal.width ?? bounds.width, height: bounds.height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let rows = computeRows(proposal: ProposedViewSize(width: bounds.width, height: proposal.height), subviews: subviews)

        for row in rows.rows {
            for element in row.elements {
                subviews[element.index].place(
                    at: CGPoint(x: bounds.minX + element.origin.x, y: bounds.minY + element.origin.y),
                    proposal: ProposedViewSize(element.size)
                )
            }
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> FlowRows {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude

        var rows: [FlowRow] = []
        var current = FlowRow(elements: [], width: 0, height: 0)
        var y: CGFloat = 0

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let predicted = current.elements.isEmpty ? size.width : current.width + spacing + size.width

            if predicted > maxWidth, current.elements.isEmpty == false {
                rows.append(current)
                y += current.height + rowSpacing
                current = FlowRow(elements: [], width: 0, height: 0)
            }

            let originX = current.elements.isEmpty ? 0 : current.width + spacing
            current.elements.append(FlowElement(index: index, origin: CGPoint(x: originX, y: y), size: size))
            current.width = originX + size.width
            current.height = max(current.height, size.height)
        }

        if !current.elements.isEmpty {
            rows.append(current)
        }

        let totalHeight = rows.enumerated().reduce(CGFloat.zero) { partial, pair in
            let row = pair.element
            return partial + row.height + (pair.offset == rows.count - 1 ? 0 : rowSpacing)
        }

        let totalWidth = rows.map(\ .width).max() ?? 0
        return FlowRows(rows: rows, width: totalWidth, height: totalHeight)
    }
}

private struct FlowRows {
    let rows: [FlowRow]
    let width: CGFloat
    let height: CGFloat
}

private struct FlowRow {
    var elements: [FlowElement]
    var width: CGFloat
    var height: CGFloat
}

private struct FlowElement {
    let index: Int
    let origin: CGPoint
    let size: CGSize
}
