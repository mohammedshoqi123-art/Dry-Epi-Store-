# EPI-Supervisor — Offline-First Sync System v2

## 📋 Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [Sequence Diagram](#sequence-diagram)
3. [File Map](#file-map)
4. [Configuration](#configuration)
5. [Deployment Checklist](#deployment-checklist)
6. [Risk Warnings](#risk-warnings)
7. [Test Scenarios](#test-scenarios)

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────────┐
│                     FLUTTER APP (Client)                         │
│                                                                  │
│  ┌─────────────┐    ┌───────────────────┐    ┌───────────────┐  │
│  │ Form Screen  │───▶│ IntelligentOffline│───▶│ ProductionSync│  │
│  │ (Field Work) │    │ Manager           │    │ Queue (v2)    │  │
│  └─────────────┘    │                   │    │               │  │
│                      │ • Connectivity    │    │ • Priority    │  │
│  ┌─────────────┐    │ • Auto-sync       │    │ • Backoff     │  │
│  │ SyncStatus   │◀──│ • Conflict resolve│    │ • Dead-letter │  │
│  │ Widgets      │    │ • Batch submit    │    │ • Encryption  │  │
│  └─────────────┘    └────────┬──────────┘    └───────────────┘  │
│                              │                                   │
│  ┌───────────────────────────┴───────────────────────────────┐  │
│  │                    Hive Storage (Encrypted)                │  │
│  │  epi_sync_queue_v2 │ epi_sync_failed │ epi_offline        │  │
│  └───────────────────────────────────────────────────────────┘  │
└──────────────────────────────┬───────────────────────────────────┘
                               │ HTTPS (batch of ≤50 items)
                               ▼
┌──────────────────────────────────────────────────────────────────┐
│                    SUPABASE EDGE FUNCTION                         │
│                    sync-offline (v2)                              │
│                                                                  │
│  1. Authenticate user (JWT)                                      │
│  2. Validate batch size (≤50)                                    │
│  3. Pre-fetch existing offline_ids (ONE query)                   │
│  4. Pre-fetch server versions for updates (ONE query)            │
│  5. For each item:                                               │
│     ├─ Duplicate? → status=duplicate                             │
│     ├─ Conflict? → status=conflict + server_data                 │
│     └─ New? → INSERT + audit log → status=synced                 │
│  6. Return per-item results + summary                            │
└──────────────────────────────┬───────────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────────┐
│                      SUPABASE DATABASE                           │
│                                                                  │
│  form_submissions │ audit_logs │ profiles │ RLS policies         │
└──────────────────────────────────────────────────────────────────┘
```

---

## Sequence Diagram

### Happy Path: Online Form Submission
```
User          FormScreen       OfflineMgr        Queue           EdgeFn         DB
 │                │                │               │               │              │
 │ Fill form      │                │               │               │              │
 │───────────────▶│                │               │               │              │
 │                │ enqueue()      │               │               │              │
 │                │───────────────▶│               │               │              │
 │                │                │ save encrypted│               │              │
 │                │                │──────────────▶│               │              │
 │                │◀───────────────│ id returned   │               │              │
 │ "Saved!"       │                │               │               │              │
 │◀───────────────│                │               │               │              │
 │                │                │               │               │              │
 │ ... network available ...       │               │               │              │
 │                │                │               │               │              │
 │                │                │ getBatch(50)  │               │              │
 │                │                │──────────────▶│               │              │
 │                │                │◀──────────────│ items[]       │              │
 │                │                │               │               │              │
 │                │                │ POST /sync-offline            │              │
 │                │                │──────────────────────────────▶│              │
 │                │                │               │  check dupes  │              │
 │                │                │               │──────────────▶│              │
 │                │                │               │◀──────────────│              │
 │                │                │               │  INSERT       │              │
 │                │                │               │──────────────▶│              │
 │                │                │               │◀──────────────│              │
 │                │                │ results[]     │               │              │
 │                │                │◀──────────────────────────────│              │
 │                │                │ markCompleted()               │              │
 │                │                │──────────────▶│               │              │
 │                │                │ emit: 🟢 synced               │              │
 │◀───────────────────────────────│               │               │              │
```

### Offline → Reconnect Path
```
User          FormScreen       OfflineMgr        Queue           EdgeFn
 │                │                │               │               │
 │ Fill 10 forms  │                │               │               │
 │ (offline)      │                │               │               │
 │───────────────▶│ enqueue ×10   │               │               │
 │                │───────────────▶│               │               │
 │                │                │ save ×10      │               │
 │                │                │──────────────▶│               │
 │                │ emit: 🔴 10 pending             │               │
 │◀───────────────────────────────│               │               │
 │                │                │               │               │
 │ ... 2 hours pass, network returns ...          │               │
 │                │                │               │               │
 │                │                │ onConnectivityChanged         │
 │                │                │───┐           │               │
 │                │                │   │ delay 3s  │               │
 │                │                │◀──┘           │               │
 │                │                │               │               │
 │                │                │ syncNow()     │               │
 │                │                │──────────────▶│               │
 │                │                │               │  batch(10)    │
 │                │                │──────────────────────────────▶│
 │                │                │               │  results[]    │
 │                │                │◀──────────────────────────────│
 │                │                │ markCompleted ×10             │
 │                │                │──────────────▶│               │
 │                │ emit: 🟢 all synced            │               │
 │◀───────────────────────────────│               │               │
```

### Conflict Resolution Path
```
Device-A      OfflineMgr       EdgeFn          DB          Device-B
 │               │              │              │              │
 │ update record │              │              │              │
 │──────────────▶│              │              │              │
 │               │ syncNow()    │              │              │
 │               │─────────────▶│              │              │
 │               │              │ check server │              │
 │               │              │─────────────▶│              │
 │               │              │◀─────────────│              │
 │               │              │              │              │
 │               │              │ CONFLICT:    │  (Device-B   │
 │               │              │ server newer │   updated     │
 │               │              │              │   after us)   │
 │               │◀─────────────│ status:      │              │
 │               │              │ conflict     │              │
 │               │              │              │              │
 │ smartMerge()  │              │              │              │
 │───┐           │              │              │              │
 │   │ field_data=local         │              │              │
 │   │ admin_fields=server      │              │              │
 │◀──┘           │              │              │              │
 │               │              │              │              │
 │ re-enqueue    │              │              │              │
 │ merged data   │              │              │              │
 │──────────────▶│              │              │              │
 │               │ syncNow()    │              │              │
 │               │─────────────▶│              │              │
 │               │              │ INSERT merged│              │
 │               │              │─────────────▶│              │
 │               │◀─────────────│ synced ✓     │              │
```

---

## File Map

### New Files Created
| File | Purpose |
|------|---------|
| `packages/core/lib/src/offline/sync_queue_v2.dart` | Production queue with priority, backoff, dead-letter |
| `packages/core/lib/src/offline/intelligent_offline_manager.dart` | Core manager: connectivity, batching, conflicts |
| `packages/shared/lib/src/widgets/sync_status_widgets.dart` | UI widgets: chip, banner, badge, snackbars |
| `apps/mobile/lib/providers/sync_providers.dart` | Riverpod providers for the new system |
| `apps/mobile/test/unit/sync_system_test.dart` | Comprehensive test suite |
| `supabase/functions/sync-offline/index.ts` | **Updated** Edge Function with v2 features |
| `docs/sync_system_v2.md` | This documentation |

### Existing Files (kept for backward compatibility)
| File | Note |
|------|------|
| `offline_manager.dart` | **Keep** — still used by legacy providers. New code uses `intelligent_offline_manager.dart` |
| `sync_queue.dart` | **Keep** — the v2 queue (`sync_queue_v2.dart`) is the replacement |
| `enhanced_sync_service.dart` | **Keep** — provides additional conflict DB storage. Manager uses its own now |
| `sync_service.dart` | **Keep** — can coexist. New providers use `IntelligentOfflineManager` |

---

## Configuration

### Update `pubspec.yaml` (packages/core)
Add if not present:
```yaml
dependencies:
  # Already present: hive_flutter, connectivity_plus, uuid
```

### Update `pubspec.yaml` (apps/mobile)
Add for background sync (optional):
```yaml
dependencies:
  workmanager: ^0.5.2
```

### Update exports in `epi_core.dart`
```dart
export 'src/offline/sync_queue_v2.dart';
export 'src/offline/intelligent_offline_manager.dart';
```

### Update exports in `epi_shared.dart`
```dart
export 'src/widgets/sync_status_widgets.dart';
```

### Android setup for workmanager (if using background sync)
In `AndroidManifest.xml`:
```xml
<application>
  <service
    android:name="be.tramckrijte.workmanager.WorkmanagerService"
    android:permission="android.permission.BIND_JOB_SERVICE"
    android:exported="false" />
</application>
```

---

## Deployment Checklist

### Pre-Deploy
- [ ] Run all tests: `flutter test test/unit/sync_system_test.dart`
- [ ] Verify Hive box names don't conflict with existing data
- [ ] Test migration: existing queue items in `epi_sync_queue` → new system
- [ ] Deploy Edge Function: `supabase functions deploy sync-offline`
- [ ] Verify Edge Function environment variables (SUPABASE_URL, etc.)
- [ ] Test with real device in airplane mode → reconnect scenario

### Database
- [ ] Verify `form_submissions.offline_id` column exists and is indexed
- [ ] Verify `form_submissions.synced_at` column exists
- [ ] Verify RLS policies allow the Edge Function's service role
- [ ] Verify `audit_logs` table exists for traceability

### Client
- [ ] Update `epi_core.dart` exports
- [ ] Update `epi_shared.dart` exports
- [ ] Wire new providers in `app_providers.dart` or migrate screens
- [ ] Test `SyncStatusChip` on dashboard
- [ ] Test `SyncStatusBanner` on submissions screen
- [ ] Test manual "Retry All Failed" flow

### Post-Deploy Monitoring
- [ ] Monitor Supabase Edge Function logs for errors
- [ ] Monitor `audit_logs` for sync events
- [ ] Track average batch sizes and sync latency
- [ ] Set up alerts for high failure rates (>10%)

---

## Risk Warnings

### ⚠️ HIGH: Data Loss Risk
**Scenario**: App is uninstalled or device is wiped while items are in the queue.
**Mitigation**:
- Queue data is encrypted in Hive, which persists across app restarts
- Consider periodic backup export via `LocalRepository.exportAll()`
- Educate field workers: "Don't uninstall the app while items show 🔴"

### ⚠️ HIGH: Conflict Data Overwrite
**Scenario**: Smart merge picks wrong data during auto-resolution.
**Mitigation**:
- `smartMerge` is conservative: only field data (GPS, photos, notes) comes from client
- Admin fields (status, reviewer) always come from server
- All resolutions are logged with `_resolved_at` and `_resolution_strategy`
- For critical records, switch to `ConflictStrategy.manualReview`

### ⚠️ MEDIUM: Queue Growth in Long Offline Periods
**Scenario**: Worker offline for a week, 500+ records queued.
**Mitigation**:
- Batch size capped at 50 per request (server also enforces this)
- Auto-sync processes multiple batches until queue is empty
- Priority ordering ensures critical health data syncs first

### ⚠️ MEDIUM: Exponential Backoff Too Aggressive
**Scenario**: Worker in area with intermittent connectivity, waits too long.
**Mitigation**:
- Backoff sequence: 10s → 30s → 90s → 5min → 15min
- Retry timer checks every 15 seconds (not just on reconnect)
- "Sync Now" button bypasses backoff for manual retry

### ⚠️ LOW: Hive Box Corruption
**Scenario**: Device crashes during write, box gets corrupted.
**Mitigation**:
- All reads wrapped in try/catch with fallback to empty
- Corrupted entries are auto-cleaned during `_autoCleanup()`
- Encryption layer validates data integrity on decrypt

---

## Test Scenarios

### Critical Scenarios (MUST pass)

| # | Scenario | Expected Behavior |
|---|----------|-------------------|
| 1 | Network drops mid-sync | Items remain in queue with retry count incremented |
| 2 | Two devices sync same record | Conflict detected → smartMerge resolves → both versions preserved in audit |
| 3 | 200+ items pending for days | Priority ordering: critical health data syncs first |
| 4 | Server returns 500 five times | Item moves to dead-letter (failed) box after 5 retries |
| 5 | Offline 3 hours, 20 records | On reconnect: immediate batch sync, all 20 records sent |

### Run Tests
```bash
cd apps/mobile
flutter test test/unit/sync_system_test.dart
```

---

## Arabic Status Messages (for UI)

| State | Indicator | Message |
|-------|-----------|---------|
| Online, all synced | 🟢 | `متصل - كل البيانات مزامنة` |
| Online, pending | 🟡 | `متصل - X سجل في الانتظار` |
| Syncing | 🟡 | `جاري رفع X سجل...` |
| Offline, pending | 🔴 | `غير متصل - X سجل بانتظار المزامنة` |
| Offline, empty | 🔴 | `غير متصل - العمل بدون إنترنت` |
| Failed items | ⚠️ | `X سجل فشل - اضغط للمراجعة` |
