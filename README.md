# LinkedIn Job Automation — n8n Workflow

Autonomous AI agent that scrapes LinkedIn for fresh job postings, scores them against your profile using an ATS + recruiter-style rubric, persists results in Postgres, and delivers matched jobs with ready-to-send cold emails to your Google Sheet and inbox.

## 🎬 Demo

https://github.com/user-attachments/assets/4cc810b8-9a22-422c-83ee-a6af09c64efa

## 🎯 Features

- **Automated Scheduling** — runs at 9 AM and 5 PM on weekdays
- **AI Profile Analysis** (Gemini 2.5 Pro) — extracts primary/secondary roles, must-have/nice-to-have skills, seniority, target location, exclusions, LinkedIn `f_E` codes
- **LinkedIn Job Scraping** (Crawl4AI) — self-hosted scraper handles anti-bot detection (random user-agent, headed-browser fingerprint via `magic` mode, TLS quirks). Extracts job cards and full descriptions via `JsonCssExtractionStrategy`. Honors LinkedIn filters: keywords, location, freshness (`f_TPR`), experience level (`f_E`), pagination.
- **ATS + Recruiter Scoring Rubric** — hard gates (must-have skills, seniority band, location, exclusions) → weighted 0-100 score → red-flag deductions → APPLY / REVIEW / SKIP
- **Postgres Persistence** — full job records, dedup, recommendation tracking
- **Cold Email Generation** — personalized template per matched job
- **Google Sheets Tracker** — append-only audit log
- **Daily Email Digest** — HTML summary with cold emails inlined

## 🛠️ Prerequisites

| Service | Purpose | Free? |
|---|---|---|
| [Jina AI](https://jina.ai) | Read CV URL | ✅ Yes |
| [Google Gemini](https://aistudio.google.com) | Profile analysis + job scoring | ✅ Yes |
| Crawl4AI (self-hosted) | LinkedIn job scraping | ✅ Yes (Docker) |
| Postgres (self-hosted) | Job storage + dedup | ✅ Yes (Docker) |
| Google Sheets | Audit log | ✅ Yes |
| Gmail | Daily summary email | ✅ Yes |

## 🚀 Setup

### Step 1 — Start the stack

```bash
cp .env.example .env   # fill POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB, CRAWL4AI_API_BASE_URL, N8N_EDITOR_BASE_URL
docker compose up -d
```

Brings up `n8n` (5678), `crawl4ai` (11235), `postgres` (5432). `init.sql` auto-creates the `jobs` table with enums and triggers.

### Step 2 — Import the workflow

- n8n UI → **+** → **Import from file** → select `linkedin-job-automation.json`
- Workflow appears on canvas

### Step 3 — Configure your details

Open the **Configuration** node and fill in:

| Field | Description | Example |
|---|---|---|
| `candidateName` | Full name | `Shubham Yadav` |
| `candidateEmail` | Email address | `mailme@gmail.com` |
| `candidateMobile` | Phone | `+91-9999999999` |
| `yearsOfExperience` | Total years (decimals OK) | `4.7` |
| `linkedinUrl` | Public LinkedIn profile URL | `https://linkedin.com/in/yourprofile` |
| `cvUrl` | Public CV URL (markdown gist preferred) | `https://gist.github.com/...` |
| `targetLocation` | Target city | `Bengaluru` |
| `remotePreference` | `hybrid` / `remote` / `onsite` | `hybrid` |
| `maxJobsToProcess` | Cap per run | `10` |
| `jobsMaxAgeSeconds` | LinkedIn freshness filter (`f_TPR`) | `86400` (24 hr) |

> ⚠️ `cvUrl` must be publicly accessible. Test in incognito.

### Step 4 — Set up credentials

#### Jina AI
1. [jina.ai](https://jina.ai) → sign up → copy API key
2. n8n: **Credentials → Add → Jina AI** → paste key → connect to **Read URL content**

#### Google Gemini
1. [aistudio.google.com](https://aistudio.google.com) → **Get API Key**
2. Connect to both Gemini nodes:
   - **Google Profile Model** → `gemini-2.5-pro`
   - **Gemini Job Scoring Model** → `gemini-2.5-flash` (cheaper, fine for scoring)

#### Postgres
1. n8n: **Credentials → Add → Postgres**
2. Host: `postgres` (compose service name), Port: `5432`, DB / user / password from `.env`
3. Connect to **Fetch Already Processed Jobs** and **Save Job Applications To DB**

#### Crawl4AI
- No credential needed — workflow reads `CRAWL4AI_API_BASE_URL` from env (set in `docker-compose.yml`)

#### Google Sheets + Gmail
- Same Google OAuth2 — authorize once, attach to **Add Job Applications To Sheet** and **Send Daily Summary**

### Step 5 — Set up Google Sheet

1. Create sheet `LinkedInJobTracker`
2. Row 1 headers:
   ```
   JOB_ID | JOB_SCORE | JOB_RECOMMENDATION | JOB_TITLE | COMPANY_NAME | JOB_URL | POSTED_AT | COLD_EMAIL | JOB_MATCH_REASON
   ```
3. Update document URL in **Add Job Applications To Sheet**

### Step 6 — Test

1. Click **Execute Workflow**
2. Verify each node:
   - Jina reads CV
   - Profile agent emits valid JSON (primary roles, must-haves, exclusions, f_E codes)
   - Crawl4AI returns job cards (search) and descriptions (detail)
   - Job Scoring agent emits 0-100 score with breakdown + gates
   - Matched rows in Postgres + Sheet, digest in inbox

> 💡 Pin successful nodes (📌) to skip re-runs and save Gemini/Jina credits.

### Step 7 — Activate

Toggle **Active** top-right. Cron: `0 9 * * 1-5` and `0 17 * * 1-5`.

## 📊 How It Works

### Flow

```
Schedule Trigger (9 AM & 5 PM weekdays)
    ↓
Configuration
    ↓
Build Profile Sources → Loop → Jina (Read CV)
    ↓
Aggregate → Agent: Profile Generation (Gemini Pro)
    ↓
Build Search LinkedIn URLs (per query × pages, with f_TPR + f_E)
    ↓
Crawl4AI Scrap Jobs (LinkedIn search results, anti-bot handled)
    ↓
Parse Jobs Meta Data (extract jobId, build URLs)
    ↓
Fetch Already Processed (Postgres dedup)
    ↓
Limit Max Jobs → Loop Over New Jobs
    ↓
Crawl4AI Scrap Job Detail (full JD + criteria)
    ↓
Parse Job Detail (description ≤ 10k chars)
    ↓
Loop Over Jobs → Job Scoring Agent (Gemini Flash, ATS rubric)
    ↓
Build Job Application Data → Save to Postgres
    ↓
Filter (skip=false AND score≥55) → Build Cold Email
    ↓
[Build Email Summary → Send Daily Summary]
[Add Job Applications To Sheet]
```

### Scoring Rubric

**Skill Lookup** — agent uses `candidate.allSkills` (full inventory, 15-25 items) as ground truth, with synonym map (e.g. `CI/CD` ↔ Harness/Jenkins/GH Actions, `Testing` ↔ Jest/Junit/Mockito). Prevents false "lacks X" deductions.

**Stage 1 — Hard Gates** (any fail → SKIP, score capped 0-40):
- `mustHaveSkillsGate` — JD must-haves coverage in `candidate.allSkills` ≥60%
- `seniorityGate` — **tiered by JD required years** (mirrors real ATS: senior bands less forgiving):
  - JD ≤2y: under by ≥2 fail, over by ≥4 fail
  - JD 3-5y: under by ≥2 fail, over by ≥5 fail
  - JD ≥6y: under by ≥1.5 fail, over by ≥6 fail
- `locationGate` — same city OR remote OR aligned with `remotePreference`
- `exclusionGate` — no exclusion term in JD title

**Stage 2 — Weighted Score (0-100)**:
- `titleMatch` (20)
- `mustHaveSkillsMatch` (30)
- `niceToHaveSkillsMatch` (10)
- `seniorityMatch` (20) — **tiered, asymmetric**:
  - Senior band (JD ≥6y): delta ∈ [-1,+2] → 20; [-1.5,-1) → 10; (+2,+4] → 8; else → 0
  - Entry/Mid (JD ≤5y): within ±1 → 20; under 2 → 13; over 2 → 8; over 3-4 → 4
- `locationMatch` (10)
- `recencyMatch` (10) — must-have skills used in last 2 yrs

**Stage 3 — Red-Flag Deductions** (floor 0, strict — no invented penalties):
- mustHave skill fully missing → -15
- job-hopper screen + avg tenure <12mo → -8
- onsite required, candidate remote-only → -10

**Recommendation** (with hard caps):
- All gates pass + score ≥75 → `APPLY`
- All gates pass + 55-74 → `REVIEW`
- Otherwise → `SKIP`
- **Hard caps** (override base):
  - `seniorityMatch` == 0 → `SKIP`
  - `seniorityMatch` ≤10 → max `REVIEW` (never `APPLY`, even if score ≥75)

### Key Nodes

**Agent: Profile Generation** — Gemini Pro extracts structured profile (primary/secondary roles, must-have / nice-to-have skills, seniority, YoE, exclusions, location, LinkedIn `f_E` codes). Output validated by **Profile Parser**.

**Build Search LinkedIn URLs** — assembles LinkedIn search URLs with `keywords`, `location`, `f_TPR` (freshness), `f_E` (experience level), pagination.

**Crawl4AI Scrap Jobs / Job Detail** — POSTs to self-hosted Crawl4AI with `JsonCssExtractionStrategy` schema. Main reason to use Crawl4AI: built-in anti-bot detection handling — random user-agent, headed-browser fingerprint via `magic: true`, `ignore_https_errors` to dodge Chromium TLS quirks (`ERR_CERT_VERIFIER_CHANGED`), and natural scroll/delay to bypass LinkedIn login walls and rate-limit screens.

**Parse Jobs Meta Data** — derives `jobId` from URL, mints public `jobUrl` (for end user) and `scrapeUrl` (for detail fetch).

**Job Scoring Agent** — Gemini Flash applies the 3-stage rubric. Strict JSON output enforced by **Structured Output Parser**.

**Save Job Applications To DB** — saves scored jobs. Already-seen jobs are filtered out earlier (via **Fetch Already Processed Jobs**) so the same posting never gets scored twice — keeps Gemini cost down.

## 📈 Customization

### Change scoring threshold
**Filtered Job Applications** node → conditions → adjust `score >= 55`.

### Change schedule
**Schedule Trigger** → cron expressions. Note: container `TZ` defaults to UTC; cron times are UTC unless `TZ` / `GENERIC_TIMEZONE` env set on n8n service.

### Tune freshness window
**Configuration** → `jobsMaxAgeSeconds`. `86400` = 24 hr, `43200` = 12 hr.

### Add profile sources
**Build Profile Sources** code node → push more URLs (LinkedIn URL is currently disabled — Jina returns non-English content for it).

### Adjust scoring rubric
**Job Scoring Agent** → systemMessage. Update gates / weights / deductions. Keep schema in sync with **Structured Output Parser**.


## 🤝 Support

1. Check n8n execution logs for the failing node
2. Crawl4AI logs: `docker logs crawl4ai`
3. Postgres logs: `docker logs postgres`
4. API provider docs: Google AI Studio, Jina, Crawl4AI
