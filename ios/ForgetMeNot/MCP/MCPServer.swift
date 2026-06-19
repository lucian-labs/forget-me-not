import Foundation
import Network
import OSLog

/// A full MCP (Model Context Protocol) server embedded in the app, over a local HTTP
/// endpoint (Streamable-HTTP-style: POST JSON-RPC → JSON response). Runs in-process while
/// the app is open, so tools operate on the live store — no data sharing / sandbox dance.
/// Point an MCP client at http://localhost:<port> (default 8473).
///
/// `@unchecked Sendable`: Network framework calls back on its own queue; store access is
/// always funneled through `MainActor.run`, so the unchecked reference is sound in practice.
final class MCPServer: @unchecked Sendable {
    let port: UInt16
    private let store: AppStore
    private let icons: IconStore
    private let queue = DispatchQueue(label: "fmn.mcp")
    private var listener: NWListener?
    private let log = Logger(subsystem: "com.lucianlabs.forgetmenot", category: "mcp")
    private(set) var isRunning = false

    init(store: AppStore, icons: IconStore, port: UInt16 = 8473) {
        self.store = store
        self.icons = icons
        self.port = port
    }

    func start() {
        guard listener == nil, let nwPort = NWEndpoint.Port(rawValue: port) else { return }
        do {
            let l = try NWListener(using: .tcp, on: nwPort)
            l.newConnectionHandler = { [weak self] conn in self?.accept(conn) }
            l.stateUpdateHandler = { [weak self] state in
                if case .ready = state { self?.isRunning = true; self?.log.info("MCP server listening on \(self?.port ?? 0)") }
                if case .failed(let e) = state { self?.isRunning = false; self?.log.error("MCP listener failed: \(e.localizedDescription, privacy: .public)") }
            }
            l.start(queue: queue)
            listener = l
        } catch {
            log.error("MCP listener could not start: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: connection plumbing

    private func accept(_ conn: NWConnection) {
        conn.start(queue: queue)
        receive(conn, buffer: Data())
    }

    private func receive(_ conn: NWConnection, buffer: Data) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 1 << 17) { [weak self] data, _, isComplete, error in
            guard let self else { conn.cancel(); return }
            var buf = buffer
            if let data { buf.append(data) }
            if let req = HTTPRequest(buf) {
                Task {
                    let response = await self.respond(to: req)
                    conn.send(content: response, completion: .contentProcessed { _ in conn.cancel() })
                }
            } else if error == nil && !isComplete && buf.count < (1 << 20) {
                self.receive(conn, buffer: buf)   // headers/body not complete yet
            } else {
                conn.cancel()
            }
        }
    }

    // MARK: JSON-RPC

    private func respond(to req: HTTPRequest) async -> Data {
        if req.method == "OPTIONS" { return Self.http(status: "204 No Content", json: nil) }
        guard req.method == "POST" else { return Self.http(status: "405 Method Not Allowed", json: ["error": "POST only"]) }
        guard let obj = try? JSONSerialization.jsonObject(with: req.body) as? [String: Any] else {
            return Self.http(json: ["jsonrpc": "2.0", "id": NSNull(), "error": ["code": -32700, "message": "Parse error"]])
        }
        let id = obj["id"]
        let method = obj["method"] as? String ?? ""
        let params = obj["params"] as? [String: Any] ?? [:]

        if id == nil { return Self.http(status: "202 Accepted", json: nil) }   // notification

        switch method {
        case "initialize":
            let pv = (params["protocolVersion"] as? String) ?? "2025-06-18"
            return rpc(id, result: [
                "protocolVersion": pv,
                "capabilities": ["tools": [String: Any]()],
                "serverInfo": ["name": "forget-me-not", "version": "2.0.0"],
            ])
        case "ping":
            return rpc(id, result: [String: Any]())
        case "tools/list":
            return rpc(id, result: ["tools": MCPTools.list])
        case "tools/call":
            let name = params["name"] as? String ?? ""
            // args is [String: Any] (not Sendable) — ship it across the actor hop as JSON bytes.
            let argsData = (try? JSONSerialization.data(withJSONObject: params["arguments"] ?? [String: Any]())) ?? Data()
            do {
                let text = try await MainActor.run { try self.execute(name: name, argsData: argsData) }
                return rpc(id, result: ["content": [["type": "text", "text": text]]])
            } catch {
                let msg = (error as? MCPError)?.message ?? error.localizedDescription
                return rpc(id, result: ["content": [["type": "text", "text": "Error: \(msg)"]], "isError": true])
            }
        default:
            return rpc(id, error: ["code": -32601, "message": "Method not found: \(method)"])
        }
    }

    private func rpc(_ id: Any?, result: Any? = nil, error: Any? = nil) -> Data {
        var obj: [String: Any] = ["jsonrpc": "2.0", "id": id ?? NSNull()]
        if let error { obj["error"] = error } else { obj["result"] = result ?? NSNull() }
        return Self.http(json: obj)
    }

    private static func http(status: String = "200 OK", json: Any?) -> Data {
        let body = json.flatMap { try? JSONSerialization.data(withJSONObject: $0) } ?? Data()
        var head = "HTTP/1.1 \(status)\r\n"
        head += "Content-Type: application/json\r\n"
        head += "Access-Control-Allow-Origin: *\r\n"
        head += "Access-Control-Allow-Headers: *\r\n"
        head += "Access-Control-Allow-Methods: POST, OPTIONS\r\n"
        head += "Content-Length: \(body.count)\r\n"
        head += "Connection: close\r\n\r\n"
        return Data(head.utf8) + body
    }

    // MARK: tools

    @MainActor private func resolve(_ args: [String: Any]) -> TaskDTO? {
        if let id = args["id"] as? String, let t = store.task(id) { return t }
        if let title = args["title"] as? String {
            return store.tasks.first { $0.title.caseInsensitiveCompare(title) == .orderedSame }
        }
        return nil
    }

    @MainActor private func execute(name: String, argsData: Data) throws -> String {
        let args = (try? JSONSerialization.jsonObject(with: argsData)) as? [String: Any] ?? [:]
        switch name {
        case "list_tasks":
            let rows = store.sortedActive.map { t in
                "\(t.title) [\(t.domain.isEmpty ? "—" : t.domain)] \(Int(Urgency.ratio(t) * 100))%\(t.status == .blocked ? " (paused)" : "")"
            }
            return rows.isEmpty ? "No active tasks." : rows.joined(separator: "\n")

        case "get_overdue":
            let due = store.sortedActive.filter { Urgency.ratio($0) >= 0.9 }
            return due.isEmpty ? "Nothing overdue." :
                due.map { "\($0.title) — \(Int(Urgency.ratio($0) * 100))%" }.joined(separator: "\n")

        case "add_task":
            guard let title = (args["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty
            else { throw MCPError("`title` is required") }
            let recurring = (args["recurring"] as? Bool) ?? true
            let cadence = (args["cadence_seconds"] as? Double) ?? (args["cadence_seconds"] as? Int).map(Double.init) ?? 86400
            let now = Date()
            let dto = TaskDTO(
                id: UUID().uuidString, title: title, description: args["details"] as? String ?? "",
                domain: args["area"] as? String ?? "", tags: [], status: .open, priority: .normal,
                createdAt: now, updatedAt: now, dueDate: nil, startedAt: now, completedAt: nil,
                estimatedHours: nil, recurring: recurring, baseCadenceSeconds: recurring ? cadence : nil,
                cadenceMore: nil, cadenceLess: nil,
                instance: recurring ? ReminderInstanceDTO(startedAt: now, actualCadenceSeconds: cadence, snoozed: false) : nil,
                followUps: [], parentTaskId: nil, prompts: [], soundSeed: nil, actionLog: [])
            store.create(dto)
            return "Added \(title)."

        case "reset_task":
            guard let t = resolve(args) else { throw MCPError.notFound }
            store.reset(id: t.id); return "Reset \(t.title)."

        case "complete_task":
            guard let t = resolve(args) else { throw MCPError.notFound }
            store.complete(id: t.id, note: args["note"] as? String ?? "via MCP"); return "Completed \(t.title)."

        case "log_note":
            guard let t = resolve(args) else { throw MCPError.notFound }
            guard let note = (args["note"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty
            else { throw MCPError("`note` is required") }
            store.addNote(id: t.id, note: note); return "Logged on \(t.title)."

        case "set_active":
            guard let t = resolve(args) else { throw MCPError.notFound }
            let active = (args["active"] as? Bool) ?? true
            store.setActive(id: t.id, active); return "\(t.title) is now \(active ? "active" : "paused")."

        case "set_icon_symbol":
            guard let t = resolve(args) else { throw MCPError.notFound }
            let symbol = (args["symbol"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            icons.setSymbol(symbol, for: t.id)
            return (symbol?.isEmpty == false) ? "Set \(t.title) icon to \(symbol!)." : "Cleared \(t.title)'s icon symbol."

        case "delete_task":
            guard let t = resolve(args) else { throw MCPError.notFound }
            store.delete(id: t.id); return "Deleted \(t.title)."

        default:
            throw MCPError("Unknown tool: \(name)")
        }
    }
}

struct MCPError: Error {
    let message: String
    init(_ message: String) { self.message = message }
    static let notFound = MCPError("No task matched that id or title.")
}

// MARK: - HTTP request parsing

private struct HTTPRequest {
    let method: String
    let path: String
    let body: Data

    /// Returns nil if the buffer doesn't yet hold a complete request (headers + Content-Length body).
    init?(_ data: Data) {
        guard let sep = data.range(of: Data("\r\n\r\n".utf8)),
              let headerStr = String(data: data[..<sep.lowerBound], encoding: .utf8) else { return nil }
        let lines = headerStr.components(separatedBy: "\r\n")
        let parts = (lines.first ?? "").components(separatedBy: " ")
        guard parts.count >= 2 else { return nil }
        method = parts[0]
        path = parts[1]
        var length = 0
        for line in lines.dropFirst() where line.lowercased().hasPrefix("content-length:") {
            length = Int(line.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces)) ?? 0
        }
        let bodyBytes = data[sep.upperBound...]
        if bodyBytes.count < length { return nil }
        body = Data(bodyBytes.prefix(length))
    }
}

// MARK: - Tool catalog (JSON Schema)

enum MCPTools {
    private static func tool(_ name: String, _ desc: String, _ props: [String: Any], required: [String] = []) -> [String: Any] {
        ["name": name, "description": desc,
         "inputSchema": ["type": "object", "properties": props, "required": required]]
    }
    private static var str: [String: Any] { ["type": "string"] }
    private static func str(_ d: String) -> [String: Any] { ["type": "string", "description": d] }

    static var list: [[String: Any]] { [
        tool("list_tasks", "List the active tasks with their area and urgency %.", [:]),
        tool("get_overdue", "List tasks that are due or overdue (≥90%).", [:]),
        tool("add_task", "Create a new task (recurring by default).", [
            "title": str("What to remember"),
            "area": str("Optional grouping, e.g. home / health"),
            "details": str("Optional description"),
            "recurring": ["type": "boolean", "description": "Default true"],
            "cadence_seconds": ["type": "number", "description": "Recurrence interval in seconds (default 86400 = 1 day)"],
        ], required: ["title"]),
        tool("reset_task", "Mark a recurring task as just done (restart its timer). Identify by id or title.", [
            "id": str, "title": str("Task title (case-insensitive)"),
        ]),
        tool("complete_task", "Mark a task as done. Identify by id or title.", [
            "id": str, "title": str("Task title"), "note": str("Optional note"),
        ]),
        tool("log_note", "Add a note to a task's history.", [
            "id": str, "title": str("Task title"), "note": str("The note text"),
        ], required: ["note"]),
        tool("set_active", "Pause or resume a task.", [
            "id": str, "title": str("Task title"), "active": ["type": "boolean", "description": "true = active, false = paused"],
        ], required: ["active"]),
        tool("set_icon_symbol", "Set (or clear) a task's icon to an SF Symbol name, e.g. drop.fill.", [
            "id": str, "title": str("Task title"), "symbol": str("SF Symbol name; omit/empty to clear"),
        ]),
        tool("delete_task", "Delete a task. Identify by id or title.", [
            "id": str, "title": str("Task title"),
        ]),
    ] }
}
