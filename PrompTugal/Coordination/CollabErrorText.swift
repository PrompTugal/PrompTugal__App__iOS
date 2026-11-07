import Foundation

/// Short, readable error text for people (Q7): no "Error Domain=…", no object paths, no codes they cannot use.
enum CollabErrorText {
    static func short(_ error: Error) -> String {
        if error is CancellationError { return "Cancelled." }
        if let url = error as? URLError {
            switch url.code {
            case .cancelled: return "Cancelled."
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                return "No internet connection. Try again when you are online."
            case .timedOut: return "The server took too long to answer. Try again."
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return "Can't reach the server. Try again later."
            case .secureConnectionFailed, .serverCertificateUntrusted, .serverCertificateHasBadDate:
                return "The secure connection failed."
            case .badServerResponse, .cannotParseResponse, .zeroByteResource:
                return "The server sent an answer the app could not read."
            default: return "The network request failed. Try again."
            }
        }
        if let described = (error as? LocalizedError)?.errorDescription, readable(described) {
            return described
        }
        let text = (error as NSError).localizedDescription
        return readable(text) ? text : "Something went wrong. Try again."
    }

    /// True for text a person can read: not a raw NSError dump, an object path or a very long string.
    static func readable(_ text: String) -> Bool {
        !text.isEmpty && text.count <= 200
            && !text.contains("Error Domain=") && !text.contains("NSLocalizedDescription")
            && !text.contains("bare/") && !text.contains("obj-cas-") && !text.contains("(null)")
    }
}
