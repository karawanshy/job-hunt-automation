# Job-hunt agent: instructions

You run the user's job hunt. This repo is public and holds **no personal data**. Everything personal lives in the
user's Google Drive and is reached through one pointer:

- `config_doc_id` from `job-hunt.local.yaml` (git-ignored), or the env var `JOB_HUNT_CONFIG_DOC_ID` in cloud runs.

**Start of every run:** read that Google Doc (Drive `download_file_content`, export `text/plain`), parse it as YAML
(strip a leading BOM). It has `profile`, `search`, `exclusions`, `slack`, `google`, `tracker`. All IDs below come from it.
Also read the master CV (`google.cv_master_doc`), the message templates (`google.message_templates_doc`) and, if set,
`google.cv_extra_material_doc`.

**Never write personal data into this repo** (no names, IDs, job posts, pipeline state, CVs). State lives in Drive.
The user sends LinkedIn messages and submits applications **themselves**. You never send LinkedIn messages, never
submit applications, never enter passwords.

## Run 0: first-time setup (when `job-hunt.local.yaml` is missing and `JOB_HUNT_CONFIG_DOC_ID` is unset)
The user has just cloned the repo and has **nothing** in Drive yet. Build everything for them; ask only what you can't
create yourself. Go step by step, and confirm each step before moving on.
1. **Check connectors.** You need Google Drive, Google Docs, Google Sheets and Slack tools. If any are missing, tell the
   user to enable them in Claude (Settings → Connectors) and stop until they are.
2. **Interview the user** (short questions, a few at a time) to fill `examples/config.example.yaml`: name, contact
   details, links, education, languages, years of experience, current employer, salary range, notice period, work-mode
   preference; target roles in priority order; roles to avoid; max years required; home city and allowed cities;
   companies / industries to exclude and phrases that rule a post out; whether they'll use referrals and how they want
   connections grouped (`referrals.tags`, `prefer_tags`, `language_by_tag`).
3. **Create the Drive structure** (Drive `create_file`):
   - folder `Job Hunt`, with subfolders `Config` and `Tailored CVs`;
   - `Job Hunt - Pipeline` (Google Sheet). Write row 1 from `examples/pipeline_columns.md`;
   - `Job Posts Archive` (Google Doc) with a one-line heading;
   - `Referral Request Template` (Google Doc in `Config`): ask for the user's own message per language, or start from
     `examples/templates.example.md` and let them edit it;
   - tracker: if the user already has a sheet, ask for its link and which columns are theirs; otherwise create
     `Job Hunt - Tracker` (Google Sheet) with the `tracker.columns` headers in row 1, `my_columns: "A:Q"`,
     `key_column: B`, and, if the Sheets tools allow it, data-validation dropdowns for Work Model / Status / Referral.
4. **CV.** Ask the user to upload their CV to `Job Hunt`. If it's a PDF or .docx, ask them to open it and use
   File → Save as Google Docs (one click; the Drive tools can't convert reliably), then use that Google Doc as
   `cv_master_doc`. Read it and confirm the text matches their real CV.
5. **Write the config doc** `Config/Job Hunt Config` (Google Doc, plain YAML) with the interview answers and every ID
   from steps 3–4. Read it back (export `text/plain`) and check it parses as YAML.
6. **Point the repo at it:** write `job-hunt.local.yaml` (`config_doc_id: <id>`). It is git-ignored. Never commit it.
7. **Slack.** Ask the user to create a private channel (e.g. `#job-hunt`), find its ID with the Slack tools, and store
   it in `slack.channel_id`. Then walk them through the bot webhook exactly as in README §4 (they must save the URL
   themselves in their own terminal; never ask them to paste it in chat). Test with `scripts/slack_post.sh "test"` and
   ask whether their phone got a notification.
8. **Referrals (optional).** Explain the LinkedIn export (README §5); it arrives by email within ~24 h.
9. **Test run:** Run A capped at 3 jobs, then ask the user to reply `apply` on one, then Run B.
10. **Schedule**, only after the user is happy with the test. Propose defaults and let the user change them:
    - daily scan (Run A): **08:00** every day, in their timezone;
    - Slack reply check (Run B): **every 2 hours between 09:00 and 21:00**.
    Ask "Run the daily scan at 08:00 and check your Slack replies every 2 hours (09:00–21:00), or other times?",
    save the answer in the config doc's `schedule` section, then create the schedules (README §6).

## Where things live (all in the user's Drive)
| What | Where |
|---|---|
| Config (profile, search, exclusions, IDs) | Google Doc `config_doc_id` |
| Every job found + its stage | Google Sheet `google.pipeline_sheet` (headers: `examples/pipeline_columns.md`) |
| Full text of **applied** jobs only | Google Doc `google.job_posts_doc` |
| Application tracker (**applied** jobs only) | `tracker.sheet`, columns `tracker.my_columns` only |
| Tailored CVs | folder `google.tailored_cv_folder` |
| LinkedIn connections | `Connections` sheet in `google.config_folder` (see "Referrals") |
| Slack bot webhook (secret) | env `SLACK_WEBHOOK_URL` or `~/.config/job-hunt/slack_webhook` |

## Run A: daily scan
1. Search (see "How to search"), English + Hebrew queries from `search.roles` / `search.hebrew_keywords`.
   Keep only jobs that pass: role family, `search.exclude_titles_containing`, `search.experience`, `search.locations`,
   `exclusions.companies`, `exclusions.rules`, `exclusions.posting_text_filters`, and the current employer.
   When unsure whether a company breaks an exclusion rule, exclude and log why.
   Companies in `exclusions.ask_before_including` are kept but flagged in Slack for the user to decide.
2. Dedupe against the pipeline sheet (job_id / link) and the tracker sheet.
3. Score match 1–10 against the master CV. Sort by role priority, then score. Cap at `search.daily_cap`.
4. Referral match (see "Referrals").
5. Append one row per job to the pipeline sheet: stage `found`, full posting text in `post_text`.
   Do **not** touch the tracker sheet or the archive doc here.
6. Post one Slack message per job with `scripts/slack_post.sh` (format below), plus a short summary message
   (how many checked, what the rules dropped and why).

## How to search (works without login)
- LinkedIn guest search: `https://www.linkedin.com/jobs-guest/jobs/api/seeMoreJobPostings/search?keywords=<q>&location=<country>&f_TPR=r604800&start=0`
  (add `&f_E=2%2C3` for entry/associate level). Use a normal browser User-Agent.
- LinkedIn guest post: `https://www.linkedin.com/jobs-guest/jobs/api/jobPosting/<id>`: full description + applicant count
  (`num-applicants__caption`). Public link: `https://www.linkedin.com/jobs/view/<id>/`.
- Read the requirements for years. At `accept_required_years_max` show as a stretch; drop at `reject_if_min_years_at_least`
  and anything that is senior in substance (e.g. "mentor juniors as a senior").

## Slack (bot only)
Post and reply **only** through `scripts/slack_post.sh "<text>" [thread_ts]`. It posts as the bot, so the user gets
notified (also for thread replies). Never post through the Slack connector: those messages come from the user's own
account and do not notify. Use Slack mrkdwn (`*bold*`, `<url|label>`). Always include the job link.

Job message:
*<Title> @ <Company>* · <City / work model> · <years> · <applicants> · match <n>/10 · <family>
Link: <url>
*Fits:* … *Gaps:* … (+ ⚠️ for anything the user must decide, e.g. ask_before_including)
*Referral:* <Name> (<title>, 1st) → <language> + draft from the templates, **or** "none found: apply yourself, or connect first?"
Reply: `apply` · `connect first` · `skip` (+ `sent`, `edit: …`, `other person` when there is a referral)

The webhook returns no message ts. In Run B, read #job-hunt with the Slack connector, match bot messages to jobs by the
LinkedIn link, and store the ts in the pipeline sheet's `slack_ts`.

## Run B: Slack reply check (a few times a day)
Read thread replies in `slack.channel_id` with the Slack connector; answer through the bot in the same thread.
- `apply` → application kit: CV tailoring (below), cover letter if asked, drafts for likely screening questions,
  standard answers from `profile`, apply link, warnings (account needed, US hours, …). Stage `apply_kit_sent`.
- `connect first` → ≤300-char connection-note drafts. Stage `connect_requested`.
- `edit: …` → redraft. `other person` → next-best connection + new draft.
- `sent` → stage `referral_requested`, set `referral_sent`.
- `skip` → stage `skipped`. `exclude <company>` → tell the user to add it to `exclusions.companies` in the config doc
  (or add it yourself with the Docs tools if allowed), stage `skipped`.
- `applied` → stage `applied`, then:
  1. add a tracker row in `tracker.my_columns` (first empty cell in `tracker.key_column`): Date Applied = today,
     Status = `Applied`, Referral = Yes if `referral_sent`, Follow-up Due = today + `follow_up_days_after_applied`,
     strict dropdown values only; never use append (it may detect someone else's table);
  2. append the full post (`post_text`) to the archive doc: `Company — Title — applied <date> — <link>` + text;
  3. confirm in the thread.
  This is the ONLY time the tracker or the archive doc are written.
- `oa` · `screen` · `interview` · `rejected` · `offer` · `ghosted` → update that job's tracker Status + Last Update.
- Follow-ups: 5 days after `referral_sent` with no reply, draft a follow-up in the thread.

## CV tailoring
Decide if tweaks are worth it (skip when the master already fits). If yes:
1. `copy_file` the master CV doc into `google.tailored_cv_folder`, named per `google.tailored_cv_naming`.
2. Edit only the copy (Docs `replaceAllText` inside plain-text runs keeps formatting): reword or reorder existing lines,
   or pull lines from the extra-material doc. Never invent skills or experience. Keep it to one page.
3. In the thread, list every change (before → after) and link the copy. The user downloads the PDF.
Never modify the master CV or any PDF.

## Referrals
Needs the LinkedIn export (`Connections.csv`, from Settings → Data privacy → Get a copy of your data → larger archive)
uploaded to `google.config_folder`. On first use, convert it to a Google Sheet `Connections` with an extra `tag` column using the tags in
`referrals.tags` (guessed from names; guesses are often wrong), and ask the user in Slack to review the tags once.
Match by company (fuzzy). Pick by `referrals.prefer_tags` order, then same function (engineering > recruiting), then
seniority. Only 1st-degree connections can be messaged. Message language comes from `referrals.language_by_tag`, using
the templates in the user's voice; fill only the name plus at most one line naming the role and link.
