// Emails every active administrator when someone requests access to Procurata.
// Called by a database trigger with the new profile id. It only acts on a pending request
// created in the last 15 minutes that has not been notified yet, so calling it by hand does nothing harmful.
// Needs the secret RESEND_API_KEY (resend.com). Optional: MAIL_FROM, APP_URL.
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const esc = (s: unknown) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]!));
const json = (b: unknown, status = 200) => new Response(JSON.stringify(b), { status, headers: { "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ ok: false }, 405);
  let id = "";
  try { id = String((await req.json()).id || ""); } catch { return json({ ok: false }, 400); }
  if (!/^[0-9a-f-]{36}$/.test(id)) return json({ ok: false }, 400);

  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const since = new Date(Date.now() - 15 * 60 * 1000).toISOString();
  const { data: p } = await sb.from("profiles").select("*").eq("id", id).eq("status", "pending").is("notified_at", null).gte("created_at", since).maybeSingle();
  if (!p) return json({ ok: true, sent: false, reason: "nothing to notify" });

  const key = Deno.env.get("RESEND_API_KEY");
  if (!key) return json({ ok: true, sent: false, reason: "RESEND_API_KEY not set" });

  const { data: admins } = await sb.from("profiles").select("email").eq("role", "admin").eq("active", true);
  const to = (admins || []).map((a) => a.email).filter(Boolean);
  if (!to.length) return json({ ok: true, sent: false, reason: "no administrators" });

  const app = Deno.env.get("APP_URL") || "";
  const rows = [["Name", p.full_name], ["Email", p.email], ["Designation", p.designation], ["Company", p.company], ["Projects", (p.requested_props || []).join(", ") || "None selected"]]
    .map(([k, v]) => `<tr><td style="padding:6px 12px 6px 0;color:#5B6478">${k}</td><td style="padding:6px 0;color:#0E1330"><b>${esc(v)}</b></td></tr>`).join("");
  const html = `<div style="font-family:Arial,sans-serif;font-size:14px;line-height:1.5;color:#0E1330">
    <p>A new user has requested access to <b>Procurata</b>, the Strata Procurement Register.</p>
    <table style="border-collapse:collapse">${rows}</table>
    <p>Review the request on the Users page${app ? `: <a href="${esc(app)}">${esc(app)}</a>` : ""}. The user cannot sign in until an administrator approves the request.</p></div>`;

  const r = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
    body: JSON.stringify({ from: Deno.env.get("MAIL_FROM") || "Procurata <onboarding@resend.dev>", to, subject: `Procurata access request: ${p.full_name || p.email}`, html }),
  });
  if (!r.ok) return json({ ok: false, sent: false, status: r.status, error: (await r.text()).slice(0, 300) }, 502);
  await sb.from("profiles").update({ notified_at: new Date().toISOString() }).eq("id", id);
  return json({ ok: true, sent: true });
});
