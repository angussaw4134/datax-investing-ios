import SwiftUI
import Charts

struct SectionEyebrow: View {
    let title: String
    var body: some View { Text(title.uppercased()).font(.system(size:10,weight:.semibold)).tracking(1.8).foregroundStyle(Theme.muted) }
}
struct QuietEmpty: View {
    let icon, title, detail: String
    var body: some View {
        VStack(spacing:12) {
            Image(systemName:icon).font(.system(size:24,weight:.light)).foregroundStyle(.white.opacity(0.65))
            Text(title).font(.system(size:15,weight:.medium))
            Text(detail).font(.system(size:12)).foregroundStyle(Theme.muted).multilineTextAlignment(.center).lineSpacing(3)
        }.frame(maxWidth:.infinity).padding(.vertical,30).padding(.horizontal,24)
    }
}
struct RefinedTransferRow: View {
    let transfer: WalletTransfer
    private var symbol: String { transfer.kind == "deposit" ? "arrow.down.left" : transfer.kind == "withdrawal" ? "arrow.up.right" : transfer.kind == "swap" ? "arrow.left.arrow.right" : "ellipsis" }
    var body: some View {
        Link(destination:MonitorFormat.explorer("tx",transfer.signature)) {
            HStack(spacing:14) {
                Image(systemName:symbol).font(.system(size:16,weight:.medium)).frame(width:42,height:42).background(Color(white:0.1),in:Circle())
                VStack(alignment:.leading,spacing:5) {
                    Text(transfer.kind == "fee-rent" ? "Network activity" : transfer.kind.capitalized).font(.system(size:14,weight:.medium))
                    Text(transfer.blockTime.map { MonitorFormat.time($0) } ?? "Time unavailable").font(.system(size:11)).foregroundStyle(Theme.muted)
                }
                Spacer(minLength:8)
                VStack(alignment:.trailing,spacing:5) {
                    Text(transfer.amountDisplay.map { $0+" "+(transfer.mint == "SOL" ? "SOL" : "tokens") } ?? "—").font(.system(size:13,weight:.medium)).lineLimit(1).minimumScaleFactor(0.6)
                    Text(!transfer.success ? "Failed" : transfer.verified ? "Confirmed" : "Unverified").font(.system(size:10)).foregroundStyle(!transfer.success ? Color.orange : Theme.muted)
                }
            }.padding(.vertical,13).foregroundStyle(.white)
        }.buttonStyle(PressFeedback())
    }
}
struct TrackedTransfersView: View {
    @EnvironmentObject var session: MonitorSession
    var initialFilter = "All"
    @State private var filter = "All"
    private let filters=["All","Deposits","Withdrawals"]
    private var rows: [WalletTransfer] {
        (session.transfers?.transfers ?? []).filter { t in
            t.kind != "unrelated" && (filter == "All" || t.kind == (filter == "Deposits" ? "deposit" : "withdrawal"))
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:24) {
                SectionEyebrow(title:"Shared wallet activity")
                HStack(spacing:8) {
                    ForEach(filters,id:\.self) { item in
                        Button { filter=item } label: { Text(item).font(.system(size:12,weight:.medium)).padding(.horizontal,16).padding(.vertical,11).background(filter == item ? Color.white : Color(white:0.08),in:Capsule()).foregroundStyle(filter == item ? Color.black : Theme.muted) }.buttonStyle(PressFeedback())
                    }
                }
                if let data=session.transfers {
                    if data.pendingClassification>0 { Text("\(data.pendingClassification) transactions are being classified.").font(.caption).foregroundStyle(Theme.muted) }
                    if rows.isEmpty { QuietEmpty(icon:"clock",title:"Nothing here yet",detail:"Confirmed wallet activity will appear here.") }
                    LazyVStack(spacing:0) { ForEach(rows) { row in RefinedTransferRow(transfer:row);Divider().overlay(.white.opacity(0.04)) } }
                    Text("Recent shared-wallet history. This screen tracks transfers; it does not send funds or assign them to a customer.").font(.caption2).foregroundStyle(Theme.muted).lineSpacing(3)
                } else { QuietEmpty(icon:"clock",title:"Activity unavailable",detail:session.trackingError ?? "Pull down to load wallet activity.") }
            }.padding(24)
        }.background(Color.black).navigationTitle("Activity").navigationBarTitleDisplayMode(.large)
            .onAppear { filter=initialFilter }.refreshable { await session.refresh() }
    }
}
struct OriginalDashboard: View {
    @EnvironmentObject var session: MonitorSession
    @State private var scope="Pool"
    @State private var period="1W"
    @State private var selectedDate: Date?
    private var points: [WalletPoint] {
        let days=period == "1W" ? 7.0 : period == "1M" ? 30.0 : period == "3M" ? 90.0 : 100000.0
        return (session.monitor?.points ?? []).filter { $0.date >= Date().addingTimeInterval(-days*86400) }
    }
    private var selected: WalletPoint? {
        guard let selectedDate else { return nil }
        return points.min { abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate)) }
    }
    var body: some View {
        ScrollView(showsIndicators:false) {
            VStack(alignment:.leading,spacing:28) {
                HStack {
                    HStack(spacing:10) { DataXMark(size:32);Text("DataX").font(.system(size:23,weight:.semibold)).tracking(-0.8) }
                    Spacer()
                    NavigationLink { MonitorAccountView() } label: { Image(systemName:"person.crop.circle").font(.system(size:24,weight:.light)).foregroundStyle(.white.opacity(0.8)).frame(width:44,height:44) }
                }
                if !session.canView { AccessState() }
                else {
                    personalHero
                    HStack(spacing:12) {
                        NavigationLink { TrackedTransfersView(initialFilter:"Deposits") } label: { Label("Deposits",systemImage:"arrow.down.left").font(.system(size:14,weight:.semibold)).frame(maxWidth:.infinity).padding(.vertical,17).foregroundStyle(.black).background(.white,in:Capsule()) }
                        NavigationLink { TrackedTransfersView(initialFilter:"Withdrawals") } label: { Label("Withdrawals",systemImage:"arrow.up.right").font(.system(size:14,weight:.medium)).frame(maxWidth:.infinity).padding(.vertical,17).background(Color(white:0.1),in:Capsule()) }
                    }.buttonStyle(PressFeedback())
                    poolSummary
                    chartSection
                    SimpleStrategyCard(report:session.monitor?.agent)
                    recentActivity
                    if let error=session.trackingError { Text(error).font(.caption2).foregroundStyle(Theme.muted) }
                }
            }.padding(.horizontal,24).padding(.top,8).padding(.bottom,24)
        }.background(Color.black).toolbar(.hidden,for:.navigationBar).refreshable { await session.refresh() }
    }
    private var personalHero: some View {
        VStack(alignment:.leading,spacing:22) {
            HStack { SectionEyebrow(title:"Your balance");Spacer();Text("CUSTOMER").font(.system(size:8,weight:.semibold)).tracking(1.2).foregroundStyle(Theme.muted) }
            HStack(alignment:.firstTextBaseline,spacing:10) {
                Text("—").font(.system(size:54,weight:.light,design:.rounded))
                Text("SOL").font(.system(size:15)).foregroundStyle(Theme.muted)
                Spacer()
                Image(systemName:"chart.line.uptrend.xyaxis").font(.system(size:25,weight:.ultraLight)).foregroundStyle(.white.opacity(0.2))
            }
            HStack {
                heroMetric("Deposited",value:"— SOL")
                Spacer()
                heroMetric("Gains",value:"— SOL")
                Spacer()
                heroMetric("Return",value:"— %")
            }
            Text("Your balance appears once customer accounting is connected.").font(.system(size:11)).foregroundStyle(Theme.muted).lineSpacing(3)
        }.padding(22).background(LinearGradient(colors:[Color(white:0.11),Color(white:0.045)],startPoint:.topLeading,endPoint:.bottomTrailing),in:RoundedRectangle(cornerRadius:26))
            .overlay(RoundedRectangle(cornerRadius:26).stroke(.white.opacity(0.07)))
    }
    private func heroMetric(_ label: String,value: String) -> some View {
        VStack(alignment:.leading,spacing:8) { Text(label).font(.system(size:11)).foregroundStyle(Theme.muted);Text(value).font(.system(size:14,weight:.medium)).monospacedDigit() }
    }
    private var poolSummary: some View {
        VStack(alignment:.leading,spacing:12) {
            HStack { SectionEyebrow(title:"Total pool");Spacer();Text(session.offline || session.portfolio?.snapshot?.isStale == true ? "Last update" : "Shared wallet").font(.system(size:10)).foregroundStyle(Theme.muted) }
            HStack(alignment:.firstTextBaseline) {
                Text(poolValue).font(.system(size:27,weight:.medium,design:.rounded)).tracking(-0.8).minimumScaleFactor(0.6).lineLimit(1)
                Spacer()
                if let aud=session.portfolio?.valuation?.totalAud { Text(aud,format:.currency(code:"AUD")).font(.system(size:12)).foregroundStyle(Theme.muted) }
            }
            Text(session.portfolio?.valuation != nil ? (session.portfolio?.valuation?.complete == true ? "Estimated value of priced holdings" : "Partial value · some holdings may be unpriced") : "SOL cash balance · excludes token positions").font(.system(size:10)).foregroundStyle(Theme.muted)
        }.padding(.horizontal,2)
    }
    private var poolValue: String {
        if let value=session.portfolio?.valuation?.totalSol { return value.formatted(.number.precision(.fractionLength(2...6)))+" SOL" }
        if let raw=session.monitor?.snapshot?.lamports { return MonitorFormat.units(raw,decimals:9)+" SOL" }
        return "— SOL"
    }
    private var chartSection: some View {
        VStack(alignment:.leading,spacing:20) {
            HStack {
                Text("Overview").font(.system(size:17,weight:.semibold))
                Spacer()
                HStack(spacing:3) { ForEach(["Pool","Personal"],id:\.self) { item in Button { scope=item;selectedDate=nil } label: { Text(item).font(.system(size:11,weight:.medium)).padding(.horizontal,12).padding(.vertical,8).background(scope == item ? Color(white:0.18) : .clear,in:Capsule()).foregroundStyle(scope == item ? .white : Theme.muted) } } }.padding(3).background(Color(white:0.07),in:Capsule())
            }
            if scope == "Pool" && points.count>1 {
                HStack { Text(selected.map { MonitorFormat.units($0.lamports,decimals:9)+" SOL" } ?? "SOL cash history").font(.system(size:12,weight:.medium)).monospacedDigit();Spacer();if let p=selected { Text(MonitorFormat.time(p.observedAt)).font(.system(size:9)).foregroundStyle(Theme.muted) } }
                Chart(points,id:\.observedAt) { p in
                    AreaMark(x:.value("Date",p.date),yStart:.value("Zero",0),yEnd:.value("SOL",p.chartValue)).foregroundStyle(LinearGradient(colors:[Color.white.opacity(0.16),.clear],startPoint:.top,endPoint:.bottom))
                    LineMark(x:.value("Date",p.date),y:.value("SOL",p.chartValue)).foregroundStyle(.white).lineStyle(StrokeStyle(lineWidth:2))
                    if let s=selected, s.observedAt == p.observedAt { RuleMark(x:.value("Selected",s.date)).foregroundStyle(.white.opacity(0.25));PointMark(x:.value("Date",s.date),y:.value("SOL",s.chartValue)).foregroundStyle(.white) }
                }.chartXAxis(.hidden).chartYAxis(.hidden).chartXSelection(value:$selectedDate).frame(height:165)
                HStack { ForEach(["1W","1M","3M","ALL"],id:\.self) { item in Button { period=item;selectedDate=nil } label: { Text(item).font(.system(size:10,weight:.semibold)).frame(maxWidth:.infinity).padding(.vertical,9).background(period == item ? Color(white:0.13) : .clear,in:Capsule()).foregroundStyle(period == item ? .white : Theme.muted) } } }
                Text("Includes transfers and network costs; not a profit chart.").font(.system(size:10)).foregroundStyle(Theme.muted)
            } else { QuietEmpty(icon:"chart.xyaxis.line",title:scope == "Personal" ? "Your performance, in time" : "History is building",detail:scope == "Personal" ? "Your gains chart will appear after customer accounting is connected." : "Wallet snapshots will appear here as they arrive.") }
        }.padding(.vertical,4)
    }
    private var recentActivity: some View {
        VStack(alignment:.leading,spacing:12) {
            HStack { Text("Recent activity").font(.system(size:17,weight:.semibold));Spacer();NavigationLink { TrackedTransfersView() } label: { Text("View all").font(.system(size:11)).foregroundStyle(Theme.muted) } }
            if let rows=session.transfers?.transfers.filter({ $0.kind != "unrelated" }), !rows.isEmpty {
                VStack(spacing:0) { ForEach(Array(rows.prefix(3))) { RefinedTransferRow(transfer:$0) } }
            } else { Text("Confirmed deposits and withdrawals will appear here.").font(.system(size:12)).foregroundStyle(Theme.muted).padding(.vertical,12) }
        }
    }
}
struct OriginalWalletView: View {
    @EnvironmentObject var session: MonitorSession
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:26) {
                if !session.canView { AccessState() }
                else {
                    SectionEyebrow(title:"Shared trading wallet")
                    if let valuation=session.portfolio?.valuation {
                        Text(valuation.totalAud.map { $0.formatted(.currency(code:"AUD")) } ?? "—").font(.system(size:42,weight:.medium,design:.rounded)).tracking(-1)
                        Text(valuation.complete ? "Estimated portfolio value" : "Partial valuation").font(.caption).foregroundStyle(Theme.muted)
                        ForEach(valuation.notes,id:\.self) { Text($0).font(.caption2).foregroundStyle(Theme.muted) }
                    }
                    HStack { SectionEyebrow(title:"Assets");Spacer();Text("Solana").font(.caption).foregroundStyle(Theme.muted) }
                    HStack(spacing:14) { Image(systemName:"circle.hexagongrid.fill").frame(width:42,height:42).background(Color(white:0.1),in:Circle());Text("Solana").font(.subheadline);Spacer();Text(session.monitor?.snapshot.map { MonitorFormat.units($0.lamports,decimals:9)+" SOL" } ?? "—").font(.system(size:13)).minimumScaleFactor(0.6).lineLimit(1) }
                    ForEach(session.monitor?.snapshot?.tokens.filter { NSDecimalNumber(string:$0.amount).compare(.zero) == .orderedDescending } ?? []) { token in
                        HStack { Text(MonitorFormat.short(token.mint)).font(.subheadline);Spacer();Text(MonitorFormat.units(token.amount,decimals:token.decimals)).font(.caption).monospacedDigit() }.padding(.vertical,10)
                    }
                    Divider()
                    NavigationLink { TrackedTransfersView() } label: { HStack { Text("Deposits & withdrawals");Spacer();Image(systemName:"chevron.right").font(.caption) }.font(.subheadline).padding(.vertical,8) }
                    if let wallet=session.monitor?.wallet { Link(destination:MonitorFormat.explorer("account",wallet)) { HStack { Text("View on Solscan");Spacer();Image(systemName:"arrow.up.right").font(.caption) }.font(.subheadline) } }
                    Text("Shared-wallet tracking. Sending funds and customer withdrawal requests are not enabled.").font(.caption2).foregroundStyle(Theme.muted).lineSpacing(3)
                }
            }.padding(24)
        }.background(Color.black).navigationTitle("Wallet").refreshable { await session.refresh() }
    }
}
