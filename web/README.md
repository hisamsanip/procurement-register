# Supabase + Vercel version

`index.html` is a single static page. It signs users in with Supabase Auth and stores data in Supabase Postgres (row-level security enforces roles).

## Deploy on Vercel
1. Vercel > Add New > Project > import this repo.
2. Set **Root Directory** to `web`. Framework preset: Other. No build command, no environment variables.
3. Deploy.

## Supabase settings (Authentication > URL Configuration)
- Site URL: your Vercel URL.
- Add the same URL under Redirect URLs (needed for invite and reset-password links).

## Access requests
New users click **Request access** on the sign-in page, set their own password and give their name, designation, company and projects. Every new account waits as *pending* until an administrator approves it on the **Users** page.
Supabase: Authentication > Sign In / Providers > **Allow new users to sign up** must be ON (approval is enforced by the app and the database).

## Email to administrators
`supabase/functions/notify-admin` emails every active administrator when a request arrives. It needs a Resend API key stored as the Edge Function secret `RESEND_API_KEY` (optional `MAIL_FROM`, `APP_URL`). Without the key, requests still appear on the Users page.

## Audit log
Every create, change and delete on records, vendors, properties, setup, users and project access, plus every sign-in, is written to `audit_log` by database triggers. Only administrators can read it (Audit log page).

## Roles
- Administrator: everything, all projects; approves users; audit log
- Property Manager: raises, edits and deletes records for assigned properties only; can add vendors with an SSM document
- Management: views all projects and the dashboard, no editing
- Vendor management: maintains the vendor list, blacklists vendors; records are view only
- Viewer: read-only for assigned properties

Database changes are in `migrations/`. Run each once, in order, in the Supabase SQL editor.
