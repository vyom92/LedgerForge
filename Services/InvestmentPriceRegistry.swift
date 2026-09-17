import Foundation

/// Public, owner-confirmed instrument metadata; never account, folio or policy identifiers.
/// Evidence and the retained requests are indexed in Holdings_and_valuation.md (Sprint 97).
nonisolated struct InvestmentPriceDefinition: Sendable {
    let mapping: InvestmentPriceMapping
    let sourceIdentity: String
    let parserProfile: String
    let isin: String?
    let expectedPlan: String?
    let expectedOption: String?
}

nonisolated enum InvestmentPriceRegistry {
    static let providerNames = ["amfi": "AMFI", "nasdaq": "Nasdaq", "fe": "Zurich / FE",
        "fidelity": "Fidelity", "blackrock": "BlackRock", "franklin": "Franklin Templeton"]
    static let providerOrder = ["amfi", "nasdaq", "fe", "fidelity", "blackrock", "franklin"]

    static let definitions: [InvestmentPriceDefinition] = {
        let amfi = [
            ("INF209K01VF2", "120539"), ("INF194K01Z85", "118481"), ("INF760K01JC6", "146130"),
            ("INF740K01PU7", "119247"), ("INF090I01GC8", "118539"), ("INF109KC1F91", "147662"),
            ("INF109KA1UA0", "129312"), ("INF109K018M4", "120621"), ("INF109KC1LJ8", "145075"),
            ("INF109KC1GH2", "143874"), ("INF109K01Z48", "120594"), ("INF205K01NG5", "120395"),
            ("INF247L01445", "127042"), ("INF204K01E54", "118668"), ("INF200K01RA0", "119835")
        ].map { isin, code in
            let blankPlan = code == "127042"
            return InvestmentPriceDefinition(mapping: .init(provider: "amfi", code: code, currency: "INR",
                priceKind: "NAV", instrumentReference: "isin:" + isin,
                evidence: "AMFI scheme code + ISIN + direct plan/option; selected 15-row replay, 9 Sep 2026"),
                sourceIdentity: "isin:" + isin, parserProfile: "indian-mutual-funds.cas.pdf", isin: isin,
                expectedPlan: blankPlan ? "" : "Direct Plan",
                expectedOption: blankPlan ? "" : (["145075", "143874"].contains(code) ? "Cumulative" : (["146130", "118668"].contains(code) ? "Growth Option" : "Growth")))
        }
        let etfs = [
            ("AOA", "55734164", "US4642898591", "ARCA"), ("DIA", "73128548", "US78467X1090", "ARCA"),
            ("IVV", "8991352", "US4642872000", "ARCA"), ("IWV", "10205675", "US4642876894", "ARCA"),
            ("QQQ", "320227571", "US46090E1038", "NASDAQ"), ("QQQM", "449738108", "US46138G6492", "NASDAQ"),
            ("SPY", "756733", "US78462F1030", "ARCA"), ("TQQQ", "72539702", "US74347X8314", "NASDAQ"),
            ("VEA", "45444192", "US9219438580", "ARCA"), ("VGT", "27638079", "US92204A7028", "ARCA"),
            ("VIG", "38746069", "US9219088443", "ARCA"), ("VNQ", "31230302", "US9229085538", "ARCA"),
            ("VOO", "136155102", "US9229083632", "ARCA"), ("VTI", "12340041", "US9229087690", "ARCA"),
            ("VTWO", "79020263", "US92206C6646", "NASDAQ")
        ].map { symbol, conid, isin, listing in
            InvestmentPriceDefinition(mapping: .init(provider: "nasdaq", code: symbol, currency: "USD",
                priceKind: "Dated last sale", instrumentReference: "isin:" + isin, listing: listing,
                evidence: "IBKR conid/ISIN/symbol; confirmed Morningstar listing and USD; Nasdaq replay, 17 Sep 2026"),
                sourceIdentity: "ibkr-conid:" + conid, parserProfile: "ibkr.open-positions.csv", isin: isin,
                expectedPlan: nil, expectedOption: nil)
        }
        let isp = [
            ("iS Nrth Am Idx I Ac", "N0USD", "GPP7"), ("L&G WTW Gbl Dvrs IPP", "USDL3", "AUJDP"),
            ("iShares Emerging MKT", "3UUSD", "LCP0"), ("Qatar Air Conv Blend", "B0280", "CAZYC")
        ].map { name, code, citi in
            InvestmentPriceDefinition(mapping: .init(provider: "fe", code: code, currency: "USD",
                priceKind: "Bid", instrumentReference: "FDD:" + citi,
                evidence: "Confirmed ISP abbreviation to FE fixed lookup key; productive table replay, 9 Sep 2026"),
                sourceIdentity: "zurich-fund-name:" + name, parserProfile: "zurich.isp.closing.csv", isin: nil,
                expectedPlan: nil, expectedOption: nil)
        }
        let cbq = [
            ("fidelity", "FAGAU/G", "LU0966156126", "NAV"),
            ("fidelity", "GTAAU/G", "LU1046421795", "NAV"),
            ("blackrock", "229918", "LU0122376428", "NAV"),
            ("franklin", "4916", "LU0109392836", "NAV (unconfirmed)")
        ].map { provider, code, isin, kind in
            InvestmentPriceDefinition(mapping: .init(provider: provider, code: code, currency: "USD",
                priceKind: kind, instrumentReference: "isin:" + isin,
                evidence: "Exact statement ISIN; issuer USD accumulating class; CBQ catalogue and issuer checks, 17 Sep 2026"),
                sourceIdentity: "isin:" + isin, parserProfile: "cbq.investment-portfolio.pdf", isin: isin,
                expectedPlan: nil, expectedOption: nil)
        }
        return amfi + etfs + isp + cbq
    }()

    static func confirmedMapping(for holding: InvestmentHolding) -> InvestmentPriceMapping? {
        if holding.zioObservationID != nil, holding.parserProfile == "zurich.isp.zio", let code = holding.zioFundCode {
            return definitions.first { $0.mapping.provider == "fe" && $0.mapping.code == code && $0.mapping.currency == holding.currency }?.mapping
        }
        let matches = definitions.filter { definition in
            guard definition.sourceIdentity == holding.instrumentIdentity,
                  definition.mapping.currency == holding.currency else { return false }
            // ISIN/conid bindings identify the same instrument across the accepted PDF/CSV representations.
            // Name-only ISP identifiers remain confined to their original qualified grammar.
            if definition.mapping.provider == "fe", holding.parserProfile != definition.parserProfile { return false }
            if definition.mapping.provider == "nasdaq" {
                guard let isin = definition.isin,
                      holding.sourceAliases.contains("isin:" + isin),
                      holding.sourceAliases.contains("symbol:" + definition.mapping.code) else { return false }
            }
            return true
        }
        return matches.count == 1 ? matches[0].mapping : nil
    }

    static func definition(for mapping: InvestmentPriceMapping) -> InvestmentPriceDefinition? {
        definitions.first { $0.mapping == mapping }
    }
}
