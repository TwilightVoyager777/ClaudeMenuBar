import Foundation
import Network

final class HTTPServer {
    static let port: UInt16 = 36787

    var onEventData: ((Data) -> Void)?

    private var listener: NWListener?

    func start() throws {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: HTTPServer.port)!)
        self.listener = listener
        listener.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }
        listener.start(queue: .global(qos: .utility))
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    // MARK: - Connection handling

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .utility))
        accumulate(connection: connection, buffer: Data())
    }

    /// Recursively reads chunks until the full HTTP request is assembled,
    /// using Content-Length to know when the body is complete.
    private func accumulate(connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] chunk, _, _, error in
            guard let chunk, error == nil else { connection.cancel(); return }
            self?.tryDispatch(buffer + chunk, on: connection)
        }
    }

    private func tryDispatch(_ data: Data, on connection: NWConnection) {
        let headerSep = Data("\r\n\r\n".utf8)

        // Wait until we have the full header block
        guard let sepRange = data.range(of: headerSep) else {
            accumulate(connection: connection, buffer: data)
            return
        }

        // Parse Content-Length from headers
        let headerBytes = data[..<sepRange.lowerBound]
        let headerString = String(data: headerBytes, encoding: .utf8) ?? ""
        let contentLength: Int = headerString
            .components(separatedBy: "\r\n")
            .compactMap { line -> Int? in
                guard line.lowercased().hasPrefix("content-length:") else { return nil }
                return Int(line.dropFirst("content-length:".count)
                              .trimmingCharacters(in: .whitespaces))
            }
            .first ?? 0

        let bodyOffset = sepRange.upperBound
        let body = data[bodyOffset...]

        guard body.count >= contentLength else {
            // Body not fully arrived yet — keep reading
            accumulate(connection: connection, buffer: data)
            return
        }

        if contentLength > 0 {
            onEventData?(Data(body.prefix(contentLength)))
        }
        sendOK(to: connection)
    }

    private func sendOK(to connection: NWConnection) {
        let response = "HTTP/1.1 200 OK\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
