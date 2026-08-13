import Arguments
import Foundation
import Media

enum InspectCommand:
    RunnableArgumentCommand
{
    static let name = "inspect"

    static func components() throws -> [CommandComponentLowerable] {
        [
            arg(
                "source",
                as: String.self,
                help: "Media file to inspect."
            ),
        ]
    }

    static func run(
        _ invocation: ParsedInvocation
    ) async throws {
        let source = try invocation.value(
            "source",
            as: String.self
        )

        guard let source else {
            throw InspectCommandError.missing_source
        }

        let url = URL(
            fileURLWithPath: NSString(
                string: source
            ).expandingTildeInPath
        )
        .standardizedFileURL

        let inspection = try await MediaAssetInspector().inspect(
            url
        )

        let encoder = JSONEncoder()

        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys,
            .withoutEscapingSlashes,
        ]

        let data = try encoder.encode(
            inspection
        )

        guard let output = String(
            data: data,
            encoding: .utf8
        ) else {
            throw InspectCommandError.encoding_failed
        }

        print(
            output
        )
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
