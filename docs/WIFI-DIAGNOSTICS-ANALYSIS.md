# Wi-Fi & Home Network Diagnostics Analysis

> What TooCheapFi SHOULD check but doesn't

---

## Executive Summary

The current implementation answers: **"Am I connected?"**

It completely ignores: **"WHY is my connection bad?"**

For a home network diagnostic tool to be truly useful, it needs to diagnose the most common problems users actually face:

1. **Slow Wi-Fi** - Often caused by interference, not ISP issues
2. **Intermittent drops** - Often channel congestion, not router failure
3. **Poor signal in some rooms** - Distance/obstacles, not "internet down"
4. **Competing with neighbors** - Channel overlap issues

---

## What's Missing: Wi-Fi Layer Diagnostics

### 1. Signal Strength (RSSI)

**What it is**: Received Signal Strength Indication, measured in dBm

**Why it matters**: Most "internet is slow" complaints are actually weak Wi-Fi signal

| RSSI | Quality | User Experience |
|------|---------|-----------------|
| -30 to -50 dBm | Excellent | Maximum speed possible |
| -50 to -60 dBm | Good | Reliable for all uses |
| -60 to -70 dBm | Fair | May see slowdowns |
| -70 to -80 dBm | Weak | Frequent issues |
| Below -80 dBm | Unusable | Constant drops |

**macOS API**: `CWInterface.rssiValue()` from CoreWLAN

```swift
import CoreWLAN

func getSignalStrength() -> (rssi: Int, quality: String) {
    guard let interface = CWWiFiClient.shared().interface() else {
        return (0, "No Wi-Fi interface")
    }

    let rssi = interface.rssiValue()

    let quality: String
    switch rssi {
    case -50...0: quality = "Excellent"
    case -60..<(-50): quality = "Good"
    case -70..<(-60): quality = "Fair"
    case -80..<(-70): quality = "Weak"
    default: quality = "Very Weak"
    }

    return (rssi, quality)
}
```

### 2. Noise Level

**What it is**: Background radio interference, measured in dBm

**Why it matters**: High noise = poor signal quality even with strong signal

| Noise | Environment |
|-------|-------------|
| -90 to -100 dBm | Very quiet (rural) |
| -80 to -90 dBm | Normal |
| -70 to -80 dBm | Noisy |
| Above -70 dBm | Very noisy (interference) |

**macOS API**: `CWInterface.noiseMeasurement()` from CoreWLAN

### 3. Signal-to-Noise Ratio (SNR)

**What it is**: RSSI minus Noise level

**Why it matters**: The TRUE indicator of connection quality

| SNR | Quality |
|-----|---------|
| 40+ dB | Excellent |
| 25-40 dB | Good |
| 15-25 dB | Fair |
| 10-15 dB | Poor |
| Below 10 dB | Unusable |

```swift
func getSignalQuality() -> (snr: Int, assessment: String) {
    guard let interface = CWWiFiClient.shared().interface() else {
        return (0, "No interface")
    }

    let rssi = interface.rssiValue()
    let noise = interface.noiseMeasurement()
    let snr = rssi - noise

    let assessment: String
    switch snr {
    case 40...: assessment = "Excellent - No issues expected"
    case 25..<40: assessment = "Good - Should work well"
    case 15..<25: assessment = "Fair - May see occasional slowdowns"
    case 10..<15: assessment = "Poor - Expect frequent issues"
    default: assessment = "Very Poor - Move closer to router"
    }

    return (snr, assessment)
}
```

---

## What's Missing: Channel Analysis

### 4. Current Channel Info

**What it is**: Which Wi-Fi channel you're connected to

**Why it matters**: Some channels are more congested than others

**macOS API**: `CWInterface.wlanChannel()` returns `CWChannel` with:
- `channelNumber` - The channel (1-11 for 2.4GHz, many for 5GHz)
- `channelBand` - 2.4GHz, 5GHz, or 6GHz
- `channelWidth` - 20, 40, 80, or 160 MHz

```swift
func getCurrentChannel() -> (channel: Int, band: String, width: String) {
    guard let interface = CWWiFiClient.shared().interface(),
          let channel = interface.wlanChannel() else {
        return (0, "Unknown", "Unknown")
    }

    let band: String
    switch channel.channelBand {
    case .band2GHz: band = "2.4 GHz"
    case .band5GHz: band = "5 GHz"
    case .band6GHz: band = "6 GHz"
    @unknown default: band = "Unknown"
    }

    let width = "\(channel.channelWidth.rawValue * 20) MHz"

    return (channel.channelNumber, band, width)
}
```

### 5. Neighboring Networks Scan

**What it is**: All Wi-Fi networks visible from your location

**Why it matters**: Identifies channel congestion and interference sources

**macOS API**: `CWInterface.scanForNetworks(withSSID:)`

```swift
func scanNeighboringNetworks() -> [NetworkInfo] {
    guard let interface = CWWiFiClient.shared().interface() else {
        return []
    }

    do {
        let networks = try interface.scanForNetworks(withSSID: nil)
        return networks.map { network in
            NetworkInfo(
                ssid: network.ssid ?? "(Hidden)",
                bssid: network.bssid ?? "",
                rssi: network.rssiValue,
                channel: network.wlanChannel?.channelNumber ?? 0,
                band: network.wlanChannel?.channelBand,
                security: network.securityMode
            )
        }
    } catch {
        return []
    }
}
```

### 6. Channel Congestion Analysis

**What it is**: How many networks are on each channel

**Why it matters**: Overlapping channels cause interference

**2.4 GHz Channel Overlap**:
```
Channel:  1   2   3   4   5   6   7   8   9   10  11
          |-------|       |-------|       |-------|
          Ch 1 range      Ch 6 range      Ch 11 range

Only channels 1, 6, and 11 don't overlap!
```

```swift
struct ChannelAnalysis {
    let channel: Int
    let networksOnChannel: Int
    let networksOnAdjacentChannels: Int
    let strongestCompetitor: Int  // RSSI
    let recommendation: String
}

func analyzeChannelCongestion(networks: [NetworkInfo]) -> [ChannelAnalysis] {
    // For 2.4 GHz, only analyze channels 1, 6, 11
    let recommendedChannels = [1, 6, 11]

    return recommendedChannels.map { channel in
        let onChannel = networks.filter {
            $0.channel == channel && $0.band == .band2GHz
        }

        // Adjacent channels (within 2) cause interference
        let adjacent = networks.filter {
            $0.band == .band2GHz &&
            abs($0.channel - channel) <= 2 &&
            $0.channel != channel
        }

        let strongest = onChannel.map { $0.rssi }.max() ?? -100

        let recommendation: String
        if onChannel.count == 0 {
            recommendation = "Excellent - No competition"
        } else if onChannel.count <= 2 && strongest < -70 {
            recommendation = "Good - Light competition"
        } else if onChannel.count <= 5 {
            recommendation = "Fair - Moderate congestion"
        } else {
            recommendation = "Poor - Heavy congestion"
        }

        return ChannelAnalysis(
            channel: channel,
            networksOnChannel: onChannel.count,
            networksOnAdjacentChannels: adjacent.count,
            strongestCompetitor: strongest,
            recommendation: recommendation
        )
    }
}
```

### 7. Best Channel Recommendation

**Algorithm**:
1. Scan all visible networks
2. For 2.4 GHz: Only consider channels 1, 6, 11
3. For 5 GHz: Consider all non-DFS channels (36-48, 149-165)
4. Score each channel based on:
   - Number of networks (fewer = better)
   - Strongest competitor signal (weaker = better)
   - Adjacent channel interference
5. Recommend the best scoring channel

```swift
func recommendBestChannel(currentBand: CWChannelBand) -> (channel: Int, reason: String) {
    let networks = scanNeighboringNetworks()

    if currentBand == .band2GHz {
        // Only 1, 6, 11 are valid
        let analysis = analyzeChannelCongestion(networks: networks)

        // Score: fewer networks + weaker competitors = better
        let best = analysis.min { a, b in
            let scoreA = a.networksOnChannel * 10 + (100 + a.strongestCompetitor)
            let scoreB = b.networksOnChannel * 10 + (100 + b.strongestCompetitor)
            return scoreA < scoreB
        }

        return (best?.channel ?? 6, best?.recommendation ?? "Default to channel 6")
    } else {
        // 5 GHz has many options
        // Prefer channels 36-48 (UNII-1) as they don't require DFS
        let preferredChannels = [36, 40, 44, 48, 149, 153, 157, 161, 165]

        let channelCounts = Dictionary(grouping: networks.filter {
            $0.band == .band5GHz
        }) { $0.channel }

        let best = preferredChannels.min { a, b in
            (channelCounts[a]?.count ?? 0) < (channelCounts[b]?.count ?? 0)
        }

        return (best ?? 36, "Least congested 5 GHz channel")
    }
}
```

---

## What's Missing: Interference Detection

### 8. Non-Wi-Fi Interference Sources

**Common household interference**:
- Microwave ovens (2.4 GHz)
- Bluetooth devices (2.4 GHz)
- Baby monitors (various)
- Cordless phones (2.4 GHz)
- Wireless cameras (2.4 GHz)
- USB 3.0 devices (can emit 2.4 GHz noise!)

**Detection approach**: Monitor noise floor spikes during interference events

```swift
func detectInterference() -> InterferenceReport {
    // Take multiple noise samples over time
    var noiseSamples: [Int] = []

    for _ in 0..<10 {
        if let interface = CWWiFiClient.shared().interface() {
            noiseSamples.append(interface.noiseMeasurement())
        }
        Thread.sleep(forTimeInterval: 0.5)
    }

    let avgNoise = noiseSamples.reduce(0, +) / noiseSamples.count
    let maxNoise = noiseSamples.max() ?? -100
    let variance = noiseSamples.map { ($0 - avgNoise) * ($0 - avgNoise) }
                               .reduce(0, +) / noiseSamples.count

    var sources: [String] = []

    // High variance suggests intermittent interference
    if variance > 25 {
        sources.append("Intermittent interference detected (microwave? Bluetooth?)")
    }

    // High average noise suggests constant interference
    if avgNoise > -80 {
        sources.append("High background noise - check for nearby electronics")
    }

    return InterferenceReport(
        averageNoise: avgNoise,
        peakNoise: maxNoise,
        variance: variance,
        likelySources: sources,
        recommendation: variance > 25 ? "Try 5 GHz band to avoid interference" : "Noise levels acceptable"
    )
}
```

### 9. Co-Channel vs Adjacent-Channel Interference

**Co-channel interference**: Multiple networks on SAME channel
- Devices take turns (CSMA/CA protocol)
- Slows everyone down but works

**Adjacent-channel interference**: Networks on OVERLAPPING channels
- Treated as noise, not as valid signals
- Causes packet corruption and retransmissions
- WORSE than co-channel!

**This is why only channels 1, 6, 11 should be used on 2.4 GHz**

```swift
func analyzeInterferenceType(currentChannel: Int, networks: [NetworkInfo]) -> String {
    let sameChannel = networks.filter { $0.channel == currentChannel }
    let adjacent = networks.filter {
        abs($0.channel - currentChannel) <= 2 &&
        $0.channel != currentChannel
    }

    if adjacent.count > sameChannel.count {
        return """
        WARNING: Adjacent-channel interference detected!

        You have \(adjacent.count) networks on overlapping channels.
        This is WORSE than sharing a channel.

        Recommendation: Switch to channel 1, 6, or 11 (whichever has
        the fewest networks). It's better to share a channel than
        use an overlapping one.
        """
    } else if sameChannel.count > 5 {
        return """
        Heavy co-channel congestion detected.

        \(sameChannel.count) networks sharing your channel.
        Consider switching to 5 GHz for less congestion.
        """
    }

    return "Channel interference is within acceptable levels"
}
```

---

## What's Missing: Connection Quality Metrics

### 10. Transmit Rate

**What it is**: The current link speed in Mbps

**Why it matters**: Shows actual vs theoretical performance

**macOS API**: `CWInterface.transmitRate()` returns Double (Mbps)

```swift
func getConnectionSpeed() -> (rate: Double, assessment: String) {
    guard let interface = CWWiFiClient.shared().interface() else {
        return (0, "No interface")
    }

    let rate = interface.transmitRate()  // Mbps

    let assessment: String
    switch rate {
    case 300...: assessment = "Excellent (Wi-Fi 5/6 speeds)"
    case 100..<300: assessment = "Good"
    case 50..<100: assessment = "Fair"
    case 10..<50: assessment = "Slow - check signal strength"
    default: assessment = "Very slow - likely far from router"
    }

    return (rate, assessment)
}
```

### 11. PHY Mode (Wi-Fi Standard)

**What it is**: Which 802.11 standard is being used

**Why it matters**: Older standards = slower speeds

| PHY Mode | Max Speed | Notes |
|----------|-----------|-------|
| 802.11b | 11 Mbps | Ancient |
| 802.11g | 54 Mbps | Old |
| 802.11n (Wi-Fi 4) | 600 Mbps | Common |
| 802.11ac (Wi-Fi 5) | 3.5 Gbps | Modern |
| 802.11ax (Wi-Fi 6) | 9.6 Gbps | Latest |

**macOS API**: `CWInterface.activePHYMode()`

```swift
func getWiFiStandard() -> String {
    guard let interface = CWWiFiClient.shared().interface() else {
        return "Unknown"
    }

    switch interface.activePHYMode() {
    case .mode11a: return "802.11a (legacy)"
    case .mode11b: return "802.11b (very slow)"
    case .mode11g: return "802.11g (slow)"
    case .mode11n: return "802.11n (Wi-Fi 4)"
    case .mode11ac: return "802.11ac (Wi-Fi 5)"
    case .mode11ax: return "802.11ax (Wi-Fi 6)"
    @unknown default: return "Unknown"
    }
}
```

### 12. Security Assessment

**What it is**: Which security protocol is being used

**Why it matters**: Older protocols are vulnerable

| Security | Status |
|----------|--------|
| Open | DANGEROUS - No encryption |
| WEP | BROKEN - Easily cracked |
| WPA | Weak - Deprecated |
| WPA2 | Good - Current standard |
| WPA3 | Best - Latest standard |

**macOS API**: `CWInterface.security()`

---

## What's Missing: Actionable Recommendations

### Current Problem

TooCheapFi says: "Wi-Fi: Connected"

It should say:
```
Wi-Fi: Connected (Fair Quality)
├─ Signal: -68 dBm (Weak - try moving closer)
├─ Noise: -85 dBm (Normal)
├─ SNR: 17 dB (Fair)
├─ Channel: 6 (2.4 GHz) - 8 other networks
├─ Speed: 72 Mbps (Below potential)
├─ Standard: 802.11n
│
├─ Issues Detected:
│  ⚠️ Weak signal strength
│  ⚠️ Channel congestion (8 networks)
│  ⚠️ Using 2.4 GHz when 5 GHz available
│
└─ Recommendations:
   1. Move closer to your router (signal is weak)
   2. Switch to 5 GHz band for less interference
   3. If staying on 2.4 GHz, channel 1 has only 3 networks
```

### Proposed Diagnostic Output

```swift
struct WiFiDiagnosticReport {
    // Signal Quality
    let rssi: Int
    let noise: Int
    let snr: Int
    let signalQuality: Quality  // excellent/good/fair/poor

    // Connection Details
    let ssid: String
    let bssid: String
    let channel: Int
    let band: Band
    let channelWidth: Int
    let phyMode: PHYMode
    let transmitRate: Double
    let security: Security

    // Environment Analysis
    let neighboringNetworks: Int
    let networksOnSameChannel: Int
    let channelCongestion: Congestion
    let bestAlternativeChannel: Int?
    let interferenceDetected: Bool

    // Issues & Recommendations
    let issues: [Issue]
    let recommendations: [Recommendation]

    // Overall Score
    let overallScore: Int  // 0-100
}

enum Issue {
    case weakSignal(rssi: Int)
    case highNoise(noise: Int)
    case channelCongestion(count: Int)
    case adjacentChannelInterference
    case using24GHzWhen5GHzAvailable
    case legacyPHYMode(mode: String)
    case weakSecurity(type: String)
    case lowTransmitRate(rate: Double)
}

enum Recommendation {
    case moveCloserToRouter
    case switchTo5GHz
    case changeChannel(to: Int, reason: String)
    case checkForInterference
    case upgradeRouter
    case updateSecurityToWPA3
    case rebootRouter
}
```

---

## Implementation Priority

### Phase 1: Basic Wi-Fi Quality (High Impact, Low Effort)

| Feature | Effort | Value |
|---------|--------|-------|
| Signal strength (RSSI) display | 1 hour | Very High |
| Noise level display | 30 min | High |
| SNR calculation | 30 min | Very High |
| Current channel info | 30 min | High |
| Transmit rate display | 30 min | Medium |

**User sees**: "Your signal is weak (-72 dBm). Move closer to router."

### Phase 2: Channel Analysis (High Impact, Medium Effort)

| Feature | Effort | Value |
|---------|--------|-------|
| Scan neighboring networks | 2 hours | Very High |
| Channel congestion analysis | 2 hours | Very High |
| Best channel recommendation | 3 hours | Very High |
| Adjacent interference warning | 1 hour | High |

**User sees**: "Channel 6 has 12 networks. Channel 1 only has 3. Consider switching."

### Phase 3: Advanced Diagnostics (Medium Impact, Higher Effort)

| Feature | Effort | Value |
|---------|--------|-------|
| Interference detection | 3 hours | Medium |
| 5 GHz recommendation | 2 hours | High |
| Security assessment | 1 hour | Medium |
| Historical signal tracking | 4 hours | Medium |

**User sees**: "Intermittent interference detected. Possible microwave or Bluetooth. Try 5 GHz."

---

## Complete Feature Comparison

| Feature | Current | Proposed |
|---------|---------|----------|
| Interface connected? | ✅ | ✅ |
| Gateway reachable? | ✅ | ✅ |
| Internet reachable? | ✅ | ✅ (multiple targets) |
| DNS working? | ✅ | ✅ (multiple domains) |
| Signal strength | ❌ | ✅ RSSI + quality |
| Noise level | ❌ | ✅ dBm + assessment |
| SNR | ❌ | ✅ With interpretation |
| Channel info | ❌ | ✅ Channel, band, width |
| Neighboring networks | ❌ | ✅ Full scan |
| Channel congestion | ❌ | ✅ Per-channel analysis |
| Best channel | ❌ | ✅ Recommendation |
| Interference detection | ❌ | ✅ Noise monitoring |
| Transmit rate | ❌ | ✅ Current speed |
| Wi-Fi standard | ❌ | ✅ PHY mode |
| Security check | ❌ | ✅ WPA2/WPA3 |
| Captive portal | ❌ | ✅ HTTP check |
| Latency | ❌ | ✅ Ping times |
| Packet loss | ❌ | ✅ Multiple pings |
| Overall score | ❌ | ✅ 0-100 rating |
| Actionable recommendations | Partial | ✅ Specific steps |

---

## Menu Bar Display (Proposed)

```
┌─────────────────────────────────────────────┐
│  TooCheapFi                                 │
├─────────────────────────────────────────────┤
│  Overall: Good (78/100)                     │
├─────────────────────────────────────────────┤
│  📶 Wi-Fi: MyNetwork                        │
│     Signal: -58 dBm (Good)                  │
│     Channel: 6 (2.4 GHz, 40 MHz)            │
│     Speed: 144 Mbps (Wi-Fi 5)               │
├─────────────────────────────────────────────┤
│  🌐 Internet: Connected                     │
│     Latency: 23 ms                          │
│     Gateway: 192.168.1.1 ✓                  │
│     DNS: Working ✓                          │
├─────────────────────────────────────────────┤
│  ⚠️ Issues:                                 │
│     • 7 networks on channel 6               │
│     • 5 GHz available but not used          │
├─────────────────────────────────────────────┤
│  💡 Recommendations:                        │
│     • Switch to 5 GHz for better speed      │
│     • Channel 1 has less congestion         │
├─────────────────────────────────────────────┤
│  📊 Analyze Channel... (scan takes 10 sec)  │
│  📈 View History...                         │
│  ⚙️ Preferences...                          │
│  ─────────────────────────────────────────  │
│  Refresh (⌘R)              Quit (⌘Q)        │
└─────────────────────────────────────────────┘
```

---

## Sources & References

- [macOS CoreWLAN Framework](https://developer.apple.com/documentation/corewlan)
- [Apple Developer Forums - Wi-Fi Signal Strength](https://developer.apple.com/forums/thread/107046)
- [Best Wi-Fi Channels Guide](https://broadbandnow.com/guides/best-wi-fi-channels)
- [Wi-Fi Channel Scanning Guide](https://www.netally.com/tech-tips/wifi-channel-scanning-a-guide-to-wifi-channels/)
- [macOS airport command](https://osxdaily.com/2010/07/07/test-wireless-signal-strength-from-the-command-line/)
- [Wi-Fi Channel Interference](https://eyenetworks.no/en/locating-good-channels-bad-neighbors-wi-fi-scanner/)
- [Channel Width Recommendations](https://www.intel.com/content/www/us/en/support/articles/000058989/wireless/intel-killer-wi-fi-products.html)

---

## Conclusion

The current implementation treats Wi-Fi as a binary: connected or not.

Real users need:
1. **"Why is my Wi-Fi slow?"** → Signal strength, channel congestion
2. **"Why do I keep disconnecting?"** → Interference, weak signal
3. **"What channel should I use?"** → Neighbor analysis
4. **"Is my router the problem?"** → Speed and standard info

Adding these features would transform TooCheapFi from "is it working?" to "here's how to make it better" - which is what users actually need.
