import SwiftUI

// Separate screenshot target. Never included in the shipping application.
@main struct DataXPreviewApp: App {
    @StateObject private var session = makePreviewSession()
    @MainActor static func makePreviewSession() -> MonitorSession {
        let s = MonitorSession()
        let time = Int(Date().timeIntervalSince1970)
        s.user = MonitorUser(id:"preview",email:"customer@example.test",created:time,canView:1,role:"viewer")
        s.signedIn = true
        var points: [WalletPoint] = []
        for i in 0..<48 {
            let observed: Int = time - (47 - i) * 3600
            let wave: Int = Int(sin(Double(i) * 0.8) * 18_000_000.0)
            let amount: Int = 420_000_000 + i * 3_100_000 + wave
            points.append(WalletPoint(observedAt:observed,lamports:String(amount)))
        }
        let snap = WalletSnapshot(id:1,observedAt:time,slot:1,lamports:points.last!.lamports,tokens:[],transactions:[],stale:false)
        let report = AgentReport(id:"preview",status:"scanning",strategy:"DataX",note:"",source:"sample",sequence:1,observedAt:time,receivedAt:time,stale:false,positions:[],trades:[],realizedPnlSol:"0.042")
        s.monitor = MonitorResponse(mode:"preview",wallet:"PreviewOnly",snapshot:snap,points:points,agent:report)
        return s
    }
    private var screen: String { ProcessInfo.processInfo.arguments.last ?? "home" }
    var body: some Scene {
        WindowGroup {
            ZStack {
                Color.black.ignoresSafeArea()
                if screen == "unlock" { DataXUnlockView() }
                else if screen == "login" { MonitorLogin() }
                else {
                    NavigationStack {
                        Group {
                            if screen == "strategy" { StrategyMonitorView() }
                            else { OriginalDashboard() }
                        }
                    }.safeAreaInset(edge:.bottom,spacing:0) {
                        DataXTabBar(selection:.constant(screen == "strategy" ? .trades : .overview)).background(Color.black)
                    }
                }
            }.environmentObject(session).preferredColorScheme(.dark).tint(.white)
                .safeAreaInset(edge:.top,spacing:0) {
                    Text("PREVIEW · SAMPLE DATA").font(.system(size:8,weight:.semibold)).tracking(2).foregroundStyle(Color(white:0.5)).frame(maxWidth:.infinity).padding(.vertical,5).background(Color.black)
                }
        }
    }
}
