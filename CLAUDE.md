# AgentEdge — St. Stephen's School Portal (Pathshala)

## Project Context
This is the Pathshala portal for St. Stephen's School (biz_001). Single-file React 18 + Babel CDN app in index.html. No build step, no npm install — everything runs from CDN. Deployed via Vercel (vercel.json present); Netlify also auto-deploys preview environments — canonical deployment decision is open. Repo: github.com/Agentedge/School_Portal.

Owner: Bhargav Avadhanula (AgentEdge founder, M&A IT Consultant at Deloitte USI, Hyderabad)
Methodology: SAP ACTIVATE adapted (phases, waves, cutover, hypercare).
Go-live target: June 1, 2026
Pilot customer: St. Stephen's School, Sangareddy, Telangana (KG-10, ~600 students). Owner Stephen; mother is principal. Project codename: "Project Genesis."

## Strategic Anchor
AgentEdge is the autonomous business operating system for Indian SMEs, distributed via CA firms (white-label, revenue share). Not a tool company — an operating layer. Moat: Indian compliance depth (GST/TDS/Tally) + CA channel + business graph. Geography: Hyderabad first, then pan-India.

Two-product architecture for the school vertical:
- **Pathshala** — the school portal where teachers, students, and parents work. Data entry + consumption.
- **AgentEdge for Schools** (agentedge_unified.html) — the intelligence/agent layer for the school owner. Reads operational data; writes agent_signals and interventions.

Both products talk to the same Supabase database, biz_001 schema. RLS enforces who sees what across both.

Four pipeline businesses: St. Stephen's School (biz_001), Satya Caterers (biz_002, parked), Bhargavi Developers (biz_003), Sri Lakshmi Printing Press (biz_004).

## Database — Supabase (ap-south-1 Mumbai)
Project: Agentedge's-Dev
Schema-per-business architecture (locked CDO decision — never row-per-business).
biz_001 = St. Stephens.
biz_001 business UUID: cc460eea-9945-4e60-a17d-2a93754d5659

Three-layer data model (locked):
- **Layer 1 — Universal Core (7 tables):** businesses, entities, transactions, events, documents, agent_signals, interventions. Each business owns their data.
- **Layer 2 — Vertical Extensions:** student_profiles (school), catering_profiles, properties, print_job_profiles. Each business owns their data.
- **Layer 3 — ae_intelligence:** Anonymised aggregates, cross-SME patterns, benchmarks, health scores. No PII. AgentEdge proprietary — the moat. NEVER exposed to clients.

Schemas in the project: ae_platform (4 tables), biz_001 through biz_004 (each ~8+ tables), ae_intelligence (3 tables). DPDP right-to-erasure = drop schema.

Two-layer agent naming (locked architectural rule):
- DB always stores universal Pulse names: CashPulse, RetentionPulse, TeamPulse, EngagePulse, OutcomePulse, OutreachPulse, PipelinePulse, AssetPulse.
- UI shows industry-specific names: FeeAlert, AdmissionRadar, AttritionGuard, RouteWatch, StaffPulse, AttendanceFlag, ResultPredictor, ParentBridge.
- agent_signals.agent_name = 'CashPulse' always, NEVER 'FeeAlert'. Translation lives only in frontend.

Deployed (as of 2026-04-18):
- 24 tables in biz_001 (extended beyond the original 8 via 003_school_schema_correction.sql which added 15 tables resolving 7 deferred assumptions: parent_id design, dedicated attendance/marks/homework tables, house_points, transport tables, fee_structure + fee_payments, subjects + teacher_subjects + academic_calendar, teacher_assignments)
- 59 RLS policies live across all 24 tables (deployed via 004_fix_rls_column_names.sql; supersedes original 004 which had wrong column names)
- 4 test auth users created and linked
- Wave 0 mock data loaded (230+ rows across 16 tables)
- 8 demo students in Class 9 Section A

## Test auth users
Password for all four: AgentEdgeTest2026!
- principal.test@agentedge.in  → UUID 55784bb1-3ad8-4a31-95dc-972f70c9b4b4 → role 'principal' → Sr. Philomena David
- teacher1.test@agentedge.in   → UUID 2eb28e93-f7bb-49d6-b760-223144fa9d4c → role 'teacher' → Ramesh Babu Yerra (Class 9A Class Teacher)
- parent1.test@agentedge.in    → UUID 343e527c-d0c3-494b-999b-6c9871ee7c21 → role 'parent' → Venkat Reddy (parent of STU001)
- student1.test@agentedge.in   → UUID 103bbc83-fe72-492f-b45b-144a01318417 → role 'student' → Ravi Kumar Reddy (STU001)

## Technical rules — NEVER violate
- No export default in CDN React files
- No JSX in pure HTML — React.createElement only (for agentedge_unified.html when we touch it)
- Always run `node --check` on any standalone .js files before declaring work complete
- Always catch(e) — never catch {}
- No nested backtick template literals
- No escaped apostrophes in encodeURIComponent — rephrase instead
- jsDelivr (not cdnjs) for Babel
- Use actual deployed column names — NEVER design-doc names
- Serve the portal via `python3 -m http.server 8000`, never file:// — Supabase JS blocks file protocol
- One feature branch per stage. Branch naming: `stage-N-short-description`. Permanent PR record, easy rollback, sane history.
- Sensitive medical/health data (e.g. disability_status) is DPA-gated. Column may exist; do NOT populate values until DPA is signed and school explicitly opts in per DPDP Act 2023.
- **Supabase `onAuthStateChange` deadlock rule:** NEVER await a Supabase call (rpc, from, auth.signOut, etc.) directly inside the `onAuthStateChange` callback. Supabase holds an internal auth lock while the callback runs — awaiting any Supabase method deadlocks the next `getSession()`. Wrap the async work in `setTimeout(async () => { ... }, 0)` so it runs after the callback returns. The callback itself must be synchronous (no `async` keyword). Learned the hard way on 2026-04-26 — `getSession()` hung indefinitely on page refresh until fixed.

## Column name conventions (actual deployed Supabase schema)
- class (NOT class_name)
- student_id (NOT student_entity_id)
- teacher_id (NOT teacher_entity_id)
- business_id (NOT school_id)
- first_name + last_name (NOT name)
- score (NOT marks_obtained)
- awarded_to_student_id on house_points (NOT entity_id)

## Schema Reality Notes

These corrections apply across all remaining stages — record once, never debug twice.

### Caught during Stage 4 testing (2026-05-01)
- **`entities.auth_user_id` does NOT exist as a top-level column.** The auth link lives inside `entities.metadata` JSONB at key `auth_user_id`. To resolve a teacher/student/parent's `entity_id` from their session:
```js
  .from("entities").select("id").eq("metadata->>auth_user_id", session.user.id).single()
```
  Applies to ALL entity types (teacher, student, parent), not just teachers.

- **`student_profiles` has TWO foreign keys to `entities`** — `entity_id` (the student themselves) and `parent_id` (the parent). There is NO `student_id` column on `student_profiles`. When embedding entities from `student_profiles`, disambiguate with the explicit FK hint:
```js
  .select("entity_id, entities!student_profiles_entity_id_fkey(first_name, last_name)")
```
  Plain `entities!inner(...)` throws `PGRST201` ("more than one relationship was found"). Also: `class` and `section` ARE top-level columns on `student_profiles` (text, nullable) — `.eq("class", "Class 9").eq("section", "A")` works directly.

### Caught during Stage 5 prep (2026-05-03)
- **`student_profiles.class` value mismatch.** Existing seed data stores `'Class 9'` (with prefix). The newer `subjects.class` value stores `'9'` (number-as-text only). The Stage 5 ALTER plan will normalise to `'9'` everywhere. Until normalised, marks-related JOIN queries that filter on class must account for this — do NOT assume consistency.

- **`student_profiles` table predates Stage 5 planning.** It exists with 13 columns and 8 test rows. Six RLS policies depend on it (entities_teacher_select, teacher_subjects_parent_select, teacher_subjects_student_select, homework_parent_select, homework_student_select, house_points_teacher_all). Three downstream tables also depend on it: teacher_subjects, homework, house_points. **DROP/CASCADE forbidden.** Stage 5 path is ALTER (extend) not DROP+CREATE.

- **`entities` table uses generic flat-column shape with `metadata` JSONB.** Has 14 columns: id, business_id, entity_type, first_name, last_name, phone, email, whatsapp, address, status, tags, metadata (jsonb), created_at, updated_at. Roll number, class, section, parent_id are NOT stored on entities — they live on student_profiles.

- **`marks` table uses simple denormalised design.** 14 columns: mark_id, business_id (default 'biz_001'), student_id (uuid - entities.id), subject_id (uuid - subjects.subject_id), class, section, exam_type (text), exam_date (date), score (numeric, NULLABLE = absent for exam), max_marks (numeric, NOT NULL), marked_by (uuid - entities.id, nullable), academic_year (default '2026-27'), created_at, updated_at.
  - **exam_type CHECK:** `('Unit Test 1','Unit Test 2','Unit Test 3','Half Yearly','Pre-Final','Annual','Class Test','Assignment')` — exact casing. NO 'Mid Term'.
  - **score CHECK:** `score >= 0`. Database does NOT enforce `score <= max_marks` — UI must.
  - **max_marks CHECK:** `max_marks > 0`.
  - **Unique constraint:** `marks_unique_per_student_per_exam` — 5-column: `(business_id, student_id, subject_id, exam_type, exam_date)` — upsert key.
  - **FKs:** student_id - biz_001.entities(id) ON DELETE CASCADE; subject_id - biz_001.subjects(subject_id); marked_by - biz_001.entities(id).

- **`subjects` table seeded for Class 9 (2026-05-03).** 9 columns: subject_id, business_id, subject_name (NOT NULL), subject_code (NULLABLE), class, academic_year (default '2026-27'), is_active (default true), created_at, updated_at. 7 Class 9 rows seeded: Telugu, Hindi, English, Mathematics, Physical Science, Biological Science, Social Studies. subject_code intentionally NULL for all 7.

## Schema architectural rules (added 2026-05-07)

1. business_id type asymmetry: business_id is TEXT in biz_XXX schemas
   (e.g., biz_001.attendance.business_id is text). business_id is UUID
   in ae_platform tables (FK to ae_platform.businesses.id). When writing
   cross-schema joins or RLS policies, do not assume same type.

2. Role case convention: ae_platform.user_roles.role stores LOWERCASE
   strings ('teacher', 'principal'). The get_user_role() function applies
   INITCAP() and returns TITLE-CASE ('Teacher', 'Principal'). All RLS
   policies compare against title-case values. Do not change one without
   the other.

3. auth_user_id resolution path: entities.metadata.auth_user_id is the
   JS resolution mechanism for marked_by payloads. Full path:
     auth.users
       → ae_platform.user_roles.auth_user_id
       → biz_001.teacher_assignments.auth_user_id (where wired)
       → biz_001.entities.metadata.auth_user_id
   Any one of these breaks and marked_by inserts fail silently.

## RLS role values
Stored lowercase in ae_platform.user_roles ('principal', 'teacher', 'parent', 'student').
get_user_role() returns title case via INITCAP(). Policies check against title case. INITCAP is the SINGLE translation layer — never toLowerCase() anywhere else.

## Wiring status

- **Stage 1 (DONE, 2026-04-20):** Supabase client (`db`) initialised at top of Babel block via `AGENTEDGE_CONFIG`. UMD build loaded from jsDelivr. Default schema = `biz_001`.
- **Stage 2 (DONE, 2026-04-25):** LoginScreen rewired to `db.auth.signInWithPassword`. Role derived from `db.rpc('get_user_role')` (function lives in `biz_001`, not `ae_platform` as originally assumed — schema override is NOT needed). Teachers also query `teacher_assignments` for class/section scoping. All role strings are title-case throughout (INITCAP is the single translation layer — never toLowerCase()). Demo credentials + role-selector deleted.
- **Stage 3 (DONE, 2026-04-26):** Session restore via `db.auth.getSession()` on App mount + `onAuthStateChange` subscription for cross-tab sign-out propagation. Deadlock fix applied (see Technical rules).
- **Stage 4 (DONE, 2026-05-02):** AttendanceTab in `AdminPanel` rewired to `biz_001.attendance`. Period-level grid (Date + Period 1–7 weekdays / 1–4 Saturday / hidden Sunday). 5-status buttons (Present / Absent / Late / Half Day / Leave) — exact CHECK constraint casing. Upsert via `onConflict: 'student_id,date,period_number'`. Teacher sees own class/section via `assignment` prop; Principal sees all (read-only, no edit buttons). All 6 browser tests passed (T1–T6); 18 test rows live in DB; RLS verified. PR #1 merged to main. 7-field minimal upsert pattern locked. Leave-guard dialog ref-based pattern locked. Two schema corrections caught during T1 — see Schema Reality Notes (entities.auth_user_id, student_profiles dual FK).
- **Stage 5 (DONE, 2026-05-06):** ✅ MarksTab in `AdminPanel` live-wired to `biz_001.marks`. Replaces previous mock UI (~860 lines added).
  - Three branches: A (fresh entry, 0 dates) / B (silent load + edit, 1 date) / C (date picker with auto-detected `(make-up)` label on minority-row date, 2+ dates)
  - Ref-based leave-guard pattern (`dirtyCountRef`) — fixes stale-closure on tab/picker changes. Same pattern still owed for AttendanceTab in pre-Wave-1.
  - Save-only-dirty upsert; 5-priority validation precedence (range / max sanity / non-numeric / empty-not-Absent / pristine)
  - Make-up modal auto-filters to students absent on the primary exam (UX refinement vs original spec)
  - T1–T6 all PASSED. Merged via PR #2 → main commit `b883c74`.
- **Stage 6 (NEXT after Stage 5):** Parent + Student views, read-only, faster than Stage 5 (~1–2 days). Parent-student linkage may need to be promoted to many-to-many table. Read-only on Parent dashboard means no save buttons, no edit grid; same `metadata->>auth_user_id` pattern for role resolution.
- **Stage 7 (FUTURE):** AgentEdge Unified (agentedge_unified.html) wired to Supabase. 8 agents + Mitra. Separate Vercel project. ~3–5 days estimated; budget 6–8 days realistically. Needs 4 missing tables built first: `fees`, `admissions`, `staff_attendance`, `communication_logs`. Genuinely new territory — bring Web Claude back for planning. School owner Stephen logs into this dashboard, not the portal.
- agentedge_unified.html: separate repo decision pending; currently sits outside School_Portal.

## Pre-Wave-1 hardening backlog
1. ✅ **CLOSED 2026-05-07:** Class normalisation audit across remaining tables (academic_calendar, attendance, marks, house_points, fee_structure, transport_routes, transport_stops, plus any other table with a `class` column). 39 rows updated across 3 tables (`biz_001.attendance` 29 rows, `biz_001.fee_structure` 4 rows, `biz_001.teacher_subjects` 6 rows).
2. AttendanceTab stale-closure audit — apply ref-based leave-guard pattern same as MarksTab fix
3. `teacher_subjects` full rebuild with real teacher-subject assignments from Stephen (current rows are partly orphaned; only Ramesh's row was repointed today)
4. Auth credential creation for TCH002-TCH007 — 2 of 8 teachers (PRIN001 + TCH001-TCH007) have auth: Principal (PRIN001 / auth_user_id 55784bb1) + Class Teacher Ramesh (TCH001 / auth_user_id 2eb28e93). Subject teachers TCH002-TCH007 not yet wired.
5. Improve marks save error handling — currently shows misleading "no longer assigned to this class" for any RLS rejection; surface real DB error code/message instead
6. Disable already-used dates in make-up exam date picker (currently server-validated only via toast on conflict)
7. Constrain make-up date input to today or earlier (no `min`/`max` attributes today)
8. Improve shared `Sel` component to handle empty/falsy values (`o.value !== undefined ? o.value : o`)
9. `audit_log` trigger fix — use `NEW.business_id` instead of `OLD`
10. 9-or-10 column ALTER plan for `student_profiles` (deferred from Stage 5)
11. DELETE-on-parent discipline: audit FK-like references in dependent tables before destructive operations
12. Redundant auth restore on page refresh — on F5, `get_user_role` and `teacher_assignments` fire twice (once from the initial `getSession()` path, once from the `SIGNED_IN` event after `getSession()` resolves). ~100ms wasted round-trips. Not a ship-blocker. Fix with a guard flag or by relying on `onAuthStateChange` alone (dropping the explicit `getSession()` call).
13. ✅ **CLOSED 2026-05-07:** Drop `biz_002.user_roles` — architectural drift cleaned; table dropped (was empty scaffolding).
14. Investigate `agent_signals_all` naming pattern — determine whether it is a view, duplicate table, or architectural drift. Document the answer.
15. Audit `biz_003` (Bhargavi Developers) and `biz_004` (Printing Press) schemas for `user_roles` drift similar to what was found in `biz_002`. Proactive cleanup before those verticals start.
16. Investigate `teacher_profiles` asymmetry vs `student_profiles` — `student_profiles` exists, `teacher_profiles` does not. Decide whether to add `teacher_profiles` or remove `student_profiles` for symmetry.
17. Email convention reconciliation — `auth.users` uses test pattern (e.g., `teacher1.test@agentedge.in`); `biz_001.entities` use real school emails. Defer execution until Stephen confirms domain.
18. Confirm full body of `get_user_role()` function — visually verify the WHERE clause matches the role case convention documented in the Schema architectural rules section above.

**Pre-Wave-1 backlog: 16 open + 2 closed = 18 items tracked (as of 2026-05-07).**

## Wave 2 / Stage 4 deferred UX backlog
- **Principal read-only view:** Hide edit controls post-Stage 4 (currently functional via assignment=null path; refine UI affordances).
- **Class Teacher vs Subject Teacher granular permissions:** Needs `teacher_subject_assignments` table — overlaps with the `teacher_subjects` table that already exists; reconcile during Stage 7.
- **Attendance rewrite future direction:** Daily per-student view, not percentage (already done in Stage 4).
- **Tabular student layout with inline edit grid for Teacher and Principal dashboards:** Carry over to MarksTab via current Stage 5 design.
- **Future-date attendance:** Currently allowed (no UI restriction). Flag for Stephen if blocking is desired.

## Open non-technical items
- **Lawyer call (PARKED but URGENT):** DPA + Privacy Notice drafting. Hard gate before Wave 1 migration. The longer this slips, the more it constrains May 10 to June 1 path. (User has explicitly chosen to leave the lawyer call out of current technical-track conversations; flag in build logs.)
- **Stephen call:** Lock May 10 as data delivery date. Confirm Saturday period count practical usage. Confirm Half Day vs Leave usage in practice. Resend data template with explicit deadline.
- **Vercel vs Netlify decision:** Both auto-deploy preview environments. Pick canonical (recommend Vercel). Disconnect the other.
- **Domain purchase:** School-relevant TLD (e.g. ststephens.school or pathshala.school). Blocks marketing site.
- **Pricing decision:** Rs.15 vs Rs.35 entry pricing question outstanding from Apr 24. Doesn't block tech work but blocks pilot agreement, marketing site copy, CA pitch.
- **Marketing site:** Overdue ~11+ days. One page, screenshots, pricing, "Book a Demo" wa.me link.
- **CA firm coffee:** First conversation must happen this week. No closing in May, just relationship start.
- **Pilot agreement with Stephen:** Sign once pricing locked.
- **Real Class 9 student data collection from Stephen:** Excel template returned with sample rows only as of Apr 28; resend with hard deadline.

## Path to June 1 go-live (26 days from 2026-05-06)

| Window | Work |
|---|---|
| This week (May 6–12) | Pre-Wave-1 hardening + non-technical critical path (lawyer call for DPA/Privacy Notice, Stephen call to lock May 10 data delivery, domain purchase, Supabase Pro decision) |
| Week 2 (May 13–19) | Wave 1 migration if data is in + Stage 6 HomeworkTab build |
| Week 3 (May 20–26) | UAT rounds 1 & 2 + teacher training + parent WhatsApp setup |
| Week 4 (May 27–June 1) | Dress rehearsal + GO-LIVE June 1 |

Sequence: Pre-Wave-1 hardening - DPA signed (legal gate) - Wave 1 migration - Stage 6 HomeworkTab - UAT - dress rehearsal - June 1.

## Working style (locked)
- **Hand-holding mode (locked 2026-04-29):** One sub-step at a time. Plain English explanation BEFORE showing code. Line-by-line breakdown of code/SQL longer than 5 lines. Query deployed state before writing code that touches it. Call out trade-offs explicitly, invite pushback. Pause for confirmation on destructive actions (TRUNCATE, DROP) before running.
- **CTO cross-questioning:** Before approving major architectural moves (new stages, schema changes, security decisions, scope expansions), ask comprehension-check questions. Pair with active assumption-surfacing — name assumptions explicitly before they become mistakes.
- **Communication tone:** Simple, plain language. No jargon density. Everyday analogies (hotel keys, conference rooms, walking between buildings). Short responses, short sentences. Define technical terms in one line before using. Default to simple mode; deep-dive only when explicitly requested.
- **Database concepts (as of April 2026):** Bhargav is learning database fundamentals hands-on. All Supabase and SQL concepts are relatively new. Anchor every teaching moment to AgentEdge-specific examples.

## Process discipline

### Verify before write (learned 2026-04-16)
Before writing SQL or code that references a table, ALWAYS query the actual deployed schema first (information_schema.columns, pg_constraint). Design documents have been wrong often enough that trusting them leads to long debug loops. Verify then write.

### Full audit before structural change (learned 2026-05-03)
Before any DROP, ALTER, RENAME, or other structural change to an existing table, run the **full 8-query audit**. Verifying columns alone is NOT enough. The audit:

1. **Columns** — `information_schema.columns` filtered to schema + table
2. **Constraints** — `pg_constraint` joined for check, unique, FK, and PK definitions
3. **Foreign keys pointing INTO the table** — `information_schema` joins on `constraint_column_usage`
4. **RLS policies referencing the table** — `pg_policies` filtered with `qual LIKE '%table_name%'`
5. **Indexes** — `pg_indexes` filtered to schema + table
6. **Triggers** — `information_schema.triggers` filtered to schema + table
7. **Views depending on the table** — `pg_views` filtered with `definition LIKE '%table_name%'`
8. **Functions/procedures referencing the table** — `pg_proc` filtered with `prosrc LIKE '%table_name%'`

Empty results are still verified results. Do not skip a query because "it's probably empty." The point of the audit is to verify, not to assume.

The 2026-05-03 incident: tried to DROP `student_profiles` to recreate it with extra columns. DROP failed safely because 6 RLS policies depended on it (entities_teacher_select, teacher_subjects_parent_select, teacher_subjects_student_select, homework_parent_select, homework_student_select, house_points_teacher_all) — plus 3 dependent tables that weren't on our radar (teacher_subjects, homework, house_points). Had `CASCADE` been used, all 6 policies would have been silently destroyed. PostgreSQL caught it. The audit rule ensures we catch it next time.

### Always view CLAUDE.md fresh from main before editing (learned 2026-05-03)
When proposing edits to CLAUDE.md, always run `git checkout main && git pull && cat CLAUDE.md` first to see the actual current contents. Do NOT trust pasted content from a chat as authoritative — older sessions on feature branches may have stale copies. Lessons accumulate in CLAUDE.md across sessions, and editing from a stale base risks overwriting recent additions. The 2026-05-03 incident: started drafting CLAUDE.md edits based on a copy from the `stage-1-to-4-supabase-wiring` branch; pulling main brought down 133 lines of CLAUDE.md content from a separate session that hadn't been visible. Always pull main and `cat` first.

### Class normalisation is a cross-cutting discipline (learned 2026-05-06)
Class normalisation is a cross-cutting data-quality discipline. 4th occurrence today (`subjects`, `teacher_assignments`, `student_profiles`, `teacher_subjects`). Every table with a `class` column requires auditing.

### Never DELETE without auditing FK-like references in dependent tables (learned 2026-05-06)
Never DELETE rows from a parent table without auditing FK-like references in dependent tables first. Yesterday's `subjects` re-seed left orphaned `subject_id`s in `teacher_subjects`, which broke the RLS chain at marks INSERT today.

### Save-side error messages must surface real DB error code (learned 2026-05-06)
Save-side error messages must surface real DB error code and message. Generic JS guesses obscure root cause; today's "no longer assigned to this class" hid an RLS 42501 rejection and cost ~2 hours of misdirected debugging.

### Schema-sensitive facts get verified by query, not by build-log re-read (learned 2026-05-07)
Schema-sensitive facts get verified by query, not by build-log re-read. Build log claims about schema state (table location, column type, row counts, FK relationships) cannot be trusted at face value. Always run an `information_schema` query against the live database before writing code that depends on schema facts. Two corrections were made on 2026-05-07 because of this — both cost 30+ minutes each.

## Architectural decisions (locked, do not re-litigate)

- **Schema-per-business, not row-per-business.** Each pilot business gets its own schema (biz_001 through biz_004). Bug isolation, DPDP right-to-erasure simplicity.
- **Universal field naming:** `business_id`, not `school_id`, for cross-vertical universality.
- **Two-layer agent naming:** DB stores Pulse names (universal); UI shows industry names (FeeAlert, etc.).
- **Single parent_id per student.** Mother and father share one parent ID per child. If they have two children, two parent IDs. Many-to-many promotion deferred to Stage 6.
- **Dedicated tables for high-frequency operational data** (attendance, marks, homework, homework_submissions, performance_observations, house_points, transport, fee_structure, fee_payments, subjects, teacher_subjects, academic_calendar). Universal `events` table still exists for generic activity.
- **Mumbai region (ap-south-1) Supabase.** Set before project creation. Non-negotiable.
- **Layer 3 (ae_intelligence) is the moat.** Anonymised aggregates only. Never exposed to clients.
- **Agents must work with incomplete data.** Indian SME owners give 60–70% of truth initially. If agents break with partial data, never reach Trust Stage 2.
- **GTM constraint:** Telugu AI tutor content tied to SCERT syllabus. Limits school product to Telangana state board for now. CBSE/ICSE need additional content builds.
- **Sales motion:** Demo on phone - pilot agreement - Excel data template - portal live within one week - conversion at day 30.
- **Emotional hook vs. business case:** 3-minute demo leads with Telugu AI tutor study tab (emotional hook for parents/students). AgentEdge intelligence agents are the business case for the school owner.
- **Bootstrap discipline:** No fundraising until 25 SMEs are live. Target exit valuation improves significantly at 100 SMEs vs. 25.
- **One feature branch per stage.** stage-N-short-description naming.
- **Plan-then-diff-then-write discipline.** Web Claude plans + drafts; Claude Code applies + tests. Never compress this loop.
- **Stage 4 patterns to carry forward:** 7-field minimal upsert (send only what we control, let DB defaults handle the rest); leave-guard dialog via useRef (not lifted state); resolve teacher entities.id once on tab mount; class+section filter on every query.

## Tools, environment, infrastructure

- **Repo:** github.com/Agentedge/School_Portal
- **Local working directory:** `~/agentedge/School_Portal/` on Windows + WSL2 + Ubuntu 24
- **Node.js:** v24.15.0
- **Supabase:** Mumbai region (ap-south-1) — database and authentication
- **Vercel + Netlify:** Both currently auto-deploying preview environments. Canonical decision pending (recommend Vercel).
- **gh CLI:** Installed and authenticated. Use `gh pr create --base main --fill` for PRs.
- **Branch model:** `main` (production), feature branches `stage-N-...` per stage.
- **Local dev server:** `python3 -m http.server 8000` from repo root. Never serve via `file://`.
- **Backup:** OneDrive `agentedge backup/` folder. **Backup is NOT the repo.** Never edit code in OneDrive — only edit in the live repo at `~/agentedge/School_Portal/`. The backup is downstream of the repo.
- **DPDP Act 2023:** Key legal constraint, especially for children's data in school vertical.
- **SCERT Telangana syllabus:** Content constraint defining serviceable school market.
- **Lead sourcing:** UDISE+ government database + Google Maps for school outreach.

## Financials (know these)
- Growth plan: Rs.6,999/mo. COGS: Rs.1,150. Gross margin: 84%.
- LTV (24 months): Rs.1,40,376. CAC via CA firm: <Rs.5,000. LTV:CAC = 28:1.
- Break-even: ~5 SMEs. Bootstrap to 25 SMEs before fundraising.
- Exit at 25 SMEs: Rs.2–3 Cr expected. Exit at 100 SMEs: Rs.15–25 Cr.
- (Per-student pricing model and revised COGS were discussed in Apr 21 Part 2 strategy session — implementation deferred until post-pilot.)

## Schema migration log

### 2026-04-15 — biz_001 schema correction
**Reason:** Validation of 7 deferred assumptions from Apr 5 schema generation. School-specific tables needed beyond the universal core.

**Changes via 003_school_schema_correction.sql (DEPLOYED):**
- Added 15 new tables resolving all 7 deferred assumptions: dedicated attendance/marks/homework/homework_submissions/performance_observations tables; house_points; transport_routes/transport_stops/student_transport; fee_structure + fee_payments; subjects + teacher_subjects + academic_calendar; teacher_assignments
- Decisions locked: single parent_id per student, dedicated structured tables for high-frequency data, transport tables required for RouteWatch agent

### 2026-04-16 — Wave 0 mock data + column-name correction loop
**Reason:** Deploy operational test data; reconcile column names between design docs and actual deployed schema.

**Changes:**
- 000_prerequisites.sql DEPLOYED — foundation schemas, trigger functions, user_roles table, 5 RLS helper functions
- 006_cleanup_student_profiles.sql DEPLOYED — dropped redundant route/stop text columns
- 005_wave0_mock_data_v3.sql DEPLOYED — 24 entities, 8 students in Class 9/Section A, 96 attendance rows, 25 fee payments across 16 tables
- Architecture Deviation Report identified 5 deviations between design and deployed schema; column mapping table finalised

### 2026-04-18 — RLS policies + auth linkage
**Reason:** Original 004_school_rls_policies.sql was syntax-valid but referenced wrong column names — ZERO policies were actually attached at runtime. Auth users needed end-to-end linkage.

**Changes:**
- 004_fix_rls_column_names.sql DEPLOYED — 59 RLS policies across 24 biz_001 tables using actual deployed column names (class not class_name, student_id not student_entity_id, etc.). Verified via 3 post-deploy queries.
- 006_auth_setup.sql DEPLOYED — 4 Supabase Auth test users created and linked end-to-end. Two-part SQL: Part A dashboard instructions, Part B DO block updating entities.metadata.auth_user_id, teacher_assignments.auth_user_id, ae_platform.user_roles.
- get_user_role() with INITCAP wrapper deployed — single point of role-case translation.

### 2026-04-29 — Period-level attendance migration
**Reason:** Stage 4 design pivoted from day-level to period-level once Stephen confirmed each subject teacher marks attendance per period (not once per day).

**Changes applied to `biz_001.attendance`:**
- TRUNCATE'd existing 96 mock rows (will be reloaded with real Class 9 data during Wave 1)
- Added `period_number INTEGER NOT NULL` column with `CHECK (period_number BETWEEN 1 AND 7)`
- Dropped old unique constraint `attendance_student_id_date_key` on `(student_id, date)`
- Added new unique constraint `attendance_student_date_period_key` on `(student_id, date, period_number)`
- Dropped old `attendance_status_check` (4 values)
- Added new `attendance_status_check` with 5 values: `('Present','Absent','Late','Half Day','Leave')`

**Verified post-migration:**
- Column listing matches design (period_number present, INTEGER, NOT NULL)
- Constraints listing matches design (new period CHECK, new 5-value status CHECK, new 3-column UNIQUE)
- Old day-level UNIQUE constraint confirmed gone
- Row count = 0 (then 18 fake test rows loaded for Stage 4 testing)

### 2026-05-03 — Class 9 subjects seeded
**Reason:** Stage 5 prep. The marks table FK requires subject_id values to exist before any marks can be inserted.

**Changes applied to `biz_001.subjects`:**
- Inserted 7 rows for Class 9: Telugu, Hindi, English, Mathematics, Physical Science, Biological Science, Social Studies
- subject_code intentionally NULL for all 7 rows (UI will display full subject_name)
- Default values used for business_id ('biz_001'), academic_year ('2026-27'), is_active (true)

**Verified post-seed:**
- 7 rows returned for class = '9' AND is_active = true
- Subject names match the SCERT syllabus block in index.html (which is canonical for Class 9 study content)

### 2026-05-03 — student_profiles audit (PRE-ALTER, no schema change yet)
**Reason:** Stage 5 needs roll_number, academic_year, status (with CHECK), and 6 other optional fields on student_profiles. Initial plan was DROP + recreate. Audit caught dependencies.

**Audit findings:**
- Existing table has 13 columns (id PK, business_id, entity_id FK, parent_id FK, admission_number, class, section, house, date_of_birth, blood_group, metadata jsonb, created_at, updated_at)
- 8 test student rows pre-seeded (Class 9 Section A) — `class` value is `'Class 9'` with prefix
- 6 RLS policies depend on the table (named above)
- 3 downstream tables depend on the table (teacher_subjects, homework, house_points)
- Zero foreign keys point INTO student_profiles from other tables (Query C empty result)

**Decision:** Pivot from DROP + recreate to ALTER + extend. Preserve all 6 RLS policies, all 8 rows, all 3 downstream-table relationships. Plan: ALTER ADD 9 columns; UPDATE class value 'Class 9' to '9'; ALTER ADD CHECK on status; ALTER ADD UNIQUE on (business_id, class, section, roll_number, academic_year); CREATE partial INDEX on active students. ~30 minutes work.

### 2026-05-05 — business_id alignment + class normalisation + marks UNIQUE
**Changes:**
- `business_id` alignment across 14 tables (362 rows updated to `'biz_001'` in single transaction)
- Class normalisation across 3 tables (`student_profiles`, `subjects`, `teacher_assignments`) — `'Class 9'` → `'9'`
- UNIQUE constraint `marks_unique_per_student_per_exam` added on `biz_001.marks` (5-column: `business_id, student_id, subject_id, exam_type, exam_date`)

### 2026-05-06 — Class normalisation extended + teacher_subjects FK repoint
**Changes:**
- Class normalisation extended to `teacher_subjects` (4th table)
- `teacher_subjects.subject_id` repointed for Ramesh (`b1000001-…`) from orphaned `a1b2c301-0002-…` to current Mathematics UUID `bdde6895-c643-47a0-a513-4552aa6e42b7`
- Backup table `biz_001.teacher_subjects_backup_20260506` created (RLS-enabled, postgres-only)

### 2026-05-06 — Stage 5 build merged
**Changes:**
- PR #2 squash-merged to main (commit `b883c74`)
- MarksTab ~860 lines added; 5 diagnostic console.log lines removed for shipping
- T1–T6 all PASSED

## Next task

- **Immediate next move:** lawyer email (DPA + Privacy Notice; DPDP Act 2023 + children's data) — gates Wave 1 migration.
- **Next stage of build:** Pre-Wave-1 hardening sub-stage (this week), then Stage 6 HomeworkTab (Week 2).
