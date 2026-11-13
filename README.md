# job-hunt-automation

A Claude Code agent that runs your job search from Slack:

1. **Every morning** it searches LinkedIn for roles that match your filters (role type, years required, cities,
   excluded companies, red-flag phrases), scores each job against your CV, and posts the good ones to a Slack channel.
2. For each job it checks whether one of your LinkedIn connections works there and drafts a referral request in your
   own words and language. If nobody does, it asks whether you want to apply yourself or connect with someone first.
3. **You reply in the job's Slack thread from your phone** (`apply`, `skip`, `sent`, `applied`, …). On `apply` it tailors
   a copy of your CV and sends an application kit. On `applied` it adds the job to your tracker sheet and archives the
   full job post.

You stay in control: the agent **never** sends LinkedIn messages or submits applications. You do that yourself.

**No personal data lives in this repo.** Your profile, filters, CV, templates and job tracking live in your own Google
Drive. The repo only stores the ID of one config doc, in a git-ignored file.

> **For AI assistants (Claude Code, etc.):** the operating instructions are in [`CLAUDE.md`](CLAUDE.md).
> If `job-hunt.local.yaml` doesn't exist, the user hasn't been set up yet: follow **"Run 0: first-time setup"** there.

---

## Contents
1. [What you need](#1-what-you-need)
2. [Quick start: let Claude set you up](#2-quick-start-let-claude-set-you-up)
3. [Manual setup, step by step](#3-manual-setup-step-by-step)
4. [Daily use](#4-daily-use)
5. [How it works](#5-how-it-works)
6. [Scheduling](#6-scheduling)
7. [Troubleshooting](#7-troubleshooting)
8. [Privacy](#8-privacy)
9. [Disclaimer and license](#9-disclaimer-and-license)

---

## 1. What you need
| | Why |
|---|---|
| [Claude](https://claude.ai) with **Claude Code** (desktop app or CLI) | Runs the agent |
| Google account + Claude connectors **Google Drive**, **Google Docs**, **Google Sheets** | Your private config, CV, tracker |
| Slack workspace + Claude connector **Slack** | Where jobs arrive and you reply |
| GitHub account | To clone; also needed for cloud scheduling |
| Your CV (PDF, Word or Google Doc) | Matching and tailoring |
| *(optional)* LinkedIn data export | Referral suggestions |

Enable the connectors in Claude: **Settings → Connectors** → Google Drive, Google Docs, Google Sheets, Slack → Connect.

## 2. Quick start: let Claude set you up
```bash
git clone https://github.com/karawanshy/job-hunt-automation.git
cd job-hunt-automation
```
Open the folder in Claude Code and say:

> **Set me up for the job hunt.**

Claude follows "Run 0" in `CLAUDE.md`. It interviews you, creates the whole Drive structure, writes your config, helps
you create the Slack bot, and does a test run. Plan for about 20–30 minutes. Things only you can do (they're explained
when you reach them):
- add your CV to the `Job Hunt` folder as a Google Doc: upload it, double-click it, **Open with → Google Docs**,
  then (for a .docx) **File → Save as Google Docs**;
- create the Slack bot and save its webhook URL in your own terminal (§3.5);
- request the LinkedIn export (§3.6).

## 3. Manual setup, step by step
Use this if you prefer to do it yourself, or to understand what the quick start creates.

### 3.1 Clone
```bash
git clone https://github.com/karawanshy/job-hunt-automation.git
cd job-hunt-automation
```

### 3.2 Create the Drive structure
Drive starts empty. Create this (names are suggestions):
```
Job Hunt/                          (folder)
├── Config/                        (folder)
│   ├── Job Hunt Config            (Google Doc, plain YAML, see 3.3)
│   ├── Referral Request Template  (Google Doc)
│   └── CV Extra Material          (Google Doc, optional)
├── Tailored CVs/                  (folder: tailored copies land here)
├── <Your Name> - CV               (Google Doc: your master CV, never edited)
├── Job Hunt - Pipeline            (Google Sheet: every job the agent found)
├── Job Hunt - Tracker             (Google Sheet: jobs you applied to)
└── Job Posts Archive              (Google Doc: full text of jobs you applied to)
```
How to fill each one:

| Item | What to put in it |
|---|---|
| **Master CV** | In `Job Hunt`: **New → File upload** your CV (.docx keeps the layout best; PDF works) → double-click it → **Open with → Google Docs** → for a .docx also **File → Save as Google Docs**. Check the Google Doc landed in `Job Hunt` (else **File → Move**). Use the Google Doc, not the PDF or .docx |
| **Referral Request Template** | Your referral message per language, `[Name]` where the name goes. Example: [`examples/templates.example.md`](examples/templates.example.md) |
| **CV Extra Material** | *Optional.* True achievements that aren't on your CV; tailoring may pull them in when a job fits |
| **Job Hunt - Pipeline** | Row 1 headers from [`examples/pipeline_columns.md`](examples/pipeline_columns.md) (A–T). Nothing else |
| **Job Hunt - Tracker** | Row 1 headers in A–Q: `owner_marker, Company, Role Title, Location, Work Model, Salary Range, Date Applied, Status, Referral, Contact, Last Update, Notes, Link, Date Found, Applicants, Match, Follow-up Due`. Dropdowns (Data → Data validation, "Reject input") for Work Model `Hybrid, On-Site, Remote` · Status `Applied, OA, Recruiter Screen, Technical Interview, Manager Interview, Final Round, Offer, Rejected, Ghosted` · Referral `Yes, No`. Quick start sets all of this up for you. **Already have a tracker, maybe shared with a friend?** Use it: set `tracker.my_columns` to your columns and the agent never writes outside them |
| **Job Posts Archive** | Empty, or a heading line |

**Finding IDs:** the ID is the long part of each URL:
`docs.google.com/document/d/`**`<ID>`**`/edit` · `docs.google.com/spreadsheets/d/`**`<ID>`**`/edit` · `drive.google.com/drive/folders/`**`<ID>`**

### 3.3 Write your config doc
Copy all of [`examples/config.example.yaml`](examples/config.example.yaml) into **Config/Job Hunt Config** and replace
every value. Keep the indentation; it's YAML. Sections:

| Section | What it controls |
|---|---|
| `profile` | Your details. Used for application answers. `current_employer` is always excluded |
| `search` | Roles (in priority order), title words to avoid, years filter, allowed and excluded cities, daily cap |
| `schedule` | Daily scan time (default 08:00) and how often to check Slack replies (default every hour, 09:00–21:00; 1 h is the cloud minimum) |
| `exclusions` | Companies to never show, rules (e.g. "no defense companies"), phrases that drop a post, companies to ask about first |
| `referrals` | Your own grouping of connections, who to ask first, and which language to write to each group |
| `slack` | Channel ID (§3.5) |
| `google` | IDs of everything from §3.2 |
| `tracker` | Tracker sheet ID, which columns are yours, column order, exact dropdown values |

### 3.4 Point the repo at your config
```bash
cp job-hunt.local.example.yaml job-hunt.local.yaml
```
Put your config doc ID in it. The file is git-ignored, so it's never committed.

### 3.5 Slack channel + bot (so you get notifications)
The Slack connector posts as **you**, and Slack never notifies you about your own messages. So the agent posts through
a tiny bot instead.
1. Create a private channel, e.g. `#job-hunt`. Open it → click the name → **About** → copy the **Channel ID** at the
   bottom into `slack.channel_id`.
2. Go to <https://api.slack.com/apps> → **Create New App** → **Paste manifest** → pick your workspace → paste:
   ```yaml
   display_information:
     name: Job Hunt Bot
   features:
     bot_user:
       display_name: Job Hunt Bot
       always_online: false
   oauth_config:
     scopes:
       bot:
         - incoming-webhook
   settings:
     org_deploy_enabled: false
     socket_mode_enabled: false
     token_rotation_enabled: false
   ```
   → **Create**. When it shows "run your app locally / Slack CLI", **skip it** → **Go to App Settings**.
3. **Incoming Webhooks** (left menu) → **On** → **Add New Webhook to Workspace** → choose your channel → **Allow** →
   copy the Webhook URL (`https://hooks.slack.com/services/…`).
4. Save it on your computer. Run this in your **own terminal app** (not inside a chat, which can't wait for input).
   It asks you to paste the URL and hides it:
   ```bash
   mkdir -p ~/.config/job-hunt && read -s "?Paste Slack webhook URL: " u && printf '%s' "$u" > ~/.config/job-hunt/slack_webhook && chmod 600 ~/.config/job-hunt/slack_webhook && echo " saved"
   ```
   That's zsh (the macOS default). In bash, use `read -s -p "Paste Slack webhook URL: " u` instead.
5. Test it: `scripts/slack_post.sh "hello from the bot"`
6. In Slack: channel name → **Notifications** → **All new messages**, and allow Slack notifications on your phone.

The webhook URL is a secret. Never commit it or paste it into a chat or an issue.

### 3.6 Referrals (optional)
1. LinkedIn → **Settings → Data privacy → Get a copy of your data** → choose **"Download larger data archive"**
   (Connections isn't among the smaller checkboxes) → **Request archive**.
2. When the email arrives (up to ~24 h), unzip it and upload `Connections.csv` to `Job Hunt/Config/`.
3. On the next run the agent builds a `Connections` sheet with a `tag` column using your `referrals.tags`, guesses tags
   from names, and asks you in Slack to check them once. Name-based guesses are often wrong, so do check.

### 3.7 First run
In Claude Code:
> Run the daily scan (Run A) as a test, max 3 jobs.

Check Slack, reply `apply` in one job's thread, then:
> Check my Slack replies (Run B).

## 4. Daily use
Reply **inside the job's thread**:

| Reply | What happens |
|---|---|
| `apply` | Tailored CV copy (when worth it, with every change listed) + application kit: your standard answers, draft screening answers, apply link, warnings |
| `connect first` | Connection-note drafts (≤300 characters) |
| `sent` | You sent the referral request. A follow-up draft comes after 5 days with no reply |
| `edit: …` / `other person` | Redraft the referral / choose another connection |
| `skip` | Drop this job |
| `exclude <company>` | Drop it and stop showing that company |
| `applied` | Row added to your tracker + full post saved to the archive |
| `oa` `screen` `interview` `rejected` `offer` `ghosted` | Tracker status updated |

## 5. How it works
- **Run A, daily scan:** search → filter → score → referral match → record in Pipeline → post to Slack.
- **Run B, reply check:** read your thread replies → act → answer in the thread (as the bot, so you're notified).
- **Pipeline vs Tracker:**
  - The **Tracker** is your clean record of applications. Only jobs you replied `applied` to go there.
  - The **Pipeline** is the agent's memory of every job it has shown you, including ones you skipped or haven't
    decided on. It's how the agent avoids showing you the same job twice, knows which Slack thread belongs to which
    job, keeps the job post text in case the link dies before you apply, and times referral follow-ups.
    You never need to open it.
- **CV tailoring** only edits a copy in `Tailored CVs/`. Your master CV is never touched.

## 6. Scheduling
Two jobs run on a schedule:

| Job | Default | What it does |
|---|---|---|
| **Run A**, daily scan | every day at **08:00** (`schedule.daily_scan`) | finds new jobs and posts them to Slack |
| **Run B**, reply check | **every hour, 09:00–21:00** (`schedule.reply_check_every_hours`, `schedule.reply_check_window`) | acts on your Slack replies; exits right away when there's nothing new |

Choose where they run:

| | Cloud routines (recommended) | Local scheduled tasks |
|---|---|---|
| Computer | can be **off / closed** | must be on with the Claude app open (missed runs fire when it reopens) |
| Fastest reply check | **every 1 hour (minimum)** | every 30 min or less |
| Secrets | stored in a cloud environment (§6.1) | read from your Mac (`job-hunt.local.yaml`, `~/.config/job-hunt/`) |
| LinkedIn | may occasionally block cloud servers | works from your home network |

### 6.1 Cloud: create an environment with your two variables
Cloud runs can't see files on your computer, so the two values your Mac keeps locally go into a cloud
**environment** instead. Do this once (menu names can shift slightly as the product changes):
1. Open <https://claude.ai/code>.
2. Open the **environment selector** (next to the repository picker) → **Add environment**. If you already have
   environments, create a new one just for this, so its variables stay separate.
3. **Name:** `job-hunt`.
4. **Network access:** the default "trusted" list doesn't include LinkedIn or Slack webhooks. Choose **Custom** and
   allow `www.linkedin.com`, `linkedin.com` and `hooks.slack.com`, or choose **Full**.
5. **Environment variables** (one per line, `.env` format):
   ```
   JOB_HUNT_CONFIG_DOC_ID=<your config doc ID>
   SLACK_WEBHOOK_URL=<your bot webhook URL>
   ```
   Paste the webhook into this field yourself. Don't send it in a chat.
6. **Save.**
7. Make sure the Google Drive, Google Docs, Google Sheets and Slack connectors are connected at
   <https://claude.ai/customize/connectors>. Cloud routines use your claude.ai connectors.

### 6.2 Cloud: create the routines
In Claude Code, run `/schedule` and ask:
> Create two routines on my copy of this repo in the `job-hunt` environment, model Sonnet:
> "Run A from CLAUDE.md" daily at <your scan time>, and "Run B from CLAUDE.md" every hour from 09:00 to 21:00 (my time).

Claude converts your local times to UTC (routines use UTC cron). Check the first runs at <https://claude.ai/code/routines>.
If Run A keeps finding nothing, LinkedIn is probably blocking the cloud: move Run A to a local task and keep Run B
in the cloud.

### 6.3 Local scheduled tasks
Ask Claude Code: *"Create local scheduled tasks for Run A and Run B using my schedule."* They read
`job-hunt.local.yaml` and `~/.config/job-hunt/slack_webhook` directly.

Change times any time in the config doc's `schedule` section, then ask Claude to update the schedules.

### 6.4 Cost
Runs count against your Claude plan's usage (or your API bill). Idle reply checks are small: they read the recent
channel messages and the config doc, then stop. Runs that act on a reply (CV tailoring, application kit) cost more, so
CLAUDE.md's "Token budget" keeps them lean. Running the routines on Sonnet instead of a larger model also reduces cost.

Rough estimates with the defaults (daily scan, hourly reply check 09:00–21:00, a couple of replies a day), on Sonnet.
Anthropic doesn't publish the exact plan limits, so treat these as ballpark figures and check your real numbers at
<https://claude.ai/settings/usage> after a few days:

Percentages are the share of that plan's limit the automation uses. The rest stays free for your own Claude use.

| Plan | Weekly limit used, per day | **Weekly limit used, whole week** | Whole week, busy (many `apply`, CV tailoring) | 5-hour limit used, any 5-hour window |
|---|---|---|---|---|
| Pro | ~1.5–3.5% | **~10–25%** | ~25–40% | ~5–15% |
| Max 5x | ~0.3–0.7% | **~2–5%** | ~5–8% | ~1–3% |
| Max 20x | ~0.1–0.2% | **~0.5–1.5%** | ~1.5–2% | ~0.3–0.8% |
| API billing | ≈ $1.50–2.80 | **≈ $10–20** | ≈ $20–30 | (≈ $45–85 a month) |

Roughly two thirds of the usage is the hourly Slack reply checks. Each check starts a fresh cloud session that loads
the instructions and tools before reading anything, even when there's nothing new. The daily scan is the rest.

Where the usage goes:

| Run | ≈ API cost per run |
|---|---|
| Idle reply check (no new replies) | $0.05–0.10 |
| Reply check that sends a kit (no tailoring) | $0.20–0.40 |
| CV tailoring | +$0.20–0.40 per job |
| Daily scan | $0.40–0.90 |

To use less: check replies less often (every 2 h halves the idle cost; `schedule.reply_check_every_hours: 2`), shorten
the window, or scan weekly (raise `search.daily_cap`, since it counts per scan). On **Pro**, a lighter schedule leaves
more room for your own Claude use. Idle checks are the part that grows with the schedule:

| Reply checks | Per day | Idle cost per month |
|---|---|---|
| Hourly, 09–21 (default) | 13 | ~$27 |
| Every 2 h, 09–21 | 7 | ~$15 |
| Hourly, 09–18 | 10 | ~$21 |
| Twice a day | 2 | ~$4 |

## 7. Troubleshooting
| Problem | Fix |
|---|---|
| No Slack notifications | Messages must come from **Job Hunt Bot**, not your account. Check the webhook (§3.5) and channel notifications |
| `No Slack webhook configured` | Save the URL (§3.5 step 4), or set `SLACK_WEBHOOK_URL` in cloud runs |
| Cloud scan finds nothing | LinkedIn sometimes blocks cloud servers, or the environment's network access doesn't allow `linkedin.com` (§6.1). Move Run A to a local task |
| Cloud run can't post to Slack | Allow `hooks.slack.com` in the environment's network access and check `SLACK_WEBHOOK_URL` (§6.1) |
| Sheet write rejected | A value isn't in your dropdown. Make `tracker.dropdowns` match the sheet exactly |
| Config error | The config doc must be valid YAML. Check the indentation and quote values containing `:` or `#` |
| The paste-the-URL command did nothing | It has to run in a real terminal app, not inside a chat |

## 8. Privacy
- Personal data stays in your Drive. The repo has only generic instructions and examples.
- `job-hunt.local.yaml` (your config doc ID) is git-ignored. The webhook lives in `~/.config/job-hunt/` or a cloud
  secret.
- Forking? Run `git status` before committing, and never add `job-hunt.local.yaml`.

## 9. Disclaimer and license
- **LinkedIn:** the scan reads LinkedIn's public job pages (the logged-out "guest" pages), a few dozen requests a
  day. It never logs in, sends messages or applies. Automated access to LinkedIn may still go against
  [LinkedIn's User Agreement](https://www.linkedin.com/legal/user-agreement), and LinkedIn can block it or change
  those pages at any time, which would stop the scan without warning. Use it at your own risk and keep the volume low.
- **Not affiliated** with LinkedIn, Slack, Google or Anthropic.
- **Check what it writes.** Job scores, CV edits and message drafts are AI-generated. Read them before you send or
  submit anything; you are responsible for what goes out under your name.
- **License:** [MIT](LICENSE).

## Repo layout
```
CLAUDE.md                     agent instructions: Run 0 setup, Run A scan, Run B replies, tailoring, referrals
scripts/slack_post.sh         posts as the Slack bot (top-level or in a thread)
examples/                     config, template and pipeline-sheet examples
job-hunt.local.example.yaml   copy to job-hunt.local.yaml (git-ignored) with your config doc ID
LICENSE                       MIT
```
