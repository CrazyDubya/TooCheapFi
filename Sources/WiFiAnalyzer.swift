import Foundation
import CoreWLAN

/// Handles Wi-Fi diagnostics and channel analysis
struct WiFiAnalyzer {

    // Non-DFS 5 GHz channels
    private let preferred5GHzChannels = [36, 40, 44, 48, 149, 153, 157, 161, 165]

    // MARK: - Wi-Fi Info

    /// Gets detailed information about the current Wi-Fi connection
    func getWiFiInfo() -> WiFiInfo? {
        guard let interface = CWWiFiClient.shared().interface() else {
            return nil
        }

        let rssi = interface.rssiValue()
        let noise = interface.noiseMeasurement()
        let signalQuality = SignalQuality.from(rssi: rssi)

        var channelBand = "Unknown"
        var channelNum = 0
        var channelWidth = 0

        if let channel = interface.wlanChannel() {
            channelNum = channel.channelNumber
            channelBand = bandString(from: channel.channelBand)
            channelWidth = widthValue(from: channel.channelWidth)
        }

        let phyMode = phyModeString(from: interface.activePHYMode())
        let security = securityString(from: interface.security())

        return WiFiInfo(
            ssid: interface.ssid(),
            bssid: interface.bssid(),
            rssi: rssi,
            noise: noise,
            channel: channelNum,
            channelBand: channelBand,
            channelWidth: channelWidth,
            transmitRate: interface.transmitRate(),
            phyMode: phyMode,
            security: security,
            signalQuality: signalQuality
        )
    }

    // MARK: - Channel Analysis

    struct ChannelAnalysisResult {
        let neighbors: [NeighboringNetwork]
        let analysis2GHz: [ChannelAnalysis]
        let recommended2GHz: Int?
        let analysis5GHz: [ChannelAnalysis]
        let recommended5GHz: Int?
    }

    /// Scans for neighboring networks and analyzes channel congestion
    func analyzeChannels() -> ChannelAnalysisResult {
        guard let interface = CWWiFiClient.shared().interface() else {
            return ChannelAnalysisResult(
                neighbors: [],
                analysis2GHz: [],
                recommended2GHz: nil,
                analysis5GHz: [],
                recommended5GHz: nil
            )
        }

        // Scan for networks
        let neighbors = scanNeighbors(interface: interface)
        guard !neighbors.isEmpty else {
            return ChannelAnalysisResult(
                neighbors: [],
                analysis2GHz: [],
                recommended2GHz: nil,
                analysis5GHz: [],
                recommended5GHz: nil
            )
        }

        let currentChannel = interface.wlanChannel()?.channelNumber ?? 0
        let currentBand = interface.wlanChannel()?.channelBand

        // Analyze 2.4 GHz
        let (analysis2GHz, recommended2GHz) = analyze2GHzChannels(
            neighbors: neighbors,
            currentChannel: currentChannel,
            currentBand: currentBand
        )

        // Analyze 5 GHz
        let (analysis5GHz, recommended5GHz) = analyze5GHzChannels(
            neighbors: neighbors,
            currentChannel: currentChannel,
            currentBand: currentBand
        )

        return ChannelAnalysisResult(
            neighbors: neighbors,
            analysis2GHz: analysis2GHz,
            recommended2GHz: recommended2GHz,
            analysis5GHz: analysis5GHz,
            recommended5GHz: recommended5GHz
        )
    }

    // MARK: - Private Helpers

    private func scanNeighbors(interface: CWInterface) -> [NeighboringNetwork] {
        do {
            let networks = try interface.scanForNetworks(withSSID: nil)
            return networks.map { network in
                var band = "Unknown"
                var channelNum = 0

                if let channel = network.wlanChannel {
                    channelNum = channel.channelNumber
                    band = bandString(from: channel.channelBand)
                }

                return NeighboringNetwork(
                    ssid: network.ssid ?? "(Hidden)",
                    bssid: network.bssid ?? "",
                    rssi: network.rssiValue,
                    channel: channelNum,
                    channelBand: band,
                    security: "Unknown"
                )
            }
        } catch {
            logWarning("WiFi network scan failed: \(error.localizedDescription)")
            return []
        }
    }

    private func analyze2GHzChannels(
        neighbors: [NeighboringNetwork],
        currentChannel: Int,
        currentBand: CWChannelBand?
    ) -> ([ChannelAnalysis], Int?) {
        var analysis: [ChannelAnalysis] = []
        var recommended: Int?
        var lowestCongestion = Int.max

        for channel in [1, 6, 11] {
            let onChannel = neighbors.filter {
                $0.channel == channel && $0.channelBand == "2.4 GHz"
            }

            let adjacent = neighbors.filter {
                $0.channelBand == "2.4 GHz" &&
                abs($0.channel - channel) <= 2 &&
                $0.channel != channel
            }

            let strongest = onChannel.map { $0.rssi }.max() ?? -100
            let totalInterference = onChannel.count + adjacent.count
            let congestion = congestionLevel(totalInterference, is5GHz: false)

            if totalInterference < lowestCongestion {
                lowestCongestion = totalInterference
                recommended = channel
            }

            analysis.append(ChannelAnalysis(
                channel: channel,
                band: "2.4 GHz",
                networksOnChannel: onChannel.count,
                networksOnAdjacentChannels: adjacent.count,
                strongestCompetitorRSSI: strongest,
                congestionLevel: congestion,
                isRecommended: false
            ))
        }

        // Don't recommend if already on best channel
        if currentBand == .band2GHz && currentChannel == recommended {
            recommended = nil
        }

        // Mark recommended channel
        for i in 0..<analysis.count {
            analysis[i].isRecommended = (analysis[i].channel == recommended)
        }

        return (analysis, recommended)
    }

    private func analyze5GHzChannels(
        neighbors: [NeighboringNetwork],
        currentChannel: Int,
        currentBand: CWChannelBand?
    ) -> ([ChannelAnalysis], Int?) {
        var analysis: [ChannelAnalysis] = []
        var recommended: Int?
        var lowestCongestion = Int.max

        for channel in preferred5GHzChannels {
            let onChannel = neighbors.filter {
                $0.channel == channel && $0.channelBand == "5 GHz"
            }

            let strongest = onChannel.map { $0.rssi }.max() ?? -100
            let congestion = congestionLevel(onChannel.count, is5GHz: true)

            if onChannel.count < lowestCongestion {
                lowestCongestion = onChannel.count
                recommended = channel
            }

            analysis.append(ChannelAnalysis(
                channel: channel,
                band: "5 GHz",
                networksOnChannel: onChannel.count,
                networksOnAdjacentChannels: 0,  // No overlap on 5 GHz
                strongestCompetitorRSSI: strongest,
                congestionLevel: congestion,
                isRecommended: false
            ))
        }

        // Don't recommend if already on best channel
        if currentBand == .band5GHz && currentChannel == recommended {
            recommended = nil
        }

        // Mark recommended channel
        for i in 0..<analysis.count {
            analysis[i].isRecommended = (analysis[i].channel == recommended)
        }

        return (analysis, recommended)
    }

    private func congestionLevel(_ count: Int, is5GHz: Bool) -> String {
        if is5GHz {
            switch count {
            case 0: return "None"
            case 1...2: return "Low"
            case 3...5: return "Medium"
            default: return "High"
            }
        } else {
            switch count {
            case 0: return "None"
            case 1...3: return "Low"
            case 4...7: return "Medium"
            default: return "High"
            }
        }
    }

    // MARK: - String Conversions

    private func bandString(from band: CWChannelBand) -> String {
        switch band {
        case .band2GHz: return "2.4 GHz"
        case .band5GHz: return "5 GHz"
        case .band6GHz: return "6 GHz"
        @unknown default: return "Unknown"
        }
    }

    private func widthValue(from width: CWChannelWidth) -> Int {
        switch width {
        case .width20MHz: return 20
        case .width40MHz: return 40
        case .width80MHz: return 80
        case .width160MHz: return 160
        @unknown default: return 0
        }
    }

    private func phyModeString(from mode: CWPHYMode) -> String {
        switch mode {
        case .mode11a: return "802.11a"
        case .mode11b: return "802.11b"
        case .mode11g: return "802.11g"
        case .mode11n: return "802.11n (Wi-Fi 4)"
        case .mode11ac: return "802.11ac (Wi-Fi 5)"
        case .mode11ax: return "802.11ax (Wi-Fi 6)"
        case .modeNone: return "None"
        @unknown default: return "Unknown"
        }
    }

    private func securityString(from security: CWSecurity) -> String {
        switch security {
        case .none: return "Open (No Security)"
        case .WEP: return "WEP (Insecure)"
        case .wpaPersonal: return "WPA Personal"
        case .wpaEnterprise: return "WPA Enterprise"
        case .wpa2Personal: return "WPA2 Personal"
        case .wpa2Enterprise: return "WPA2 Enterprise"
        case .wpa3Personal: return "WPA3 Personal"
        case .wpa3Enterprise: return "WPA3 Enterprise"
        case .wpa3Transition: return "WPA3 Transition"
        case .dynamicWEP: return "Dynamic WEP"
        case .unknown: return "Unknown"
        @unknown default: return "Unknown"
        }
    }
}
