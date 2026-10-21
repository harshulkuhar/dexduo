import SwiftUI

enum DexSupport {
    static let email = "kuharharshul@gmail.com"
    static let website = URL(string: "https://harshulkuhar.github.io/dexduo/")!
    static let privacy = website.appendingPathComponent("privacy/")
    static let terms = website.appendingPathComponent("terms/")
    static let support = website.appendingPathComponent("support/")
}

struct SupportAboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            Text("Support & About").font(.headline)
            Text(DexSupport.email).textSelection(.enabled).accessibilityIdentifier("supportEmail")
            Link("Email support", destination: URL(string: "mailto:\(DexSupport.email)?subject=DexDuo%20support")!).frame(minHeight: 44)
            Link("Support website", destination: DexSupport.support).frame(minHeight: 44)
            Link("Privacy policy", destination: DexSupport.privacy).frame(minHeight: 44).accessibilityIdentifier("supportPrivacy")
            Link("Terms of use", destination: DexSupport.terms).frame(minHeight: 44).accessibilityIdentifier("supportTerms")
            Text("Unofficial fan project. Not affiliated with Nintendo, The Pokémon Company or Game Freak.")
                .font(.footnote).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
