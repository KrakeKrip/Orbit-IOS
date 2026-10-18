import Testing
@testable import OrbitCore

@Test func timelineEdgeScrollRampsAndClamps() {
    func tick(_ y: Double, _ offset: Double = 100) -> Double {
        TaskTimelineAutoScroll.offset(current: offset, pointer: y, viewport: 600, minimum: 0, maximum: 1000)
    }
    #expect(tick(300) == 100)
    #expect(tick(0) == 96)
    #expect(tick(28) == 98)
    #expect(tick(600) == 104)
    #expect(tick(572) == 102)
    #expect(tick(-100, 0) == 0)
    #expect(tick(700, 1000) == 1000)
    #expect(TaskTimelineAutoScroll.offset(current: 12, pointer: .nan, viewport: 600, minimum: 0, maximum: 100) == 12)
}
