import Foundation

struct NetworkStatus {
    var wifiConnected: Bool
    var wifiStatus: String
    
    var routerReachable: Bool
    var routerStatus: String
    
    var ispReachable: Bool
    var ispStatus: String
    
    var dnsWorking: Bool
    var dnsStatus: String
    
    var diagnoses: [String]
    var suggestedFixes: [String]
    
    var isFullyConnected: Bool {
        return wifiConnected && routerReachable && ispReachable && dnsWorking
    }
    
    static var unknown: NetworkStatus {
        return NetworkStatus(
            wifiConnected: false,
            wifiStatus: "Checking...",
            routerReachable: false,
            routerStatus: "Checking...",
            ispReachable: false,
            ispStatus: "Checking...",
            dnsWorking: false,
            dnsStatus: "Checking...",
            diagnoses: [],
            suggestedFixes: []
        )
    }
}
