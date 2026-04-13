-- Fix: grant proper permissions to service_role and authenticated roles
BEGIN;

-- Tables: grant full access to service_role (bypasses RLS)
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;

-- Authenticated: read access (RLS policies control actual visibility)
GRANT SELECT ON governorates TO authenticated;
GRANT SELECT ON districts TO authenticated;
GRANT SELECT, UPDATE ON profiles TO authenticated;
GRANT SELECT ON forms TO authenticated;
GRANT SELECT, INSERT, UPDATE ON form_submissions TO authenticated;
GRANT SELECT, INSERT, UPDATE ON supply_shortages TO authenticated;
GRANT SELECT ON audit_logs TO authenticated;
GRANT SELECT ON health_facilities TO authenticated;
GRANT SELECT ON pages TO authenticated;
GRANT SELECT ON app_settings TO authenticated;

-- Anon: minimal (only for signup)
GRANT INSERT ON profiles TO anon;

COMMIT;
