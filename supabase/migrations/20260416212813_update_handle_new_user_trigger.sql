-- Update handle_new_user trigger to save governorate_id and district_id
-- Previously these fields were always NULL on new profiles

CREATE OR REPLACE FUNCTION handle_new_user() RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO profiles (id, email, full_name, role, governorate_id, district_id)
  VALUES (NEW.id, NEW.email, COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    COALESCE((NEW.raw_user_meta_data->>'role')::user_role, 'data_entry'),
    (NEW.raw_user_meta_data->>'governorate_id')::UUID,
    (NEW.raw_user_meta_data->>'district_id')::UUID);
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Failed to create profile for user %: %', NEW.id, SQLERRM;
  RETURN NEW;
END; $$;
