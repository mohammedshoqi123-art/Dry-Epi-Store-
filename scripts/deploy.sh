#!/bin/bash
set -e

echo "🚀 EPI Supervisor — Deploy Script"
echo "=================================="

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Load .env
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

echo -e "${YELLOW}Deploying Supabase Edge Functions...${NC}"

if [ -z "$SUPABASE_PROJECT_REF" ]; then
    echo -e "${RED}SUPABASE_PROJECT_REF not set in .env${NC}"
    exit 1
fi

# Deploy each function
for fn in create-admin submit-form get-analytics ai-chat sync-offline; do
    echo -e "  → Deploying ${fn}..."
    supabase functions deploy "$fn" --project-ref "$SUPABASE_PROJECT_REF"
    echo -e "  ${GREEN}✔ ${fn} deployed${NC}"
done

echo -e "${GREEN}✅ All functions deployed!${NC}"
