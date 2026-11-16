import CryptoKit
import SwiftUI

/// The key the composers sign with. The app hands in the person key (PTPlaces' sign-in) with `.talkSigning { … }`;
/// without one, items go unsigned and the screen says so. The signature, not anything on this device, is what lets
/// the conductor trust a message: it acts only on messages signed by a registered fingerprint (ENVELOPE.md).
extension EnvironmentValues {
    @Entry public var talkSigningKey: (@Sendable () -> P256.Signing.PrivateKey?)? = nil
}

extension View {
    public func talkSigning(_ key: @escaping @Sendable () -> P256.Signing.PrivateKey?) -> some View {
        environment(\.talkSigningKey, key)
    }
}

/// The 17 places of the Algarve's first wave (as PTLocal and PTPlaces list them), for the contribution's town.
public enum TalkTowns {
    public struct Town: Identifiable, Hashable, Sendable {
        public let id: String
        public let name: String
    }

    public static let all: [Town] = [
        Town(id: "albufeira", name: "Albufeira"), Town(id: "alcoutim", name: "Alcoutim"), Town(id: "aljezur", name: "Aljezur"), Town(id: "castro-marim", name: "Castro Marim"),
        Town(id: "faro", name: "Faro"), Town(id: "lagoa", name: "Lagoa"), Town(id: "lagos", name: "Lagos"), Town(id: "loule", name: "Loulé"), Town(id: "monchique", name: "Monchique"),
        Town(id: "olhao", name: "Olhão"), Town(id: "portimao", name: "Portimão"), Town(id: "quarteira", name: "Quarteira"), Town(id: "sao-bras-de-alportel", name: "São Brás de Alportel"),
        Town(id: "silves", name: "Silves"), Town(id: "tavira", name: "Tavira"), Town(id: "vila-do-bispo", name: "Vila do Bispo"),
        Town(id: "vila-real-de-santo-antonio", name: "Vila Real de Santo António"),
    ]
    public static func name(_ id: String) -> String? { all.first { $0.id == id }?.name }
}
