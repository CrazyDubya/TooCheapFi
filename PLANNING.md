# TooCheapFi Strategic Planning Document

> **Document Version**: 1.0
> **Created**: January 2026
> **Purpose**: Transform TooCheapFi from a simple network monitor into a genuinely useful, widely-adopted tool

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Current State Analysis](#current-state-analysis)
3. [Competitive Landscape](#competitive-landscape)
4. [Market Opportunity](#market-opportunity)
5. [Strategic Vision](#strategic-vision)
6. [Product Roadmap](#product-roadmap)
7. [Technical Architecture](#technical-architecture)
8. [Distribution Strategy](#distribution-strategy)
9. [Success Metrics](#success-metrics)
10. [Risk Assessment](#risk-assessment)

---

## Executive Summary

### The Problem
Network connectivity issues are one of the most frustrating experiences for computer users. When the internet stops working, most users don't know if the problem is:
- Their Wi-Fi adapter
- Their router
- Their ISP
- DNS servers
- The specific website/service they're trying to reach

### Current Solution
TooCheapFi currently provides basic 4-layer network diagnostics in a macOS menu bar app. It works, but it's limited to a single platform, lacks user customization, has no history tracking, and is difficult to install.

### The Opportunity
There's a gap in the market for a **free, open-source, privacy-respecting network diagnostic tool** that:
- Works across platforms (macOS, Windows, Linux)
- Provides actionable diagnostics, not just "you're offline"
- Tracks connectivity history for identifying patterns
- Helps users communicate with ISPs about outages
- Is dead-simple to install and use

### Recommended Strategy
Transform TooCheapFi into a **multi-platform network health dashboard** with intelligent diagnostics, outage tracking, and ISP accountability features. Phase the approach to deliver value incrementally while building toward a comprehensive solution.

---

## Current State Analysis

### What TooCheapFi Does Today

| Capability | Status | Quality |
|------------|--------|---------|
| Wi-Fi interface detection | ✅ Implemented | Good |
| Router connectivity test | ✅ Implemented | Good |
| Internet connectivity test (8.8.8.8) | ✅ Implemented | Good |
| DNS resolution test | ✅ Implemented | Good |
| Menu bar integration | ✅ Implemented | Good |
| Actionable fix suggestions | ✅ Implemented | Good |
| Automatic refresh on network change | ✅ Implemented | Good |

### What TooCheapFi Lacks

| Capability | Impact | Priority |
|------------|--------|----------|
| Cross-platform support | Limits audience to ~15% of users | HIGH |
| User preferences/settings | No customization possible | HIGH |
| Outage history tracking | Can't prove ISP outages | HIGH |
| Notifications | Users must look at menu bar | MEDIUM |
| Easy installation (Homebrew, etc.) | Friction to adopt | MEDIUM |
| Bandwidth/latency testing | Limited diagnostic depth | MEDIUM |
| Multiple network support | Can't compare Wi-Fi vs Ethernet | LOW |
| Unit tests | No quality assurance | MEDIUM |

### Technical Debt & Gaps

1. **No tests** - Zero unit or integration tests
2. **Hardcoded values** - Check interval (5s), ping timeout (2s), DNS servers (8.8.8.8)
3. **Single-platform** - Swift/Cocoa locks us to macOS
4. **No persistence** - Nothing survives app restart
5. **No configuration file** - Can't customize without code changes

---

## Competitive Landscape

### Commercial Competitors

| Product | Price | Strengths | Weaknesses |
|---------|-------|-----------|------------|
| **iStat Menus** | $15 | Comprehensive system monitoring, beautiful UI, per-app bandwidth | Paid, no diagnostics/troubleshooting |
| **PeakHour** | $10 | Network-focused, history tracking, ISP reports | Paid, macOS only |
| **Little Snitch** | $69 | Deep packet inspection, security-focused | Expensive, complex, not for troubleshooting |
| **CleanMyMac** | $90/yr | All-in-one, polished | Expensive, network is minor feature |

### Open Source Competitors

| Project | Platform | Stars | Strengths | Weaknesses |
|---------|----------|-------|-----------|------------|
| **Stats** | macOS | 25k+ | Free, system-wide monitoring | No network diagnostics |
| **Netiquette** | macOS | 1k+ | Security-focused, shows connections | No troubleshooting |
| **NetSpeedMonitor** | macOS | 200+ | Minimal, speed-focused | No diagnostics |
| **Sniffnet** | Cross-platform | 15k+ | Beautiful GUI, packet analysis | Complex, overkill for basic users |
| **RustNet** | Cross-platform | New | TUI, deep inspection | Developer-focused, steep learning curve |

### Key Insight: The Gap

**No free tool exists that combines:**
1. Simple, approachable UI for non-technical users
2. Actionable network troubleshooting (not just monitoring)
3. Outage history for ISP accountability
4. Cross-platform availability
5. Privacy-respecting (local-only)

**This is our opportunity.**

---

## Market Opportunity

### Target Users

#### Primary: Home Users Frustrated with ISPs
- **Pain point**: "My internet keeps dropping and my ISP says nothing is wrong"
- **Need**: Proof of outages with timestamps, duration, and frequency
- **Solution**: Outage history with exportable reports

#### Secondary: Remote Workers
- **Pain point**: "I need reliable internet for video calls"
- **Need**: Early warning of connectivity issues, connection quality metrics
- **Solution**: Proactive notifications, latency/jitter monitoring

#### Tertiary: IT Support / Help Desks
- **Pain point**: "Users say 'the internet is broken' with no details"
- **Need**: Quick diagnostic tool to identify the actual problem layer
- **Solution**: Shareable diagnostic reports

### Market Size Indicators

- **macOS users**: ~100 million active devices
- **Homebrew installs**: iStat Menus has 25k+ GitHub stars
- **"Network not working" searches**: Consistently high volume
- **ISP complaint forums**: Extremely active (indicates unmet need)

### Differentiation Strategy

| Competitor Approach | Our Approach |
|--------------------|--------------|
| Show metrics | Explain problems |
| Monitor passively | Diagnose actively |
| Technical audience | Everyone |
| Paid / Freemium | Free and open source |
| Single platform | Cross-platform |
| Cloud-connected | Privacy-first (local only) |

---

## Strategic Vision

### Mission Statement

> **Make network troubleshooting accessible to everyone by providing clear, actionable diagnostics that empower users to understand and resolve connectivity issues.**

### Product Vision (12-month)

TooCheapFi becomes the go-to tool for:
1. **Instant diagnosis** - Know exactly what's wrong in seconds
2. **ISP accountability** - Prove outages with data
3. **Cross-platform** - Works wherever you do
4. **Zero friction** - Install with one command, works immediately

### Core Principles

1. **Clarity over complexity** - A confused user is a failed user
2. **Local-first** - Never send user data anywhere
3. **Actionable over informational** - Always tell users what to DO
4. **Cross-platform parity** - Same great experience everywhere
5. **Open source sustainability** - Community-driven development

---

## Product Roadmap

### Phase 1: Foundation (Current → Solid)
**Goal**: Make the current macOS app production-ready and easy to install

| Feature | Description | Effort |
|---------|-------------|--------|
| Homebrew formula | `brew install toocheapfi` | Small |
| User preferences | Check interval, custom DNS servers | Medium |
| Unit tests | Test NetworkMonitor logic | Medium |
| Outage logging | SQLite-based local history | Medium |
| Basic notifications | macOS native notifications | Small |

**Deliverable**: Version 1.0 - Polished macOS app available via Homebrew

### Phase 2: Intelligence (Useful → Valuable)
**Goal**: Add features that make the tool indispensable

| Feature | Description | Effort |
|---------|-------------|--------|
| Outage history UI | View past connectivity events | Medium |
| Latency tracking | Measure and graph ping times | Medium |
| ISP report export | Generate PDF/CSV outage reports | Medium |
| Connectivity score | Simple 1-100 network health rating | Small |
| Smart notifications | Alert patterns, not every blip | Medium |

**Deliverable**: Version 2.0 - The ISP accountability tool

### Phase 3: Expansion (macOS → Everywhere)
**Goal**: Reach users on all platforms

| Feature | Description | Effort |
|---------|-------------|--------|
| CLI core (Rust) | Cross-platform diagnostic engine | Large |
| Linux support | First-class Linux desktop/server support | Medium |
| Windows support | System tray integration | Medium |
| Shared history | Sync history across devices (optional, encrypted) | Large |

**Deliverable**: Version 3.0 - Cross-platform network diagnostics

### Phase 4: Community (Tool → Platform)
**Goal**: Enable community contributions and integrations

| Feature | Description | Effort |
|---------|-------------|--------|
| Plugin system | Custom diagnostic checks | Large |
| Home Assistant integration | Smart home connectivity monitoring | Medium |
| API endpoint | Local REST API for scripting | Small |
| Community diagnostic rules | Shared troubleshooting knowledge | Medium |

**Deliverable**: Version 4.0 - Extensible platform

---

## Technical Architecture

### Current Architecture (Phase 1)

```
┌─────────────────────────────────────────────────────────┐
│                    macOS Menu Bar                        │
│                   (main.swift - Cocoa)                   │
├─────────────────────────────────────────────────────────┤
│                  NetworkMonitor.swift                    │
│    ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐     │
│    │ Wi-Fi   │ │ Router  │ │  ISP    │ │  DNS    │     │
│    │ Check   │ │ Ping    │ │ Ping    │ │ Resolve │     │
│    └─────────┘ └─────────┘ └─────────┘ └─────────┘     │
├─────────────────────────────────────────────────────────┤
│              macOS System Frameworks                     │
│     SystemConfiguration │ Network │ Foundation          │
└─────────────────────────────────────────────────────────┘
```

### Target Architecture (Phase 3+)

```
┌──────────────────────────────────────────────────────────────────┐
│                        Native UI Layer                            │
│   ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│   │ macOS Menu  │  │ Windows     │  │ Linux System Tray       │  │
│   │ Bar (Swift) │  │ Tray (C#)   │  │ (GTK/Qt)                │  │
│   └──────┬──────┘  └──────┬──────┘  └───────────┬─────────────┘  │
└──────────┼────────────────┼─────────────────────┼────────────────┘
           │                │                     │
           ▼                ▼                     ▼
┌──────────────────────────────────────────────────────────────────┐
│                    Core Diagnostic Engine                         │
│                        (Rust Library)                             │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                     Diagnostic Checks                        │ │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌───────┐ │ │
│  │  │Interface│ │ Gateway │ │Internet │ │  DNS    │ │Latency│ │ │
│  │  │ Check   │ │  Ping   │ │  Ping   │ │ Resolve │ │ Track │ │ │
│  │  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └───────┘ │ │
│  └─────────────────────────────────────────────────────────────┘ │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                    History & Analytics                       │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │ │
│  │  │ SQLite Store │  │ Event Logger │  │ Report Generator │  │ │
│  │  └──────────────┘  └──────────────┘  └──────────────────┘  │ │
│  └─────────────────────────────────────────────────────────────┘ │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                      Configuration                           │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │ │
│  │  │  TOML Config │  │  CLI Parser  │  │  FFI Bindings    │  │ │
│  │  └──────────────┘  └──────────────┘  └──────────────────┘  │ │
│  └─────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
```

### Why Rust for Core?

1. **Cross-platform** - Single codebase for all platforms
2. **Performance** - Low latency for real-time monitoring
3. **Safety** - Memory safety without garbage collection
4. **FFI** - Easy bindings to Swift, C#, Python
5. **Ecosystem** - Excellent networking libraries (tokio, trust-dns)
6. **Credibility** - Rust signals quality to developers

### Data Model

```sql
-- Core event storage
CREATE TABLE connectivity_events (
    id INTEGER PRIMARY KEY,
    timestamp DATETIME NOT NULL,
    event_type TEXT NOT NULL,  -- 'check', 'outage_start', 'outage_end'
    wifi_status TEXT,          -- 'ok', 'no_interface', 'no_ip'
    router_status TEXT,        -- 'ok', 'unreachable', 'timeout'
    isp_status TEXT,           -- 'ok', 'unreachable', 'timeout'
    dns_status TEXT,           -- 'ok', 'failed', 'timeout'
    latency_ms INTEGER,
    details TEXT               -- JSON for additional context
);

-- Aggregated outage records
CREATE TABLE outages (
    id INTEGER PRIMARY KEY,
    start_time DATETIME NOT NULL,
    end_time DATETIME,
    duration_seconds INTEGER,
    affected_layer TEXT,       -- 'wifi', 'router', 'isp', 'dns'
    cause TEXT
);

-- User configuration
CREATE TABLE config (
    key TEXT PRIMARY KEY,
    value TEXT
);
```

---

## Distribution Strategy

### Phase 1: macOS Homebrew

**Primary**: Homebrew formula
```bash
brew install toocheapfi
```

**Benefits**:
- Developers already use Homebrew
- Automatic updates
- Trust signal (vetted by Homebrew)
- No signing/notarization needed for CLI

**Implementation**:
1. Create Homebrew tap: `homebrew-toocheapfi`
2. Write formula with release binary download
3. Submit to homebrew-core once established

### Phase 2: Multi-Platform Package Managers

| Platform | Distribution | Command |
|----------|--------------|---------|
| macOS | Homebrew | `brew install toocheapfi` |
| Linux (Debian/Ubuntu) | .deb + PPA | `apt install toocheapfi` |
| Linux (Fedora/RHEL) | .rpm + COPR | `dnf install toocheapfi` |
| Linux (Arch) | AUR | `yay -S toocheapfi` |
| Windows | Winget | `winget install toocheapfi` |
| Windows | Chocolatey | `choco install toocheapfi` |
| All | Cargo | `cargo install toocheapfi` |

### Phase 3: GUI Distribution

| Platform | Format | Notes |
|----------|--------|-------|
| macOS | .dmg + Homebrew Cask | Notarized, code-signed |
| Windows | .msi + Microsoft Store | Code-signed |
| Linux | Flatpak + AppImage | Universal packaging |

### Marketing Channels

1. **GitHub** - Primary project home, releases, discussions
2. **Hacker News** - Launch announcements
3. **Reddit** - r/macapps, r/selfhosted, r/homelab, r/sysadmin
4. **Product Hunt** - Version 2.0 launch
5. **Tech blogs** - OMG Ubuntu, It's FOSS, etc.

---

## Success Metrics

### Phase 1 Success Criteria

| Metric | Target | Measurement |
|--------|--------|-------------|
| GitHub stars | 500+ | GitHub API |
| Homebrew installs | 1,000+ | Homebrew analytics |
| GitHub issues (bugs) | <10 open | GitHub |
| Test coverage | >80% | CI pipeline |

### Phase 2 Success Criteria

| Metric | Target | Measurement |
|--------|--------|-------------|
| GitHub stars | 2,000+ | GitHub API |
| Monthly active users | 5,000+ | Anonymous telemetry (opt-in) |
| ISP reports generated | 1,000+ | Local counter (opt-in) |
| Community contributors | 10+ | GitHub |

### Phase 3 Success Criteria

| Metric | Target | Measurement |
|--------|--------|-------------|
| GitHub stars | 10,000+ | GitHub API |
| Monthly active users | 50,000+ | Anonymous telemetry |
| Platform distribution | 40% macOS, 40% Linux, 20% Windows | Telemetry |
| Package manager availability | 10+ | Manual count |

---

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Rust learning curve | Medium | High | Start with Swift improvements first |
| Platform-specific bugs | High | Medium | Extensive platform testing, CI matrix |
| Performance issues | Low | Medium | Benchmark tests, profiling |
| Dependency vulnerabilities | Medium | High | Regular audits, minimal dependencies |

### Market Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| No user adoption | Medium | Critical | Validate with early users before big investments |
| Competitor copies features | Medium | Low | Move fast, build community moat |
| Apple/Microsoft changes break app | Low | High | Monitor platform changes, maintain alternatives |

### Operational Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Maintainer burnout | Medium | Critical | Build contributor community early |
| No contributors | Medium | High | Clear contribution guidelines, welcoming culture |
| Trademark issues with "Fi" | Low | Medium | Research before major marketing |

---

## Immediate Next Steps

### This Week
1. [ ] Add unit tests for NetworkMonitor
2. [ ] Create Homebrew formula and tap
3. [ ] Add basic SQLite history logging
4. [ ] Add user preferences file support

### This Month
1. [ ] Implement outage history UI in menu
2. [ ] Add macOS native notifications
3. [ ] Create GitHub release workflow
4. [ ] Write CONTRIBUTING.md guidelines

### This Quarter
1. [ ] Launch v1.0 on Homebrew
2. [ ] Gather user feedback
3. [ ] Begin Rust core prototype
4. [ ] Design cross-platform architecture

---

## Appendix: Research Sources

### Network Monitoring Market
- [Best Network Monitoring Software for Mac](https://www.macobserver.com/macos/best-software/best-network-monitoring-software-for-mac/)
- [PeakHour Bandwidth Monitoring](https://peakhourapp.com/)
- [Network Troubleshooting Tools 2026](https://obkio.com/blog/network-troubleshooting-tools/)

### Open Source Alternatives
- [Netiquette by Objective-See](https://github.com/objective-see/Netiquette)
- [NetSpeedMonitor](https://github.com/elegracer/NetSpeedMonitor)
- [Sniffnet](https://crates.io/crates/sniffnet)
- [RustNet](https://github.com/domcyrus/rustnet)

### Distribution
- [Homebrew Swift Distribution](https://nshipster.com/homebrew/)
- [Homebrew Cask Documentation](https://docs.brew.sh/Cask-Cookbook)

### Cross-Platform Development
- [RustNet Cross-Platform Monitor](https://www.linuxlinks.com/rustnet-cross-platform-network-monitoring-tool/)
- [Network Monitoring GitHub Topics](https://github.com/topics/network-monitoring?l=rust)

---

*This document should be reviewed and updated quarterly as the project evolves.*
