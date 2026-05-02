import Foundation

enum OllamaError: Error {
    case badStatus(Int)
    case parseError
}

/// Sends raw transcript to local Ollama for grammar fix + filler removal.
/// Optional — app works without it.
actor OllamaTransformer {
    private let base = URL(string: "http://localhost:11434")!
    private let model = "llama3.2:3b"

    private static let systemPrompt =
        "Clean the transcript. Fix grammar. Remove disfluencies (um, uh, like, you know, I mean). " +
        "Follow any formatting commands in the text (e.g. 'make this a list'). " +
        "Return ONLY the cleaned text — no preamble, no explanation."

    func isAvailable() async -> Bool {
        var req = URLRequest(url: base.appendingPathComponent("api/tags"))
        req.timeoutInterval = 2
        return (try? await URLSession.shared.data(for: req)) != nil
    }

    func clean(text: String) async throws -> String {
        var request = URLRequest(url: base.appendingPathComponent("api/generate"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": model,
            "prompt": text,
            "system": Self.systemPrompt,
            "stream": false
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(status) else { throw OllamaError.badStatus(status) }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["response"] as? String
        else { throw OllamaError.parseError }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
