-- ============================================================
-- SafeGuard — Database Schema (PostgreSQL)
-- Translated directly from the class diagram.
-- Run against the `safeguard` database.
-- ============================================================

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ------------------------------------------------------------
-- PARENT
-- ------------------------------------------------------------
CREATE TABLE parent (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name      VARCHAR(100)  NOT NULL,
    email          VARCHAR(150)  NOT NULL UNIQUE,
    password_hash  TEXT          NOT NULL,
    fcm_token      TEXT,                              -- for push notifications
    created_at     TIMESTAMP     NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------
-- CHILD  (belongs to one parent)
-- ------------------------------------------------------------
CREATE TABLE child (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_id      UUID          NOT NULL REFERENCES parent(id) ON DELETE CASCADE,
    name           VARCHAR(100)  NOT NULL,
    age            INT           CHECK (age >= 0 AND age <= 18),
    device_id      VARCHAR(200),                      -- the paired Android device
    pairing_code   VARCHAR(20),                       -- code the child enters to link
    linked_at      TIMESTAMP,
    created_at     TIMESTAMP     NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------
-- MONITORING SETTINGS  (one-to-one with child)
-- Parent controls these; they describe how THIS child is monitored.
-- ------------------------------------------------------------
CREATE TABLE monitoring_settings (
    id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    child_id               UUID NOT NULL UNIQUE REFERENCES child(id) ON DELETE CASCADE,

    language_enabled       BOOLEAN NOT NULL DEFAULT TRUE,
    language_sensitivity   VARCHAR(10) NOT NULL DEFAULT 'medium'
                             CHECK (language_sensitivity IN ('low','medium','high')),

    image_enabled          BOOLEAN NOT NULL DEFAULT TRUE,
    image_sensitivity      VARCHAR(10) NOT NULL DEFAULT 'medium'
                             CHECK (image_sensitivity IN ('low','medium','high')),

    website_enabled        BOOLEAN NOT NULL DEFAULT TRUE,

    duration_enabled       BOOLEAN NOT NULL DEFAULT TRUE,
    duration_threshold     INT NOT NULL DEFAULT 3600,   -- seconds (default 1h)

    stranger_enabled       BOOLEAN NOT NULL DEFAULT TRUE,
    bullying_enabled       BOOLEAN NOT NULL DEFAULT TRUE,
    mental_health_enabled  BOOLEAN NOT NULL DEFAULT TRUE,
    sos_enabled            BOOLEAN NOT NULL DEFAULT TRUE,

    updated_at             TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------
-- EVENT  (something detected on the child device)
-- ------------------------------------------------------------
CREATE TABLE event (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    child_id          UUID NOT NULL REFERENCES child(id) ON DELETE CASCADE,
    type              VARCHAR(30) NOT NULL
                        CHECK (type IN ('language','image','website','duration',
                                        'stranger','bullying','mental_health','sos')),
    content           TEXT,                       -- the flagged text / url / note
    detected_language VARCHAR(20),                -- 'derja','arabic','french','english'
    severity          VARCHAR(10) NOT NULL DEFAULT 'low'
                        CHECK (severity IN ('low','medium','high')),
    created_at        TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------
-- ALERT  (notification sent to a parent about an event)
-- Not every event becomes an alert -> event 1 : 0..1 alert
-- ------------------------------------------------------------
CREATE TABLE alert (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id    UUID NOT NULL UNIQUE REFERENCES event(id) ON DELETE CASCADE,
    parent_id   UUID NOT NULL REFERENCES parent(id) ON DELETE CASCADE,
    message     TEXT NOT NULL,
    is_read     BOOLEAN NOT NULL DEFAULT FALSE,
    sent_at     TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------
-- CONTACT  (for stranger detection)
-- ------------------------------------------------------------
CREATE TABLE contact (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    child_id       UUID NOT NULL REFERENCES child(id) ON DELETE CASCADE,
    contact_name   VARCHAR(150),
    contact_handle VARCHAR(200),                 -- phone / username / email
    is_approved    BOOLEAN NOT NULL DEFAULT FALSE,
    is_stranger    BOOLEAN NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------
-- USAGE RECORD  (screen-time / video duration tracking)
-- ------------------------------------------------------------
CREATE TABLE usage_record (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    child_id         UUID NOT NULL REFERENCES child(id) ON DELETE CASCADE,
    app_or_video     VARCHAR(200) NOT NULL,
    duration_seconds INT NOT NULL DEFAULT 0,
    recorded_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------
-- SUPPORT RESOURCE  (shown to child on distress detection)
-- ------------------------------------------------------------
CREATE TABLE support_resource (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title        VARCHAR(200) NOT NULL,
    description  TEXT,
    contact_info VARCHAR(200),
    language     VARCHAR(20) NOT NULL DEFAULT 'french'
);

-- ------------------------------------------------------------
-- Helpful indexes for common queries
-- ------------------------------------------------------------
CREATE INDEX idx_child_parent      ON child(parent_id);
CREATE INDEX idx_event_child       ON event(child_id);
CREATE INDEX idx_event_created     ON event(created_at);
CREATE INDEX idx_alert_parent      ON alert(parent_id);
CREATE INDEX idx_alert_isread      ON alert(is_read);
CREATE INDEX idx_contact_child     ON contact(child_id);
CREATE INDEX idx_usage_child       ON usage_record(child_id);

-- ============================================================
-- End of schema
-- ============================================================