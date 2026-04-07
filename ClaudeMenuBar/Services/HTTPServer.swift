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

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .utility))
        receiveRequest(on: connection)
    }

    private func receiveRequest(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let data, error == nil else { connection.cancel(); return }
            self?.parseHTTPBody(from: data, connection: connection)
        }
    }

    private func parseHTTPBody(from rawData: Data, connection: NWConnection) {
        let separator = Data("\r\n\r\n".utf8)
        if let range = rawData.range(of: separator) {
            let body = rawData[range.upperBound...]
            if !body.isEmpty {
                onEventData?(Data(body))
            }
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
