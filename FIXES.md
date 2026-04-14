# EPI Supervisor — Issues Found & Fixes

## 🔴 Critical Issues

### 1. Duplicate Export in epi_core.dart
- `local_repository.dart` exported twice
- **Fix**: Remove duplicate line

### 2. CORS Open to All Origins
- All Edge Functions use `Access-Control-Allow-Origin: '*'`
- **Fix**: Add project-specific origin via env variable

### 3. Rate Limiting Fail-Open
- If rate limit RPC fails, request is allowed by default
- **Fix**: Changed to fail-closed for critical operations

### 4. Missing Seed Data Migration
- README mentions `002_seed_data.sql` but file doesn't exist
- **Fix**: Create seed data file with Yemen governorates

## 🟡 Medium Issues

### 5. References Table Name Mismatch
- DatabaseService queries `'references'` table but actual table is `doc_references`
- **Fix**: Correct table name in DatabaseService

### 6. getUnreadNotificationCount Returns Inaccurate Count
- Uses `limit: 1` so returns 0 or 1, not actual count
- **Fix**: Use proper count query

## 🟢 Low Issues

### 7. SENTRY_DSN Secret Missing
- CI references `SENTRY_DSN` but it's not in GitHub secrets
- **Fix**: Add SENTRY_DSN as optional secret or use NOT_SET default

### 8. CI Uses `--no-fatal-infos` But May Have Warnings
- Already handled with flag
