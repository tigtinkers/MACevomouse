import Foundation
import MACEvoCore

#if os(Linux)
import Glibc
#else
import Darwin
#endif

enum CLIError: Error, LocalizedError {
    case usage(String)

    var errorDescription: String? {
        switch self {
        case .usage(let message): return message
        }
    }
}

func usage() -> String {
    """
    Usage:
      macevo-cli replay <fixture.json>
      macevo-cli validate <fixture.json>

    Replays a versioned fixture into action intents. This tool never captures or
    injects operating-system input. Fixtures with source other than synthetic are
    rejected unless a future, explicitly reviewed diagnostic mode is added.
    """
}

func run(arguments: [String]) throws {
    guard arguments.count == 3 else { throw CLIError.usage(usage()) }
    let command = arguments[1]
    let url = URL(fileURLWithPath: arguments[2])
    let fixture = try FixtureReplay.load(from: url)
    try fixture.validate()
    guard fixture.source == .synthetic else {
        throw CLIError.usage("Only explicitly synthetic fixtures are accepted by the Linux replay CLI.\n\n\(usage())")
    }

    switch command {
    case "validate":
        print("valid synthetic fixture: \(fixture.label) (\(fixture.events.count) events)")
    case "replay":
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        for intent in try FixtureReplay.replay(fixture) {
            print(String(decoding: try encoder.encode(intent), as: UTF8.self))
        }
    default:
        throw CLIError.usage(usage())
    }
}

do {
    try run(arguments: CommandLine.arguments)
} catch {
    FileHandle.standardError.write(Data("macevo-cli: \(error.localizedDescription)\n".utf8))
    exit(2)
}
