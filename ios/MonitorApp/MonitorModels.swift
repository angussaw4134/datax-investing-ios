import Foundation

struct MonitorUser: Decodable, Identifiable {
    let id, email: String
    let created, canView: Int
    let role: String?
    var isAdmin: Bool { role == "admin" }
    var permitted: Bool { isAdmin || canView == 1 }
}
struct MeResponse: Decodable { let user: MonitorUser }
struct UsersResponse: Decodable { let users: [MonitorUser] }
struct TokenResponse: Decodable { let token: String }
struct ErrorResponse: Decodable { let error: String }
struct WalletToken: Decodable, Identifiable {
    let account, mint, amount: String
    let decimals: Int
    var id: String { account }
}
struct ChainActivity: Decodable, Identifiable {
    let signature: String
    let slot: Int
    let blockTime: Int?
    let success: Bool
    var id: String { signature }
}
struct WalletSnapshot: Decodable {
    let id, observedAt, slot: Int
    let lamports: String
    let tokens: [WalletToken]
    let transactions: [ChainActivity]
    let stale: Bool
    var isStale: Bool { stale || Date().timeIntervalSince1970 - Double(observedAt) > 300 }
}
struct WalletPoint: Decodable {
    let observedAt: Int
    let lamports: String
    var date: Date { Date(timeIntervalSince1970: Double(observedAt)) }
    var chartValue: Double { (Double(lamports) ?? 0) / 1_000_000_000 }
}
struct AgentPosition: Decodable { let symbol, quantity: String }
struct AgentTrade: Decodable, Identifiable {
    let id, symbol, side, signature: String
    let at: Int
}
struct AgentReport: Decodable {
    let id, status, strategy, note, source: String
    let sequence, observedAt, receivedAt: Int
    let stale: Bool
    let positions: [AgentPosition]
    let trades: [AgentTrade]
    let realizedPnlSol: String?
    var isStale: Bool { stale || Date().timeIntervalSince1970 - Double(observedAt) > 300 }
}
struct MonitorResponse: Decodable {
    let mode, wallet: String
    let snapshot: WalletSnapshot?
    let points: [WalletPoint]
    let agent: AgentReport?
}
struct PortfolioResponse: Decodable {
    let wallet: String
    let snapshot: PortfolioSnapshot?
    let valuation: PoolValuation?
    let onchainPnl: PoolPnl?
}
struct PortfolioSnapshot: Decodable {
    let observedAt: Int
    let stale: Bool
    var isStale: Bool { stale || Date().timeIntervalSince1970-Double(observedAt)>300 }
}
struct PoolValuation: Decodable {
    let totalUsd, totalAud, totalSol: Double?
    let complete: Bool
    let notes: [String]
}
struct PoolPnl: Decodable {
    let netDepositsSol: String
    let pnlSol: Double?
    let complete: Bool
}
struct TransfersResponse: Decodable {
    let wallet, netDepositsSol: String
    let pendingClassification: Int
    let transfers: [WalletTransfer]
}
struct WalletTransfer: Decodable, Identifiable {
    let signature, kind: String
    let mint, amountDisplay: String?
    let blockTime: Int?
    let verified, success: Bool
    var id: String { signature }
}
enum MonitorFormat {
    // Exact string conversion for displayed balances. Double is used only for plotting.
    static func units(_ raw: String, decimals: Int) -> String {
        guard decimals >= 0, decimals <= 255, !raw.isEmpty, raw.allSatisfy({ $0.isNumber }) else { return "Unavailable" }
        if decimals == 0 { return raw }
        let padded=String(repeating:"0",count:max(0,decimals+1-raw.count))+raw
        let split=padded.index(padded.endIndex,offsetBy:-decimals)
        return String(padded[..<split])+"."+String(padded[split...])
    }
    static func time(_ seconds: Int) -> String { Date(timeIntervalSince1970:Double(seconds)).formatted(date:.abbreviated,time:.shortened) }
    static func short(_ value: String) -> String { String(value.prefix(7))+"…"+String(value.suffix(6)) }
    static func explorer(_ kind: String, _ value: String) -> URL { URL(string:"https://solscan.io/\(kind)/\(value)")! }
}
