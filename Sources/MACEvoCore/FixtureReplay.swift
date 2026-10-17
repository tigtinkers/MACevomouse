import Foundation

public enum FixtureReplay {
    public static func replay(_ fixture: FixtureDocument) throws -> [ActionIntent] {
        try fixture.validate()
        var engine = try RuleEngine(configuration: fixture.configuration)
        var intents: [ActionIntent] = []
        for event in fixture.events {
            intents.append(contentsOf: try engine.process(event))
        }
        return intents
    }

    public static func load(from url: URL) throws -> FixtureDocument {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(FixtureDocument.self, from: data)
    }
}
