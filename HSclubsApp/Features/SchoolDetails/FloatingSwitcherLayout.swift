import CoreGraphics

enum FloatingSwitcherEdge: Sendable, Equatable {
    case leading
    case trailing
}

struct FloatingSwitcherLayout: Sendable, Equatable {
    let buttonSize: CGFloat
    let verticalMargin: CGFloat
    let tuckedOffset: CGFloat

    init(buttonSize: CGFloat = 54, verticalMargin: CGFloat = 24, tuckedOffset: CGFloat = 28) {
        self.buttonSize = buttonSize
        self.verticalMargin = verticalMargin
        self.tuckedOffset = tuckedOffset
    }

    func clampedCenterY(_ value: CGFloat, height: CGFloat) -> CGFloat {
        let minimum = buttonSize / 2 + verticalMargin
        let maximum = max(minimum, height - buttonSize / 2 - verticalMargin)
        return min(max(value, minimum), maximum)
    }

    func resolvedEdge(
        from edge: FloatingSwitcherEdge,
        translationX: CGFloat,
        width: CGFloat
    ) -> FloatingSwitcherEdge {
        let startingX = edge == .trailing ? width : 0
        return startingX + translationX >= width / 2 ? .trailing : .leading
    }

    func horizontalOffset(
        edge: FloatingSwitcherEdge,
        translationX: CGFloat,
        isExpanded: Bool
    ) -> CGFloat {
        guard !isExpanded else { return translationX }
        let outwardOffset = edge == .trailing ? tuckedOffset : -tuckedOffset
        return outwardOffset + translationX
    }
}
