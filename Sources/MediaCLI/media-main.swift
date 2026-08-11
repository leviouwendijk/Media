import Arguments
import Media

@main
enum MediaCommand: ArgumentCommand {
    static let name = "media"
    static let defaultChild = Help.self

    static let children: [ArgumentCommandType] = [
        Help.self,
    ]

    enum Help: RunnableArgumentCommand {
        static let name = "help"

        static func run(
            _ invocation: ParsedInvocation
        ) async throws {
            print(
                ArgumentHelpRenderer().render(
                    command: try MediaCommand.spec()
                )
            )
        }
    }

    static func main() async {
        await ArgumentProgram.main(
            command: Self.self
        )
    }
}
