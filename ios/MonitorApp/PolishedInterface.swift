import SwiftUI

struct DataXMark: View {
    var size: CGFloat = 48
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius:size*0.29).fill(LinearGradient(colors:[Color(white:0.19),Color(white:0.065)],startPoint:.topLeading,endPoint:.bottomTrailing))
            RoundedRectangle(cornerRadius:size*0.29).strokeBorder(.white.opacity(0.14),lineWidth:1)
            GeometryReader { g in
                Path { p in
                    p.move(to:CGPoint(x:g.size.width*0.29,y:g.size.height*0.27))
                    p.addLine(to:CGPoint(x:g.size.width*0.71,y:g.size.height*0.73))
                    p.move(to:CGPoint(x:g.size.width*0.71,y:g.size.height*0.27))
                    p.addLine(to:CGPoint(x:g.size.width*0.29,y:g.size.height*0.73))
                }.stroke(.white,style:StrokeStyle(lineWidth:size*0.075,lineCap:.round))
            }
        }.frame(width:size,height:size).accessibilityHidden(true)
    }
}
struct PressFeedback: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration:0.16),value:configuration.isPressed)
    }
}
struct DataXUnlockView: View {
    @EnvironmentObject var session: MonitorSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var breathing = false
    @State private var unlocking = false
    var body: some View {
        VStack(spacing:0) {
            Spacer()
            ZStack {
                Circle().stroke(.white.opacity(0.045),lineWidth:1).frame(width:220,height:220)
                Circle().stroke(.white.opacity(0.08),lineWidth:1).frame(width:166,height:166)
                    .scaleEffect(breathing && !reduceMotion ? 1.06 : 1)
                Circle().fill(.white.opacity(0.035)).frame(width:145,height:145).blur(radius:24)
                DataXMark(size:92).shadow(color:.white.opacity(0.06),radius:28)
            }.frame(height:230)
            Text("DataX").font(.system(size:36,weight:.semibold,design:.rounded)).tracking(-1)
            Text("Your portfolio. Protected.").font(.subheadline).foregroundStyle(Theme.muted).padding(.top,10)
            Spacer()
            Button {
                guard !unlocking else { return }
                unlocking=true
                Task { await session.unlock();unlocking=false }
            } label: {
                HStack(spacing:12) {
                    if unlocking { ProgressView().tint(.black) }
                    else { Image(systemName:"faceid").font(.title3) }
                    Text(unlocking ? "Unlocking…" : "Unlock DataX").font(.system(size:16,weight:.semibold))
                }.frame(maxWidth:.infinity).padding(.vertical,20).foregroundStyle(.black)
                    .background(.white,in:RoundedRectangle(cornerRadius:22))
            }.buttonStyle(PressFeedback()).disabled(unlocking)
            Text("Use Face ID or your device passcode").font(.caption).foregroundStyle(Theme.muted).padding(.top,16)
            Button("Sign out") { Task { await session.logout() } }.font(.caption).foregroundStyle(Theme.muted).padding(.top,24).disabled(session.busy || unlocking)
        }.padding(.horizontal,30).padding(.bottom,30)
            .opacity(appeared ? 1 : 0).offset(y:appeared || reduceMotion ? 0 : 12)
            .onAppear {
                withAnimation(reduceMotion ? nil : .easeOut(duration:0.45)) { appeared=true }
                if !reduceMotion { withAnimation(.easeInOut(duration:2.8).repeatForever(autoreverses:true)) { breathing=true } }
            }
    }
}
enum DataXTab: Int, CaseIterable {
    case overview, trades, wallet, activity, account
    var title: String { ["Home","Trades","Wallet","Activity","Account"][rawValue] }
    var icon: String { ["square.grid.2x2.fill","chart.xyaxis.line","wallet.pass.fill","clock.fill","person.crop.circle.fill"][rawValue] }
}
struct DataXTabBar: View {
    @Binding var selection: DataXTab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var highlight
    var body: some View {
        HStack(spacing:2) {
            ForEach(DataXTab.allCases,id:\.rawValue) { tab in
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response:0.32,dampingFraction:0.82)) { selection=tab }
                } label: {
                    VStack(spacing:7) {
                        Image(systemName:tab.icon).font(.system(size:18,weight:.medium)).frame(height:22)
                        Text(tab.title).font(.system(size:10,weight:selection == tab ? .semibold : .medium)).lineLimit(1)
                    }.foregroundStyle(selection == tab ? Color.white : Color(white:0.45))
                        .frame(maxWidth:.infinity).frame(height:59)
                        .background {
                            if selection == tab { RoundedRectangle(cornerRadius:19).fill(.white.opacity(0.095)).matchedGeometryEffect(id:"selected",in:highlight) }
                        }
                }.buttonStyle(PressFeedback()).accessibilityLabel(tab.title)
                    .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }.padding(7).background(Color(white:0.055),in:RoundedRectangle(cornerRadius:27))
            .overlay(RoundedRectangle(cornerRadius:27).stroke(.white.opacity(0.09),lineWidth:1))
            .shadow(color:.black.opacity(0.5),radius:16,y:6).padding(.horizontal,16).padding(.top,8).padding(.bottom,4)
    }
}
struct StrategyPresentation {
    let title, detail, icon: String
    init(_ report: AgentReport?) {
        guard let report else { title="Connecting";detail="Waiting for the trading system.";icon="antenna.radiowaves.left.and.right";return }
        guard !report.isStale else { title="Update delayed";detail="Waiting for a fresh update.";icon="clock";return }
        switch report.status {
        case "scanning": title="Scanning";detail="Looking for the next opportunity.";icon="viewfinder"
        case "buying": title="Buying";detail="Opening a position.";icon="arrow.down.left"
        case "selling": title="Selling";detail="Closing a position.";icon="arrow.up.right"
        case "holding": title="Holding";detail="Monitoring open positions.";icon="chart.line.uptrend.xyaxis"
        case "paused": title="Paused";detail="Trading is temporarily paused.";icon="pause"
        case "stopped": title="Stopped";detail="The trading system is stopped.";icon="stop"
        case "error": title="Needs attention";detail="The operator is needed.";icon="exclamationmark.triangle"
        default: title=report.positions.isEmpty ? "Active" : "Holding";detail=report.positions.isEmpty ? "The trading system is running." : "Monitoring open positions.";icon="waveform.path"
        }
    }
}
struct SimpleStrategyCard: View {
    let report: AgentReport?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse=false
    var body: some View {
        let status=StrategyPresentation(report)
        VStack(alignment:.leading,spacing:22) {
            HStack {
                Text("DATAX TRADING SYSTEMS").font(.system(size:9,weight:.semibold)).tracking(1.5).foregroundStyle(Theme.muted)
                Spacer()
                Circle().fill(report != nil && report?.isStale == false ? Theme.positive : Theme.muted).frame(width:6,height:6)
            }
            HStack(spacing:16) {
                ZStack {
                    RoundedRectangle(cornerRadius:17).fill(.white.opacity(0.06)).frame(width:54,height:54)
                    Image(systemName:status.icon).font(.system(size:23,weight:.light)).opacity(pulse && !reduceMotion ? 0.55 : 1)
                }
                VStack(alignment:.leading,spacing:6) {
                    Text(status.title).font(.system(size:27,weight:.medium,design:.rounded)).contentTransition(.numericText())
                    Text(status.detail).font(.caption).foregroundStyle(Theme.muted)
                }
                Spacer(minLength:0)
            }
            if let report { Text("Updated "+MonitorFormat.time(report.observedAt)).font(.system(size:10)).foregroundStyle(Theme.muted) }
        }.monitorCard().onAppear {
            if !reduceMotion { withAnimation(.easeInOut(duration:2).repeatForever(autoreverses:true)) { pulse=true } }
        }
    }
}
