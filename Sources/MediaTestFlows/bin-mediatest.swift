import TestFlows

@main
enum MediaTestFlowsMain {
    static func main() async {
        await TestFlowCLI.run(
            suite: MediaFlowSuite.self
        )
    }
}
