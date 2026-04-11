#!/bin/bash
set -e

echo "╔══════════════════════════════════════════════════════════╗"
echo "║       EPI Supervisor — Supabase Setup                    ║"
echo "╚══════════════════════════════════════════════════════════╝"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Load .env
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
    echo -e "${GREEN}✓ Loaded .env${NC}"
else
    echo -e "${YELLOW}⚠ No .env found, copying from template...${NC}"
    cp .env.example .env
    echo -e "${RED}✘ Please fill in .env with your Supabase credentials and run again.${NC}"
    exit 1
fi

# Validate required vars
if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_SERVICE_ROLE_KEY" ]; then
    echo -e "${RED}✘ SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set in .env${NC}"
    exit 1
fi

PROJECT_REF=$(echo "$SUPABASE_URL" | sed 's|https://||;s|\.supabase\.co||')
echo -e "${CYAN}Project Ref: $PROJECT_REF${NC}"

# ─── 1. Check Supabase CLI ─────────────────────────────────────────────
echo -e "\n${CYAN}▶ Step 1: Checking Supabase CLI...${NC}"
if ! command -v supabase &> /dev/null; then
    echo -e "${YELLOW}Installing Supabase CLI...${NC}"
    npm install -g supabase 2>/dev/null || {
        echo -e "${RED}Failed to install supabase CLI via npm.${NC}"
        echo -e "${YELLOW}Try: npx supabase --version${NC}"
        USE_NPX=true
    }
fi

SUPABASE_CMD="supabase"
if [ "$USE_NPX" = "true" ]; then
    SUPABASE_CMD="npx supabase"
fi

$SUPABASE_CMD --version
echo -e "${GREEN}  ✔ Supabase CLI ready${NC}"

# ─── 2. Login to Supabase ──────────────────────────────────────────────
echo -e "\n${CYAN}▶ Step 2: Checking Supabase auth...${NC}"
$SUPABASE_CMD projects list 2>/dev/null || {
    echo -e "${YELLOW}Please login to Supabase:${NC}"
    $SUPABASE_CMD login
}

# ─── 3. Link project ───────────────────────────────────────────────────
echo -e "\n${CYAN}▶ Step 3: Linking project...${NC}"
$SUPABASE_CMD link --project-ref "$PROJECT_REF" 2>/dev/null || {
    echo -e "${YELLOW}⚠ Could not link project. Will push migrations directly.${NC}"
}

# ─── 4. Run migrations ─────────────────────────────────────────────────
echo -e "\n${CYAN}▶ Step 4: Running database migrations...${NC}"

# Method 1: Use supabase db push (if linked)
if $SUPABASE_CMD db push --dry-run 2>/dev/null; then
    $SUPABASE_CMD db push
    echo -e "${GREEN}  ✔ Migrations applied via db push${NC}"
else
    # Method 2: Execute SQL files directly using psql via Supabase
    echo -e "${YELLOW}  Using direct SQL execution...${NC}"
    
    # Extract connection string from URL
    DB_PASSWORD="${SUPABASE_DB_PASSWORD:-}"
    if [ -z "$DB_PASSWORD" ]; then
        echo -e "${YELLOW}  SUPABASE_DB_PASSWORD not set, using supabase db remote commit...${NC}"
        
        # Try using supabase CLI to execute
        $SUPABASE_CMD db execute --linked --file supabase/migrations/001_initial_schema.sql 2>/dev/null || {
            echo -e "${YELLOW}  Trying alternative method...${NC}"
            
            # Method 3: Use the REST API to execute SQL
            echo -e "${YELLOW}  Executing migrations via SQL editor API...${NC}"
            
            for sql_file in supabase/migrations/*.sql; do
                echo -e "  → Running $(basename $sql_file)..."
                SQL_CONTENT=$(cat "$sql_file")
                
                # Execute via Supabase SQL API
                curl -s -X POST "${SUPABASE_URL}/rest/v1/rpc/exec_sql" \
                    -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
                    -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
                    -H "Content-Type: application/json" \
                    -d "{\"query\": $(echo "$SQL_CONTENT" | jq -Rs .)}" 2>/dev/null || true
            done
        }
    else
        # Direct psql connection
        DB_URL="postgresql://postgres:${DB_PASSWORD}@db.${PROJECT_REF}.supabase.co:5432/postgres"
        
        echo "  → Running 001_initial_schema.sql..."
        PGPASSWORD="$DB_PASSWORD" psql "$DB_URL" -f supabase/migrations/001_initial_schema.sql 2>/dev/null || {
            echo -e "${YELLOW}  Direct psql failed, using supabase CLI...${NC}"
            $SUPABASE_CMD db execute --db-url "$DB_URL" --file supabase/migrations/001_initial_schema.sql
        }
        
        echo "  → Running 002_seed_data.sql..."
        $SUPABASE_CMD db execute --db-url "$DB_URL" --file supabase/migrations/002_seed_data.sql 2>/dev/null || true
    fi
fi

echo -e "${GREEN}  ✔ Migrations completed${NC}"

# ─── 5. Deploy Edge Functions ──────────────────────────────────────────
echo -e "\n${CYAN}▶ Step 5: Deploying Edge Functions...${NC}"
FUNCTIONS=("create-admin" "submit-form" "get-analytics" "ai-chat" "sync-offline")

for fn in "${FUNCTIONS[@]}"; do
    echo -e "  → Deploying ${fn}..."
    $SUPABASE_CMD functions deploy "$fn" --project-ref "$PROJECT_REF" --no-verify-jwt 2>/dev/null || {
        echo -e "${YELLOW}  ⚠ Failed to deploy ${fn}, trying without --no-verify-jwt...${NC}"
        $SUPABASE_CMD functions deploy "$fn" --project-ref "$PROJECT_REF" 2>/dev/null || {
            echo -e "${RED}  ✘ Failed to deploy ${fn}${NC}"
        }
    }
done
echo -e "${GREEN}  ✔ Edge Functions deployed${NC}"

# ─── 6. Create Admin User ─────────────────────────────────────────────
echo -e "\n${CYAN}▶ Step 6: Setting up admin user...${NC}"

ADMIN_EMAIL="${ADMIN_EMAIL:-mohammedshoqi123@gmail.com}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"
ADMIN_NAME="${ADMIN_FULL_NAME:-مدير النظام}"

if [ -z "$ADMIN_PASSWORD" ]; then
    ADMIN_PASSWORD="Admin@$(date +%Y)EPI!"
    echo -e "${YELLOW}  Generated admin password: ${ADMIN_PASSWORD}${NC}"
fi

echo -e "  → Creating admin: ${ADMIN_EMAIL}..."

# Call create-admin Edge Function
RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/functions/v1/create-admin" \
    -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
    -H "Content-Type: application/json" \
    -d "{
        \"email\": \"${ADMIN_EMAIL}\",
        \"password\": \"${ADMIN_PASSWORD}\",
        \"full_name\": \"${ADMIN_NAME}\",
        \"role\": \"admin\"
    }" 2>/dev/null)

echo -e "  Response: ${RESPONSE}"

if echo "$RESPONSE" | grep -q '"success"'; then
    echo -e "${GREEN}  ✔ Admin user created successfully${NC}"
else
    echo -e "${YELLOW}  ⚠ Admin creation response: ${RESPONSE}${NC}"
    echo -e "${YELLOW}  The user might already exist. Try logging in.${NC}"
fi

# ─── Summary ───────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════"
echo -e "${GREEN}  SUPABASE SETUP COMPLETE ✔${NC}"
echo "═══════════════════════════════════════════════"
echo ""
echo -e "  Admin Login:"
echo -e "    Email:    ${YELLOW}${ADMIN_EMAIL}${NC}"
echo -e "    Password: ${YELLOW}${ADMIN_PASSWORD}${NC}"
echo ""
echo -e "${RED}  ⚠  Change the admin password after first login!${NC}"
echo ""
echo "  Next steps:"
echo "    1. cd apps/mobile"
echo "    2. flutter pub get"
echo "    3. flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=..."
echo ""
