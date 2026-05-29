# AgentEdge — St. Stephen's School Portal (Pathshala)

## Project Context
This is the Pathshala portal repo for St. Stephen's School (`biz_001`). Single-file React 18 + Babel CDN app in `index.html` (4,108 lines as of 2026-05-29). No build step, no `npm install` — everything runs from CDN. Deployed via Vercel, auto-deploys from GitHub `main` pushes. Migrated from Netlify in early days. Repo: `github.com/Agentedge/School_Portal`.

Owner: Bhargav Avadhanula (AgentEdge founder, M&A IT Consultant at Deloitte USI, Hyderabad).
Methodology: SAP ACTIVATE adapted (phases, waves, cutover, hypercare).
**Go-live target: June 8, 2026** (revised from June 1).
Pilot customer: St. Stephen's School, Sangareddy, Telangana (KG-10, ~600 students). Owner Stephen; mother is principal. Project codename: "Project Genesis."

This repo is one of two products in the school vertical. The other is **AgentEdge Unified** — the school owner's intelligence dashboard with 8 agents, in a separate repo (`Agentedge/AgentEdge_Unified`). Both products share the same Supabase project and `biz_001` schema. RLS enforces who sees what across both.

## Strategic Anchor
AgentEdge is the autonomous business operating system for Indian SMEs, distributed via CA firms (white-label, revenue share). Not a tool company — an operating layer. Moat: Indian compliance depth (GST/TDS/Tally) + CA channel + business graph. Geography: Hyderabad first, then pan-India.

Two-product architecture for the school vertical:
- **Pathshala** (this repo) — student/parent/teacher app. Data entry + consumption.
- **AgentEdge Unified** (separate repo) — intelligence/agent layer for the school owner. Reads operational data; writes `agent_signals` and `interventions`.

Pipeline: St. Stephen's School (biz_001), Satya Caterers (biz_002, parked), Bhargavi Developers (biz_003), Sri Lakshmi Printing Press (biz_004).

GTM constraint: Telugu AI tutor content tied to SCERT syllabus. School product is limited to Telangana state board for now. CBSE/ICSE need additional content builds.

## Current State Snapshot — 2026-05-29

### Shipped (Stages 1–6 all DONE)
- **Stage 1**: Supabase client (`db`) initialised via `AGENTEDGE_CONFIG` (jsDelivr UMD; default schema = `biz_001`).
- **Stage 2**: LoginScreen wired to `db.auth.signInWithPassword`; role from `db.rpc('get_user_role')`; teacher class/section scoping via `teacher_assignments`.
- **Stage 3**: Session restore via `db.auth.getSession()` + `onAuthStateChange` subscription (with deadlock fix applied — see Technical Rules).
- **Stage 4**: AttendanceTab live-wired to `biz_001.attendance`. Period-level grid (P1–P7 weekday / P1–P4 Saturday). Teacher write; Principal read-only. Merged via PR #1.
- **Stage 5**: MarksTab live-wired to `biz_001.marks`. Three-branch UX (fresh / silent-load / make-up). Merged via PR #2 (commit `b883c74`).
- **Stage 6**: HomeworkTab live-wired to `biz_001.homework` + `biz_001.homework_submissions`. View, grade, and create. M024 auto-cascade trigger validated end-to-end via UI insert. Merged via PR #3 (commit `c2b81ad`). **Production verification still PENDING at time of writing.**

### Still on mock data
- ClassOverview / Performance / Insights tabs (teacher view)
- Parent dashboard (all tabs)
- Student dashboard (all tabs)
- The teacher's homework UI is wired; parent/student READ-only homework views are filed as **B-43 (MEDIUM)** — Phase 2 work.

### Active blockers
- **Auth credentials:** only PRIN001 (Principal) and TCH001 (Ramesh) work. TCH002–TCH009 not provisioned. Blocks UAT round 1.
- **Wave 1 real student data:** template returned with sample rows only. Stephen has not delivered actual Class 9 student data.
- **DPA + Privacy Notice:** not drafted. Lawyer email unsent (>16 days deferred). Hard gate for Wave 1 real data ingestion under DPDP Act 2023.
- **Domain:** not purchased. Still on default Vercel subdomain.
- **Supabase free-tier auto-pause (S-1):** project auto-pauses after ~7 days idle. Caused a "Failed to fetch" outage during Stage 6 smoke testing on May 28. Must upgrade to paid tier (~$25/mo) before St. Stephen's hits live traffic.

### Next decision — three candidate paths (no commitment yet)
Ordered by go-live impact:
1. **Non-technical blockers** (lawyer email → Stephen data call → domain). Single highest-leverage move.
2. **AgentEdge Unified polish** (in AgentEdge Unified repo) — Wave A is COMPLETE (all 8 agents wired to live Supabase as of 2026-05-13: RouteWatch, AdmissionRadar, StaffPulse, FeeAlert, AttritionGuard, AttendanceFlag, ResultPredictor, ParentBridge). Remaining polish: real login form (Stage 2 form vs current auto-signin), credentials out of source into Vercel env vars (B-24, B-37), Vercel deployment protection off (B-27) before any external demo.
3. **Parent + Student views (B-43)** — required for full Phase 1, but not strictly gating June 8 teacher-facing functionality.

## Database — Supabase (Mumbai, ap-south-1)

**Project:** `Agentedge's-Dev` (single Supabase project. Main branch serves as production today — no separate dev/prod yet.)
**Region:** Mumbai (ap-south-1) — non-negotiable, set before project creation.
**Schema-per-business architecture (LOCKED):** each pilot business gets its own schema. Never row-per-business.

| Schema | Purpose |
|---|---|
| `ae_platform` | System tables: businesses, user_roles, helper functions |
| `biz_001` | St. Stephen's School (24+ tables) |
| `biz_002` | Satya Caterers (parked) |
| `biz_003` | Bhargavi Developers |
| `biz_004` | Sri Lakshmi Printing Press |
| `ae_intelligence` | Anonymised aggregates, cross-SME patterns, benchmarks, health scores. **The moat. Never exposed to clients.** Currently 4 scaffolded tables (`signal_aggregates`, `cross_signal_patterns`, `benchmarks`, `health_score_inputs`); no pipeline yet. Activates when second school enters pipeline. |

**biz_001 business UUID:** `cc460eea-9945-4e60-a17d-2a93754d5659`

### Three-layer data model (LOCKED)
- **Layer 1 — Universal Core (7 tables):** `businesses`, `entities`, `transactions`, `events`, `documents`, `agent_signals`, `interventions`. Each business owns their data.
- **Layer 2 — Vertical Extensions:** `student_profiles` (school), `catering_profiles`, `properties`, `print_job_profiles`. Each business owns their data.
- **Layer 3 — `ae_intelligence`:** as above. AgentEdge proprietary.

### Two-layer agent naming (LOCKED ARCHITECTURAL RULE)
- DB always stores **universal Pulse names**: `CashPulse`, `RetentionPulse`, `TeamPulse`, `EngagePulse`, `OutcomePulse`, `OutreachPulse`, `PipelinePulse`, `AssetPulse`.
- UI shows **industry-specific names**: FeeAlert, AdmissionRadar, AttritionGuard, RouteWatch, StaffPulse, AttendanceFlag, ResultPredictor, ParentBridge.
- `agent_signals.agent_name = 'CashPulse'` always, NEVER `'FeeAlert'`. Translation lives only in frontend.

### Deployed state (as of 2026-05-29)
- 24+ tables in `biz_001`
- 80+ RLS policies live across `biz_001` (original 59 from M004, expanded by M016–M021)
- 8 demo students seeded in Class 9 Section A (STU001–STU008 via M022)
- DPDP right-to-erasure simplicity: drop schema = full erasure

### Test auth users
Password for all four: `AgentEdgeTest2026!`
- `principal.test@agentedge.in` → role `principal` → Sr. Philomena David
- `teacher1.test@agentedge.in` → role `teacher` → Ramesh Babu Yerra (Class 9A Class Teacher)
- `parent1.test@agentedge.in` → role `parent` → Venkat Reddy (parent of STU001)
- `student1.test@agentedge.in` → role `student` → Ravi Kumar Reddy (STU001)

Note: only the first two are exercised in the wired teacher flow. Parent/Student logins not yet meaningfully tested against wired data.

## Critical Technical Rules — NEVER violate
- **No `export default`** in CDN React files
- **No JSX in pure HTML** — `React.createElement` only (applies to `agentedge_unified.html` in the other repo; Babel CDN in this repo allows JSX in `index.html`)
- **Always `node --check`** on any standalone `.js` files before declaring work complete
- **Always `catch(e)`** — never `catch {}`
- **No nested backtick template literals**
- **No escaped apostrophes in `encodeURIComponent`** — rephrase instead
- **jsDelivr (not cdnjs)** for Babel
- **Use actual deployed column names** — NEVER design-doc names. Always verify via `information_schema` before writing schema-touching code.
- **Serve via `python3 -m http.server 8000`**, never `file://` — Supabase JS blocks file protocol
- **One feature branch per stage.** Branch naming: `stage-N-short-description`. PRs merged to `main`, branches deleted after merge.
- **Sensitive medical/health data** (`disability_status`, `gender`, `date_of_birth`, `blood_group`) is DPA-gated. Columns exist; do NOT populate values until DPA is signed and school opts in per DPDP Act 2023.
- **Supabase `onAuthStateChange` deadlock rule:** NEVER `await` a Supabase call (`rpc`, `from`, `auth.signOut`, etc.) directly inside the `onAuthStateChange` callback. Supabase holds an internal auth lock while the callback runs — awaiting any Supabase method deadlocks the next `getSession()`. Wrap async work in `setTimeout(async () => { ... }, 0)` so it runs after the callback returns. The callback itself must be synchronous (no `async` keyword). Learned the hard way on 2026-04-26.
- **WSL2 cannot route IPv6.** For `pg_dump` and direct Postgres connections from WSL, use the Supabase Session Pooler endpoint (`aws-1`, not `aws-0`). The default direct connection times out silently on IPv6 lookup.
- **Supabase free-tier auto-pauses after ~7 days idle (S-1).** During development this is annoying (~5-min restore). For go-live this is unacceptable. Paid tier upgrade required before St. Stephen's hits live traffic.

## Schema Reality Notes
*Corrections that apply across all remaining work — recorded once, never debug twice.*

### `entities.auth_user_id` does NOT exist as a top-level column
The auth link lives inside `entities.metadata` JSONB at key `auth_user_id`. To resolve a teacher/student/parent's `entity_id` from their session:

```js
.from("entities").select("id").eq("metadata->>auth_user_id", session.user.id).single()
```

Applies to ALL entity types, not just teachers. Caught during Stage 4 testing (2026-05-01).

### `student_profiles` has TWO FKs to `entities`
`entity_id` (the student) and `parent_id` (the parent). There is NO `student_id` column on `student_profiles`. When embedding entities, disambiguate with the explicit FK hint:

```js
.select("entity_id, entities!student_profiles_entity_id_fkey(first_name, last_name)")
```

Plain `entities!inner(...)` throws `PGRST201`. Also: `class` and `section` are top-level columns on `student_profiles`.

### `student_profiles.class` is normalised to `'9'` (no prefix)
Original seed data used `'Class 9'`. Normalised across all 4 tables (`student_profiles`, `subjects`, `teacher_assignments`, `teacher_subjects`) via M007. Class normalisation is a cross-cutting discipline — every table with a `class` column needs auditing during onboarding.

### `marks` table — denormalised, 14 columns
Key constraints:
- `exam_type CHECK`: exact casing for `('Unit Test 1', 'Unit Test 2', 'Unit Test 3', 'Half Yearly', 'Pre-Final', 'Annual', 'Class Test', 'Assignment')`. No 'Mid Term'.
- `score CHECK: score >= 0`. **DB does NOT enforce `score <= max_marks`** — UI must validate.
- Unique constraint `marks_unique_per_student_per_exam`: 5-column `(business_id, student_id, subject_id, exam_type, exam_date)` — upsert key.

### `entities` table is generic flat-shape with `metadata` JSONB
14 columns. Roll number, class, section, parent_id are NOT stored on entities — they live on `student_profiles`.

### `subjects` seeded for Class 9 only
7 subjects active: Telugu, Hindi, English, Mathematics, Physical Science, Biological Science, Social Studies. `subject_code` intentionally NULL.

### Column name conventions (deployed Supabase schema)
- `class` (NOT `class_name`)
- `student_id` (NOT `student_entity_id`)
- `teacher_id` (NOT `teacher_entity_id`)
- `business_id` (NOT `school_id`)
- `first_name` + `last_name` (NOT `name`)
- `score` (NOT `marks_obtained`)
- `awarded_to_student_id` on `house_points` (NOT `entity_id`)

## Schema Architectural Rules

1. **`business_id` type asymmetry.** `business_id` is `text` in `biz_XXX` schemas (e.g., `biz_001.attendance.business_id` is text). `business_id` is `uuid` in `ae_platform.businesses(id)`. When writing cross-schema joins or RLS policies, do not assume same type. **Exception:** `ae_platform.user_roles.business_id` is `text` — `get_user_role()` casts it to uuid in its JOIN. See rule #5.

2. **Role case convention.** `ae_platform.user_roles.role` stores LOWERCASE (`'teacher'`, `'principal'`, `'admin_team'`). `get_user_role()` applies `INITCAP()` and returns title-case (`'Teacher'`, `'Principal'`, `'Admin_team'`). All RLS policies compare against title-case values. **INITCAP is the SINGLE translation layer** — never `toLowerCase()` anywhere else.

3. **`auth_user_id` resolution path.** Four hops; any one breaks and `marked_by` inserts fail silently:
   ```
   auth.users
     → ae_platform.user_roles.auth_user_id
     → biz_001.teacher_assignments.auth_user_id (where wired)
     → biz_001.entities.metadata.auth_user_id
   ```

4. **`agent_signals_all` is the moat-feed read surface.** Each `biz_XXX` schema has `agent_signals_all` as a view UNIONing `agent_signals` (live) and `agent_signals_archive`. The future Layer 3 aggregation pipeline reads from this view, not the underlying tables directly. `ae_intelligence` currently has 4 scaffolded tables but no pipeline functions/triggers — moat aggregation activates when a second school enters the pipeline.

5. **`ae_platform.user_roles.business_id` is TEXT, not UUID.** Rule #1 says "business_id is UUID in ae_platform tables" — that's true for `ae_platform.businesses(id)` but NOT for `ae_platform.user_roles(business_id)`, which is `text`. `get_user_role()` casts `ur.business_id::uuid` in its JOIN. Required because columns are different types.

### INITCAP + underscore role names (LANDMINE — learned via B-30, 2026-05-12)
`INITCAP('admin_team')` returns `'Admin_team'` (lowercase t), NOT `'Admin_Team'`. M017 originally hardcoded `'Admin_Team'` (capital T) in policy bodies — silently filtered all rows for admin_team users. M019 fixed it. **Any role string with underscores must be hardcoded with the correct case in RLS policies — never rely on INITCAP for these in your head.**

### SQL Editor bypasses RLS (LANDMINE — recurring)
Seeing data in the Supabase SQL Editor (postgres role) does NOT prove the app can read it. RLS audit must happen before wiring agents, not after discovering silent failures. Run the full coverage audit upfront, don't discover gaps reactively. Reference query:

```sql
SELECT tablename, policyname FROM pg_policies
WHERE schemaname='biz_001' AND policyname LIKE '%admin_team%';
```

This caught B-33 (entities table had no admin_team policy → silent 0-row return for StaffPulse).

## Migration Log

All migrations live in `sql/` in this repo. **Several migrations (M016, M017, M018, M019, M020, M021) actually serve AgentEdge Unified agents but live here because both products share `biz_001`. Backlog item B-42 (LOW) tracks a possible repo split — not urgent.**

| # | File | Date | Purpose | Closes |
|---|---|---|---|---|
| 000 | `000_baseline.sql` | 2026-04 | Full schema baseline pg_dump (~187KB, 6 schemas, 65 tables). Stands in for individual M001–M006 which were never repo'd as standalone files. | Pre-Wave-1 #19 (partial — accepted baseline approach over backfilling 6 separate files) |
| 007 | `007_pre_wave_1_cleanup_part_1.sql` | 2026-05-07 | Class normalisation (39 rows across 3 tables); drop empty `biz_002.user_roles`; fix `log_audit()` UPDATE branch losing OLD data | Pre-Wave-1 #1, #9, #13 |
| 008 | `008_pre_wave_1_cleanup_part_2.sql` | 2026-05-08 | Add 10 columns to `student_profiles` (incl. DPDP-gated `gender`, `disability_status`). Table grew 13 → 23 columns. | Pre-Wave-1 #10 |
| 009 | `009_pre_wave_1_cleanup_part_3.sql` | 2026-05-08 | Create `biz_001.teacher_profiles` (15 columns, mirrors `student_profiles` shape) | Pre-Wave-1 #16 |
| 010 | `010_communication_preferences.sql` | 2026-05 | New table — parent communication channel preferences | — |
| 011 | `011_communication_logs.sql` | 2026-05 | New table — outbound communication audit trail | — |
| 012 | `012_fee_summary.sql` | 2026-05 | New table — derived fee summary per student | — |
| 013 | `013_staff_attendance.sql` | 2026-05 | New table — staff daily attendance | — |
| 014 | `014_staff_period_attendance.sql` | 2026-05 | New table — staff period-level attendance | — |
| 015 | `015_admissions.sql` | 2026-05 | New table — admissions pipeline (drives AdmissionRadar agent) | — |
| 016 | `016_admin_team_role.sql` | 2026-05-11 | Add `admin_team` to `ae_platform.user_roles` CHECK; legacy `admin` preserved | B-10 |
| 017 | `017_rls_policies_new_tables.sql` | 2026-05-11 | 18 RLS policies across M010–M015 tables. **Had INITCAP bug — hardcoded `'Admin_Team'` (wrong case).** | (introduced B-30) |
| 018 | `018_admin_team_transport_rls.sql` | 2026-05-12 | admin_team SELECT policies on `transport_routes`, `transport_stops`, `student_transport` (required for RouteWatch). **Serves AgentEdge Unified.** | — |
| 019 | `019_fix_initcap_admin_team_policies.sql` | 2026-05-12 | Fix M017 INITCAP bug — replace `'Admin_Team'` with `'Admin_team'` | B-30 |
| 020 | `020_admin_team_rls_entities.sql` | 2026-05-12 | admin_team SELECT policy on `entities` (silent 0-row landmine discovered during StaffPulse smoke test). **Serves AgentEdge Unified.** | B-33 |
| 021 | `021_admin_team_rls_broad_sweep.sql` | 2026-05-12 | Broad admin_team RLS sweep for `biz_001` (21 policies added). Catch-all to prevent further silent landmines. **Serves AgentEdge Unified.** | — |
| 022 | `022_seed_student_data.sql` | 2026-05-16 | Seed 8 Class 9A students (STU001–STU008) | — |
| 023 | `023_backfill_not_submitted.sql` | 2026-05-16 | Backfill `homework_submissions` with 'Not Submitted' rows for existing homework | — |
| 024 | `024_homework_submission_autocreate_trigger.sql` | 2026-05-16 | Trigger on `homework` INSERT that auto-cascades a `homework_submissions` row per enrolled student in the target class. Validated end-to-end via Stage 6 UI insert. | — |

## Open Backlog

### Pre-Wave-1 hardening (5 open of 19 total)
- **#3** `teacher_subjects` full rebuild with real teacher-subject assignments. **Stephen-blocked.**
- **#4** Auth credentials for TCH002–TCH009 (8 teachers). Only PRIN001 + TCH001 have working auth. **UAT-gated.**
- **#15** Audit `biz_003` and `biz_004` for `user_roles` drift. Deferred until those businesses activate.
- **#17** Email convention reconciliation — `auth.users` uses test pattern; `entities` use real school emails. **Domain-gated.**
- **#19** Backfill missing migrations 001–006 from live Supabase to repo as standalone files. **Partially closed via M000 baseline approach.** Outstanding question: individual files or baseline sufficient? Decision deferred.

### Recent items (B-XX series)
- **B-10** Legacy `admin` role in user_roles CHECK preserved alongside `admin_team`. ✅ Captured in M016.
- **B-24** Hardcoded Supabase credentials in `AgentEdge_Unified/index.html` source. Move to Vercel env vars before any external demo. **OPEN.** *AgentEdge_Unified repo.*
- **B-27** Vercel deployment protection enabled on `AgentEdge_Unified` project (Hobby plan default for private repos — blocks external viewing). Disable before external demo. **OPEN.** *AgentEdge_Unified repo.*
- **B-30** M017 INITCAP `'Admin_Team'` (wrong case). ✅ Closed by M019.
- **B-33** `entities` table missing admin_team policy → silent 0-row return for StaffPulse. ✅ Closed by M020.
- **B-37** admin password committed in `AgentEdge_Unified` repo (separate private repo). Not active exposure but bad hygiene. **OPEN.**
- **B-40** Add `homework_id` to relevant `agent_signals` payload for Wave A homework-signal consumption. ~10 min. **OPEN.**
- **B-41** Backfill `roll_number` on 8 seed students (currently NULL). Cosmetic. **OPEN.**
- **B-42** Consider a separate `Agentedge/Supabase_Migrations` repo (SQL currently mixed with Pathshala UI in this repo). **LOW.**
- **B-43** Parent + Student READ-only homework views (Phase 2 add). **MEDIUM, OPEN.**
- **B-44** Add success/error styling distinction to `showToast` (currently identical). Cosmetic. **OPEN.**

### Deferred UX (post-Stage 4, low-priority)
- Principal read-only view: hide edit controls more cleanly post-Stage 4
- Class Teacher vs Subject Teacher granular permissions (overlaps with `teacher_subjects` table; reconcile during AgentEdge Unified wiring)
- Tabular student layout with inline edit grid for Teacher and Principal dashboards
- Future-date attendance: currently allowed (no UI restriction). Flag for Stephen if blocking is desired.

## Strategic Flags

- **S-1: Supabase free-tier auto-pause = go-live blocker.** Free projects auto-pause after ~7 days idle. Caused "Failed to fetch" during Stage 6 smoke test (May 28). For live school usage, need paid tier (~$25/mo). Must upgrade before go-live.
- **S-2: `showToast` hardcoded "8 students assigned"** in the Stage 6 homework-create flow. Works for Class 9A's 8 students; will mislead when real class sizes vary. Make dynamic post-Wave-1.

## Open Non-Technical Items
- **Lawyer email (PARKED but URGENT):** DPA + Privacy Notice drafting under DPDP Act 2023 (children's data). Hard gate before Wave 1 migration. Deferred >16 days.
- **Stephen call:** lock data delivery date. Confirm Saturday period count practical usage. Confirm Half Day vs Leave usage. Resend data template with hard deadline.
- **Domain purchase:** school-relevant TLD (e.g. `ststephens.school` or `pathshala.school`). Blocks marketing site + production URL.
- **Marketing site:** one page, screenshots, "Book a Demo" `wa.me` link. Long-deferred.
- **CA firm coffee:** first conversation. No closing in May; relationship start only.
- **Pilot agreement with Stephen:** sign once pricing locked.
- **Real Class 9 student data collection from Stephen:** Excel template returned with sample rows only as of Apr 28; resend with hard deadline.

## Path to June 8 Go-Live (10 days from 2026-05-29)

| Window | Work |
|---|---|
| Today–May 31 | Verify Stage 6 production deploy. Send lawyer email (DPA + Privacy Notice). Stephen call to lock data delivery + Saturday/Half-Day usage. Domain purchase. Supabase Pro upgrade (S-1). |
| June 1–3 | Wave 1 migration if Stephen data is in. Provision auth credentials for TCH002–TCH009. |
| June 4–5 | UAT round 1: 2 teachers + 3 parents on real data. Fix bug list. |
| June 6–7 | Teacher training. Parent WhatsApp onboarding. Dress rehearsal. |
| June 8 | GO-LIVE — Pathshala Portal for St. Stephen's School. |

**Critical path:** lawyer email → DPA signed → Wave 1 migration → UAT → go-live. Stephen data delivery is the gating dependency.

## Working Style (LOCKED)
- **Hand-holding mode (locked 2026-04-29, reinforced 2026-05-28):** One sub-step at a time. Plain English explanation BEFORE showing code. Line-by-line breakdown of code/SQL longer than 5 lines. Query deployed state before writing code that touches it. Call out trade-offs explicitly, invite pushback. Pause for confirmation on destructive actions (TRUNCATE, DROP) before running.
- **CTO cross-questioning:** Before approving major architectural moves (new stages, schema changes, security decisions, scope expansions), ask comprehension-check questions. Pair with active assumption-surfacing — name assumptions explicitly before they become mistakes.
- **Communication tone:** Simple, plain language. No jargon density. Everyday analogies (hotel keys, conference rooms, walking between buildings). Short responses, short sentences. Define technical terms in one line before using. Default to simple mode; deep-dive only when explicitly requested.
- **Database concepts:** Bhargav is learning database fundamentals hands-on. All Supabase and SQL concepts are relatively new. Anchor every teaching moment to AgentEdge-specific examples.

## Process Discipline

### Verify before write (2026-04-16)
Before writing SQL or code that references a table, ALWAYS query the actual deployed schema first (`information_schema.columns`, `pg_constraint`). Design documents have been wrong often enough that trusting them leads to long debug loops.

### Full audit before structural change (2026-05-03)
Before any DROP, ALTER, RENAME, or other structural change to an existing table, run the **full 8-query audit**:

1. **Columns** — `information_schema.columns`
2. **Constraints** — `pg_constraint` (check, unique, FK, PK)
3. **Foreign keys pointing INTO the table** — `information_schema.constraint_column_usage`
4. **RLS policies referencing the table** — `pg_policies` (qual + with_check)
5. **Indexes** — `pg_indexes`
6. **Triggers** — `information_schema.triggers`
7. **Views depending on the table** — `pg_views` (definition LIKE)
8. **Functions/procedures referencing the table** — `pg_proc` (prosrc LIKE)

Empty results are still verified results. Do not skip a query because "it's probably empty."

### View CLAUDE.md fresh from main before editing (2026-05-03)
Always `git checkout main && git pull && cat CLAUDE.md` before proposing edits. Do NOT trust pasted content from a chat as authoritative — older sessions on feature branches may have stale copies. Lessons accumulate across sessions; editing from a stale base overwrites recent additions.

### Class normalisation is cross-cutting (2026-05-06)
Every table with a `class` column requires auditing. Discovered across 4 separate tables during Pre-Wave-1; assume the next vertical (caterers, developers, printing) will have its own analog.

### DELETE-on-parent discipline (2026-05-06 / expanded 2026-05-08)
Before any DELETE on a parent table (any table whose `id` is referenced by columns in other tables):

1. Query for dependents in each candidate child table.
2. Decide explicit handling per dependent set: CASCADE / SET NULL / RESTRICT / manual cleanup.
3. **Many of our tables LACK FK constraints** — Postgres will not prevent or cascade automatically. Silent orphans are the default. Plan accordingly.
4. Document the decision in the migration script before executing.
5. If unsure, RESTRICT first. Safer to fail than silently orphan.

Original incident: `subjects` re-seed left orphaned `subject_id`s in `teacher_subjects`, which broke the RLS chain at `marks` INSERT — ~2 hours of misdirected debugging.

### Save-side error messages must surface real DB error code (2026-05-06)
Generic JS guesses obscure root cause. Log structured `{code, message, details, hint}` to console; surface diagnostic code suffix in user message. The day this rule was added, "no longer assigned to this class" hid an RLS 42501 rejection and cost ~2 hours.

### Schema-sensitive facts get verified by query, not by build-log re-read (2026-05-07)
Build log claims about schema state (table location, column type, row counts, FK relationships) cannot be trusted at face value. Always run an `information_schema` query against the live database before writing code that depends on schema facts. Two corrections were made on 2026-05-07 because of this — both cost 30+ minutes each.

### Re-verify backlog items against live state before working them (2026-05-08)
When picking up a backlog item, do NOT trust the description as written in CLAUDE.md or build logs. Re-verify against the live system first. Methods in priority order:
1. Direct query against live DB or live file (`sed`/`grep` on the actual code).
2. Fresh read of the relevant code section, not a paraphrase from a build log.
3. Most recent commit message for that area.

**Forbidden:** verifying by re-reading the build log entry that originally captured the item — that's circular verification and doesn't catch drift between capture-time and now.

Five Pre-Wave-1 items had partially-misleading descriptions caught only via re-verification (#2, #6, #9, #12, #16). Without this rule, all five would have been worked from incorrect designs.

### RLS audit before wiring agents (2026-05-12)
Run the full admin_team coverage audit before wiring any agent in AgentEdge Unified. Do not discover gaps one at a time. Two silent landmines hit on the same sweep (B-30, B-33) — both would have been caught upfront by the coverage query.

### Credential hygiene
Never echo real credential values in diffs. Store in named config objects (`AGENTEDGE_CONFIG`), never loose constants. Never commit real credentials to repo (see B-37 — still open in `AgentEdge_Unified` repo).

## Architectural Decisions (LOCKED — do not re-litigate)

- **Schema-per-business, not row-per-business.** Each pilot business gets its own schema. Bug isolation, DPDP right-to-erasure simplicity.
- **Universal field naming:** `business_id`, not `school_id`, for cross-vertical universality.
- **Two-layer agent naming:** DB stores Pulse names; UI shows industry names.
- **Single `parent_id` per student.** Mother and father share one parent ID per child. Many-to-many promotion deferred to post-launch.
- **Dedicated tables for high-frequency operational data** (attendance, marks, homework, etc.). Universal `events` table still exists for generic activity.
- **Mumbai region (ap-south-1) Supabase.** Set before project creation. Non-negotiable.
- **Layer 3 (`ae_intelligence`) is the moat.** Anonymised aggregates only. Never exposed to clients.
- **Agents must work with incomplete data.** Indian SME owners give 60–70% of truth initially. If agents break with partial data, they never reach Trust Stage 2.
- **Sales motion:** Demo on phone → pilot agreement → Excel data template → portal live within one week → conversion at day 30.
- **Emotional hook vs. business case:** 3-minute demo leads with Telugu AI tutor (emotional hook for parents/students). AgentEdge intelligence agents are the business case for the school owner.
- **One feature branch per stage.** `stage-N-short-description` naming.
- **Plan-then-diff-then-write discipline.** Web Claude plans + drafts; Claude Code applies + tests. Never compress this loop.
- **Stage 4 patterns to carry forward:** 7-field minimal upsert (send only what we control, let DB defaults handle the rest); leave-guard dialog via `useRef` (not lifted state); resolve teacher `entities.id` once on tab mount; class+section filter on every query.
- **`tools/core/` is a pending Python initiative, NOT a SQL migration.** Intended as a shared library (`schema.py`, `emitters.py`, `validators.py`, `output.py`) for mock data generation + future client data importers. Will live in a `tools/` folder when built, not `sql/`. Status: scoped, not implemented.

## Tools & Environment

- **Repo:** `github.com/Agentedge/School_Portal` (private)
- **Working directory:** `~/agentedge/School_Portal/` on Windows + WSL2 + Ubuntu 24
- **Node.js:** v24.15.0
- **Claude Code:** v2.1.138 in WSL Ubuntu
- **Supabase:** Mumbai (ap-south-1). Project `Agentedge's-Dev`. Free tier (S-1 upgrade pending).
- **Vercel:** Canonical deployment. Auto-deploys from GitHub `main`. Project: `school-portal`.
- **`gh` CLI:** Installed and authenticated. `gh pr create --base main --fill` for PRs.
- **Local dev:** `python3 -m http.server 8000` from repo root. Never `file://`.
- **WSL Supabase quirk:** WSL2 cannot route IPv6. Use Session Pooler endpoint (`aws-1`, not `aws-0`) for `pg_dump` and direct Postgres connections.
- **VS Code in WSL:** the `code` command is not available — use `nano` for in-terminal edits.
- **Backup:** OneDrive `agentedge backup/`. **Backup is NOT the repo.** Never edit code in OneDrive — only in `~/agentedge/School_Portal/`. Backup is downstream of repo.
- **DPDP Act 2023:** key legal constraint, especially for children's data in the school vertical.
- **SCERT Telangana syllabus:** content constraint defining the serviceable school market.

## Next Task

**Immediate (today):** Verify Stage 6 production deploy. Visit production URL, log in as `teacher1.test`, navigate Admin → Homework, confirm "+ New Homework" button is visible. No console errors. Smoking-gun proof Stage 6 is live.

**Highest-leverage single move (this week):** Lawyer email — DPA + Privacy Notice drafting. Gates Wave 1 migration. Has been parked >16 days; cost of further delay is direct cost on the June 8 timeline.

**Next build move (after non-technical unblockers):** TBD between Parent/Student homework views (B-43) for Pathshala, AgentEdge Unified polish (login form, credentials hygiene, deployment protection — see backlog B-24, B-27, B-37), or other Pre-Wave-1 cleanup. Pick after lawyer email is sent and Stephen has committed a data date.
