#!/bin/bash
set -e

echo "🚀 EPI Supervisor Platform - Setup Script"
echo "==========================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

command -v flutter >/dev/null 2>&1 || { echo -e "${RED}Flutter is required. Install from https://flutter.dev${NC}"; exit 1; }
command -v supabase >/dev/null 2>&1 || { echo -e "${YELLOW}Installing Supabase CLI...${NC}"; npm install -g supabase; }

echo -e "${GREEN}✓ Prerequisites OK${NC}"

# Setup Supabase
echo -e "${YELLOW}Setting up Supabase...${NC}"

if [ ! -f .env ]; then
    cp .env.example .env
    echo -e "${YELLOW}⚠ Created .env from template. Please fill in your Supabase credentials.${NC}"
fi

# Run migrations
echo -e "${YELLOW}Running database migrations...${NC}"
if command -v supabase >/dev/null 2>&1; then
    supabase db push --db-url "$SUPABASE_URL" 2>/dev/null || echo -e "${YELLOW}⚠ Run migrations manually: supabase db push${NC}"
fi

# Create admin user
echo -e "${YELLOW}Creating admin user...${NC}"
ADMIN_PASS=$(openssl rand -base64 16 2>/dev/null || head -c 16 /dev/urandom | base64 | head -c 16)
echo "  Email: ${ADMIN_EMAIL:-admin@epi.local}"
echo "  Password: (generated randomly — check .env or re-create via Edge Function)"
echo -e "${YELLOW}Run the create-admin Edge Function after deploying to set up your admin.${NC}"

# Setup Flutter
echo -e "${YELLOW}Setting up Flutter dependencies...${NC}"
cd apps/mobile
flutter pub get
cd ../..

# Generate code
echo -e "${YELLOW}Generating code...${NC}"
cd packages/core
flutter pub get
dart run build_runner build --delete-conflicting-outputs
cd ../shared
flutter pub get
dart run build_runner build --delete-conflicting-outputs
cd ../features
flutter pub get
cd ../..

echo ""
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}✅ Setup complete!${NC}"
echo -e "${GREEN}==========================================${NC}"
echo ""
echo "Next steps:"
echo "  1. Fill in .env with your Supabase credentials"
echo "  2. Deploy Edge Functions: supabase functions deploy"
echo "  3. Create admin user via the Edge Function"
echo "  4. Run the app: cd apps/mobile && flutter run"
echo ""
