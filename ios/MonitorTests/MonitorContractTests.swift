import XCTest
@testable import DataXInvesting

final class MonitorContractTests: XCTestCase {
    func testPortfolioPartialValuationAndUnknownGain() throws {
        let raw=#"{"wallet":"pool","snapshot":{"observed_at":1,"stale":false},"valuation":{"total_usd":12.5,"total_aud":null,"total_sol":0.15,"complete":false,"notes":["Unpriced holding"]},"onchain_pnl":{"net_deposits_sol":"0.2","pnl_sol":null,"complete":false}}"#
        let value=try decoder.decode(PortfolioResponse.self,from:Data(raw.utf8))
        XCTAssertNil(value.valuation?.totalAud)
        XCTAssertNil(value.onchainPnl?.pnlSol)
        XCTAssertEqual(value.valuation?.complete,false)
        XCTAssertEqual(value.snapshot?.isStale,true)
    }
    func testTransferContractPreservesFailedAndExactAmount() throws {
        let raw=#"{"wallet":"pool","net_deposits_sol":"0.1","pending_classification":2,"transfers":[{"signature":"sig","kind":"withdrawal","mint":"SOL","amount_display":"0.000000001","block_time":null,"verified":true,"success":false}]}"#
        let value=try decoder.decode(TransfersResponse.self,from:Data(raw.utf8))
        XCTAssertEqual(value.pendingClassification,2)
        XCTAssertEqual(value.transfers.first?.amountDisplay,"0.000000001")
        XCTAssertEqual(value.transfers.first?.success,false)
        XCTAssertNil(value.transfers.first?.blockTime)
    }
    private var decoder: JSONDecoder { let d=JSONDecoder();d.keyDecodingStrategy = .convertFromSnakeCase;return d }
    func testUnknownDataIsNotZero() throws {
        let raw=#"{"mode":"live-read-only","wallet":"wallet","snapshot":null,"points":[],"agent":null,"trading_profit_verified":null,"customer_balance":null}"#
        let result=try decoder.decode(MonitorResponse.self,from:Data(raw.utf8))
        XCTAssertNil(result.snapshot);XCTAssertNil(result.agent);XCTAssertTrue(result.points.isEmpty)
    }
    func testLiveResponseContract() throws {
        let raw=#"{"mode":"live-read-only","wallet":"wallet","snapshot":{"id":1,"observed_at":1794391684,"slot":468084225,"lamports":"595623087","stale":false,"tokens":[{"account":"ata","mint":"mint","amount":"9007199254740993","decimals":6}],"transactions":[{"signature":"sig","slot":1,"block_time":null,"success":false}]},"points":[{"observed_at":1794391684,"lamports":"595623087"}],"agent":{"id":"report","sequence":42,"observed_at":1794391684,"received_at":1794391685,"status":"scanning","strategy":"S9-LIVE","note":"flat","positions":[],"trades":[],"realized_pnl_sol":"0","stale":false,"source":"agent-reported; not independently reconciled"},"trading_profit_verified":null,"customer_balance":null}"#
        let result=try decoder.decode(MonitorResponse.self,from:Data(raw.utf8))
        XCTAssertEqual(result.snapshot?.lamports,"595623087")
        XCTAssertEqual(result.agent?.realizedPnlSol,"0")
        XCTAssertNil(result.snapshot?.transactions.first?.blockTime)
        XCTAssertEqual(result.snapshot?.transactions.first?.success,false)
        XCTAssertEqual(result.snapshot?.tokens.first?.amount,"9007199254740993")
    }
    func testExactDisplayDoesNotLoseMicroUnits() {
        XCTAssertEqual(MonitorFormat.units("595623087",decimals:9),"0.595623087")
        XCTAssertEqual(MonitorFormat.units("1",decimals:9),"0.000000001")
        XCTAssertEqual(MonitorFormat.units("9007199254740993",decimals:6),"9007199254.740993")
        XCTAssertEqual(MonitorFormat.units("0",decimals:9),"0.000000000")
        XCTAssertEqual(MonitorFormat.units("bad",decimals:9),"Unavailable")
    }
    func testViewerDefaultsDoNotGrantAccess() throws {
        let raw=#"{"user":{"id":"u","email":"viewer@example.test","created":1,"can_view":0,"role":"viewer"}}"#
        let result=try decoder.decode(MeResponse.self,from:Data(raw.utf8))
        XCTAssertFalse(result.user.isAdmin);XCTAssertFalse(result.user.permitted)
        let adminList=#"{"users":[{"id":"u","email":"viewer@example.test","created":1,"can_view":1}]}"#
        let list=try decoder.decode(UsersResponse.self,from:Data(adminList.utf8))
        XCTAssertNil(list.users.first?.role);XCTAssertEqual(list.users.first?.permitted,true)
    }
}
