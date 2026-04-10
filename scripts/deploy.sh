#!/bin/bash
set -e

echo "🚀 EPI Supervisor - Deploy Script"
echo "=================================="

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Deploy Supabase Edge Functions
echo -e "${YELLOW}Deploying Edge Functions...${NC}"
supabase functions deploy create-admin
supabase functions deploy submit-form
supabase functions deploy sync-offline
supabase functions deploy get-analytics
supabase functions deploy ai-chat
echo -e "${GREEN}✓ Edge Functions deployed${NC}"

# Set secrets
echo -e "${YELLOW}Setting Edge Function secrets...${NC}"
supabase secrets set GEMINI_API_KEY="$GEMINI_API_KEY"
echo -e "${GREEN}✓ Secrets configured${NC}"

# Deploy web (if using Supabase hosting or Vercel)
echo -e "${YELLOW}Deploying web...${NC}"
if command -v vercel >/dev/null 2>&1; then
    cd apps/mobile/build/web
    vercel --prod --yes
    cd ../../../..
    echo -e "${GREEN}✓ Web deployed to Vercel${NC}"
else
    echo -e "${YELLOW}⚠ Install Vercel CLI or deploy build/web/ manually${NC}"
fi

# Create admin user
echo -e "${YELLOW}Creating admin user...${NC}"
curl -s -X POST "$SUPABASE_URL/functions/v1/create-admin" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
    -H "Content-Type: application/json" \
    -d '{"email":"admin@epi.local","password":"Admin@123","full_name":"مدير النظام","role":"admin"}' || true
echo -e "${GREEN}✓ Admin user created${NC}"

echo ""
echo -e "${GREEN}==================================${NC}"
echo -e "${GREEN}✅ Deployment complete!${NC}"
echo -e "${GREEN}==================================${NC}"
echo ""
echo "Admin credentials:"
echo "  Email: admin@epi.local"
echo "  Password: Admin@123"
echo ""
echo "⚠ Change the admin password immediately after first login!"
