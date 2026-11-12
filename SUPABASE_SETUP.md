# Setup Guide — Supabase + GitHub Pages

This setup guide is required before real staff can sign in. The package is a prepared app, not a live connected service yet. You must create the Supabase project and supply its two public client settings. Do not share passwords or secret keys in chat or commit them to GitHub.

## Part A — Create the Supabase project

1. Open <https://supabase.com/dashboard> and sign in or create a Supabase account.
2. Select **New project**.
3. Choose an organization, name the project `gaius-ministry-staff`, create a strong database password, and choose a region close to Ethiopia if available.
4. Wait until the project is ready.

## Part B — Create the database and security rules

1. In the Supabase project, open **SQL Editor**.
2. Choose **New query**.
3. Open this package's `supabase/schema.sql`, copy the entire file, and paste it into the SQL Editor.
4. Click **Run**.
5. Confirm the query completes without errors. The schema creates staff profiles, Monday events, attendance, activities, leadership comments, and Row Level Security (RLS) policies.
6. Open **Authentication → Sign In / Providers** (or **Authentication → Settings**) and disable public email sign-ups / new user sign-ups. The app has no public registration page; only an administrator-created account should be able to enter. Supabase Admin API user creation continues to work.

Do not skip the RLS policies. They are what protect the staff records when the app is hosted as a public static website.

## Part C — Create the first administrator

The public app intentionally has no open sign-up. Create the first administrator from the Supabase Dashboard:

1. Open **Authentication → Users**.
2. Choose **Add user** (or **Create user**).
3. Use this internal login identity as the email: `gaius-admin@staff.gaiusministry.org`.
4. Choose a strong initial password. Confirm/auto-confirm the user if the dialog offers that option. This is a synthetic login identity; it does not require a real mailbox.
5. After the user is created, return to **SQL Editor** and run this statement:

```sql
-- Or copy the full query from supabase/promote-first-admin.sql
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
```

6. Use `gaius-admin` and the password you created to sign in to the app. The administrator can then create staff accounts in the Members area. On administrator sign-in, the app automatically prepares the next Monday's staff meeting and weekly program as separate events and adds attendance rows for all active staff.

**Keep the first administrator credentials secure.** Do not make a staff member an administrator unless that person is authorized to manage staff access and attendance records.

## Part D — Deploy the secure account-creation function

The app's Members page creates login accounts through a server-side Supabase Edge Function. The function uses Supabase's current `@supabase/server` wrapper: it validates the signed-in user's JWT, then checks that the caller is an active administrator before using the server-side admin client to create an account. The secret key is never placed in browser files. The browser uses only the publishable key, while Row Level Security restricts database access.

### 1. Install and link the Supabase CLI

On a computer with a terminal (Windows, macOS, or Linux), install the Supabase CLI using the official instructions: <https://supabase.com/docs/guides/cli>.

Then open a terminal in this app folder and run:

```bash
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase functions deploy admin-create-member
```

Replace `YOUR_PROJECT_REF` with the project reference shown in the Supabase Project URL. The function uses Supabase’s server-side context and checks the signed-in caller against the administrator profile before creating accounts. `supabase/config.toml` keeps JWT verification enabled for the function.

## Part E — Connect the front end

1. In Supabase, open **Project Settings → API Keys** (or use the project’s **Connect** dialog).
2. Copy the **Project URL**.
3. Copy the **Publishable key** (usually begins `sb_publishable_`). A legacy `anon` public key can also be used if your project still displays it.
4. Open `config.js` in the app folder and replace the two placeholders:

```js
window.GAIUS_CONFIG = {
  url: 'https://YOUR_PROJECT_REF.supabase.co',
  publishableKey: 'YOUR_SUPABASE_PUBLISHABLE_KEY'
};
```

Only the Project URL and publishable/anon key belong here. Never place `sb_secret_...` or `service_role` keys in `config.js`.

## Part F — Publish on GitHub Pages

1. Sign in at <https://github.com>.
2. Create a repository named `gaius-ministry-staff-app`.
3. Upload the **contents** of the `Gaius-Ministry-Management-App` folder to the repository root. `index.html` must be at the top level, with `assets/`, `supabase/`, and the other files beside it.
4. Open the repository's **Settings → Pages**.
5. Under **Build and deployment**, choose **Deploy from a branch**.
6. Select branch `main` and folder `/(root)`, then save.
7. After GitHub Pages finishes publishing, open the HTTPS link it provides.
8. On iPhone, open that link in Safari → Share → Add to Home Screen → Add.

The database and authentication are hosted by Supabase; GitHub Pages only hosts the front-end files.

## Part G — Add the team and set Monday activities

1. Sign in with the first administrator account.
2. Open **Members / አባላት** and create each staff account. Usernames must use 3–30 English letters, numbers, dots, underscores, or hyphens. Temporary passwords must be at least 10 characters.
3. Give each member their username and temporary password privately. Members can change their own passwords from the app header.
4. Open **Monday Meetings & Program / የሰኞ ስብሰባና ፕሮግራም**.
5. The next Monday's two events are prepared automatically when an administrator signs in. Open each event and set its actual start/end time, location and leadership notes. No event time is assumed.
6. To prepare another Monday in advance, use the manual date form, enter the confirmed meeting/program times and select **Create staff meeting + weekly program**.
7. Open each event's attendance register. Mark each staff member Present, Late, Absent, or Excused. Save attendance and leadership comments.
8. At the end of the event, select **Close attendance**. Only then are any remaining Not recorded entries changed to Absent. The administrator can reopen the register if a correction is required.

The app does not assume the meeting/program times. Leave them blank until the organization confirms the schedule.

## Security and operational notes

- Anyone can download the front-end files from a public GitHub Pages site, but the Supabase database should reveal no records to signed-out users; verify this with a signed-out test.
- Staff can read organization-wide activity records, but can edit their own activity rows. Only an administrator can manage attendance, member access, and leader comments.
- Each staff member can read their own attendance and comments addressed to them. Admins can read the full register.
- The app uses username-based synthetic Auth identities at `@staff.gaiusministry.org`; no email inbox or email-password reset flow is configured. If a password is lost, an administrator must reset it using the Supabase Auth administration tools or add an approved password-reset procedure.
- Deactivating a profile blocks app access at sign-in; it does not delete historical attendance or activity records.
- Export and retain periodic reports according to the ministry's data-retention practice. Do not enter beneficiary clinical details or other sensitive personal information into the activity register.
- Test the app using one admin and at least two test staff accounts before entering live staff data.
