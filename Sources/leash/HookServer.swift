import Foundation
import Network

struct HookEvent {
    let ppid: Int32?
    let cwd: String?
    let message: String?
}

enum HookKind {
    case stop      // a turn finished
    case notify    // Claude needs input mid-turn (permission, idle wait)
    case submit    // the user sent a prompt
}

final class HookServer {
    private var listener: NWListener?
    private let onEvent: (HookKind, HookEvent) -> Void

    init(onEvent: @escaping (HookKind, HookEvent) -> Void) {
        self.onEvent = onEvent
    }

    func start(port: UInt16) throws {
        let params = NWParameters.tcp
        // Loopback only — never accept connections from the network.
        let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        listener.newConnectionHandler = { [weak self] conn in self?.handle(conn) }
        listener.stateUpdateHandler = { state in
            if case .failed(let error) = state {
                NSLog("leash: listener failed: \(error)")
            }
        }
        listener.start(queue: .global(qos: .userInitiated))
        self.listener = listener
        NSLog("leash: listening on 127.0.0.1:\(port)")
    }

    private func handle(_ conn: NWConnection) {
        conn.start(queue: .global(qos: .userInitiated))
        receive(conn, buffer: Data())
    }

    /// Accumulate until we have headers + the full Content-Length body (or the
    /// peer closes), so a request split across TCP segments still parses.
    private func receive(_ conn: NWConnection, buffer: Data) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { conn.cancel(); return }
            var buffer = buffer
            if let data { buffer.append(data) }

            if !isComplete, error == nil, !self.isRequestComplete(buffer) {
                self.receive(conn, buffer: buffer)
                return
            }

            if let request = String(data: buffer, encoding: .utf8) {
                self.route(request: request)
            }
            self.reply(conn)
        }
    }

    private func isRequestComplete(_ buffer: Data) -> Bool {
        guard let text = String(data: buffer, encoding: .utf8),
              let headerEnd = text.range(of: "\r\n\r\n") else { return false }
        let header = text[text.startIndex..<headerEnd.lowerBound]
        // Find Content-Length if present.
        for line in header.split(separator: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2, parts[0].lowercased() == "content-length" {
                let len = Int(parts[1].trimmingCharacters(in: .whitespaces)) ?? 0
                let body = text[headerEnd.upperBound...]
                return body.utf8.count >= len
            }
        }
        return true // no body expected
    }

    private func reply(_ conn: NWConnection) {
        let body = "{\"ok\":true}"
        let response = """
        HTTP/1.1 200 OK\r
        Content-Type: application/json\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """
        conn.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
            conn.cancel()
        })
    }

    private func route(request: String) {
        let lines = request.split(separator: "\r\n", omittingEmptySubsequences: false)
        guard let requestLine = lines.first else { return }
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else { return }
        let path = String(parts[1])

        let bodyStart = request.range(of: "\r\n\r\n")?.upperBound
        let body = bodyStart.map { String(request[$0...]) } ?? ""
        let event = parse(body: body)

        switch path {
        case "/stop":   onEvent(.stop, event)
        case "/notify": onEvent(.notify, event)
        case "/submit": onEvent(.submit, event)
        default: break
        }
    }

    private func parse(body: String) -> HookEvent {
        guard let data = body.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return HookEvent(ppid: nil, cwd: nil, message: nil)
        }
        let ppid: Int32? = (obj["ppid"] as? NSNumber)?.int32Value
            ?? Int32((obj["ppid"] as? String) ?? "")
        return HookEvent(
            ppid: ppid,
            cwd: obj["cwd"] as? String,
            message: obj["message"] as? String
        )
    }
}
