# extract-ssm

Reads an SSM company profile (PDF, JPG or PNG) with the Claude API and returns the vendor name, SSM no., registered address and state, plus telephone and email when printed.

- Needs the secret `ANTHROPIC_API_KEY` (Supabase, Edge Functions, Secrets). Optional `ANTHROPIC_MODEL` (default `claude-haiku-5-5`).
- Only signed-in, active administrators, Property Managers and Vendor management can call it.
- Without the key it answers `not_configured` and the app reads the document in the browser instead (text layer, then OCR).
- The user always reviews every field before saving.
