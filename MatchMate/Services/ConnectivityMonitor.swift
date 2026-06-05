import Combine
import Foundation
import Network

protocol ConnectivityMonitoring {
    var isConnected: Bool { get }
    var isConnectedPublisher: AnyPublisher<Bool, Never> { get }
}

final class ConnectivityMonitor: ConnectivityMonitoring {
    static let shared = ConnectivityMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.matchmate.connectivity-monitor")
    private let subject = CurrentValueSubject<Bool, Never>(true)

    var isConnected: Bool {
        subject.value
    }

    var isConnectedPublisher: AnyPublisher<Bool, Never> {
        subject.eraseToAnyPublisher()
    }

    private init() {
        monitor.pathUpdateHandler = { [subject] path in
            subject.send(path.status == .satisfied)
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
