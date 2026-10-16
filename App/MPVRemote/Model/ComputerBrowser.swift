import Foundation
import Network
import Observation
import RemoteProtocol

/// Lists companions advertising themselves over Bonjour on the local network.
@Observable
final class ComputerBrowser {
    private(set) var names: [String] = []
    private var browser: NWBrowser?

    func start() {
        guard browser == nil else { return }
        let browser = NWBrowser(for: .bonjour(type: RemoteService.bonjourType, domain: nil), using: .tcp)
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            // The same computer appears once per network interface.
            let names = Set(results.compactMap { result -> String? in
                if case .service(let name, _, _, _) = result.endpoint { return name }
                return nil
            })
            MainActor.assumeIsolated { self?.names = names.sorted() }
        }
        browser.start(queue: .main)
        self.browser = browser
    }

    func stop() {
        browser?.cancel()
        browser = nil
    }
}
