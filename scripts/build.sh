#!/bin/bash
set -e

echo "🔨 EPI Supervisor — Build Script"
echo "================================="

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

echo -e "${YELLOW}Building APK...${NC}"

# Setup local.properties
echo "flutter.sdk=$(dirname $(dirname $(which flutter)))" > apps/mobile/android/local.properties

# Install dependencies
cd packages/core && flutter pub get && dart run build_runner build --delete-conflicting-outputs && cd ../..
cd packages/shared && flutter pub get && dart run build_runner build --delete-conflicting-outputs && cd ../..
cd packages/features && flutter pub get && cd ../..
cd apps/mobile && flutter pub get

# Build
flutter build apk --release \
    --dart-define=SUPABASE_URL="$SUPABASE_URL" \
    --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
    --dart-define=GEMINI_API_KEY="$GEMINI_API_KEY"

echo -e "${GREEN}✅ APK built: apps/mobile/build/app/outputs/flutter-apk/app-release.apk${NC}"
