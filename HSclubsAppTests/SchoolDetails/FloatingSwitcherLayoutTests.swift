import Testing
@testable import HSclubs

struct FloatingSwitcherLayoutTests {
    private let layout = FloatingSwitcherLayout()

    @Test func clampsTheBallInsideVerticalMargins() {
        #expect(layout.clampedCenterY(-100, height: 800) == 51)
        #expect(layout.clampedCenterY(900, height: 800) == 749)
        #expect(layout.clampedCenterY(300, height: 800) == 300)
    }

    @Test func switchesEdgesOnlyAfterCrossingTheScreenMidpoint() {
        #expect(layout.resolvedEdge(from: .trailing, translationX: -100, width: 400) == .trailing)
        #expect(layout.resolvedEdge(from: .trailing, translationX: -250, width: 400) == .leading)
        #expect(layout.resolvedEdge(from: .leading, translationX: 100, width: 400) == .leading)
        #expect(layout.resolvedEdge(from: .leading, translationX: 250, width: 400) == .trailing)
    }

    @Test func tucksOutwardOnlyWhileCollapsed() {
        #expect(layout.horizontalOffset(edge: .trailing, translationX: 0, isExpanded: false) == 28)
        #expect(layout.horizontalOffset(edge: .leading, translationX: 0, isExpanded: false) == -28)
        #expect(layout.horizontalOffset(edge: .trailing, translationX: -40, isExpanded: false) == -12)
        #expect(layout.horizontalOffset(edge: .trailing, translationX: 0, isExpanded: true) == 0)
    }
}
