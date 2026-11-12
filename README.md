# Gaius Ministry Staff & Program Management App

Bilingual (English / አማርኛ), iPhone-friendly Progressive Web App for staff login, Monday staff meeting attendance, weekly program attendance, leadership comments, and activity reporting.

## Main features

- Username + password login through Supabase Auth. Members do not need personal email addresses.
- Administrator and staff roles. Administrators manage the staff directory and attendance; staff can view their own attendance and leadership feedback.
- Two separate Monday records: **Monday Staff Meeting** and **Monday Weekly Program**.
- When an administrator signs in, the upcoming Monday’s two events are created automatically, with attendance rows for every active staff member. The administrator can also prepare another Monday in advance. Duplicate events are prevented.
- Attendance statuses: Present, Late, Absent, Excused, and Not recorded.
- Closing an attendance register marks any remaining Not recorded rows as Absent. The administrator must confirm this action.
- A leader can save an event-level note and a private comment for each member. Staff can see comments addressed to them.
- Monthly activities register retaining reporting fields: planned / actual output, department, center, reach, day, status, priority, challenges/reasons, actions taken, responsible person, due date, description, and evidence link. Includes monthly summaries by center and department, performance gaps, data-quality checks, monthly report text, and CSV export.
- CSV export, English/Amharic interface, dark mode, and installable PWA app shell.
- The supplied Gaius Ministry logo is used for branding and the app icon.

## Important behavior

- **The app requires an internet connection to sign in and use shared Supabase data.** The service worker caches only the app shell; it does not make cloud attendance or database operations available offline.
- The app uses a public Supabase publishable key in `config.js`. This is intended for browser applications; database access is protected by Row Level Security (RLS).
- Supabase’s server-side Edge Function uses the privileged admin client only after checking the signed-in user’s active administrator profile. Never expose a secret key in `config.js`, HTML, or GitHub.
- Username identities are mapped internally to synthetic addresses ending in `@staff.gaiusministry.org`. No mailbox is needed. Public sign-ups should be disabled in Supabase; accounts are created and managed by the Gaius administrator.
- Reporting periods use Gregorian (G.C.) month numbers. Ethiopian-calendar conversion is not implemented.
- The upcoming Monday meeting and weekly program are created automatically at administrator sign-in. Event times remain blank until the organization sets the actual times. The app does not invent meeting or program times.

## Files

- `index.html` — bilingual app, login, event attendance, activity register.
- `config.js` — Supabase Project URL and publishable key placeholders.
- `manifest.webmanifest`, `service-worker.js` — PWA installation and app-shell caching.
- `assets/` — supplied logo and app icons.
- `supabase/schema.sql` — database tables, functions, grants, and RLS policies.
- `supabase/promote-first-admin.sql` — one-time first-administrator promotion query.
- `supabase/functions/admin-create-member/index.ts` — server-side administrator-only account creation.
- `supabase/config.toml` — Edge Function configuration.

## Setup overview

Follow `SUPABASE_SETUP.md` before publishing to GitHub Pages. The app is not ready for live staff accounts until the Supabase project is configured, the SQL schema is installed, the first administrator is promoted, the Edge Function is deployed, and `config.js` is updated.
