#!/bin/bash
set -e

echo "🔨 EPI Supervisor - Build Script"
echo "================================="

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Build web
echo -e "${YELLOW}Building Web...${NC}"
cd apps/mobile
flutter build web --release --dart-define=SUPABASE_URL="$SUPABASE_URL" --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
echo -e "${GREEN}✓ Web build complete → build/web/${NC}"

# Build APK
echo -e "${YELLOW}Building APK...${NC}"
flutter build apk --release --dart-define=SUPABASE_URL="$SUPABASE_URL" --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
echo -e "${GREEN}✓ APK build complete → build/app/outputs/flutter-apk/app-release.apk${NC}"

# Build App Bundle (for Play Store)
echo -e "${YELLOW}Building App Bundle...${NC}"
flutter build appbundle --release --dart-define=SUPABASE_URL="$SUPABASE_URL" --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
echo -e "${GREEN}✓ AAB build complete → build/app/outputs/bundle/release/app-release.aab${NC}"

cd ../..

echo ""
echo -e "${GREEN}=================================${NC}"
echo -e "${GREEN}✅ All builds complete!${NC}"
echo -e "${GREEN}=================================${NC}"
echo ""
echo "Artifacts:"
echo "  Web:  apps/mobile/build/web/"
echo "  APK:  apps/mobile/build/app/outputs/flutter-apk/app-release.apk"
echo "  AAB:  apps/mobile/build/app/outputs/bundle/release/app-release.aab"
