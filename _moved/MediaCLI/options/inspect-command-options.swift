import Arguments
import Foundation

struct InspectCommandOptions:
    Sendable,
    ArgumentParsed
{
    typealias ArgumentPayload = Payload

    let source: URL

    init(
        arguments: Payload
    ) throws {
        guard let source = arguments.source,
              !source.isEmpty else {
            throw InspectCommandError.missing_source
        }

        self.source = URL(
            fileURLWithPath: NSString(
                string: source
            ).expandingTildeInPath
        )
        .standardizedFileURL
    }

    struct Payload:
        Sendable,
        ArgumentGroup
    {
        @Arg(
            "source",
            help: "Media file to inspect."
        )
        var source: String?

        init() {}
    }
}

enum InspectCommandError:
    Error,
    LocalizedError
{
    case missing_source
    case encoding_failed

    var errorDescription: String? {
        switch self {
        case .missing_source:
            return "Missing media source path."

        case .encoding_failed:
            return "Could not render media inspection as UTF-8 JSON."
        }
    }
}
