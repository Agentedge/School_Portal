# AgentEdge — St. Stephen's School Portal (Pathshala)

## Project Context

This is the Pathshala portal for St. Stephen's School (biz\_001). Single-file React 18 + Babel CDN app in index.html. No build step, no npm install — everything runs from CDN. Deployed via Vercel (vercel.json present). Repo: github.com/Agentedge/School\_Portal.

Owner: Bhargav Avadhanula (AgentEdge founder, M\&A IT Consultant at Deloitte USI)
Go-live target: June 1, 2026
Pilot customer: St. Stephen's School, Sangareddy, Telangana (KG-10, \~600 students)

## Database — Supabase (ap-south-1 Mumbai)

Project: Agentedge's-Dev
Schema-per-business architecture. biz\_001 = St. Stephens.
biz\_001 business UUID: cc460eea-9945-4e60-a17d-2a93754d5659

Deployed (as of 2026-04-18):

* 24 tables in biz\_001
* 59 RLS policies live across all 24 tables
* 4 test auth users created and linked
* Wave 0 mock data loaded (230+ rows across 16 tables)

## Test auth users

Password for all four: AgentEdgeTest2026!

* principal.test@agentedge.in  → UUID 55784bb1-3ad8-4a31-95dc-972f70c9b4b4 → role 'principal' → Sr. Philomena David
* teacher1.test@agentedge.in   → UUID 2eb28e93-f7bb-49d6-b760-223144fa9d4c → role 'teacher' → Ramesh Babu Yerra (Class 9A Class Teacher)
* parent1.test@agentedge.in    → UUID 343e527c-d0c3-494b-999b-6c9871ee7c21 → role 'parent' → Venkat Reddy (parent of STU001)
* student1.test@agentedge.in   → UUID 103bbc83-fe72-492f-b45b-144a01318417 → role 'student' → Ravi Kumar Reddy (STU001)

## Technical rules — NEVER violate

* No export default in CDN React files
* No JSX in pure HTML — React.createElement only (for agentedge\_unified.html when we touch it)
* Always run `node --check` on any standalone .js files before declaring work complete
* Always catch(e) — never catch {}
* No nested backtick template literals
* No escaped apostrophes in encodeURIComponent — rephrase instead
* jsDelivr (not cdnjs) for Babel
* Use actual deployed column names — NEVER design-doc names
* Serve the portal via `python3 -m http.server 8000`, never file:// — Supabase JS blocks file protocol
* **Supabase `onAuthStateChange` deadlock rule:** NEVER await a Supabase call (rpc, from, auth.signOut, etc.) directly inside the `onAuthStateChange` callback. Supabase holds an internal auth lock while the callback runs — awaiting any Supabase method deadlocks the next `getSession()`. Wrap the async work in `setTimeout(async () => { ... }, 0)` so it runs after the callback returns. The callback itself must be synchronous (no `async` keyword). Learned the hard way on 2026-04-26 — `getSession()` hung indefinitely on page refresh until fixed.

## Column name conventions (actual deployed Supabase schema)

* class (NOT class\_name)
* student\_id (NOT student\_entity\_id)
* teacher\_id (NOT teacher\_entity\_id)
* business\_id (NOT school\_id)
* first\_name + last\_name (NOT name)
* score (NOT marks\_obtained)
* awarded\_to\_student\_id on house\_points (NOT entity\_id)

## Schema Reality Notes (caught during Stage 4 testing, 2026-05-01)

These corrections apply across all remaining stages — record once, never debug twice.

* **`entities.auth\_user\_id` does NOT exist as a top-level column.** The auth link lives inside `entities.metadata` JSONB at key `auth\_user\_id`. To resolve a teacher/student/parent's `entity\_id` from their session:
  ```js
  .from("entities").select("id").eq("metadata->>auth_user_id", session.user.id).single()
  ```
  Applies to ALL entity types (teacher, student, parent), not just teachers.

* **`student\_profiles` has TWO foreign keys to `entities`** — `entity\_id` (the student themselves) and `parent\_id` (the parent). There is NO `student\_id` column on `student\_profiles`. When embedding entities from `student\_profiles`, disambiguate with the explicit FK hint:
  ```js
  .select("entity_id, entities!student_profiles_entity_id_fkey(first_name, last_name)")
  ```
  Plain `entities!inner(...)` throws `PGRST201` ("more than one relationship was found"). Also: `class` and `section` ARE top-level columns on `student\_profiles` (text, nullable) — `.eq("class", "Class 9").eq("section", "A")` works directly.

## RLS role values

Stored lowercase in ae\_platform.user\_roles ('principal', 'teacher', 'parent', 'student').
get\_user\_role() returns title case via INITCAP(). Policies check against title case.

## Wiring status

* **Stage 1 (DONE, 2026-04-20):** Supabase client (`db`) initialised at top of Babel block via `AGENTEDGE\_CONFIG`. UMD build loaded from jsDelivr. Default schema = `biz\_001`.
* **Stage 2 (DONE, 2026-04-25):** LoginScreen rewired to `db.auth.signInWithPassword`. Role derived from `db.rpc('get\_user\_role')` (function lives in `biz\_001`, not `ae\_platform` as originally assumed — schema override is NOT needed). Teachers also query `teacher\_assignments` for class/section scoping. All role strings are title-case throughout (INITCAP is the single translation layer — never toLowerCase()). Demo credentials + role-selector deleted.
* **Stage 3 (DONE, 2026-04-26):** Session restore via `db.auth.getSession()` on App mount + `onAuthStateChange` subscription for cross-tab sign-out propagation. Deadlock fix applied (see Technical rules).
* **Stage 4 (DONE, 2026-05-01):** AttendanceTab in `AdminPanel` rewired to `biz\_001.attendance`. Period-level grid (Date + Period 1-7 weekdays / 1-4 Saturday / hidden Sunday), 5-status buttons (Present / Absent / Late / Half Day / Leave), upsert via `onConflict: 'student\_id,date,period\_number'`. Teacher sees own class/section via `assignment` prop; Principal sees all (read-only, no edit buttons). All 6 browser tests passed (T1-T6); 18 test rows live in DB; RLS verified. Two schema corrections caught during T1 — see Schema Reality Notes.
* **Stage 5 (NEXT):** Marks tab wired live to `biz\_001.marks`. Same pattern as AttendanceTab — teacher edits own class only, principal read-only. First step: verify actual deployed schema for `biz\_001.marks` (columns, FKs, CHECK constraints, UNIQUE constraints) before designing UI. Process discipline rule applies.
* **Stage 6+ (FUTURE):** Homework, Performance, Student/Parent views still hardcoded.
* agentedge\_unified.html: separate repo, untouched.

## Stage 5 backlog

* **Redundant restore on page refresh:** on F5, `get\_user\_role` and `teacher\_assignments` fire twice — once from the initial `getSession()` path, once from the `SIGNED\_IN` event that fires after `getSession()` resolves. Functionally identical, \~100ms of wasted round-trips. Not a ship-blocker. Fix during Stage 5 cleanup with a guard flag or by relying on `onAuthStateChange` alone (dropping the explicit `getSession()` call).

## Next task

* Stage 5 — Marks tab live wiring. See Wiring status above for scope. **First action: query the actual deployed schema for `biz\_001.marks`** (columns, FKs, CHECK and UNIQUE constraints) before any UI design — process discipline rule applies (design docs have been wrong twice on this project; verify then write). Once schema is verified, document facts under this section the same way Stage 4 did.

## Process discipline (learned the hard way on 2026-04-16)

Before writing SQL or code that references a table, ALWAYS query the actual deployed schema first (information\_schema.columns, pg\_constraint). Design documents have been wrong often enough that trusting them leads to long debug loops. Verify then write.
## Schema migration log



\### 2026-04-29 — Period-level attendance migration

\*\*Reason:\*\* Stage 4 design pivoted from day-level to period-level once Stephen confirmed each subject teacher marks attendance per period (not once per day).



\*\*Changes applied to `biz\_001.attendance`:\*\*

\- TRUNCATE'd existing 96 mock rows (will be reloaded with real Class 9 data during Wave 1)

\- Added `period\_number INTEGER NOT NULL` column with `CHECK (period\_number BETWEEN 1 AND 7)`

\- Dropped old unique constraint `attendance\_student\_id\_date\_key` on `(student\_id, date)`

\- Added new unique constraint `attendance\_student\_date\_period\_key` on `(student\_id, date, period\_number)`

\- Dropped old `attendance\_status\_check` (4 values)

\- Added new `attendance\_status\_check` with 5 values: `('Present','Absent','Late','Half Day','Leave')`



\*\*Verified post-migration:\*\*

\- Column listing matches design (period\_number present, INTEGER, NOT NULL)

\- Constraints listing matches design (new period CHECK, new 5-value status CHECK, new 3-column UNIQUE)

\- Old day-level UNIQUE constraint confirmed gone

\- Row count = 0

