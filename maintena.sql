-- ============================================================
-- RENTAL MAINTENANCE PLATFORM — FULL DATABASE SCHEMA
-- Multi-Tenant | White-Label | South Africa
-- ============================================================

-- ============================================================
-- EXTENSIONS
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- ENUMS
-- ============================================================

CREATE TYPE user_role AS ENUM (
  'super_admin',
  'manager',
  'maintenance_admin',
  'technician',
  'tenant',
  'staff'
);

CREATE TYPE user_status AS ENUM (
  'active',
  'inactive',
  'suspended',
  'pending'
);

CREATE TYPE ticket_status AS ENUM (
  'open',
  'assigned',
  'in_progress',
  'on_hold',
  'completed',
  'closed',
  'cancelled'
);

CREATE TYPE ticket_priority AS ENUM (
  'low',
  'medium',
  'high',
  'urgent'
);

CREATE TYPE ticket_source AS ENUM (
  'tenant',
  'staff',
  'technician',
  'manager',
  'system'
);

CREATE TYPE location_type AS ENUM (
  'unit',
  'facility',
  'outdoor',
  'infrastructure',
  'common_area'
);

CREATE TYPE unit_type AS ENUM (
  'apartment',
  'townhouse',
  'studio',
  'penthouse',
  'retail',
  'office',
  'storage'
);

CREATE TYPE frequency_type AS ENUM (
  'daily',
  'weekly',
  'fortnightly',
  'monthly',
  'quarterly',
  'biannual',
  'yearly',
  'custom'
);

CREATE TYPE company_status AS ENUM (
  'active',
  'inactive',
  'suspended',
  'trial'
);

CREATE TYPE notification_channel AS ENUM (
  'email',
  'sms',
  'in_app',
  'whatsapp'
);

CREATE TYPE attachment_type AS ENUM (
  'image',
  'document',
  'video'
);

-- ============================================================
-- 1. COMPANIES (White-Label Tenants)
-- ============================================================
CREATE TABLE companies (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name            VARCHAR(200) NOT NULL,
  slug            VARCHAR(100) UNIQUE NOT NULL,        -- subdomain: slug.system.com
  logo_url        TEXT,
  primary_color   VARCHAR(7)   DEFAULT '#1a1a2e',      -- hex color
  secondary_color VARCHAR(7)   DEFAULT '#16213e',
  domain          VARCHAR(200),                        -- custom domain if any
  status          company_status NOT NULL DEFAULT 'trial',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 2. COMPANY SETTINGS
-- ============================================================
CREATE TABLE company_settings (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id          UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  support_email       VARCHAR(200),
  notification_email  VARCHAR(200),
  timezone            VARCHAR(100) DEFAULT 'Africa/Johannesburg',
  currency            VARCHAR(10)  DEFAULT 'ZAR',
  sms_enabled         BOOLEAN DEFAULT FALSE,
  whatsapp_enabled    BOOLEAN DEFAULT FALSE,
  email_enabled       BOOLEAN DEFAULT TRUE,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(company_id)
);

-- ============================================================
-- 3. USERS (All roles in one table)
-- ============================================================
CREATE TABLE users (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id      UUID REFERENCES companies(id) ON DELETE CASCADE,   -- NULL for super_admin
  name            VARCHAR(200) NOT NULL,
  email           VARCHAR(200) NOT NULL,
  phone           VARCHAR(20),
  password_hash   TEXT NOT NULL,
  role            user_role NOT NULL,
  status          user_status NOT NULL DEFAULT 'pending',
  profile_photo   TEXT,
  last_login      TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(email)
);

-- ============================================================
-- 4. PROPERTIES
-- ============================================================
CREATE TABLE properties (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id      UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  name            VARCHAR(200) NOT NULL,
  address         TEXT NOT NULL,
  city            VARCHAR(100),
  province        VARCHAR(100),
  postal_code     VARCHAR(10),
  latitude        DECIMAL(10, 8),
  longitude       DECIMAL(11, 8),
  description     TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 5. UNITS (Individual rentable spaces)
-- ============================================================
CREATE TABLE units (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  property_id     UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  unit_number     VARCHAR(50) NOT NULL,
  floor           INTEGER,
  type            unit_type NOT NULL DEFAULT 'apartment',
  description     TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(property_id, unit_number)
);

-- ============================================================
-- 6. UNIT OCCUPANTS (Tenant history per unit)
-- ============================================================
CREATE TABLE unit_occupants (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  unit_id         UUID NOT NULL REFERENCES units(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  start_date      DATE NOT NULL,
  end_date        DATE,                                -- NULL means currently active
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 7. PROPERTY AREAS (Shared/common spaces)
-- ============================================================
CREATE TABLE property_areas (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  property_id     UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  name            VARCHAR(200) NOT NULL,
  type            location_type NOT NULL DEFAULT 'common_area',
  description     TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 8. CATEGORIES (Per company — customizable)
-- ============================================================
CREATE TABLE categories (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id      UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  name            VARCHAR(100) NOT NULL,
  description     TEXT,
  icon            VARCHAR(50),                         -- icon name for UI
  color           VARCHAR(7),                          -- optional category color
  is_active       BOOLEAN DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(company_id, name)
);

-- ============================================================
-- 9. TICKETS (Core of the system)
-- ============================================================
CREATE TABLE tickets (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  ticket_number   VARCHAR(20) UNIQUE NOT NULL,         -- human-readable: TKT-0001
  company_id      UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  property_id     UUID NOT NULL REFERENCES properties(id),
  unit_id         UUID REFERENCES units(id),           -- NULL if area ticket
  area_id         UUID REFERENCES property_areas(id),  -- NULL if unit ticket
  category_id     UUID REFERENCES categories(id),
  created_by      UUID NOT NULL REFERENCES users(id),  -- who submitted
  assigned_to     UUID REFERENCES users(id),           -- technician
  source          ticket_source NOT NULL DEFAULT 'tenant',
  title           VARCHAR(300) NOT NULL,
  description     TEXT,
  priority        ticket_priority NOT NULL DEFAULT 'medium',
  status          ticket_status NOT NULL DEFAULT 'open',
  -- Cost tracking (approved in planning)
  parts_cost      DECIMAL(10,2),
  labour_cost     DECIMAL(10,2),
  total_cost      DECIMAL(10,2) GENERATED ALWAYS AS (
                    COALESCE(parts_cost, 0) + COALESCE(labour_cost, 0)
                  ) STORED,
  due_date        DATE,
  completed_at    TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- Constraint: ticket must belong to either a unit OR an area
  CONSTRAINT ticket_location_check CHECK (
    (unit_id IS NOT NULL AND area_id IS NULL) OR
    (area_id IS NOT NULL AND unit_id IS NULL) OR
    (unit_id IS NULL AND area_id IS NULL)    -- staff/manager created without specific location
  )
);

-- Auto-generate ticket number
CREATE SEQUENCE ticket_seq START 1;

CREATE OR REPLACE FUNCTION generate_ticket_number()
RETURNS TRIGGER AS $$
BEGIN
  NEW.ticket_number := 'TKT-' || LPAD(nextval('ticket_seq')::TEXT, 6, '0');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_ticket_number
BEFORE INSERT ON tickets
FOR EACH ROW
WHEN (NEW.ticket_number IS NULL OR NEW.ticket_number = '')
EXECUTE FUNCTION generate_ticket_number();

-- ============================================================
-- 10. TICKET UPDATES (Activity feed / comments)
-- ============================================================
CREATE TABLE ticket_updates (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  ticket_id       UUID NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES users(id),
  message         TEXT,
  status_change   ticket_status,                       -- what status changed to (if any)
  is_internal     BOOLEAN DEFAULT FALSE,               -- internal note (not visible to tenant)
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 11. ATTACHMENTS (Photos and documents)
-- ============================================================
CREATE TABLE attachments (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  ticket_id       UUID NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
  uploaded_by     UUID NOT NULL REFERENCES users(id),
  file_url        TEXT NOT NULL,
  file_name       VARCHAR(300),
  file_size       INTEGER,                             -- bytes
  file_type       attachment_type NOT NULL DEFAULT 'image',
  mime_type       VARCHAR(100),
  storage_path    TEXT,                                -- e.g. company_5/tickets/221/leak.jpg
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 12. MAINTENANCE SCHEDULES (Preventative maintenance)
-- ============================================================
CREATE TABLE maintenance_schedules (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id      UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  property_id     UUID NOT NULL REFERENCES properties(id),
  unit_id         UUID REFERENCES units(id),           -- NULL if area task
  area_id         UUID REFERENCES property_areas(id),  -- NULL if unit task
  title           VARCHAR(300) NOT NULL,
  description     TEXT,
  category_id     UUID REFERENCES categories(id),
  assigned_to     UUID REFERENCES users(id),           -- default technician
  priority        ticket_priority NOT NULL DEFAULT 'medium',
  frequency_type  frequency_type NOT NULL,
  frequency_value INTEGER DEFAULT 1,                   -- e.g. every 2 weeks = value 2, type weekly
  next_due_date   DATE NOT NULL,
  last_run_date   DATE,
  is_active       BOOLEAN DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 13. SCHEDULED TICKET LOG (Tracks auto-generated tickets)
-- ============================================================
CREATE TABLE scheduled_ticket_log (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  schedule_id     UUID NOT NULL REFERENCES maintenance_schedules(id) ON DELETE CASCADE,
  ticket_id       UUID NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
  run_date        DATE NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 14. NOTIFICATIONS
-- ============================================================
CREATE TABLE notifications (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id      UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  ticket_id       UUID REFERENCES tickets(id) ON DELETE SET NULL,
  title           VARCHAR(300) NOT NULL,
  message         TEXT NOT NULL,
  channel         notification_channel NOT NULL DEFAULT 'in_app',
  is_read         BOOLEAN DEFAULT FALSE,
  sent_at         TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 15. ACTIVITY LOGS (Full audit trail)
-- ============================================================
CREATE TABLE activity_logs (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id      UUID REFERENCES companies(id) ON DELETE CASCADE,
  user_id         UUID REFERENCES users(id) ON DELETE SET NULL,
  entity_type     VARCHAR(50) NOT NULL,                -- 'ticket', 'user', 'property', etc.
  entity_id       UUID,
  action          VARCHAR(100) NOT NULL,               -- 'created', 'assigned', 'status_changed'
  old_value       JSONB,
  new_value       JSONB,
  ip_address      VARCHAR(45),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 16. PLATFORM METRICS (Super Admin — no company data)
-- ============================================================
CREATE TABLE platform_metrics (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  total_companies INTEGER DEFAULT 0,
  active_companies INTEGER DEFAULT 0,
  total_users     INTEGER DEFAULT 0,
  total_tickets   INTEGER DEFAULT 0,
  total_properties INTEGER DEFAULT 0,
  recorded_at     DATE NOT NULL DEFAULT CURRENT_DATE,
  UNIQUE(recorded_at)
);

-- ============================================================
-- INDEXES (Performance)
-- ============================================================

-- Users
CREATE INDEX idx_users_company     ON users(company_id);
CREATE INDEX idx_users_role        ON users(role);
CREATE INDEX idx_users_email       ON users(email);

-- Properties
CREATE INDEX idx_properties_company ON properties(company_id);

-- Units
CREATE INDEX idx_units_property    ON units(property_id);

-- Unit Occupants
CREATE INDEX idx_occupants_unit    ON unit_occupants(unit_id);
CREATE INDEX idx_occupants_user    ON unit_occupants(user_id);
CREATE INDEX idx_occupants_active  ON unit_occupants(unit_id) WHERE end_date IS NULL;

-- Tickets
CREATE INDEX idx_tickets_company   ON tickets(company_id);
CREATE INDEX idx_tickets_property  ON tickets(property_id);
CREATE INDEX idx_tickets_unit      ON tickets(unit_id);
CREATE INDEX idx_tickets_area      ON tickets(area_id);
CREATE INDEX idx_tickets_status    ON tickets(status);
CREATE INDEX idx_tickets_assigned  ON tickets(assigned_to);
CREATE INDEX idx_tickets_created   ON tickets(created_by);
CREATE INDEX idx_tickets_priority  ON tickets(priority);

-- Ticket Updates
CREATE INDEX idx_updates_ticket    ON ticket_updates(ticket_id);

-- Notifications
CREATE INDEX idx_notif_user        ON notifications(user_id);
CREATE INDEX idx_notif_unread      ON notifications(user_id) WHERE is_read = FALSE;

-- Activity Logs
CREATE INDEX idx_logs_company      ON activity_logs(company_id);
CREATE INDEX idx_logs_entity       ON activity_logs(entity_type, entity_id);

-- Maintenance Schedules
CREATE INDEX idx_schedules_due     ON maintenance_schedules(next_due_date) WHERE is_active = TRUE;

-- ============================================================
-- UPDATED_AT TRIGGER FUNCTION
-- ============================================================
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to all tables with updated_at
CREATE TRIGGER trg_companies_updated      BEFORE UPDATE ON companies      FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_company_settings_upd   BEFORE UPDATE ON company_settings FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_users_updated          BEFORE UPDATE ON users          FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_properties_updated     BEFORE UPDATE ON properties     FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_units_updated          BEFORE UPDATE ON units          FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_areas_updated          BEFORE UPDATE ON property_areas FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_categories_updated     BEFORE UPDATE ON categories     FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_tickets_updated        BEFORE UPDATE ON tickets        FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_schedules_updated      BEFORE UPDATE ON maintenance_schedules FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================
-- SEED DATA — Default Categories (applied on company creation)
-- ============================================================
-- Note: These are templates. Insert per company_id on onboarding.
-- Example:
-- INSERT INTO categories (company_id, name, icon)
-- VALUES
--   ('<company_id>', 'Plumbing',     'droplet'),
--   ('<company_id>', 'Electrical',   'zap'),
--   ('<company_id>', 'Security',     'shield'),
--   ('<company_id>', 'Landscaping',  'leaf'),
--   ('<company_id>', 'Appliances',   'settings'),
--   ('<company_id>', 'Structural',   'home'),
--   ('<company_id>', 'Cleaning',     'wind'),
--   ('<company_id>', 'Parking',      'car'),
--   ('<company_id>', 'HVAC',         'thermometer'),
--   ('<company_id>', 'Pest Control', 'bug');

-- ============================================================
-- END OF SCHEMA
-- ============================================================
