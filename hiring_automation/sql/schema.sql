-- ==============================================================================
-- DevSynt Hiring Automation System - Supabase / PostgreSQL Schema
-- Author: DevSynt AI Internship Evaluation Project
-- Description: Complete schema for candidate intake, AI scoring, and routing workflows.
-- ==============================================================================

-- Enable UUID extension if not enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Drop existing table and functions if recreating
-- DROP TABLE IF EXISTS candidates CASCADE;

-- 1. Create candidates main table
CREATE TABLE IF NOT EXISTS candidates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    phone TEXT,
    source TEXT NOT NULL CHECK (source IN ('email', 'form')),
    role_applied TEXT NOT NULL,
    resume_text TEXT NOT NULL,
    resume_url TEXT,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ats_score NUMERIC CHECK (ats_score >= 0 AND ats_score <= 100),
    classification TEXT CHECK (classification IN ('Strong', 'Average', 'Weak')),
    status TEXT NOT NULL DEFAULT 'pending_review' CHECK (status IN ('pending_review', 'notified', 'manual_review', 'shortlisted', 'rejected')),
    manager_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Prevent exact duplicate submissions for the same candidate email & role
    CONSTRAINT unique_candidate_role UNIQUE (email, role_applied)
);

-- 2. Create performance & search indexes
CREATE INDEX IF NOT EXISTS idx_candidates_status ON candidates(status);
CREATE INDEX IF NOT EXISTS idx_candidates_classification ON candidates(classification);
CREATE INDEX IF NOT EXISTS idx_candidates_email ON candidates(email);
CREATE INDEX IF NOT EXISTS idx_candidates_applied_at ON candidates(applied_at DESC);
CREATE INDEX IF NOT EXISTS idx_candidates_routing_poll ON candidates(status, classification) 
    WHERE status = 'pending_review' AND classification IS NOT NULL;

-- 3. Create auto-update trigger for updated_at column
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_candidates_updated_at ON candidates;
CREATE TRIGGER set_candidates_updated_at
    BEFORE UPDATE ON candidates
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- 4. Create View for Hiring Analytics Dashboard
CREATE OR REPLACE VIEW candidate_pipeline_summary AS
SELECT 
    role_applied,
    COUNT(*) as total_applicants,
    COUNT(CASE WHEN classification = 'Strong' THEN 1 END) as strong_candidates,
    COUNT(CASE WHEN classification = 'Average' THEN 1 END) as average_candidates,
    COUNT(CASE WHEN classification = 'Weak' THEN 1 END) as weak_candidates,
    COUNT(CASE WHEN status = 'shortlisted' THEN 1 END) as shortlisted_count,
    COUNT(CASE WHEN status = 'manual_review' THEN 1 END) as manual_review_count,
    COUNT(CASE WHEN status = 'rejected' THEN 1 END) as rejected_count,
    ROUND(AVG(ats_score), 2) as average_ats_score
FROM candidates
GROUP BY role_applied;

-- 5. Comments on table and columns for Supabase REST API & documentation
COMMENT ON TABLE candidates IS 'DevSynt Candidate Intake and AI Screening Records';
COMMENT ON COLUMN candidates.source IS 'Channel application was received from: email or form';
COMMENT ON COLUMN candidates.ats_score IS 'AI-generated candidate ATS score between 0 and 100';
COMMENT ON COLUMN candidates.classification IS 'Candidate classification: Strong (75-100), Average (50-74), Weak (<50)';
COMMENT ON COLUMN candidates.status IS 'Pipeline status: pending_review, notified, manual_review, shortlisted, rejected';

-- ==============================================================================
-- Sample Verification Query
-- SELECT * FROM candidates WHERE status = 'pending_review' AND classification IS NOT NULL;
-- ==============================================================================
