-- =====================================================================
-- NSFDC Schemes Database
-- Generated from user-supplied scheme JSON (compiled 2026-09-07).
-- No values invented, removed, or modified — only restructured/normalized.
-- Re-verify against nsfdc.nic.in / socialjustice.gov.in before production use,
-- per the confidence/action_needed fields preserved below.
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 0. Metadata about this data pull (one row, global to the whole dataset)
-- ---------------------------------------------------------------------
CREATE TABLE data_meta (
    id              SERIAL PRIMARY KEY,
    compiled        DATE NOT NULL,
    note            TEXT NOT NULL,
    schema_version  INTEGER NOT NULL
);

INSERT INTO data_meta (compiled, note, schema_version) VALUES (
    '2026-09-07',
    'Pulled from nsfdc.nic.in-adjacent official/government sources via web search, not a live API (none exists). Confidence varies per scheme — see ''confidence'' field on each. Re-verify against nsfdc.nic.in / socialjustice.gov.in before treating any of this as production-accurate; this is seed data for your matching engine''s v1, not a guarantee of current rates.',
    1
);

-- ---------------------------------------------------------------------
-- 1. Core schemes table
-- ---------------------------------------------------------------------
CREATE TABLE schemes (
    code                                    TEXT PRIMARY KEY,
    name                                    TEXT NOT NULL,
    corporation                             TEXT,
    scheme_category                         TEXT,   -- e.g. "Education", "Micro-enterprise / small business"
    confidence                              TEXT,
    source_url                              TEXT,
    as_of                                   TEXT,   -- free-text vintage marker, e.g. "~2012"
    max_project_cost                        NUMERIC(14,2),
    max_loan_amount                         NUMERIC(14,2),
    max_unit_cost                           NUMERIC(14,2),
    loan_pct_of_project                     NUMERIC(5,2),
    tenure_months                           INTEGER,
    moratorium_months                       INTEGER,
    repayment_schedule                      TEXT,
    eligibility_max_annual_family_income    NUMERIC(14,2),
    eligibility_gender                      TEXT,
    eligibility_notes                       TEXT,
    notes                                   TEXT,   -- general/free-form notes (e.g. VETLS)
    action_needed                           TEXT    -- outstanding verification tasks
);

-- ---------------------------------------------------------------------
-- 2. Scheme-level interest rates (nsfdc_to_sca / sca_to_beneficiary / male / female)
-- ---------------------------------------------------------------------
CREATE TABLE scheme_interest_rates (
    id           SERIAL PRIMARY KEY,
    scheme_code  TEXT NOT NULL REFERENCES schemes(code) ON DELETE CASCADE,
    rate_type    TEXT NOT NULL,   -- 'nsfdc_to_sca' | 'sca_to_beneficiary' | 'male' | 'female'
    rate_value   NUMERIC(6,3) NOT NULL,
    unit         TEXT DEFAULT '% per annum'
);

-- ---------------------------------------------------------------------
-- 3. Eligibility categories (array in source, e.g. ["SC"])
-- ---------------------------------------------------------------------
CREATE TABLE scheme_eligibility_categories (
    id           SERIAL PRIMARY KEY,
    scheme_code  TEXT NOT NULL REFERENCES schemes(code) ON DELETE CASCADE,
    category     TEXT NOT NULL
);

-- ---------------------------------------------------------------------
-- 4. Eligible entity types (Individual, Registered Societies, etc.)
-- ---------------------------------------------------------------------
CREATE TABLE scheme_entity_types (
    id           SERIAL PRIMARY KEY,
    scheme_code  TEXT NOT NULL REFERENCES schemes(code) ON DELETE CASCADE,
    entity_type  TEXT NOT NULL
);

-- ---------------------------------------------------------------------
-- 5. Sample eligible activities (business types)
-- ---------------------------------------------------------------------
CREATE TABLE scheme_eligible_activities (
    id           SERIAL PRIMARY KEY,
    scheme_code  TEXT NOT NULL REFERENCES schemes(code) ON DELETE CASCADE,
    activity     TEXT NOT NULL
);

-- ---------------------------------------------------------------------
-- 6. Documents required
-- ---------------------------------------------------------------------
CREATE TABLE scheme_documents_required (
    id           SERIAL PRIMARY KEY,
    scheme_code  TEXT NOT NULL REFERENCES schemes(code) ON DELETE CASCADE,
    document     TEXT NOT NULL
);

-- ---------------------------------------------------------------------
-- 7. Variants (e.g. NSFDC-ELS "Study in India" vs "Study abroad")
-- ---------------------------------------------------------------------
CREATE TABLE scheme_variants (
    variant_id                              SERIAL PRIMARY KEY,
    scheme_code                             TEXT NOT NULL REFERENCES schemes(code) ON DELETE CASCADE,
    label                                   TEXT NOT NULL,
    max_loan_amount                         NUMERIC(14,2),
    loan_pct_of_fee                         NUMERIC(5,2),
    note                                    TEXT,
    repayment_years_for_loans_up_to_10L     INTEGER
);

CREATE TABLE scheme_variant_interest_rates (
    id           SERIAL PRIMARY KEY,
    variant_id   INTEGER NOT NULL REFERENCES scheme_variants(variant_id) ON DELETE CASCADE,
    gender       TEXT NOT NULL,   -- 'male' | 'female'
    rate_value   NUMERIC(6,3) NOT NULL,
    unit         TEXT DEFAULT '% per annum'
);

-- ---------------------------------------------------------------------
-- 8. Conflicting-source records (e.g. NSFDC-TL has two disagreeing sources)
-- ---------------------------------------------------------------------
CREATE TABLE scheme_source_conflicts (
    conflict_id            SERIAL PRIMARY KEY,
    scheme_code            TEXT NOT NULL REFERENCES schemes(code) ON DELETE CASCADE,
    source_url             TEXT,
    as_of                  TEXT,
    max_unit_cost          NUMERIC(14,2),
    loan_pct_of_project    NUMERIC(5,2),
    interest_rate_text     TEXT   -- used when the source gives a free-text range instead of a tier table
);

CREATE TABLE scheme_source_conflict_tiers (
    tier_id                    SERIAL PRIMARY KEY,
    conflict_id                INTEGER NOT NULL REFERENCES scheme_source_conflicts(conflict_id) ON DELETE CASCADE,
    unit_cost_upto             NUMERIC(14,2) NOT NULL,
    sca_rate                   NUMERIC(6,3),
    beneficiary_rate_male      NUMERIC(6,3),
    beneficiary_rate_female    NUMERIC(6,3)
);

-- ---------------------------------------------------------------------
-- 9. Working defaults (used when a scheme has unresolved source conflicts)
-- ---------------------------------------------------------------------
CREATE TABLE scheme_working_default (
    scheme_code                             TEXT PRIMARY KEY REFERENCES schemes(code) ON DELETE CASCADE,
    max_loan_amount                         NUMERIC(14,2),
    loan_pct_of_project                     NUMERIC(5,2),
    tenure_months                           INTEGER,
    moratorium_months                       INTEGER,
    eligibility_max_annual_family_income    NUMERIC(14,2)
);

CREATE TABLE scheme_working_default_categories (
    id           SERIAL PRIMARY KEY,
    scheme_code  TEXT NOT NULL REFERENCES scheme_working_default(scheme_code) ON DELETE CASCADE,
    category     TEXT NOT NULL
);

-- =====================================================================
-- INDEXES
-- =====================================================================
CREATE INDEX idx_schemes_scheme_category         ON schemes(scheme_category);
CREATE INDEX idx_schemes_income_ceiling          ON schemes(eligibility_max_annual_family_income);
CREATE INDEX idx_schemes_max_loan_amount         ON schemes(max_loan_amount);
CREATE INDEX idx_schemes_gender                  ON schemes(eligibility_gender);

CREATE INDEX idx_elig_categories_scheme          ON scheme_eligibility_categories(scheme_code);
CREATE INDEX idx_elig_categories_category        ON scheme_eligibility_categories(category);

CREATE INDEX idx_entity_types_scheme             ON scheme_entity_types(scheme_code);
CREATE INDEX idx_entity_types_type               ON scheme_entity_types(entity_type);

CREATE INDEX idx_activities_scheme               ON scheme_eligible_activities(scheme_code);
CREATE INDEX idx_activities_activity             ON scheme_eligible_activities(activity);

CREATE INDEX idx_documents_scheme                ON scheme_documents_required(scheme_code);

CREATE INDEX idx_interest_rates_scheme           ON scheme_interest_rates(scheme_code);

CREATE INDEX idx_variants_scheme                 ON scheme_variants(scheme_code);
CREATE INDEX idx_variant_rates_variant           ON scheme_variant_interest_rates(variant_id);

CREATE INDEX idx_conflicts_scheme                ON scheme_source_conflicts(scheme_code);
CREATE INDEX idx_conflict_tiers_conflict         ON scheme_source_conflict_tiers(conflict_id);

CREATE INDEX idx_wd_categories_scheme            ON scheme_working_default_categories(scheme_code);

-- =====================================================================
-- DATA: NSFDC-MCF — Micro Credit Finance
-- =====================================================================
INSERT INTO schemes (
    code, name, corporation, scheme_category, confidence, source_url,
    max_project_cost, max_loan_amount, loan_pct_of_project,
    tenure_months, moratorium_months, repayment_schedule,
    eligibility_max_annual_family_income, eligibility_notes
) VALUES (
    'NSFDC-MCF', 'Micro Credit Finance', 'NSFDC', 'Micro-enterprise / small business',
    'high — actively maintained citizen-facing page', 'https://myscheme.gov.in/schemes/mcfnsfdc',
    140000, 125000, 90,
    36, 3, 'quarterly installments',
    300000,
    'For partnership firms/cooperative societies, every member must be SC and each member''s family income must be under the ceiling individually.'
);

INSERT INTO scheme_interest_rates (scheme_code, rate_type, rate_value, unit) VALUES
    ('NSFDC-MCF', 'nsfdc_to_sca', 2.5, '% per annum'),
    ('NSFDC-MCF', 'sca_to_beneficiary', 6.5, '% per annum');

INSERT INTO scheme_eligibility_categories (scheme_code, category) VALUES
    ('NSFDC-MCF', 'SC');

INSERT INTO scheme_entity_types (scheme_code, entity_type) VALUES
    ('NSFDC-MCF', 'Individual'),
    ('NSFDC-MCF', 'Registered Societies'),
    ('NSFDC-MCF', 'Joint Liability Groups');

INSERT INTO scheme_eligible_activities (scheme_code, activity) VALUES
    ('NSFDC-MCF', 'betel leaf shop'),
    ('NSFDC-MCF', 'bakery'),
    ('NSFDC-MCF', 'candle making'),
    ('NSFDC-MCF', 'cycle repair'),
    ('NSFDC-MCF', 'goat rearing'),
    ('NSFDC-MCF', 'beauty parlour'),
    ('NSFDC-MCF', 'vegetable vending'),
    ('NSFDC-MCF', 'incense stick making'),
    ('NSFDC-MCF', 'fish vending'),
    ('NSFDC-MCF', 'milch animal rearing'),
    ('NSFDC-MCF', 'papad manufacturing'),
    ('NSFDC-MCF', 'pickle manufacturing'),
    ('NSFDC-MCF', 'tea shop');

INSERT INTO scheme_documents_required (scheme_code, document) VALUES
    ('NSFDC-MCF', 'Passport-size photograph'),
    ('NSFDC-MCF', 'Aadhaar Card'),
    ('NSFDC-MCF', 'Income certificate'),
    ('NSFDC-MCF', 'Caste certificate'),
    ('NSFDC-MCF', 'Residence proof'),
    ('NSFDC-MCF', 'Bank passbook/details');

-- =====================================================================
-- DATA: NSFDC-ELS — Education Loan Scheme
-- =====================================================================
INSERT INTO schemes (
    code, name, corporation, scheme_category, confidence, source_url,
    eligibility_max_annual_family_income, eligibility_notes
) VALUES (
    'NSFDC-ELS', 'Education Loan Scheme', 'NSFDC', 'Education',
    'high — actively maintained citizen-facing page', 'https://www.myscheme.gov.in/schemes/els',
    300000,
    'Apply through State Channelizing Agencies (SCAs) or Channelizing Agencies (CAs).'
);

INSERT INTO scheme_eligibility_categories (scheme_code, category) VALUES
    ('NSFDC-ELS', 'SC');

INSERT INTO scheme_entity_types (scheme_code, entity_type) VALUES
    ('NSFDC-ELS', 'Individual'),
    ('NSFDC-ELS', 'Partnership Firm'),
    ('NSFDC-ELS', 'Co-operative Society');

INSERT INTO scheme_variants (scheme_code, label, max_loan_amount, loan_pct_of_fee, note, repayment_years_for_loans_up_to_10L) VALUES
    ('NSFDC-ELS', 'Study in India', 3000000, 90, 'Lower of ₹30L or 90% of course fee', 10),
    ('NSFDC-ELS', 'Study abroad',   4000000, 90, 'Lower of ₹40L or 90% of course fee', 12);

-- variant interest rates: pull variant_id via label lookup for clarity
INSERT INTO scheme_variant_interest_rates (variant_id, gender, rate_value, unit)
SELECT variant_id, 'male', 6.0, '% per annum' FROM scheme_variants WHERE scheme_code = 'NSFDC-ELS' AND label = 'Study in India';
INSERT INTO scheme_variant_interest_rates (variant_id, gender, rate_value, unit)
SELECT variant_id, 'female', 5.5, '% per annum' FROM scheme_variants WHERE scheme_code = 'NSFDC-ELS' AND label = 'Study in India';
INSERT INTO scheme_variant_interest_rates (variant_id, gender, rate_value, unit)
SELECT variant_id, 'male', 7.0, '% per annum' FROM scheme_variants WHERE scheme_code = 'NSFDC-ELS' AND label = 'Study abroad';
INSERT INTO scheme_variant_interest_rates (variant_id, gender, rate_value, unit)
SELECT variant_id, 'female', 6.5, '% per annum' FROM scheme_variants WHERE scheme_code = 'NSFDC-ELS' AND label = 'Study abroad';

-- =====================================================================
-- DATA: NSFDC-TL — Term Loan Scheme (LOW confidence, conflicting sources)
-- =====================================================================
INSERT INTO schemes (
    code, name, corporation, scheme_category, confidence, action_needed
) VALUES (
    'NSFDC-TL', 'Term Loan Scheme', 'NSFDC', 'Business / project finance',
    'LOW — conflicting figures across years, no current national (non-state-blended) page found',
    'DO NOT ship this scheme''s numbers to production matching without manually checking the current nsfdc.nic.in Term Loan page or calling NSFDC (011-22054392) to confirm which figure set is current. Use the 2021 circular as the working default since it''s the more recent, more detailed source, but mark it as unverified in the UI (e.g. a ''last verified: [date]'' badge) until confirmed.'
);

-- Conflict source 1: ~2012 Lok Sabha reply
INSERT INTO scheme_source_conflicts (scheme_code, source_url, as_of, max_unit_cost, interest_rate_text) VALUES
    ('NSFDC-TL', 'https://eparlib.nic.in/bitstream/123456789/622471/1/123531.pdf', '~2012 (Lok Sabha reply)', 3000000, '6-10% p.a. from beneficiaries');

-- Conflict source 2: 2021 circular (with tiered rates)
INSERT INTO scheme_source_conflicts (scheme_code, source_url, as_of, max_unit_cost, loan_pct_of_project) VALUES
    ('NSFDC-TL', 'https://socialjustice.gov.in/writereaddata/UploadFile/About_NSFDC_08_2021.pdf', '2021 circular', 5000000, 90);

INSERT INTO scheme_source_conflict_tiers (conflict_id, unit_cost_upto, sca_rate, beneficiary_rate_male, beneficiary_rate_female)
SELECT conflict_id, 500000, 3, 4, 3.5 FROM scheme_source_conflicts WHERE scheme_code = 'NSFDC-TL' AND as_of = '2021 circular';
INSERT INTO scheme_source_conflict_tiers (conflict_id, unit_cost_upto, sca_rate, beneficiary_rate_male, beneficiary_rate_female)
SELECT conflict_id, 1000000, 5, 5.5, 5 FROM scheme_source_conflicts WHERE scheme_code = 'NSFDC-TL' AND as_of = '2021 circular';
INSERT INTO scheme_source_conflict_tiers (conflict_id, unit_cost_upto, sca_rate, beneficiary_rate_male, beneficiary_rate_female)
SELECT conflict_id, 5000000, 6, 6, 6 FROM scheme_source_conflicts WHERE scheme_code = 'NSFDC-TL' AND as_of = '2021 circular';

INSERT INTO scheme_working_default (scheme_code, max_loan_amount, loan_pct_of_project, tenure_months, moratorium_months, eligibility_max_annual_family_income) VALUES
    ('NSFDC-TL', 5000000, 90, 84, 6, 300000);

INSERT INTO scheme_working_default_categories (scheme_code, category) VALUES
    ('NSFDC-TL', 'SC');

-- =====================================================================
-- DATA: NSFDC-MSY — Mahila Samriddhi Yojana (LOW confidence)
-- =====================================================================
INSERT INTO schemes (
    code, name, corporation, scheme_category, confidence, source_url, as_of,
    max_unit_cost, eligibility_gender, eligibility_notes, action_needed
) VALUES (
    'NSFDC-MSY', 'Mahila Samriddhi Yojana', 'NSFDC', 'Women micro-enterprise',
    'LOW — only found figures from a ~2012 parliamentary reply',
    'https://eparlib.nic.in/bitstream/123456789/622471/1/123531.pdf', '~2012',
    30000, 'Female', 'Exclusively for women beneficiaries.',
    'Re-verify unit cost ceiling — ₹30,000 looks dated for 2026; likely revised upward since. Check nsfdc.nic.in before use.'
);

INSERT INTO scheme_interest_rates (scheme_code, rate_type, rate_value, unit) VALUES
    ('NSFDC-MSY', 'nsfdc_to_sca', 1, '% per annum'),
    ('NSFDC-MSY', 'sca_to_beneficiary', 4, '% per annum');

INSERT INTO scheme_eligibility_categories (scheme_code, category) VALUES
    ('NSFDC-MSY', 'SC');

-- =====================================================================
-- DATA: NSFDC-VETLS — Vocational Education and Training Loan Scheme (LOW confidence)
-- =====================================================================
INSERT INTO schemes (
    code, name, corporation, scheme_category, confidence, source_url, notes, action_needed
) VALUES (
    'NSFDC-VETLS', 'Vocational Education and Training Loan Scheme', 'NSFDC', 'Skill development',
    'LOW — figures not independently found this pass, only scheme name confirmed to exist',
    'https://vikaspedia.in/social-welfare/scheduled-caste-welfare-1/national-institutes-for-sc-welfare',
    'NSFDC finances up to 100% of project cost for this scheme (the only scheme with 100% financing per the 2021 circular — every other scheme caps at 90%). Rate/ceiling details need direct lookup on nsfdc.nic.in.',
    'Fetch full details from nsfdc.nic.in before seeding real numbers.'
);

COMMIT;

-- =====================================================================
-- EXAMPLE MATCHING QUERIES
-- (Assumes a hypothetical `users` table with columns:
--  id, category TEXT, gender TEXT, state TEXT, annual_family_income NUMERIC,
--  business_type TEXT, requested_loan_amount NUMERIC)
--
-- NOTE: none of the source data is state-specific — these are national
-- schemes disbursed through State Channelizing Agencies (SCAs), so
-- `state` isn't a filter criterion here; it would only matter for
-- routing an approved application to the correct SCA. It's included
-- below only to show where it *would* plug in if you later add an
-- SCA-directory table.
-- =====================================================================

-- 1. Schemes a given SC applicant qualifies for on income + category alone
-- SELECT s.code, s.name, s.max_loan_amount, s.eligibility_max_annual_family_income
-- FROM schemes s
-- JOIN scheme_eligibility_categories c ON c.scheme_code = s.code
-- WHERE c.category = 'SC'
--   AND (s.eligibility_max_annual_family_income IS NULL
--        OR s.eligibility_max_annual_family_income >= :user_annual_family_income);

-- 2. Schemes matching a requested loan amount (within max_loan_amount, or variant ceiling)
-- SELECT s.code, s.name, s.max_loan_amount
-- FROM schemes s
-- WHERE s.max_loan_amount >= :requested_loan_amount
-- UNION
-- SELECT v.scheme_code, s.name, v.max_loan_amount
-- FROM scheme_variants v
-- JOIN schemes s ON s.code = v.scheme_code
-- WHERE v.max_loan_amount >= :requested_loan_amount;

-- 3. Women-only schemes (gender-restricted eligibility)
-- SELECT code, name, max_unit_cost
-- FROM schemes
-- WHERE eligibility_gender = 'Female';

-- 4. Schemes matching a specific business/activity type (e.g. "bakery")
-- SELECT s.code, s.name, a.activity
-- FROM schemes s
-- JOIN scheme_eligible_activities a ON a.scheme_code = s.code
-- WHERE a.activity ILIKE '%bakery%';

-- 5. Full eligibility + best applicable interest rate for a male SC applicant
--    requesting 100,000 with income 250,000, business = "tea shop"
-- SELECT s.code, s.name, s.max_loan_amount, ir.rate_type, ir.rate_value
-- FROM schemes s
-- JOIN scheme_eligibility_categories c ON c.scheme_code = s.code AND c.category = 'SC'
-- LEFT JOIN scheme_interest_rates ir ON ir.scheme_code = s.code
-- LEFT JOIN scheme_eligible_activities a ON a.scheme_code = s.code
-- WHERE (s.eligibility_max_annual_family_income IS NULL OR s.eligibility_max_annual_family_income >= 250000)
--   AND (s.eligibility_gender IS NULL OR s.eligibility_gender = 'Male')
--   AND s.max_loan_amount >= 100000
--   AND (a.activity IS NULL OR a.activity ILIKE '%tea shop%');

-- 6. Only "high confidence" schemes (excludes LOW-confidence / unverified entries)
-- SELECT code, name, confidence
-- FROM schemes
-- WHERE confidence ILIKE 'high%';

-- 7. Education loan variant matching (male, wants to study abroad, needs 3.5L)
-- SELECT v.label, v.max_loan_amount, vr.gender, vr.rate_value
-- FROM scheme_variants v
-- JOIN scheme_variant_interest_rates vr ON vr.variant_id = v.variant_id
-- WHERE v.scheme_code = 'NSFDC-ELS'
--   AND v.label = 'Study abroad'
--   AND vr.gender = 'male'
--   AND v.max_loan_amount >= 350000;

-- 8. Flag schemes that need manual re-verification before being shown to users
-- SELECT code, name, confidence, action_needed
-- FROM schemes
-- WHERE action_needed IS NOT NULL;
