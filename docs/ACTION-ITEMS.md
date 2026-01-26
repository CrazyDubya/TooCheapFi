# Immediate Action Items

> Prioritized task list for making TooCheapFi production-ready

---

## Priority 1: Critical Path (Required for v1.0)

### 1.1 Add Version Flag Support
**Effort**: 30 minutes | **Impact**: Enables Homebrew, improves UX

- [ ] Add `--version` / `-v` flag to print version
- [ ] Add `--help` / `-h` flag with usage info
- [ ] Add `--check-once` flag for scripting
- [ ] Add `--json` flag for machine-readable output

**File**: `Sources/main.swift`

### 1.2 Create GitHub Actions CI
**Effort**: 1 hour | **Impact**: Automated quality checks

- [ ] Create `.github/workflows/ci.yml`
- [ ] Configure macOS runner with Swift 5.9
- [ ] Add build step
- [ ] Add test step (once tests exist)
- [ ] Add SwiftLint step

### 1.3 Add Unit Tests
**Effort**: 3-4 hours | **Impact**: Code quality, refactoring confidence

- [ ] Update `Package.swift` with test target
- [ ] Create `Tests/NetworkStatusTests.swift`
- [ ] Create `Tests/NetworkMonitorTests.swift`
- [ ] Mock network interfaces for testability
- [ ] Target 80%+ coverage

### 1.4 Create Homebrew Tap
**Effort**: 2 hours | **Impact**: Easy installation

- [ ] Create `CrazyDubya/homebrew-toocheapfi` repository
- [ ] Write `Formula/toocheapfi.rb`
- [ ] Test local installation
- [ ] Document in README

---

## Priority 2: User Value (Differentiating Features)

### 2.1 User Preferences System
**Effort**: 2-3 hours | **Impact**: Customization

- [ ] Create `Sources/Preferences.swift`
- [ ] Define JSON config schema
- [ ] Load/save preferences
- [ ] Integrate with NetworkMonitor
- [ ] Add preferences menu items

**Config options**:
- Check interval (1s, 5s, 10s, 30s)
- Custom DNS servers
- Notification preferences

### 2.2 SQLite History Logging
**Effort**: 4-5 hours | **Impact**: ISP accountability

- [ ] Create `Sources/HistoryStore.swift`
- [ ] Define database schema
- [ ] Implement event recording
- [ ] Implement outage detection
- [ ] Add data retention cleanup

### 2.3 macOS Notifications
**Effort**: 2-3 hours | **Impact**: Proactive alerts

- [ ] Create `Sources/NotificationManager.swift`
- [ ] Request notification permissions
- [ ] Notify on outage start
- [ ] Notify on connection restore
- [ ] Respect user preferences

---

## Priority 3: Polish (Quality of Life)

### 3.1 History Menu UI
**Effort**: 3-4 hours | **Impact**: User visibility

- [ ] Add "Recent Events" submenu
- [ ] Show last 5 outages with duration
- [ ] Add "View Full History..." option
- [ ] Show uptime percentage

### 3.2 GitHub Release Workflow
**Effort**: 1-2 hours | **Impact**: Distribution

- [ ] Create `.github/workflows/release.yml`
- [ ] Build universal binary (arm64 + x86_64)
- [ ] Create release archives
- [ ] Auto-generate release notes

### 3.3 Documentation Updates
**Effort**: 1-2 hours | **Impact**: User onboarding

- [ ] Update README with new features
- [ ] Add Homebrew installation instructions
- [ ] Add configuration documentation
- [ ] Create CHANGELOG.md

---

## Priority 4: Future Foundation (Phase 2 Prep)

### 4.1 Latency Tracking
**Effort**: 2-3 hours | **Impact**: Network quality metrics

- [ ] Measure and store ping latencies
- [ ] Calculate average/p95 latencies
- [ ] Add latency display to menu

### 4.2 Export Functionality
**Effort**: 3-4 hours | **Impact**: ISP accountability

- [ ] Export history to CSV
- [ ] Generate PDF outage report
- [ ] Add "Export..." menu item

### 4.3 Launch at Login
**Effort**: 1-2 hours | **Impact**: User convenience

- [ ] Add SMLoginItemSetEnabled support
- [ ] Add toggle in preferences
- [ ] Handle app updates

---

## Dependency Graph

```
┌─────────────────┐
│  Version Flag   │ ──────────────────────────────────┐
└────────┬────────┘                                   │
         │                                            │
         ▼                                            ▼
┌─────────────────┐                         ┌─────────────────┐
│   GitHub CI     │                         │  Homebrew Tap   │
└────────┬────────┘                         └─────────────────┘
         │
         ▼
┌─────────────────┐
│   Unit Tests    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐     ┌─────────────────┐
│  Preferences    │────▶│  Notifications  │
└────────┬────────┘     └─────────────────┘
         │
         ▼
┌─────────────────┐     ┌─────────────────┐
│ SQLite History  │────▶│  History Menu   │
└────────┬────────┘     └─────────────────┘
         │
         ▼
┌─────────────────┐
│ Export Reports  │
└─────────────────┘
```

---

## Estimated Total Effort

| Priority | Items | Estimated Hours |
|----------|-------|-----------------|
| P1 (Critical) | 4 items | 6-8 hours |
| P2 (Value) | 3 items | 8-11 hours |
| P3 (Polish) | 3 items | 5-8 hours |
| P4 (Future) | 3 items | 6-9 hours |
| **Total** | **13 items** | **25-36 hours** |

---

## Quick Wins (< 1 hour each)

1. [ ] Add version flag (30 min)
2. [ ] Create basic CI workflow (30 min)
3. [ ] Update README with roadmap (30 min)
4. [ ] Create CONTRIBUTING.md (30 min)
5. [ ] Add .swiftlint.yml (15 min)

---

## Definition of Done for v1.0

- [ ] Version flag works (`--version`, `--help`)
- [ ] CI pipeline passes
- [ ] Unit tests exist with >80% coverage
- [ ] Homebrew tap installation works
- [ ] Preferences file supported
- [ ] History logged to SQLite
- [ ] Notifications work
- [ ] README documents all features
- [ ] CHANGELOG.md exists
- [ ] GitHub release created
