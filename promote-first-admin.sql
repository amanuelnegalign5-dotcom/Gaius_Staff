-- Run this once after creating the first Auth user in Supabase Dashboard.
-- Create the Auth user with this synthetic email and your chosen strong password:
-- gaius-admin@staff.gaiusministry.org

update public.profiles p
set username = 'gaius-admin',
    full_name = 'Gaius Ministry Administrator',
    role = 'admin',
    center = 'HQ',
    department = 'Other',
    is_active = true,
    updated_at = now()
from auth.users u
where p.id = u.id
  and u.email = 'gaius-admin@staff.gaiusministry.org';

-- Expected result: UPDATE 1. If 0 rows were updated, verify that the Auth user
-- exists and that its email matches the synthetic address above.
