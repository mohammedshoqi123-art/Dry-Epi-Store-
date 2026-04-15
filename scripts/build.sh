#!/bin/bash
set -e

echo "🔨 EPI Supervisor — Build Script"
echo "================================="

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Check Flutter
command -v flutter >/dev/null 2>&1 || { echo -e "${RED}Flutter is required.${NC}"; exit 1; }

# Load .env if exists
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Set defaults
SUPABASE_URL="${SUPABASE_URL:-}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"
GEMINI_API_KEY="${GEMINI_API_KEY:-}"
ENCRYPTION_KEY="${ENCRYPTION_KEY:-}"
SENTRY_DSN="${SENTRY_DSN:-}"

# ═══ Signing check ═══
SIGNING_FLAG=""
if [ -n "$KEYSTORE_BASE64" ]; then
    echo -e "${GREEN}✅ Release keystore found (env var)${NC}"
elif [ -f "apps/mobile/android/local.properties" ] && grep -q "storeFile" apps/mobile/android/local.properties 2>/dev/null; then
    echo -e "${GREEN}✅ Release keystore configured in local.properties${NC}"
else
    echo -e "${YELLOW}⚠️  No release keystore found. APK will use debug signing.${NC}"
    echo -e "${CYAN}   To enable release signing:${NC}"
    echo -e "${CYAN}   1. Generate: keytool -genkey -v -keystore epi-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias epi-supervisor${NC}"
    echo -e "${CYAN}   2. Add to local.properties:${NC}"
    echo -e "${CYAN}      storeFile=/path/to/epi-release.jks${NC}"
    echo -e "${CYAN}      storePassword=your-password${NC}"
    echo -e "${CYAN}      keyAlias=epi-supervisor${NC}"
    echo -e "${CYAN}      keyPassword=your-password${NC}"
    echo ""
fi

# ═══ ENCRYPTION_KEY check ═══
if [ -z "$ENCRYPTION_KEY" ] || [ "$ENCRYPTION_KEY" = "" ]; then
    echo -e "${RED}❌ ENCRYPTION_KEY is not set!${NC}"
    echo -e "${CYAN}   The app will NOT start without it.${NC}"
    echo -e "${CYAN}   Generate one: openssl rand -base64 32${NC}"
    echo -e "${CYAN}   Set it in .env or pass as env var.${NC}"
    exit 1
fi

echo -e "${YELLOW}Building APK...${NC}"

# Setup local.properties
echo "flutter.sdk=$(dirname $(dirname $(which flutter)))" > apps/mobile/android/local.properties

# Install dependencies
echo -e "${CYAN}Installing dependencies...${NC}"
cd packages/core && flutter pub get && cd ../..
cd packages/shared && flutter pub get && dart run build_runner build --delete-conflicting-outputs && cd ../..
cd packages/features && flutter pub get && cd ../..
cd apps/mobile && flutter pub get

# Build flags
GEMINI_FLAG=""
if [ -n "$GEMINI_API_KEY" ] && [ "$GEMINI_API_KEY" != "NOT_SET" ]; then
    GEMINI_FLAG="--dart-define=GEMINI_API_KEY=$GEMINI_API_KEY"
fi

SENTRY_FLAG=""
if [ -n "$SENTRY_DSN" ] && [ "$SENTRY_DSN" != "NOT_SET" ]; then
    SENTRY_FLAG="--dart-define=SENTRY_DSN=$SENTRY_DSN"
fi

# Build
flutter build apk --release \
    --dart-define=SUPABASE_URL="$SUPABASE_URL" \
    --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
    --dart-define=ENCRYPTION_KEY="$ENCRYPTION_KEY" \
    $GEMINI_FLAG \
    $SENTRY_FLAG

APK_PATH="apps/mobile/build/app/outputs/flutter-apk/app-release.apk"
APK_SIZE=$(du -h "$APK_PATH" 2>/dev/null | cut -f1)

echo ""
echo -e "${GREEN}══════════════════════════════════════${NC}"
echo -e "${GREEN}✅ BUILD SUCCESSFUL${NC}"
echo -e "${GREEN}══════════════════════════════════════${NC}"
echo -e "📱 APK: ${CYAN}$APK_PATH${NC}"
echo -e "📦 Size: ${CYAN}${APK_SIZE}${NC}"
echo ""
