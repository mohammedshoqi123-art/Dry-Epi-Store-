#!/bin/bash
# ============================================================
# EPI Supervisor — Setup Checker
# يتحقق من إعداد المشروع قبل البناء
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔍 EPI Supervisor — Setup Check"
echo "================================"
echo ""

ERRORS=0
WARNINGS=0

# 1. Check Flutter
echo -n "Flutter SDK... "
if command -v flutter &> /dev/null; then
  FLUTTER_VERSION=$(flutter --version | head -1)
  echo -e "${GREEN}✓${NC} $FLUTTER_VERSION"
else
  echo -e "${RED}✗ Flutter not found. Install from https://flutter.dev${NC}"
  ERRORS=$((ERRORS + 1))
fi

# 2. Check Dart
echo -n "Dart SDK... "
if command -v dart &> /dev/null; then
  DART_VERSION=$(dart --version 2>&1 | head -1)
  echo -e "${GREEN}✓${NC} $DART_VERSION"
else
  echo -e "${RED}✗ Dart not found${NC}"
  ERRORS=$((ERRORS + 1))
fi

# 3. Check .env file
echo -n ".env file... "
if [ -f ".env" ]; then
  echo -e "${GREEN}✓${NC} Found"

  # Check required variables
  if grep -q "SUPABASE_URL=https://your-project-ref" .env 2>/dev/null; then
    echo -e "  ${RED}✗ SUPABASE_URL not configured!${NC}"
    ERRORS=$((ERRORS + 1))
  elif grep -q "SUPABASE_URL=" .env 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} SUPABASE_URL is set"
  else
    echo -e "  ${RED}✗ SUPABASE_URL missing!${NC}"
    ERRORS=$((ERRORS + 1))
  fi

  if grep -q "SUPABASE_ANON_KEY=your-anon" .env 2>/dev/null; then
    echo -e "  ${RED}✗ SUPABASE_ANON_KEY not configured!${NC}"
    ERRORS=$((ERRORS + 1))
  elif grep -q "SUPABASE_ANON_KEY=" .env 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} SUPABASE_ANON_KEY is set"
  else
    echo -e "  ${RED}✗ SUPABASE_ANON_KEY missing!${NC}"
    ERRORS=$((ERRORS + 1))
  fi

  if grep -q "ENCRYPTION_KEY=EPI_SUPERVISOR_AES_KEY" .env 2>/dev/null; then
    echo -e "  ${YELLOW}⚠${NC} ENCRYPTION_KEY is using default value (change for production!)"
    WARNINGS=$((WARNINGS + 1))
  fi
else
  echo -e "${RED}✗ Not found! Copy .env.example to .env and configure it.${NC}"
  echo "  Run: cp .env.example .env && nano .env"
  ERRORS=$((ERRORS + 1))
fi

# 4. Check assets
echo -n "Font assets... "
if [ -d "apps/mobile/assets/fonts" ] && [ "$(ls -A apps/mobile/assets/fonts 2>/dev/null)" ]; then
  echo -e "${GREEN}✓${NC} $(ls apps/mobile/assets/fonts | wc -l) font files"
else
  echo -e "${RED}✗ Missing font files in apps/mobile/assets/fonts/${NC}"
  ERRORS=$((ERRORS + 1))
fi

# 5. Check dependencies
echo -n "Dependencies... "
if [ -f "apps/mobile/pubspec.lock" ]; then
  echo -e "${GREEN}✓${NC} pubspec.lock exists"
else
  echo -e "${YELLOW}⚠${NC} pubspec.lock missing — run: flutter pub get"
  WARNINGS=$((WARNINGS + 1))
fi

# 6. Check Melos
echo -n "Melos... "
if command -v melos &> /dev/null; then
  echo -e "${GREEN}✓${NC} $(melos --version)"
elif [ -f "melos.yaml" ]; then
  echo -e "${YELLOW}⚠${NC} melos.yaml found but melos not installed"
  echo "  Install: dart pub global activate melos"
  WARNINGS=$((WARNINGS + 1))
else
  echo -e "${YELLOW}⚠${NC} Not configured (optional)"
  WARNINGS=$((WARNINGS + 1))
fi

# Summary
echo ""
echo "================================"
if [ $ERRORS -gt 0 ]; then
  echo -e "${RED}❌ $ERRORS error(s) found — fix these before building!${NC}"
  exit 1
elif [ $WARNINGS -gt 0 ]; then
  echo -e "${YELLOW}⚠️  $WARNINGS warning(s) — review these${NC}"
  exit 0
else
  echo -e "${GREEN}✅ All checks passed! Ready to build.${NC}"
  exit 0
fi
