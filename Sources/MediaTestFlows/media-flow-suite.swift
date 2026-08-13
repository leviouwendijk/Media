import TestFlows

enum MediaFlowSuite: TestFlowRegistry {
    static let title = "Media"

    static let flows: [TestFlow] = [
        audioBufferFlow,
        pathFlow,
        avFlow,
        ltcFlow,
    ]
}
