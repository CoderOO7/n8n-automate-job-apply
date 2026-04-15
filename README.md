# LinkedIn Job Automation — n8n Workflow

An autonomous AI agent that runs every weekday morning, scrapes LinkedIn for fresh job postings, scores them against your profile, and delivers matched jobs with ready-to-send cold emails directly to your Google Sheet and inbox.
<img width="1763" height="476" alt="image" src="https://github.com/user-attachments/assets/0fbdbbf8-e8d6-46c3-b14b-624a887d7729" />

## 🎯 Features

- **Automated Scheduling**: Runs automatically at 9 AM and 5 PM on weekdays
- **AI-Powered Profile Analysis**: Parses your LinkedIn profile and CV to extract:
  - Primary and secondary job roles
  - Core technical skills
  - Experience level (Junior, Mid-level, Senior)
  - Expected salary range
  - Preferred locations
- **Smart Job Scraping**: Uses Apify to scrape LinkedIn jobs based on your profile
- **Intelligent Scoring**: AI-powered job matching (1-10 scale) based on relevance to your profile
- **Deduplication**: Tracks already-processed jobs to avoid duplicates
- **Cold Email Generation**: Automatically creates professional cold emails for each matched job
- **Google Sheets Integration**: Saves all matched jobs with reasons and cold emails
- **Daily Email Digest**: Sends you an HTML email summary with all matched jobs and pre-written emails


## 🛠️ Prerequisites

Before importing the workflow, set up the following accounts and credentials:

| Service | Purpose | Free? |
|---|---|---|
| [Jina AI](https://jina.ai) | Read your LinkedIn + CV URL | ✅ Yes |
| [Google Gemini](https://aistudio.google.com) | AI profile analysis + job scoring | ✅ Yes |
| [Apify](https://apify.com) | Scrape LinkedIn job listings | ✅ $5 free credit |
| Google Sheets | Job tracker + dedup store | ✅ Yes |
| Gmail | Daily summary email | ✅ Yes |


## 🚀 Setup Instructions

### Step 1 — Import the workflow
- Open n8n → click **+** → **Import from file**
- Select the `linkedIn_Job_Automation.json` file
- The workflow will appear on your canvas


### Step 2 — Configure your details

Open the **⚙️ Configuration** node and fill in your details:

| Field | Description | Example |
|---|---|---|
| `candidateName` | Your full name | `Shubham Yadav` |
| `candidateEmail` | Your email address | `mailme@gmail.com` |
| `candidateMobile` | Your phone number | `+91-9999999999` |
| `linkedinUrl` | Your public LinkedIn profile URL | `https://linkedin.com/in/yourprofile` |
| `cvUrl` | Public URL to your CV/resume (markdown preferred, Google Doc, GitHub Gist, or portfolio) | `https://gist.github.com/...` |
| `targetLocation` | City you want to work in | `Bengaluru` |
| `remotePreference` | Work type preference | `hybrid` / `remote` / `onsite` |
| `minimumSalaryAnnual` | Minimum annual salary | `2500000` |
| `maxJobsToProcess` | Max jobs to score per run | `5` |

> ⚠️ Your `linkedinUrl` must be **publicly accessible**. Test by opening it in an incognito browser window without logging in.

> ⚠️ Your `cvUrl` must also be publicly accessible. If using Google Docs, set sharing to "Anyone with the link can view".


### Step 3 — Set up credentials

#### Jina AI
1. Go to [jina.ai](https://jina.ai) → sign up → copy your API key
2. In n8n: **Settings → Credentials → Add → Jina AI**
3. Paste your API key
4. Connect to the **📖 Jina: Read Profile Source** node

#### Google Gemini
1. Go to [aistudio.google.com](https://aistudio.google.com) → **Get API Key → Create API key**
2. In n8n: Select the Google chat model node for **🎯 Agent: Profile Generation**
3. Paste your API key
4. Recommended models:
   - Profile Generation: `gemini-2.5-pro`
   - Job Scoring: `gemini-2.5-flash`

#### Apify
1. Go to [apify.com](https://apify.com) → sign up → **Settings → API & Integrations → copy API token**
2. In n8n: Select **🔍 Apify: Scrape LinkedIn** node and set the Bearer Auth token to your Apify API token

#### Google Sheets
1. Select **Get Already Processed Jobs** node
2. Click authenticate and log in with your Google account
3. Allow permissions for creating, reading, and updating files

#### Gmail
- Uses the same Google OAuth2 credentials created above


### Step 4 — Set up Google Sheet

1. Create a new Google Sheet called `LinkedInJobTracker`
2. Add these column headers in **Row 1**:

```
URLS | Job Title | Company | Cold Email | Job Score | Job Match Reason | Date
```

3. Copy the sheet URL and update it in these nodes:
   - **Get Already Processed Jobs** — Document URL field
   - **Add Jobs To Sheet** — Document URL field


### Step 5 — Test the workflow

Before activating, run it manually:

1. Click **Execute Workflow** on the canvas
2. Watch each node execute step by step
3. Check that:
   - Jina reads your profile successfully
   - Profile Generation returns valid search queries
   - Apify returns job listings
   - Job Scoring assigns scores
   - Matched jobs appear in your Google Sheet

> 💡 **Tip:** Use the **pin icon (📌)** on successfully completed nodes to avoid re-running them during testing. This saves API credits — especially on Jina and Gemini.



### Step 6 — Activate

Once testing passes, click the **Publish** toggle at the top right of the canvas. The workflow will now run automatically every weekday at **9:00 AM** and evening at **5:00 PM** without any manual action.


## 📊 How It Works

### Workflow Flow

```
Schedule Trigger (9 AM & 5 PM on weekdays)
    ↓
Configuration (Set candidate details)
    ↓
Build Profile Sources (Extract URLs)
    ↓
Jina API (Read LinkedIn & CV)
    ↓
AI Agent - Profile Analysis (Extract skills, roles, preferences)
    ↓
Generate Search Queries (Create 3 targeted job title queries)
    ↓
Apify (Scrape LinkedIn jobs)
    ↓
Check Duplicates (Skip already-processed jobs)
    ↓
Loop Over Jobs (Process each new job)
    ↓
AI Agent - Job Scoring (Score job relevance 1-10)
    ↓
Filter High Scores (Keep jobs with score ≥ 6)
    ↓
Generate Cold Emails (Create personalized email templates)
    ↓
Save to Google Sheets (Track all applications)
    ↓
Send Daily Email (Email digest with opportunities)
```

### Key Nodes Explained

**🎯 Agent: Profile Generation**
- Uses Google Gemini to analyze your LinkedIn profile and CV
- Extracts primary roles, secondary roles, core skills, seniority level
- Generates 3 targeted job search queries
- Returns a structured profile for matching

**🔍 Apify: Scrape LinkedIn**
- Scrapes LinkedIn job search results
- Uses your generated search queries
- Filters by location, experience level, and publication date
- Returns matching job listings

**🎯 Agent: Job Scoring**
- Compares each job description against your profile
- Scores relevancy from 1-10
- Considers job title fit, required skills, seniority level, salary range
- Only jobs with score ≥ 6 proceed to application

**Build Cold Email**
- Generates a professional cold email template
- Personalized with candidate name, job title, and company
- Ready to copy-paste and send directly


## 📈 Customization

### Change Job Scoring Threshold
1. Go to **📦 Filtered: Job Applications** node
2. Change the `rightValue` in the filter from `6` to your preferred minimum score

### Modify Email Template
1. Go to **🧾 Build Email Summary** node
2. Edit the HTML template in the code node

### Change Schedule
1. Go to **Schedule Trigger** node
2. Modify the cron expressions:
   - `0 9 * * 1-5` = 9 AM on weekdays
   - `0 17 * * 1-5` = 5 PM on weekdays

### Add More Profile Sources
1. Go to **⚙️ Configuration** node
2. Add more URLs (portfolio, GitHub profile, etc.)
3. They'll be automatically processed by the Jina reader

## ⚠️ Important Notes

- **API Costs**: Monitor your usage and set appropriate limits. Free tiers are available, but switching to paid plans (Apify, Google Gemini, Jina) will incur charges
- **LinkedIn Terms of Service**: Respect LinkedIn's ToS—this workflow is for personal automation only
- **Rate Limiting**: Free-tier APIs may impose rate limits. If you encounter throttling, add a **Wait** node between loops to introduce delays
- **Privacy**: Keep your credentials and personal information secure
- **Email Frequency**: Emails are sent daily. Adjust the schedule if needed

## 📝 License

This workflow is provided as-is for personal use. Modify and customize as needed for your needs.

## 🤝 Support

For issues or questions:
1. Review the n8n documentation
2. Check API provider documentation (Google, Apify, Jina)
3. Review the workflow execution logs for specific error messages
