-- =============================================================================
-- Migration: create the 3 missing tables of the approved 18-table target
-- Status:    ADDITIVE. New, empty tables. Existing tables are not changed.
-- Source:    database/MIGRATION_MAPPING.md §2.5 (incident_events),
--            §2.13 (notification_deliveries), §2.18 (automation_runs).
-- Rollback:  database/rollback/20261107000200_create_target_tables.down.sql
--
-- Access: NO client access. Every privilege is revoked from anon/authenticated
-- and RLS is enabled with no policies. Who may read or write these tables is
-- part of the pending decisions A2 (boundary), A5 (n8n identity),
-- A6 (notifications) and A7 (audit/timeline). They are added later, together
-- with the database functions that write these tables.
--
-- Delete behaviour: references to incidents, investigations and playbook runs
-- are ON DELETE RESTRICT, so history cannot disappear silently (mapping §2.5).
-- Optional references to people/devices are ON DELETE SET NULL, the same rule
-- the existing actor columns use.
-- =============================================================================

-- Automation runs (one row per n8n workflow execution) -----------------------
CREATE TABLE public.automation_runs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workflow_name text NOT NULL,
    workflow_id text,
    n8n_execution_id text,
    trigger_type text,
    incident_id uuid,
    investigation_id uuid,
    playbook_run_id uuid,
    status text DEFAULT 'queued' NOT NULL,
    input jsonb DEFAULT '{}'::jsonb NOT NULL,
    output jsonb,
    error_message text,
    started_at timestamptz,
    completed_at timestamptz,
    created_at timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT automation_runs_pkey PRIMARY KEY (id),
    -- Prevents the same n8n execution from being recorded twice.
    CONSTRAINT automation_runs_n8n_execution_id_key UNIQUE (n8n_execution_id),
    CONSTRAINT automation_runs_status_check CHECK (status = ANY (ARRAY[
        'queued', 'running', 'success', 'failed', 'cancelled', 'timed_out'])),
    CONSTRAINT automation_runs_completed_after_started CHECK (
        completed_at IS NULL OR started_at IS NULL OR completed_at >= started_at),
    CONSTRAINT automation_runs_incident_id_fkey FOREIGN KEY (incident_id)
        REFERENCES public.incidents(id) ON DELETE RESTRICT,
    CONSTRAINT automation_runs_investigation_id_fkey FOREIGN KEY (investigation_id)
        REFERENCES public.investigations(id) ON DELETE RESTRICT,
    CONSTRAINT automation_runs_playbook_run_id_fkey FOREIGN KEY (playbook_run_id)
        REFERENCES public.playbook_runs(id) ON DELETE RESTRICT
);

COMMENT ON TABLE public.automation_runs IS
    'n8n workflow executions. Written only by trusted database functions (pending A5). No client access.';

CREATE INDEX idx_automation_runs_incident_id ON public.automation_runs USING btree (incident_id);
CREATE INDEX idx_automation_runs_investigation_id ON public.automation_runs USING btree (investigation_id);
CREATE INDEX idx_automation_runs_playbook_run_id ON public.automation_runs USING btree (playbook_run_id);
CREATE INDEX idx_automation_runs_status ON public.automation_runs USING btree (status);

-- Incident timeline (user-facing history; replaces legacy incident_logs) ------
CREATE TABLE public.incident_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    incident_id uuid NOT NULL,
    event_type text NOT NULL,
    source text,
    level text,
    message text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    actor_id uuid,
    occurred_at timestamptz DEFAULT now() NOT NULL,
    created_at timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT incident_events_pkey PRIMARY KEY (id),
    CONSTRAINT incident_events_event_type_check CHECK (event_type = ANY (ARRAY[
        'log', 'status_change', 'comment', 'investigation', 'approval',
        'remediation', 'recovery', 'notification'])),
    CONSTRAINT incident_events_level_check CHECK (level IS NULL OR level = ANY (ARRAY[
        'info', 'warning', 'error', 'critical'])),
    CONSTRAINT incident_events_incident_id_fkey FOREIGN KEY (incident_id)
        REFERENCES public.incidents(id) ON DELETE RESTRICT,
    CONSTRAINT incident_events_actor_id_fkey FOREIGN KEY (actor_id)
        REFERENCES public.profiles(id) ON DELETE SET NULL
);

COMMENT ON TABLE public.incident_events IS
    'Incident timeline. Append-only rules, writers and readers are pending A7. No client access yet.';

CREATE INDEX idx_incident_events_incident_occurred
    ON public.incident_events USING btree (incident_id, occurred_at DESC);
CREATE INDEX idx_incident_events_actor_id ON public.incident_events USING btree (actor_id);

-- Notification deliveries (per channel/device attempt for an inbox item) ------
CREATE TABLE public.notification_deliveries (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    notification_id uuid NOT NULL,
    device_token_id uuid,
    channel text NOT NULL,
    status text DEFAULT 'pending' NOT NULL,
    provider_message_id text,
    error_message text,
    attempt_count integer DEFAULT 0 NOT NULL,
    attempted_at timestamptz,
    delivered_at timestamptz,
    created_at timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT notification_deliveries_pkey PRIMARY KEY (id),
    CONSTRAINT notification_deliveries_channel_check CHECK (channel = ANY (ARRAY[
        'in_app', 'push', 'email', 'telegram'])),
    CONSTRAINT notification_deliveries_status_check CHECK (status = ANY (ARRAY[
        'pending', 'sent', 'failed', 'delivered'])),
    CONSTRAINT notification_deliveries_attempt_count_check CHECK (attempt_count >= 0),
    -- A delivery belongs to its notification and is removed with it (the
    -- notification itself is removed when its user or incident is deleted).
    CONSTRAINT notification_deliveries_notification_id_fkey FOREIGN KEY (notification_id)
        REFERENCES public.notifications(id) ON DELETE CASCADE,
    CONSTRAINT notification_deliveries_device_token_id_fkey FOREIGN KEY (device_token_id)
        REFERENCES public.device_tokens(id) ON DELETE SET NULL
);

COMMENT ON TABLE public.notification_deliveries IS
    'Delivery attempts per notification and channel. Writers pending A6. No client access.';

CREATE INDEX idx_notification_deliveries_notification_id
    ON public.notification_deliveries USING btree (notification_id);
CREATE INDEX idx_notification_deliveries_device_token_id
    ON public.notification_deliveries USING btree (device_token_id);
CREATE INDEX idx_notification_deliveries_status
    ON public.notification_deliveries USING btree (status);

-- Access: RLS on, no policies, no client privileges ---------------------------
ALTER TABLE public.automation_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.incident_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_deliveries ENABLE ROW LEVEL SECURITY;

-- Also removes the TRUNCATE/REFERENCES/TRIGGER/MAINTAIN that the live default
-- privileges grant to client roles on new tables (checklist P3b).
REVOKE ALL ON TABLE
    public.automation_runs, public.incident_events, public.notification_deliveries
FROM PUBLIC, anon, authenticated;
