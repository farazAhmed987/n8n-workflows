# DevSynt Hiring Automation System with n8n

Production-grade candidate intake, AI-based resume screening, database storage, and candidate routing pipeline built for **DevSynt Practical Evaluation Project**.

---

## 🌟 Architecture Overview

The system consists of **two connected n8n workflows** running on a local n8n instance backed by a **Supabase (PostgreSQL)** database and **OpenAI (GPT-4o-mini)** for automated ATS candidate evaluation.

```
                      ┌────────────────────────────────┐
                      │    Candidate Applications      │
                      └───────────────┬────────────────┘
                                      │
              ┌───────────────────────┴───────────────────────┐
              │                                               │
    [Source A: IMAP Email]                         [Source B: Google Form]
   (careers@devsynt.com)                          (Google Form / Webhook)
              │                                               │
              └───────────────────────┬───────────────────────┘
                                      ▼
                      ┌────────────────────────────────┐
                      │  Workflow 1: Intake & Screen   │
                      │ 1. Clean & Normalize Payload   │
                      │ 2. Deduplicate Check           │
                      │ 3. Store in Supabase           │
                      │ 4. Send Immediate Ack Email    │
                      │ 5. AI CV Review & ATS Score    │
                      │ 6. Update ATS Score in DB      │
                      └───────────────┬────────────────┘
                                      │
                                      ▼
                      ┌────────────────────────────────┐
                      │    Supabase Candidates DB      │
                      │  `status = 'pending_review'`   │
                      └───────────────┬────────────────┘
                                      │
                                      ▼ (Cron Poll / 15 Mins)
                      ┌────────────────────────────────┐
                      │   Workflow 2: Review & Route   │
                      │ 1. Fetch Scored Candidates     │
                      │ 2. Switch Branch Logic         │
                      └───────┬───────┬───────┬────────┘
                              │       │       │
             ┌────────────────┘       │       └────────────────┐
             ▼                        ▼                        ▼
     [Strong: 75-100]          [Average: 50-74]            [Weak: <50]
- HTML Shortlist Email    - Alert Hiring Manager      - Courteous Rejection
- Status: `shortlisted`   - Status: `manual_review`   - Status: `rejected`
```

---

## 🚀 Environment Setup

### 1. Prerequisites
- **Node.js**: v20+ or v24+ (`node -v`)
- **Python**: 3.10+ (`python --version`)
- **Supabase Account**: PostgreSQL Database URI & REST API Keys
- **OpenAI API Key**: Required for ATS Scoring

### 2. Local Node & n8n Project Setup
In the `hiring_automation` directory:

```bash
# 1. Install dependencies (n8n & dotenv)
npm install

# 2. Activate Python Virtual Environment
# Windows:
.\venv\Scripts\activate
# Linux/macOS:
source venv/bin/activate
```

### 3. Environment Configuration
Copy the template environment file:

```bash
cp .env.example .env
```

Configure your credentials inside `.env`:
- `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`
- `OPENAI_API_KEY`
- `IMAP_USER` and `IMAP_PASSWORD` (for intake email)
- `SMTP_USER` and `SMTP_PASSWORD` (for outbound notifications)

---

## 🗄️ Database Schema Setup (Supabase)

Run the included [`sql/schema.sql`](file:///d:/n8n/hiring_automation/sql/schema.sql) in your **Supabase Query Editor**.

### Table Schema: `candidates`
| Column | Type | Notes |
| :--- | :--- | :--- |
| `id` | `UUID` | Primary Key (auto-generated) |
| `name` | `TEXT` | Candidate full name |
| `email` | `TEXT` | Candidate email address |
| `phone` | `TEXT` | Optional phone number |
| `source` | `TEXT` | Channel: `'email'` or `'form'` |
| `role_applied` | `TEXT` | Target position |
| `resume_text` | `TEXT` | Full resume content or parsed text |
| `applied_at` | `TIMESTAMPTZ` | Submission timestamp |
| `ats_score` | `NUMERIC` | AI ATS Score (0–100) |
| `classification` | `TEXT` | `'Strong'`, `'Average'`, `'Weak'` |
| `status` | `TEXT` | Pipeline state: `'pending_review'`, `'shortlisted'`, `'manual_review'`, `'rejected'` |
| `manager_notes` | `TEXT` | AI evaluation breakdown & hiring manager notes |

---

## 📥 Importing Workflows into n8n

1. **Start n8n**:
   ```bash
   npm start
   ```
2. Open your browser at **`http://localhost:5678`**.
3. Create your initial owner credentials if running for the first time.
4. Click **Workflows ➔ Import from File**:
   - Import **`workflows/workflow_1_intake_and_screening.json`**
   - Import **`workflows/workflow_2_review_and_routing.json`**
5. Configure your Credentials in n8n UI:
   - **Supabase API**: URL & Service Role Key
   - **OpenAI API**: API Key
   - **SMTP / IMAP**: Host, Port, Email & App Passwords

---

## 🎯 Scoring Bands & Routing Rules

| ATS Score Band | Classification | Automated Pipeline Action | Final Database Status |
| :--- | :--- | :--- | :--- |
| **75 – 100** | **Strong** | Send HTML Shortlist / Interview Confirmation Email | `shortlisted` |
| **50 – 74** | **Average** | Flag candidate & alert Hiring Manager for manual review | `manual_review` |
| **Below 50** | **Weak** | Send polite, professional HTML rejection email | `rejected` |

---

## 🧪 Testing & Verification

Run the Python test script inside the virtual environment:

```bash
# Validate data normalization and sample datasets
python scripts/test_intake.py

# Send test payloads to local n8n Webhook
python scripts/test_intake.py --post
```

---

## 🛡️ Production Best Practices & Error Handling

1. **Idempotency & Duplicate Prevention**:
   - PostgreSQL unique constraint `(email, role_applied)` prevents double submission errors.
   - Database queries check existing entries prior to inserting.
2. **Status Locks**:
   - Workflow 2 updates status atomically after every action step (`shortlisted`, `manual_review`, `rejected`) so no candidate receives duplicate emails.
3. **Structured AI Fallbacks**:
   - If AI response parsing fails, the system defaults to an `Average` status (Score: 60) and flags the record for manual hiring manager review.
4. **Data Isolation**:
   - Virtual environment (`venv`) keeps Python dependencies isolated.
   - `.env` keeps all secrets out of source control.
