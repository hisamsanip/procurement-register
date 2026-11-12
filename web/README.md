# Supabase + Vercel version

`index.html` is a single static page. It signs users in with Supabase Auth and stores data in Supabase Postgres (row-level security enforces roles).

## Deploy on Vercel
1. Vercel > Add New > Project > import this repo.
2. Set **Root Directory** to `web`. Framework preset: Other. No build command, no environment variables.
3. Deploy.

## Supabase settings (Authentication > URL Configuration)
- Site URL: your Vercel URL.
- Add the same URL under Redirect URLs (needed for invite and reset-password links).

## First admin
Invite yourself (Authentication > Users > Invite user), accept the email, then run in the SQL editor:
`update public.profiles set role='admin' where email='YOUR_EMAIL';`
After that, manage roles and property access in the app's **Users** page.

## Roles
- Administrator: everything, all projects
- Property Manager: raises and edits records for assigned properties only; can add vendors with an SSM document
- Management: views all projects and the dashboard, no editing
- Vendor management: maintains the vendor list, blacklists vendors; records are view only
- Viewer: read-only for assigned properties

Database changes after the first setup are in `migrations/`. Run each once in the Supabase SQL editor.
