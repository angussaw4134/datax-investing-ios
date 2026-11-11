import Foundation
import SwiftUI
import Security
import LocalAuthentication

enum MonitorVault {
    static let service="com.datax.investing.monitor.v1"
    static var query: [String:Any] { [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:"session"] }
    static func load() -> String? {
        var q=query; q[kSecReturnData as String]=true; q[kSecMatchLimit as String]=kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary,&item)==errSecSuccess,let data=item as? Data else { return nil }
        return String(data:data,encoding:.utf8)
    }
    static func save(_ token: String) throws {
        SecItemDelete(query as CFDictionary)
        var q=query; q[kSecValueData as String]=Data(token.utf8); q[kSecAttrAccessible as String]=kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        guard SecItemAdd(q as CFDictionary,nil)==errSecSuccess else { throw NSError(domain:"DataX",code:1,userInfo:[NSLocalizedDescriptionKey:"Could not securely store your session. Please try again."]) }
    }
    static func clear() { SecItemDelete(query as CFDictionary) }
}
@MainActor final class MonitorSession: ObservableObject {
    static let origin="https://datax-monitor.accesshubv1.workers.dev"
    @Published var user: MonitorUser?
    @Published var monitor: MonitorResponse?
    @Published var users: [MonitorUser]=[]
    @Published var signedIn=MonitorVault.load() != nil
    @Published var busy=false
    @Published var locked=false
    @Published var error: String?
    @Published var lastUpdated: Date?
    @Published var offline=false
    @AppStorage("datax.monitor.biometric") var biometric=false
    private var token=MonitorVault.load()
    private var refreshing=false
    private let decoder: JSONDecoder = { let d=JSONDecoder();d.keyDecodingStrategy = .convertFromSnakeCase;return d }()
    private let http: URLSession = { let c=URLSessionConfiguration.ephemeral;c.httpCookieStorage=nil;c.httpShouldSetCookies=false;c.requestCachePolicy = .reloadIgnoringLocalCacheData;return URLSession(configuration:c) }()
    var canView: Bool { user?.permitted == true }
    func request(_ path: String, body: [String:Any]?=nil) async throws -> Data {
        var r=URLRequest(url:URL(string:Self.origin+"/api"+path)!);r.timeoutInterval=25
        r.setValue("application/json",forHTTPHeaderField:"Content-Type")
        if let token { r.setValue("Bearer "+token,forHTTPHeaderField:"Authorization") }
        if let body { r.httpMethod="POST";r.httpBody=try JSONSerialization.data(withJSONObject:body) }
        let (data,response)=try await http.data(for:r)
        guard let response=response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard 200..<300 ~= response.statusCode else {
            if response.statusCode==401 && !path.hasPrefix("/auth/") { clear() }
            let text=(try? decoder.decode(ErrorResponse.self,from:data).error) ?? "Service returned HTTP \(response.statusCode). Please try again later."
            throw NSError(domain:"DataX",code:response.statusCode,userInfo:[NSLocalizedDescriptionKey:text])
        }
        return data
    }
    func sendCode(email: String) async -> Bool {
        guard !busy else { return false };busy=true;defer{busy=false}
        do{_ = try await request("/auth/code",body:["email":email.trimmingCharacters(in:.whitespacesAndNewlines),"accept_terms":true]);return true}catch{self.error=error.localizedDescription;return false}
    }
    func verify(email: String, code: String) async {
        guard !busy else { return };busy=true;defer{busy=false}
        do {
            let result=try decoder.decode(TokenResponse.self,from:await request("/auth/verify",body:["email":email.trimmingCharacters(in:.whitespacesAndNewlines),"code":code]))
            try MonitorVault.save(result.token);token=result.token;signedIn=true;locked=false;await refresh()
        }catch{self.error=error.localizedDescription}
    }
    func refresh() async {
        guard signedIn && !locked && !refreshing else { return };refreshing=true;defer{refreshing=false}
        do {
            user=try decoder.decode(MeResponse.self,from:await request("/me")).user
            if canView { monitor=try decoder.decode(MonitorResponse.self,from:await request("/monitor")) } else { monitor=nil }
            if user?.isAdmin == true { users=try decoder.decode(UsersResponse.self,from:await request("/admin/users")).users } else { users=[] }
            lastUpdated=Date();offline=false
        }catch{offline=true;self.error=error.localizedDescription}
    }
    func refreshWallet() async {
        guard !busy else { return };busy=true;defer{busy=false}
        do{_ = try await request("/monitor/refresh",body:[:]);await refresh()}catch{self.error=error.localizedDescription}
    }
    func setAccess(id: String, allowed: Bool) async {
        guard !busy else { return };busy=true;defer{busy=false}
        do{_ = try await request("/admin/access",body:["id":id,"can_view":allowed]);await refresh()}catch{self.error=error.localizedDescription}
    }
    func logout() async {
        guard !busy else { return };busy=true;defer{busy=false}
        do{_ = try await request("/auth/logout",body:[:]);clear()}catch{self.error="Sign-out could not be confirmed. Retry to revoke the server session. " + error.localizedDescription}
    }
    func deleteAccount() async {
        guard !busy else { return };busy=true;defer{busy=false}
        do{_ = try await request("/auth/delete",body:["confirm":"DELETE"]);clear()}catch{self.error=error.localizedDescription}
    }
    func clear() { MonitorVault.clear();token=nil;signedIn=false;user=nil;monitor=nil;users=[];locked=false;lastUpdated=nil;offline=false }
    func unlock() async { do{if try await LAContext().evaluatePolicy(.deviceOwnerAuthentication,localizedReason:"Unlock DataX Investing"){locked=false;await refresh()}}catch{self.error=error.localizedDescription} }
}
