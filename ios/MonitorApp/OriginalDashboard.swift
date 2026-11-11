import SwiftUI
import Charts

// Original DataX visual components, connected to the live monitor models.
struct WalletAction: View {
    let title, icon: String
    var body: some View {
        VStack(spacing:10) {
            Image(systemName:icon).font(.system(size:21,weight:.medium)).frame(width:58,height:58)
                .background(Color(white:0.12),in:RoundedRectangle(cornerRadius:21))
                .overlay(RoundedRectangle(cornerRadius:21).stroke(.white.opacity(0.07)))
            Text(title).font(.system(size:12,weight:.medium)).foregroundStyle(Color(white:0.76))
        }.frame(maxWidth:.infinity).foregroundStyle(.white)
    }
}
struct OriginalTag: View {
    let text: String
    var color: Color = .white
    var body: some View { Text(text.uppercased()).font(.system(size:9,weight:.bold,design:.monospaced)).tracking(1).padding(.horizontal,10).padding(.vertical,6).foregroundStyle(color).background(color.opacity(0.09),in:Capsule()) }
}
struct OriginalStat: View {
    let title, value: String
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            Text(title).font(.system(size:9,weight:.semibold)).tracking(1).foregroundStyle(Theme.muted)
            Text(value).font(.system(size:21,weight:.medium,design:.rounded)).minimumScaleFactor(0.5).lineLimit(1)
        }.monitorCard()
    }
}
struct OriginalEmpty: View {
    let title, message, icon: String
    var body: some View {
        VStack(spacing:14) {
            Image(systemName:icon).font(.largeTitle)
            Text(title).font(.headline)
            Text(message).font(.subheadline).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
        }.frame(maxWidth:.infinity).padding(.vertical,32).monitorCard()
    }
}
struct OriginalDashboard: View {
    @EnvironmentObject var session: MonitorSession
    @State private var period = "1M"
    @State private var selectedDate: Date?
    @State private var transferNotice = false
    @State private var chartScope = "Personal"
    private let periods = ["1W","1M","3M","ALL"]
    private var points: [WalletPoint] {
        let days = period == "1W" ? 7.0 : period == "1M" ? 30.0 : period == "3M" ? 90.0 : 100000.0
        return (session.monitor?.points ?? []).filter { $0.date >= Date().addingTimeInterval(-days*86400) }
    }
    private var selected: WalletPoint? {
        guard let selectedDate else { return nil }
        return points.min { abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate)) }
    }
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:24) {
                header
                if !session.canView { AccessState() }
                else if let data = session.monitor {
                    portfolioHeading(data)
                    personalBalance
                    poolBalance(data)
                    shortcuts
                    performanceHistory
                    HStack(spacing:12) {
                        OriginalStat(title:"REPORTED EARNINGS",value:data.agent?.realizedPnlSol.map { $0+" SOL" } ?? "Unavailable")
                        OriginalStat(title:"OPEN POSITIONS",value:data.agent.map { String($0.positions.count) } ?? "Unavailable")
                    }
                    tradingSystem(data)
                    positions(data)
                    Text("Balance history includes transfers and network costs. Earnings and positions are reported by the trading system, not independently reconciled.").font(.caption2).foregroundStyle(Theme.muted)
                } else {
                    OriginalEmpty(title:"Connecting your wallet",message:"Your live balance and activity will appear here when available.",icon:"wallet.pass")
                }
            }.padding(22)
        }.background(Color.black).toolbar(.hidden,for:.navigationBar)
            .refreshable { await session.refresh() }
            .sheet(isPresented:$transferNotice) { TransferAvailabilityView() }
    }
    private var header: some View {
        HStack(spacing:12) {
            DataXMark(size:42)
            VStack(alignment:.leading,spacing:4) {
                Text("DataX Investing").font(.system(size:15,weight:.semibold))
                Text("Customer account").font(.caption).foregroundStyle(Theme.muted)
            }
            Spacer()
            NavigationLink { ChainMonitorView() } label: {
                Image(systemName:"bell").font(.system(size:18)).frame(width:40,height:40).background(Theme.card,in:Circle())
            }.foregroundStyle(.white)
        }
    }
    private func portfolioHeading(_ data: MonitorResponse) -> some View {
        HStack {
            Text("YOUR BALANCE").font(.system(size:10,weight:.semibold)).tracking(2).foregroundStyle(Theme.muted)
            Spacer()
            OriginalTag(text:session.offline ? "Offline" : data.snapshot == nil ? "Connecting" : data.snapshot?.isStale == true ? "Stale" : "Live",color:session.offline || data.snapshot?.isStale == true ? .orange : .white)
        }
    }
    private var personalBalance: some View {
        VStack(alignment:.leading,spacing:14) {
            Text("Unavailable").font(.system(size:42,weight:.medium,design:.rounded)).minimumScaleFactor(0.6).lineLimit(1)
            Text("Your share of the DataX pool").font(.caption).foregroundStyle(Theme.muted)
            HStack(spacing:12) {
                OriginalStat(title:"YOU DEPOSITED",value:"Unavailable")
                OriginalStat(title:"YOUR GAINS",value:"Unavailable")
            }
            HStack {
                Text("Your return").foregroundStyle(Theme.muted)
                Spacer()
                Text("Unavailable").fontWeight(.medium)
            }.font(.subheadline)
            Text("Personal balance and percentage gains will appear when customer accounting is connected.")
                .font(.caption2).foregroundStyle(Theme.muted)
        }
    }
    private func poolBalance(_ data: MonitorResponse) -> some View {
        HStack(spacing:14) {
            Image(systemName:"square.stack.3d.up").font(.title3).frame(width:40,height:40).background(.white.opacity(0.06),in:RoundedRectangle(cornerRadius:13))
            VStack(alignment:.leading,spacing:5) {
                Text("POOL BALANCE").font(.system(size:9,weight:.semibold)).tracking(1).foregroundStyle(Theme.muted)
                Text(data.snapshot.map { MonitorFormat.units($0.lamports,decimals:9)+" SOL" } ?? "Unavailable")
                    .font(.system(size:20,weight:.medium,design:.rounded)).minimumScaleFactor(0.5).lineLimit(1)
                Text("SOL cash only · excludes token positions").font(.caption2).foregroundStyle(Theme.muted)
            }
            Spacer(minLength:0)
        }.monitorCard()
    }
    private var performanceHistory: some View {
        VStack(alignment:.leading,spacing:18) {
            HStack {
                Text("Performance").font(.headline)
                Spacer()
                Picker("Chart",selection:$chartScope) {
                    Text("Personal").tag("Personal")
                    Text("Pool").tag("Pool")
                }.pickerStyle(.segmented).frame(width:170)
            }
            if chartScope == "Personal" {
                OriginalEmpty(title:"Your performance",message:"Your personal gains chart will appear once your deposits and pool share are recorded.",icon:"chart.line.uptrend.xyaxis")
            } else {
                if let point = selected {
                    Text(MonitorFormat.units(point.lamports,decimals:9)+" SOL")
                        .font(.title3.monospacedDigit())
                    Text(MonitorFormat.time(point.observedAt)).font(.caption2).foregroundStyle(Theme.muted)
                }
                history
                Text("Pool SOL cash history includes deposits, withdrawals and network costs. It is not a profit chart.").font(.caption2).foregroundStyle(Theme.muted)
            }
        }
    }
    private func balance(_ data: MonitorResponse) -> some View {
        VStack(spacing:10) {
            Text((selected?.lamports ?? data.snapshot?.lamports).map { MonitorFormat.units($0,decimals:9) } ?? "—")
                .font(.system(size:46,weight:.medium,design:.rounded)).minimumScaleFactor(0.5).lineLimit(1).tracking(-2).contentTransition(.numericText())
            HStack(spacing:6) {
                Text("SOL").fontWeight(.semibold)
                Text("· Solana wallet balance").foregroundStyle(Theme.muted)
            }.font(.caption)
            if let point = selected { Text(MonitorFormat.time(point.observedAt)).font(.caption2).foregroundStyle(Theme.muted) }
            else if session.offline { Text("Showing your last fetched balance").font(.caption2).foregroundStyle(.orange) }
        }.frame(maxWidth:.infinity).padding(.top,6)
    }
    private var shortcuts: some View {
        HStack(spacing:16) {
            Button { transferNotice=true } label: { WalletAction(title:"Deposit",icon:"arrow.down.left") }
            Button { transferNotice=true } label: { WalletAction(title:"Withdraw",icon:"arrow.up.right") }
            NavigationLink { StrategyMonitorView() } label: { WalletAction(title:"Trades",icon:"chart.xyaxis.line") }
            NavigationLink { ChainMonitorView() } label: { WalletAction(title:"Activity",icon:"clock") }
        }.buttonStyle(.plain).padding(.vertical,12)
    }
    private var history: some View {
        VStack(spacing:14) {
            if points.count > 1 {
                Chart {
                    ForEach(Array(points.enumerated()),id:\.offset) { _,p in
                        AreaMark(x:.value("Date",p.date),yStart:.value("Zero",0),yEnd:.value("SOL",p.chartValue))
                            .foregroundStyle(LinearGradient(colors:[Color.white.opacity(0.22),Color.white.opacity(0.01)],startPoint:.top,endPoint:.bottom))
                        LineMark(x:.value("Date",p.date),y:.value("SOL",p.chartValue)).foregroundStyle(.white).lineStyle(StrokeStyle(lineWidth:2.5))
                    }
                    if let p = selected {
                        RuleMark(x:.value("Selected",p.date)).foregroundStyle(Theme.muted.opacity(0.5))
                        PointMark(x:.value("Date",p.date),y:.value("SOL",p.chartValue)).foregroundStyle(.white)
                    }
                }.chartYAxis(.hidden)
                    .chartXAxis { AxisMarks(values:.automatic(desiredCount:4)) { _ in AxisValueLabel().foregroundStyle(Theme.muted) } }
                    .chartOverlay { proxy in
                        GeometryReader { geometry in
                            Rectangle().fill(.clear).contentShape(Rectangle())
                                .gesture(DragGesture(minimumDistance:0).onChanged { value in
                                    if let frame = proxy.plotFrame { selectedDate=proxy.value(atX:value.location.x-geometry[frame].origin.x,as:Date.self) }
                                }.onEnded { _ in selectedDate=nil })
                                .onContinuousHover { phase in
                                    switch phase {
                                    case .active(let location): if let frame = proxy.plotFrame { selectedDate=proxy.value(atX:location.x-geometry[frame].origin.x,as:Date.self) }
                                    case .ended: selectedDate=nil
                                    }
                                }
                        }
                    }.frame(height:190)
                Text("Touch and slide, or hover, to inspect your balance.").font(.caption2).foregroundStyle(Theme.muted)
            } else {
                OriginalEmpty(title:"Your story starts here",message:"Your chart builds as live wallet snapshots arrive.",icon:"chart.line.uptrend.xyaxis")
            }
            HStack {
                ForEach(periods,id:\.self) { p in
                    Button { period=p;selectedDate=nil } label: {
                        Text(p).font(.caption.weight(.semibold)).frame(maxWidth:.infinity).padding(.vertical,10)
                            .background(period == p ? Color.white.opacity(0.12) : .clear,in:Capsule())
                            .foregroundStyle(period == p ? Color.white : Theme.muted)
                    }
                }
            }
        }
    }
    private func tradingSystem(_ data: MonitorResponse) -> some View {
        SimpleStrategyCard(report:data.agent)
    }
    private func positions(_ data: MonitorResponse) -> some View {
        VStack(spacing:16) {
            HStack { Text("Recent positions").font(.headline);Spacer();Text(data.agent.map { "\($0.positions.count) open" } ?? "Unavailable").font(.caption).foregroundStyle(Theme.muted) }.padding(.top,8)
            if let agent = data.agent {
                if agent.positions.isEmpty {
                    OriginalEmpty(title:"No positions yet",message:"Positions from DataX Trading Systems will appear here.",icon:"chart.xyaxis.line")
                }
                ForEach(Array(agent.positions.prefix(3).enumerated()),id:\.offset) { _,p in
                    HStack(spacing:14) {
                        Text(String(p.symbol.prefix(1))).font(.headline).frame(width:44,height:44).background(.white.opacity(0.06),in:RoundedRectangle(cornerRadius:14))
                        VStack(alignment:.leading,spacing:6) { Text(p.symbol).font(.subheadline.weight(.semibold));Text("OPEN POSITION").font(.caption2).foregroundStyle(Theme.muted) }
                        Spacer()
                        Text(p.quantity).font(.subheadline.monospacedDigit())
                    }.padding(.vertical,9)
                }
            }
        }
    }
}
struct TransferAvailabilityView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack(alignment:.leading,spacing:22) {
                OriginalEmpty(title:"Transfers aren't enabled",message:"This app currently monitors the trading wallet. Customer deposits and withdrawal requests are not connected.",icon:"wallet.pass")
                Text("Viewing this wallet does not give you ownership of its assets.").font(.caption).foregroundStyle(Theme.muted)
                Spacer()
            }.padding(24).background(Color.black).navigationTitle("Your wallet")
                .toolbar { Button("Done") { dismiss() } }
        }.preferredColorScheme(.dark)
    }
}
struct OriginalWalletView: View {
    @EnvironmentObject var session: MonitorSession
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:20) {
                if !session.canView { AccessState() }
                else if let data = session.monitor {
                    OriginalTag(text:"Solana")
                    Text(data.snapshot.map { MonitorFormat.units($0.lamports,decimals:9)+" SOL" } ?? "Unavailable").font(.system(size:42,weight:.medium,design:.rounded)).minimumScaleFactor(0.5).lineLimit(1)
                    Text("Monitored wallet balance").foregroundStyle(Theme.muted)
                    Text("Token holdings").font(.headline).padding(.top,8)
                    if let snapshot = data.snapshot {
                        ForEach(snapshot.tokens.filter { NSDecimalNumber(string:$0.amount).compare(NSDecimalNumber.zero) == .orderedDescending }) { token in
                            Link(destination:MonitorFormat.explorer("token",token.mint)) {
                                HStack { Text(MonitorFormat.short(token.mint));Spacer();Text(MonitorFormat.units(token.amount,decimals:token.decimals)) }.font(.subheadline).monitorCard()
                            }
                        }
                        Text("Updated "+MonitorFormat.time(snapshot.observedAt)).font(.caption).foregroundStyle(snapshot.isStale ? Color.orange : Theme.muted)
                    }
                    Link(destination:MonitorFormat.explorer("account",data.wallet)) { Label("View wallet on Solscan",systemImage:"arrow.up.right.square") }.font(.subheadline)
                    if session.user?.isAdmin == true {
                        ActionButton(title:"Refresh wallet") { Task { await session.refreshWallet() } }.disabled(session.busy)
                    }
                }
            }.padding(22)
        }.background(Color.black).navigationTitle("Your wallet").refreshable { await session.refresh() }
    }
}
