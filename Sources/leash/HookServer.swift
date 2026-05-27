import Foundation
import Network

struct HookEvent {
    let ppid: Int32?
    let cwd: String?
    let message: String?
}

final class HookServer {
    private var listener: NWListener?
    private let onStop: (HookEvent) -> Void
    private let onSubmit: (HookEvent) -> Void

    init(onStop: @escaping (HookEvent) -> Void, onSubmit: @escaping (HookEvent) -> Void) {
        self.onStop = onStop
        self.onSubmit = onSubmit
    }

    func start(port: UInt16) throws {
        let params = NWParameters.tcp
        let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        listener.newConnectionHandler = { [weak self] conn in self?.handle(conn) }
        listener.start(queue: .global(qos: .userInitiated))
        self.listener = listener
        NSLog("leash: listening on 127.0.0.1:\(port)")
    }

    private func handle(_ conn: NWConnection) {
        conn.start(queue: .global(qos: .userInitiated))
        conn.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, _, _ in
            defer { conn.cancel() }
            guard let self, let data, let request = String(data: data, encoding: .utf8) else { return }
            self.route(request: request)
            let body = "{\"ok\":true}"
            let response = """
            HTTP/1.1 200 OK\r
            Content-Type: application/json\r
            Content-Length: \(body.utf8.count)\r
            Connection: close\r
            \r
            \(body)
            """
            conn.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in })
        }
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
        case "/stop": onStop(event)
        case "/submit": onSubmit(event)
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
