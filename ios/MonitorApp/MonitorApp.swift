import SwiftUI
import Charts

enum Theme {
    static let card=Color(white:0.075), muted=Color(white:0.57), positive=Color(red:0.60,green:0.86,blue:0.68)
}
extension View { func monitorCard() -> some View { padding(20).frame(maxWidth:.infinity,alignment:.leading).background(Theme.card,in:RoundedRectangle(cornerRadius:22)).overlay(RoundedRectangle(cornerRadius:22).stroke(.white.opacity(0.06))) } }
struct MonitorBrand: View { var body: some View { HStack(spacing:9){DataXMark(size:34);Text("DataX").font(.system(size:25,weight:.bold,design:.rounded));Text("INVESTING").font(.system(size:9,weight:.medium)).tracking(2).foregroundStyle(Theme.muted)} } }
struct ActionButton: View {
    let title: String
    let action: () -> Void
    var body: some View { Button(action:action){HStack{Text(title).fontWeight(.semibold);Spacer();Image(systemName:"arrow.up.right")}.padding(18).foregroundStyle(.black).background(.white,in:RoundedRectangle(cornerRadius:16))}.buttonStyle(.plain) }
}
struct MonitorEmpty: View { let title, detail: String;var body: some View { VStack(alignment:.leading,spacing:10){Text(title).font(.headline);Text(detail).font(.subheadline).foregroundStyle(Theme.muted)}.monitorCard() } }
#if !SCREENSHOT
@main struct DataXMonitorApp: App {
    @StateObject private var session=MonitorSession()
    @Environment(\.scenePhase) private var phase
    var body: some Scene { WindowGroup { MonitorRoot().environmentObject(session).preferredColorScheme(.dark).tint(.white).onChange(of:phase){_,value in
        if value == .background && session.biometric && session.signedIn { session.locked=true }
        if value == .active && session.signedIn && !session.locked { Task { await session.refresh() } }
    } } }
}
#endif
struct MonitorRoot: View {
    @EnvironmentObject var session: MonitorSession
    @Environment(\.scenePhase) private var phase
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if !session.signedIn { MonitorLogin() }
            else if session.locked { DataXUnlockView() }
            else { MonitorTabs() }
        }.task {
            if session.signedIn && session.biometric { session.locked=true }
            await session.refresh()
            while !Task.isCancelled { do{try await Task.sleep(for:.seconds(30))}catch{break};if phase == .active { await session.refresh() } }
        }.alert("DataX",isPresented:Binding(get:{session.error != nil},set:{if !$0{session.error=nil}})){Button("OK"){session.error=nil}}message:{Text(session.error ?? "")}
    }
}
struct MonitorLogin: View {
    @EnvironmentObject var session: MonitorSession
    @State private var email=""
    @State private var code=""
    @State private var accepted=false
    @State private var sent=false
    @State private var resendAfter=Date.distantPast
    var body: some View {
        ScrollView { VStack(alignment:.leading,spacing:24){
            MonitorBrand().padding(.top,40)
            Text(sent ? "Check your inbox." : "Your next chapter.").font(.system(size:40,weight:.semibold)).tracking(-1.5)
            Text(sent ? "Enter the 8-digit code sent to your email. It expires in ten minutes." : "Your portfolio. Your performance. DataX Trading Systems.").foregroundStyle(Theme.muted)
            VStack(spacing:18){
                TextField("Email address",text:$email).textContentType(.emailAddress).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled().disabled(sent)
                if sent { Divider();TextField("8-digit code",text:$code).textContentType(.oneTimeCode).keyboardType(.numberPad).onChange(of:code){_,v in code=String(v.filter(\.isNumber).prefix(8))} }
            }.monitorCard()
            if !sent { Toggle("I accept the monitoring terms and privacy notice",isOn:$accepted).font(.subheadline) }
            HStack{Link("Terms",destination:URL(string:MonitorSession.origin+"/terms.html")!);Text("·");Link("Privacy",destination:URL(string:MonitorSession.origin+"/privacy.html")!)}.font(.caption).foregroundStyle(Theme.muted)
            ActionButton(title:session.busy ? "Please wait…" : sent ? "Verify and continue" : "Send sign-in code") { Task {
                if sent { await session.verify(email:email,code:code);code="" }
                else if await session.sendCode(email:email) { sent=true;resendAfter=Date().addingTimeInterval(60) }
            }}.disabled(session.busy || email.isEmpty || (!sent && !accepted) || (sent && code.count != 8))
            if sent {
                TimelineView(.periodic(from:.now,by:1)){context in let remaining=max(0,Int(ceil(resendAfter.timeIntervalSince(context.date))))
                    Button(remaining>0 ? "Resend available in \(remaining)s" : "Send another code"){Task{if await session.sendCode(email:email){resendAfter=Date().addingTimeInterval(60)}}}.disabled(session.busy || remaining>0).font(.caption)
                }
                Button("Use another email"){sent=false;code=""}.font(.caption)
            }
            Text("New accounts need the owner’s approval to view the wallet. Monitoring does not give you ownership of its assets.").font(.caption).foregroundStyle(Theme.muted)
        }.padding(26) }.scrollDismissesKeyboard(.interactively)
    }
}
struct MonitorTabs: View {
    @State private var selected: DataXTab = .overview
    var body: some View {
        TabView(selection:$selected) {
            NavigationStack { WalletMonitorView() }.tag(DataXTab.overview).toolbar(.hidden,for:.tabBar)
            NavigationStack { StrategyMonitorView() }.tag(DataXTab.trades).toolbar(.hidden,for:.tabBar)
            NavigationStack { OriginalWalletView() }.tag(DataXTab.wallet).toolbar(.hidden,for:.tabBar)
            NavigationStack { ChainMonitorView() }.tag(DataXTab.activity).toolbar(.hidden,for:.tabBar)
            NavigationStack { MonitorAccountView() }.tag(DataXTab.account).toolbar(.hidden,for:.tabBar)
        }.safeAreaInset(edge:.bottom,spacing:0) { DataXTabBar(selection:$selected).background(Color.black) }
    }
}
struct AccessState: View {
    @EnvironmentObject var session: MonitorSession
    var body: some View { VStack(spacing:24){MonitorEmpty(title:session.user == nil ? "Connecting to DataX" : "Your account is ready",detail:session.user == nil ? "Fetching your account. Retry if the service is unavailable." : "The owner must approve your access before you can see this wallet.");ActionButton(title:"Check access"){Task{await session.refresh()}}}.padding(24) }
}
struct WalletMonitorView: View {
    var body: some View { OriginalDashboard() }
}
struct StrategyMonitorView: View {
    @EnvironmentObject var session: MonitorSession
    var body: some View { Group{if !session.canView{AccessState()}else{ScrollView{VStack(alignment:.leading,spacing:20){
        if let a=session.monitor?.agent {
            SimpleStrategyCard(report:a)
            Text("Open positions").font(.headline)
            if a.positions.isEmpty{MonitorEmpty(title:"No positions reported",detail:"The trading system is waiting for an opportunity.")}
            ForEach(Array(a.positions.enumerated()),id:\.offset){_,p in HStack{Text(p.symbol);Spacer();Text(p.quantity).monospacedDigit()}.monitorCard()}
            Text("Strategy trades").font(.headline)
            if a.trades.isEmpty{MonitorEmpty(title:"No strategy trades reported",detail:"Wallet deposits and test transactions are not automatically counted as strategy trades.")}
            ForEach(a.trades){t in Link(destination:MonitorFormat.explorer("tx",t.signature)){VStack(alignment:.leading,spacing:10){Text(t.side.uppercased()+" · "+t.symbol).font(.headline);Text(MonitorFormat.time(t.at)).font(.caption).foregroundStyle(Theme.muted);Label("Inspect transaction",systemImage:"arrow.up.right.square").font(.caption)}.monitorCard()}}
            Text("Trade activity is reported by DataX Trading Systems.").font(.caption).foregroundStyle(Theme.muted)
        }else{MonitorEmpty(title:"Connecting",detail:"Waiting for an update from the trading system.")}
    }.padding(22)}.refreshable{await session.refresh()}}}.background(Color.black).navigationTitle("Strategy") }
}
struct ChainMonitorView: View {
    @EnvironmentObject var session: MonitorSession
    var body: some View { Group{if !session.canView{AccessState()}else{ScrollView{VStack(alignment:.leading,spacing:18){
        Text("Recent on-chain activity").font(.headline)
        if let s=session.monitor?.snapshot {
            if s.isStale{Text("Snapshot is stale. Last updated "+MonitorFormat.time(s.observedAt)).foregroundStyle(.orange).font(.caption)}
            if s.transactions.isEmpty{MonitorEmpty(title:"No recent signatures",detail:"The latest RPC response contains no recent activity.")}
            ForEach(s.transactions){t in Link(destination:MonitorFormat.explorer("tx",t.signature)){HStack{Image(systemName:t.success ? "checkmark.circle" : "xmark.circle").foregroundStyle(t.success ? Theme.positive : .red);VStack(alignment:.leading,spacing:8){Text(MonitorFormat.short(t.signature)).font(.subheadline.monospaced());Text(t.blockTime.map{MonitorFormat.time($0)} ?? "Time unavailable").font(.caption).foregroundStyle(Theme.muted)};Spacer();Text(t.success ? "Confirmed" : "Failed").font(.caption)}.monitorCard()}}
        }else{MonitorEmpty(title:"Activity unavailable",detail:"Waiting for a wallet snapshot.")}
        Text("Latest 50 address signatures. This is separate from strategy trades and is not a complete profit ledger.").font(.caption).foregroundStyle(Theme.muted)
    }.padding(22)}.refreshable{await session.refresh()}}}.background(Color.black).navigationTitle("Activity") }
}
struct MonitorAccountView: View {
    @EnvironmentObject var session: MonitorSession
    @State private var deleting=false
    var body: some View { List {
        if let user=session.user {
            Section("Account"){Text(user.email).textSelection(.enabled);LabeledContent("Access",value:user.isAdmin ? "Owner" : user.canView==1 ? "Customer" : "Pending approval")}
            if user.isAdmin{Section{NavigationLink("Manage customer access"){MonitorAdminView()}}}
            Section("Security"){Toggle("Lock with Face ID or passcode",isOn:$session.biometric);Text("Session stored in this device’s Keychain. Email verification is required to sign in.").font(.caption).foregroundStyle(Theme.muted)}
        }

        Section("Help"){Link("Support",destination:URL(string:"mailto:angussaw09@gmail.com")!);Link("Privacy notice",destination:URL(string:MonitorSession.origin+"/privacy.html")!);Link("Monitoring terms",destination:URL(string:MonitorSession.origin+"/terms.html")!)}
        Section{Button("Sign out",role:.destructive){Task{await session.logout()}}.disabled(session.busy);if session.user?.isAdmin == false{Button("Delete account",role:.destructive){deleting=true}.disabled(session.busy)}}
    }.scrollContentBackground(.hidden).background(Color.black).navigationTitle("Account")
        .confirmationDialog("Permanently delete your customer account?",isPresented:$deleting,titleVisibility:.visible){Button("Delete account",role:.destructive){Task{await session.deleteAccount()}}}message:{Text("Your login and access are removed. The monitored wallet and public blockchain history are unchanged.")}
    }
}
struct MonitorAdminView: View {
    @EnvironmentObject var session: MonitorSession
    var body: some View { List {
        Section{Text("Only approved customers can see wallet holdings and private S9 reports. Approval grants viewing access only.").font(.caption).foregroundStyle(Theme.muted)}
        ForEach(session.users.filter{$0.id != session.user?.id}){u in VStack(alignment:.leading,spacing:12){Text(u.email).font(.subheadline);HStack{Text(u.canView==1 ? "Has access" : "Pending").font(.caption).foregroundStyle(Theme.muted);Spacer();Button(u.canView==1 ? "Revoke" : "Grant"){Task{await session.setAccess(id:u.id,allowed:u.canView != 1)}}.disabled(session.busy)}}.padding(.vertical,8)}
    }.scrollContentBackground(.hidden).background(Color.black).navigationTitle("Customer access").refreshable{await session.refresh()} }
}
