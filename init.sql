-- Enums
DO $$ BEGIN 
  CREATE TYPE job_source AS ENUM (
    'LINKEDIN', 'NAUKRI', 'WELLFOUND'
  ); EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN 
  CREATE TYPE job_recommendation AS ENUM ('APPLY', 'REVIEW', 'SKIP'); EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Table
CREATE TABLE IF NOT EXISTS jobs (
  id BIGSERIAL PRIMARY KEY,
  job_id TEXT UNIQUE NOT NULL,
  title TEXT NOT NULL,
  url TEXT NOT NULL,
  description TEXT,
  company_name TEXT,
  location TEXT,
  score NUMERIC,
  score_reason TEXT,
  source job_source NOT NULL,
  recommendation job_recommendation DEFAULT 'REVIEW',
  posted_at DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  modified_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Auto-update modified_at on row UPDATE
CREATE OR REPLACE FUNCTION set_modified_at () RETURNS TRIGGER AS $$ BEGIN 
  NEW.modified_at = NOW(); RETURN NEW;
END; $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_jobs_modified_at ON jobs;

CREATE TRIGGER trg_jobs_modified_at BEFORE
UPDATE ON jobs FOR EACH ROW
EXECUTE FUNCTION set_modified_at ();