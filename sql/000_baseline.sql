--
-- PostgreSQL database dump
--

\restrict 8fZtOydteTReWzzqqY4B5tLB8BhcDvmMezgj0HD62PyLkebpkRIqhnUm6QDmpxE

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.9 (Ubuntu 17.9-1.pgdg24.04+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: ae_intelligence; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA ae_intelligence;


--
-- Name: ae_platform; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA ae_platform;


--
-- Name: biz_001; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA biz_001;


--
-- Name: biz_002; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA biz_002;


--
-- Name: biz_003; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA biz_003;


--
-- Name: biz_004; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA biz_004;


--
-- Name: get_own_entity_id(); Type: FUNCTION; Schema: biz_001; Owner: -
--

CREATE FUNCTION biz_001.get_own_entity_id() RETURNS uuid
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
  SELECT e.id
  FROM biz_001.entities e
  WHERE (e.metadata->>'auth_user_id')::uuid = auth.uid()
  LIMIT 1;
$$;


--
-- Name: get_parent_student_id(); Type: FUNCTION; Schema: biz_001; Owner: -
--

CREATE FUNCTION biz_001.get_parent_student_id() RETURNS uuid
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
    SELECT sp.entity_id
    FROM biz_001.student_profiles sp
    WHERE sp.parent_id = biz_001.get_own_entity_id()
    LIMIT 1;
$$;


--
-- Name: get_parent_student_ids(); Type: FUNCTION; Schema: biz_001; Owner: -
--

CREATE FUNCTION biz_001.get_parent_student_ids() RETURNS TABLE(student_entity_id uuid)
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
  SELECT sp.entity_id
  FROM biz_001.student_profiles sp
  WHERE sp.parent_id = biz_001.get_own_entity_id();
$$;


--
-- Name: get_teacher_classes(); Type: FUNCTION; Schema: biz_001; Owner: -
--

CREATE FUNCTION biz_001.get_teacher_classes() RETURNS TABLE(class text, section text)
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
  SELECT DISTINCT ta.class, ta.section
  FROM biz_001.teacher_assignments ta
  WHERE ta.auth_user_id = auth.uid()
  AND ta.is_active = true
  AND ta.class IS NOT NULL;
$$;


--
-- Name: get_teacher_subject_ids(); Type: FUNCTION; Schema: biz_001; Owner: -
--

CREATE FUNCTION biz_001.get_teacher_subject_ids() RETURNS TABLE(subject_id uuid)
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
  SELECT DISTINCT ts.subject_id
  FROM biz_001.teacher_subjects ts
  JOIN biz_001.teacher_assignments ta
    ON ta.teacher_id = ts.teacher_id
    AND ta.class = ts.class
    AND ta.section = ts.section
  WHERE ta.auth_user_id = auth.uid()
  AND ta.is_active = true;
$$;


--
-- Name: get_user_role(); Type: FUNCTION; Schema: biz_001; Owner: -
--

CREATE FUNCTION biz_001.get_user_role() RETURNS text
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
  SELECT INITCAP(ur.role)
  FROM ae_platform.user_roles ur
  JOIN ae_platform.businesses b ON b.id = ur.business_id::uuid
  WHERE ur.auth_user_id = auth.uid()
  AND b.schema_name = 'biz_001'
  LIMIT 1;
$$;


--
-- Name: log_audit(); Type: FUNCTION; Schema: biz_001; Owner: -
--

CREATE FUNCTION biz_001.log_audit() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_row_id UUID;
  v_data JSONB;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_data := to_jsonb(OLD);
  ELSE
    v_data := to_jsonb(NEW);
  END IF;

  -- Try to extract the row ID from whichever PK column exists
  v_row_id := COALESCE(
    (v_data->>'id')::uuid,
    (v_data->>'subject_id')::uuid,
    (v_data->>'attendance_id')::uuid,
    (v_data->>'mark_id')::uuid,
    (v_data->>'payment_id')::uuid,
    (v_data->>'fee_structure_id')::uuid,
    (v_data->>'homework_id')::uuid,
    (v_data->>'submission_id')::uuid,
    (v_data->>'assignment_id')::uuid,
    (v_data->>'calendar_id')::uuid,
    (v_data->>'teacher_subject_id')::uuid,
    (v_data->>'route_id')::uuid,
    (v_data->>'stop_id')::uuid,
    (v_data->>'student_transport_id')::uuid,
    (v_data->>'point_id')::uuid,
    gen_random_uuid()
  );

  INSERT INTO biz_001.audit_log
    (business_id, table_name, row_id, action, old_data, new_data, changed_by)
  VALUES
    ((SELECT id FROM ae_platform.businesses WHERE schema_name = 'biz_001'),
     TG_TABLE_NAME,
     v_row_id,
     TG_OP,
     CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD) ELSE NULL END,  -- ← THE FIX
     CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN to_jsonb(NEW) ELSE NULL END,
     auth.uid()
    );
  RETURN COALESCE(NEW, OLD);
END;
$$;


--
-- Name: get_user_role(); Type: FUNCTION; Schema: biz_002; Owner: -
--

CREATE FUNCTION biz_002.get_user_role() RETURNS text
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
    SELECT role FROM biz_002.user_roles
    WHERE user_id = auth.uid()
    AND business_id = 'biz_002'
    LIMIT 1;
$$;


--
-- Name: log_audit(); Type: FUNCTION; Schema: biz_002; Owner: -
--

CREATE FUNCTION biz_002.log_audit() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO biz_002.audit_log (table_name, row_id, action, old_data, new_data)
        VALUES (TG_TABLE_NAME, NEW.id, 'INSERT', NULL, to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO biz_002.audit_log (table_name, row_id, action, old_data, new_data)
        VALUES (TG_TABLE_NAME, NEW.id, 'UPDATE', to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO biz_002.audit_log (table_name, row_id, action, old_data, new_data)
        VALUES (TG_TABLE_NAME, OLD.id, 'DELETE', to_jsonb(OLD), NULL);
        RETURN OLD;
    END IF;
END;
$$;


--
-- Name: update_client_counters(); Type: FUNCTION; Schema: biz_002; Owner: -
--

CREATE FUNCTION biz_002.update_client_counters() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    target_client_id UUID;
BEGIN
    -- Determine which client to update
    IF TG_OP = 'DELETE' THEN
        target_client_id := OLD.client_id;
    ELSE
        target_client_id := NEW.client_id;
    END IF;

    -- Recalculate all three counters from the source data
    UPDATE biz_002.entities SET
        total_events = COALESCE((
            SELECT COUNT(*) FROM biz_002.catering_orders
            WHERE client_id = target_client_id
            AND status NOT IN ('cancelled')
        ), 0),
        total_spend = COALESCE((
            SELECT SUM(total_amount) FROM biz_002.catering_orders
            WHERE client_id = target_client_id
            AND status NOT IN ('enquiry', 'cancelled')
        ), 0),
        last_event_date = (
            SELECT MAX(event_date) FROM biz_002.catering_orders
            WHERE client_id = target_client_id
            AND status NOT IN ('cancelled')
        )
    WHERE id = target_client_id;

    -- If client changed on UPDATE, also recalculate the OLD client
    IF TG_OP = 'UPDATE' AND OLD.client_id IS DISTINCT FROM NEW.client_id THEN
        UPDATE biz_002.entities SET
            total_events = COALESCE((
                SELECT COUNT(*) FROM biz_002.catering_orders
                WHERE client_id = OLD.client_id
                AND status NOT IN ('cancelled')
            ), 0),
            total_spend = COALESCE((
                SELECT SUM(total_amount) FROM biz_002.catering_orders
                WHERE client_id = OLD.client_id
                AND status NOT IN ('enquiry', 'cancelled')
            ), 0),
            last_event_date = (
                SELECT MAX(event_date) FROM biz_002.catering_orders
                WHERE client_id = OLD.client_id
                AND status NOT IN ('cancelled')
            )
        WHERE id = OLD.client_id;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: log_audit(); Type: FUNCTION; Schema: biz_003; Owner: -
--

CREATE FUNCTION biz_003.log_audit() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO biz_003.audit_log (table_name, row_id, action, old_data, new_data)
        VALUES (TG_TABLE_NAME, NEW.id, 'INSERT', NULL, to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO biz_003.audit_log (table_name, row_id, action, old_data, new_data)
        VALUES (TG_TABLE_NAME, NEW.id, 'UPDATE', to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO biz_003.audit_log (table_name, row_id, action, old_data, new_data)
        VALUES (TG_TABLE_NAME, OLD.id, 'DELETE', to_jsonb(OLD), NULL);
        RETURN OLD;
    END IF;
END;
$$;


--
-- Name: log_audit(); Type: FUNCTION; Schema: biz_004; Owner: -
--

CREATE FUNCTION biz_004.log_audit() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO biz_004.audit_log (table_name, row_id, action, old_data, new_data)
        VALUES (TG_TABLE_NAME, NEW.id, 'INSERT', NULL, to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO biz_004.audit_log (table_name, row_id, action, old_data, new_data)
        VALUES (TG_TABLE_NAME, NEW.id, 'UPDATE', to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO biz_004.audit_log (table_name, row_id, action, old_data, new_data)
        VALUES (TG_TABLE_NAME, OLD.id, 'DELETE', to_jsonb(OLD), NULL);
        RETURN OLD;
    END IF;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: benchmarks; Type: TABLE; Schema: ae_intelligence; Owner: -
--

CREATE TABLE ae_intelligence.benchmarks (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    vertical text NOT NULL,
    metric_name text NOT NULL,
    metric_value numeric(12,4),
    unit text,
    region text,
    sample_size integer,
    period_start date,
    period_end date,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: cross_signal_patterns; Type: TABLE; Schema: ae_intelligence; Owner: -
--

CREATE TABLE ae_intelligence.cross_signal_patterns (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    pattern_name text NOT NULL,
    description text,
    vertical text,
    agent_names text[],
    confidence numeric(5,4),
    sample_size integer,
    data jsonb DEFAULT '{}'::jsonb,
    status text DEFAULT 'active'::text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT cross_signal_patterns_status_check CHECK ((status = ANY (ARRAY['active'::text, 'superseded'::text, 'invalidated'::text])))
);


--
-- Name: health_score_inputs; Type: TABLE; Schema: ae_intelligence; Owner: -
--

CREATE TABLE ae_intelligence.health_score_inputs (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    intelligence_id uuid NOT NULL,
    vertical text NOT NULL,
    dimension text NOT NULL,
    metric_name text NOT NULL,
    metric_value numeric(12,4),
    period text,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: signal_aggregates; Type: TABLE; Schema: ae_intelligence; Owner: -
--

CREATE TABLE ae_intelligence.signal_aggregates (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    business_id uuid NOT NULL,
    signal_type text NOT NULL,
    anonymous_data jsonb DEFAULT '{}'::jsonb NOT NULL,
    period_start date,
    period_end date,
    computed_at timestamp with time zone DEFAULT now()
);


--
-- Name: businesses; Type: TABLE; Schema: ae_platform; Owner: -
--

CREATE TABLE ae_platform.businesses (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text NOT NULL,
    name text NOT NULL,
    vertical text NOT NULL,
    city text,
    state text,
    owner_name text,
    owner_phone text,
    owner_email text,
    schema_name text NOT NULL,
    intelligence_id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    status text DEFAULT 'active'::text NOT NULL,
    onboarded_at timestamp with time zone DEFAULT now(),
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT businesses_status_check CHECK ((status = ANY (ARRAY['active'::text, 'onboarding'::text, 'paused'::text, 'offboarded'::text])))
);


--
-- Name: ca_firm_clients; Type: TABLE; Schema: ae_platform; Owner: -
--

CREATE TABLE ae_platform.ca_firm_clients (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    ca_firm_id uuid NOT NULL,
    business_id text NOT NULL,
    relationship text DEFAULT 'accountant'::text,
    started_at date,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: ca_firms; Type: TABLE; Schema: ae_platform; Owner: -
--

CREATE TABLE ae_platform.ca_firms (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    name text NOT NULL,
    contact_name text,
    contact_phone text,
    contact_email text,
    city text,
    status text DEFAULT 'active'::text NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT ca_firms_status_check CHECK ((status = ANY (ARRAY['active'::text, 'inactive'::text])))
);


--
-- Name: consents; Type: TABLE; Schema: ae_platform; Owner: -
--

CREATE TABLE ae_platform.consents (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text NOT NULL,
    entity_name text NOT NULL,
    entity_role text,
    consent_type text NOT NULL,
    consent_given boolean DEFAULT false NOT NULL,
    given_at timestamp with time zone,
    revoked_at timestamp with time zone,
    method text,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: user_roles; Type: TABLE; Schema: ae_platform; Owner: -
--

CREATE TABLE ae_platform.user_roles (
    user_role_id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    auth_user_id uuid NOT NULL,
    business_id text NOT NULL,
    role text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT user_roles_role_check CHECK ((role = ANY (ARRAY['principal'::text, 'admin'::text, 'teacher'::text, 'parent'::text, 'student'::text])))
);


--
-- Name: academic_calendar; Type: TABLE; Schema: biz_001; Owner: -
--

CREATE TABLE biz_001.academic_calendar (
    calendar_id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_001'::text NOT NULL,
    event_name text NOT NULL,
    event_type text NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL,
    academic_year text DEFAULT '2026-27'::text NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT academic_calendar_event_type_check CHECK ((event_type = ANY (ARRAY['Term Start'::text, 'Term End'::text, 'Exam'::text, 'Holiday'::text, 'Event'::text, 'Working Day Adjustment'::text])))
);


--
-- Name: agent_signals; Type: TABLE; Schema: biz_001; Owner: -
--

CREATE TABLE biz_001.agent_signals (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_001'::text NOT NULL,
    agent_name text NOT NULL,
    signal_type text NOT NULL,
    severity text DEFAULT 'info'::text,
    entity_id uuid,
    title text NOT NULL,
    description text,
    data jsonb DEFAULT '{}'::jsonb,
    status text DEFAULT 'active'::text,
    resolved_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT agent_signals_severity_check CHECK ((severity = ANY (ARRAY['info'::text, 'low'::text, 'medium'::text, 'high'::text, 'critical'::text]))),
    CONSTRAINT agent_signals_status_check CHECK ((status = ANY (ARRAY['active'::text, 'acknowledged'::text, 'resolved'::text, 'dismissed'::text])))
);


--
-- Name: agent_signals_archive; Type: TABLE; Schema: biz_001; Owner: -
--

CREATE TABLE biz_001.agent_signals_archive (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_001'::text NOT NULL,
    agent_name text NOT NULL,
    signal_type text NOT NULL,
    severity text DEFAULT 'info'::text,
    entity_id uuid,
    title text NOT NULL,
    description text,
    data jsonb DEFAULT '{}'::jsonb,
    status text DEFAULT 'active'::text,
    resolved_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT agent_signals_severity_check CHECK ((severity = ANY (ARRAY['info'::text, 'low'::text, 'medium'::text, 'high'::text, 'critical'::text]))),
    CONSTRAINT agent_signals_status_check CHECK ((status = ANY (ARRAY['active'::text, 'acknowledged'::text, 'resolved'::text, 'dismissed'::text])))
);


--
-- Name: agent_signals_all; Type: VIEW; Schema: biz_001; Owner: -
--

CREATE VIEW biz_001.agent_signals_all AS
 SELECT agent_signals.id,
    agent_signals.business_id,
    agent_signals.agent_name,
    agent_signals.signal_type,
    agent_signals.severity,
    agent_signals.entity_id,
    agent_signals.title,
    agent_signals.description,
    agent_signals.data,
    agent_signals.status,
    agent_signals.resolved_at,
    agent_signals.created_at,
    agent_signals.updated_at
   FROM biz_001.agent_signals
UNION ALL
 SELECT agent_signals_archive.id,
    agent_signals_archive.business_id,
    agent_signals_archive.agent_name,
    agent_signals_archive.signal_type,
    agent_signals_archive.severity,
    agent_signals_archive.entity_id,
    agent_signals_archive.title,
    agent_signals_archive.description,
    agent_signals_archive.data,
    agent_signals_archive.status,
    agent_signals_archive.resolved_at,
    agent_signals_archive.created_at,
    agent_signals_archive.updated_at
   FROM biz_001.agent_signals_archive;


--
-- Name: attendance; Type: TABLE; Schema: biz_001; Owner: -
--

CREATE TABLE biz_001.attendance (
    attendance_id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_001'::text NOT NULL,
    student_id uuid NOT NULL,
    class text NOT NULL,
    section text NOT NULL,
    date date NOT NULL,
    status text NOT NULL,
    marked_by uuid,
    notes text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    period_number integer NOT NULL,
    CONSTRAINT attendance_period_number_check CHECK (((period_number >= 1) AND (period_number <= 7))),
    CONSTRAINT attendance_status_check CHECK ((status = ANY (ARRAY['Present'::text, 'Absent'::text, 'Late'::text, 'Half Day'::text, 'Leave'::text])))
);


--
-- Name: audit_log; Type: TABLE; Schema: biz_001; Owner: -
--

CREATE TABLE biz_001.audit_log (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_001'::text NOT NULL,
    table_name text NOT NULL,
    row_id uuid NOT NULL,
    action text NOT NULL,
    old_data jsonb,
    new_data jsonb,
    changed_by text DEFAULT CURRENT_USER,
    changed_at timestamp with time zone DEFAULT now(),
    CONSTRAINT audit_log_action_check CHECK ((action = ANY (ARRAY['INSERT'::text, 'UPDATE'::text, 'DELETE'::text])))
);


--
-- Name: documents; Type: TABLE; Schema: biz_001; Owner: -
--

CREATE TABLE biz_001.documents (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_001'::text NOT NULL,
    entity_id uuid,
    document_type text NOT NULL,
    title text NOT NULL,
    file_url text,
    file_size_bytes bigint,
    mime_type text,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: entities; Type: TABLE; Schema: biz_001; Owner: -
--

CREATE TABLE biz_001.entities (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_001'::text NOT NULL,
    entity_type text NOT NULL,
    first_name text NOT NULL,
    last_name text,
    phone text,
    email text,
    whatsapp text,
    address text,
    status text DEFAULT 'active'::text NOT NULL,
    tags text[],
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT entities_entity_type_check CHECK ((entity_type = ANY (ARRAY['student'::text, 'parent'::text, 'teacher'::text, 'staff'::text, 'vendor'::text, 'contact'::text]))),
    CONSTRAINT entities_status_check CHECK ((status = ANY (ARRAY['active'::text, 'inactive'::text, 'archived'::text])))
);


--
-- Name: events; Type: TABLE; Schema: biz_001; Owner: -
--

CREATE TABLE biz_001.events (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_001'::text NOT NULL,
    entity_id uuid,
    event_type text NOT NULL,
    event_date date NOT NULL,
    title text,
    description text,
    data jsonb DEFAULT '{}'::jsonb,
    status text DEFAULT 'recorded'::text,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT events_status_check CHECK ((status = ANY (ARRAY['scheduled'::text, 'recorded'::text, 'cancelled'::text])))
);


--
-- Name: fee_payments; Type: TABLE; Schema: biz_001; Owner: -
--

CREATE TABLE biz_001.fee_payments (
    payment_id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_001'::text NOT NULL,
    student_id uuid NOT NULL,
    fee_structure_id uuid,
    parent_id uuid,
    amount_paid numeric(10,2) NOT NULL,
    payment_date date DEFAULT CURRENT_DATE NOT NULL,
    payment_mode text NOT NULL,
    reference_number text,
    period_month integer,
    period_year integer,
    received_by uuid,
    academic_year text DEFAULT '2026-27'::text NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT fee_payments_amount_paid_check CHECK ((amount_paid > (0)::numeric)),
    CONSTRAINT fee_payments_payment_mode_check CHECK ((payment_mode = ANY (ARRAY['Cash'::text, 'UPI'::text, 'Cheque'::text, 'NEFT'::text, 'DD'::text]))),
    CONSTRAINT fee_payments_period_month_check CHECK (((period_month >= 1) AND (period_month <= 12)))
);


--
-- Name: fee_structure; Type: TABLE; Schema: biz_001; Owner: -
--

CREATE TABLE biz_001.fee_structure (
    fee_structure_id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_001'::text NOT NULL,
    class text NOT NULL,
    fee_type text NOT NULL,
    amount numeric(10,2) NOT NULL,
    frequency text NOT NULL,
    due_day integer,
    academic_year text DEFAULT '2026-27'::text NOT NULL,
    is_active boolean DEFAULT true,
    notes text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT fee_structure_amount_check CHECK ((amount >= (0)::numeric)),
    CONSTRAINT fee_structure_due_day_check CHECK (((due_day >= 1) AND (due_day <= 31))),
    CONSTRAINT fee_structure_fee_type_check CHECK ((fee_type = ANY (ARRAY['Tuition'::text, 'Transport'::text, 'Exam'::text, 'Annual'::text, 'Development'::text, 'Library'::text, 'Computer Lab'::text, 'Other'::text]))),
    CONSTRAINT fee_structure_frequency_check CHECK ((frequency = ANY (ARRAY['Monthly'::text, 'Quarterly'::text, 'Annual'::text, 'One Time'::text])))
);


--
-- Name: homework; Type: TABLE; Schema: biz_001; Owner: -
--

CREATE TABLE biz_001.homework (
    homework_id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_001'::text NOT NULL,
    title text NOT NULL,
    subject_id uuid NOT NULL,
    class text NOT NULL,
    section text NOT NULL,
    assigned_by uuid,
    assigned_date date DEFAULT CURRENT_DATE NOT NULL,
    due_date date NOT NULL,
    homework_type text NOT NULL,
    max_score numeric(5,2) DEFAULT 10,
    questions jsonb DEFAULT '[]'::jsonb,
    instructions text,
    is_active boolean DEFAULT true,
    academic_year text DEFAULT '2026-27'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT homework_homework_type_check CHECK ((homework_type = ANY (ARRAY['Quiz'::text, 'Worksheet'::text, 'Reading'::text, 'Project'::text])))
);


--
-- Name: homework_submissions; Type: TABLE; Schema: biz_001; Owner: -
--

CREATE TABLE biz_001.homework_submissions (
    submission_id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_001'::text NOT NULL,
    homework_id uuid NOT NULL,
    student_id uuid NOT NULL,
    submitted_at timestamp with time zone DEFAULT now(),
    score numeric(5,2),
    attempt_number integer DEFAULT 1,
    answers jsonb DEFAULT '{}'::jsonb,
    status text DEFAULT 'Submitted'::text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT homework_submissions_score_check CHECK ((score >= (0)::numeric)),
    CONSTRAINT homework_submissions_status_check CHECK ((status = ANY (ARRAY['Submitted'::text, 'Late'::text, 'Graded'::text, 'Not Submitted'::text])))
);


--
-- Name: house_points; Type: TABLE; Schema: biz_001; Owner: -
--

CREATE TABLE biz_001.house_points (
    point_id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_001'::text NOT NULL,
    house_name text NOT NULL,
    points_awarded integer NOT NULL,
    reason text NOT NULL,
    reason_category text,
    awarded_to_student_id uuid,
    awarded_by uuid,
    awarded_date date DEFAULT CURRENT_DATE NOT NULL,
    academic_year text DEFAULT '2026-27'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT house_points_house_name_check CHECK ((house_name = ANY (ARRAY['Red'::text, 'Blue'::text, 'Green'::text, 'Yellow'::text]))),
    CONSTRAINT house_points_points_awarded_check CHECK ((points_awarded > 0)),
    CONSTRAINT house_points_reason_category_check CHECK ((reason_category = ANY (ARRAY['Sports'::text, 'Academic'::text, 'Cultural'::text, 'Behaviour'::text, 'Other'::text])))
);


--
-- Name: interventions; Type: TABLE; Schema: biz_001; Owner: -
--

CREATE TABLE biz_001.interventions (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_001'::text NOT NULL,
    agent_name text NOT NULL,
    signal_id uuid,
    action_type text NOT NULL,
    action_payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    status text DEFAULT 'pending'::text,
    decided_by text,
    decided_at timestamp with time zone,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT interventions_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text, 'auto_executed'::text, 'expired'::text])))
);


--
-- Name: marks; Type: TABLE; Schema: biz_001; Owner: -
--

CREATE TABLE biz_001.marks (
    mark_id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_001'::text NOT NULL,
    student_id uuid NOT NULL,
    subject_id uuid NOT NULL,
    class text NOT NULL,
    section text NOT NULL,
    exam_type text NOT NULL,
    exam_date date NOT NULL,
    score numeric(5,2),
    max_marks numeric(5,2) NOT NULL,
    marked_by uuid,
    academic_year text DEFAULT '2026-27'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT marks_exam_type_check CHECK ((exam_type = ANY (ARRAY['Unit Test 1'::text, 'Unit Test 2'::text, 'Unit Test 3'::text, 'Half Yearly'::text, 'Pre-Final'::text, 'Annual'::text, 'Class Test'::text, 'Assignment'::text]))),
    CONSTRAINT marks_max_marks_check CHECK ((max_marks > (0)::numeric)),
    CONSTRAINT marks_score_check CHECK ((score >= (0)::numeric))
);


--
-- Name: performance_observations; Type: TABLE; Schema: biz_001; Owner: -
--

CREATE TABLE biz_001.performance_observations (
    observation_id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_001'::text NOT NULL,
    student_id uuid NOT NULL,
    class text NOT NULL,
    section text NOT NULL,
    subject_id uuid,
    observed_by uuid,
    observation_date date NOT NULL,
    participation integer,
    classwork_score numeric(4,1),
    behaviour text,
    homework_status text,
    notes text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT performance_observations_behaviour_check CHECK ((behaviour = ANY (ARRAY['Excellent'::text, 'Good'::text, 'Satisfactory'::text, 'Needs Improvement'::text]))),
    CONSTRAINT performance_observations_classwork_score_check CHECK (((classwork_score >= (0)::numeric) AND (classwork_score <= (10)::numeric))),
    CONSTRAINT performance_observations_homework_status_check CHECK ((homework_status = ANY (ARRAY['Submitted'::text, 'Late'::text, 'Not Submitted'::text, 'Incomplete'::text]))),
    CONSTRAINT performance_observations_participation_check CHECK (((participation >= 1) AND (participation <= 5)))
);


--
-- Name: student_profiles; Type: TABLE; Schema: biz_001; Owner: -
--

CREATE TABLE biz_001.student_profiles (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_001'::text NOT NULL,
    entity_id uuid NOT NULL,
    parent_id uuid,
    admission_number text,
    class text,
    section text,
    house text,
    date_of_birth date,
    blood_group text,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    roll_number text,
    gender text,
    photo_url text,
    admission_date date,
    fee_category text,
    transport_mode text,
    previous_school text,
    disability_status text,
    academic_year text,
    enrollment_status text DEFAULT 'enrolled'::text NOT NULL
);


--
-- Name: COLUMN student_profiles.roll_number; Type: COMMENT; Schema: biz_001; Owner: -
--

COMMENT ON COLUMN biz_001.student_profiles.roll_number IS 'Class-level roll number, distinct from school-wide admission_number';


--
-- Name: COLUMN student_profiles.gender; Type: COMMENT; Schema: biz_001; Owner: -
--

COMMENT ON COLUMN biz_001.student_profiles.gender IS 'DPDP-sensitive. Standard values: Male/Female/Other/Prefer not to say. Populate only with consent.';


--
-- Name: COLUMN student_profiles.photo_url; Type: COMMENT; Schema: biz_001; Owner: -
--

COMMENT ON COLUMN biz_001.student_profiles.photo_url IS 'URL to student photo, typically a Supabase Storage path';


--
-- Name: COLUMN student_profiles.admission_date; Type: COMMENT; Schema: biz_001; Owner: -
--

COMMENT ON COLUMN biz_001.student_profiles.admission_date IS 'Date the student joined the school (admission, not academic year start)';


--
-- Name: COLUMN student_profiles.fee_category; Type: COMMENT; Schema: biz_001; Owner: -
--

COMMENT ON COLUMN biz_001.student_profiles.fee_category IS 'Free-text interim; future FK to fee_structure.category when Item #5 unblocks';


--
-- Name: COLUMN student_profiles.transport_mode; Type: COMMENT; Schema: biz_001; Owner: -
--

COMMENT ON COLUMN biz_001.student_profiles.transport_mode IS 'Standard values: bus/own/walking. Free-text until transport_routes is modelled.';


--
-- Name: COLUMN student_profiles.previous_school; Type: COMMENT; Schema: biz_001; Owner: -
--

COMMENT ON COLUMN biz_001.student_profiles.previous_school IS 'Name of prior school for transfer-in students';


--
-- Name: COLUMN student_profiles.disability_status; Type: COMMENT; Schema: biz_001; Owner: -
--

COMMENT ON COLUMN biz_001.student_profiles.disability_status IS 'DPDP-sensitive. NO current consumer in 8 Pulse agents. Populate only with documented purpose + consent.';


--
-- Name: COLUMN student_profiles.academic_year; Type: COMMENT; Schema: biz_001; Owner: -
--

COMMENT ON COLUMN biz_001.student_profiles.academic_year IS 'Format: YYYY-YY (e.g., 2026-27). India academic year starts in June.';


--
-- Name: COLUMN student_profiles.enrollment_status; Type: COMMENT; Schema: biz_001; Owner: -
--

COMMENT ON COLUMN biz_001.student_profiles.enrollment_status IS 'Student-level state: enrolled/transferred/graduated/withdrawn. Distinct from entity-level entities.status.';


--
-- Name: student_transport; Type: TABLE; Schema: biz_001; Owner: -
--

CREATE TABLE biz_001.student_transport (
    student_transport_id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_001'::text NOT NULL,
    student_id uuid NOT NULL,
    route_id uuid NOT NULL,
    stop_id uuid NOT NULL,
    monthly_fee numeric(10,2) NOT NULL,
    academic_year text DEFAULT '2026-27'::text NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT student_transport_monthly_fee_check CHECK ((monthly_fee >= (0)::numeric))
);


--
-- Name: subjects; Type: TABLE; Schema: biz_001; Owner: -
--

CREATE TABLE biz_001.subjects (
    subject_id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_001'::text NOT NULL,
    subject_name text NOT NULL,
    subject_code text,
    class text NOT NULL,
    academic_year text DEFAULT '2026-27'::text NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: teacher_assignments; Type: TABLE; Schema: biz_001; Owner: -
--

CREATE TABLE biz_001.teacher_assignments (
    assignment_id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_001'::text NOT NULL,
    teacher_id uuid NOT NULL,
    auth_user_id uuid,
    class text NOT NULL,
    section text NOT NULL,
    role text NOT NULL,
    academic_year text DEFAULT '2026-27'::text NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT teacher_assignments_role_check CHECK ((role = ANY (ARRAY['Class Teacher'::text, 'Subject Teacher'::text, 'Admin'::text, 'Principal'::text])))
);


--
-- Name: teacher_profiles; Type: TABLE; Schema: biz_001; Owner: -
--

CREATE TABLE biz_001.teacher_profiles (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_001'::text NOT NULL,
    entity_id uuid NOT NULL,
    employee_code text,
    joining_date date,
    qualifications text,
    employment_type text,
    photo_url text,
    gender text,
    date_of_birth date,
    blood_group text,
    employment_status text DEFAULT 'active'::text NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: TABLE teacher_profiles; Type: COMMENT; Schema: biz_001; Owner: -
--

COMMENT ON TABLE biz_001.teacher_profiles IS 'Teacher demographic + employment metadata. Mirrors student_profiles shape. Identity/contact in entities; assignments in teacher_assignments; subjects in teacher_subjects.';


--
-- Name: COLUMN teacher_profiles.employee_code; Type: COMMENT; Schema: biz_001; Owner: -
--

COMMENT ON COLUMN biz_001.teacher_profiles.employee_code IS 'School-internal teacher ID (analogous to admission_number for students)';


--
-- Name: COLUMN teacher_profiles.joining_date; Type: COMMENT; Schema: biz_001; Owner: -
--

COMMENT ON COLUMN biz_001.teacher_profiles.joining_date IS 'Date the teacher joined this school (analogous to admission_date for students)';


--
-- Name: COLUMN teacher_profiles.qualifications; Type: COMMENT; Schema: biz_001; Owner: -
--

COMMENT ON COLUMN biz_001.teacher_profiles.qualifications IS 'Free-text qualifications (e.g., "B.Ed, M.Sc Mathematics"). Could move to structured array later.';


--
-- Name: COLUMN teacher_profiles.employment_type; Type: COMMENT; Schema: biz_001; Owner: -
--

COMMENT ON COLUMN biz_001.teacher_profiles.employment_type IS 'Standard values: full-time/part-time/contract/visiting. Free-text for now.';


--
-- Name: COLUMN teacher_profiles.photo_url; Type: COMMENT; Schema: biz_001; Owner: -
--

COMMENT ON COLUMN biz_001.teacher_profiles.photo_url IS 'URL to teacher photo, typically a Supabase Storage path';


--
-- Name: COLUMN teacher_profiles.gender; Type: COMMENT; Schema: biz_001; Owner: -
--

COMMENT ON COLUMN biz_001.teacher_profiles.gender IS 'DPDP-sensitive. Standard values: Male/Female/Other/Prefer not to say. Populate only with consent.';


--
-- Name: COLUMN teacher_profiles.date_of_birth; Type: COMMENT; Schema: biz_001; Owner: -
--

COMMENT ON COLUMN biz_001.teacher_profiles.date_of_birth IS 'DPDP-sensitive. Used for age verification, leave eligibility, retirement planning.';


--
-- Name: COLUMN teacher_profiles.blood_group; Type: COMMENT; Schema: biz_001; Owner: -
--

COMMENT ON COLUMN biz_001.teacher_profiles.blood_group IS 'For emergency/medical contexts. Free-text (e.g., "O+", "AB-").';


--
-- Name: COLUMN teacher_profiles.employment_status; Type: COMMENT; Schema: biz_001; Owner: -
--

COMMENT ON COLUMN biz_001.teacher_profiles.employment_status IS 'Teacher-level state: active/on-leave/resigned/terminated. Distinct from entity-level entities.status.';


--
-- Name: teacher_subjects; Type: TABLE; Schema: biz_001; Owner: -
--

CREATE TABLE biz_001.teacher_subjects (
    teacher_subject_id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_001'::text NOT NULL,
    teacher_id uuid NOT NULL,
    subject_id uuid NOT NULL,
    class text NOT NULL,
    section text NOT NULL,
    academic_year text DEFAULT '2026-27'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: teacher_subjects_backup_20260506; Type: TABLE; Schema: biz_001; Owner: -
--

CREATE TABLE biz_001.teacher_subjects_backup_20260506 (
    teacher_subject_id uuid,
    business_id text,
    teacher_id uuid,
    subject_id uuid,
    class text,
    section text,
    academic_year text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone
);


--
-- Name: transactions; Type: TABLE; Schema: biz_001; Owner: -
--

CREATE TABLE biz_001.transactions (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_001'::text NOT NULL,
    entity_id uuid,
    transaction_type text NOT NULL,
    amount numeric(12,2) NOT NULL,
    currency text DEFAULT 'INR'::text,
    date date NOT NULL,
    description text,
    payment_method text,
    reference_number text,
    status text DEFAULT 'completed'::text,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT transactions_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'completed'::text, 'failed'::text, 'reversed'::text]))),
    CONSTRAINT transactions_transaction_type_check CHECK ((transaction_type = ANY (ARRAY['fee_payment'::text, 'salary'::text, 'vendor_payment'::text, 'refund'::text, 'expense'::text, 'other'::text])))
);


--
-- Name: transport_routes; Type: TABLE; Schema: biz_001; Owner: -
--

CREATE TABLE biz_001.transport_routes (
    route_id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_001'::text NOT NULL,
    route_code text NOT NULL,
    route_name text NOT NULL,
    vehicle_type text,
    vehicle_number text,
    driver_name text NOT NULL,
    driver_phone text,
    monthly_cost numeric(10,2),
    is_active boolean DEFAULT true,
    academic_year text DEFAULT '2026-27'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: transport_stops; Type: TABLE; Schema: biz_001; Owner: -
--

CREATE TABLE biz_001.transport_stops (
    stop_id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_001'::text NOT NULL,
    route_id uuid NOT NULL,
    stop_name text NOT NULL,
    stop_order integer NOT NULL,
    pickup_time time without time zone,
    dropoff_time time without time zone,
    landmark text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT transport_stops_stop_order_check CHECK ((stop_order > 0))
);


--
-- Name: agent_signals; Type: TABLE; Schema: biz_002; Owner: -
--

CREATE TABLE biz_002.agent_signals (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_002'::text NOT NULL,
    agent_name text NOT NULL,
    signal_type text NOT NULL,
    severity text DEFAULT 'info'::text,
    entity_id uuid,
    order_id uuid,
    title text NOT NULL,
    description text,
    data jsonb DEFAULT '{}'::jsonb,
    status text DEFAULT 'active'::text,
    resolved_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT agent_signals_severity_check CHECK ((severity = ANY (ARRAY['info'::text, 'low'::text, 'medium'::text, 'high'::text, 'critical'::text]))),
    CONSTRAINT agent_signals_status_check CHECK ((status = ANY (ARRAY['active'::text, 'acknowledged'::text, 'resolved'::text, 'dismissed'::text])))
);


--
-- Name: agent_signals_archive; Type: TABLE; Schema: biz_002; Owner: -
--

CREATE TABLE biz_002.agent_signals_archive (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_002'::text NOT NULL,
    agent_name text NOT NULL,
    signal_type text NOT NULL,
    severity text DEFAULT 'info'::text,
    entity_id uuid,
    order_id uuid,
    title text NOT NULL,
    description text,
    data jsonb DEFAULT '{}'::jsonb,
    status text DEFAULT 'active'::text,
    resolved_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT agent_signals_severity_check CHECK ((severity = ANY (ARRAY['info'::text, 'low'::text, 'medium'::text, 'high'::text, 'critical'::text]))),
    CONSTRAINT agent_signals_status_check CHECK ((status = ANY (ARRAY['active'::text, 'acknowledged'::text, 'resolved'::text, 'dismissed'::text])))
);


--
-- Name: agent_signals_all; Type: VIEW; Schema: biz_002; Owner: -
--

CREATE VIEW biz_002.agent_signals_all AS
 SELECT agent_signals.id,
    agent_signals.business_id,
    agent_signals.agent_name,
    agent_signals.signal_type,
    agent_signals.severity,
    agent_signals.entity_id,
    agent_signals.order_id,
    agent_signals.title,
    agent_signals.description,
    agent_signals.data,
    agent_signals.status,
    agent_signals.resolved_at,
    agent_signals.created_at,
    agent_signals.updated_at
   FROM biz_002.agent_signals
UNION ALL
 SELECT agent_signals_archive.id,
    agent_signals_archive.business_id,
    agent_signals_archive.agent_name,
    agent_signals_archive.signal_type,
    agent_signals_archive.severity,
    agent_signals_archive.entity_id,
    agent_signals_archive.order_id,
    agent_signals_archive.title,
    agent_signals_archive.description,
    agent_signals_archive.data,
    agent_signals_archive.status,
    agent_signals_archive.resolved_at,
    agent_signals_archive.created_at,
    agent_signals_archive.updated_at
   FROM biz_002.agent_signals_archive;


--
-- Name: audit_log; Type: TABLE; Schema: biz_002; Owner: -
--

CREATE TABLE biz_002.audit_log (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_002'::text NOT NULL,
    table_name text NOT NULL,
    row_id uuid NOT NULL,
    action text NOT NULL,
    old_data jsonb,
    new_data jsonb,
    changed_by text DEFAULT CURRENT_USER,
    changed_at timestamp with time zone DEFAULT now(),
    CONSTRAINT audit_log_action_check CHECK ((action = ANY (ARRAY['INSERT'::text, 'UPDATE'::text, 'DELETE'::text])))
);


--
-- Name: catering_orders; Type: TABLE; Schema: biz_002; Owner: -
--

CREATE TABLE biz_002.catering_orders (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_002'::text NOT NULL,
    client_id uuid NOT NULL,
    event_name text NOT NULL,
    event_type text NOT NULL,
    event_date date NOT NULL,
    event_end_date date,
    city text NOT NULL,
    venue text,
    guest_count integer NOT NULL,
    menu_type text,
    per_plate_rate numeric(8,2),
    total_amount numeric(12,2),
    advance_amount numeric(12,2) DEFAULT 0,
    balance_amount numeric(12,2),
    outstation boolean DEFAULT false,
    status text DEFAULT 'enquiry'::text NOT NULL,
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT catering_orders_advance_amount_check CHECK ((advance_amount >= (0)::numeric)),
    CONSTRAINT catering_orders_event_type_check CHECK ((event_type = ANY (ARRAY['wedding'::text, 'corporate'::text, 'religious'::text, 'political'::text, 'birthday'::text, 'bulk_tiffin'::text, 'other'::text]))),
    CONSTRAINT catering_orders_guest_count_check CHECK ((guest_count > 0)),
    CONSTRAINT catering_orders_menu_type_check CHECK ((menu_type = ANY (ARRAY['veg_simple'::text, 'veg_standard'::text, 'veg_grand'::text, 'nonveg_simple'::text, 'nonveg_standard'::text, 'nonveg_grand'::text, 'combo_standard'::text, 'combo_grand'::text]))),
    CONSTRAINT catering_orders_per_plate_rate_check CHECK ((per_plate_rate > (0)::numeric)),
    CONSTRAINT catering_orders_status_check CHECK ((status = ANY (ARRAY['enquiry'::text, 'quoted'::text, 'confirmed'::text, 'in_progress'::text, 'completed'::text, 'cancelled'::text]))),
    CONSTRAINT catering_orders_total_amount_check CHECK ((total_amount > (0)::numeric))
);


--
-- Name: documents; Type: TABLE; Schema: biz_002; Owner: -
--

CREATE TABLE biz_002.documents (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_002'::text NOT NULL,
    entity_id uuid,
    order_id uuid,
    document_type text NOT NULL,
    title text NOT NULL,
    file_url text,
    file_size_bytes bigint,
    mime_type text,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: entities; Type: TABLE; Schema: biz_002; Owner: -
--

CREATE TABLE biz_002.entities (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_002'::text NOT NULL,
    entity_type text NOT NULL,
    first_name text NOT NULL,
    last_name text,
    phone text,
    email text,
    whatsapp text,
    address text,
    city text,
    status text DEFAULT 'active'::text NOT NULL,
    tags text[],
    preferences jsonb DEFAULT '{}'::jsonb,
    total_events integer DEFAULT 0,
    total_spend numeric(12,2) DEFAULT 0,
    last_event_date date,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT entities_entity_type_check CHECK ((entity_type = ANY (ARRAY['client'::text, 'vendor'::text, 'staff'::text, 'contact'::text]))),
    CONSTRAINT entities_status_check CHECK ((status = ANY (ARRAY['active'::text, 'inactive'::text, 'archived'::text])))
);


--
-- Name: event_expenses; Type: TABLE; Schema: biz_002; Owner: -
--

CREATE TABLE biz_002.event_expenses (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_002'::text NOT NULL,
    order_id uuid NOT NULL,
    vendor_id uuid,
    category text NOT NULL,
    item_name text NOT NULL,
    quantity numeric(10,2),
    unit text,
    unit_price numeric(10,2),
    total_amount numeric(12,2) NOT NULL,
    date date NOT NULL,
    payment_method text,
    paid boolean DEFAULT false,
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT event_expenses_category_check CHECK ((category = ANY (ARRAY['groceries'::text, 'meat'::text, 'dairy'::text, 'spices'::text, 'vegetables'::text, 'fruits'::text, 'beverages'::text, 'equipment_rental'::text, 'transport'::text, 'staff_wages'::text, 'venue'::text, 'decoration'::text, 'utilities'::text, 'other'::text]))),
    CONSTRAINT event_expenses_quantity_check CHECK ((quantity > (0)::numeric)),
    CONSTRAINT event_expenses_total_amount_check CHECK ((total_amount > (0)::numeric)),
    CONSTRAINT event_expenses_unit_price_check CHECK ((unit_price > (0)::numeric))
);


--
-- Name: event_staff; Type: TABLE; Schema: biz_002; Owner: -
--

CREATE TABLE biz_002.event_staff (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_002'::text NOT NULL,
    order_id uuid NOT NULL,
    staff_id uuid NOT NULL,
    role text NOT NULL,
    shift text,
    wage_amount numeric(8,2),
    wage_paid boolean DEFAULT false,
    rating integer,
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT event_staff_rating_check CHECK (((rating >= 1) AND (rating <= 5))),
    CONSTRAINT event_staff_role_check CHECK ((role = ANY (ARRAY['head_cook_veg'::text, 'head_cook_nonveg'::text, 'assistant_cook'::text, 'server'::text, 'cleaner'::text, 'driver'::text, 'supervisor'::text, 'helper'::text, 'other'::text]))),
    CONSTRAINT event_staff_wage_amount_check CHECK ((wage_amount > (0)::numeric))
);


--
-- Name: events; Type: TABLE; Schema: biz_002; Owner: -
--

CREATE TABLE biz_002.events (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_002'::text NOT NULL,
    entity_id uuid,
    event_type text NOT NULL,
    event_date date NOT NULL,
    title text,
    description text,
    data jsonb DEFAULT '{}'::jsonb,
    status text DEFAULT 'recorded'::text,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT events_status_check CHECK ((status = ANY (ARRAY['scheduled'::text, 'recorded'::text, 'cancelled'::text])))
);


--
-- Name: interventions; Type: TABLE; Schema: biz_002; Owner: -
--

CREATE TABLE biz_002.interventions (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_002'::text NOT NULL,
    agent_name text NOT NULL,
    signal_id uuid,
    action_type text NOT NULL,
    action_payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    status text DEFAULT 'pending'::text,
    decided_by text,
    decided_at timestamp with time zone,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT interventions_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text, 'auto_executed'::text, 'expired'::text])))
);


--
-- Name: quotes; Type: TABLE; Schema: biz_002; Owner: -
--

CREATE TABLE biz_002.quotes (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_002'::text NOT NULL,
    client_id uuid NOT NULL,
    order_id uuid,
    event_type text NOT NULL,
    event_date date,
    city text,
    guest_count integer NOT NULL,
    menu_type text,
    per_plate_rate numeric(8,2) NOT NULL,
    total_amount numeric(12,2) NOT NULL,
    outstation_multiplier numeric(4,2) DEFAULT 1.00,
    margin_percent numeric(5,2),
    cost_breakdown jsonb DEFAULT '{}'::jsonb,
    status text DEFAULT 'draft'::text,
    sent_at timestamp with time zone,
    valid_until date,
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT quotes_guest_count_check CHECK ((guest_count > 0)),
    CONSTRAINT quotes_per_plate_rate_check CHECK ((per_plate_rate > (0)::numeric)),
    CONSTRAINT quotes_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'sent'::text, 'accepted'::text, 'rejected'::text, 'expired'::text]))),
    CONSTRAINT quotes_total_amount_check CHECK ((total_amount > (0)::numeric))
);


--
-- Name: transactions; Type: TABLE; Schema: biz_002; Owner: -
--

CREATE TABLE biz_002.transactions (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_002'::text NOT NULL,
    entity_id uuid,
    order_id uuid,
    transaction_type text NOT NULL,
    amount numeric(12,2) NOT NULL,
    currency text DEFAULT 'INR'::text,
    date date NOT NULL,
    description text,
    payment_method text,
    reference_number text,
    status text DEFAULT 'completed'::text,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT transactions_amount_check CHECK ((amount > (0)::numeric)),
    CONSTRAINT transactions_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'completed'::text, 'failed'::text, 'reversed'::text]))),
    CONSTRAINT transactions_transaction_type_check CHECK ((transaction_type = ANY (ARRAY['payment_received'::text, 'payment_made'::text, 'advance'::text, 'refund'::text, 'expense'::text])))
);


--
-- Name: agent_signals; Type: TABLE; Schema: biz_003; Owner: -
--

CREATE TABLE biz_003.agent_signals (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_003'::text NOT NULL,
    agent_name text NOT NULL,
    signal_type text NOT NULL,
    severity text DEFAULT 'info'::text,
    entity_id uuid,
    title text NOT NULL,
    description text,
    data jsonb DEFAULT '{}'::jsonb,
    status text DEFAULT 'active'::text,
    resolved_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT agent_signals_severity_check CHECK ((severity = ANY (ARRAY['info'::text, 'low'::text, 'medium'::text, 'high'::text, 'critical'::text]))),
    CONSTRAINT agent_signals_status_check CHECK ((status = ANY (ARRAY['active'::text, 'acknowledged'::text, 'resolved'::text, 'dismissed'::text])))
);


--
-- Name: agent_signals_archive; Type: TABLE; Schema: biz_003; Owner: -
--

CREATE TABLE biz_003.agent_signals_archive (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_003'::text NOT NULL,
    agent_name text NOT NULL,
    signal_type text NOT NULL,
    severity text DEFAULT 'info'::text,
    entity_id uuid,
    title text NOT NULL,
    description text,
    data jsonb DEFAULT '{}'::jsonb,
    status text DEFAULT 'active'::text,
    resolved_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT agent_signals_severity_check CHECK ((severity = ANY (ARRAY['info'::text, 'low'::text, 'medium'::text, 'high'::text, 'critical'::text]))),
    CONSTRAINT agent_signals_status_check CHECK ((status = ANY (ARRAY['active'::text, 'acknowledged'::text, 'resolved'::text, 'dismissed'::text])))
);


--
-- Name: agent_signals_all; Type: VIEW; Schema: biz_003; Owner: -
--

CREATE VIEW biz_003.agent_signals_all AS
 SELECT agent_signals.id,
    agent_signals.business_id,
    agent_signals.agent_name,
    agent_signals.signal_type,
    agent_signals.severity,
    agent_signals.entity_id,
    agent_signals.title,
    agent_signals.description,
    agent_signals.data,
    agent_signals.status,
    agent_signals.resolved_at,
    agent_signals.created_at,
    agent_signals.updated_at
   FROM biz_003.agent_signals
UNION ALL
 SELECT agent_signals_archive.id,
    agent_signals_archive.business_id,
    agent_signals_archive.agent_name,
    agent_signals_archive.signal_type,
    agent_signals_archive.severity,
    agent_signals_archive.entity_id,
    agent_signals_archive.title,
    agent_signals_archive.description,
    agent_signals_archive.data,
    agent_signals_archive.status,
    agent_signals_archive.resolved_at,
    agent_signals_archive.created_at,
    agent_signals_archive.updated_at
   FROM biz_003.agent_signals_archive;


--
-- Name: audit_log; Type: TABLE; Schema: biz_003; Owner: -
--

CREATE TABLE biz_003.audit_log (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_003'::text NOT NULL,
    table_name text NOT NULL,
    row_id uuid NOT NULL,
    action text NOT NULL,
    old_data jsonb,
    new_data jsonb,
    changed_by text DEFAULT CURRENT_USER,
    changed_at timestamp with time zone DEFAULT now(),
    CONSTRAINT audit_log_action_check CHECK ((action = ANY (ARRAY['INSERT'::text, 'UPDATE'::text, 'DELETE'::text])))
);


--
-- Name: documents; Type: TABLE; Schema: biz_003; Owner: -
--

CREATE TABLE biz_003.documents (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_003'::text NOT NULL,
    entity_id uuid,
    document_type text NOT NULL,
    title text NOT NULL,
    file_url text,
    file_size_bytes bigint,
    mime_type text,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: entities; Type: TABLE; Schema: biz_003; Owner: -
--

CREATE TABLE biz_003.entities (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_003'::text NOT NULL,
    entity_type text NOT NULL,
    first_name text NOT NULL,
    last_name text,
    phone text,
    email text,
    whatsapp text,
    address text,
    status text DEFAULT 'active'::text NOT NULL,
    tags text[],
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT entities_entity_type_check CHECK ((entity_type = ANY (ARRAY['buyer'::text, 'tenant'::text, 'broker'::text, 'contractor'::text, 'vendor'::text, 'staff'::text, 'contact'::text]))),
    CONSTRAINT entities_status_check CHECK ((status = ANY (ARRAY['active'::text, 'inactive'::text, 'archived'::text])))
);


--
-- Name: events; Type: TABLE; Schema: biz_003; Owner: -
--

CREATE TABLE biz_003.events (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_003'::text NOT NULL,
    entity_id uuid,
    event_type text NOT NULL,
    event_date date NOT NULL,
    title text,
    description text,
    data jsonb DEFAULT '{}'::jsonb,
    status text DEFAULT 'recorded'::text,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT events_status_check CHECK ((status = ANY (ARRAY['scheduled'::text, 'recorded'::text, 'cancelled'::text])))
);


--
-- Name: interventions; Type: TABLE; Schema: biz_003; Owner: -
--

CREATE TABLE biz_003.interventions (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_003'::text NOT NULL,
    agent_name text NOT NULL,
    signal_id uuid,
    action_type text NOT NULL,
    action_payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    status text DEFAULT 'pending'::text,
    decided_by text,
    decided_at timestamp with time zone,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT interventions_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text, 'auto_executed'::text, 'expired'::text])))
);


--
-- Name: properties; Type: TABLE; Schema: biz_003; Owner: -
--

CREATE TABLE biz_003.properties (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_003'::text NOT NULL,
    property_name text NOT NULL,
    property_type text NOT NULL,
    location text,
    city text,
    area_sqft numeric(10,2),
    listed_price numeric(14,2),
    status text DEFAULT 'available'::text,
    owner_entity_id uuid,
    buyer_entity_id uuid,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT properties_property_type_check CHECK ((property_type = ANY (ARRAY['residential_plot'::text, 'commercial_plot'::text, 'apartment'::text, 'villa'::text, 'commercial_building'::text, 'other'::text]))),
    CONSTRAINT properties_status_check CHECK ((status = ANY (ARRAY['available'::text, 'reserved'::text, 'sold'::text, 'rented'::text, 'under_construction'::text])))
);


--
-- Name: transactions; Type: TABLE; Schema: biz_003; Owner: -
--

CREATE TABLE biz_003.transactions (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_003'::text NOT NULL,
    entity_id uuid,
    transaction_type text NOT NULL,
    amount numeric(12,2) NOT NULL,
    currency text DEFAULT 'INR'::text,
    date date NOT NULL,
    description text,
    payment_method text,
    reference_number text,
    status text DEFAULT 'completed'::text,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT transactions_amount_check CHECK ((amount > (0)::numeric)),
    CONSTRAINT transactions_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'completed'::text, 'failed'::text, 'reversed'::text]))),
    CONSTRAINT transactions_transaction_type_check CHECK ((transaction_type = ANY (ARRAY['sale_payment'::text, 'rent_received'::text, 'contractor_payment'::text, 'refund'::text, 'expense'::text, 'other'::text])))
);


--
-- Name: agent_signals; Type: TABLE; Schema: biz_004; Owner: -
--

CREATE TABLE biz_004.agent_signals (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_004'::text NOT NULL,
    agent_name text NOT NULL,
    signal_type text NOT NULL,
    severity text DEFAULT 'info'::text,
    entity_id uuid,
    title text NOT NULL,
    description text,
    data jsonb DEFAULT '{}'::jsonb,
    status text DEFAULT 'active'::text,
    resolved_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT agent_signals_severity_check CHECK ((severity = ANY (ARRAY['info'::text, 'low'::text, 'medium'::text, 'high'::text, 'critical'::text]))),
    CONSTRAINT agent_signals_status_check CHECK ((status = ANY (ARRAY['active'::text, 'acknowledged'::text, 'resolved'::text, 'dismissed'::text])))
);


--
-- Name: agent_signals_archive; Type: TABLE; Schema: biz_004; Owner: -
--

CREATE TABLE biz_004.agent_signals_archive (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_004'::text NOT NULL,
    agent_name text NOT NULL,
    signal_type text NOT NULL,
    severity text DEFAULT 'info'::text,
    entity_id uuid,
    title text NOT NULL,
    description text,
    data jsonb DEFAULT '{}'::jsonb,
    status text DEFAULT 'active'::text,
    resolved_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT agent_signals_severity_check CHECK ((severity = ANY (ARRAY['info'::text, 'low'::text, 'medium'::text, 'high'::text, 'critical'::text]))),
    CONSTRAINT agent_signals_status_check CHECK ((status = ANY (ARRAY['active'::text, 'acknowledged'::text, 'resolved'::text, 'dismissed'::text])))
);


--
-- Name: agent_signals_all; Type: VIEW; Schema: biz_004; Owner: -
--

CREATE VIEW biz_004.agent_signals_all AS
 SELECT agent_signals.id,
    agent_signals.business_id,
    agent_signals.agent_name,
    agent_signals.signal_type,
    agent_signals.severity,
    agent_signals.entity_id,
    agent_signals.title,
    agent_signals.description,
    agent_signals.data,
    agent_signals.status,
    agent_signals.resolved_at,
    agent_signals.created_at,
    agent_signals.updated_at
   FROM biz_004.agent_signals
UNION ALL
 SELECT agent_signals_archive.id,
    agent_signals_archive.business_id,
    agent_signals_archive.agent_name,
    agent_signals_archive.signal_type,
    agent_signals_archive.severity,
    agent_signals_archive.entity_id,
    agent_signals_archive.title,
    agent_signals_archive.description,
    agent_signals_archive.data,
    agent_signals_archive.status,
    agent_signals_archive.resolved_at,
    agent_signals_archive.created_at,
    agent_signals_archive.updated_at
   FROM biz_004.agent_signals_archive;


--
-- Name: audit_log; Type: TABLE; Schema: biz_004; Owner: -
--

CREATE TABLE biz_004.audit_log (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_004'::text NOT NULL,
    table_name text NOT NULL,
    row_id uuid NOT NULL,
    action text NOT NULL,
    old_data jsonb,
    new_data jsonb,
    changed_by text DEFAULT CURRENT_USER,
    changed_at timestamp with time zone DEFAULT now(),
    CONSTRAINT audit_log_action_check CHECK ((action = ANY (ARRAY['INSERT'::text, 'UPDATE'::text, 'DELETE'::text])))
);


--
-- Name: documents; Type: TABLE; Schema: biz_004; Owner: -
--

CREATE TABLE biz_004.documents (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_004'::text NOT NULL,
    entity_id uuid,
    document_type text NOT NULL,
    title text NOT NULL,
    file_url text,
    file_size_bytes bigint,
    mime_type text,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: entities; Type: TABLE; Schema: biz_004; Owner: -
--

CREATE TABLE biz_004.entities (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_004'::text NOT NULL,
    entity_type text NOT NULL,
    first_name text NOT NULL,
    last_name text,
    phone text,
    email text,
    whatsapp text,
    address text,
    status text DEFAULT 'active'::text NOT NULL,
    tags text[],
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT entities_entity_type_check CHECK ((entity_type = ANY (ARRAY['client'::text, 'vendor'::text, 'staff'::text, 'contact'::text]))),
    CONSTRAINT entities_status_check CHECK ((status = ANY (ARRAY['active'::text, 'inactive'::text, 'archived'::text])))
);


--
-- Name: events; Type: TABLE; Schema: biz_004; Owner: -
--

CREATE TABLE biz_004.events (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_004'::text NOT NULL,
    entity_id uuid,
    event_type text NOT NULL,
    event_date date NOT NULL,
    title text,
    description text,
    data jsonb DEFAULT '{}'::jsonb,
    status text DEFAULT 'recorded'::text,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT events_status_check CHECK ((status = ANY (ARRAY['scheduled'::text, 'recorded'::text, 'cancelled'::text])))
);


--
-- Name: interventions; Type: TABLE; Schema: biz_004; Owner: -
--

CREATE TABLE biz_004.interventions (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_004'::text NOT NULL,
    agent_name text NOT NULL,
    signal_id uuid,
    action_type text NOT NULL,
    action_payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    status text DEFAULT 'pending'::text,
    decided_by text,
    decided_at timestamp with time zone,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT interventions_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text, 'auto_executed'::text, 'expired'::text])))
);


--
-- Name: print_job_profiles; Type: TABLE; Schema: biz_004; Owner: -
--

CREATE TABLE biz_004.print_job_profiles (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_004'::text NOT NULL,
    client_id uuid NOT NULL,
    job_name text NOT NULL,
    job_type text NOT NULL,
    quantity integer,
    paper_type text,
    size text,
    color_type text,
    quoted_amount numeric(10,2),
    final_amount numeric(10,2),
    due_date date,
    status text DEFAULT 'received'::text,
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT print_job_profiles_color_type_check CHECK ((color_type = ANY (ARRAY['single_color'::text, 'multi_color'::text, 'full_color'::text]))),
    CONSTRAINT print_job_profiles_final_amount_check CHECK ((final_amount > (0)::numeric)),
    CONSTRAINT print_job_profiles_job_type_check CHECK ((job_type = ANY (ARRAY['wedding_cards'::text, 'business_cards'::text, 'banners'::text, 'books'::text, 'pamphlets'::text, 'letterheads'::text, 'bills'::text, 'posters'::text, 'other'::text]))),
    CONSTRAINT print_job_profiles_quantity_check CHECK ((quantity > 0)),
    CONSTRAINT print_job_profiles_quoted_amount_check CHECK ((quoted_amount > (0)::numeric)),
    CONSTRAINT print_job_profiles_status_check CHECK ((status = ANY (ARRAY['received'::text, 'in_progress'::text, 'printing'::text, 'completed'::text, 'delivered'::text, 'cancelled'::text])))
);


--
-- Name: transactions; Type: TABLE; Schema: biz_004; Owner: -
--

CREATE TABLE biz_004.transactions (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    business_id text DEFAULT 'biz_004'::text NOT NULL,
    entity_id uuid,
    transaction_type text NOT NULL,
    amount numeric(12,2) NOT NULL,
    currency text DEFAULT 'INR'::text,
    date date NOT NULL,
    description text,
    payment_method text,
    reference_number text,
    status text DEFAULT 'completed'::text,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT transactions_amount_check CHECK ((amount > (0)::numeric)),
    CONSTRAINT transactions_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'completed'::text, 'failed'::text, 'reversed'::text]))),
    CONSTRAINT transactions_transaction_type_check CHECK ((transaction_type = ANY (ARRAY['payment_received'::text, 'payment_made'::text, 'advance'::text, 'refund'::text, 'expense'::text, 'other'::text])))
);


--
-- Name: benchmarks benchmarks_pkey; Type: CONSTRAINT; Schema: ae_intelligence; Owner: -
--

ALTER TABLE ONLY ae_intelligence.benchmarks
    ADD CONSTRAINT benchmarks_pkey PRIMARY KEY (id);


--
-- Name: cross_signal_patterns cross_signal_patterns_pkey; Type: CONSTRAINT; Schema: ae_intelligence; Owner: -
--

ALTER TABLE ONLY ae_intelligence.cross_signal_patterns
    ADD CONSTRAINT cross_signal_patterns_pkey PRIMARY KEY (id);


--
-- Name: health_score_inputs health_score_inputs_pkey; Type: CONSTRAINT; Schema: ae_intelligence; Owner: -
--

ALTER TABLE ONLY ae_intelligence.health_score_inputs
    ADD CONSTRAINT health_score_inputs_pkey PRIMARY KEY (id);


--
-- Name: signal_aggregates signal_aggregates_pkey; Type: CONSTRAINT; Schema: ae_intelligence; Owner: -
--

ALTER TABLE ONLY ae_intelligence.signal_aggregates
    ADD CONSTRAINT signal_aggregates_pkey PRIMARY KEY (id);


--
-- Name: businesses businesses_business_id_key; Type: CONSTRAINT; Schema: ae_platform; Owner: -
--

ALTER TABLE ONLY ae_platform.businesses
    ADD CONSTRAINT businesses_business_id_key UNIQUE (business_id);


--
-- Name: businesses businesses_pkey; Type: CONSTRAINT; Schema: ae_platform; Owner: -
--

ALTER TABLE ONLY ae_platform.businesses
    ADD CONSTRAINT businesses_pkey PRIMARY KEY (id);


--
-- Name: ca_firm_clients ca_firm_clients_ca_firm_id_business_id_key; Type: CONSTRAINT; Schema: ae_platform; Owner: -
--

ALTER TABLE ONLY ae_platform.ca_firm_clients
    ADD CONSTRAINT ca_firm_clients_ca_firm_id_business_id_key UNIQUE (ca_firm_id, business_id);


--
-- Name: ca_firm_clients ca_firm_clients_pkey; Type: CONSTRAINT; Schema: ae_platform; Owner: -
--

ALTER TABLE ONLY ae_platform.ca_firm_clients
    ADD CONSTRAINT ca_firm_clients_pkey PRIMARY KEY (id);


--
-- Name: ca_firms ca_firms_pkey; Type: CONSTRAINT; Schema: ae_platform; Owner: -
--

ALTER TABLE ONLY ae_platform.ca_firms
    ADD CONSTRAINT ca_firms_pkey PRIMARY KEY (id);


--
-- Name: consents consents_pkey; Type: CONSTRAINT; Schema: ae_platform; Owner: -
--

ALTER TABLE ONLY ae_platform.consents
    ADD CONSTRAINT consents_pkey PRIMARY KEY (id);


--
-- Name: user_roles user_roles_auth_user_id_business_id_key; Type: CONSTRAINT; Schema: ae_platform; Owner: -
--

ALTER TABLE ONLY ae_platform.user_roles
    ADD CONSTRAINT user_roles_auth_user_id_business_id_key UNIQUE (auth_user_id, business_id);


--
-- Name: user_roles user_roles_pkey; Type: CONSTRAINT; Schema: ae_platform; Owner: -
--

ALTER TABLE ONLY ae_platform.user_roles
    ADD CONSTRAINT user_roles_pkey PRIMARY KEY (user_role_id);


--
-- Name: academic_calendar academic_calendar_pkey; Type: CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.academic_calendar
    ADD CONSTRAINT academic_calendar_pkey PRIMARY KEY (calendar_id);


--
-- Name: agent_signals_archive agent_signals_archive_pkey; Type: CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.agent_signals_archive
    ADD CONSTRAINT agent_signals_archive_pkey PRIMARY KEY (id);


--
-- Name: agent_signals agent_signals_pkey; Type: CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.agent_signals
    ADD CONSTRAINT agent_signals_pkey PRIMARY KEY (id);


--
-- Name: attendance attendance_pkey; Type: CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.attendance
    ADD CONSTRAINT attendance_pkey PRIMARY KEY (attendance_id);


--
-- Name: attendance attendance_student_date_period_key; Type: CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.attendance
    ADD CONSTRAINT attendance_student_date_period_key UNIQUE (student_id, date, period_number);


--
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (id);


--
-- Name: documents documents_pkey; Type: CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.documents
    ADD CONSTRAINT documents_pkey PRIMARY KEY (id);


--
-- Name: entities entities_pkey; Type: CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.entities
    ADD CONSTRAINT entities_pkey PRIMARY KEY (id);


--
-- Name: events events_pkey; Type: CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.events
    ADD CONSTRAINT events_pkey PRIMARY KEY (id);


--
-- Name: fee_payments fee_payments_pkey; Type: CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.fee_payments
    ADD CONSTRAINT fee_payments_pkey PRIMARY KEY (payment_id);


--
-- Name: fee_structure fee_structure_class_fee_type_academic_year_key; Type: CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.fee_structure
    ADD CONSTRAINT fee_structure_class_fee_type_academic_year_key UNIQUE (class, fee_type, academic_year);


--
-- Name: fee_structure fee_structure_pkey; Type: CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.fee_structure
    ADD CONSTRAINT fee_structure_pkey PRIMARY KEY (fee_structure_id);


--
-- Name: homework homework_pkey; Type: CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.homework
    ADD CONSTRAINT homework_pkey PRIMARY KEY (homework_id);


--
-- Name: homework_submissions homework_submissions_homework_id_student_id_key; Type: CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.homework_submissions
    ADD CONSTRAINT homework_submissions_homework_id_student_id_key UNIQUE (homework_id, student_id);


--
-- Name: homework_submissions homework_submissions_pkey; Type: CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.homework_submissions
    ADD CONSTRAINT homework_submissions_pkey PRIMARY KEY (submission_id);


--
-- Name: house_points house_points_pkey; Type: CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.house_points
    ADD CONSTRAINT house_points_pkey PRIMARY KEY (point_id);


--
-- Name: interventions interventions_pkey; Type: CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.interventions
    ADD CONSTRAINT interventions_pkey PRIMARY KEY (id);


--
-- Name: marks marks_pkey; Type: CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.marks
    ADD CONSTRAINT marks_pkey PRIMARY KEY (mark_id);


--
-- Name: marks marks_student_id_subject_id_exam_type_exam_date_key; Type: CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.marks
    ADD CONSTRAINT marks_student_id_subject_id_exam_type_exam_date_key UNIQUE (student_id, subject_id, exam_type, exam_date);


--
-- Name: marks marks_unique_per_student_per_exam; Type: CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.marks
    ADD CONSTRAINT marks_unique_per_student_per_exam UNIQUE (business_id, student_id, subject_id, exam_type, exam_date);


--
-- Name: performance_observations performance_observations_pkey; Type: CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.performance_observations
    ADD CONSTRAINT performance_observations_pkey PRIMARY KEY (observation_id);


--
-- Name: performance_observations performance_observations_student_id_subject_id_observation__key; Type: CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.performance_observations
    ADD CONSTRAINT performance_observations_student_id_subject_id_observation__key UNIQUE (student_id, subject_id, observation_date);


--
-- Name: student_profiles student_profiles_entity_id_key; Type: CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.student_profiles
    ADD CONSTRAINT student_profiles_entity_id_key UNIQUE (entity_id);


--
-- Name: student_profiles student_profiles_pkey; Type: CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.student_profiles
    ADD CONSTRAINT student_profiles_pkey PRIMARY KEY (id);


--
-- Name: student_transport student_transport_pkey; Type: CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.student_transport
    ADD CONSTRAINT student_transport_pkey PRIMARY KEY (student_transport_id);


--
-- Name: student_transport student_transport_student_id_academic_year_key; Type: CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.student_transport
    ADD CONSTRAINT student_transport_student_id_academic_year_key UNIQUE (student_id, academic_year);


--
-- Name: subjects subjects_business_class_year_name_key; Type: CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.subjects
    ADD CONSTRAINT subjects_business_class_year_name_key UNIQUE (business_id, class, academic_year, subject_name);


--
-- Name: subjects subjects_pkey; Type: CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.subjects
    ADD CONSTRAINT subjects_pkey PRIMARY KEY (subject_id);


--
-- Name: teacher_assignments teacher_assignments_pkey; Type: CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.teacher_assignments
    ADD CONSTRAINT teacher_assignments_pkey PRIMARY KEY (assignment_id);


--
-- Name: teacher_profiles teacher_profiles_pkey; Type: CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.teacher_profiles
    ADD CONSTRAINT teacher_profiles_pkey PRIMARY KEY (id);


--
-- Name: teacher_subjects teacher_subjects_pkey; Type: CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.teacher_subjects
    ADD CONSTRAINT teacher_subjects_pkey PRIMARY KEY (teacher_subject_id);


--
-- Name: transactions transactions_pkey; Type: CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.transactions
    ADD CONSTRAINT transactions_pkey PRIMARY KEY (id);


--
-- Name: transport_routes transport_routes_pkey; Type: CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.transport_routes
    ADD CONSTRAINT transport_routes_pkey PRIMARY KEY (route_id);


--
-- Name: transport_routes transport_routes_route_code_academic_year_key; Type: CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.transport_routes
    ADD CONSTRAINT transport_routes_route_code_academic_year_key UNIQUE (route_code, academic_year);


--
-- Name: transport_stops transport_stops_pkey; Type: CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.transport_stops
    ADD CONSTRAINT transport_stops_pkey PRIMARY KEY (stop_id);


--
-- Name: transport_stops transport_stops_route_id_stop_order_key; Type: CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.transport_stops
    ADD CONSTRAINT transport_stops_route_id_stop_order_key UNIQUE (route_id, stop_order);


--
-- Name: agent_signals_archive agent_signals_archive_pkey; Type: CONSTRAINT; Schema: biz_002; Owner: -
--

ALTER TABLE ONLY biz_002.agent_signals_archive
    ADD CONSTRAINT agent_signals_archive_pkey PRIMARY KEY (id);


--
-- Name: agent_signals agent_signals_pkey; Type: CONSTRAINT; Schema: biz_002; Owner: -
--

ALTER TABLE ONLY biz_002.agent_signals
    ADD CONSTRAINT agent_signals_pkey PRIMARY KEY (id);


--
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: biz_002; Owner: -
--

ALTER TABLE ONLY biz_002.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (id);


--
-- Name: catering_orders catering_orders_pkey; Type: CONSTRAINT; Schema: biz_002; Owner: -
--

ALTER TABLE ONLY biz_002.catering_orders
    ADD CONSTRAINT catering_orders_pkey PRIMARY KEY (id);


--
-- Name: documents documents_pkey; Type: CONSTRAINT; Schema: biz_002; Owner: -
--

ALTER TABLE ONLY biz_002.documents
    ADD CONSTRAINT documents_pkey PRIMARY KEY (id);


--
-- Name: entities entities_pkey; Type: CONSTRAINT; Schema: biz_002; Owner: -
--

ALTER TABLE ONLY biz_002.entities
    ADD CONSTRAINT entities_pkey PRIMARY KEY (id);


--
-- Name: event_expenses event_expenses_pkey; Type: CONSTRAINT; Schema: biz_002; Owner: -
--

ALTER TABLE ONLY biz_002.event_expenses
    ADD CONSTRAINT event_expenses_pkey PRIMARY KEY (id);


--
-- Name: event_staff event_staff_order_id_staff_id_key; Type: CONSTRAINT; Schema: biz_002; Owner: -
--

ALTER TABLE ONLY biz_002.event_staff
    ADD CONSTRAINT event_staff_order_id_staff_id_key UNIQUE (order_id, staff_id);


--
-- Name: event_staff event_staff_pkey; Type: CONSTRAINT; Schema: biz_002; Owner: -
--

ALTER TABLE ONLY biz_002.event_staff
    ADD CONSTRAINT event_staff_pkey PRIMARY KEY (id);


--
-- Name: events events_pkey; Type: CONSTRAINT; Schema: biz_002; Owner: -
--

ALTER TABLE ONLY biz_002.events
    ADD CONSTRAINT events_pkey PRIMARY KEY (id);


--
-- Name: interventions interventions_pkey; Type: CONSTRAINT; Schema: biz_002; Owner: -
--

ALTER TABLE ONLY biz_002.interventions
    ADD CONSTRAINT interventions_pkey PRIMARY KEY (id);


--
-- Name: quotes quotes_pkey; Type: CONSTRAINT; Schema: biz_002; Owner: -
--

ALTER TABLE ONLY biz_002.quotes
    ADD CONSTRAINT quotes_pkey PRIMARY KEY (id);


--
-- Name: transactions transactions_pkey; Type: CONSTRAINT; Schema: biz_002; Owner: -
--

ALTER TABLE ONLY biz_002.transactions
    ADD CONSTRAINT transactions_pkey PRIMARY KEY (id);


--
-- Name: agent_signals_archive agent_signals_archive_pkey; Type: CONSTRAINT; Schema: biz_003; Owner: -
--

ALTER TABLE ONLY biz_003.agent_signals_archive
    ADD CONSTRAINT agent_signals_archive_pkey PRIMARY KEY (id);


--
-- Name: agent_signals agent_signals_pkey; Type: CONSTRAINT; Schema: biz_003; Owner: -
--

ALTER TABLE ONLY biz_003.agent_signals
    ADD CONSTRAINT agent_signals_pkey PRIMARY KEY (id);


--
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: biz_003; Owner: -
--

ALTER TABLE ONLY biz_003.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (id);


--
-- Name: documents documents_pkey; Type: CONSTRAINT; Schema: biz_003; Owner: -
--

ALTER TABLE ONLY biz_003.documents
    ADD CONSTRAINT documents_pkey PRIMARY KEY (id);


--
-- Name: entities entities_pkey; Type: CONSTRAINT; Schema: biz_003; Owner: -
--

ALTER TABLE ONLY biz_003.entities
    ADD CONSTRAINT entities_pkey PRIMARY KEY (id);


--
-- Name: events events_pkey; Type: CONSTRAINT; Schema: biz_003; Owner: -
--

ALTER TABLE ONLY biz_003.events
    ADD CONSTRAINT events_pkey PRIMARY KEY (id);


--
-- Name: interventions interventions_pkey; Type: CONSTRAINT; Schema: biz_003; Owner: -
--

ALTER TABLE ONLY biz_003.interventions
    ADD CONSTRAINT interventions_pkey PRIMARY KEY (id);


--
-- Name: properties properties_pkey; Type: CONSTRAINT; Schema: biz_003; Owner: -
--

ALTER TABLE ONLY biz_003.properties
    ADD CONSTRAINT properties_pkey PRIMARY KEY (id);


--
-- Name: transactions transactions_pkey; Type: CONSTRAINT; Schema: biz_003; Owner: -
--

ALTER TABLE ONLY biz_003.transactions
    ADD CONSTRAINT transactions_pkey PRIMARY KEY (id);


--
-- Name: agent_signals_archive agent_signals_archive_pkey; Type: CONSTRAINT; Schema: biz_004; Owner: -
--

ALTER TABLE ONLY biz_004.agent_signals_archive
    ADD CONSTRAINT agent_signals_archive_pkey PRIMARY KEY (id);


--
-- Name: agent_signals agent_signals_pkey; Type: CONSTRAINT; Schema: biz_004; Owner: -
--

ALTER TABLE ONLY biz_004.agent_signals
    ADD CONSTRAINT agent_signals_pkey PRIMARY KEY (id);


--
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: biz_004; Owner: -
--

ALTER TABLE ONLY biz_004.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (id);


--
-- Name: documents documents_pkey; Type: CONSTRAINT; Schema: biz_004; Owner: -
--

ALTER TABLE ONLY biz_004.documents
    ADD CONSTRAINT documents_pkey PRIMARY KEY (id);


--
-- Name: entities entities_pkey; Type: CONSTRAINT; Schema: biz_004; Owner: -
--

ALTER TABLE ONLY biz_004.entities
    ADD CONSTRAINT entities_pkey PRIMARY KEY (id);


--
-- Name: events events_pkey; Type: CONSTRAINT; Schema: biz_004; Owner: -
--

ALTER TABLE ONLY biz_004.events
    ADD CONSTRAINT events_pkey PRIMARY KEY (id);


--
-- Name: interventions interventions_pkey; Type: CONSTRAINT; Schema: biz_004; Owner: -
--

ALTER TABLE ONLY biz_004.interventions
    ADD CONSTRAINT interventions_pkey PRIMARY KEY (id);


--
-- Name: print_job_profiles print_job_profiles_pkey; Type: CONSTRAINT; Schema: biz_004; Owner: -
--

ALTER TABLE ONLY biz_004.print_job_profiles
    ADD CONSTRAINT print_job_profiles_pkey PRIMARY KEY (id);


--
-- Name: transactions transactions_pkey; Type: CONSTRAINT; Schema: biz_004; Owner: -
--

ALTER TABLE ONLY biz_004.transactions
    ADD CONSTRAINT transactions_pkey PRIMARY KEY (id);


--
-- Name: idx_intel_benchmarks_metric; Type: INDEX; Schema: ae_intelligence; Owner: -
--

CREATE INDEX idx_intel_benchmarks_metric ON ae_intelligence.benchmarks USING btree (metric_name);


--
-- Name: idx_intel_benchmarks_vertical; Type: INDEX; Schema: ae_intelligence; Owner: -
--

CREATE INDEX idx_intel_benchmarks_vertical ON ae_intelligence.benchmarks USING btree (vertical);


--
-- Name: idx_intel_health_dimension; Type: INDEX; Schema: ae_intelligence; Owner: -
--

CREATE INDEX idx_intel_health_dimension ON ae_intelligence.health_score_inputs USING btree (dimension);


--
-- Name: idx_intel_health_intid; Type: INDEX; Schema: ae_intelligence; Owner: -
--

CREATE INDEX idx_intel_health_intid ON ae_intelligence.health_score_inputs USING btree (intelligence_id);


--
-- Name: idx_intel_health_vertical; Type: INDEX; Schema: ae_intelligence; Owner: -
--

CREATE INDEX idx_intel_health_vertical ON ae_intelligence.health_score_inputs USING btree (vertical);


--
-- Name: idx_intel_patterns_vertical; Type: INDEX; Schema: ae_intelligence; Owner: -
--

CREATE INDEX idx_intel_patterns_vertical ON ae_intelligence.cross_signal_patterns USING btree (vertical);


--
-- Name: idx_signal_aggregates_business_id; Type: INDEX; Schema: ae_intelligence; Owner: -
--

CREATE INDEX idx_signal_aggregates_business_id ON ae_intelligence.signal_aggregates USING btree (business_id);


--
-- Name: idx_signal_aggregates_signal_type; Type: INDEX; Schema: ae_intelligence; Owner: -
--

CREATE INDEX idx_signal_aggregates_signal_type ON ae_intelligence.signal_aggregates USING btree (signal_type);


--
-- Name: idx_businesses_business_id; Type: INDEX; Schema: ae_platform; Owner: -
--

CREATE INDEX idx_businesses_business_id ON ae_platform.businesses USING btree (business_id);


--
-- Name: idx_businesses_intelligence_id; Type: INDEX; Schema: ae_platform; Owner: -
--

CREATE INDEX idx_businesses_intelligence_id ON ae_platform.businesses USING btree (intelligence_id);


--
-- Name: idx_businesses_vertical; Type: INDEX; Schema: ae_platform; Owner: -
--

CREATE INDEX idx_businesses_vertical ON ae_platform.businesses USING btree (vertical);


--
-- Name: idx_consents_business_id; Type: INDEX; Schema: ae_platform; Owner: -
--

CREATE INDEX idx_consents_business_id ON ae_platform.consents USING btree (business_id);


--
-- Name: idx_user_roles_auth_user_id; Type: INDEX; Schema: ae_platform; Owner: -
--

CREATE INDEX idx_user_roles_auth_user_id ON ae_platform.user_roles USING btree (auth_user_id);


--
-- Name: idx_user_roles_business_id; Type: INDEX; Schema: ae_platform; Owner: -
--

CREATE INDEX idx_user_roles_business_id ON ae_platform.user_roles USING btree (business_id);


--
-- Name: idx_001_audit_row; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_001_audit_row ON biz_001.audit_log USING btree (row_id);


--
-- Name: idx_001_audit_table; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_001_audit_table ON biz_001.audit_log USING btree (table_name);


--
-- Name: idx_001_audit_time; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_001_audit_time ON biz_001.audit_log USING btree (changed_at);


--
-- Name: idx_001_entities_status; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_001_entities_status ON biz_001.entities USING btree (status);


--
-- Name: idx_001_entities_type; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_001_entities_type ON biz_001.entities USING btree (entity_type);


--
-- Name: idx_001_events_date; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_001_events_date ON biz_001.events USING btree (event_date);


--
-- Name: idx_001_events_entity; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_001_events_entity ON biz_001.events USING btree (entity_id);


--
-- Name: idx_001_events_type; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_001_events_type ON biz_001.events USING btree (event_type);


--
-- Name: idx_001_signals_agent; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_001_signals_agent ON biz_001.agent_signals USING btree (agent_name);


--
-- Name: idx_001_signals_status; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_001_signals_status ON biz_001.agent_signals USING btree (status);


--
-- Name: idx_001_student_class; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_001_student_class ON biz_001.student_profiles USING btree (class, section);


--
-- Name: idx_001_student_entity; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_001_student_entity ON biz_001.student_profiles USING btree (entity_id);


--
-- Name: idx_001_transactions_date; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_001_transactions_date ON biz_001.transactions USING btree (date);


--
-- Name: idx_001_transactions_entity; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_001_transactions_entity ON biz_001.transactions USING btree (entity_id);


--
-- Name: idx_001_transactions_type; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_001_transactions_type ON biz_001.transactions USING btree (transaction_type);


--
-- Name: idx_academic_calendar_dates; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_academic_calendar_dates ON biz_001.academic_calendar USING btree (start_date, end_date);


--
-- Name: idx_academic_calendar_event_type; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_academic_calendar_event_type ON biz_001.academic_calendar USING btree (event_type);


--
-- Name: idx_attendance_class_section_date; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_attendance_class_section_date ON biz_001.attendance USING btree (class, section, date);


--
-- Name: idx_attendance_date; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_attendance_date ON biz_001.attendance USING btree (date);


--
-- Name: idx_attendance_status; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_attendance_status ON biz_001.attendance USING btree (status);


--
-- Name: idx_attendance_student_id; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_attendance_student_id ON biz_001.attendance USING btree (student_id);


--
-- Name: idx_fee_payments_academic_year; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_fee_payments_academic_year ON biz_001.fee_payments USING btree (academic_year);


--
-- Name: idx_fee_payments_date; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_fee_payments_date ON biz_001.fee_payments USING btree (payment_date);


--
-- Name: idx_fee_payments_student_id; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_fee_payments_student_id ON biz_001.fee_payments USING btree (student_id);


--
-- Name: idx_fee_structure_class; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_fee_structure_class ON biz_001.fee_structure USING btree (class, academic_year);


--
-- Name: idx_homework_class_section; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_homework_class_section ON biz_001.homework USING btree (class, section);


--
-- Name: idx_homework_due_date; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_homework_due_date ON biz_001.homework USING btree (due_date);


--
-- Name: idx_homework_subject_id; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_homework_subject_id ON biz_001.homework USING btree (subject_id);


--
-- Name: idx_house_points_academic_year; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_house_points_academic_year ON biz_001.house_points USING btree (academic_year);


--
-- Name: idx_house_points_house_name; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_house_points_house_name ON biz_001.house_points USING btree (house_name);


--
-- Name: idx_house_points_student_id; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_house_points_student_id ON biz_001.house_points USING btree (awarded_to_student_id);


--
-- Name: idx_hw_submissions_homework_id; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_hw_submissions_homework_id ON biz_001.homework_submissions USING btree (homework_id);


--
-- Name: idx_hw_submissions_status; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_hw_submissions_status ON biz_001.homework_submissions USING btree (status);


--
-- Name: idx_hw_submissions_student_id; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_hw_submissions_student_id ON biz_001.homework_submissions USING btree (student_id);


--
-- Name: idx_marks_class_section; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_marks_class_section ON biz_001.marks USING btree (class, section);


--
-- Name: idx_marks_exam_type; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_marks_exam_type ON biz_001.marks USING btree (exam_type);


--
-- Name: idx_marks_student_id; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_marks_student_id ON biz_001.marks USING btree (student_id);


--
-- Name: idx_marks_subject_id; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_marks_subject_id ON biz_001.marks USING btree (subject_id);


--
-- Name: idx_performance_date; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_performance_date ON biz_001.performance_observations USING btree (observation_date);


--
-- Name: idx_performance_student_id; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_performance_student_id ON biz_001.performance_observations USING btree (student_id);


--
-- Name: idx_student_transport_route_id; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_student_transport_route_id ON biz_001.student_transport USING btree (route_id);


--
-- Name: idx_student_transport_student_id; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_student_transport_student_id ON biz_001.student_transport USING btree (student_id);


--
-- Name: idx_subjects_class; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_subjects_class ON biz_001.subjects USING btree (class);


--
-- Name: idx_teacher_assignments_auth_user_id; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_teacher_assignments_auth_user_id ON biz_001.teacher_assignments USING btree (auth_user_id);


--
-- Name: idx_teacher_assignments_class_section; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_teacher_assignments_class_section ON biz_001.teacher_assignments USING btree (class, section);


--
-- Name: idx_teacher_assignments_teacher_id; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_teacher_assignments_teacher_id ON biz_001.teacher_assignments USING btree (teacher_id);


--
-- Name: idx_teacher_profiles_entity_id; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_teacher_profiles_entity_id ON biz_001.teacher_profiles USING btree (entity_id);


--
-- Name: idx_teacher_subjects_subject_id; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_teacher_subjects_subject_id ON biz_001.teacher_subjects USING btree (subject_id);


--
-- Name: idx_teacher_subjects_teacher_id; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_teacher_subjects_teacher_id ON biz_001.teacher_subjects USING btree (teacher_id);


--
-- Name: idx_transport_stops_route_id; Type: INDEX; Schema: biz_001; Owner: -
--

CREATE INDEX idx_transport_stops_route_id ON biz_001.transport_stops USING btree (route_id);


--
-- Name: idx_002_audit_row; Type: INDEX; Schema: biz_002; Owner: -
--

CREATE INDEX idx_002_audit_row ON biz_002.audit_log USING btree (row_id);


--
-- Name: idx_002_audit_table; Type: INDEX; Schema: biz_002; Owner: -
--

CREATE INDEX idx_002_audit_table ON biz_002.audit_log USING btree (table_name);


--
-- Name: idx_002_audit_time; Type: INDEX; Schema: biz_002; Owner: -
--

CREATE INDEX idx_002_audit_time ON biz_002.audit_log USING btree (changed_at);


--
-- Name: idx_002_entities_city; Type: INDEX; Schema: biz_002; Owner: -
--

CREATE INDEX idx_002_entities_city ON biz_002.entities USING btree (city);


--
-- Name: idx_002_entities_status; Type: INDEX; Schema: biz_002; Owner: -
--

CREATE INDEX idx_002_entities_status ON biz_002.entities USING btree (status);


--
-- Name: idx_002_entities_type; Type: INDEX; Schema: biz_002; Owner: -
--

CREATE INDEX idx_002_entities_type ON biz_002.entities USING btree (entity_type);


--
-- Name: idx_002_events_date; Type: INDEX; Schema: biz_002; Owner: -
--

CREATE INDEX idx_002_events_date ON biz_002.events USING btree (event_date);


--
-- Name: idx_002_events_entity; Type: INDEX; Schema: biz_002; Owner: -
--

CREATE INDEX idx_002_events_entity ON biz_002.events USING btree (entity_id);


--
-- Name: idx_002_expenses_category; Type: INDEX; Schema: biz_002; Owner: -
--

CREATE INDEX idx_002_expenses_category ON biz_002.event_expenses USING btree (category);


--
-- Name: idx_002_expenses_date; Type: INDEX; Schema: biz_002; Owner: -
--

CREATE INDEX idx_002_expenses_date ON biz_002.event_expenses USING btree (date);


--
-- Name: idx_002_expenses_order; Type: INDEX; Schema: biz_002; Owner: -
--

CREATE INDEX idx_002_expenses_order ON biz_002.event_expenses USING btree (order_id);


--
-- Name: idx_002_expenses_vendor; Type: INDEX; Schema: biz_002; Owner: -
--

CREATE INDEX idx_002_expenses_vendor ON biz_002.event_expenses USING btree (vendor_id);


--
-- Name: idx_002_orders_city; Type: INDEX; Schema: biz_002; Owner: -
--

CREATE INDEX idx_002_orders_city ON biz_002.catering_orders USING btree (city);


--
-- Name: idx_002_orders_client; Type: INDEX; Schema: biz_002; Owner: -
--

CREATE INDEX idx_002_orders_client ON biz_002.catering_orders USING btree (client_id);


--
-- Name: idx_002_orders_date; Type: INDEX; Schema: biz_002; Owner: -
--

CREATE INDEX idx_002_orders_date ON biz_002.catering_orders USING btree (event_date);


--
-- Name: idx_002_orders_status; Type: INDEX; Schema: biz_002; Owner: -
--

CREATE INDEX idx_002_orders_status ON biz_002.catering_orders USING btree (status);


--
-- Name: idx_002_orders_type; Type: INDEX; Schema: biz_002; Owner: -
--

CREATE INDEX idx_002_orders_type ON biz_002.catering_orders USING btree (event_type);


--
-- Name: idx_002_quotes_client; Type: INDEX; Schema: biz_002; Owner: -
--

CREATE INDEX idx_002_quotes_client ON biz_002.quotes USING btree (client_id);


--
-- Name: idx_002_quotes_order; Type: INDEX; Schema: biz_002; Owner: -
--

CREATE INDEX idx_002_quotes_order ON biz_002.quotes USING btree (order_id);


--
-- Name: idx_002_quotes_status; Type: INDEX; Schema: biz_002; Owner: -
--

CREATE INDEX idx_002_quotes_status ON biz_002.quotes USING btree (status);


--
-- Name: idx_002_signals_agent; Type: INDEX; Schema: biz_002; Owner: -
--

CREATE INDEX idx_002_signals_agent ON biz_002.agent_signals USING btree (agent_name);


--
-- Name: idx_002_signals_order; Type: INDEX; Schema: biz_002; Owner: -
--

CREATE INDEX idx_002_signals_order ON biz_002.agent_signals USING btree (order_id);


--
-- Name: idx_002_signals_status; Type: INDEX; Schema: biz_002; Owner: -
--

CREATE INDEX idx_002_signals_status ON biz_002.agent_signals USING btree (status);


--
-- Name: idx_002_staff_order; Type: INDEX; Schema: biz_002; Owner: -
--

CREATE INDEX idx_002_staff_order ON biz_002.event_staff USING btree (order_id);


--
-- Name: idx_002_staff_staff; Type: INDEX; Schema: biz_002; Owner: -
--

CREATE INDEX idx_002_staff_staff ON biz_002.event_staff USING btree (staff_id);


--
-- Name: idx_002_transactions_date; Type: INDEX; Schema: biz_002; Owner: -
--

CREATE INDEX idx_002_transactions_date ON biz_002.transactions USING btree (date);


--
-- Name: idx_002_transactions_entity; Type: INDEX; Schema: biz_002; Owner: -
--

CREATE INDEX idx_002_transactions_entity ON biz_002.transactions USING btree (entity_id);


--
-- Name: idx_002_transactions_order; Type: INDEX; Schema: biz_002; Owner: -
--

CREATE INDEX idx_002_transactions_order ON biz_002.transactions USING btree (order_id);


--
-- Name: idx_002_transactions_type; Type: INDEX; Schema: biz_002; Owner: -
--

CREATE INDEX idx_002_transactions_type ON biz_002.transactions USING btree (transaction_type);


--
-- Name: idx_003_audit_row; Type: INDEX; Schema: biz_003; Owner: -
--

CREATE INDEX idx_003_audit_row ON biz_003.audit_log USING btree (row_id);


--
-- Name: idx_003_audit_table; Type: INDEX; Schema: biz_003; Owner: -
--

CREATE INDEX idx_003_audit_table ON biz_003.audit_log USING btree (table_name);


--
-- Name: idx_003_audit_time; Type: INDEX; Schema: biz_003; Owner: -
--

CREATE INDEX idx_003_audit_time ON biz_003.audit_log USING btree (changed_at);


--
-- Name: idx_003_entities_status; Type: INDEX; Schema: biz_003; Owner: -
--

CREATE INDEX idx_003_entities_status ON biz_003.entities USING btree (status);


--
-- Name: idx_003_entities_type; Type: INDEX; Schema: biz_003; Owner: -
--

CREATE INDEX idx_003_entities_type ON biz_003.entities USING btree (entity_type);


--
-- Name: idx_003_events_date; Type: INDEX; Schema: biz_003; Owner: -
--

CREATE INDEX idx_003_events_date ON biz_003.events USING btree (event_date);


--
-- Name: idx_003_events_entity; Type: INDEX; Schema: biz_003; Owner: -
--

CREATE INDEX idx_003_events_entity ON biz_003.events USING btree (entity_id);


--
-- Name: idx_003_properties_status; Type: INDEX; Schema: biz_003; Owner: -
--

CREATE INDEX idx_003_properties_status ON biz_003.properties USING btree (status);


--
-- Name: idx_003_properties_type; Type: INDEX; Schema: biz_003; Owner: -
--

CREATE INDEX idx_003_properties_type ON biz_003.properties USING btree (property_type);


--
-- Name: idx_003_signals_agent; Type: INDEX; Schema: biz_003; Owner: -
--

CREATE INDEX idx_003_signals_agent ON biz_003.agent_signals USING btree (agent_name);


--
-- Name: idx_003_transactions_date; Type: INDEX; Schema: biz_003; Owner: -
--

CREATE INDEX idx_003_transactions_date ON biz_003.transactions USING btree (date);


--
-- Name: idx_003_transactions_entity; Type: INDEX; Schema: biz_003; Owner: -
--

CREATE INDEX idx_003_transactions_entity ON biz_003.transactions USING btree (entity_id);


--
-- Name: idx_004_audit_row; Type: INDEX; Schema: biz_004; Owner: -
--

CREATE INDEX idx_004_audit_row ON biz_004.audit_log USING btree (row_id);


--
-- Name: idx_004_audit_table; Type: INDEX; Schema: biz_004; Owner: -
--

CREATE INDEX idx_004_audit_table ON biz_004.audit_log USING btree (table_name);


--
-- Name: idx_004_audit_time; Type: INDEX; Schema: biz_004; Owner: -
--

CREATE INDEX idx_004_audit_time ON biz_004.audit_log USING btree (changed_at);


--
-- Name: idx_004_entities_status; Type: INDEX; Schema: biz_004; Owner: -
--

CREATE INDEX idx_004_entities_status ON biz_004.entities USING btree (status);


--
-- Name: idx_004_entities_type; Type: INDEX; Schema: biz_004; Owner: -
--

CREATE INDEX idx_004_entities_type ON biz_004.entities USING btree (entity_type);


--
-- Name: idx_004_events_date; Type: INDEX; Schema: biz_004; Owner: -
--

CREATE INDEX idx_004_events_date ON biz_004.events USING btree (event_date);


--
-- Name: idx_004_events_entity; Type: INDEX; Schema: biz_004; Owner: -
--

CREATE INDEX idx_004_events_entity ON biz_004.events USING btree (entity_id);


--
-- Name: idx_004_jobs_client; Type: INDEX; Schema: biz_004; Owner: -
--

CREATE INDEX idx_004_jobs_client ON biz_004.print_job_profiles USING btree (client_id);


--
-- Name: idx_004_jobs_status; Type: INDEX; Schema: biz_004; Owner: -
--

CREATE INDEX idx_004_jobs_status ON biz_004.print_job_profiles USING btree (status);


--
-- Name: idx_004_jobs_type; Type: INDEX; Schema: biz_004; Owner: -
--

CREATE INDEX idx_004_jobs_type ON biz_004.print_job_profiles USING btree (job_type);


--
-- Name: idx_004_signals_agent; Type: INDEX; Schema: biz_004; Owner: -
--

CREATE INDEX idx_004_signals_agent ON biz_004.agent_signals USING btree (agent_name);


--
-- Name: idx_004_transactions_date; Type: INDEX; Schema: biz_004; Owner: -
--

CREATE INDEX idx_004_transactions_date ON biz_004.transactions USING btree (date);


--
-- Name: idx_004_transactions_entity; Type: INDEX; Schema: biz_004; Owner: -
--

CREATE INDEX idx_004_transactions_entity ON biz_004.transactions USING btree (entity_id);


--
-- Name: benchmarks trg_updated_intel_benchmarks; Type: TRIGGER; Schema: ae_intelligence; Owner: -
--

CREATE TRIGGER trg_updated_intel_benchmarks BEFORE UPDATE ON ae_intelligence.benchmarks FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: cross_signal_patterns trg_updated_intel_patterns; Type: TRIGGER; Schema: ae_intelligence; Owner: -
--

CREATE TRIGGER trg_updated_intel_patterns BEFORE UPDATE ON ae_intelligence.cross_signal_patterns FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: businesses set_updated_at_businesses; Type: TRIGGER; Schema: ae_platform; Owner: -
--

CREATE TRIGGER set_updated_at_businesses BEFORE UPDATE ON ae_platform.businesses FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: user_roles set_updated_at_user_roles; Type: TRIGGER; Schema: ae_platform; Owner: -
--

CREATE TRIGGER set_updated_at_user_roles BEFORE UPDATE ON ae_platform.user_roles FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: businesses trg_updated_businesses; Type: TRIGGER; Schema: ae_platform; Owner: -
--

CREATE TRIGGER trg_updated_businesses BEFORE UPDATE ON ae_platform.businesses FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: ca_firm_clients trg_updated_ca_clients; Type: TRIGGER; Schema: ae_platform; Owner: -
--

CREATE TRIGGER trg_updated_ca_clients BEFORE UPDATE ON ae_platform.ca_firm_clients FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: ca_firms trg_updated_ca_firms; Type: TRIGGER; Schema: ae_platform; Owner: -
--

CREATE TRIGGER trg_updated_ca_firms BEFORE UPDATE ON ae_platform.ca_firms FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: consents trg_updated_consents; Type: TRIGGER; Schema: ae_platform; Owner: -
--

CREATE TRIGGER trg_updated_consents BEFORE UPDATE ON ae_platform.consents FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: attendance audit_attendance; Type: TRIGGER; Schema: biz_001; Owner: -
--

CREATE TRIGGER audit_attendance AFTER INSERT OR DELETE OR UPDATE ON biz_001.attendance FOR EACH ROW EXECUTE FUNCTION biz_001.log_audit();


--
-- Name: fee_payments audit_fee_payments; Type: TRIGGER; Schema: biz_001; Owner: -
--

CREATE TRIGGER audit_fee_payments AFTER INSERT OR DELETE OR UPDATE ON biz_001.fee_payments FOR EACH ROW EXECUTE FUNCTION biz_001.log_audit();


--
-- Name: marks audit_marks; Type: TRIGGER; Schema: biz_001; Owner: -
--

CREATE TRIGGER audit_marks AFTER INSERT OR DELETE OR UPDATE ON biz_001.marks FOR EACH ROW EXECUTE FUNCTION biz_001.log_audit();


--
-- Name: subjects audit_subjects; Type: TRIGGER; Schema: biz_001; Owner: -
--

CREATE TRIGGER audit_subjects AFTER INSERT OR DELETE OR UPDATE ON biz_001.subjects FOR EACH ROW EXECUTE FUNCTION biz_001.log_audit();


--
-- Name: teacher_assignments audit_teacher_assignments; Type: TRIGGER; Schema: biz_001; Owner: -
--

CREATE TRIGGER audit_teacher_assignments AFTER INSERT OR DELETE OR UPDATE ON biz_001.teacher_assignments FOR EACH ROW EXECUTE FUNCTION biz_001.log_audit();


--
-- Name: entities trg_audit_001_entities; Type: TRIGGER; Schema: biz_001; Owner: -
--

CREATE TRIGGER trg_audit_001_entities AFTER INSERT OR DELETE OR UPDATE ON biz_001.entities FOR EACH ROW EXECUTE FUNCTION biz_001.log_audit();


--
-- Name: events trg_audit_001_events; Type: TRIGGER; Schema: biz_001; Owner: -
--

CREATE TRIGGER trg_audit_001_events AFTER INSERT OR DELETE OR UPDATE ON biz_001.events FOR EACH ROW EXECUTE FUNCTION biz_001.log_audit();


--
-- Name: interventions trg_audit_001_interventions; Type: TRIGGER; Schema: biz_001; Owner: -
--

CREATE TRIGGER trg_audit_001_interventions AFTER INSERT OR DELETE OR UPDATE ON biz_001.interventions FOR EACH ROW EXECUTE FUNCTION biz_001.log_audit();


--
-- Name: agent_signals trg_audit_001_signals; Type: TRIGGER; Schema: biz_001; Owner: -
--

CREATE TRIGGER trg_audit_001_signals AFTER INSERT OR DELETE OR UPDATE ON biz_001.agent_signals FOR EACH ROW EXECUTE FUNCTION biz_001.log_audit();


--
-- Name: student_profiles trg_audit_001_students; Type: TRIGGER; Schema: biz_001; Owner: -
--

CREATE TRIGGER trg_audit_001_students AFTER INSERT OR DELETE OR UPDATE ON biz_001.student_profiles FOR EACH ROW EXECUTE FUNCTION biz_001.log_audit();


--
-- Name: transactions trg_audit_001_transactions; Type: TRIGGER; Schema: biz_001; Owner: -
--

CREATE TRIGGER trg_audit_001_transactions AFTER INSERT OR DELETE OR UPDATE ON biz_001.transactions FOR EACH ROW EXECUTE FUNCTION biz_001.log_audit();


--
-- Name: documents trg_updated_001_documents; Type: TRIGGER; Schema: biz_001; Owner: -
--

CREATE TRIGGER trg_updated_001_documents BEFORE UPDATE ON biz_001.documents FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: entities trg_updated_001_entities; Type: TRIGGER; Schema: biz_001; Owner: -
--

CREATE TRIGGER trg_updated_001_entities BEFORE UPDATE ON biz_001.entities FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: events trg_updated_001_events; Type: TRIGGER; Schema: biz_001; Owner: -
--

CREATE TRIGGER trg_updated_001_events BEFORE UPDATE ON biz_001.events FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: interventions trg_updated_001_interventions; Type: TRIGGER; Schema: biz_001; Owner: -
--

CREATE TRIGGER trg_updated_001_interventions BEFORE UPDATE ON biz_001.interventions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: agent_signals trg_updated_001_signals; Type: TRIGGER; Schema: biz_001; Owner: -
--

CREATE TRIGGER trg_updated_001_signals BEFORE UPDATE ON biz_001.agent_signals FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: student_profiles trg_updated_001_students; Type: TRIGGER; Schema: biz_001; Owner: -
--

CREATE TRIGGER trg_updated_001_students BEFORE UPDATE ON biz_001.student_profiles FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: transactions trg_updated_001_transactions; Type: TRIGGER; Schema: biz_001; Owner: -
--

CREATE TRIGGER trg_updated_001_transactions BEFORE UPDATE ON biz_001.transactions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: academic_calendar update_academic_calendar_updated_at; Type: TRIGGER; Schema: biz_001; Owner: -
--

CREATE TRIGGER update_academic_calendar_updated_at BEFORE UPDATE ON biz_001.academic_calendar FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: attendance update_attendance_updated_at; Type: TRIGGER; Schema: biz_001; Owner: -
--

CREATE TRIGGER update_attendance_updated_at BEFORE UPDATE ON biz_001.attendance FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: fee_payments update_fee_payments_updated_at; Type: TRIGGER; Schema: biz_001; Owner: -
--

CREATE TRIGGER update_fee_payments_updated_at BEFORE UPDATE ON biz_001.fee_payments FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: fee_structure update_fee_structure_updated_at; Type: TRIGGER; Schema: biz_001; Owner: -
--

CREATE TRIGGER update_fee_structure_updated_at BEFORE UPDATE ON biz_001.fee_structure FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: homework update_homework_updated_at; Type: TRIGGER; Schema: biz_001; Owner: -
--

CREATE TRIGGER update_homework_updated_at BEFORE UPDATE ON biz_001.homework FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: house_points update_house_points_updated_at; Type: TRIGGER; Schema: biz_001; Owner: -
--

CREATE TRIGGER update_house_points_updated_at BEFORE UPDATE ON biz_001.house_points FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: homework_submissions update_hw_submissions_updated_at; Type: TRIGGER; Schema: biz_001; Owner: -
--

CREATE TRIGGER update_hw_submissions_updated_at BEFORE UPDATE ON biz_001.homework_submissions FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: marks update_marks_updated_at; Type: TRIGGER; Schema: biz_001; Owner: -
--

CREATE TRIGGER update_marks_updated_at BEFORE UPDATE ON biz_001.marks FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: performance_observations update_performance_updated_at; Type: TRIGGER; Schema: biz_001; Owner: -
--

CREATE TRIGGER update_performance_updated_at BEFORE UPDATE ON biz_001.performance_observations FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: student_transport update_student_transport_updated_at; Type: TRIGGER; Schema: biz_001; Owner: -
--

CREATE TRIGGER update_student_transport_updated_at BEFORE UPDATE ON biz_001.student_transport FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: subjects update_subjects_updated_at; Type: TRIGGER; Schema: biz_001; Owner: -
--

CREATE TRIGGER update_subjects_updated_at BEFORE UPDATE ON biz_001.subjects FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: teacher_assignments update_teacher_assignments_updated_at; Type: TRIGGER; Schema: biz_001; Owner: -
--

CREATE TRIGGER update_teacher_assignments_updated_at BEFORE UPDATE ON biz_001.teacher_assignments FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: teacher_subjects update_teacher_subjects_updated_at; Type: TRIGGER; Schema: biz_001; Owner: -
--

CREATE TRIGGER update_teacher_subjects_updated_at BEFORE UPDATE ON biz_001.teacher_subjects FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: transport_routes update_transport_routes_updated_at; Type: TRIGGER; Schema: biz_001; Owner: -
--

CREATE TRIGGER update_transport_routes_updated_at BEFORE UPDATE ON biz_001.transport_routes FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: transport_stops update_transport_stops_updated_at; Type: TRIGGER; Schema: biz_001; Owner: -
--

CREATE TRIGGER update_transport_stops_updated_at BEFORE UPDATE ON biz_001.transport_stops FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: catering_orders trg_002_client_counters; Type: TRIGGER; Schema: biz_002; Owner: -
--

CREATE TRIGGER trg_002_client_counters AFTER INSERT OR DELETE OR UPDATE ON biz_002.catering_orders FOR EACH ROW EXECUTE FUNCTION biz_002.update_client_counters();


--
-- Name: entities trg_audit_002_entities; Type: TRIGGER; Schema: biz_002; Owner: -
--

CREATE TRIGGER trg_audit_002_entities AFTER INSERT OR DELETE OR UPDATE ON biz_002.entities FOR EACH ROW EXECUTE FUNCTION biz_002.log_audit();


--
-- Name: events trg_audit_002_events; Type: TRIGGER; Schema: biz_002; Owner: -
--

CREATE TRIGGER trg_audit_002_events AFTER INSERT OR DELETE OR UPDATE ON biz_002.events FOR EACH ROW EXECUTE FUNCTION biz_002.log_audit();


--
-- Name: event_expenses trg_audit_002_expenses; Type: TRIGGER; Schema: biz_002; Owner: -
--

CREATE TRIGGER trg_audit_002_expenses AFTER INSERT OR DELETE OR UPDATE ON biz_002.event_expenses FOR EACH ROW EXECUTE FUNCTION biz_002.log_audit();


--
-- Name: interventions trg_audit_002_interventions; Type: TRIGGER; Schema: biz_002; Owner: -
--

CREATE TRIGGER trg_audit_002_interventions AFTER INSERT OR DELETE OR UPDATE ON biz_002.interventions FOR EACH ROW EXECUTE FUNCTION biz_002.log_audit();


--
-- Name: catering_orders trg_audit_002_orders; Type: TRIGGER; Schema: biz_002; Owner: -
--

CREATE TRIGGER trg_audit_002_orders AFTER INSERT OR DELETE OR UPDATE ON biz_002.catering_orders FOR EACH ROW EXECUTE FUNCTION biz_002.log_audit();


--
-- Name: quotes trg_audit_002_quotes; Type: TRIGGER; Schema: biz_002; Owner: -
--

CREATE TRIGGER trg_audit_002_quotes AFTER INSERT OR DELETE OR UPDATE ON biz_002.quotes FOR EACH ROW EXECUTE FUNCTION biz_002.log_audit();


--
-- Name: agent_signals trg_audit_002_signals; Type: TRIGGER; Schema: biz_002; Owner: -
--

CREATE TRIGGER trg_audit_002_signals AFTER INSERT OR DELETE OR UPDATE ON biz_002.agent_signals FOR EACH ROW EXECUTE FUNCTION biz_002.log_audit();


--
-- Name: event_staff trg_audit_002_staff; Type: TRIGGER; Schema: biz_002; Owner: -
--

CREATE TRIGGER trg_audit_002_staff AFTER INSERT OR DELETE OR UPDATE ON biz_002.event_staff FOR EACH ROW EXECUTE FUNCTION biz_002.log_audit();


--
-- Name: transactions trg_audit_002_transactions; Type: TRIGGER; Schema: biz_002; Owner: -
--

CREATE TRIGGER trg_audit_002_transactions AFTER INSERT OR DELETE OR UPDATE ON biz_002.transactions FOR EACH ROW EXECUTE FUNCTION biz_002.log_audit();


--
-- Name: documents trg_updated_002_documents; Type: TRIGGER; Schema: biz_002; Owner: -
--

CREATE TRIGGER trg_updated_002_documents BEFORE UPDATE ON biz_002.documents FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: entities trg_updated_002_entities; Type: TRIGGER; Schema: biz_002; Owner: -
--

CREATE TRIGGER trg_updated_002_entities BEFORE UPDATE ON biz_002.entities FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: events trg_updated_002_events; Type: TRIGGER; Schema: biz_002; Owner: -
--

CREATE TRIGGER trg_updated_002_events BEFORE UPDATE ON biz_002.events FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: event_expenses trg_updated_002_expenses; Type: TRIGGER; Schema: biz_002; Owner: -
--

CREATE TRIGGER trg_updated_002_expenses BEFORE UPDATE ON biz_002.event_expenses FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: interventions trg_updated_002_interventions; Type: TRIGGER; Schema: biz_002; Owner: -
--

CREATE TRIGGER trg_updated_002_interventions BEFORE UPDATE ON biz_002.interventions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: catering_orders trg_updated_002_orders; Type: TRIGGER; Schema: biz_002; Owner: -
--

CREATE TRIGGER trg_updated_002_orders BEFORE UPDATE ON biz_002.catering_orders FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: quotes trg_updated_002_quotes; Type: TRIGGER; Schema: biz_002; Owner: -
--

CREATE TRIGGER trg_updated_002_quotes BEFORE UPDATE ON biz_002.quotes FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: agent_signals trg_updated_002_signals; Type: TRIGGER; Schema: biz_002; Owner: -
--

CREATE TRIGGER trg_updated_002_signals BEFORE UPDATE ON biz_002.agent_signals FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: event_staff trg_updated_002_staff; Type: TRIGGER; Schema: biz_002; Owner: -
--

CREATE TRIGGER trg_updated_002_staff BEFORE UPDATE ON biz_002.event_staff FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: transactions trg_updated_002_transactions; Type: TRIGGER; Schema: biz_002; Owner: -
--

CREATE TRIGGER trg_updated_002_transactions BEFORE UPDATE ON biz_002.transactions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: entities trg_audit_003_entities; Type: TRIGGER; Schema: biz_003; Owner: -
--

CREATE TRIGGER trg_audit_003_entities AFTER INSERT OR DELETE OR UPDATE ON biz_003.entities FOR EACH ROW EXECUTE FUNCTION biz_003.log_audit();


--
-- Name: events trg_audit_003_events; Type: TRIGGER; Schema: biz_003; Owner: -
--

CREATE TRIGGER trg_audit_003_events AFTER INSERT OR DELETE OR UPDATE ON biz_003.events FOR EACH ROW EXECUTE FUNCTION biz_003.log_audit();


--
-- Name: interventions trg_audit_003_interventions; Type: TRIGGER; Schema: biz_003; Owner: -
--

CREATE TRIGGER trg_audit_003_interventions AFTER INSERT OR DELETE OR UPDATE ON biz_003.interventions FOR EACH ROW EXECUTE FUNCTION biz_003.log_audit();


--
-- Name: properties trg_audit_003_properties; Type: TRIGGER; Schema: biz_003; Owner: -
--

CREATE TRIGGER trg_audit_003_properties AFTER INSERT OR DELETE OR UPDATE ON biz_003.properties FOR EACH ROW EXECUTE FUNCTION biz_003.log_audit();


--
-- Name: agent_signals trg_audit_003_signals; Type: TRIGGER; Schema: biz_003; Owner: -
--

CREATE TRIGGER trg_audit_003_signals AFTER INSERT OR DELETE OR UPDATE ON biz_003.agent_signals FOR EACH ROW EXECUTE FUNCTION biz_003.log_audit();


--
-- Name: transactions trg_audit_003_transactions; Type: TRIGGER; Schema: biz_003; Owner: -
--

CREATE TRIGGER trg_audit_003_transactions AFTER INSERT OR DELETE OR UPDATE ON biz_003.transactions FOR EACH ROW EXECUTE FUNCTION biz_003.log_audit();


--
-- Name: documents trg_updated_003_documents; Type: TRIGGER; Schema: biz_003; Owner: -
--

CREATE TRIGGER trg_updated_003_documents BEFORE UPDATE ON biz_003.documents FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: entities trg_updated_003_entities; Type: TRIGGER; Schema: biz_003; Owner: -
--

CREATE TRIGGER trg_updated_003_entities BEFORE UPDATE ON biz_003.entities FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: events trg_updated_003_events; Type: TRIGGER; Schema: biz_003; Owner: -
--

CREATE TRIGGER trg_updated_003_events BEFORE UPDATE ON biz_003.events FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: interventions trg_updated_003_interventions; Type: TRIGGER; Schema: biz_003; Owner: -
--

CREATE TRIGGER trg_updated_003_interventions BEFORE UPDATE ON biz_003.interventions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: properties trg_updated_003_properties; Type: TRIGGER; Schema: biz_003; Owner: -
--

CREATE TRIGGER trg_updated_003_properties BEFORE UPDATE ON biz_003.properties FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: agent_signals trg_updated_003_signals; Type: TRIGGER; Schema: biz_003; Owner: -
--

CREATE TRIGGER trg_updated_003_signals BEFORE UPDATE ON biz_003.agent_signals FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: transactions trg_updated_003_transactions; Type: TRIGGER; Schema: biz_003; Owner: -
--

CREATE TRIGGER trg_updated_003_transactions BEFORE UPDATE ON biz_003.transactions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: entities trg_audit_004_entities; Type: TRIGGER; Schema: biz_004; Owner: -
--

CREATE TRIGGER trg_audit_004_entities AFTER INSERT OR DELETE OR UPDATE ON biz_004.entities FOR EACH ROW EXECUTE FUNCTION biz_004.log_audit();


--
-- Name: events trg_audit_004_events; Type: TRIGGER; Schema: biz_004; Owner: -
--

CREATE TRIGGER trg_audit_004_events AFTER INSERT OR DELETE OR UPDATE ON biz_004.events FOR EACH ROW EXECUTE FUNCTION biz_004.log_audit();


--
-- Name: interventions trg_audit_004_interventions; Type: TRIGGER; Schema: biz_004; Owner: -
--

CREATE TRIGGER trg_audit_004_interventions AFTER INSERT OR DELETE OR UPDATE ON biz_004.interventions FOR EACH ROW EXECUTE FUNCTION biz_004.log_audit();


--
-- Name: print_job_profiles trg_audit_004_jobs; Type: TRIGGER; Schema: biz_004; Owner: -
--

CREATE TRIGGER trg_audit_004_jobs AFTER INSERT OR DELETE OR UPDATE ON biz_004.print_job_profiles FOR EACH ROW EXECUTE FUNCTION biz_004.log_audit();


--
-- Name: agent_signals trg_audit_004_signals; Type: TRIGGER; Schema: biz_004; Owner: -
--

CREATE TRIGGER trg_audit_004_signals AFTER INSERT OR DELETE OR UPDATE ON biz_004.agent_signals FOR EACH ROW EXECUTE FUNCTION biz_004.log_audit();


--
-- Name: transactions trg_audit_004_transactions; Type: TRIGGER; Schema: biz_004; Owner: -
--

CREATE TRIGGER trg_audit_004_transactions AFTER INSERT OR DELETE OR UPDATE ON biz_004.transactions FOR EACH ROW EXECUTE FUNCTION biz_004.log_audit();


--
-- Name: documents trg_updated_004_documents; Type: TRIGGER; Schema: biz_004; Owner: -
--

CREATE TRIGGER trg_updated_004_documents BEFORE UPDATE ON biz_004.documents FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: entities trg_updated_004_entities; Type: TRIGGER; Schema: biz_004; Owner: -
--

CREATE TRIGGER trg_updated_004_entities BEFORE UPDATE ON biz_004.entities FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: events trg_updated_004_events; Type: TRIGGER; Schema: biz_004; Owner: -
--

CREATE TRIGGER trg_updated_004_events BEFORE UPDATE ON biz_004.events FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: interventions trg_updated_004_interventions; Type: TRIGGER; Schema: biz_004; Owner: -
--

CREATE TRIGGER trg_updated_004_interventions BEFORE UPDATE ON biz_004.interventions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: print_job_profiles trg_updated_004_jobs; Type: TRIGGER; Schema: biz_004; Owner: -
--

CREATE TRIGGER trg_updated_004_jobs BEFORE UPDATE ON biz_004.print_job_profiles FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: agent_signals trg_updated_004_signals; Type: TRIGGER; Schema: biz_004; Owner: -
--

CREATE TRIGGER trg_updated_004_signals BEFORE UPDATE ON biz_004.agent_signals FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: transactions trg_updated_004_transactions; Type: TRIGGER; Schema: biz_004; Owner: -
--

CREATE TRIGGER trg_updated_004_transactions BEFORE UPDATE ON biz_004.transactions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: signal_aggregates signal_aggregates_business_id_fkey; Type: FK CONSTRAINT; Schema: ae_intelligence; Owner: -
--

ALTER TABLE ONLY ae_intelligence.signal_aggregates
    ADD CONSTRAINT signal_aggregates_business_id_fkey FOREIGN KEY (business_id) REFERENCES ae_platform.businesses(id);


--
-- Name: ca_firm_clients ca_firm_clients_business_id_fkey; Type: FK CONSTRAINT; Schema: ae_platform; Owner: -
--

ALTER TABLE ONLY ae_platform.ca_firm_clients
    ADD CONSTRAINT ca_firm_clients_business_id_fkey FOREIGN KEY (business_id) REFERENCES ae_platform.businesses(business_id) ON DELETE CASCADE;


--
-- Name: ca_firm_clients ca_firm_clients_ca_firm_id_fkey; Type: FK CONSTRAINT; Schema: ae_platform; Owner: -
--

ALTER TABLE ONLY ae_platform.ca_firm_clients
    ADD CONSTRAINT ca_firm_clients_ca_firm_id_fkey FOREIGN KEY (ca_firm_id) REFERENCES ae_platform.ca_firms(id) ON DELETE CASCADE;


--
-- Name: consents consents_business_id_fkey; Type: FK CONSTRAINT; Schema: ae_platform; Owner: -
--

ALTER TABLE ONLY ae_platform.consents
    ADD CONSTRAINT consents_business_id_fkey FOREIGN KEY (business_id) REFERENCES ae_platform.businesses(business_id) ON DELETE CASCADE;


--
-- Name: user_roles user_roles_auth_user_id_fkey; Type: FK CONSTRAINT; Schema: ae_platform; Owner: -
--

ALTER TABLE ONLY ae_platform.user_roles
    ADD CONSTRAINT user_roles_auth_user_id_fkey FOREIGN KEY (auth_user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: agent_signals agent_signals_entity_id_fkey; Type: FK CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.agent_signals
    ADD CONSTRAINT agent_signals_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES biz_001.entities(id) ON DELETE SET NULL;


--
-- Name: attendance attendance_marked_by_fkey; Type: FK CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.attendance
    ADD CONSTRAINT attendance_marked_by_fkey FOREIGN KEY (marked_by) REFERENCES biz_001.entities(id);


--
-- Name: attendance attendance_student_id_fkey; Type: FK CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.attendance
    ADD CONSTRAINT attendance_student_id_fkey FOREIGN KEY (student_id) REFERENCES biz_001.entities(id) ON DELETE CASCADE;


--
-- Name: documents documents_entity_id_fkey; Type: FK CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.documents
    ADD CONSTRAINT documents_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES biz_001.entities(id) ON DELETE SET NULL;


--
-- Name: events events_entity_id_fkey; Type: FK CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.events
    ADD CONSTRAINT events_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES biz_001.entities(id) ON DELETE SET NULL;


--
-- Name: fee_payments fee_payments_fee_structure_id_fkey; Type: FK CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.fee_payments
    ADD CONSTRAINT fee_payments_fee_structure_id_fkey FOREIGN KEY (fee_structure_id) REFERENCES biz_001.fee_structure(fee_structure_id);


--
-- Name: fee_payments fee_payments_parent_id_fkey; Type: FK CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.fee_payments
    ADD CONSTRAINT fee_payments_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES biz_001.entities(id);


--
-- Name: fee_payments fee_payments_received_by_fkey; Type: FK CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.fee_payments
    ADD CONSTRAINT fee_payments_received_by_fkey FOREIGN KEY (received_by) REFERENCES biz_001.entities(id);


--
-- Name: fee_payments fee_payments_student_id_fkey; Type: FK CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.fee_payments
    ADD CONSTRAINT fee_payments_student_id_fkey FOREIGN KEY (student_id) REFERENCES biz_001.entities(id) ON DELETE CASCADE;


--
-- Name: homework homework_assigned_by_fkey; Type: FK CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.homework
    ADD CONSTRAINT homework_assigned_by_fkey FOREIGN KEY (assigned_by) REFERENCES biz_001.entities(id);


--
-- Name: homework homework_subject_id_fkey; Type: FK CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.homework
    ADD CONSTRAINT homework_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES biz_001.subjects(subject_id);


--
-- Name: homework_submissions homework_submissions_homework_id_fkey; Type: FK CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.homework_submissions
    ADD CONSTRAINT homework_submissions_homework_id_fkey FOREIGN KEY (homework_id) REFERENCES biz_001.homework(homework_id) ON DELETE CASCADE;


--
-- Name: homework_submissions homework_submissions_student_id_fkey; Type: FK CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.homework_submissions
    ADD CONSTRAINT homework_submissions_student_id_fkey FOREIGN KEY (student_id) REFERENCES biz_001.entities(id) ON DELETE CASCADE;


--
-- Name: house_points house_points_awarded_by_fkey; Type: FK CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.house_points
    ADD CONSTRAINT house_points_awarded_by_fkey FOREIGN KEY (awarded_by) REFERENCES biz_001.entities(id);


--
-- Name: house_points house_points_awarded_to_student_id_fkey; Type: FK CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.house_points
    ADD CONSTRAINT house_points_awarded_to_student_id_fkey FOREIGN KEY (awarded_to_student_id) REFERENCES biz_001.entities(id);


--
-- Name: interventions interventions_signal_id_fkey; Type: FK CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.interventions
    ADD CONSTRAINT interventions_signal_id_fkey FOREIGN KEY (signal_id) REFERENCES biz_001.agent_signals(id) ON DELETE SET NULL;


--
-- Name: marks marks_marked_by_fkey; Type: FK CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.marks
    ADD CONSTRAINT marks_marked_by_fkey FOREIGN KEY (marked_by) REFERENCES biz_001.entities(id);


--
-- Name: marks marks_student_id_fkey; Type: FK CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.marks
    ADD CONSTRAINT marks_student_id_fkey FOREIGN KEY (student_id) REFERENCES biz_001.entities(id) ON DELETE CASCADE;


--
-- Name: marks marks_subject_id_fkey; Type: FK CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.marks
    ADD CONSTRAINT marks_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES biz_001.subjects(subject_id);


--
-- Name: performance_observations performance_observations_observed_by_fkey; Type: FK CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.performance_observations
    ADD CONSTRAINT performance_observations_observed_by_fkey FOREIGN KEY (observed_by) REFERENCES biz_001.entities(id);


--
-- Name: performance_observations performance_observations_student_id_fkey; Type: FK CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.performance_observations
    ADD CONSTRAINT performance_observations_student_id_fkey FOREIGN KEY (student_id) REFERENCES biz_001.entities(id) ON DELETE CASCADE;


--
-- Name: performance_observations performance_observations_subject_id_fkey; Type: FK CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.performance_observations
    ADD CONSTRAINT performance_observations_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES biz_001.subjects(subject_id);


--
-- Name: student_profiles student_profiles_entity_id_fkey; Type: FK CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.student_profiles
    ADD CONSTRAINT student_profiles_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES biz_001.entities(id) ON DELETE CASCADE;


--
-- Name: student_profiles student_profiles_parent_id_fkey; Type: FK CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.student_profiles
    ADD CONSTRAINT student_profiles_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES biz_001.entities(id) ON DELETE SET NULL;


--
-- Name: student_transport student_transport_route_id_fkey; Type: FK CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.student_transport
    ADD CONSTRAINT student_transport_route_id_fkey FOREIGN KEY (route_id) REFERENCES biz_001.transport_routes(route_id);


--
-- Name: student_transport student_transport_stop_id_fkey; Type: FK CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.student_transport
    ADD CONSTRAINT student_transport_stop_id_fkey FOREIGN KEY (stop_id) REFERENCES biz_001.transport_stops(stop_id);


--
-- Name: student_transport student_transport_student_id_fkey; Type: FK CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.student_transport
    ADD CONSTRAINT student_transport_student_id_fkey FOREIGN KEY (student_id) REFERENCES biz_001.entities(id) ON DELETE CASCADE;


--
-- Name: teacher_assignments teacher_assignments_auth_user_id_fkey; Type: FK CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.teacher_assignments
    ADD CONSTRAINT teacher_assignments_auth_user_id_fkey FOREIGN KEY (auth_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: teacher_assignments teacher_assignments_teacher_id_fkey; Type: FK CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.teacher_assignments
    ADD CONSTRAINT teacher_assignments_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES biz_001.entities(id) ON DELETE CASCADE;


--
-- Name: teacher_subjects teacher_subjects_teacher_id_fkey; Type: FK CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.teacher_subjects
    ADD CONSTRAINT teacher_subjects_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES biz_001.entities(id) ON DELETE CASCADE;


--
-- Name: transactions transactions_entity_id_fkey; Type: FK CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.transactions
    ADD CONSTRAINT transactions_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES biz_001.entities(id) ON DELETE SET NULL;


--
-- Name: transport_stops transport_stops_route_id_fkey; Type: FK CONSTRAINT; Schema: biz_001; Owner: -
--

ALTER TABLE ONLY biz_001.transport_stops
    ADD CONSTRAINT transport_stops_route_id_fkey FOREIGN KEY (route_id) REFERENCES biz_001.transport_routes(route_id) ON DELETE CASCADE;


--
-- Name: agent_signals agent_signals_entity_id_fkey; Type: FK CONSTRAINT; Schema: biz_002; Owner: -
--

ALTER TABLE ONLY biz_002.agent_signals
    ADD CONSTRAINT agent_signals_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES biz_002.entities(id) ON DELETE SET NULL;


--
-- Name: catering_orders catering_orders_client_id_fkey; Type: FK CONSTRAINT; Schema: biz_002; Owner: -
--

ALTER TABLE ONLY biz_002.catering_orders
    ADD CONSTRAINT catering_orders_client_id_fkey FOREIGN KEY (client_id) REFERENCES biz_002.entities(id) ON DELETE RESTRICT;


--
-- Name: documents documents_entity_id_fkey; Type: FK CONSTRAINT; Schema: biz_002; Owner: -
--

ALTER TABLE ONLY biz_002.documents
    ADD CONSTRAINT documents_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES biz_002.entities(id) ON DELETE SET NULL;


--
-- Name: event_expenses event_expenses_order_id_fkey; Type: FK CONSTRAINT; Schema: biz_002; Owner: -
--

ALTER TABLE ONLY biz_002.event_expenses
    ADD CONSTRAINT event_expenses_order_id_fkey FOREIGN KEY (order_id) REFERENCES biz_002.catering_orders(id) ON DELETE CASCADE;


--
-- Name: event_expenses event_expenses_vendor_id_fkey; Type: FK CONSTRAINT; Schema: biz_002; Owner: -
--

ALTER TABLE ONLY biz_002.event_expenses
    ADD CONSTRAINT event_expenses_vendor_id_fkey FOREIGN KEY (vendor_id) REFERENCES biz_002.entities(id) ON DELETE SET NULL;


--
-- Name: event_staff event_staff_order_id_fkey; Type: FK CONSTRAINT; Schema: biz_002; Owner: -
--

ALTER TABLE ONLY biz_002.event_staff
    ADD CONSTRAINT event_staff_order_id_fkey FOREIGN KEY (order_id) REFERENCES biz_002.catering_orders(id) ON DELETE CASCADE;


--
-- Name: event_staff event_staff_staff_id_fkey; Type: FK CONSTRAINT; Schema: biz_002; Owner: -
--

ALTER TABLE ONLY biz_002.event_staff
    ADD CONSTRAINT event_staff_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES biz_002.entities(id) ON DELETE CASCADE;


--
-- Name: events events_entity_id_fkey; Type: FK CONSTRAINT; Schema: biz_002; Owner: -
--

ALTER TABLE ONLY biz_002.events
    ADD CONSTRAINT events_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES biz_002.entities(id) ON DELETE SET NULL;


--
-- Name: documents fk_documents_order; Type: FK CONSTRAINT; Schema: biz_002; Owner: -
--

ALTER TABLE ONLY biz_002.documents
    ADD CONSTRAINT fk_documents_order FOREIGN KEY (order_id) REFERENCES biz_002.catering_orders(id) ON DELETE SET NULL;


--
-- Name: agent_signals fk_signals_order; Type: FK CONSTRAINT; Schema: biz_002; Owner: -
--

ALTER TABLE ONLY biz_002.agent_signals
    ADD CONSTRAINT fk_signals_order FOREIGN KEY (order_id) REFERENCES biz_002.catering_orders(id) ON DELETE SET NULL;


--
-- Name: transactions fk_transactions_order; Type: FK CONSTRAINT; Schema: biz_002; Owner: -
--

ALTER TABLE ONLY biz_002.transactions
    ADD CONSTRAINT fk_transactions_order FOREIGN KEY (order_id) REFERENCES biz_002.catering_orders(id) ON DELETE SET NULL;


--
-- Name: interventions interventions_signal_id_fkey; Type: FK CONSTRAINT; Schema: biz_002; Owner: -
--

ALTER TABLE ONLY biz_002.interventions
    ADD CONSTRAINT interventions_signal_id_fkey FOREIGN KEY (signal_id) REFERENCES biz_002.agent_signals(id) ON DELETE SET NULL;


--
-- Name: quotes quotes_client_id_fkey; Type: FK CONSTRAINT; Schema: biz_002; Owner: -
--

ALTER TABLE ONLY biz_002.quotes
    ADD CONSTRAINT quotes_client_id_fkey FOREIGN KEY (client_id) REFERENCES biz_002.entities(id) ON DELETE CASCADE;


--
-- Name: quotes quotes_order_id_fkey; Type: FK CONSTRAINT; Schema: biz_002; Owner: -
--

ALTER TABLE ONLY biz_002.quotes
    ADD CONSTRAINT quotes_order_id_fkey FOREIGN KEY (order_id) REFERENCES biz_002.catering_orders(id) ON DELETE SET NULL;


--
-- Name: transactions transactions_entity_id_fkey; Type: FK CONSTRAINT; Schema: biz_002; Owner: -
--

ALTER TABLE ONLY biz_002.transactions
    ADD CONSTRAINT transactions_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES biz_002.entities(id) ON DELETE SET NULL;


--
-- Name: agent_signals agent_signals_entity_id_fkey; Type: FK CONSTRAINT; Schema: biz_003; Owner: -
--

ALTER TABLE ONLY biz_003.agent_signals
    ADD CONSTRAINT agent_signals_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES biz_003.entities(id) ON DELETE SET NULL;


--
-- Name: documents documents_entity_id_fkey; Type: FK CONSTRAINT; Schema: biz_003; Owner: -
--

ALTER TABLE ONLY biz_003.documents
    ADD CONSTRAINT documents_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES biz_003.entities(id) ON DELETE SET NULL;


--
-- Name: events events_entity_id_fkey; Type: FK CONSTRAINT; Schema: biz_003; Owner: -
--

ALTER TABLE ONLY biz_003.events
    ADD CONSTRAINT events_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES biz_003.entities(id) ON DELETE SET NULL;


--
-- Name: interventions interventions_signal_id_fkey; Type: FK CONSTRAINT; Schema: biz_003; Owner: -
--

ALTER TABLE ONLY biz_003.interventions
    ADD CONSTRAINT interventions_signal_id_fkey FOREIGN KEY (signal_id) REFERENCES biz_003.agent_signals(id) ON DELETE SET NULL;


--
-- Name: properties properties_buyer_entity_id_fkey; Type: FK CONSTRAINT; Schema: biz_003; Owner: -
--

ALTER TABLE ONLY biz_003.properties
    ADD CONSTRAINT properties_buyer_entity_id_fkey FOREIGN KEY (buyer_entity_id) REFERENCES biz_003.entities(id) ON DELETE SET NULL;


--
-- Name: properties properties_owner_entity_id_fkey; Type: FK CONSTRAINT; Schema: biz_003; Owner: -
--

ALTER TABLE ONLY biz_003.properties
    ADD CONSTRAINT properties_owner_entity_id_fkey FOREIGN KEY (owner_entity_id) REFERENCES biz_003.entities(id) ON DELETE SET NULL;


--
-- Name: transactions transactions_entity_id_fkey; Type: FK CONSTRAINT; Schema: biz_003; Owner: -
--

ALTER TABLE ONLY biz_003.transactions
    ADD CONSTRAINT transactions_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES biz_003.entities(id) ON DELETE SET NULL;


--
-- Name: agent_signals agent_signals_entity_id_fkey; Type: FK CONSTRAINT; Schema: biz_004; Owner: -
--

ALTER TABLE ONLY biz_004.agent_signals
    ADD CONSTRAINT agent_signals_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES biz_004.entities(id) ON DELETE SET NULL;


--
-- Name: documents documents_entity_id_fkey; Type: FK CONSTRAINT; Schema: biz_004; Owner: -
--

ALTER TABLE ONLY biz_004.documents
    ADD CONSTRAINT documents_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES biz_004.entities(id) ON DELETE SET NULL;


--
-- Name: events events_entity_id_fkey; Type: FK CONSTRAINT; Schema: biz_004; Owner: -
--

ALTER TABLE ONLY biz_004.events
    ADD CONSTRAINT events_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES biz_004.entities(id) ON DELETE SET NULL;


--
-- Name: interventions interventions_signal_id_fkey; Type: FK CONSTRAINT; Schema: biz_004; Owner: -
--

ALTER TABLE ONLY biz_004.interventions
    ADD CONSTRAINT interventions_signal_id_fkey FOREIGN KEY (signal_id) REFERENCES biz_004.agent_signals(id) ON DELETE SET NULL;


--
-- Name: print_job_profiles print_job_profiles_client_id_fkey; Type: FK CONSTRAINT; Schema: biz_004; Owner: -
--

ALTER TABLE ONLY biz_004.print_job_profiles
    ADD CONSTRAINT print_job_profiles_client_id_fkey FOREIGN KEY (client_id) REFERENCES biz_004.entities(id) ON DELETE RESTRICT;


--
-- Name: transactions transactions_entity_id_fkey; Type: FK CONSTRAINT; Schema: biz_004; Owner: -
--

ALTER TABLE ONLY biz_004.transactions
    ADD CONSTRAINT transactions_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES biz_004.entities(id) ON DELETE SET NULL;


--
-- Name: user_roles platform_admin_all_roles; Type: POLICY; Schema: ae_platform; Owner: -
--

CREATE POLICY platform_admin_all_roles ON ae_platform.user_roles USING ((EXISTS ( SELECT 1
   FROM ae_platform.user_roles ur2
  WHERE ((ur2.auth_user_id = auth.uid()) AND (ur2.role = 'platform_admin'::text)))));


--
-- Name: user_roles; Type: ROW SECURITY; Schema: ae_platform; Owner: -
--

ALTER TABLE ae_platform.user_roles ENABLE ROW LEVEL SECURITY;

--
-- Name: user_roles user_roles_own_row; Type: POLICY; Schema: ae_platform; Owner: -
--

CREATE POLICY user_roles_own_row ON ae_platform.user_roles FOR SELECT USING ((auth_user_id = auth.uid()));


--
-- Name: user_roles users_see_own_role; Type: POLICY; Schema: ae_platform; Owner: -
--

CREATE POLICY users_see_own_role ON ae_platform.user_roles FOR SELECT USING ((auth_user_id = auth.uid()));


--
-- Name: academic_calendar; Type: ROW SECURITY; Schema: biz_001; Owner: -
--

ALTER TABLE biz_001.academic_calendar ENABLE ROW LEVEL SECURITY;

--
-- Name: academic_calendar academic_calendar_authenticated_select; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY academic_calendar_authenticated_select ON biz_001.academic_calendar FOR SELECT USING ((biz_001.get_user_role() = ANY (ARRAY['Teacher'::text, 'Parent'::text, 'Student'::text])));


--
-- Name: academic_calendar academic_calendar_principal_all; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY academic_calendar_principal_all ON biz_001.academic_calendar USING ((biz_001.get_user_role() = 'Principal'::text)) WITH CHECK ((biz_001.get_user_role() = 'Principal'::text));


--
-- Name: agent_signals; Type: ROW SECURITY; Schema: biz_001; Owner: -
--

ALTER TABLE biz_001.agent_signals ENABLE ROW LEVEL SECURITY;

--
-- Name: agent_signals_archive; Type: ROW SECURITY; Schema: biz_001; Owner: -
--

ALTER TABLE biz_001.agent_signals_archive ENABLE ROW LEVEL SECURITY;

--
-- Name: agent_signals_archive agent_signals_archive_principal_all; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY agent_signals_archive_principal_all ON biz_001.agent_signals_archive USING ((biz_001.get_user_role() = 'Principal'::text)) WITH CHECK ((biz_001.get_user_role() = 'Principal'::text));


--
-- Name: agent_signals agent_signals_principal_all; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY agent_signals_principal_all ON biz_001.agent_signals USING ((biz_001.get_user_role() = 'Principal'::text)) WITH CHECK ((biz_001.get_user_role() = 'Principal'::text));


--
-- Name: attendance; Type: ROW SECURITY; Schema: biz_001; Owner: -
--

ALTER TABLE biz_001.attendance ENABLE ROW LEVEL SECURITY;

--
-- Name: attendance attendance_parent_select; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY attendance_parent_select ON biz_001.attendance FOR SELECT USING (((biz_001.get_user_role() = 'Parent'::text) AND (student_id IN ( SELECT get_parent_student_ids.student_entity_id
   FROM biz_001.get_parent_student_ids() get_parent_student_ids(student_entity_id)))));


--
-- Name: attendance attendance_principal_all; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY attendance_principal_all ON biz_001.attendance USING ((biz_001.get_user_role() = 'Principal'::text)) WITH CHECK ((biz_001.get_user_role() = 'Principal'::text));


--
-- Name: attendance attendance_student_select; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY attendance_student_select ON biz_001.attendance FOR SELECT USING (((biz_001.get_user_role() = 'Student'::text) AND (student_id = biz_001.get_own_entity_id())));


--
-- Name: attendance attendance_teacher_all; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY attendance_teacher_all ON biz_001.attendance USING (((biz_001.get_user_role() = 'Teacher'::text) AND ((class, section) IN ( SELECT get_teacher_classes.class,
    get_teacher_classes.section
   FROM biz_001.get_teacher_classes() get_teacher_classes(class, section))))) WITH CHECK (((biz_001.get_user_role() = 'Teacher'::text) AND ((class, section) IN ( SELECT get_teacher_classes.class,
    get_teacher_classes.section
   FROM biz_001.get_teacher_classes() get_teacher_classes(class, section)))));


--
-- Name: audit_log; Type: ROW SECURITY; Schema: biz_001; Owner: -
--

ALTER TABLE biz_001.audit_log ENABLE ROW LEVEL SECURITY;

--
-- Name: audit_log audit_log_authenticated_insert; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY audit_log_authenticated_insert ON biz_001.audit_log FOR INSERT WITH CHECK ((auth.uid() IS NOT NULL));


--
-- Name: audit_log audit_log_principal_select; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY audit_log_principal_select ON biz_001.audit_log FOR SELECT USING ((biz_001.get_user_role() = 'Principal'::text));


--
-- Name: documents; Type: ROW SECURITY; Schema: biz_001; Owner: -
--

ALTER TABLE biz_001.documents ENABLE ROW LEVEL SECURITY;

--
-- Name: documents documents_principal_all; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY documents_principal_all ON biz_001.documents USING ((biz_001.get_user_role() = 'Principal'::text)) WITH CHECK ((biz_001.get_user_role() = 'Principal'::text));


--
-- Name: entities; Type: ROW SECURITY; Schema: biz_001; Owner: -
--

ALTER TABLE biz_001.entities ENABLE ROW LEVEL SECURITY;

--
-- Name: entities entities_parent_select; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY entities_parent_select ON biz_001.entities FOR SELECT USING (((biz_001.get_user_role() = 'Parent'::text) AND ((id = biz_001.get_own_entity_id()) OR (id IN ( SELECT get_parent_student_ids.student_entity_id
   FROM biz_001.get_parent_student_ids() get_parent_student_ids(student_entity_id))))));


--
-- Name: entities entities_principal_all; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY entities_principal_all ON biz_001.entities USING ((biz_001.get_user_role() = 'Principal'::text)) WITH CHECK ((biz_001.get_user_role() = 'Principal'::text));


--
-- Name: entities entities_student_select; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY entities_student_select ON biz_001.entities FOR SELECT USING (((biz_001.get_user_role() = 'Student'::text) AND (id = biz_001.get_own_entity_id())));


--
-- Name: entities entities_teacher_select; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY entities_teacher_select ON biz_001.entities FOR SELECT USING (((biz_001.get_user_role() = 'Teacher'::text) AND ((id = biz_001.get_own_entity_id()) OR (entity_type = ANY (ARRAY['teacher'::text, 'staff'::text])) OR (id IN ( SELECT sp.entity_id
   FROM biz_001.student_profiles sp
  WHERE ((sp.class, sp.section) IN ( SELECT get_teacher_classes.class,
            get_teacher_classes.section
           FROM biz_001.get_teacher_classes() get_teacher_classes(class, section))))) OR (id IN ( SELECT sp.parent_id
   FROM biz_001.student_profiles sp
  WHERE (((sp.class, sp.section) IN ( SELECT get_teacher_classes.class,
            get_teacher_classes.section
           FROM biz_001.get_teacher_classes() get_teacher_classes(class, section))) AND (sp.parent_id IS NOT NULL)))))));


--
-- Name: events; Type: ROW SECURITY; Schema: biz_001; Owner: -
--

ALTER TABLE biz_001.events ENABLE ROW LEVEL SECURITY;

--
-- Name: events events_principal_all; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY events_principal_all ON biz_001.events USING ((biz_001.get_user_role() = 'Principal'::text)) WITH CHECK ((biz_001.get_user_role() = 'Principal'::text));


--
-- Name: fee_payments; Type: ROW SECURITY; Schema: biz_001; Owner: -
--

ALTER TABLE biz_001.fee_payments ENABLE ROW LEVEL SECURITY;

--
-- Name: fee_payments fee_payments_parent_select; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY fee_payments_parent_select ON biz_001.fee_payments FOR SELECT USING (((biz_001.get_user_role() = 'Parent'::text) AND (student_id IN ( SELECT get_parent_student_ids.student_entity_id
   FROM biz_001.get_parent_student_ids() get_parent_student_ids(student_entity_id)))));


--
-- Name: fee_payments fee_payments_principal_all; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY fee_payments_principal_all ON biz_001.fee_payments USING ((biz_001.get_user_role() = 'Principal'::text)) WITH CHECK ((biz_001.get_user_role() = 'Principal'::text));


--
-- Name: fee_payments fee_payments_student_select; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY fee_payments_student_select ON biz_001.fee_payments FOR SELECT USING (((biz_001.get_user_role() = 'Student'::text) AND (student_id = biz_001.get_own_entity_id())));


--
-- Name: fee_structure; Type: ROW SECURITY; Schema: biz_001; Owner: -
--

ALTER TABLE biz_001.fee_structure ENABLE ROW LEVEL SECURITY;

--
-- Name: fee_structure fee_structure_authenticated_select; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY fee_structure_authenticated_select ON biz_001.fee_structure FOR SELECT USING ((biz_001.get_user_role() = ANY (ARRAY['Teacher'::text, 'Parent'::text, 'Student'::text])));


--
-- Name: fee_structure fee_structure_principal_all; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY fee_structure_principal_all ON biz_001.fee_structure USING ((biz_001.get_user_role() = 'Principal'::text)) WITH CHECK ((biz_001.get_user_role() = 'Principal'::text));


--
-- Name: homework; Type: ROW SECURITY; Schema: biz_001; Owner: -
--

ALTER TABLE biz_001.homework ENABLE ROW LEVEL SECURITY;

--
-- Name: homework homework_parent_select; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY homework_parent_select ON biz_001.homework FOR SELECT USING (((biz_001.get_user_role() = 'Parent'::text) AND ((class, section) IN ( SELECT sp.class,
    sp.section
   FROM biz_001.student_profiles sp
  WHERE (sp.entity_id IN ( SELECT get_parent_student_ids.student_entity_id
           FROM biz_001.get_parent_student_ids() get_parent_student_ids(student_entity_id)))))));


--
-- Name: homework homework_principal_all; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY homework_principal_all ON biz_001.homework USING ((biz_001.get_user_role() = 'Principal'::text)) WITH CHECK ((biz_001.get_user_role() = 'Principal'::text));


--
-- Name: homework homework_student_select; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY homework_student_select ON biz_001.homework FOR SELECT USING (((biz_001.get_user_role() = 'Student'::text) AND ((class, section) IN ( SELECT sp.class,
    sp.section
   FROM biz_001.student_profiles sp
  WHERE (sp.entity_id = biz_001.get_own_entity_id())))));


--
-- Name: homework_submissions; Type: ROW SECURITY; Schema: biz_001; Owner: -
--

ALTER TABLE biz_001.homework_submissions ENABLE ROW LEVEL SECURITY;

--
-- Name: homework_submissions homework_submissions_parent_select; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY homework_submissions_parent_select ON biz_001.homework_submissions FOR SELECT USING (((biz_001.get_user_role() = 'Parent'::text) AND (student_id IN ( SELECT get_parent_student_ids.student_entity_id
   FROM biz_001.get_parent_student_ids() get_parent_student_ids(student_entity_id)))));


--
-- Name: homework_submissions homework_submissions_principal_all; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY homework_submissions_principal_all ON biz_001.homework_submissions USING ((biz_001.get_user_role() = 'Principal'::text)) WITH CHECK ((biz_001.get_user_role() = 'Principal'::text));


--
-- Name: homework_submissions homework_submissions_student_all; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY homework_submissions_student_all ON biz_001.homework_submissions USING (((biz_001.get_user_role() = 'Student'::text) AND (student_id = biz_001.get_own_entity_id()))) WITH CHECK (((biz_001.get_user_role() = 'Student'::text) AND (student_id = biz_001.get_own_entity_id())));


--
-- Name: homework_submissions homework_submissions_teacher_all; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY homework_submissions_teacher_all ON biz_001.homework_submissions USING (((biz_001.get_user_role() = 'Teacher'::text) AND (homework_id IN ( SELECT h.homework_id
   FROM biz_001.homework h
  WHERE ((h.class, h.section) IN ( SELECT get_teacher_classes.class,
            get_teacher_classes.section
           FROM biz_001.get_teacher_classes() get_teacher_classes(class, section))))))) WITH CHECK (((biz_001.get_user_role() = 'Teacher'::text) AND (homework_id IN ( SELECT h.homework_id
   FROM biz_001.homework h
  WHERE ((h.class, h.section) IN ( SELECT get_teacher_classes.class,
            get_teacher_classes.section
           FROM biz_001.get_teacher_classes() get_teacher_classes(class, section)))))));


--
-- Name: homework homework_teacher_all; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY homework_teacher_all ON biz_001.homework USING (((biz_001.get_user_role() = 'Teacher'::text) AND ((class, section) IN ( SELECT get_teacher_classes.class,
    get_teacher_classes.section
   FROM biz_001.get_teacher_classes() get_teacher_classes(class, section))))) WITH CHECK (((biz_001.get_user_role() = 'Teacher'::text) AND ((class, section) IN ( SELECT get_teacher_classes.class,
    get_teacher_classes.section
   FROM biz_001.get_teacher_classes() get_teacher_classes(class, section)))));


--
-- Name: house_points; Type: ROW SECURITY; Schema: biz_001; Owner: -
--

ALTER TABLE biz_001.house_points ENABLE ROW LEVEL SECURITY;

--
-- Name: house_points house_points_parent_select; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY house_points_parent_select ON biz_001.house_points FOR SELECT USING (((biz_001.get_user_role() = 'Parent'::text) AND (awarded_to_student_id IN ( SELECT get_parent_student_ids.student_entity_id
   FROM biz_001.get_parent_student_ids() get_parent_student_ids(student_entity_id)))));


--
-- Name: house_points house_points_principal_all; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY house_points_principal_all ON biz_001.house_points USING ((biz_001.get_user_role() = 'Principal'::text)) WITH CHECK ((biz_001.get_user_role() = 'Principal'::text));


--
-- Name: house_points house_points_student_select; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY house_points_student_select ON biz_001.house_points FOR SELECT USING (((biz_001.get_user_role() = 'Student'::text) AND (awarded_to_student_id = biz_001.get_own_entity_id())));


--
-- Name: house_points house_points_teacher_all; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY house_points_teacher_all ON biz_001.house_points USING (((biz_001.get_user_role() = 'Teacher'::text) AND (awarded_to_student_id IN ( SELECT sp.entity_id
   FROM biz_001.student_profiles sp
  WHERE ((sp.class, sp.section) IN ( SELECT get_teacher_classes.class,
            get_teacher_classes.section
           FROM biz_001.get_teacher_classes() get_teacher_classes(class, section))))))) WITH CHECK (((biz_001.get_user_role() = 'Teacher'::text) AND (awarded_to_student_id IN ( SELECT sp.entity_id
   FROM biz_001.student_profiles sp
  WHERE ((sp.class, sp.section) IN ( SELECT get_teacher_classes.class,
            get_teacher_classes.section
           FROM biz_001.get_teacher_classes() get_teacher_classes(class, section)))))));


--
-- Name: interventions; Type: ROW SECURITY; Schema: biz_001; Owner: -
--

ALTER TABLE biz_001.interventions ENABLE ROW LEVEL SECURITY;

--
-- Name: interventions interventions_principal_all; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY interventions_principal_all ON biz_001.interventions USING ((biz_001.get_user_role() = 'Principal'::text)) WITH CHECK ((biz_001.get_user_role() = 'Principal'::text));


--
-- Name: marks; Type: ROW SECURITY; Schema: biz_001; Owner: -
--

ALTER TABLE biz_001.marks ENABLE ROW LEVEL SECURITY;

--
-- Name: marks marks_parent_select; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY marks_parent_select ON biz_001.marks FOR SELECT USING (((biz_001.get_user_role() = 'Parent'::text) AND (student_id IN ( SELECT get_parent_student_ids.student_entity_id
   FROM biz_001.get_parent_student_ids() get_parent_student_ids(student_entity_id)))));


--
-- Name: marks marks_principal_all; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY marks_principal_all ON biz_001.marks USING ((biz_001.get_user_role() = 'Principal'::text)) WITH CHECK ((biz_001.get_user_role() = 'Principal'::text));


--
-- Name: marks marks_student_select; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY marks_student_select ON biz_001.marks FOR SELECT USING (((biz_001.get_user_role() = 'Student'::text) AND (student_id = biz_001.get_own_entity_id())));


--
-- Name: marks marks_teacher_all; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY marks_teacher_all ON biz_001.marks USING (((biz_001.get_user_role() = 'Teacher'::text) AND ((class, section) IN ( SELECT get_teacher_classes.class,
    get_teacher_classes.section
   FROM biz_001.get_teacher_classes() get_teacher_classes(class, section))) AND (subject_id IN ( SELECT get_teacher_subject_ids.subject_id
   FROM biz_001.get_teacher_subject_ids() get_teacher_subject_ids(subject_id))))) WITH CHECK (((biz_001.get_user_role() = 'Teacher'::text) AND ((class, section) IN ( SELECT get_teacher_classes.class,
    get_teacher_classes.section
   FROM biz_001.get_teacher_classes() get_teacher_classes(class, section))) AND (subject_id IN ( SELECT get_teacher_subject_ids.subject_id
   FROM biz_001.get_teacher_subject_ids() get_teacher_subject_ids(subject_id)))));


--
-- Name: performance_observations; Type: ROW SECURITY; Schema: biz_001; Owner: -
--

ALTER TABLE biz_001.performance_observations ENABLE ROW LEVEL SECURITY;

--
-- Name: performance_observations performance_observations_principal_all; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY performance_observations_principal_all ON biz_001.performance_observations USING ((biz_001.get_user_role() = 'Principal'::text)) WITH CHECK ((biz_001.get_user_role() = 'Principal'::text));


--
-- Name: student_profiles; Type: ROW SECURITY; Schema: biz_001; Owner: -
--

ALTER TABLE biz_001.student_profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: student_profiles student_profiles_parent_select; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY student_profiles_parent_select ON biz_001.student_profiles FOR SELECT USING (((biz_001.get_user_role() = 'Parent'::text) AND (entity_id IN ( SELECT get_parent_student_ids.student_entity_id
   FROM biz_001.get_parent_student_ids() get_parent_student_ids(student_entity_id)))));


--
-- Name: student_profiles student_profiles_principal_all; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY student_profiles_principal_all ON biz_001.student_profiles USING ((biz_001.get_user_role() = 'Principal'::text)) WITH CHECK ((biz_001.get_user_role() = 'Principal'::text));


--
-- Name: student_profiles student_profiles_student_select; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY student_profiles_student_select ON biz_001.student_profiles FOR SELECT USING (((biz_001.get_user_role() = 'Student'::text) AND (entity_id = biz_001.get_own_entity_id())));


--
-- Name: student_profiles student_profiles_teacher_select; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY student_profiles_teacher_select ON biz_001.student_profiles FOR SELECT USING (((biz_001.get_user_role() = 'Teacher'::text) AND ((class, section) IN ( SELECT get_teacher_classes.class,
    get_teacher_classes.section
   FROM biz_001.get_teacher_classes() get_teacher_classes(class, section)))));


--
-- Name: student_transport; Type: ROW SECURITY; Schema: biz_001; Owner: -
--

ALTER TABLE biz_001.student_transport ENABLE ROW LEVEL SECURITY;

--
-- Name: student_transport student_transport_parent_select; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY student_transport_parent_select ON biz_001.student_transport FOR SELECT USING (((biz_001.get_user_role() = 'Parent'::text) AND (student_id IN ( SELECT get_parent_student_ids.student_entity_id
   FROM biz_001.get_parent_student_ids() get_parent_student_ids(student_entity_id)))));


--
-- Name: student_transport student_transport_principal_all; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY student_transport_principal_all ON biz_001.student_transport USING ((biz_001.get_user_role() = 'Principal'::text)) WITH CHECK ((biz_001.get_user_role() = 'Principal'::text));


--
-- Name: student_transport student_transport_student_select; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY student_transport_student_select ON biz_001.student_transport FOR SELECT USING (((biz_001.get_user_role() = 'Student'::text) AND (student_id = biz_001.get_own_entity_id())));


--
-- Name: subjects; Type: ROW SECURITY; Schema: biz_001; Owner: -
--

ALTER TABLE biz_001.subjects ENABLE ROW LEVEL SECURITY;

--
-- Name: subjects subjects_authenticated_select; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY subjects_authenticated_select ON biz_001.subjects FOR SELECT USING ((biz_001.get_user_role() = ANY (ARRAY['Teacher'::text, 'Parent'::text, 'Student'::text])));


--
-- Name: subjects subjects_principal_all; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY subjects_principal_all ON biz_001.subjects USING ((biz_001.get_user_role() = 'Principal'::text)) WITH CHECK ((biz_001.get_user_role() = 'Principal'::text));


--
-- Name: teacher_assignments; Type: ROW SECURITY; Schema: biz_001; Owner: -
--

ALTER TABLE biz_001.teacher_assignments ENABLE ROW LEVEL SECURITY;

--
-- Name: teacher_assignments teacher_assignments_principal_all; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY teacher_assignments_principal_all ON biz_001.teacher_assignments USING ((biz_001.get_user_role() = 'Principal'::text)) WITH CHECK ((biz_001.get_user_role() = 'Principal'::text));


--
-- Name: teacher_assignments teacher_assignments_teacher_select_own; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY teacher_assignments_teacher_select_own ON biz_001.teacher_assignments FOR SELECT USING (((biz_001.get_user_role() = 'Teacher'::text) AND (auth_user_id = auth.uid())));


--
-- Name: teacher_profiles; Type: ROW SECURITY; Schema: biz_001; Owner: -
--

ALTER TABLE biz_001.teacher_profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: teacher_subjects; Type: ROW SECURITY; Schema: biz_001; Owner: -
--

ALTER TABLE biz_001.teacher_subjects ENABLE ROW LEVEL SECURITY;

--
-- Name: teacher_subjects_backup_20260506; Type: ROW SECURITY; Schema: biz_001; Owner: -
--

ALTER TABLE biz_001.teacher_subjects_backup_20260506 ENABLE ROW LEVEL SECURITY;

--
-- Name: teacher_subjects teacher_subjects_parent_select; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY teacher_subjects_parent_select ON biz_001.teacher_subjects FOR SELECT USING (((biz_001.get_user_role() = 'Parent'::text) AND ((class, section) IN ( SELECT sp.class,
    sp.section
   FROM biz_001.student_profiles sp
  WHERE (sp.entity_id IN ( SELECT get_parent_student_ids.student_entity_id
           FROM biz_001.get_parent_student_ids() get_parent_student_ids(student_entity_id)))))));


--
-- Name: teacher_subjects teacher_subjects_principal_all; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY teacher_subjects_principal_all ON biz_001.teacher_subjects USING ((biz_001.get_user_role() = 'Principal'::text)) WITH CHECK ((biz_001.get_user_role() = 'Principal'::text));


--
-- Name: teacher_subjects teacher_subjects_student_select; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY teacher_subjects_student_select ON biz_001.teacher_subjects FOR SELECT USING (((biz_001.get_user_role() = 'Student'::text) AND ((class, section) IN ( SELECT sp.class,
    sp.section
   FROM biz_001.student_profiles sp
  WHERE (sp.entity_id = biz_001.get_own_entity_id())))));


--
-- Name: teacher_subjects teacher_subjects_teacher_select; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY teacher_subjects_teacher_select ON biz_001.teacher_subjects FOR SELECT USING (((biz_001.get_user_role() = 'Teacher'::text) AND (teacher_id = biz_001.get_own_entity_id())));


--
-- Name: transactions; Type: ROW SECURITY; Schema: biz_001; Owner: -
--

ALTER TABLE biz_001.transactions ENABLE ROW LEVEL SECURITY;

--
-- Name: transactions transactions_principal_all; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY transactions_principal_all ON biz_001.transactions USING ((biz_001.get_user_role() = 'Principal'::text)) WITH CHECK ((biz_001.get_user_role() = 'Principal'::text));


--
-- Name: transport_routes; Type: ROW SECURITY; Schema: biz_001; Owner: -
--

ALTER TABLE biz_001.transport_routes ENABLE ROW LEVEL SECURITY;

--
-- Name: transport_routes transport_routes_authenticated_select; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY transport_routes_authenticated_select ON biz_001.transport_routes FOR SELECT USING ((biz_001.get_user_role() = ANY (ARRAY['Teacher'::text, 'Parent'::text, 'Student'::text])));


--
-- Name: transport_routes transport_routes_principal_all; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY transport_routes_principal_all ON biz_001.transport_routes USING ((biz_001.get_user_role() = 'Principal'::text)) WITH CHECK ((biz_001.get_user_role() = 'Principal'::text));


--
-- Name: transport_stops; Type: ROW SECURITY; Schema: biz_001; Owner: -
--

ALTER TABLE biz_001.transport_stops ENABLE ROW LEVEL SECURITY;

--
-- Name: transport_stops transport_stops_authenticated_select; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY transport_stops_authenticated_select ON biz_001.transport_stops FOR SELECT USING ((biz_001.get_user_role() = ANY (ARRAY['Teacher'::text, 'Parent'::text, 'Student'::text])));


--
-- Name: transport_stops transport_stops_principal_all; Type: POLICY; Schema: biz_001; Owner: -
--

CREATE POLICY transport_stops_principal_all ON biz_001.transport_stops USING ((biz_001.get_user_role() = 'Principal'::text)) WITH CHECK ((biz_001.get_user_role() = 'Principal'::text));


--
-- Name: agent_signals; Type: ROW SECURITY; Schema: biz_002; Owner: -
--

ALTER TABLE biz_002.agent_signals ENABLE ROW LEVEL SECURITY;

--
-- Name: audit_log; Type: ROW SECURITY; Schema: biz_002; Owner: -
--

ALTER TABLE biz_002.audit_log ENABLE ROW LEVEL SECURITY;

--
-- Name: catering_orders; Type: ROW SECURITY; Schema: biz_002; Owner: -
--

ALTER TABLE biz_002.catering_orders ENABLE ROW LEVEL SECURITY;

--
-- Name: documents; Type: ROW SECURITY; Schema: biz_002; Owner: -
--

ALTER TABLE biz_002.documents ENABLE ROW LEVEL SECURITY;

--
-- Name: entities; Type: ROW SECURITY; Schema: biz_002; Owner: -
--

ALTER TABLE biz_002.entities ENABLE ROW LEVEL SECURITY;

--
-- Name: event_expenses; Type: ROW SECURITY; Schema: biz_002; Owner: -
--

ALTER TABLE biz_002.event_expenses ENABLE ROW LEVEL SECURITY;

--
-- Name: event_staff; Type: ROW SECURITY; Schema: biz_002; Owner: -
--

ALTER TABLE biz_002.event_staff ENABLE ROW LEVEL SECURITY;

--
-- Name: events; Type: ROW SECURITY; Schema: biz_002; Owner: -
--

ALTER TABLE biz_002.events ENABLE ROW LEVEL SECURITY;

--
-- Name: interventions; Type: ROW SECURITY; Schema: biz_002; Owner: -
--

ALTER TABLE biz_002.interventions ENABLE ROW LEVEL SECURITY;

--
-- Name: documents operations_documents_select; Type: POLICY; Schema: biz_002; Owner: -
--

CREATE POLICY operations_documents_select ON biz_002.documents FOR SELECT USING ((biz_002.get_user_role() = 'operations'::text));


--
-- Name: entities operations_entities_select; Type: POLICY; Schema: biz_002; Owner: -
--

CREATE POLICY operations_entities_select ON biz_002.entities FOR SELECT USING ((biz_002.get_user_role() = 'operations'::text));


--
-- Name: events operations_events_all; Type: POLICY; Schema: biz_002; Owner: -
--

CREATE POLICY operations_events_all ON biz_002.events USING ((biz_002.get_user_role() = 'operations'::text));


--
-- Name: event_expenses operations_expenses_all; Type: POLICY; Schema: biz_002; Owner: -
--

CREATE POLICY operations_expenses_all ON biz_002.event_expenses USING ((biz_002.get_user_role() = 'operations'::text));


--
-- Name: interventions operations_interventions_select; Type: POLICY; Schema: biz_002; Owner: -
--

CREATE POLICY operations_interventions_select ON biz_002.interventions FOR SELECT USING ((biz_002.get_user_role() = 'operations'::text));


--
-- Name: catering_orders operations_orders_all; Type: POLICY; Schema: biz_002; Owner: -
--

CREATE POLICY operations_orders_all ON biz_002.catering_orders USING ((biz_002.get_user_role() = 'operations'::text));


--
-- Name: agent_signals operations_signals_select; Type: POLICY; Schema: biz_002; Owner: -
--

CREATE POLICY operations_signals_select ON biz_002.agent_signals FOR SELECT USING ((biz_002.get_user_role() = 'operations'::text));


--
-- Name: event_staff operations_staff_all; Type: POLICY; Schema: biz_002; Owner: -
--

CREATE POLICY operations_staff_all ON biz_002.event_staff USING ((biz_002.get_user_role() = 'operations'::text));


--
-- Name: audit_log owner_audit_select; Type: POLICY; Schema: biz_002; Owner: -
--

CREATE POLICY owner_audit_select ON biz_002.audit_log FOR SELECT USING ((biz_002.get_user_role() = 'owner'::text));


--
-- Name: documents owner_documents_all; Type: POLICY; Schema: biz_002; Owner: -
--

CREATE POLICY owner_documents_all ON biz_002.documents USING ((biz_002.get_user_role() = 'owner'::text));


--
-- Name: entities owner_entities_all; Type: POLICY; Schema: biz_002; Owner: -
--

CREATE POLICY owner_entities_all ON biz_002.entities USING ((biz_002.get_user_role() = 'owner'::text));


--
-- Name: events owner_events_all; Type: POLICY; Schema: biz_002; Owner: -
--

CREATE POLICY owner_events_all ON biz_002.events USING ((biz_002.get_user_role() = 'owner'::text));


--
-- Name: event_expenses owner_expenses_all; Type: POLICY; Schema: biz_002; Owner: -
--

CREATE POLICY owner_expenses_all ON biz_002.event_expenses USING ((biz_002.get_user_role() = 'owner'::text));


--
-- Name: interventions owner_interventions_all; Type: POLICY; Schema: biz_002; Owner: -
--

CREATE POLICY owner_interventions_all ON biz_002.interventions USING ((biz_002.get_user_role() = 'owner'::text));


--
-- Name: catering_orders owner_orders_all; Type: POLICY; Schema: biz_002; Owner: -
--

CREATE POLICY owner_orders_all ON biz_002.catering_orders USING ((biz_002.get_user_role() = 'owner'::text));


--
-- Name: quotes owner_quotes_all; Type: POLICY; Schema: biz_002; Owner: -
--

CREATE POLICY owner_quotes_all ON biz_002.quotes USING ((biz_002.get_user_role() = 'owner'::text));


--
-- Name: agent_signals owner_signals_all; Type: POLICY; Schema: biz_002; Owner: -
--

CREATE POLICY owner_signals_all ON biz_002.agent_signals USING ((biz_002.get_user_role() = 'owner'::text));


--
-- Name: event_staff owner_staff_all; Type: POLICY; Schema: biz_002; Owner: -
--

CREATE POLICY owner_staff_all ON biz_002.event_staff USING ((biz_002.get_user_role() = 'owner'::text));


--
-- Name: transactions owner_transactions_all; Type: POLICY; Schema: biz_002; Owner: -
--

CREATE POLICY owner_transactions_all ON biz_002.transactions USING ((biz_002.get_user_role() = 'owner'::text));


--
-- Name: quotes; Type: ROW SECURITY; Schema: biz_002; Owner: -
--

ALTER TABLE biz_002.quotes ENABLE ROW LEVEL SECURITY;

--
-- Name: documents sales_documents_select; Type: POLICY; Schema: biz_002; Owner: -
--

CREATE POLICY sales_documents_select ON biz_002.documents FOR SELECT USING ((biz_002.get_user_role() = 'sales'::text));


--
-- Name: entities sales_entities_all; Type: POLICY; Schema: biz_002; Owner: -
--

CREATE POLICY sales_entities_all ON biz_002.entities USING ((biz_002.get_user_role() = 'sales'::text));


--
-- Name: catering_orders sales_orders_select; Type: POLICY; Schema: biz_002; Owner: -
--

CREATE POLICY sales_orders_select ON biz_002.catering_orders FOR SELECT USING ((biz_002.get_user_role() = 'sales'::text));


--
-- Name: quotes sales_quotes_all; Type: POLICY; Schema: biz_002; Owner: -
--

CREATE POLICY sales_quotes_all ON biz_002.quotes USING ((biz_002.get_user_role() = 'sales'::text));


--
-- Name: agent_signals sales_signals_select; Type: POLICY; Schema: biz_002; Owner: -
--

CREATE POLICY sales_signals_select ON biz_002.agent_signals FOR SELECT USING ((biz_002.get_user_role() = 'sales'::text));


--
-- Name: transactions; Type: ROW SECURITY; Schema: biz_002; Owner: -
--

ALTER TABLE biz_002.transactions ENABLE ROW LEVEL SECURITY;

--
-- Name: SCHEMA ae_platform; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA ae_platform TO anon;
GRANT USAGE ON SCHEMA ae_platform TO authenticated;
GRANT USAGE ON SCHEMA ae_platform TO service_role;


--
-- Name: SCHEMA biz_001; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA biz_001 TO anon;
GRANT USAGE ON SCHEMA biz_001 TO authenticated;
GRANT USAGE ON SCHEMA biz_001 TO service_role;


--
-- Name: TABLE businesses; Type: ACL; Schema: ae_platform; Owner: -
--

GRANT SELECT ON TABLE ae_platform.businesses TO anon;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE ae_platform.businesses TO authenticated;


--
-- Name: TABLE ca_firm_clients; Type: ACL; Schema: ae_platform; Owner: -
--

GRANT SELECT ON TABLE ae_platform.ca_firm_clients TO anon;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE ae_platform.ca_firm_clients TO authenticated;


--
-- Name: TABLE ca_firms; Type: ACL; Schema: ae_platform; Owner: -
--

GRANT SELECT ON TABLE ae_platform.ca_firms TO anon;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE ae_platform.ca_firms TO authenticated;


--
-- Name: TABLE consents; Type: ACL; Schema: ae_platform; Owner: -
--

GRANT SELECT ON TABLE ae_platform.consents TO anon;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE ae_platform.consents TO authenticated;


--
-- Name: TABLE user_roles; Type: ACL; Schema: ae_platform; Owner: -
--

GRANT SELECT ON TABLE ae_platform.user_roles TO anon;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE ae_platform.user_roles TO authenticated;


--
-- Name: TABLE academic_calendar; Type: ACL; Schema: biz_001; Owner: -
--

GRANT SELECT ON TABLE biz_001.academic_calendar TO anon;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE biz_001.academic_calendar TO authenticated;


--
-- Name: TABLE agent_signals; Type: ACL; Schema: biz_001; Owner: -
--

GRANT SELECT ON TABLE biz_001.agent_signals TO anon;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE biz_001.agent_signals TO authenticated;


--
-- Name: TABLE agent_signals_archive; Type: ACL; Schema: biz_001; Owner: -
--

GRANT SELECT ON TABLE biz_001.agent_signals_archive TO anon;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE biz_001.agent_signals_archive TO authenticated;


--
-- Name: TABLE agent_signals_all; Type: ACL; Schema: biz_001; Owner: -
--

GRANT SELECT ON TABLE biz_001.agent_signals_all TO anon;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE biz_001.agent_signals_all TO authenticated;


--
-- Name: TABLE attendance; Type: ACL; Schema: biz_001; Owner: -
--

GRANT SELECT ON TABLE biz_001.attendance TO anon;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE biz_001.attendance TO authenticated;


--
-- Name: TABLE audit_log; Type: ACL; Schema: biz_001; Owner: -
--

GRANT SELECT ON TABLE biz_001.audit_log TO anon;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE biz_001.audit_log TO authenticated;


--
-- Name: TABLE documents; Type: ACL; Schema: biz_001; Owner: -
--

GRANT SELECT ON TABLE biz_001.documents TO anon;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE biz_001.documents TO authenticated;


--
-- Name: TABLE entities; Type: ACL; Schema: biz_001; Owner: -
--

GRANT SELECT ON TABLE biz_001.entities TO anon;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE biz_001.entities TO authenticated;


--
-- Name: TABLE events; Type: ACL; Schema: biz_001; Owner: -
--

GRANT SELECT ON TABLE biz_001.events TO anon;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE biz_001.events TO authenticated;


--
-- Name: TABLE fee_payments; Type: ACL; Schema: biz_001; Owner: -
--

GRANT SELECT ON TABLE biz_001.fee_payments TO anon;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE biz_001.fee_payments TO authenticated;


--
-- Name: TABLE fee_structure; Type: ACL; Schema: biz_001; Owner: -
--

GRANT SELECT ON TABLE biz_001.fee_structure TO anon;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE biz_001.fee_structure TO authenticated;


--
-- Name: TABLE homework; Type: ACL; Schema: biz_001; Owner: -
--

GRANT SELECT ON TABLE biz_001.homework TO anon;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE biz_001.homework TO authenticated;


--
-- Name: TABLE homework_submissions; Type: ACL; Schema: biz_001; Owner: -
--

GRANT SELECT ON TABLE biz_001.homework_submissions TO anon;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE biz_001.homework_submissions TO authenticated;


--
-- Name: TABLE house_points; Type: ACL; Schema: biz_001; Owner: -
--

GRANT SELECT ON TABLE biz_001.house_points TO anon;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE biz_001.house_points TO authenticated;


--
-- Name: TABLE interventions; Type: ACL; Schema: biz_001; Owner: -
--

GRANT SELECT ON TABLE biz_001.interventions TO anon;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE biz_001.interventions TO authenticated;


--
-- Name: TABLE marks; Type: ACL; Schema: biz_001; Owner: -
--

GRANT SELECT ON TABLE biz_001.marks TO anon;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE biz_001.marks TO authenticated;


--
-- Name: TABLE performance_observations; Type: ACL; Schema: biz_001; Owner: -
--

GRANT SELECT ON TABLE biz_001.performance_observations TO anon;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE biz_001.performance_observations TO authenticated;


--
-- Name: TABLE student_profiles; Type: ACL; Schema: biz_001; Owner: -
--

GRANT SELECT ON TABLE biz_001.student_profiles TO anon;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE biz_001.student_profiles TO authenticated;


--
-- Name: TABLE student_transport; Type: ACL; Schema: biz_001; Owner: -
--

GRANT SELECT ON TABLE biz_001.student_transport TO anon;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE biz_001.student_transport TO authenticated;


--
-- Name: TABLE subjects; Type: ACL; Schema: biz_001; Owner: -
--

GRANT SELECT ON TABLE biz_001.subjects TO anon;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE biz_001.subjects TO authenticated;


--
-- Name: TABLE teacher_assignments; Type: ACL; Schema: biz_001; Owner: -
--

GRANT SELECT ON TABLE biz_001.teacher_assignments TO anon;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE biz_001.teacher_assignments TO authenticated;


--
-- Name: TABLE teacher_profiles; Type: ACL; Schema: biz_001; Owner: -
--

GRANT SELECT ON TABLE biz_001.teacher_profiles TO anon;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE biz_001.teacher_profiles TO authenticated;


--
-- Name: TABLE teacher_subjects; Type: ACL; Schema: biz_001; Owner: -
--

GRANT SELECT ON TABLE biz_001.teacher_subjects TO anon;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE biz_001.teacher_subjects TO authenticated;


--
-- Name: TABLE teacher_subjects_backup_20260506; Type: ACL; Schema: biz_001; Owner: -
--

GRANT SELECT ON TABLE biz_001.teacher_subjects_backup_20260506 TO anon;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE biz_001.teacher_subjects_backup_20260506 TO authenticated;


--
-- Name: TABLE transactions; Type: ACL; Schema: biz_001; Owner: -
--

GRANT SELECT ON TABLE biz_001.transactions TO anon;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE biz_001.transactions TO authenticated;


--
-- Name: TABLE transport_routes; Type: ACL; Schema: biz_001; Owner: -
--

GRANT SELECT ON TABLE biz_001.transport_routes TO anon;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE biz_001.transport_routes TO authenticated;


--
-- Name: TABLE transport_stops; Type: ACL; Schema: biz_001; Owner: -
--

GRANT SELECT ON TABLE biz_001.transport_stops TO anon;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE biz_001.transport_stops TO authenticated;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: ae_platform; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA ae_platform GRANT SELECT ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA ae_platform GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES TO authenticated;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: biz_001; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA biz_001 GRANT SELECT ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA biz_001 GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES TO authenticated;


--
-- PostgreSQL database dump complete
--

\unrestrict 8fZtOydteTReWzzqqY4B5tLB8BhcDvmMezgj0HD62PyLkebpkRIqhnUm6QDmpxE

