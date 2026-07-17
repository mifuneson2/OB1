# Extension 4: Meal Planning

## Why This Matters

Your agent can reason across five datasets — what you've cooked before, what's in the pantry, who's home this week (from your family calendar), what people actually liked, and what you need to buy. That's meal planning that actually works. And your spouse needs access too — not to your whole brain, just to the meal plan and the shopping list. This is where you learn to share specific parts of your system with someone else.

## Learning Path: Extension 4 of 6

| Extension | Name | Status |
|-----------|------|--------|
| 1 | Household Knowledge Base | Complete |
| 2 | Home Maintenance Tracker | Complete |
| 3 | Family Calendar | Complete |
| **4** | **Meal Planning** | **<-- You are here** |
| 5 | Professional CRM | Not started |
| 6 | Job Hunt Pipeline | Not started |

## What You'll Learn

- Row Level Security (first introduction to multi-user access)
- Shared MCP server (separate server with limited, scoped access)
- JSONB for complex data (ingredients, instructions)
- Auto-generating derivative data (shopping lists from meal plans)
- Cross-extension queries (checking who's home this week from the family calendar)

## What It Does

A complete meal planning system with recipes, weekly meal plans, and auto-generated shopping lists. Includes a separate shared MCP server so your partner can view plans and check off grocery items without accessing your full Open Brain.

**Tables:**
- `recipes` — Your recipe collection with JSONB ingredients and instructions
- `meal_plans` — Weekly meal planning linked to recipes
- `shopping_lists` — Auto-generated grocery lists from meal plans

**Primary MCP Tools (full access):**
- `add_recipe` — Add a recipe with ingredients and instructions
- `search_recipes` — Search by name, cuisine, tags, or ingredient
- `update_recipe` — Update an existing recipe
- `create_meal_plan` — Plan meals for a week
- `get_meal_plan` — View the meal plan for a given week
- `generate_shopping_list` — Auto-generate shopping list from meal plan

**Shared MCP Tools (household access):**
- `view_meal_plan` — View meal plans (read-only)
- `view_recipes` — Browse recipes (read-only)
- `view_shopping_list` — View shopping list
- `mark_item_purchased` — Toggle item purchased status

## Prerequisites

- Working Open Brain setup
- Extensions 1-3 recommended (Extension 3's family_members table is referenced for cross-extension integration)
- Supabase CLI installed and linked to your project
- **Required reading:** [Row Level Security](../../primitives/rls/) primitive
- **Required reading:** [Shared MCP Server](../../primitives/shared-mcp/) primitive

## Credential Tracker

You'll reference these values during setup. Copy this block into a text editor and fill it in as you go.

> **Already have your Supabase credentials from the [Setup Guide](../../docs/01-getting-started.md)?** You just need the same Project URL and Secret key.

```text
MEAL PLANNING -- CREDENTIAL TRACKER
--------------------------------------

SUPABASE (from your Open Brain setup)
  Project URL:           ____________
  Secret key:            ____________
  Project ref:           ____________

GENERATED DURING SETUP
  Default User ID:             ____________
  MCP Access Key:              ____________  (same key for all extensions)
  MCP Server URL:              ____________
  MCP Connection URL:          ____________

FOR SHARED SERVER
  Household Access Key:        ____________
  Household Key (Supabase):    ____________
  Shared Server URL:           ____________
  Shared Connection URL:       ____________

NOTE: This extension uses TWO Edge Functions:
  1. Primary (meal-planning-mcp) — your full access
  2. Shared (meal-planning-shared-mcp) — household read + shopping list

--------------------------------------
```

## Steps

> **No JSON config files. No local Node.js server. Same pattern as your core Open Brain setup.**

### 1. Create the Database Schema

Run the SQL in `schema.sql` against your Supabase database. This creates three RLS-enabled tables:

```bash
# Using Supabase SQL Editor (recommended)
# 1. Open https://supabase.com/dashboard/project/YOUR_PROJECT_ID/sql/new
# 2. Paste the contents of schema.sql
# 3. Click "Run"
```

**Important:** The schema includes Row Level Security policies. Make sure you understand what RLS does before proceeding (see the [RLS primitive](../../primitives/rls/)).

### 2. Generate Your User ID

The extension needs a user ID to scope your data. Generate a UUID and save it in your credential tracker:

```bash
# macOS / Linux
uuidgen | tr '[:upper:]' '[:lower:]'

# Or use any UUID generator — the value just needs to be unique to you
```

Set it as an environment variable for your Edge Function:

```bash
supabase secrets set DEFAULT_USER_ID=your-generated-uuid-here
```

> If you already set `DEFAULT_USER_ID` for a previous extension, you can skip this step — all extensions share the same user ID.

### 3. Deploy the Primary MCP Server

Follow the [Deploy an Edge Function](../../primitives/deploy-edge-function/) guide using these values:

| Setting | Value |
|---------|-------|
| Function name | `meal-planning-mcp` |
| Download path | `extensions/meal-planning` |

### 4. Connect to Your AI

Follow the [Remote MCP Connection](../../primitives/remote-mcp/) guide to connect this extension to Claude Desktop, ChatGPT, Claude Code, or any other MCP client.

| Setting | Value |
|---------|-------|
| Connector name | `Meal Planning` |
| URL | Your **MCP Connection URL** from the credential tracker |

### 5. Test the Primary Server

Try these prompts in Claude Desktop:

```
Add a recipe: Chicken Stir-Fry. Ingredients: 1 lb chicken breast, 2 cups broccoli, 1 cup bell peppers, 3 tbsp soy sauce, 2 tbsp oil. Instructions: 1) Cut chicken into cubes. 2) Heat oil in wok. 3) Cook chicken 5 min. 4) Add vegetables, cook 3 min. 5) Add soy sauce, toss well. Tags: quick, healthy, asian. Prep 10 min, cook 15 min, serves 4.

Plan meals for the week of March 17: Monday dinner is the chicken stir-fry, Tuesday dinner is pasta night (custom meal, no recipe), Wednesday dinner is tacos.

Generate a shopping list for the week of March 17.
```

## Setting Up the Shared Server

The shared server gives household members limited access — they can view meal plans, browse recipes, and manage the shopping list without accessing your full Open Brain.

### 1. Create the household_member key

The RLS policies grant household access on the condition `auth.jwt() ->> 'role' = 'household_member'`, so the shared server needs a key whose JWT carries exactly that claim.

Running `schema.sql` already did half the work: it creates the `household_member` Postgres role, grants it to `authenticator`, and gives it read access to `recipes` and `meal_plans` plus read/update on `shopping_lists` — and nothing else. The role has to exist before any key can reference it, because PostgREST switches into the role named in the JWT's `role` claim.

> **⚠️ A Secret Key from the dashboard will not work here.** Not "works but is weaker" — it defeats the entire point of this server. [Supabase's docs](https://supabase.com/docs/guides/api/api-keys) are explicit: *"Secret keys authorize access to your project's data via the built-in `service_role` Postgres role,"* which *"uses the `BYPASSRLS` attribute, skipping any and all Row Level Security policies you attach."* There is no option to give a Secret Key a different role, and naming one `..._household_key` changes nothing. Such a key makes this server work perfectly **while handing it your entire database** — every table, read and write. The failure is invisible: it looks exactly like success.
>
> Verify any key before trusting it — `secret_jwt_template` is the ground truth, not the name:
>
> ```bash
> supabase projects api-keys --project-ref <your-ref>
> # {"role": "service_role"} => WRONG KEY, bypasses RLS
> ```

Instead, mint a **JWT that carries the claim**, signed with your project's legacy JWT secret. This is the same mechanism Supabase's own `anon` and `service_role` keys use — they are just JWTs whose `role` claim names a Postgres role, which PostgREST then enters via `SET ROLE`.

Get the secret from **Dashboard → Project Settings → JWT Keys → `Legacy JWT Secret` tab → Reveal**. Precision matters here, because several nearby values look plausible and none of them work:

| Where | What it is | Use it? |
|-------|-----------|---------|
| **Legacy JWT Secret** tab → Reveal | the shared secret | ✅ **this one** |
| **JWT Signing Keys** tab → Key ID | a UUID identifying a key | ❌ not a secret |
| **JWT Signing Keys** tab → current key | ECC (P-256); private half is not extractable | ❌ can't sign with it |
| API Keys page | `anon` / `service_role` / `sb_secret_…` | ❌ these are keys *signed by* the secret, not the secret |

If your project has migrated to JWT Signing Keys, the Legacy JWT Secret tab says it is *"used to **only verify** JSON Web Tokens."* **That is fine, and is exactly what this needs** — Supabase no longer *signs* with it, but it stays in the verification set, so tokens you sign with it are still accepted. That is also why your `anon` and `service_role` keys still work.

> **Don't sanity-check the secret by verifying it against your `anon` key.** If the legacy key has ever been rotated (the JWT Signing Keys tab shows `Last rotated at`), `anon` was signed with the *older* secret and the check fails on a perfectly good value. Test against the real thing instead: mint the token, set it, and call a tool.

```bash
# Prompts for the JWT secret with echo off, then prints the JWT to sign with it.
# The secret goes via the environment, never argv -- arguments are visible to
# anyone who can run `ps`.
#
# printf + `read -rs` rather than bash's `read -p`: -p means "read from a
# coprocess" in zsh (the default shell on macOS), which fails with
# "read: -p: no coprocess" and leaves the secret empty. This form works in both.
printf "JWT secret: "
read -rs JWT_SECRET
echo

JWT_SECRET="$JWT_SECRET" PROJECT_REF="<your-project-ref>" deno eval '
import { create } from "https://deno.land/x/djwt@v3.0.2/mod.ts";
const key = await crypto.subtle.importKey(
  "raw", new TextEncoder().encode(Deno.env.get("JWT_SECRET") ?? ""),
  { name: "HMAC", hash: "SHA-256" }, false, ["sign", "verify"],
);
const now = Math.floor(Date.now() / 1000);
console.log(await create({ alg: "HS256", typ: "JWT" }, {
  iss: "supabase",
  // Required. The API gateway checks this before PostgREST ever sees the
  // token; omit it and every request fails with "Invalid API key" and the
  // hint "This API key might also be owned by another Supabase project".
  ref: Deno.env.get("PROJECT_REF"),
  role: "household_member",          // the claim the RLS policies match on
  iat: now,
  exp: now + 60 * 60 * 24 * 365 * 5, // 5 years; re-mint to rotate
}, key));
'

unset JWT_SECRET
```

These are the same five claims Supabase's own `anon` and `service_role` keys carry — decode one with `supabase projects api-keys` and compare if a token is ever rejected. All five are required; `ref` in particular is checked by the gateway before PostgREST ever runs.

The `role` claim is what matters: PostgREST reads it, enters the `household_member` role, and your policies finally apply. Treat the output like any other secret.

**This token goes in the `Authorization` header, never the `apikey` slot** — which is why `shared-server.ts` passes the *anon* key to `createClient` and the household JWT as an `Authorization` header. The two headers do different jobs: `apikey` identifies the project to the gateway and must be a key Supabase has registered, while `Authorization` carries the JWT that selects the role. `createClient(url, householdJwt)` sends the token as both, so the gateway rejects it as `Invalid API key` and the role claim is never read. The anon key is safe in that slot: it only opens the door — what's visible is decided by the JWT, and RLS still applies.

Prefer per-user auth over a shared key? That is a larger change than it looks. Supabase puts custom claims under `app_metadata`, so a signed-in user's `auth.jwt() ->> 'role'` returns `authenticated`, not `household_member`. You would need to rewrite the policies to read `auth.jwt() -> 'app_metadata' ->> 'role'` **and** replace this server's static key with a real session token.

### Confirm the boundary is real

A working server proves nothing about the boundary: with a `service_role` key every tool behaves **identically** while RLS is bypassed entirely. Success is not evidence. Test the two halves separately.

**1. The role's reach** — should return a count, then refuse:

```sql
BEGIN;
SET LOCAL ROLE household_member;
SET LOCAL request.jwt.claims = '{"role":"household_member"}';
SELECT count(*) FROM meal_plans;   -- works
SELECT count(*) FROM auth.users;   -- ERROR: permission denied
ROLLBACK;
```

**2. That the server actually uses that role.** `service_role` bypasses RLS but *not* table grants, so revoking a grant breaks a real `household_member` connection and leaves a `service_role` one untouched:

```sql
REVOKE SELECT ON public.recipes FROM household_member;
```

Now call `view_recipes`. **It must fail** with `permission denied for table recipes`. If it still returns data, your key is `service_role` and the boundary does not exist. Restore immediately either way:

```sql
GRANT SELECT ON public.recipes TO household_member;
```

> **Operational note:** this token's life is tied to the legacy JWT secret. The JWT Signing Keys tab offers to **revoke** previously-used keys once their tokens expire — revoking the legacy HS256 key invalidates this token, along with your `anon` and `service_role` keys. Re-mint before revoking.

### 2. Deploy the Shared Edge Function

Follow the [Deploy an Edge Function](../../primitives/deploy-edge-function/) guide with these differences:

| Setting | Value |
|---------|-------|
| Function name | `meal-planning-shared-mcp` |
| Download path | `extensions/meal-planning` |
| Server file | `shared-server.ts` (not `index.ts`) |
| Access key secret name | `MCP_HOUSEHOLD_ACCESS_KEY` (not `MCP_ACCESS_KEY`) |

You'll also need the `household_member` key from step 1. These are two different secrets, and the near-identical names are easy to mix up:

| Secret | What it is |
|--------|-----------|
| `MCP_HOUSEHOLD_ACCESS_KEY` | authenticates **callers to the MCP server** — this is what your household member puts in their client |
| `HOUSEHOLD_SUPABASE_KEY` | the key the **server uses to reach the database** — the `household_member` key from step 1. Never shared with anyone. |

```bash
supabase secrets set HOUSEHOLD_SUPABASE_KEY=<the household_member key from step 1>
```

> **Why not `SUPABASE_HOUSEHOLD_KEY`?** Supabase reserves the `SUPABASE_` prefix for the variables it injects itself, and `secrets set` **silently skips** any name that starts with it (`Env name cannot start with SUPABASE_, skipping`). A `SUPABASE_`-prefixed name can never hold a value, so don't "tidy" this one back into that shape.

If `HOUSEHOLD_SUPABASE_KEY` is unset, the server returns **HTTP 500** on every authenticated request (`supabaseKey is required`) — the key check runs first, so a 500 here means auth worked and this secret is missing. A 401 means the caller's `MCP_HOUSEHOLD_ACCESS_KEY` is wrong instead.

### 3. Connect Your Household Member

Your spouse/partner follows the [Remote MCP Connection](../../primitives/remote-mcp/) guide on their device:

| Setting | Value |
|---------|-------|
| Connector name | `Meal Planning (Shared)` |
| URL | The shared server's MCP Connection URL |

They can view meal plans and check off grocery items. They cannot create recipes, modify meal plans, or access other parts of your Open Brain.

### 4. Test the Shared Server

Your spouse can now use prompts like:

```
What's for dinner this week?
Show me the shopping list for this week.
Mark "chicken breast" as purchased.
Search recipes tagged "quick".
```

## Cross-Extension Integration

**With Family Calendar (Extension 3):**
Your agent can check who's home this week via the `family_members` and `activities` tables to adjust serving sizes. Example prompt:

```
Who's home for dinner this week? Adjust the meal plan servings accordingly.
```

**With Household Knowledge Base (Extension 1):**
Cross-reference pantry inventory: "Do we have the ingredients for chicken stir-fry?" queries both the recipe's ingredients and your knowledge base entries about pantry stock.

**Pattern reuse:**
The RLS patterns you learn here apply directly to Extensions 5 (Professional CRM) and 6 (Job Hunt Pipeline). The shared MCP server pattern is reusable for any future extension where you want to give someone else partial access.

## Expected Outcome

Your agent can now:

- Store and search your recipe collection
- Plan weekly meals with a mix of recipes and custom entries
- Auto-generate shopping lists by aggregating recipe ingredients
- Let your spouse view plans and check off grocery items without full system access

The shared server demonstrates a key Open Brain principle: your data, your rules. You control exactly what someone else can see and do.

## Troubleshooting

For common issues (connection errors, 401s, deployment problems), see [Common Troubleshooting](../../primitives/troubleshooting/).

**Extension-specific issues:**

**RLS policies blocking queries on the shared server**
- Verify your user has the `household_member` role set in `raw_app_meta_data`
- Check the RLS policies match the schema.sql
- Test with service role key first to confirm it's not an RLS issue

**JSONB ingredient search not working**
- The `search_recipes` tool uses `.cs.` (contains) operator for JSONB — ingredient names must match exactly (case-insensitive)
- For more flexible search, consider adding a GIN index on the ingredients JSONB column

**Shopping list aggregation is wrong**
- The current implementation does simple string concatenation for quantities (e.g., "1 cup + 2 cups")
- For production use, you'd want smarter quantity aggregation

**Shared server can see all data**
- Double-check that RLS policies are enabled (`ALTER TABLE ... ENABLE ROW LEVEL SECURITY`)
- Verify the `household_member` role is set correctly in the JWT claims
- Test by trying to insert/delete from the shared server (should fail)

## Next Steps

**Extension 5: Professional CRM** — You'll apply the RLS skills you just learned to protect professional contact data. The shared server pattern isn't needed here (your work contacts are private), but the multi-entity relationship (contacts → interactions) is the same pattern you used in Extension 3 (family members → activities).

**Key concepts in Extension 5:**
- Contact management with interaction history
- Relationship tracking and follow-up reminders
- RLS for sensitive professional data
- Integration with calendar (Extension 3) for scheduling follow-ups

Continue to [Extension 5: Professional CRM](../professional-crm/)

> **Tool surface area:** This extension introduced the concept of scoped servers — a primary server with full access and a shared server with limited tools. That same principle applies to how you organize all your MCP tools. With ~25 tools across 4 extensions now, consider running the [MCP Tool Audit & Optimization Guide](../../docs/05-tool-audit.md) to identify which servers to connect per workflow and whether any tools can be consolidated.
