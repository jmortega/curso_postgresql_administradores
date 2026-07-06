--
-- PostgreSQL database dump
--

\restrict NhjxLFPxF0YleGExx5pt7F6N2DC1rxIA1QtqNpK3tjg82BHsGPMYrHMHcwhq79o

-- Dumped from database version 15.18 (Debian 15.18-1.pgdg13+1)
-- Dumped by pg_dump version 15.18 (Debian 15.18-1.pgdg13+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: emaildeliverytype; Type: TYPE; Schema: public; Owner: analytics
--

CREATE TYPE public.emaildeliverytype AS ENUM (
    'attachment',
    'inline'
);


ALTER TYPE public.emaildeliverytype OWNER TO analytics;

--
-- Name: objecttype; Type: TYPE; Schema: public; Owner: analytics
--

CREATE TYPE public.objecttype AS ENUM (
    'query',
    'chart',
    'dashboard',
    'dataset'
);


ALTER TYPE public.objecttype OWNER TO analytics;

--
-- Name: sliceemailreportformat; Type: TYPE; Schema: public; Owner: analytics
--

CREATE TYPE public.sliceemailreportformat AS ENUM (
    'visualization',
    'data'
);


ALTER TYPE public.sliceemailreportformat OWNER TO analytics;

--
-- Name: tagtype; Type: TYPE; Schema: public; Owner: analytics
--

CREATE TYPE public.tagtype AS ENUM (
    'custom',
    'type',
    'owner',
    'favorited_by'
);


ALTER TYPE public.tagtype OWNER TO analytics;

--
-- Name: safe_to_jsonb(text); Type: FUNCTION; Schema: public; Owner: analytics
--

CREATE FUNCTION public.safe_to_jsonb(input text) RETURNS jsonb
    LANGUAGE plpgsql IMMUTABLE
    AS $$
BEGIN
  RETURN input::jsonb;
EXCEPTION WHEN invalid_text_representation THEN
  RETURN NULL;
END;
$$;


ALTER FUNCTION public.safe_to_jsonb(input text) OWNER TO analytics;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ab_group; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.ab_group (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    label character varying(150),
    description character varying(512)
);


ALTER TABLE public.ab_group OWNER TO analytics;

--
-- Name: ab_group_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.ab_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ab_group_id_seq OWNER TO analytics;

--
-- Name: ab_group_role; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.ab_group_role (
    id integer NOT NULL,
    group_id integer,
    role_id integer
);


ALTER TABLE public.ab_group_role OWNER TO analytics;

--
-- Name: ab_group_role_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.ab_group_role_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ab_group_role_id_seq OWNER TO analytics;

--
-- Name: ab_permission; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.ab_permission (
    id integer NOT NULL,
    name character varying(100) NOT NULL
);


ALTER TABLE public.ab_permission OWNER TO analytics;

--
-- Name: ab_permission_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.ab_permission_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ab_permission_id_seq OWNER TO analytics;

--
-- Name: ab_permission_view; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.ab_permission_view (
    id integer NOT NULL,
    permission_id integer,
    view_menu_id integer
);


ALTER TABLE public.ab_permission_view OWNER TO analytics;

--
-- Name: ab_permission_view_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.ab_permission_view_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ab_permission_view_id_seq OWNER TO analytics;

--
-- Name: ab_permission_view_role; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.ab_permission_view_role (
    id integer NOT NULL,
    permission_view_id integer,
    role_id integer
);


ALTER TABLE public.ab_permission_view_role OWNER TO analytics;

--
-- Name: ab_permission_view_role_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.ab_permission_view_role_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ab_permission_view_role_id_seq OWNER TO analytics;

--
-- Name: ab_register_user; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.ab_register_user (
    id integer NOT NULL,
    first_name character varying(64) NOT NULL,
    last_name character varying(64) NOT NULL,
    username character varying(128) NOT NULL,
    password character varying(256),
    email character varying(320) NOT NULL,
    registration_date timestamp without time zone,
    registration_hash character varying(256)
);


ALTER TABLE public.ab_register_user OWNER TO analytics;

--
-- Name: ab_register_user_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.ab_register_user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ab_register_user_id_seq OWNER TO analytics;

--
-- Name: ab_role; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.ab_role (
    id integer NOT NULL,
    name character varying(64) NOT NULL
);


ALTER TABLE public.ab_role OWNER TO analytics;

--
-- Name: ab_role_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.ab_role_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ab_role_id_seq OWNER TO analytics;

--
-- Name: ab_user; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.ab_user (
    id integer NOT NULL,
    first_name character varying(64) NOT NULL,
    last_name character varying(64) NOT NULL,
    username character varying(128) NOT NULL,
    password character varying(256),
    active boolean,
    email character varying(320) NOT NULL,
    last_login timestamp without time zone,
    login_count integer,
    fail_login_count integer,
    created_on timestamp without time zone,
    changed_on timestamp without time zone,
    created_by_fk integer,
    changed_by_fk integer
);


ALTER TABLE public.ab_user OWNER TO analytics;

--
-- Name: ab_user_group; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.ab_user_group (
    id integer NOT NULL,
    user_id integer,
    group_id integer
);


ALTER TABLE public.ab_user_group OWNER TO analytics;

--
-- Name: ab_user_group_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.ab_user_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ab_user_group_id_seq OWNER TO analytics;

--
-- Name: ab_user_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.ab_user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ab_user_id_seq OWNER TO analytics;

--
-- Name: ab_user_role; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.ab_user_role (
    id integer NOT NULL,
    user_id integer,
    role_id integer
);


ALTER TABLE public.ab_user_role OWNER TO analytics;

--
-- Name: ab_user_role_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.ab_user_role_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ab_user_role_id_seq OWNER TO analytics;

--
-- Name: ab_view_menu; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.ab_view_menu (
    id integer NOT NULL,
    name character varying(255) NOT NULL
);


ALTER TABLE public.ab_view_menu OWNER TO analytics;

--
-- Name: ab_view_menu_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.ab_view_menu_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ab_view_menu_id_seq OWNER TO analytics;

--
-- Name: alembic_version; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.alembic_version (
    version_num character varying(32) NOT NULL
);


ALTER TABLE public.alembic_version OWNER TO analytics;

--
-- Name: annotation; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.annotation (
    created_on timestamp without time zone,
    changed_on timestamp without time zone,
    id integer NOT NULL,
    start_dttm timestamp without time zone,
    end_dttm timestamp without time zone,
    layer_id integer,
    short_descr character varying(500),
    long_descr text,
    changed_by_fk integer,
    created_by_fk integer,
    json_metadata text
);


ALTER TABLE public.annotation OWNER TO analytics;

--
-- Name: annotation_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.annotation_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.annotation_id_seq OWNER TO analytics;

--
-- Name: annotation_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: analytics
--

ALTER SEQUENCE public.annotation_id_seq OWNED BY public.annotation.id;


--
-- Name: annotation_layer; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.annotation_layer (
    created_on timestamp without time zone,
    changed_on timestamp without time zone,
    id integer NOT NULL,
    name character varying(250),
    descr text,
    changed_by_fk integer,
    created_by_fk integer
);


ALTER TABLE public.annotation_layer OWNER TO analytics;

--
-- Name: annotation_layer_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.annotation_layer_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.annotation_layer_id_seq OWNER TO analytics;

--
-- Name: annotation_layer_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: analytics
--

ALTER SEQUENCE public.annotation_layer_id_seq OWNED BY public.annotation_layer.id;


--
-- Name: cache_keys; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.cache_keys (
    id integer NOT NULL,
    cache_key character varying(256) NOT NULL,
    cache_timeout integer,
    datasource_uid character varying(64) NOT NULL,
    created_on timestamp without time zone
);


ALTER TABLE public.cache_keys OWNER TO analytics;

--
-- Name: cache_keys_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.cache_keys_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cache_keys_id_seq OWNER TO analytics;

--
-- Name: cache_keys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: analytics
--

ALTER SEQUENCE public.cache_keys_id_seq OWNED BY public.cache_keys.id;


--
-- Name: clientes; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.clientes (
    id integer NOT NULL,
    nombre character varying(100),
    email character varying(150),
    ciudad character varying(80),
    fecha_alta date
);


ALTER TABLE public.clientes OWNER TO analytics;

--
-- Name: clientes_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.clientes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.clientes_id_seq OWNER TO analytics;

--
-- Name: clientes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: analytics
--

ALTER SEQUENCE public.clientes_id_seq OWNED BY public.clientes.id;


--
-- Name: css_templates; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.css_templates (
    created_on timestamp without time zone,
    changed_on timestamp without time zone,
    id integer NOT NULL,
    template_name character varying(250),
    css text,
    changed_by_fk integer,
    created_by_fk integer,
    uuid uuid
);


ALTER TABLE public.css_templates OWNER TO analytics;

--
-- Name: css_templates_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.css_templates_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.css_templates_id_seq OWNER TO analytics;

--
-- Name: css_templates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: analytics
--

ALTER SEQUENCE public.css_templates_id_seq OWNED BY public.css_templates.id;


--
-- Name: dashboard_roles; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.dashboard_roles (
    id integer NOT NULL,
    role_id integer NOT NULL,
    dashboard_id integer
);


ALTER TABLE public.dashboard_roles OWNER TO analytics;

--
-- Name: dashboard_roles_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.dashboard_roles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dashboard_roles_id_seq OWNER TO analytics;

--
-- Name: dashboard_roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: analytics
--

ALTER SEQUENCE public.dashboard_roles_id_seq OWNED BY public.dashboard_roles.id;


--
-- Name: dashboard_slices; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.dashboard_slices (
    id integer NOT NULL,
    dashboard_id integer,
    slice_id integer
);


ALTER TABLE public.dashboard_slices OWNER TO analytics;

--
-- Name: dashboard_slices_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.dashboard_slices_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dashboard_slices_id_seq OWNER TO analytics;

--
-- Name: dashboard_slices_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: analytics
--

ALTER SEQUENCE public.dashboard_slices_id_seq OWNED BY public.dashboard_slices.id;


--
-- Name: dashboard_user; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.dashboard_user (
    id integer NOT NULL,
    user_id integer,
    dashboard_id integer
);


ALTER TABLE public.dashboard_user OWNER TO analytics;

--
-- Name: dashboard_user_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.dashboard_user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dashboard_user_id_seq OWNER TO analytics;

--
-- Name: dashboard_user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: analytics
--

ALTER SEQUENCE public.dashboard_user_id_seq OWNED BY public.dashboard_user.id;


--
-- Name: dashboards; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.dashboards (
    created_on timestamp without time zone,
    changed_on timestamp without time zone,
    id integer NOT NULL,
    dashboard_title character varying(500),
    position_json text,
    created_by_fk integer,
    changed_by_fk integer,
    css text,
    description text,
    slug character varying(255),
    json_metadata text,
    published boolean,
    uuid uuid,
    certified_by text,
    certification_details text,
    is_managed_externally boolean DEFAULT false NOT NULL,
    external_url text,
    theme_id integer
);


ALTER TABLE public.dashboards OWNER TO analytics;

--
-- Name: dashboards_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.dashboards_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dashboards_id_seq OWNER TO analytics;

--
-- Name: dashboards_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: analytics
--

ALTER SEQUENCE public.dashboards_id_seq OWNED BY public.dashboards.id;


--
-- Name: database_user_oauth2_tokens; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.database_user_oauth2_tokens (
    created_on timestamp without time zone,
    changed_on timestamp without time zone,
    id integer NOT NULL,
    user_id integer NOT NULL,
    database_id integer NOT NULL,
    access_token bytea,
    access_token_expiration timestamp without time zone,
    refresh_token bytea,
    created_by_fk integer,
    changed_by_fk integer
);


ALTER TABLE public.database_user_oauth2_tokens OWNER TO analytics;

--
-- Name: database_user_oauth2_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.database_user_oauth2_tokens_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.database_user_oauth2_tokens_id_seq OWNER TO analytics;

--
-- Name: database_user_oauth2_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: analytics
--

ALTER SEQUENCE public.database_user_oauth2_tokens_id_seq OWNED BY public.database_user_oauth2_tokens.id;


--
-- Name: dbs; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.dbs (
    created_on timestamp without time zone,
    changed_on timestamp without time zone,
    id integer NOT NULL,
    database_name character varying(250) NOT NULL,
    sqlalchemy_uri character varying(1024) NOT NULL,
    created_by_fk integer,
    changed_by_fk integer,
    password bytea,
    cache_timeout integer,
    extra text,
    select_as_create_table_as boolean,
    allow_ctas boolean,
    expose_in_sqllab boolean,
    force_ctas_schema character varying(250),
    allow_run_async boolean,
    allow_dml boolean,
    verbose_name character varying(250),
    impersonate_user boolean,
    allow_file_upload boolean DEFAULT true NOT NULL,
    encrypted_extra bytea,
    server_cert bytea,
    allow_cvas boolean,
    uuid uuid,
    configuration_method character varying(255) DEFAULT 'sqlalchemy_form'::character varying,
    is_managed_externally boolean DEFAULT false NOT NULL,
    external_url text
);


ALTER TABLE public.dbs OWNER TO analytics;

--
-- Name: dbs_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.dbs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dbs_id_seq OWNER TO analytics;

--
-- Name: dbs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: analytics
--

ALTER SEQUENCE public.dbs_id_seq OWNED BY public.dbs.id;


--
-- Name: dynamic_plugin; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.dynamic_plugin (
    created_on timestamp without time zone,
    changed_on timestamp without time zone,
    id integer NOT NULL,
    name character varying(50) NOT NULL,
    key character varying(50) NOT NULL,
    bundle_url character varying(1000) NOT NULL,
    created_by_fk integer,
    changed_by_fk integer
);


ALTER TABLE public.dynamic_plugin OWNER TO analytics;

--
-- Name: dynamic_plugin_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.dynamic_plugin_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dynamic_plugin_id_seq OWNER TO analytics;

--
-- Name: dynamic_plugin_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: analytics
--

ALTER SEQUENCE public.dynamic_plugin_id_seq OWNED BY public.dynamic_plugin.id;


--
-- Name: embedded_dashboards; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.embedded_dashboards (
    created_on timestamp without time zone,
    changed_on timestamp without time zone,
    allow_domain_list text,
    uuid uuid,
    dashboard_id integer NOT NULL,
    changed_by_fk integer,
    created_by_fk integer
);


ALTER TABLE public.embedded_dashboards OWNER TO analytics;

--
-- Name: favstar; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.favstar (
    id integer NOT NULL,
    user_id integer,
    class_name character varying(50),
    obj_id integer,
    dttm timestamp without time zone,
    uuid uuid
);


ALTER TABLE public.favstar OWNER TO analytics;

--
-- Name: favstar_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.favstar_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.favstar_id_seq OWNER TO analytics;

--
-- Name: favstar_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: analytics
--

ALTER SEQUENCE public.favstar_id_seq OWNED BY public.favstar.id;


--
-- Name: key_value; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.key_value (
    id integer NOT NULL,
    resource character varying(32) NOT NULL,
    value bytea NOT NULL,
    uuid uuid,
    created_on timestamp without time zone,
    created_by_fk integer,
    changed_on timestamp without time zone,
    changed_by_fk integer,
    expires_on timestamp without time zone
);


ALTER TABLE public.key_value OWNER TO analytics;

--
-- Name: key_value_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.key_value_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.key_value_id_seq OWNER TO analytics;

--
-- Name: key_value_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: analytics
--

ALTER SEQUENCE public.key_value_id_seq OWNED BY public.key_value.id;


--
-- Name: keyvalue; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.keyvalue (
    id integer NOT NULL,
    value text NOT NULL
);


ALTER TABLE public.keyvalue OWNER TO analytics;

--
-- Name: keyvalue_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.keyvalue_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.keyvalue_id_seq OWNER TO analytics;

--
-- Name: keyvalue_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: analytics
--

ALTER SEQUENCE public.keyvalue_id_seq OWNED BY public.keyvalue.id;


--
-- Name: logs; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.logs (
    id integer NOT NULL,
    action character varying(512),
    user_id integer,
    json text,
    dttm timestamp without time zone,
    dashboard_id integer,
    slice_id integer,
    duration_ms integer,
    referrer character varying(1024)
);


ALTER TABLE public.logs OWNER TO analytics;

--
-- Name: logs_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.logs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.logs_id_seq OWNER TO analytics;

--
-- Name: logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: analytics
--

ALTER SEQUENCE public.logs_id_seq OWNED BY public.logs.id;


--
-- Name: query; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.query (
    id integer NOT NULL,
    client_id character varying(11) NOT NULL,
    database_id integer NOT NULL,
    tmp_table_name character varying(256),
    tab_name character varying(256),
    sql_editor_id character varying(256),
    user_id integer,
    status character varying(16),
    schema character varying(256),
    sql text,
    select_sql text,
    executed_sql text,
    "limit" integer,
    select_as_cta boolean,
    select_as_cta_used boolean,
    progress integer,
    rows integer,
    error_message text,
    start_time numeric(20,6),
    changed_on timestamp without time zone,
    end_time numeric(20,6),
    results_key character varying(64),
    start_running_time numeric(20,6),
    end_result_backend_time numeric(20,6),
    tracking_url text,
    extra_json text,
    tmp_schema_name character varying(256),
    ctas_method character varying(16),
    limiting_factor character varying(255) DEFAULT 'UNKNOWN'::character varying,
    catalog character varying(256)
);


ALTER TABLE public.query OWNER TO analytics;

--
-- Name: query_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.query_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.query_id_seq OWNER TO analytics;

--
-- Name: query_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: analytics
--

ALTER SEQUENCE public.query_id_seq OWNED BY public.query.id;


--
-- Name: report_execution_log; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.report_execution_log (
    id integer NOT NULL,
    scheduled_dttm timestamp without time zone NOT NULL,
    start_dttm timestamp without time zone,
    end_dttm timestamp without time zone,
    value double precision,
    value_row_json text,
    state character varying(50) NOT NULL,
    error_message text,
    report_schedule_id integer NOT NULL,
    uuid uuid
);


ALTER TABLE public.report_execution_log OWNER TO analytics;

--
-- Name: report_execution_log_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.report_execution_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.report_execution_log_id_seq OWNER TO analytics;

--
-- Name: report_execution_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: analytics
--

ALTER SEQUENCE public.report_execution_log_id_seq OWNED BY public.report_execution_log.id;


--
-- Name: report_recipient; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.report_recipient (
    id integer NOT NULL,
    type character varying(50) NOT NULL,
    recipient_config_json text,
    report_schedule_id integer NOT NULL,
    created_on timestamp without time zone,
    changed_on timestamp without time zone,
    created_by_fk integer,
    changed_by_fk integer
);


ALTER TABLE public.report_recipient OWNER TO analytics;

--
-- Name: report_recipient_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.report_recipient_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.report_recipient_id_seq OWNER TO analytics;

--
-- Name: report_recipient_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: analytics
--

ALTER SEQUENCE public.report_recipient_id_seq OWNED BY public.report_recipient.id;


--
-- Name: report_schedule; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.report_schedule (
    id integer NOT NULL,
    type character varying(50) NOT NULL,
    name character varying(150) NOT NULL,
    description text,
    context_markdown text,
    active boolean,
    crontab character varying(1000) NOT NULL,
    sql text,
    chart_id integer,
    dashboard_id integer,
    database_id integer,
    last_eval_dttm timestamp without time zone,
    last_state character varying(50),
    last_value double precision,
    last_value_row_json text,
    validator_type character varying(100),
    validator_config_json text,
    log_retention integer,
    grace_period integer,
    created_on timestamp without time zone,
    changed_on timestamp without time zone,
    created_by_fk integer,
    changed_by_fk integer,
    working_timeout integer,
    report_format character varying(50) DEFAULT 'PNG'::character varying,
    creation_method character varying(255) DEFAULT 'alerts_reports'::character varying,
    timezone character varying(100) DEFAULT 'UTC'::character varying NOT NULL,
    extra_json text NOT NULL,
    force_screenshot boolean,
    custom_width integer,
    custom_height integer,
    email_subject character varying(255)
);


ALTER TABLE public.report_schedule OWNER TO analytics;

--
-- Name: report_schedule_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.report_schedule_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.report_schedule_id_seq OWNER TO analytics;

--
-- Name: report_schedule_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: analytics
--

ALTER SEQUENCE public.report_schedule_id_seq OWNED BY public.report_schedule.id;


--
-- Name: report_schedule_user; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.report_schedule_user (
    id integer NOT NULL,
    user_id integer NOT NULL,
    report_schedule_id integer NOT NULL
);


ALTER TABLE public.report_schedule_user OWNER TO analytics;

--
-- Name: report_schedule_user_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.report_schedule_user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.report_schedule_user_id_seq OWNER TO analytics;

--
-- Name: report_schedule_user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: analytics
--

ALTER SEQUENCE public.report_schedule_user_id_seq OWNED BY public.report_schedule_user.id;


--
-- Name: rls_filter_roles; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.rls_filter_roles (
    id integer NOT NULL,
    role_id integer NOT NULL,
    rls_filter_id integer
);


ALTER TABLE public.rls_filter_roles OWNER TO analytics;

--
-- Name: rls_filter_roles_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.rls_filter_roles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.rls_filter_roles_id_seq OWNER TO analytics;

--
-- Name: rls_filter_roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: analytics
--

ALTER SEQUENCE public.rls_filter_roles_id_seq OWNED BY public.rls_filter_roles.id;


--
-- Name: rls_filter_tables; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.rls_filter_tables (
    id integer NOT NULL,
    table_id integer,
    rls_filter_id integer
);


ALTER TABLE public.rls_filter_tables OWNER TO analytics;

--
-- Name: rls_filter_tables_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.rls_filter_tables_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.rls_filter_tables_id_seq OWNER TO analytics;

--
-- Name: rls_filter_tables_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: analytics
--

ALTER SEQUENCE public.rls_filter_tables_id_seq OWNED BY public.rls_filter_tables.id;


--
-- Name: row_level_security_filters; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.row_level_security_filters (
    created_on timestamp without time zone,
    changed_on timestamp without time zone,
    id integer NOT NULL,
    clause text NOT NULL,
    created_by_fk integer,
    changed_by_fk integer,
    filter_type character varying(255),
    group_key character varying(255),
    name character varying(255) NOT NULL,
    description text
);


ALTER TABLE public.row_level_security_filters OWNER TO analytics;

--
-- Name: row_level_security_filters_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.row_level_security_filters_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.row_level_security_filters_id_seq OWNER TO analytics;

--
-- Name: row_level_security_filters_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: analytics
--

ALTER SEQUENCE public.row_level_security_filters_id_seq OWNED BY public.row_level_security_filters.id;


--
-- Name: saved_query; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.saved_query (
    created_on timestamp without time zone,
    changed_on timestamp without time zone,
    id integer NOT NULL,
    user_id integer,
    db_id integer,
    label character varying(256),
    schema character varying(128),
    sql text,
    description text,
    changed_by_fk integer,
    created_by_fk integer,
    extra_json text,
    last_run timestamp without time zone,
    rows integer,
    uuid uuid,
    template_parameters text,
    catalog character varying(256)
);


ALTER TABLE public.saved_query OWNER TO analytics;

--
-- Name: saved_query_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.saved_query_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.saved_query_id_seq OWNER TO analytics;

--
-- Name: saved_query_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: analytics
--

ALTER SEQUENCE public.saved_query_id_seq OWNED BY public.saved_query.id;


--
-- Name: slice_user; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.slice_user (
    id integer NOT NULL,
    user_id integer,
    slice_id integer
);


ALTER TABLE public.slice_user OWNER TO analytics;

--
-- Name: slice_user_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.slice_user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.slice_user_id_seq OWNER TO analytics;

--
-- Name: slice_user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: analytics
--

ALTER SEQUENCE public.slice_user_id_seq OWNED BY public.slice_user.id;


--
-- Name: slices; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.slices (
    created_on timestamp without time zone,
    changed_on timestamp without time zone,
    id integer NOT NULL,
    slice_name character varying(250),
    druid_datasource_id integer,
    table_id integer,
    datasource_type character varying(200),
    datasource_name character varying(2000),
    viz_type character varying(250),
    params text,
    created_by_fk integer,
    changed_by_fk integer,
    description text,
    cache_timeout integer,
    perm character varying(2000),
    datasource_id integer,
    schema_perm character varying(1000),
    uuid uuid,
    query_context text,
    last_saved_at timestamp without time zone,
    last_saved_by_fk integer,
    certified_by text,
    certification_details text,
    is_managed_externally boolean DEFAULT false NOT NULL,
    external_url text,
    catalog_perm character varying(1000),
    CONSTRAINT ck_chart_datasource CHECK (((datasource_type)::text = 'table'::text))
);


ALTER TABLE public.slices OWNER TO analytics;

--
-- Name: slices_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.slices_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.slices_id_seq OWNER TO analytics;

--
-- Name: slices_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: analytics
--

ALTER SEQUENCE public.slices_id_seq OWNED BY public.slices.id;


--
-- Name: sql_metrics; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.sql_metrics (
    created_on timestamp without time zone,
    changed_on timestamp without time zone,
    id integer NOT NULL,
    metric_name character varying(255) NOT NULL,
    verbose_name character varying(1024),
    metric_type character varying(32),
    table_id integer,
    expression text NOT NULL,
    description text,
    created_by_fk integer,
    changed_by_fk integer,
    d3format character varying(128),
    warning_text text,
    extra text,
    uuid uuid,
    currency jsonb
);


ALTER TABLE public.sql_metrics OWNER TO analytics;

--
-- Name: sql_metrics_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.sql_metrics_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sql_metrics_id_seq OWNER TO analytics;

--
-- Name: sql_metrics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: analytics
--

ALTER SEQUENCE public.sql_metrics_id_seq OWNED BY public.sql_metrics.id;


--
-- Name: sqlatable_user; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.sqlatable_user (
    id integer NOT NULL,
    user_id integer,
    table_id integer
);


ALTER TABLE public.sqlatable_user OWNER TO analytics;

--
-- Name: sqlatable_user_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.sqlatable_user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sqlatable_user_id_seq OWNER TO analytics;

--
-- Name: sqlatable_user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: analytics
--

ALTER SEQUENCE public.sqlatable_user_id_seq OWNED BY public.sqlatable_user.id;


--
-- Name: ssh_tunnels; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.ssh_tunnels (
    created_on timestamp without time zone,
    changed_on timestamp without time zone,
    created_by_fk integer,
    changed_by_fk integer,
    extra_json text,
    uuid uuid,
    id integer NOT NULL,
    database_id integer,
    server_address character varying(256),
    server_port integer,
    username bytea,
    password bytea,
    private_key bytea,
    private_key_password bytea
);


ALTER TABLE public.ssh_tunnels OWNER TO analytics;

--
-- Name: ssh_tunnels_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.ssh_tunnels_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ssh_tunnels_id_seq OWNER TO analytics;

--
-- Name: ssh_tunnels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: analytics
--

ALTER SEQUENCE public.ssh_tunnels_id_seq OWNED BY public.ssh_tunnels.id;


--
-- Name: tab_state; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.tab_state (
    created_on timestamp without time zone,
    changed_on timestamp without time zone,
    extra_json text,
    id integer NOT NULL,
    user_id integer,
    label character varying(256),
    active boolean,
    database_id integer,
    schema character varying(256),
    sql text,
    query_limit integer,
    latest_query_id character varying(11),
    autorun boolean NOT NULL,
    template_params text,
    created_by_fk integer,
    changed_by_fk integer,
    hide_left_bar boolean DEFAULT false NOT NULL,
    saved_query_id integer,
    catalog character varying(256)
);


ALTER TABLE public.tab_state OWNER TO analytics;

--
-- Name: tab_state_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.tab_state_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tab_state_id_seq OWNER TO analytics;

--
-- Name: tab_state_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: analytics
--

ALTER SEQUENCE public.tab_state_id_seq OWNED BY public.tab_state.id;


--
-- Name: table_columns; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.table_columns (
    created_on timestamp without time zone,
    changed_on timestamp without time zone,
    id integer NOT NULL,
    table_id integer,
    column_name character varying(255) NOT NULL,
    is_dttm boolean,
    is_active boolean,
    type text,
    groupby boolean,
    filterable boolean,
    description text,
    created_by_fk integer,
    changed_by_fk integer,
    expression text,
    verbose_name character varying(1024),
    python_date_format character varying(255),
    uuid uuid,
    extra text,
    advanced_data_type character varying(255),
    datetime_format character varying(100)
);


ALTER TABLE public.table_columns OWNER TO analytics;

--
-- Name: table_columns_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.table_columns_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.table_columns_id_seq OWNER TO analytics;

--
-- Name: table_columns_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: analytics
--

ALTER SEQUENCE public.table_columns_id_seq OWNED BY public.table_columns.id;


--
-- Name: table_schema; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.table_schema (
    created_on timestamp without time zone,
    changed_on timestamp without time zone,
    extra_json text,
    id integer NOT NULL,
    tab_state_id integer,
    database_id integer NOT NULL,
    schema character varying(256),
    "table" character varying(256),
    description text,
    expanded boolean,
    created_by_fk integer,
    changed_by_fk integer,
    catalog character varying(256)
);


ALTER TABLE public.table_schema OWNER TO analytics;

--
-- Name: table_schema_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.table_schema_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.table_schema_id_seq OWNER TO analytics;

--
-- Name: table_schema_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: analytics
--

ALTER SEQUENCE public.table_schema_id_seq OWNED BY public.table_schema.id;


--
-- Name: tables; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.tables (
    created_on timestamp without time zone,
    changed_on timestamp without time zone,
    id integer NOT NULL,
    table_name character varying(250) NOT NULL,
    main_dttm_col character varying(250),
    default_endpoint text,
    database_id integer NOT NULL,
    created_by_fk integer,
    changed_by_fk integer,
    "offset" integer,
    description text,
    is_featured boolean,
    cache_timeout integer,
    schema character varying(255),
    sql text,
    params text,
    perm character varying(1000),
    filter_select_enabled boolean,
    fetch_values_predicate text,
    is_sqllab_view boolean DEFAULT false,
    template_params text,
    schema_perm character varying(1000),
    extra text,
    uuid uuid,
    is_managed_externally boolean DEFAULT false NOT NULL,
    external_url text,
    normalize_columns boolean DEFAULT false,
    always_filter_main_dttm boolean DEFAULT false,
    catalog character varying(256),
    catalog_perm character varying(1000),
    folders json,
    currency_code_column character varying(250)
);


ALTER TABLE public.tables OWNER TO analytics;

--
-- Name: tables_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.tables_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tables_id_seq OWNER TO analytics;

--
-- Name: tables_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: analytics
--

ALTER SEQUENCE public.tables_id_seq OWNED BY public.tables.id;


--
-- Name: tag; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.tag (
    created_on timestamp without time zone,
    changed_on timestamp without time zone,
    id integer NOT NULL,
    name character varying(250),
    type character varying,
    created_by_fk integer,
    changed_by_fk integer,
    description text
);


ALTER TABLE public.tag OWNER TO analytics;

--
-- Name: tag_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.tag_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tag_id_seq OWNER TO analytics;

--
-- Name: tag_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: analytics
--

ALTER SEQUENCE public.tag_id_seq OWNED BY public.tag.id;


--
-- Name: tagged_object; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.tagged_object (
    created_on timestamp without time zone,
    changed_on timestamp without time zone,
    id integer NOT NULL,
    tag_id integer,
    object_id integer,
    object_type character varying,
    created_by_fk integer,
    changed_by_fk integer
);


ALTER TABLE public.tagged_object OWNER TO analytics;

--
-- Name: tagged_object_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.tagged_object_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tagged_object_id_seq OWNER TO analytics;

--
-- Name: tagged_object_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: analytics
--

ALTER SEQUENCE public.tagged_object_id_seq OWNED BY public.tagged_object.id;


--
-- Name: task_subscribers; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.task_subscribers (
    id integer NOT NULL,
    task_id integer NOT NULL,
    user_id integer NOT NULL,
    subscribed_at timestamp without time zone NOT NULL,
    created_on timestamp without time zone,
    created_by_fk integer,
    changed_on timestamp without time zone,
    changed_by_fk integer
);


ALTER TABLE public.task_subscribers OWNER TO analytics;

--
-- Name: task_subscribers_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.task_subscribers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.task_subscribers_id_seq OWNER TO analytics;

--
-- Name: task_subscribers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: analytics
--

ALTER SEQUENCE public.task_subscribers_id_seq OWNED BY public.task_subscribers.id;


--
-- Name: tasks; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.tasks (
    id integer NOT NULL,
    uuid uuid NOT NULL,
    task_key character varying(256) NOT NULL,
    task_type character varying(100) NOT NULL,
    task_name character varying(256),
    scope character varying(20) DEFAULT 'private'::character varying NOT NULL,
    status character varying(50) NOT NULL,
    dedup_key character varying(64) NOT NULL,
    created_on timestamp without time zone,
    changed_on timestamp without time zone,
    created_by_fk integer,
    changed_by_fk integer,
    started_at timestamp without time zone,
    ended_at timestamp without time zone,
    user_id integer,
    payload text,
    properties text
);


ALTER TABLE public.tasks OWNER TO analytics;

--
-- Name: tasks_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.tasks_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tasks_id_seq OWNER TO analytics;

--
-- Name: tasks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: analytics
--

ALTER SEQUENCE public.tasks_id_seq OWNED BY public.tasks.id;


--
-- Name: themes; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.themes (
    uuid uuid,
    created_on timestamp without time zone,
    changed_on timestamp without time zone,
    id integer NOT NULL,
    theme_name character varying(250),
    json_data text,
    is_system boolean NOT NULL,
    created_by_fk integer,
    changed_by_fk integer,
    is_system_default boolean NOT NULL,
    is_system_dark boolean NOT NULL
);


ALTER TABLE public.themes OWNER TO analytics;

--
-- Name: themes_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.themes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.themes_id_seq OWNER TO analytics;

--
-- Name: themes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: analytics
--

ALTER SEQUENCE public.themes_id_seq OWNED BY public.themes.id;


--
-- Name: user_attribute; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.user_attribute (
    created_on timestamp without time zone,
    changed_on timestamp without time zone,
    id integer NOT NULL,
    user_id integer,
    welcome_dashboard_id integer,
    created_by_fk integer,
    changed_by_fk integer,
    avatar_url character varying(100)
);


ALTER TABLE public.user_attribute OWNER TO analytics;

--
-- Name: user_attribute_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.user_attribute_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.user_attribute_id_seq OWNER TO analytics;

--
-- Name: user_attribute_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: analytics
--

ALTER SEQUENCE public.user_attribute_id_seq OWNED BY public.user_attribute.id;


--
-- Name: user_favorite_tag; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.user_favorite_tag (
    user_id integer NOT NULL,
    tag_id integer NOT NULL
);


ALTER TABLE public.user_favorite_tag OWNER TO analytics;

--
-- Name: ventas; Type: TABLE; Schema: public; Owner: analytics
--

CREATE TABLE public.ventas (
    id integer NOT NULL,
    fecha date NOT NULL,
    producto character varying(100),
    categoria character varying(50),
    cantidad integer,
    precio numeric(10,2),
    region character varying(50)
);


ALTER TABLE public.ventas OWNER TO analytics;

--
-- Name: ventas_id_seq; Type: SEQUENCE; Schema: public; Owner: analytics
--

CREATE SEQUENCE public.ventas_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ventas_id_seq OWNER TO analytics;

--
-- Name: ventas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: analytics
--

ALTER SEQUENCE public.ventas_id_seq OWNED BY public.ventas.id;


--
-- Name: annotation id; Type: DEFAULT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.annotation ALTER COLUMN id SET DEFAULT nextval('public.annotation_id_seq'::regclass);


--
-- Name: annotation_layer id; Type: DEFAULT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.annotation_layer ALTER COLUMN id SET DEFAULT nextval('public.annotation_layer_id_seq'::regclass);


--
-- Name: cache_keys id; Type: DEFAULT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.cache_keys ALTER COLUMN id SET DEFAULT nextval('public.cache_keys_id_seq'::regclass);


--
-- Name: clientes id; Type: DEFAULT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.clientes ALTER COLUMN id SET DEFAULT nextval('public.clientes_id_seq'::regclass);


--
-- Name: css_templates id; Type: DEFAULT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.css_templates ALTER COLUMN id SET DEFAULT nextval('public.css_templates_id_seq'::regclass);


--
-- Name: dashboard_roles id; Type: DEFAULT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.dashboard_roles ALTER COLUMN id SET DEFAULT nextval('public.dashboard_roles_id_seq'::regclass);


--
-- Name: dashboard_slices id; Type: DEFAULT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.dashboard_slices ALTER COLUMN id SET DEFAULT nextval('public.dashboard_slices_id_seq'::regclass);


--
-- Name: dashboard_user id; Type: DEFAULT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.dashboard_user ALTER COLUMN id SET DEFAULT nextval('public.dashboard_user_id_seq'::regclass);


--
-- Name: dashboards id; Type: DEFAULT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.dashboards ALTER COLUMN id SET DEFAULT nextval('public.dashboards_id_seq'::regclass);


--
-- Name: database_user_oauth2_tokens id; Type: DEFAULT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.database_user_oauth2_tokens ALTER COLUMN id SET DEFAULT nextval('public.database_user_oauth2_tokens_id_seq'::regclass);


--
-- Name: dbs id; Type: DEFAULT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.dbs ALTER COLUMN id SET DEFAULT nextval('public.dbs_id_seq'::regclass);


--
-- Name: dynamic_plugin id; Type: DEFAULT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.dynamic_plugin ALTER COLUMN id SET DEFAULT nextval('public.dynamic_plugin_id_seq'::regclass);


--
-- Name: favstar id; Type: DEFAULT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.favstar ALTER COLUMN id SET DEFAULT nextval('public.favstar_id_seq'::regclass);


--
-- Name: key_value id; Type: DEFAULT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.key_value ALTER COLUMN id SET DEFAULT nextval('public.key_value_id_seq'::regclass);


--
-- Name: keyvalue id; Type: DEFAULT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.keyvalue ALTER COLUMN id SET DEFAULT nextval('public.keyvalue_id_seq'::regclass);


--
-- Name: logs id; Type: DEFAULT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.logs ALTER COLUMN id SET DEFAULT nextval('public.logs_id_seq'::regclass);


--
-- Name: query id; Type: DEFAULT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.query ALTER COLUMN id SET DEFAULT nextval('public.query_id_seq'::regclass);


--
-- Name: report_execution_log id; Type: DEFAULT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.report_execution_log ALTER COLUMN id SET DEFAULT nextval('public.report_execution_log_id_seq'::regclass);


--
-- Name: report_recipient id; Type: DEFAULT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.report_recipient ALTER COLUMN id SET DEFAULT nextval('public.report_recipient_id_seq'::regclass);


--
-- Name: report_schedule id; Type: DEFAULT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.report_schedule ALTER COLUMN id SET DEFAULT nextval('public.report_schedule_id_seq'::regclass);


--
-- Name: report_schedule_user id; Type: DEFAULT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.report_schedule_user ALTER COLUMN id SET DEFAULT nextval('public.report_schedule_user_id_seq'::regclass);


--
-- Name: rls_filter_roles id; Type: DEFAULT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.rls_filter_roles ALTER COLUMN id SET DEFAULT nextval('public.rls_filter_roles_id_seq'::regclass);


--
-- Name: rls_filter_tables id; Type: DEFAULT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.rls_filter_tables ALTER COLUMN id SET DEFAULT nextval('public.rls_filter_tables_id_seq'::regclass);


--
-- Name: row_level_security_filters id; Type: DEFAULT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.row_level_security_filters ALTER COLUMN id SET DEFAULT nextval('public.row_level_security_filters_id_seq'::regclass);


--
-- Name: saved_query id; Type: DEFAULT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.saved_query ALTER COLUMN id SET DEFAULT nextval('public.saved_query_id_seq'::regclass);


--
-- Name: slice_user id; Type: DEFAULT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.slice_user ALTER COLUMN id SET DEFAULT nextval('public.slice_user_id_seq'::regclass);


--
-- Name: slices id; Type: DEFAULT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.slices ALTER COLUMN id SET DEFAULT nextval('public.slices_id_seq'::regclass);


--
-- Name: sql_metrics id; Type: DEFAULT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.sql_metrics ALTER COLUMN id SET DEFAULT nextval('public.sql_metrics_id_seq'::regclass);


--
-- Name: sqlatable_user id; Type: DEFAULT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.sqlatable_user ALTER COLUMN id SET DEFAULT nextval('public.sqlatable_user_id_seq'::regclass);


--
-- Name: ssh_tunnels id; Type: DEFAULT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.ssh_tunnels ALTER COLUMN id SET DEFAULT nextval('public.ssh_tunnels_id_seq'::regclass);


--
-- Name: tab_state id; Type: DEFAULT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.tab_state ALTER COLUMN id SET DEFAULT nextval('public.tab_state_id_seq'::regclass);


--
-- Name: table_columns id; Type: DEFAULT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.table_columns ALTER COLUMN id SET DEFAULT nextval('public.table_columns_id_seq'::regclass);


--
-- Name: table_schema id; Type: DEFAULT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.table_schema ALTER COLUMN id SET DEFAULT nextval('public.table_schema_id_seq'::regclass);


--
-- Name: tables id; Type: DEFAULT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.tables ALTER COLUMN id SET DEFAULT nextval('public.tables_id_seq'::regclass);


--
-- Name: tag id; Type: DEFAULT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.tag ALTER COLUMN id SET DEFAULT nextval('public.tag_id_seq'::regclass);


--
-- Name: tagged_object id; Type: DEFAULT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.tagged_object ALTER COLUMN id SET DEFAULT nextval('public.tagged_object_id_seq'::regclass);


--
-- Name: task_subscribers id; Type: DEFAULT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.task_subscribers ALTER COLUMN id SET DEFAULT nextval('public.task_subscribers_id_seq'::regclass);


--
-- Name: tasks id; Type: DEFAULT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.tasks ALTER COLUMN id SET DEFAULT nextval('public.tasks_id_seq'::regclass);


--
-- Name: themes id; Type: DEFAULT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.themes ALTER COLUMN id SET DEFAULT nextval('public.themes_id_seq'::regclass);


--
-- Name: user_attribute id; Type: DEFAULT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.user_attribute ALTER COLUMN id SET DEFAULT nextval('public.user_attribute_id_seq'::regclass);


--
-- Name: ventas id; Type: DEFAULT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.ventas ALTER COLUMN id SET DEFAULT nextval('public.ventas_id_seq'::regclass);


--
-- Data for Name: ab_group; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.ab_group (id, name, label, description) FROM stdin;
\.


--
-- Data for Name: ab_group_role; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.ab_group_role (id, group_id, role_id) FROM stdin;
\.


--
-- Data for Name: ab_permission; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.ab_permission (id, name) FROM stdin;
1	can_read
2	can_write
8	can_upload
9	can_this_form_post
10	can_this_form_get
11	can_list
12	can_download
13	can_show
14	can_delete
15	can_edit
16	can_add
17	can_userinfo
18	resetmypassword
19	resetpasswords
20	userinfoedit
21	copyrole
22	can_info
23	can_get
24	can_add_role_permissions
25	can_post
26	can_list_role_permissions
27	can_update_role_users
28	can_put
29	can_update_role_groups
30	can_invalidate
31	can_warm_up_cache
32	can_export
33	can_cache_dashboard_screenshot
34	can_export_as_example
35	can_delete_embedded
36	can_put_chart_customizations
37	can_set_embedded
38	can_get_embedded
39	can_duplicate
40	can_get_or_create_dataset
41	can_get_drill_info
42	can_validate_expression
43	can_get_column_values
44	can_import_
45	can_bulk_create
46	can_get_results
47	can_export_streaming_csv
48	can_estimate_query_cost
49	can_format_sql
50	can_export_csv
51	can_execute_sql_query
52	can_recent_activity
53	can_query_form_data
54	can_time_range
55	can_query
56	can_samples
57	can_external_metadata_by_name
58	can_external_metadata
59	can_save
60	can_explore_json
61	can_sqllab_history
62	can_explore
63	can_dashboard_permalink
64	can_language_pack
65	can_file_handler
66	can_log
67	can_fetch_datasource_metadata
68	can_slice
69	can_dashboard
70	can_expanded
71	can_delete_query
72	can_activate
73	can_migrate_query
74	can_tags
75	can_list_roles
76	can_grant_guest_token
77	menu_access
78	all_datasource_access
79	all_database_access
80	all_query_access
81	can_csv
82	can_share_dashboard
83	can_share_chart
84	can_sqllab
85	can_view_query
86	can_view_chart_as_table
87	can_drill
88	can_tag
89	database_access
90	catalog_access
91	schema_access
92	datasource_access
\.


--
-- Data for Name: ab_permission_view; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.ab_permission_view (id, permission_id, view_menu_id) FROM stdin;
1	1	1
2	2	1
3	1	2
4	2	2
5	1	3
6	2	3
7	1	4
8	2	4
9	1	5
10	2	5
11	1	6
12	2	6
13	1	7
14	2	7
15	1	8
16	2	8
17	1	9
18	2	9
19	1	10
25	8	9
26	9	17
27	10	17
28	9	18
29	10	18
30	9	19
31	10	19
32	11	21
33	12	21
34	13	21
35	14	21
36	15	21
37	16	21
38	17	21
39	18	21
40	19	21
41	20	21
42	11	22
43	12	22
44	13	22
45	14	22
46	15	22
47	16	22
48	21	22
49	11	23
50	12	23
51	13	23
52	14	23
53	15	23
54	16	23
55	22	24
56	23	24
57	24	25
58	25	25
59	26	25
60	27	25
61	23	25
62	28	25
63	14	25
64	29	25
65	22	25
66	25	26
67	22	26
68	23	26
69	14	26
70	28	26
71	25	27
72	22	27
73	23	27
74	14	27
75	28	27
76	25	28
77	22	28
78	23	28
79	14	28
80	28	28
81	25	29
82	22	29
83	23	29
84	14	29
85	28	29
86	23	30
87	13	31
88	23	32
89	11	33
90	1	34
91	1	35
92	30	36
93	31	4
94	32	4
95	1	37
96	32	37
97	2	37
98	1	38
99	2	38
100	1	40
101	2	40
102	1	41
103	2	41
104	33	8
105	32	8
106	34	8
107	35	8
108	36	8
109	37	8
110	38	8
111	32	9
112	39	6
113	40	6
114	32	6
115	41	6
116	31	6
117	42	42
118	43	42
119	1	43
120	1	44
121	1	45
122	2	45
123	1	46
124	2	46
125	44	47
126	32	47
127	1	48
128	2	48
129	32	1
130	45	49
131	1	49
132	2	49
133	46	50
134	47	50
135	48	50
136	49	50
137	50	50
138	51	50
139	1	50
140	1	51
141	2	51
142	52	7
143	1	52
144	11	53
145	12	53
146	13	53
147	15	53
148	16	53
149	2	53
150	1	54
151	1	55
152	53	56
153	54	56
154	55	56
155	56	42
156	57	42
157	23	42
158	58	42
159	59	42
160	11	1
161	60	58
162	61	58
163	62	58
164	63	58
165	64	58
166	31	58
167	65	58
168	66	58
169	67	58
170	68	58
171	69	58
172	70	59
173	25	59
174	14	59
175	71	60
176	72	60
177	25	60
178	23	60
179	14	60
180	73	60
181	28	60
182	11	61
183	74	62
184	75	64
185	1	65
186	11	66
187	13	66
188	14	66
189	15	66
190	16	66
191	1	67
192	76	67
193	1	68
194	77	69
195	77	70
196	77	71
197	77	72
198	77	73
199	77	74
200	77	48
201	77	75
202	77	76
203	77	77
204	77	78
205	77	79
206	77	80
207	77	81
208	77	82
209	77	83
210	77	84
211	77	54
212	77	85
213	77	61
214	77	86
215	77	87
216	77	88
217	77	89
218	77	90
219	77	91
220	78	92
221	79	93
222	80	94
223	81	58
224	82	58
225	83	58
226	84	58
227	85	8
228	86	8
229	87	8
230	88	4
231	88	8
232	89	95
233	89	96
234	90	97
235	91	98
236	91	99
237	92	100
238	91	101
239	90	102
\.


--
-- Data for Name: ab_permission_view_role; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.ab_permission_view_role (id, permission_view_id, role_id) FROM stdin;
1	26	1
2	27	1
3	28	1
4	29	1
5	30	1
6	31	1
7	32	1
8	33	1
9	34	1
10	35	1
11	36	1
12	37	1
13	38	1
14	39	1
15	40	1
16	41	1
17	42	1
18	43	1
19	44	1
20	45	1
21	46	1
22	47	1
23	48	1
24	49	1
25	50	1
26	51	1
27	52	1
28	53	1
29	54	1
30	55	1
31	56	1
32	57	1
33	58	1
34	59	1
35	60	1
36	61	1
37	62	1
38	63	1
39	64	1
40	65	1
41	66	1
42	67	1
43	68	1
44	69	1
45	70	1
46	71	1
47	72	1
48	73	1
49	74	1
50	75	1
51	76	1
52	77	1
53	78	1
54	79	1
55	80	1
56	81	1
57	82	1
58	83	1
59	84	1
60	85	1
61	86	1
62	87	1
63	88	1
64	9	1
65	10	1
66	89	1
67	90	1
68	91	1
69	92	1
70	93	1
71	94	1
72	7	1
73	8	1
74	3	1
75	4	1
76	95	1
77	96	1
78	97	1
79	98	1
80	99	1
81	100	1
82	101	1
83	102	1
84	103	1
85	104	1
86	105	1
87	106	1
88	107	1
89	108	1
90	109	1
91	110	1
92	15	1
93	16	1
94	111	1
95	17	1
96	18	1
97	25	1
98	112	1
99	113	1
100	114	1
101	115	1
102	116	1
103	11	1
104	12	1
105	117	1
106	118	1
107	119	1
108	120	1
109	121	1
110	122	1
111	123	1
112	124	1
113	125	1
114	126	1
115	19	1
116	5	1
117	6	1
118	127	1
119	128	1
120	129	1
121	1	1
122	2	1
123	130	1
124	131	1
125	132	1
126	133	1
127	134	1
128	135	1
129	136	1
130	137	1
131	138	1
132	139	1
133	140	1
134	141	1
135	142	1
136	13	1
137	14	1
138	143	1
139	144	1
140	145	1
141	146	1
142	147	1
143	148	1
144	149	1
145	150	1
146	151	1
147	152	1
148	153	1
149	154	1
150	155	1
151	156	1
152	157	1
153	158	1
154	159	1
155	160	1
156	161	1
157	162	1
158	163	1
159	164	1
160	165	1
161	166	1
162	167	1
163	168	1
164	169	1
165	170	1
166	171	1
167	172	1
168	173	1
169	174	1
170	175	1
171	176	1
172	177	1
173	178	1
174	179	1
175	180	1
176	181	1
177	182	1
178	183	1
179	184	1
180	185	1
181	186	1
182	187	1
183	188	1
184	189	1
185	190	1
186	191	1
187	192	1
188	193	1
189	194	1
190	195	1
191	196	1
192	197	1
193	198	1
194	199	1
195	200	1
196	201	1
197	202	1
198	203	1
199	204	1
200	205	1
201	206	1
202	207	1
203	208	1
204	209	1
205	210	1
206	211	1
207	212	1
208	213	1
209	214	1
210	215	1
211	216	1
212	217	1
213	218	1
214	219	1
215	220	1
216	221	1
217	222	1
218	223	1
219	224	1
220	225	1
221	226	1
222	227	1
223	228	1
224	229	1
225	230	1
226	231	1
227	3	3
228	4	3
229	5	3
230	6	3
231	7	3
232	8	3
233	9	3
234	10	3
235	11	3
236	12	3
237	15	3
238	16	3
239	17	3
240	25	3
241	30	3
242	31	3
243	38	3
244	39	3
245	86	3
246	87	3
247	88	3
248	89	3
249	90	3
250	91	3
251	92	3
252	94	3
253	95	3
254	96	3
255	97	3
256	98	3
257	99	3
258	100	3
259	101	3
260	102	3
261	103	3
262	104	3
263	105	3
264	106	3
265	107	3
266	108	3
267	110	3
268	112	3
269	113	3
270	114	3
271	115	3
272	117	3
273	118	3
274	119	3
275	120	3
276	121	3
277	122	3
278	123	3
279	124	3
280	125	3
281	126	3
282	130	3
283	131	3
284	132	3
285	134	3
286	142	3
287	143	3
288	144	3
289	146	3
290	151	3
291	152	3
292	153	3
293	154	3
294	155	3
295	156	3
296	157	3
297	158	3
298	159	3
299	160	3
300	161	3
301	163	3
302	164	3
303	165	3
304	167	3
305	168	3
306	169	3
307	170	3
308	171	3
309	182	3
310	183	3
311	185	3
312	186	3
313	187	3
314	188	3
315	189	3
316	190	3
317	191	3
318	193	3
319	199	3
320	201	3
321	202	3
322	203	3
323	204	3
324	205	3
325	206	3
326	207	3
327	208	3
328	209	3
329	210	3
330	212	3
331	213	3
332	214	3
333	215	3
334	220	3
335	221	3
336	223	3
337	224	3
338	225	3
339	227	3
340	228	3
341	229	3
342	230	3
343	231	3
344	3	4
345	7	4
346	8	4
347	11	4
348	15	4
349	16	4
350	17	4
351	30	4
352	31	4
353	38	4
354	39	4
355	86	4
356	87	4
357	88	4
358	89	4
359	90	4
360	91	4
361	92	4
362	94	4
363	95	4
364	96	4
365	97	4
366	98	4
367	99	4
368	100	4
369	101	4
370	102	4
371	103	4
372	104	4
373	105	4
374	106	4
375	107	4
376	108	4
377	110	4
378	115	4
379	119	4
380	120	4
381	121	4
382	122	4
383	123	4
384	124	4
385	130	4
386	131	4
387	132	4
388	134	4
389	142	4
390	143	4
391	144	4
392	146	4
393	151	4
394	152	4
395	153	4
396	154	4
397	156	4
398	157	4
399	158	4
400	160	4
401	161	4
402	163	4
403	164	4
404	165	4
405	167	4
406	168	4
407	169	4
408	170	4
409	171	4
410	182	4
411	183	4
412	185	4
413	186	4
414	187	4
415	188	4
416	189	4
417	190	4
418	191	4
419	193	4
420	199	4
421	201	4
422	202	4
423	203	4
424	204	4
425	205	4
426	206	4
427	208	4
428	210	4
429	212	4
430	213	4
431	223	4
432	224	4
433	225	4
434	227	4
435	228	4
436	229	4
437	230	4
438	231	4
439	1	5
440	2	5
441	17	5
442	19	5
443	129	5
444	133	5
445	135	5
446	136	5
447	137	5
448	138	5
449	139	5
450	140	5
451	141	5
452	162	5
453	172	5
454	173	5
455	174	5
456	175	5
457	176	5
458	177	5
459	178	5
460	179	5
461	180	5
462	181	5
463	216	5
464	217	5
465	218	5
466	219	5
467	223	5
468	226	5
\.


--
-- Data for Name: ab_register_user; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.ab_register_user (id, first_name, last_name, username, password, email, registration_date, registration_hash) FROM stdin;
\.


--
-- Data for Name: ab_role; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.ab_role (id, name) FROM stdin;
1	Admin
2	Public
3	Alpha
4	Gamma
5	sql_lab
\.


--
-- Data for Name: ab_user; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.ab_user (id, first_name, last_name, username, password, active, email, last_login, login_count, fail_login_count, created_on, changed_on, created_by_fk, changed_by_fk) FROM stdin;
1	Admin	User	admin	scrypt:32768:8:1$3lNw2g8xvSRoq0ae$ed151430ea664a5f9061402d9d9aaabf3a6c0469ec3f915e96fbd709ba24fb2ba91ad08a196b3b6624f052ffbdbd99fc1a94873cdef75ee88af3bc9571e1c778	t	admin@ejemplo.com	2026-06-28 12:36:43.153922	1	0	2026-06-28 12:19:42.246929	2026-06-28 12:19:42.246934	\N	\N
2	Ana	García	analista	scrypt:32768:8:1$3xgv98v6hHd06nF7$b86ff647d003af346f91e053e673d33800f54770f2d1e94c20d1ef6a0a4dc693d4bed73a0b5dd4f87e4754ac7f460b892ba0f3234fde2e68080e69edc5f5556c	t	ana@ejemplo.com	\N	\N	\N	2026-06-28 12:38:25.789545	2026-06-28 12:38:25.78955	\N	\N
\.


--
-- Data for Name: ab_user_group; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.ab_user_group (id, user_id, group_id) FROM stdin;
\.


--
-- Data for Name: ab_user_role; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.ab_user_role (id, user_id, role_id) FROM stdin;
1	1	1
2	2	4
\.


--
-- Data for Name: ab_view_menu; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.ab_view_menu (id, name) FROM stdin;
1	SavedQuery
2	CssTemplate
3	ReportSchedule
4	Chart
5	Annotation
6	Dataset
7	Log
8	Dashboard
9	Database
10	Query
11	SupersetIndexView
12	UtilView
13	LocaleView
14	SupersetAuthView
15	SupersetRegisterUserView
16	SecurityApi
17	UserInfoEditView
18	ResetPasswordView
19	ResetMyPasswordView
20	AuthDBView
21	UserDBModelView
22	RoleModelView
23	UserGroupModelView
24	Permission
25	Role
26	User
27	ViewMenu
28	PermissionViewMenu
29	Group
30	OpenApi
31	SwaggerView
32	MenuApi
33	AsyncEventsRestApi
34	AdvancedDataType
35	AvailableDomains
36	CacheRestApi
37	Theme
38	CurrentUserRestApi
39	UserRestApi
40	DashboardFilterStateRestApi
41	DashboardPermalinkRestApi
42	Datasource
43	EmbeddedDashboard
44	Explore
45	ExploreFormDataRestApi
46	ExplorePermalinkRestApi
47	ImportExportRestApi
48	Row Level Security
49	Tag
50	SQLLab
51	SqlLabPermalinkRestApi
52	security
53	DynamicPlugin
54	Extensions
55	Task
56	Api
57	EmbeddedView
58	Superset
59	TableSchemaView
60	TabStateView
61	Tags
62	TagView
63	RedirectView
64	RoleRestAPI
65	user
66	UserRegistrationsRestAPI
67	SecurityRestApi
68	RowLevelSecurity
69	Security
70	List Roles
71	User Registrations
72	List Users
73	List Groups
74	Action Log
75	Home
76	Data
77	Databases
78	Dashboards
79	Charts
80	Datasets
81	Manage
82	Plugins
83	CSS Templates
84	Themes
85	Tasks
86	Alerts & Report
87	Annotation Layers
88	SQL Lab
89	SQL Editor
90	Saved Queries
91	Query Search
92	all_datasource_access
93	all_database_access
94	all_query_access
95	[Analytics PostgreSQL].(id:1)
96	[PostgreSQL].(id:2)
97	[PostgreSQL].[analytics]
98	[PostgreSQL].[analytics].[public]
99	[PostgreSQL].[analytics].[information_schema]
100	[Analytics PostgreSQL].[ventas](id:1)
101	[Analytics PostgreSQL].[analytics].[public]
102	[Analytics PostgreSQL].[analytics]
\.


--
-- Data for Name: alembic_version; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.alembic_version (version_num) FROM stdin;
4b2a8c9d3e1f
\.


--
-- Data for Name: annotation; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.annotation (created_on, changed_on, id, start_dttm, end_dttm, layer_id, short_descr, long_descr, changed_by_fk, created_by_fk, json_metadata) FROM stdin;
\.


--
-- Data for Name: annotation_layer; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.annotation_layer (created_on, changed_on, id, name, descr, changed_by_fk, created_by_fk) FROM stdin;
\.


--
-- Data for Name: cache_keys; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.cache_keys (id, cache_key, cache_timeout, datasource_uid, created_on) FROM stdin;
\.


--
-- Data for Name: clientes; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.clientes (id, nombre, email, ciudad, fecha_alta) FROM stdin;
1	Ana García	ana@ejemplo.com	Madrid	2024-01-10
2	Carlos López	carlos@ejemplo.com	Barcelona	2024-03-22
3	Marta Ruiz	marta@ejemplo.com	Valencia	2024-06-15
4	Pedro Sánchez	pedro@ejemplo.com	Sevilla	2024-09-01
5	Laura Martín	laura@ejemplo.com	Bilbao	2025-01-05
\.


--
-- Data for Name: css_templates; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.css_templates (created_on, changed_on, id, template_name, css, changed_by_fk, created_by_fk, uuid) FROM stdin;
\.


--
-- Data for Name: dashboard_roles; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.dashboard_roles (id, role_id, dashboard_id) FROM stdin;
\.


--
-- Data for Name: dashboard_slices; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.dashboard_slices (id, dashboard_id, slice_id) FROM stdin;
\.


--
-- Data for Name: dashboard_user; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.dashboard_user (id, user_id, dashboard_id) FROM stdin;
\.


--
-- Data for Name: dashboards; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.dashboards (created_on, changed_on, id, dashboard_title, position_json, created_by_fk, changed_by_fk, css, description, slug, json_metadata, published, uuid, certified_by, certification_details, is_managed_externally, external_url, theme_id) FROM stdin;
\.


--
-- Data for Name: database_user_oauth2_tokens; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.database_user_oauth2_tokens (created_on, changed_on, id, user_id, database_id, access_token, access_token_expiration, refresh_token, created_by_fk, changed_by_fk) FROM stdin;
\.


--
-- Data for Name: dbs; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.dbs (created_on, changed_on, id, database_name, sqlalchemy_uri, created_by_fk, changed_by_fk, password, cache_timeout, extra, select_as_create_table_as, allow_ctas, expose_in_sqllab, force_ctas_schema, allow_run_async, allow_dml, verbose_name, impersonate_user, allow_file_upload, encrypted_extra, server_cert, allow_cvas, uuid, configuration_method, is_managed_externally, external_url) FROM stdin;
2026-06-28 12:43:11.963143	2026-06-28 12:43:11.963147	1	Analytics PostgreSQL	postgresql+psycopg2://analytics:XXXXXXXXXX@db:5432/analytics	\N	\N	\\x36374f49766b4d6e4d7a64616d5641412f72623730773d3d	\N	{\n    "metadata_params": {},\n    "engine_params": {},\n    "metadata_cache_timeout": {},\n    "schemas_allowed_for_file_upload": []\n}\n	f	f	t	\N	f	f	\N	f	f	\N	\N	f	d2bf5c28-14e0-4654-87e0-e6a40dce4cd6	sqlalchemy_form	f	\N
2026-06-28 12:46:27.411224	2026-06-28 12:49:37.678333	2	PostgreSQL	postgresql+psycopg2://analytics:XXXXXXXXXX@db:5432/analytics	1	1	\\x36374f49766b4d6e4d7a64616d5641412f72623730773d3d	\N	{"allows_virtual_table_explore":true}	f	f	t	\N	f	f	\N	f	f	\\x796c4353333376646a4f4e44396d7562736c496457673d3d	\N	f	edb9b9c2-dfa8-425e-893c-c11255ac5349	dynamic_form	f	\N
\.


--
-- Data for Name: dynamic_plugin; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.dynamic_plugin (created_on, changed_on, id, name, key, bundle_url, created_by_fk, changed_by_fk) FROM stdin;
\.


--
-- Data for Name: embedded_dashboards; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.embedded_dashboards (created_on, changed_on, allow_domain_list, uuid, dashboard_id, changed_by_fk, created_by_fk) FROM stdin;
\.


--
-- Data for Name: favstar; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.favstar (id, user_id, class_name, obj_id, dttm, uuid) FROM stdin;
\.


--
-- Data for Name: key_value; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.key_value (id, resource, value, uuid, created_on, created_by_fk, changed_on, changed_by_fk, expires_on) FROM stdin;
2	superset_metastore_cache	\\x22716d78724d52687165726b22	9233ce3b-5fb4-300e-954b-c653db9bd03b	2026-06-28 12:50:50.390185	1	2026-06-28 12:54:23.363216	1	2026-07-05 12:54:23.361516
1	superset_metastore_cache	\\x7b226f776e6572223a20312c202264617461736f757263655f6964223a20312c202264617461736f757263655f74797065223a20227461626c65222c202263686172745f6964223a206e756c6c2c2022666f726d5f64617461223a20227b5c2264617461736f757263655c223a5c22315f5f7461626c655c222c5c2276697a5f747970655c223a5c22686973746f6772616d5f76325c222c5c226d61747269786966795f656e61626c655c223a66616c73652c5c226d61747269786966795f6d6f64655f636f6c756d6e735c223a5c2264697361626c65645c222c5c226d61747269786966795f64696d656e73696f6e5f73656c656374696f6e5f6d6f64655f636f6c756d6e735c223a5c226d656d626572735c222c5c226d61747269786966795f64696d656e73696f6e5f636f6c756d6e735c223a7b5c2264696d656e73696f6e5c223a5c225c222c5c2276616c7565735c223a5b5d7d2c5c226d61747269786966795f746f706e5f76616c75655f636f6c756d6e735c223a31302c5c226d61747269786966795f616c6c5f736f72745f62795f636f6c756d6e735c223a5c22615f746f5f7a5c222c5c226d61747269786966795f746f706e5f6f726465725f636f6c756d6e735c223a747275652c5c226d61747269786966795f73686f775f636f6c756d6e5f686561646572735c223a747275652c5c226d61747269786966795f6669745f636f6c756d6e735f64796e616d6963616c6c795c223a747275652c5c226d61747269786966795f6d6f64655f726f77735c223a5c2264697361626c65645c222c5c226d61747269786966795f64696d656e73696f6e5f73656c656374696f6e5f6d6f64655f726f77735c223a5c226d656d626572735c222c5c226d61747269786966795f64696d656e73696f6e5f726f77735c223a7b5c2264696d656e73696f6e5c223a5c225c222c5c2276616c7565735c223a5b5d7d2c5c226d61747269786966795f746f706e5f76616c75655f726f77735c223a31302c5c226d61747269786966795f616c6c5f736f72745f62795f726f77735c223a5c22615f746f5f7a5c222c5c226d61747269786966795f746f706e5f6f726465725f726f77735c223a747275652c5c226d61747269786966795f73686f775f726f775f6c6162656c735c223a747275652c5c226d61747269786966795f726f775f6865696768745c223a3330302c5c226d61747269786966795f6368617274735f7065725f726f775c223a342c5c226d61747269786966795f63656c6c5f7469746c655f74656d706c6174655c223a5c225c222c5c22636f6c756d6e5c223a5c2263616e74696461645c222c5c2267726f757062795c223a5b5c2270726f647563746f5c222c5c2270726563696f5c225d2c5c226164686f635f66696c746572735c223a5b7b5c22636c617573655c223a5c2257484552455c222c5c227375626a6563745c223a5c2266656368615c222c5c226f70657261746f725c223a5c2254454d504f52414c5f52414e47455c222c5c22636f6d70617261746f725c223a5c224e6f2066696c7465725c222c5c2265787072657373696f6e547970655c223a5c2253494d504c455c227d5d2c5c22726f775f6c696d69745c223a31303030302c5c2262696e735c223a352c5c226e6f726d616c697a655c223a66616c73652c5c2263756d756c61746976655c223a66616c73652c5c22636f6c6f725f736368656d655c223a5c227375706572736574436f6c6f72735c222c5c2273686f775f76616c75655c223a66616c73652c5c2273686f775f6c6567656e645c223a747275652c5c22785f617869735f7469746c655c223a5c225c222c5c22785f617869735f666f726d61745c223a5c22534d4152545f4e554d4245525c222c5c22795f617869735f7469746c655c223a5c225c222c5c22795f617869735f666f726d61745c223a5c22534d4152545f4e554d4245525c222c5c2265787472615f666f726d5f646174615c223a7b7d7d227d	b9895596-df2c-38f5-ac9d-968d01bc0595	2026-06-28 12:50:50.383514	1	2026-06-28 12:57:35.798384	1	2026-07-05 12:57:35.797405
\.


--
-- Data for Name: keyvalue; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.keyvalue (id, value) FROM stdin;
\.


--
-- Data for Name: logs; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.logs (id, action, user_id, json, dttm, dashboard_id, slice_id, duration_ms, referrer) FROM stdin;
1	welcome	\N	{"path": "/superset/welcome/", "object_ref": "Superset.welcome"}	2026-06-28 12:25:40.039681	\N	\N	0	\N
2	welcome	1	{"path": "/superset/welcome/", "object_ref": "Superset.welcome"}	2026-06-28 12:36:43.262263	\N	\N	85	http://localhost:8088/login/
3	LogRestApi.recent_activity	1	{"path": "/api/v1/log/recent_activity/", "q": "(distinct:!f,page_size:24)", "object_ref": "LogRestApi.recent_activity", "rison": {"distinct": false, "page_size": 24}}	2026-06-28 12:36:43.788059	\N	\N	34	http://localhost:8088/superset/welcome/
4	DatabaseRestApi.get_list	1	{"path": "/api/v1/database/", "q": "(filters:!((col:database_name,opr:neq,value:examples)))", "rison": {"filters": [{"col": "database_name", "opr": "neq", "value": "examples"}]}}	2026-06-28 12:36:44.155468	\N	\N	359	http://localhost:8088/superset/welcome/
5	DatabaseRestApi.get_list	1	{"path": "/api/v1/database/", "q": "(filters:!((col:allow_file_upload,opr:upload_is_enabled,value:!t)))", "rison": {"filters": [{"col": "allow_file_upload", "opr": "upload_is_enabled", "value": true}]}}	2026-06-28 12:36:44.163474	\N	\N	442	http://localhost:8088/superset/welcome/
6	DashboardRestApi.get_list	1	{"path": "/api/v1/dashboard/", "q": "(filters:!((col:owners,opr:rel_m_m,value:'1')),order_column:changed_on_delta_humanized,order_direction:desc,page:0,page_size:5)", "rison": {"filters": [{"col": "owners", "opr": "rel_m_m", "value": "1"}], "order_column": "changed_on_delta_humanized", "order_direction": "desc", "page": 0, "page_size": 5}}	2026-06-28 12:36:44.172851	\N	\N	372	http://localhost:8088/superset/welcome/
7	DashboardRestApi.get_list	1	{"path": "/api/v1/dashboard/", "q": "(filters:!((col:owners,opr:rel_m_m,value:'1')),order_column:changed_on_delta_humanized,order_direction:desc,page:0,page_size:5)", "object_ref": "DashboardRestApi.get_list"}	2026-06-28 12:36:44.20116	\N	\N	451	http://localhost:8088/superset/welcome/
8	SavedQueryRestApi.get_list	1	{"path": "/api/v1/saved_query/", "q": "(filters:!((col:created_by,opr:rel_o_m,value:'1')),order_column:changed_on_delta_humanized,order_direction:desc,page:0,page_size:5)", "rison": {"filters": [{"col": "created_by", "opr": "rel_o_m", "value": "1"}], "order_column": "changed_on_delta_humanized", "order_direction": "desc", "page": 0, "page_size": 5}}	2026-06-28 12:36:44.204053	\N	\N	319	http://localhost:8088/superset/welcome/
9	ChartRestApi.get_list	1	{"path": "/api/v1/chart/", "q": "(filters:!((col:owners,opr:rel_m_m,value:'1')),order_column:changed_on_delta_humanized,order_direction:desc,page:0,page_size:5)", "rison": {"filters": [{"col": "owners", "opr": "rel_m_m", "value": "1"}], "order_column": "changed_on_delta_humanized", "order_direction": "desc", "page": 0, "page_size": 5}}	2026-06-28 12:36:44.236592	\N	\N	421	http://localhost:8088/superset/welcome/
10	DashboardRestApi.get_list	1	{"path": "/api/v1/dashboard/", "q": "(filters:!(),order_column:changed_on_delta_humanized,order_direction:desc,page:0,page_size:5)", "rison": {"filters": [], "order_column": "changed_on_delta_humanized", "order_direction": "desc", "page": 0, "page_size": 5}}	2026-06-28 12:36:44.312686	\N	\N	46	http://localhost:8088/superset/welcome/
11	ChartRestApi.get_list	1	{"path": "/api/v1/chart/", "q": "(filters:!(),order_column:changed_on_delta_humanized,order_direction:desc,page:0,page_size:5)", "rison": {"filters": [], "order_column": "changed_on_delta_humanized", "order_direction": "desc", "page": 0, "page_size": 5}}	2026-06-28 12:36:44.314212	\N	\N	86	http://localhost:8088/superset/welcome/
12	DashboardRestApi.get_list	1	{"path": "/api/v1/dashboard/", "q": "(filters:!(),order_column:changed_on_delta_humanized,order_direction:desc,page:0,page_size:5)", "object_ref": "DashboardRestApi.get_list"}	2026-06-28 12:36:44.318553	\N	\N	78	http://localhost:8088/superset/welcome/
13	ChartRestApi.info	1	{"path": "/api/v1/chart/_info", "q": "(keys:!(permissions))", "rison": {"keys": ["permissions"]}}	2026-06-28 12:36:44.392851	\N	\N	6	http://localhost:8088/superset/welcome/
14	DashboardRestApi.info	1	{"path": "/api/v1/dashboard/_info", "q": "(keys:!(permissions))", "rison": {"keys": ["permissions"]}}	2026-06-28 12:36:44.397775	\N	\N	14	http://localhost:8088/superset/welcome/
15	log	1	{"impression_id": "2_Ptgfgqrz0pwat5kcczr", "version": "v2", "ts": 1782650203611, "event_name": "spa_navigation", "path": "/superset/welcome/", "event_type": "user", "event_id": "c_QEIM4YlYnguHNdeeY0D", "visibility": "visible"}	2026-06-28 12:36:44.630903	\N	\N	0	http://localhost:8088/superset/welcome/
16	log	1	{"impression_id": "2_Ptgfgqrz0pwat5kcczr", "version": "v2", "ts": 1782650227365, "event_name": "spa_navigation", "path": "/users/", "event_type": "user", "event_id": "TrY7LjV5l20pdcOEeGNFd", "visibility": "visible"}	2026-06-28 12:37:08.378558	\N	\N	0	http://localhost:8088/users/?pageIndex=0&sortColumn=username&sortOrder=desc
17	DashboardRestApi.get_list	1	{"path": "/api/v1/dashboard/", "q": "(order_column:changed_on_delta_humanized,order_direction:desc,page:0,page_size:25,select_columns:!(id,dashboard_title,published,url,slug,changed_by,changed_by.id,changed_by.first_name,changed_by.last_name,changed_on_delta_humanized,owners,owners.id,owners.first_name,owners.last_name,tags.id,tags.name,tags.type,status,certified_by,certification_details,changed_on))", "rison": {"order_column": "changed_on_delta_humanized", "order_direction": "desc", "page": 0, "page_size": 25, "select_columns": ["id", "dashboard_title", "published", "url", "slug", "changed_by", "changed_by.id", "changed_by.first_name", "changed_by.last_name", "changed_on_delta_humanized", "owners", "owners.id", "owners.first_name", "owners.last_name", "tags.id", "tags.name", "tags.type", "status", "certified_by", "certification_details", "changed_on"]}}	2026-06-28 12:37:20.005553	\N	\N	41	http://localhost:8088/dashboard/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc&viewMode=table
18	DashboardRestApi.info	1	{"path": "/api/v1/dashboard/_info", "q": "(keys:!(permissions))", "rison": {"keys": ["permissions"]}}	2026-06-28 12:37:20.006143	\N	\N	60	http://localhost:8088/dashboard/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc&viewMode=table
19	DashboardRestApi.get_list	1	{"path": "/api/v1/dashboard/", "q": "(order_column:changed_on_delta_humanized,order_direction:desc,page:0,page_size:25,select_columns:!(id,dashboard_title,published,url,slug,changed_by,changed_by.id,changed_by.first_name,changed_by.last_name,changed_on_delta_humanized,owners,owners.id,owners.first_name,owners.last_name,tags.id,tags.name,tags.type,status,certified_by,certification_details,changed_on))", "object_ref": "DashboardRestApi.get_list"}	2026-06-28 12:37:20.013591	\N	\N	72	http://localhost:8088/dashboard/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc&viewMode=table
20	log	1	{"impression_id": "2_Ptgfgqrz0pwat5kcczr", "version": "v2", "ts": 1782650239830, "event_name": "spa_navigation", "path": "/dashboard/list/", "event_type": "user", "event_id": "E67YmTithFgc2mSrp0syJ", "visibility": "visible"}	2026-06-28 12:37:20.842827	\N	\N	0	http://localhost:8088/dashboard/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc&viewMode=table
21	ChartRestApi.info	1	{"path": "/api/v1/chart/_info", "q": "(keys:!(permissions))", "rison": {"keys": ["permissions"]}}	2026-06-28 12:37:22.211891	\N	\N	30	http://localhost:8088/chart/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc&viewMode=table
22	ChartRestApi.get_list	1	{"path": "/api/v1/chart/", "q": "(order_column:changed_on_delta_humanized,order_direction:desc,page:0,page_size:25)", "rison": {"order_column": "changed_on_delta_humanized", "order_direction": "desc", "page": 0, "page_size": 25}}	2026-06-28 12:37:22.241027	\N	\N	52	http://localhost:8088/chart/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc&viewMode=table
27	SqlLabRestApi.get	1	{"path": "/api/v1/sqllab/", "object_ref": "SqlLabRestApi.get"}	2026-06-28 12:37:27.462853	\N	\N	11	http://localhost:8088/sqllab/
32	DashboardRestApi.info	1	{"path": "/api/v1/dashboard/_info", "q": "(keys:!(permissions))", "rison": {"keys": ["permissions"]}}	2026-06-28 12:37:32.919302	\N	\N	47	http://localhost:8088/dashboard/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc&viewMode=table
35	DatabaseRestApi.get_list	1	{"path": "/api/v1/database/", "q": "(filters:!((col:database_name,opr:neq,value:examples)))", "rison": {"filters": [{"col": "database_name", "opr": "neq", "value": "examples"}]}}	2026-06-28 12:38:30.427351	\N	\N	31	http://localhost:8088/dashboard/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc&viewMode=table
40	log	1	{"impression_id": "n0t21lhc5lUUrZ9U_EAfB", "version": "v2", "ts": 1782650310330, "event_name": "spa_navigation", "path": "/dashboard/list/", "event_type": "user", "event_id": "SWbptoosgzY-UhRjTnCjP", "visibility": "visible"}	2026-06-28 12:38:31.341506	\N	\N	0	http://localhost:8088/dashboard/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc&viewMode=table
41	log	1	{"impression_id": "n0t21lhc5lUUrZ9U_EAfB", "version": "v2", "ts": 1782650314246, "event_name": "spa_navigation", "path": "/users/", "event_type": "user", "event_id": "-i2_OziZJDJoiUfVxyobD", "visibility": "visible"}	2026-06-28 12:38:35.257236	\N	\N	0	http://localhost:8088/users/?pageIndex=0&sortColumn=username&sortOrder=desc
46	DatabaseRestApi.info	1	{"path": "/api/v1/database/_info", "q": "(keys:!(permissions))", "rison": {"keys": ["permissions"]}}	2026-06-28 12:39:09.731389	\N	\N	46	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
51	validation_error	1	{"path": "/api/v1/database/validate_parameters/", "database_name": "PostgreSQL", "engine": "postgresql", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "driver": "psycopg2", "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "parameters": {"host": "localhost"}}	2026-06-28 12:39:40.654037	\N	\N	\N	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
23	log	1	{"impression_id": "2_Ptgfgqrz0pwat5kcczr", "version": "v2", "ts": 1782650242056, "event_name": "spa_navigation", "path": "/chart/list/", "event_type": "user", "event_id": "lX991Emf7At4umujS4G6F", "visibility": "visible"}	2026-06-28 12:37:23.07082	\N	\N	0	http://localhost:8088/chart/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc&viewMode=table
28	log	1	{"source": "sqlLab", "ts": 1782650247345, "event_name": "spa_navigation", "path": "/sqllab/", "event_type": "user", "event_id": "v6QVFFQ3yKYFC8J5mV5Q3", "visibility": "visible"}	2026-06-28 12:37:28.358198	\N	\N	0	http://localhost:8088/sqllab/
33	DashboardRestApi.get_list	1	{"path": "/api/v1/dashboard/", "q": "(order_column:changed_on_delta_humanized,order_direction:desc,page:0,page_size:25,select_columns:!(id,dashboard_title,published,url,slug,changed_by,changed_by.id,changed_by.first_name,changed_by.last_name,changed_on_delta_humanized,owners,owners.id,owners.first_name,owners.last_name,tags.id,tags.name,tags.type,status,certified_by,certification_details,changed_on))", "object_ref": "DashboardRestApi.get_list"}	2026-06-28 12:37:32.920534	\N	\N	54	http://localhost:8088/dashboard/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc&viewMode=table
37	DashboardRestApi.get_list	1	{"path": "/api/v1/dashboard/", "q": "(order_column:changed_on_delta_humanized,order_direction:desc,page:0,page_size:25,select_columns:!(id,dashboard_title,published,url,slug,changed_by,changed_by.id,changed_by.first_name,changed_by.last_name,changed_on_delta_humanized,owners,owners.id,owners.first_name,owners.last_name,tags.id,tags.name,tags.type,status,certified_by,certification_details,changed_on))", "rison": {"order_column": "changed_on_delta_humanized", "order_direction": "desc", "page": 0, "page_size": 25, "select_columns": ["id", "dashboard_title", "published", "url", "slug", "changed_by", "changed_by.id", "changed_by.first_name", "changed_by.last_name", "changed_on_delta_humanized", "owners", "owners.id", "owners.first_name", "owners.last_name", "tags.id", "tags.name", "tags.type", "status", "certified_by", "certification_details", "changed_on"]}}	2026-06-28 12:38:30.498821	\N	\N	26	http://localhost:8088/dashboard/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc&viewMode=table
45	DatabaseRestApi.get_list	1	{"path": "/api/v1/database/", "q": "(order_column:changed_on_delta_humanized,order_direction:desc,page:0,page_size:25)", "rison": {"order_column": "changed_on_delta_humanized", "order_direction": "desc", "page": 0, "page_size": 25}}	2026-06-28 12:39:09.722968	\N	\N	64	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
49	DatabaseRestApi.get_list	1	{"path": "/api/v1/database/", "q": "(filters:!((col:allow_file_upload,opr:upload_is_enabled,value:!t)))", "rison": {"filters": [{"col": "allow_file_upload", "opr": "upload_is_enabled", "value": true}]}}	2026-06-28 12:39:15.006402	\N	\N	38	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
24	DatasetRestApi.info	1	{"path": "/api/v1/dataset/_info", "q": "(keys:!(permissions))", "rison": {"keys": ["permissions"]}}	2026-06-28 12:37:24.461821	\N	\N	56	http://localhost:8088/tablemodelview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
29	DatabaseRestApi.get_list	1	{"path": "/api/v1/database/", "q": "(filters:!((col:database_name,opr:ct,value:'')),order_column:database_name,order_direction:asc,page:0,page_size:100)", "rison": {"filters": [{"col": "database_name", "opr": "ct", "value": ""}], "order_column": "database_name", "order_direction": "asc", "page": 0, "page_size": 100}}	2026-06-28 12:37:29.863375	\N	\N	36	http://localhost:8088/sqllab/
34	log	1	{"impression_id": "2_Ptgfgqrz0pwat5kcczr", "version": "v2", "ts": 1782650252818, "event_name": "spa_navigation", "path": "/dashboard/list/", "event_type": "user", "event_id": "042vbe3prKqx6KO1oK5km", "visibility": "visible"}	2026-06-28 12:37:33.829611	\N	\N	0	http://localhost:8088/dashboard/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc&viewMode=table
38	DashboardRestApi.info	1	{"path": "/api/v1/dashboard/_info", "q": "(keys:!(permissions))", "rison": {"keys": ["permissions"]}}	2026-06-28 12:38:30.501436	\N	\N	45	http://localhost:8088/dashboard/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc&viewMode=table
42	CssTemplateRestApi.info	1	{"path": "/api/v1/css_template/_info", "q": "(keys:!(permissions))", "rison": {"keys": ["permissions"]}}	2026-06-28 12:38:48.105364	\N	\N	11	http://localhost:8088/csstemplatemodelview/list/?pageIndex=0&sortColumn=template_name&sortOrder=desc
47	DatabaseRestApi.get_list	1	{"path": "/api/v1/database/", "q": "(filters:!((col:allow_file_upload,opr:upload_is_enabled,value:!t)))", "rison": {"filters": [{"col": "allow_file_upload", "opr": "upload_is_enabled", "value": true}]}}	2026-06-28 12:39:09.739356	\N	\N	59	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
52	validation_error	1	{"path": "/api/v1/database/validate_parameters/", "database_name": "PostgreSQL", "engine": "postgresql", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "driver": "psycopg2", "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "parameters": {"host": "localhost", "port": "5432"}}	2026-06-28 12:39:44.901066	\N	\N	\N	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
25	DatasetRestApi.get_list	1	{"path": "/api/v1/dataset/", "q": "(order_column:changed_on_delta_humanized,order_direction:desc,page:0,page_size:25)", "rison": {"order_column": "changed_on_delta_humanized", "order_direction": "desc", "page": 0, "page_size": 25}}	2026-06-28 12:37:24.464672	\N	\N	52	http://localhost:8088/tablemodelview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
30	log	1	{"source": "sqlLab", "ts": 1782650249536, "event_name": "sqllab_monitor_local_storage_usage", "current_usage": 0.14, "query_count": 0, "event_type": "user", "event_id": "0JgxGZFLHWZ4tMJK9jMTx", "visibility": "visible"}	2026-06-28 12:37:30.549013	\N	\N	0	http://localhost:8088/sqllab/
39	DashboardRestApi.get_list	1	{"path": "/api/v1/dashboard/", "q": "(order_column:changed_on_delta_humanized,order_direction:desc,page:0,page_size:25,select_columns:!(id,dashboard_title,published,url,slug,changed_by,changed_by.id,changed_by.first_name,changed_by.last_name,changed_on_delta_humanized,owners,owners.id,owners.first_name,owners.last_name,tags.id,tags.name,tags.type,status,certified_by,certification_details,changed_on))", "object_ref": "DashboardRestApi.get_list"}	2026-06-28 12:38:30.505163	\N	\N	51	http://localhost:8088/dashboard/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc&viewMode=table
44	log	1	{"impression_id": "n0t21lhc5lUUrZ9U_EAfB", "version": "v2", "ts": 1782650327990, "event_name": "spa_navigation", "path": "/csstemplatemodelview/list/", "event_type": "user", "event_id": "VrMZ6iFY-O3VN4_JuxWjx", "visibility": "visible"}	2026-06-28 12:38:49.00166	\N	\N	0	http://localhost:8088/csstemplatemodelview/list/?pageIndex=0&sortColumn=template_name&sortOrder=desc
50	DatabaseRestApi.available	1	{"path": "/api/v1/database/available/", "object_ref": "DatabaseRestApi.available"}	2026-06-28 12:39:15.02141	\N	\N	66	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
26	log	1	{"impression_id": "2_Ptgfgqrz0pwat5kcczr", "version": "v2", "ts": 1782650244297, "event_name": "spa_navigation", "path": "/tablemodelview/list/", "event_type": "user", "event_id": "4pYiBW67lXU4Zo_BYX055", "visibility": "visible"}	2026-06-28 12:37:25.313271	\N	\N	0	http://localhost:8088/tablemodelview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
31	DashboardRestApi.get_list	1	{"path": "/api/v1/dashboard/", "q": "(order_column:changed_on_delta_humanized,order_direction:desc,page:0,page_size:25,select_columns:!(id,dashboard_title,published,url,slug,changed_by,changed_by.id,changed_by.first_name,changed_by.last_name,changed_on_delta_humanized,owners,owners.id,owners.first_name,owners.last_name,tags.id,tags.name,tags.type,status,certified_by,certification_details,changed_on))", "rison": {"order_column": "changed_on_delta_humanized", "order_direction": "desc", "page": 0, "page_size": 25, "select_columns": ["id", "dashboard_title", "published", "url", "slug", "changed_by", "changed_by.id", "changed_by.first_name", "changed_by.last_name", "changed_on_delta_humanized", "owners", "owners.id", "owners.first_name", "owners.last_name", "tags.id", "tags.name", "tags.type", "status", "certified_by", "certification_details", "changed_on"]}}	2026-06-28 12:37:32.912302	\N	\N	22	http://localhost:8088/dashboard/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc&viewMode=table
36	DatabaseRestApi.get_list	1	{"path": "/api/v1/database/", "q": "(filters:!((col:allow_file_upload,opr:upload_is_enabled,value:!t)))", "rison": {"filters": [{"col": "allow_file_upload", "opr": "upload_is_enabled", "value": true}]}}	2026-06-28 12:38:30.43081	\N	\N	51	http://localhost:8088/dashboard/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc&viewMode=table
43	CssTemplateRestApi.get_list	1	{"path": "/api/v1/css_template/", "q": "(order_column:template_name,order_direction:desc,page:0,page_size:25)", "rison": {"order_column": "template_name", "order_direction": "desc", "page": 0, "page_size": 25}}	2026-06-28 12:38:48.12365	\N	\N	27	http://localhost:8088/csstemplatemodelview/list/?pageIndex=0&sortColumn=template_name&sortOrder=desc
48	log	1	{"impression_id": "n0t21lhc5lUUrZ9U_EAfB", "version": "v2", "ts": 1782650349521, "event_name": "spa_navigation", "path": "/databaseview/list/", "event_type": "user", "event_id": "sO-U6t---MfK7GjbmCofc", "visibility": "visible"}	2026-06-28 12:39:10.536639	\N	\N	0	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
53	test_connection_attempt	1	{"path": "/api/v1/database/test_connection/", "sqlalchemy_uri": "postgresql+psycopg2://analytics:analytics_pass@db:5432/analytics", "database_name": "PostgreSQL", "masked_encrypted_extra": "", "engine": "postgresql"}	2026-06-28 12:40:19.300367	\N	\N	\N	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
54	test_connection_success	1	{"path": "/api/v1/database/test_connection/", "sqlalchemy_uri": "postgresql+psycopg2://analytics:analytics_pass@db:5432/analytics", "database_name": "PostgreSQL", "masked_encrypted_extra": "", "engine": "postgresql"}	2026-06-28 12:40:19.321012	\N	\N	\N	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
55	DatabaseRestApi.test_connection	1	{"path": "/api/v1/database/test_connection/", "sqlalchemy_uri": "postgresql+psycopg2://analytics:analytics_pass@db:5432/analytics", "database_name": "PostgreSQL", "masked_encrypted_extra": "", "object_ref": "DatabaseRestApi.test_connection"}	2026-06-28 12:40:19.326514	\N	\N	38	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
56	validation_error	1	{"path": "/api/v1/database/validate_parameters/", "database_name": "PostgreSQL", "engine": "postgresql", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "driver": "psycopg2", "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "parameters": {"host": "localhost"}}	2026-06-28 12:41:09.532901	\N	\N	\N	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
57	validation_error	1	{"path": "/api/v1/database/validate_parameters/", "database_name": "PostgreSQL", "engine": "postgresql", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "driver": "psycopg2", "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "parameters": {"host": "localhost", "port": "5432"}}	2026-06-28 12:41:19.397999	\N	\N	\N	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
58	validation_error	1	{"path": "/api/v1/database/validate_parameters/", "database_name": "PostgreSQL", "engine": "postgresql", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "driver": "psycopg2", "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "parameters": {"host": "localhost", "port": "5432"}}	2026-06-28 12:41:20.411959	\N	\N	\N	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
59	validation_error	1	{"path": "/api/v1/database/validate_parameters/", "database_name": "PostgreSQL", "engine": "postgresql", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "driver": "psycopg2", "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "parameters": {"host": "localhost", "port": "5432", "database": "analytics"}}	2026-06-28 12:41:32.103796	\N	\N	\N	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
60	validation_error	1	{"path": "/api/v1/database/validate_parameters/", "database_name": "PostgreSQL", "engine": "postgresql", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "driver": "psycopg2", "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "parameters": {"host": "localhost", "port": "5432", "database": "analytics"}}	2026-06-28 12:41:33.232197	\N	\N	\N	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
135	DatabaseRestApi.get_list	1	{"path": "/api/v1/database/", "q": "(filters:!((col:allow_file_upload,opr:upload_is_enabled,value:!t)))", "rison": {"filters": [{"col": "allow_file_upload", "opr": "upload_is_enabled", "value": true}]}}	2026-06-28 12:46:52.545155	\N	\N	310	http://localhost:8088/databaseview/list/
61	validation_error	1	{"path": "/api/v1/database/validate_parameters/", "database_name": "PostgreSQL", "engine": "postgresql", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "driver": "psycopg2", "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "parameters": {"host": "localhost", "port": "5432", "database": "analytics", "username": "admin"}}	2026-06-28 12:41:43.803163	\N	\N	\N	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
66	db_creation_failed.SupersetErrorsException	1	{"path": "/api/v1/database/", "database_name": "PostgreSQL", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "masked_encrypted_extra": "{}", "sqlalchemy_uri": "postgresql+psycopg2://admin:admin123@localhost:5432/analytics", "engine": "postgresql"}	2026-06-28 12:42:06.587995	\N	\N	\N	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
71	test_connection_error.DBAPIError	1	{"path": "/api/v1/database/", "database_name": "PostgreSQL", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "masked_encrypted_extra": "{}", "sqlalchemy_uri": "postgresql+psycopg2://admin:admin123@db-1:5432/analytics", "engine": "postgresql"}	2026-06-28 12:42:37.13111	\N	\N	\N	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
76	validation_error	1	{"path": "/api/v1/database/validate_parameters/", "database_name": "PostgreSQL", "engine": "postgresql", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "driver": "psycopg2", "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "parameters": {"host": "localhost", "port": "5433", "database": "analytics", "username": "admin", "password": "admin123"}}	2026-06-28 12:42:51.913693	\N	\N	\N	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
81	DatabaseRestApi.get_list	1	{"path": "/api/v1/database/", "q": "(filters:!((col:allow_file_upload,opr:upload_is_enabled,value:!t)))", "rison": {"filters": [{"col": "allow_file_upload", "opr": "upload_is_enabled", "value": true}]}}	2026-06-28 12:43:30.39402	\N	\N	27	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
85	DatabaseRestApi.get_list	1	{"path": "/api/v1/database/", "q": "(order_column:changed_on_delta_humanized,order_direction:desc,page:0,page_size:25)", "rison": {"order_column": "changed_on_delta_humanized", "order_direction": "desc", "page": 0, "page_size": 25}}	2026-06-28 12:43:33.415356	\N	\N	37	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
88	DatabaseRestApi.get_list	1	{"path": "/api/v1/database/", "q": "(filters:!((col:allow_file_upload,opr:upload_is_enabled,value:!t)))", "rison": {"filters": [{"col": "allow_file_upload", "opr": "upload_is_enabled", "value": true}]}}	2026-06-28 12:43:36.138374	\N	\N	43	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
93	DatabaseRestApi.get_list	1	{"path": "/api/v1/database/", "q": "(filters:!((col:allow_file_upload,opr:upload_is_enabled,value:!t)))", "rison": {"filters": [{"col": "allow_file_upload", "opr": "upload_is_enabled", "value": true}]}}	2026-06-28 12:43:40.964817	\N	\N	29	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
97	DatabaseRestApi.get_list	1	{"path": "/api/v1/database/", "q": "(filters:!((col:allow_file_upload,opr:upload_is_enabled,value:!t)))", "rison": {"filters": [{"col": "allow_file_upload", "opr": "upload_is_enabled", "value": true}]}}	2026-06-28 12:44:02.648766	\N	\N	29	http://localhost:8088/databaseview/list/
102	validation_error	1	{"path": "/api/v1/database/validate_parameters/", "database_name": "PostgreSQL", "engine": "postgresql", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "driver": "psycopg2", "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "parameters": {"database": "analytics"}}	2026-06-28 12:44:57.313593	\N	\N	\N	http://localhost:8088/databaseview/list/
107	validation_error	1	{"path": "/api/v1/database/validate_parameters/", "database_name": "PostgreSQL", "engine": "postgresql", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "driver": "psycopg2", "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "parameters": {"database": "analytics", "username": "analytics", "password": "analytics_pass", "host": "localhost", "port": "5433"}}	2026-06-28 12:45:16.922566	\N	\N	\N	http://localhost:8088/databaseview/list/
112	validation_error	1	{"path": "/api/v1/database/validate_parameters/", "database_name": "PostgreSQL", "engine": "postgresql", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "driver": "psycopg2", "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "parameters": {"database": "analytics", "username": "analytics", "password": "analytics_pass", "host": "localhost", "port": "5432"}}	2026-06-28 12:45:21.168235	\N	\N	\N	http://localhost:8088/databaseview/list/
117	DatabaseRestApi.post	1	{"path": "/api/v1/database/", "database_name": "PostgreSQL", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "masked_encrypted_extra": "{}", "sqlalchemy_uri": "postgresql+psycopg2://analytics:analytics_pass@localhost:5432/analytics", "object_ref": "DatabaseRestApi.post"}	2026-06-28 12:45:22.06622	\N	\N	38	http://localhost:8088/databaseview/list/
62	validation_error	1	{"path": "/api/v1/database/validate_parameters/", "database_name": "PostgreSQL", "engine": "postgresql", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "driver": "psycopg2", "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "parameters": {"host": "localhost", "port": "5432", "database": "analytics", "username": "admin", "password": "admin123"}}	2026-06-28 12:42:01.678625	\N	\N	\N	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
67	DatabaseRestApi.post	1	{"path": "/api/v1/database/", "database_name": "PostgreSQL", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "masked_encrypted_extra": "{}", "sqlalchemy_uri": "postgresql+psycopg2://admin:admin123@localhost:5432/analytics", "object_ref": "DatabaseRestApi.post"}	2026-06-28 12:42:06.594606	\N	\N	50	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
72	db_creation_failed.SupersetErrorsException	1	{"path": "/api/v1/database/", "database_name": "PostgreSQL", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "masked_encrypted_extra": "{}", "sqlalchemy_uri": "postgresql+psycopg2://admin:admin123@db-1:5432/analytics", "engine": "postgresql"}	2026-06-28 12:42:37.136989	\N	\N	\N	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
77	test_connection_attempt	1	{"path": "/api/v1/database/", "database_name": "PostgreSQL", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "masked_encrypted_extra": "{}", "sqlalchemy_uri": "postgresql+psycopg2://admin:admin123@localhost:5433/analytics", "engine": "postgresql"}	2026-06-28 12:42:51.964662	\N	\N	\N	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
86	DatabaseRestApi.get_list	1	{"path": "/api/v1/database/", "q": "(filters:!((col:allow_file_upload,opr:upload_is_enabled,value:!t)))", "rison": {"filters": [{"col": "allow_file_upload", "opr": "upload_is_enabled", "value": true}]}}	2026-06-28 12:43:33.419508	\N	\N	35	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
90	test_connection_attempt	1	{"path": "/api/v1/database/test_connection/", "sqlalchemy_uri": "postgresql+psycopg2://analytics:XXXXXXXXXX@db:5432/analytics", "database_name": "Analytics PostgreSQL", "extra": "{\\n    \\"metadata_params\\": {},\\n    \\"engine_params\\": {},\\n    \\"metadata_cache_timeout\\": {},\\n    \\"schemas_allowed_for_file_upload\\": []\\n}\\n", "masked_encrypted_extra": "", "engine": "postgresql"}	2026-06-28 12:43:38.129994	\N	\N	\N	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
98	DatabaseRestApi.available	1	{"path": "/api/v1/database/available/", "object_ref": "DatabaseRestApi.available"}	2026-06-28 12:44:02.669187	\N	\N	56	http://localhost:8088/databaseview/list/
103	validation_error	1	{"path": "/api/v1/database/validate_parameters/", "database_name": "PostgreSQL", "engine": "postgresql", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "driver": "psycopg2", "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "parameters": {"database": "analytics", "username": "analytics"}}	2026-06-28 12:45:01.139743	\N	\N	\N	http://localhost:8088/databaseview/list/
108	test_connection_attempt	1	{"path": "/api/v1/database/", "database_name": "PostgreSQL", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "masked_encrypted_extra": "{}", "sqlalchemy_uri": "postgresql+psycopg2://analytics:analytics_pass@localhost:5433/analytics", "engine": "postgresql"}	2026-06-28 12:45:16.975413	\N	\N	\N	http://localhost:8088/databaseview/list/
113	validation_error	1	{"path": "/api/v1/database/validate_parameters/", "database_name": "PostgreSQL", "engine": "postgresql", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "driver": "psycopg2", "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "parameters": {"database": "analytics", "username": "analytics", "password": "analytics_pass", "host": "localhost", "port": "5432"}}	2026-06-28 12:45:21.995888	\N	\N	\N	http://localhost:8088/databaseview/list/
63	validation_error	1	{"path": "/api/v1/database/validate_parameters/", "database_name": "PostgreSQL", "engine": "postgresql", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "driver": "psycopg2", "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "parameters": {"host": "localhost", "port": "5432", "database": "analytics", "username": "admin", "password": "admin123"}}	2026-06-28 12:42:06.508207	\N	\N	\N	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
68	validation_error	1	{"path": "/api/v1/database/validate_parameters/", "database_name": "PostgreSQL", "engine": "postgresql", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "driver": "psycopg2", "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "parameters": {"host": "db-1", "port": "5432", "database": "analytics", "username": "admin", "password": "admin123"}}	2026-06-28 12:42:35.549789	\N	\N	\N	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
73	DatabaseRestApi.post	1	{"path": "/api/v1/database/", "database_name": "PostgreSQL", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "masked_encrypted_extra": "{}", "sqlalchemy_uri": "postgresql+psycopg2://admin:admin123@db-1:5432/analytics", "object_ref": "DatabaseRestApi.post"}	2026-06-28 12:42:37.141814	\N	\N	46	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
78	test_connection_error.DBAPIError	1	{"path": "/api/v1/database/", "database_name": "PostgreSQL", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "masked_encrypted_extra": "{}", "sqlalchemy_uri": "postgresql+psycopg2://admin:admin123@localhost:5433/analytics", "engine": "postgresql"}	2026-06-28 12:42:51.971011	\N	\N	\N	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
82	DatabaseRestApi.get_list	1	{"path": "/api/v1/database/", "q": "(filters:!((col:database_name,opr:neq,value:examples)))", "rison": {"filters": [{"col": "database_name", "opr": "neq", "value": "examples"}]}}	2026-06-28 12:43:33.322409	\N	\N	45	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
87	log	1	{"impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782650613232, "event_name": "spa_navigation", "path": "/databaseview/list/", "event_type": "user", "event_id": "Krey0uirF8BDrfq5LT4yw", "visibility": "visible"}	2026-06-28 12:43:34.244699	\N	\N	0	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
91	test_connection_success	1	{"path": "/api/v1/database/test_connection/", "sqlalchemy_uri": "postgresql+psycopg2://analytics:XXXXXXXXXX@db:5432/analytics", "database_name": "Analytics PostgreSQL", "extra": "{\\n    \\"metadata_params\\": {},\\n    \\"engine_params\\": {},\\n    \\"metadata_cache_timeout\\": {},\\n    \\"schemas_allowed_for_file_upload\\": []\\n}\\n", "masked_encrypted_extra": "", "engine": "postgresql"}	2026-06-28 12:43:38.150355	\N	\N	\N	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
94	DatabaseRestApi.get_list	1	{"path": "/api/v1/database/", "q": "(filters:!((col:allow_file_upload,opr:upload_is_enabled,value:!t)))", "rison": {"filters": [{"col": "allow_file_upload", "opr": "upload_is_enabled", "value": true}]}}	2026-06-28 12:43:45.139738	\N	\N	32	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
99	validation_error	1	{"path": "/api/v1/database/validate_parameters/", "database_name": "PostgreSQL", "engine": "postgresql", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "driver": "psycopg2", "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true}	2026-06-28 12:44:09.487262	\N	\N	\N	http://localhost:8088/databaseview/list/
104	validation_error	1	{"path": "/api/v1/database/validate_parameters/", "database_name": "PostgreSQL", "engine": "postgresql", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "driver": "psycopg2", "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "parameters": {"database": "analytics", "username": "analytics", "password": "analytics_pass"}}	2026-06-28 12:45:06.033464	\N	\N	\N	http://localhost:8088/databaseview/list/
109	test_connection_error.DBAPIError	1	{"path": "/api/v1/database/", "database_name": "PostgreSQL", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "masked_encrypted_extra": "{}", "sqlalchemy_uri": "postgresql+psycopg2://analytics:analytics_pass@localhost:5433/analytics", "engine": "postgresql"}	2026-06-28 12:45:16.982651	\N	\N	\N	http://localhost:8088/databaseview/list/
114	test_connection_attempt	1	{"path": "/api/v1/database/", "database_name": "PostgreSQL", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "masked_encrypted_extra": "{}", "sqlalchemy_uri": "postgresql+psycopg2://analytics:analytics_pass@localhost:5432/analytics", "engine": "postgresql"}	2026-06-28 12:45:22.049317	\N	\N	\N	http://localhost:8088/databaseview/list/
64	test_connection_attempt	1	{"path": "/api/v1/database/", "database_name": "PostgreSQL", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "masked_encrypted_extra": "{}", "sqlalchemy_uri": "postgresql+psycopg2://admin:admin123@localhost:5432/analytics", "engine": "postgresql"}	2026-06-28 12:42:06.57161	\N	\N	\N	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
69	validation_error	1	{"path": "/api/v1/database/validate_parameters/", "database_name": "PostgreSQL", "engine": "postgresql", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "driver": "psycopg2", "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "parameters": {"host": "db-1", "port": "5432", "database": "analytics", "username": "admin", "password": "admin123"}}	2026-06-28 12:42:37.06266	\N	\N	\N	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
74	validation_error	1	{"path": "/api/v1/database/validate_parameters/", "database_name": "PostgreSQL", "engine": "postgresql", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "driver": "psycopg2", "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "parameters": {"host": "db-1", "port": "5433", "database": "analytics", "username": "admin", "password": "admin123"}}	2026-06-28 12:42:48.252136	\N	\N	\N	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
79	db_creation_failed.SupersetErrorsException	1	{"path": "/api/v1/database/", "database_name": "PostgreSQL", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "masked_encrypted_extra": "{}", "sqlalchemy_uri": "postgresql+psycopg2://admin:admin123@localhost:5433/analytics", "engine": "postgresql"}	2026-06-28 12:42:51.975461	\N	\N	\N	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
83	DatabaseRestApi.get_list	1	{"path": "/api/v1/database/", "q": "(filters:!((col:allow_file_upload,opr:upload_is_enabled,value:!t)))", "rison": {"filters": [{"col": "allow_file_upload", "opr": "upload_is_enabled", "value": true}]}}	2026-06-28 12:43:33.32576	\N	\N	33	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
89	DatabaseRestApi.available	1	{"path": "/api/v1/database/available/", "object_ref": "DatabaseRestApi.available"}	2026-06-28 12:43:36.162499	\N	\N	81	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
95	DatabaseRestApi.available	1	{"path": "/api/v1/database/available/", "object_ref": "DatabaseRestApi.available"}	2026-06-28 12:43:45.160967	\N	\N	63	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
100	validation_error	1	{"path": "/api/v1/database/validate_parameters/", "database_name": "PostgreSQL", "engine": "postgresql", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "driver": "psycopg2", "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true}	2026-06-28 12:44:12.475166	\N	\N	\N	http://localhost:8088/databaseview/list/
105	validation_error	1	{"path": "/api/v1/database/validate_parameters/", "database_name": "PostgreSQL", "engine": "postgresql", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "driver": "psycopg2", "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "parameters": {"database": "analytics", "username": "analytics", "password": "analytics_pass", "host": "localhost"}}	2026-06-28 12:45:10.120405	\N	\N	\N	http://localhost:8088/databaseview/list/
110	db_creation_failed.SupersetErrorsException	1	{"path": "/api/v1/database/", "database_name": "PostgreSQL", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "masked_encrypted_extra": "{}", "sqlalchemy_uri": "postgresql+psycopg2://analytics:analytics_pass@localhost:5433/analytics", "engine": "postgresql"}	2026-06-28 12:45:16.988215	\N	\N	\N	http://localhost:8088/databaseview/list/
115	test_connection_error.DBAPIError	1	{"path": "/api/v1/database/", "database_name": "PostgreSQL", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "masked_encrypted_extra": "{}", "sqlalchemy_uri": "postgresql+psycopg2://analytics:analytics_pass@localhost:5432/analytics", "engine": "postgresql"}	2026-06-28 12:45:22.05672	\N	\N	\N	http://localhost:8088/databaseview/list/
65	test_connection_error.DBAPIError	1	{"path": "/api/v1/database/", "database_name": "PostgreSQL", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "masked_encrypted_extra": "{}", "sqlalchemy_uri": "postgresql+psycopg2://admin:admin123@localhost:5432/analytics", "engine": "postgresql"}	2026-06-28 12:42:06.581389	\N	\N	\N	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
70	test_connection_attempt	1	{"path": "/api/v1/database/", "database_name": "PostgreSQL", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "masked_encrypted_extra": "{}", "sqlalchemy_uri": "postgresql+psycopg2://admin:admin123@db-1:5432/analytics", "engine": "postgresql"}	2026-06-28 12:42:37.11674	\N	\N	\N	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
75	validation_error	1	{"path": "/api/v1/database/validate_parameters/", "database_name": "PostgreSQL", "engine": "postgresql", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "driver": "psycopg2", "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "parameters": {"host": "localhost", "port": "5433", "database": "analytics", "username": "admin", "password": "admin123"}}	2026-06-28 12:42:51.825888	\N	\N	\N	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
80	DatabaseRestApi.post	1	{"path": "/api/v1/database/", "database_name": "PostgreSQL", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "masked_encrypted_extra": "{}", "sqlalchemy_uri": "postgresql+psycopg2://admin:admin123@localhost:5433/analytics", "object_ref": "DatabaseRestApi.post"}	2026-06-28 12:42:51.9793	\N	\N	35	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
84	DatabaseRestApi.info	1	{"path": "/api/v1/database/_info", "q": "(keys:!(permissions))", "rison": {"keys": ["permissions"]}}	2026-06-28 12:43:33.410401	\N	\N	51	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
92	DatabaseRestApi.test_connection	1	{"path": "/api/v1/database/test_connection/", "sqlalchemy_uri": "postgresql+psycopg2://analytics:XXXXXXXXXX@db:5432/analytics", "database_name": "Analytics PostgreSQL", "extra": "{\\n    \\"metadata_params\\": {},\\n    \\"engine_params\\": {},\\n    \\"metadata_cache_timeout\\": {},\\n    \\"schemas_allowed_for_file_upload\\": []\\n}\\n", "masked_encrypted_extra": "", "object_ref": "DatabaseRestApi.test_connection"}	2026-06-28 12:43:38.155715	\N	\N	26	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
96	DatabaseRestApi.get_list	1	{"path": "/api/v1/database/", "q": "(filters:!((col:allow_file_upload,opr:upload_is_enabled,value:!t)))", "rison": {"filters": [{"col": "allow_file_upload", "opr": "upload_is_enabled", "value": true}]}}	2026-06-28 12:43:50.880657	\N	\N	28	http://localhost:8088/databaseview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
101	validation_error	1	{"path": "/api/v1/database/validate_parameters/", "database_name": "PostgreSQL", "engine": "postgresql", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "driver": "psycopg2", "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true}	2026-06-28 12:44:56.356431	\N	\N	\N	http://localhost:8088/databaseview/list/
106	validation_error	1	{"path": "/api/v1/database/validate_parameters/", "database_name": "PostgreSQL", "engine": "postgresql", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "driver": "psycopg2", "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "parameters": {"database": "analytics", "username": "analytics", "password": "analytics_pass", "host": "localhost", "port": "5433"}}	2026-06-28 12:45:15.749828	\N	\N	\N	http://localhost:8088/databaseview/list/
111	DatabaseRestApi.post	1	{"path": "/api/v1/database/", "database_name": "PostgreSQL", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "masked_encrypted_extra": "{}", "sqlalchemy_uri": "postgresql+psycopg2://analytics:analytics_pass@localhost:5433/analytics", "object_ref": "DatabaseRestApi.post"}	2026-06-28 12:45:16.992326	\N	\N	37	http://localhost:8088/databaseview/list/
116	db_creation_failed.SupersetErrorsException	1	{"path": "/api/v1/database/", "database_name": "PostgreSQL", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "masked_encrypted_extra": "{}", "sqlalchemy_uri": "postgresql+psycopg2://analytics:analytics_pass@localhost:5432/analytics", "engine": "postgresql"}	2026-06-28 12:45:22.062036	\N	\N	\N	http://localhost:8088/databaseview/list/
118	DatabaseRestApi.validate_parameters	1	{"path": "/api/v1/database/validate_parameters/", "database_name": "PostgreSQL", "engine": "postgresql", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "driver": "psycopg2", "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "parameters": {"database": "analytics", "username": "analytics", "password": "analytics_pass", "host": "db", "port": "5432"}, "object_ref": "DatabaseRestApi.validate_parameters"}	2026-06-28 12:46:26.424572	\N	\N	25	http://localhost:8088/databaseview/list/
119	DatabaseRestApi.validate_parameters	1	{"path": "/api/v1/database/validate_parameters/", "database_name": "PostgreSQL", "engine": "postgresql", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "driver": "psycopg2", "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "parameters": {"database": "analytics", "username": "analytics", "password": "analytics_pass", "host": "db", "port": "5432"}, "object_ref": "DatabaseRestApi.validate_parameters"}	2026-06-28 12:46:27.339402	\N	\N	23	http://localhost:8088/databaseview/list/
120	test_connection_attempt	1	{"path": "/api/v1/database/", "database_name": "PostgreSQL", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "masked_encrypted_extra": "{}", "sqlalchemy_uri": "postgresql+psycopg2://analytics:analytics_pass@db:5432/analytics", "engine": "postgresql"}	2026-06-28 12:46:27.386622	\N	\N	\N	http://localhost:8088/databaseview/list/
121	test_connection_success	1	{"path": "/api/v1/database/", "database_name": "PostgreSQL", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "masked_encrypted_extra": "{}", "sqlalchemy_uri": "postgresql+psycopg2://analytics:analytics_pass@db:5432/analytics", "engine": "postgresql"}	2026-06-28 12:46:27.405419	\N	\N	\N	http://localhost:8088/databaseview/list/
122	DatabaseRestApi.post	1	{"path": "/api/v1/database/", "database_name": "PostgreSQL", "configuration_method": "dynamic_form", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "sqlalchemy_uri_placeholder": "postgresql://user:password@host:port/dbname[?key=value&key=value...]", "extra": "{\\"allows_virtual_table_explore\\":true}", "expose_in_sqllab": true, "masked_encrypted_extra": "{}", "sqlalchemy_uri": "postgresql+psycopg2://analytics:analytics_pass@db:5432/analytics", "object_ref": "DatabaseRestApi.post"}	2026-06-28 12:46:27.527507	\N	\N	153	http://localhost:8088/databaseview/list/
123	DatabaseRestApi.get_list	1	{"path": "/api/v1/database/", "q": "(order_column:changed_on_delta_humanized,order_direction:desc,page:0,page_size:25)", "rison": {"order_column": "changed_on_delta_humanized", "order_direction": "desc", "page": 0, "page_size": 25}}	2026-06-28 12:46:27.640872	\N	\N	27	http://localhost:8088/databaseview/list/
125	validation_error	1	{"path": "/api/v1/database/validate_parameters/", "allow_ctas": false, "allow_cvas": false, "allow_dml": false, "allow_file_upload": false, "allow_run_async": false, "backend": "postgresql", "cache_timeout": null, "configuration_method": "dynamic_form", "database_name": "PostgreSQL", "driver": "psycopg2", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "expose_in_sqllab": true, "extra": "{\\"allows_virtual_table_explore\\":true}", "force_ctas_schema": null, "id": 2, "impersonate_user": false, "is_managed_externally": false, "masked_encrypted_extra": "{}", "parameters": {"database": "analytics", "encryption": false, "host": "db", "password": "XXXXXXXXXX", "port": "5433", "query": {}, "username": "analytics"}, "parameters_schema": {"properties": {"database": {"description": "Database name", "type": "string"}, "encryption": {"description": "Use an encrypted connection to the database", "type": "boolean"}, "host": {"description": "Hostname or IP address", "type": "string"}, "password": {"description": "Password", "nullable": true, "type": "string"}, "port": {"description": "Database port", "maximum": 65536, "minimum": 0, "type": "integer"}, "query": {"additionalProperties": {}, "description": "Additional parameters", "type": "object"}, "ssh": {"description": "Use an ssh tunnel connection to the database", "type": "boolean"}, "username": {"description": "Username", "nullable": true, "type": "string"}}, "required": ["database", "host", "port", "username"], "type": "object"}, "server_cert": null, "sqlalchemy_uri": "postgresql+psycopg2://analytics:XXXXXXXXXX@db:5432/analytics", "ssh_tunnel": null, "uuid": "edb9b9c2-dfa8-425e-893c-c11255ac5349", "engine": "postgresql", "catalog": {}, "query_input": ""}	2026-06-28 12:46:35.363967	\N	\N	\N	http://localhost:8088/databaseview/list/
126	DatabaseRestApi.put	1	{"path": "/api/v1/database/2", "allow_ctas": false, "allow_cvas": false, "allow_dml": false, "allow_file_upload": false, "allow_run_async": false, "backend": "postgresql", "cache_timeout": null, "configuration_method": "dynamic_form", "database_name": "PostgreSQL", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "expose_in_sqllab": true, "extra": "{\\"allows_virtual_table_explore\\":true}", "force_ctas_schema": null, "id": 2, "impersonate_user": false, "is_managed_externally": false, "masked_encrypted_extra": "{}", "parameters_schema": {"properties": {"database": {"description": "Database name", "type": "string"}, "encryption": {"description": "Use an encrypted connection to the database", "type": "boolean"}, "host": {"description": "Hostname or IP address", "type": "string"}, "password": {"description": "Password", "nullable": true, "type": "string"}, "port": {"description": "Database port", "maximum": 65536, "minimum": 0, "type": "integer"}, "query": {"additionalProperties": {}, "description": "Additional parameters", "type": "object"}, "ssh": {"description": "Use an ssh tunnel connection to the database", "type": "boolean"}, "username": {"description": "Username", "nullable": true, "type": "string"}}, "required": ["database", "host", "port", "username"], "type": "object"}, "server_cert": null, "sqlalchemy_uri": "postgresql+psycopg2://analytics:XXXXXXXXXX@db:5433/analytics", "ssh_tunnel": null, "uuid": "edb9b9c2-dfa8-425e-893c-c11255ac5349", "catalog": [], "query_input": "", "url_rule": "/api/v1/database/<int:pk>", "object_ref": "DatabaseRestApi.put", "pk": 2}	2026-06-28 12:46:35.456737	\N	\N	61	http://localhost:8088/databaseview/list/
132	DatabaseRestApi.put	1	{"path": "/api/v1/database/2", "allow_ctas": false, "allow_cvas": false, "allow_dml": false, "allow_file_upload": false, "allow_run_async": false, "cache_timeout": null, "configuration_method": "dynamic_form", "database_name": "PostgreSQL", "expose_in_sqllab": true, "extra": "{\\"allows_virtual_table_explore\\":true}", "force_ctas_schema": null, "impersonate_user": false, "is_managed_externally": false, "masked_encrypted_extra": "{}", "server_cert": null, "sqlalchemy_uri": "postgresql+psycopg2://analytics:XXXXXXXXXX@db:5432/analytics", "ssh_tunnel": null, "uuid": "edb9b9c2-dfa8-425e-893c-c11255ac5349", "id": 2, "catalog": [], "query_input": "", "url_rule": "/api/v1/database/<int:pk>", "object_ref": "DatabaseRestApi.put", "pk": 2}	2026-06-28 12:46:49.688905	\N	\N	131	http://localhost:8088/databaseview/list/
196	SqlLabRestApi.get	1	{"path": "/api/v1/sqllab/", "object_ref": "SqlLabRestApi.get"}	2026-06-28 12:54:13.247524	\N	\N	10	http://localhost:8088/sqllab
124	validation_error	1	{"path": "/api/v1/database/validate_parameters/", "allow_ctas": false, "allow_cvas": false, "allow_dml": false, "allow_file_upload": false, "allow_run_async": false, "backend": "postgresql", "cache_timeout": null, "configuration_method": "dynamic_form", "database_name": "PostgreSQL", "driver": "psycopg2", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "expose_in_sqllab": true, "extra": "{\\"allows_virtual_table_explore\\":true}", "force_ctas_schema": null, "id": 2, "impersonate_user": false, "is_managed_externally": false, "masked_encrypted_extra": "{}", "parameters": {"database": "analytics", "encryption": false, "host": "db", "password": "XXXXXXXXXX", "port": "5433", "query": {}, "username": "analytics"}, "parameters_schema": {"properties": {"database": {"description": "Database name", "type": "string"}, "encryption": {"description": "Use an encrypted connection to the database", "type": "boolean"}, "host": {"description": "Hostname or IP address", "type": "string"}, "password": {"description": "Password", "nullable": true, "type": "string"}, "port": {"description": "Database port", "maximum": 65536, "minimum": 0, "type": "integer"}, "query": {"additionalProperties": {}, "description": "Additional parameters", "type": "object"}, "ssh": {"description": "Use an ssh tunnel connection to the database", "type": "boolean"}, "username": {"description": "Username", "nullable": true, "type": "string"}}, "required": ["database", "host", "port", "username"], "type": "object"}, "server_cert": null, "sqlalchemy_uri": "postgresql+psycopg2://analytics:XXXXXXXXXX@db:5432/analytics", "ssh_tunnel": null, "uuid": "edb9b9c2-dfa8-425e-893c-c11255ac5349", "engine": "postgresql", "catalog": {}, "query_input": ""}	2026-06-28 12:46:35.278106	\N	\N	\N	http://localhost:8088/databaseview/list/
127	DatabaseRestApi.validate_parameters	1	{"path": "/api/v1/database/validate_parameters/", "allow_ctas": false, "allow_cvas": false, "allow_dml": false, "allow_file_upload": false, "allow_run_async": false, "backend": "postgresql", "cache_timeout": null, "configuration_method": "dynamic_form", "database_name": "PostgreSQL", "driver": "psycopg2", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "expose_in_sqllab": true, "extra": "{\\"allows_virtual_table_explore\\":true}", "force_ctas_schema": null, "id": 2, "impersonate_user": false, "is_managed_externally": false, "masked_encrypted_extra": "{}", "parameters": {"database": "analytics", "encryption": false, "host": "db", "password": "XXXXXXXXXX", "port": "5432", "query": {}, "username": "analytics"}, "parameters_schema": {"properties": {"database": {"description": "Database name", "type": "string"}, "encryption": {"description": "Use an encrypted connection to the database", "type": "boolean"}, "host": {"description": "Hostname or IP address", "type": "string"}, "password": {"description": "Password", "nullable": true, "type": "string"}, "port": {"description": "Database port", "maximum": 65536, "minimum": 0, "type": "integer"}, "query": {"additionalProperties": {}, "description": "Additional parameters", "type": "object"}, "ssh": {"description": "Use an ssh tunnel connection to the database", "type": "boolean"}, "username": {"description": "Username", "nullable": true, "type": "string"}}, "required": ["database", "host", "port", "username"], "type": "object"}, "server_cert": null, "sqlalchemy_uri": "postgresql+psycopg2://analytics:XXXXXXXXXX@db:5432/analytics", "ssh_tunnel": null, "uuid": "edb9b9c2-dfa8-425e-893c-c11255ac5349", "engine": "postgresql", "catalog": {}, "query_input": "", "object_ref": "DatabaseRestApi.validate_parameters"}	2026-06-28 12:46:44.114278	\N	\N	44	http://localhost:8088/databaseview/list/
131	DatabaseRestApi.validate_parameters	1	{"path": "/api/v1/database/validate_parameters/", "allow_ctas": false, "allow_cvas": false, "allow_dml": false, "allow_file_upload": false, "allow_run_async": false, "cache_timeout": null, "configuration_method": "dynamic_form", "database_name": "PostgreSQL", "expose_in_sqllab": true, "extra": "{\\"allows_virtual_table_explore\\":true}", "force_ctas_schema": null, "impersonate_user": false, "is_managed_externally": false, "masked_encrypted_extra": "{}", "parameters": {"database": "analytics", "encryption": false, "host": "db", "password": "XXXXXXXXXX", "port": 5432, "query": {}, "username": "analytics"}, "server_cert": null, "sqlalchemy_uri": "postgresql+psycopg2://analytics:XXXXXXXXXX@db:5432/analytics", "ssh_tunnel": null, "uuid": "edb9b9c2-dfa8-425e-893c-c11255ac5349", "id": 2, "engine": "postgresql", "catalog": {}, "query_input": "", "object_ref": "DatabaseRestApi.validate_parameters"}	2026-06-28 12:46:49.527067	\N	\N	45	http://localhost:8088/databaseview/list/
139	DatabaseRestApi.validate_parameters	1	{"path": "/api/v1/database/validate_parameters/", "allow_ctas": false, "allow_cvas": false, "allow_dml": false, "allow_file_upload": false, "allow_run_async": false, "backend": "postgresql", "cache_timeout": null, "configuration_method": "dynamic_form", "database_name": "PostgreSQL", "driver": "psycopg2", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "expose_in_sqllab": true, "extra": "{\\"allows_virtual_table_explore\\":true}", "force_ctas_schema": null, "id": 2, "impersonate_user": false, "is_managed_externally": false, "masked_encrypted_extra": "{}", "parameters": {"database": "analytics", "encryption": false, "host": "db", "password": "XXXXXXXXXX", "port": 5432, "query": {}, "username": "analytics"}, "parameters_schema": {"properties": {"database": {"description": "Database name", "type": "string"}, "encryption": {"description": "Use an encrypted connection to the database", "type": "boolean"}, "host": {"description": "Hostname or IP address", "type": "string"}, "password": {"description": "Password", "nullable": true, "type": "string"}, "port": {"description": "Database port", "maximum": 65536, "minimum": 0, "type": "integer"}, "query": {"additionalProperties": {}, "description": "Additional parameters", "type": "object"}, "ssh": {"description": "Use an ssh tunnel connection to the database", "type": "boolean"}, "username": {"description": "Username", "nullable": true, "type": "string"}}, "required": ["database", "host", "port", "username"], "type": "object"}, "server_cert": null, "sqlalchemy_uri": "postgresql+psycopg2://analytics:XXXXXXXXXX@db:5432/analytics", "ssh_tunnel": null, "uuid": "edb9b9c2-dfa8-425e-893c-c11255ac5349", "engine": "postgresql", "catalog": {}, "query_input": "", "object_ref": "DatabaseRestApi.validate_parameters"}	2026-06-28 12:49:37.530784	\N	\N	46	http://localhost:8088/databaseview/list/
144	DatabaseRestApi.available	1	{"path": "/api/v1/database/available/", "object_ref": "DatabaseRestApi.available"}	2026-06-28 12:49:38.091927	\N	\N	96	http://localhost:8088/databaseview/list/
149	DatasetRestApi.info	1	{"path": "/api/v1/dataset/_info", "q": "(keys:!(permissions))", "rison": {"keys": ["permissions"]}}	2026-06-28 12:49:41.791859	\N	\N	30	http://localhost:8088/tablemodelview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
156	DatabaseRestApi.tables	1	{"path": "/api/v1/database/1/tables/", "q": "(force:!f,schema_name:public)", "url_rule": "/api/v1/database/<int:pk>/tables/", "object_ref": "DatabaseRestApi.tables", "pk": 1, "rison": {"force": false, "schema_name": "public"}}	2026-06-28 12:49:51.054862	\N	\N	123	http://localhost:8088/dataset/add/
198	DatabaseRestApi.function_names	1	{"path": "/api/v1/database/1/function_names/", "url_rule": "/api/v1/database/<int:pk>/function_names/", "object_ref": "DatabaseRestApi.function_names", "pk": 1}	2026-06-28 12:54:13.567433	\N	\N	9	http://localhost:8088/sqllab
128	DatabaseRestApi.validate_parameters	1	{"path": "/api/v1/database/validate_parameters/", "allow_ctas": false, "allow_cvas": false, "allow_dml": false, "allow_file_upload": false, "allow_run_async": false, "backend": "postgresql", "cache_timeout": null, "configuration_method": "dynamic_form", "database_name": "PostgreSQL", "driver": "psycopg2", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "expose_in_sqllab": true, "extra": "{\\"allows_virtual_table_explore\\":true}", "force_ctas_schema": null, "id": 2, "impersonate_user": false, "is_managed_externally": false, "masked_encrypted_extra": "{}", "parameters": {"database": "analytics", "encryption": false, "host": "db", "password": "XXXXXXXXXX", "port": "5432", "query": {}, "username": "analytics"}, "parameters_schema": {"properties": {"database": {"description": "Database name", "type": "string"}, "encryption": {"description": "Use an encrypted connection to the database", "type": "boolean"}, "host": {"description": "Hostname or IP address", "type": "string"}, "password": {"description": "Password", "nullable": true, "type": "string"}, "port": {"description": "Database port", "maximum": 65536, "minimum": 0, "type": "integer"}, "query": {"additionalProperties": {}, "description": "Additional parameters", "type": "object"}, "ssh": {"description": "Use an ssh tunnel connection to the database", "type": "boolean"}, "username": {"description": "Username", "nullable": true, "type": "string"}}, "required": ["database", "host", "port", "username"], "type": "object"}, "server_cert": null, "sqlalchemy_uri": "postgresql+psycopg2://analytics:XXXXXXXXXX@db:5432/analytics", "ssh_tunnel": null, "uuid": "edb9b9c2-dfa8-425e-893c-c11255ac5349", "engine": "postgresql", "catalog": {}, "query_input": "", "object_ref": "DatabaseRestApi.validate_parameters"}	2026-06-28 12:46:44.825618	\N	\N	45	http://localhost:8088/databaseview/list/
136	DatabaseRestApi.available	1	{"path": "/api/v1/database/available/", "object_ref": "DatabaseRestApi.available"}	2026-06-28 12:46:52.569873	\N	\N	361	http://localhost:8088/databaseview/list/
146	DashboardRestApi.info	1	{"path": "/api/v1/dashboard/_info", "q": "(keys:!(permissions))", "rison": {"keys": ["permissions"]}}	2026-06-28 12:49:40.895698	\N	\N	46	http://localhost:8088/dashboard/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc&viewMode=table
152	DatabaseRestApi.get_list	1	{"path": "/api/v1/database/", "q": "(filters:!((col:database_name,opr:ct,value:'')),order_column:database_name,order_direction:asc,page:0,page_size:100)", "rison": {"filters": [{"col": "database_name", "opr": "ct", "value": ""}], "order_column": "database_name", "order_direction": "asc", "page": 0, "page_size": 100}}	2026-06-28 12:49:46.461797	\N	\N	22	http://localhost:8088/dataset/add/
157	DatabaseRestApi.schemas	1	{"path": "/api/v1/database/1/schemas/", "q": "(force:!t)", "url_rule": "/api/v1/database/<int:pk>/schemas/", "object_ref": "DatabaseRestApi.schemas", "pk": 1, "rison": {"force": true}}	2026-06-28 12:49:51.629819	\N	\N	30	http://localhost:8088/dataset/add/
161	log	1	{"impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651022644, "event_name": "spa_navigation", "path": "/chart/add/", "event_type": "user", "event_id": "Fg5nj2eT_sxNY3nSLPlvm", "visibility": "visible"}	2026-06-28 12:50:23.661244	\N	\N	0	http://localhost:8088/chart/add/?dataset=ventas
170	load_into_dataframe	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": [{"timeGrain": "P1D", "columnType": "BASE_AXIS", "sqlExpression": "categoria", "label": "categoria", "expressionType": "SQL", "isColumnReference": true}], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 10000, "series_columns": [], "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "viz_type": "echarts_timeseries_bar"}, "custom_params": {}, "custom_form_data": {}, "time_offsets": [], "post_processing": [{"operation": "pivot", "options": {"index": ["categoria"], "columns": [], "aggregates": {"count": {"operator": "mean"}}, "drop_missing_columns": false}}, {"operation": "flatten"}]}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": [{"timeGrain": "P1D", "columnType": "BASE_AXIS", "sqlExpression": "categoria", "label": "categoria", "expressionType": "SQL", "isColumnReference": true}], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 10000, "series_columns": [], "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "viz_type": "echarts_timeseries_bar"}, "custom_params": {}, "custom_form_data": {}, "time_offsets": [], "post_processing": [{"operation": "pivot", "options": {"index": ["categoria"], "columns": [], "aggregates": {"count": {"operator": "mean"}}, "drop_missing_columns": false}}, {"operation": "flatten"}]}, "result_format": "json", "result_type": "full", "object_ref": "Database.load_into_dataframe"}	2026-06-28 12:51:21.403314	\N	\N	23	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&viz_type=echarts_timeseries_bar&datasource=1__table&datasource_id=1&datasource_type=table
175	execute_sql	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": [{"timeGrain": "P1D", "columnType": "BASE_AXIS", "sqlExpression": "categoria", "label": "categoria", "expressionType": "SQL", "isColumnReference": true}], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 1000, "series_columns": [], "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "viz_type": "echarts_timeseries_bar"}, "custom_params": {}, "custom_form_data": {}, "time_offsets": [], "post_processing": [{"operation": "pivot", "options": {"index": ["categoria"], "columns": [], "aggregates": {"count": {"operator": "mean"}}, "drop_missing_columns": false}}, {"operation": "flatten"}]}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": [{"timeGrain": "P1D", "columnType": "BASE_AXIS", "sqlExpression": "categoria", "label": "categoria", "expressionType": "SQL", "isColumnReference": true}], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 1000, "series_columns": [], "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "viz_type": "echarts_timeseries_bar"}, "custom_params": {}, "custom_form_data": {}, "time_offsets": [], "post_processing": [{"operation": "pivot", "options": {"index": ["categoria"], "columns": [], "aggregates": {"count": {"operator": "mean"}}, "drop_missing_columns": false}}, {"operation": "flatten"}]}, "result_format": "json", "result_type": "results", "object_ref": "superset.models.core"}	2026-06-28 12:51:21.53706	\N	\N	1	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&viz_type=echarts_timeseries_bar&datasource=1__table&datasource_id=1&datasource_type=table
180	ChartDataRestApi.data	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": [{"timeGrain": "P1D", "columnType": "BASE_AXIS", "sqlExpression": "categoria", "label": "categoria", "expressionType": "SQL", "isColumnReference": true}], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 1000, "series_columns": [], "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "viz_type": "echarts_timeseries_bar"}, "custom_params": {}, "custom_form_data": {}, "time_offsets": [], "post_processing": [{"operation": "pivot", "options": {"index": ["categoria"], "columns": [], "aggregates": {"count": {"operator": "mean"}}, "drop_missing_columns": false}}, {"operation": "flatten"}]}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": [{"timeGrain": "P1D", "columnType": "BASE_AXIS", "sqlExpression": "categoria", "label": "categoria", "expressionType": "SQL", "isColumnReference": true}], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 1000, "series_columns": [], "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "viz_type": "echarts_timeseries_bar"}, "custom_params": {}, "custom_form_data": {}, "time_offsets": [], "post_processing": [{"operation": "pivot", "options": {"index": ["categoria"], "columns": [], "aggregates": {"count": {"operator": "mean"}}, "drop_missing_columns": false}}, {"operation": "flatten"}]}, "result_format": "json", "result_type": "results", "object_ref": "ChartDataRestApi.data", "is_cached": [null]}	2026-06-28 12:51:21.580093	\N	\N	75	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&viz_type=echarts_timeseries_bar&datasource=1__table&datasource_id=1&datasource_type=table
183	ExploreFormDataRestApi.put	1	{"path": "/api/v1/explore/form_data/qmxrMRhqerk", "tab_id": "3", "datasource_id": 1, "datasource_type": "table", "form_data": {}, "url_rule": "/api/v1/explore/form_data/<string:key>", "object_ref": "ExploreFormDataRestApi.put", "key": "qmxrMRhqerk"}	2026-06-28 12:51:39.297455	\N	\N	12	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&viz_type=echarts_timeseries_bar&datasource=1__table&datasource_id=1&datasource_type=table
129	DatabaseRestApi.put	1	{"path": "/api/v1/database/2", "allow_ctas": false, "allow_cvas": false, "allow_dml": false, "allow_file_upload": false, "allow_run_async": false, "backend": "postgresql", "cache_timeout": null, "configuration_method": "dynamic_form", "database_name": "PostgreSQL", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "expose_in_sqllab": true, "extra": "{\\"allows_virtual_table_explore\\":true}", "force_ctas_schema": null, "id": 2, "impersonate_user": false, "is_managed_externally": false, "masked_encrypted_extra": "{}", "parameters_schema": {"properties": {"database": {"description": "Database name", "type": "string"}, "encryption": {"description": "Use an encrypted connection to the database", "type": "boolean"}, "host": {"description": "Hostname or IP address", "type": "string"}, "password": {"description": "Password", "nullable": true, "type": "string"}, "port": {"description": "Database port", "maximum": 65536, "minimum": 0, "type": "integer"}, "query": {"additionalProperties": {}, "description": "Additional parameters", "type": "object"}, "ssh": {"description": "Use an ssh tunnel connection to the database", "type": "boolean"}, "username": {"description": "Username", "nullable": true, "type": "string"}}, "required": ["database", "host", "port", "username"], "type": "object"}, "server_cert": null, "sqlalchemy_uri": "postgresql+psycopg2://analytics:XXXXXXXXXX@db:5432/analytics", "ssh_tunnel": null, "uuid": "edb9b9c2-dfa8-425e-893c-c11255ac5349", "catalog": [], "query_input": "", "url_rule": "/api/v1/database/<int:pk>", "object_ref": "DatabaseRestApi.put", "pk": 2}	2026-06-28 12:46:44.996091	\N	\N	136	http://localhost:8088/databaseview/list/
130	DatabaseRestApi.get_list	1	{"path": "/api/v1/database/", "q": "(order_column:changed_on_delta_humanized,order_direction:desc,page:0,page_size:25)", "rison": {"order_column": "changed_on_delta_humanized", "order_direction": "desc", "page": 0, "page_size": 25}}	2026-06-28 12:46:45.110344	\N	\N	28	http://localhost:8088/databaseview/list/
133	DatabaseRestApi.get_list	1	{"path": "/api/v1/database/", "q": "(order_column:changed_on_delta_humanized,order_direction:desc,page:0,page_size:25)", "rison": {"order_column": "changed_on_delta_humanized", "order_direction": "desc", "page": 0, "page_size": 25}}	2026-06-28 12:46:49.861329	\N	\N	44	http://localhost:8088/databaseview/list/
134	DatabaseRestApi.get_list	1	{"path": "/api/v1/database/", "q": "(filters:!((col:allow_file_upload,opr:upload_is_enabled,value:!t)))", "rison": {"filters": [{"col": "allow_file_upload", "opr": "upload_is_enabled", "value": true}]}}	2026-06-28 12:46:49.867411	\N	\N	33	http://localhost:8088/databaseview/list/
137	DatabaseRestApi.validate_parameters	1	{"path": "/api/v1/database/validate_parameters/", "allow_ctas": false, "allow_cvas": false, "allow_dml": false, "allow_file_upload": false, "allow_run_async": false, "backend": "postgresql", "cache_timeout": null, "configuration_method": "dynamic_form", "database_name": "PostgreSQL", "driver": "psycopg2", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "expose_in_sqllab": true, "extra": "{\\"allows_virtual_table_explore\\":true}", "force_ctas_schema": null, "id": 2, "impersonate_user": false, "is_managed_externally": false, "masked_encrypted_extra": "{}", "parameters": {"database": "analytics", "encryption": false, "host": "db", "password": "XXXXXXXXXX", "port": 5432, "query": {}, "username": "analytics"}, "parameters_schema": {"properties": {"database": {"description": "Database name", "type": "string"}, "encryption": {"description": "Use an encrypted connection to the database", "type": "boolean"}, "host": {"description": "Hostname or IP address", "type": "string"}, "password": {"description": "Password", "nullable": true, "type": "string"}, "port": {"description": "Database port", "maximum": 65536, "minimum": 0, "type": "integer"}, "query": {"additionalProperties": {}, "description": "Additional parameters", "type": "object"}, "ssh": {"description": "Use an ssh tunnel connection to the database", "type": "boolean"}, "username": {"description": "Username", "nullable": true, "type": "string"}}, "required": ["database", "host", "port", "username"], "type": "object"}, "server_cert": null, "sqlalchemy_uri": "postgresql+psycopg2://analytics:XXXXXXXXXX@db:5432/analytics", "ssh_tunnel": null, "uuid": "edb9b9c2-dfa8-425e-893c-c11255ac5349", "engine": "postgresql", "catalog": {}, "query_input": "", "object_ref": "DatabaseRestApi.validate_parameters"}	2026-06-28 12:47:04.155055	\N	\N	44	http://localhost:8088/databaseview/list/
138	DatabaseRestApi.validate_parameters	1	{"path": "/api/v1/database/validate_parameters/", "allow_ctas": false, "allow_cvas": false, "allow_dml": false, "allow_file_upload": false, "allow_run_async": false, "backend": "postgresql", "cache_timeout": null, "configuration_method": "dynamic_form", "database_name": "PostgreSQL", "driver": "psycopg2", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "expose_in_sqllab": true, "extra": "{\\"allows_virtual_table_explore\\":true}", "force_ctas_schema": null, "id": 2, "impersonate_user": false, "is_managed_externally": false, "masked_encrypted_extra": "{}", "parameters": {"database": "analytics", "encryption": false, "host": "db", "password": "XXXXXXXXXX", "port": 5432, "query": {}, "username": "analytics"}, "parameters_schema": {"properties": {"database": {"description": "Database name", "type": "string"}, "encryption": {"description": "Use an encrypted connection to the database", "type": "boolean"}, "host": {"description": "Hostname or IP address", "type": "string"}, "password": {"description": "Password", "nullable": true, "type": "string"}, "port": {"description": "Database port", "maximum": 65536, "minimum": 0, "type": "integer"}, "query": {"additionalProperties": {}, "description": "Additional parameters", "type": "object"}, "ssh": {"description": "Use an ssh tunnel connection to the database", "type": "boolean"}, "username": {"description": "Username", "nullable": true, "type": "string"}}, "required": ["database", "host", "port", "username"], "type": "object"}, "server_cert": null, "sqlalchemy_uri": "postgresql+psycopg2://analytics:XXXXXXXXXX@db:5432/analytics", "ssh_tunnel": null, "uuid": "edb9b9c2-dfa8-425e-893c-c11255ac5349", "engine": "postgresql", "catalog": {}, "query_input": "", "object_ref": "DatabaseRestApi.validate_parameters"}	2026-06-28 12:47:21.981254	\N	\N	42	http://localhost:8088/databaseview/list/
142	DatabaseRestApi.get_list	1	{"path": "/api/v1/database/", "q": "(order_column:changed_on_delta_humanized,order_direction:desc,page:0,page_size:25)", "rison": {"order_column": "changed_on_delta_humanized", "order_direction": "desc", "page": 0, "page_size": 25}}	2026-06-28 12:49:38.048643	\N	\N	47	http://localhost:8088/databaseview/list/
147	DashboardRestApi.get_list	1	{"path": "/api/v1/dashboard/", "q": "(order_column:changed_on_delta_humanized,order_direction:desc,page:0,page_size:25,select_columns:!(id,dashboard_title,published,url,slug,changed_by,changed_by.id,changed_by.first_name,changed_by.last_name,changed_on_delta_humanized,owners,owners.id,owners.first_name,owners.last_name,tags.id,tags.name,tags.type,status,certified_by,certification_details,changed_on))", "object_ref": "DashboardRestApi.get_list"}	2026-06-28 12:49:40.902348	\N	\N	47	http://localhost:8088/dashboard/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc&viewMode=table
248	_get_data_response	1	\N	2026-06-28 12:54:55.993898	\N	\N	105	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
140	DatabaseRestApi.validate_parameters	1	{"path": "/api/v1/database/validate_parameters/", "allow_ctas": false, "allow_cvas": false, "allow_dml": false, "allow_file_upload": false, "allow_run_async": false, "backend": "postgresql", "cache_timeout": null, "configuration_method": "dynamic_form", "database_name": "PostgreSQL", "driver": "psycopg2", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "expose_in_sqllab": true, "extra": "{\\"allows_virtual_table_explore\\":true}", "force_ctas_schema": null, "id": 2, "impersonate_user": false, "is_managed_externally": false, "masked_encrypted_extra": "{}", "parameters": {"database": "analytics", "encryption": false, "host": "db", "password": "XXXXXXXXXX", "port": 5432, "query": {}, "username": "analytics"}, "parameters_schema": {"properties": {"database": {"description": "Database name", "type": "string"}, "encryption": {"description": "Use an encrypted connection to the database", "type": "boolean"}, "host": {"description": "Hostname or IP address", "type": "string"}, "password": {"description": "Password", "nullable": true, "type": "string"}, "port": {"description": "Database port", "maximum": 65536, "minimum": 0, "type": "integer"}, "query": {"additionalProperties": {}, "description": "Additional parameters", "type": "object"}, "ssh": {"description": "Use an ssh tunnel connection to the database", "type": "boolean"}, "username": {"description": "Username", "nullable": true, "type": "string"}}, "required": ["database", "host", "port", "username"], "type": "object"}, "server_cert": null, "sqlalchemy_uri": "postgresql+psycopg2://analytics:XXXXXXXXXX@db:5432/analytics", "ssh_tunnel": null, "uuid": "edb9b9c2-dfa8-425e-893c-c11255ac5349", "engine": "postgresql", "catalog": {}, "query_input": "", "object_ref": "DatabaseRestApi.validate_parameters"}	2026-06-28 12:49:37.601364	\N	\N	46	http://localhost:8088/databaseview/list/
143	DatabaseRestApi.get_list	1	{"path": "/api/v1/database/", "q": "(filters:!((col:allow_file_upload,opr:upload_is_enabled,value:!t)))", "rison": {"filters": [{"col": "allow_file_upload", "opr": "upload_is_enabled", "value": true}]}}	2026-06-28 12:49:38.066176	\N	\N	41	http://localhost:8088/databaseview/list/
148	DatasetRestApi.get_list	1	{"path": "/api/v1/dataset/", "q": "(order_column:changed_on_delta_humanized,order_direction:desc,page:0,page_size:25)", "rison": {"order_column": "changed_on_delta_humanized", "order_direction": "desc", "page": 0, "page_size": 25}}	2026-06-28 12:49:41.789121	\N	\N	35	http://localhost:8088/tablemodelview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
154	DatabaseRestApi.schemas	1	{"path": "/api/v1/database/1/schemas/", "q": "(force:!f)", "url_rule": "/api/v1/database/<int:pk>/schemas/", "object_ref": "DatabaseRestApi.schemas", "pk": 1, "rison": {"force": false}}	2026-06-28 12:49:48.992696	\N	\N	32	http://localhost:8088/dataset/add/
163	DatabaseRestApi.table_extra_metadata	1	{"path": "/api/v1/database/1/table_metadata/extra/", "name": "ventas", "catalog": "analytics", "schema": "public", "url_rule": "/api/v1/database/<int:pk>/table_metadata/extra/", "object_ref": "DatabaseRestApi.table_extra_metadata", "pk": 1}	2026-06-28 12:50:49.401363	\N	\N	7	http://localhost:8088/explore/?viz_type=echarts_timeseries_bar&datasource=1__table
167	log	1	{"impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651060014, "event_name": "change_explore_controls", "event_type": "user", "event_id": "EOqWk1sz3H3-Qev7d65n1", "visibility": "visible"}	2026-06-28 12:51:01.031397	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&viz_type=echarts_timeseries_bar&datasource=1__table&datasource_id=1&datasource_type=table
172	ChartDataRestApi.json_dumps	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": [{"timeGrain": "P1D", "columnType": "BASE_AXIS", "sqlExpression": "categoria", "label": "categoria", "expressionType": "SQL", "isColumnReference": true}], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 10000, "series_columns": [], "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "viz_type": "echarts_timeseries_bar"}, "custom_params": {}, "custom_form_data": {}, "time_offsets": [], "post_processing": [{"operation": "pivot", "options": {"index": ["categoria"], "columns": [], "aggregates": {"count": {"operator": "mean"}}, "drop_missing_columns": false}}, {"operation": "flatten"}]}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": [{"timeGrain": "P1D", "columnType": "BASE_AXIS", "sqlExpression": "categoria", "label": "categoria", "expressionType": "SQL", "isColumnReference": true}], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 10000, "series_columns": [], "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "viz_type": "echarts_timeseries_bar"}, "custom_params": {}, "custom_form_data": {}, "time_offsets": [], "post_processing": [{"operation": "pivot", "options": {"index": ["categoria"], "columns": [], "aggregates": {"count": {"operator": "mean"}}, "drop_missing_columns": false}}, {"operation": "flatten"}]}, "result_format": "json", "result_type": "full"}	2026-06-28 12:51:21.439679	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&viz_type=echarts_timeseries_bar&datasource=1__table&datasource_id=1&datasource_type=table
177	QueryObject.post_processing	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": [{"timeGrain": "P1D", "columnType": "BASE_AXIS", "sqlExpression": "categoria", "label": "categoria", "expressionType": "SQL", "isColumnReference": true}], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 1000, "series_columns": [], "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "viz_type": "echarts_timeseries_bar"}, "custom_params": {}, "custom_form_data": {}, "time_offsets": [], "post_processing": [{"operation": "pivot", "options": {"index": ["categoria"], "columns": [], "aggregates": {"count": {"operator": "mean"}}, "drop_missing_columns": false}}, {"operation": "flatten"}]}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": [{"timeGrain": "P1D", "columnType": "BASE_AXIS", "sqlExpression": "categoria", "label": "categoria", "expressionType": "SQL", "isColumnReference": true}], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 1000, "series_columns": [], "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "viz_type": "echarts_timeseries_bar"}, "custom_params": {}, "custom_form_data": {}, "time_offsets": [], "post_processing": [{"operation": "pivot", "options": {"index": ["categoria"], "columns": [], "aggregates": {"count": {"operator": "mean"}}, "drop_missing_columns": false}}, {"operation": "flatten"}]}, "result_format": "json", "result_type": "results"}	2026-06-28 12:51:21.558718	\N	\N	2	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&viz_type=echarts_timeseries_bar&datasource=1__table&datasource_id=1&datasource_type=table
181	ExploreFormDataRestApi.put	1	{"path": "/api/v1/explore/form_data/qmxrMRhqerk", "tab_id": "3", "datasource_id": 1, "datasource_type": "table", "form_data": {}, "url_rule": "/api/v1/explore/form_data/<string:key>", "object_ref": "ExploreFormDataRestApi.put", "key": "qmxrMRhqerk"}	2026-06-28 12:51:22.2845	\N	\N	11	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&viz_type=echarts_timeseries_bar&datasource=1__table&datasource_id=1&datasource_type=table
184	DatabaseRestApi.get_list	1	{"path": "/api/v1/database/", "q": "(filters:!((col:database_name,opr:ct,value:'')),order_column:database_name,order_direction:asc,page:0,page_size:100)", "rison": {"filters": [{"col": "database_name", "opr": "ct", "value": ""}], "order_column": "database_name", "order_direction": "asc", "page": 0, "page_size": 100}}	2026-06-28 12:51:46.509813	\N	\N	78	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&viz_type=echarts_timeseries_bar&datasource=1__table&datasource_id=1&datasource_type=table
141	DatabaseRestApi.put	1	{"path": "/api/v1/database/2", "allow_ctas": false, "allow_cvas": false, "allow_dml": false, "allow_file_upload": false, "allow_run_async": false, "backend": "postgresql", "cache_timeout": null, "configuration_method": "dynamic_form", "database_name": "PostgreSQL", "engine_information": {"disable_ssh_tunneling": false, "supports_dynamic_catalog": true, "supports_file_upload": true, "supports_oauth2": false}, "expose_in_sqllab": true, "extra": "{\\"allows_virtual_table_explore\\":true}", "force_ctas_schema": null, "id": 2, "impersonate_user": false, "is_managed_externally": false, "masked_encrypted_extra": "{}", "parameters_schema": {"properties": {"database": {"description": "Database name", "type": "string"}, "encryption": {"description": "Use an encrypted connection to the database", "type": "boolean"}, "host": {"description": "Hostname or IP address", "type": "string"}, "password": {"description": "Password", "nullable": true, "type": "string"}, "port": {"description": "Database port", "maximum": 65536, "minimum": 0, "type": "integer"}, "query": {"additionalProperties": {}, "description": "Additional parameters", "type": "object"}, "ssh": {"description": "Use an ssh tunnel connection to the database", "type": "boolean"}, "username": {"description": "Username", "nullable": true, "type": "string"}}, "required": ["database", "host", "port", "username"], "type": "object"}, "server_cert": null, "sqlalchemy_uri": "postgresql+psycopg2://analytics:XXXXXXXXXX@db:5432/analytics", "ssh_tunnel": null, "uuid": "edb9b9c2-dfa8-425e-893c-c11255ac5349", "catalog": [], "query_input": "", "url_rule": "/api/v1/database/<int:pk>", "object_ref": "DatabaseRestApi.put", "pk": 2}	2026-06-28 12:49:37.76714	\N	\N	131	http://localhost:8088/databaseview/list/
145	DashboardRestApi.get_list	1	{"path": "/api/v1/dashboard/", "q": "(order_column:changed_on_delta_humanized,order_direction:desc,page:0,page_size:25,select_columns:!(id,dashboard_title,published,url,slug,changed_by,changed_by.id,changed_by.first_name,changed_by.last_name,changed_on_delta_humanized,owners,owners.id,owners.first_name,owners.last_name,tags.id,tags.name,tags.type,status,certified_by,certification_details,changed_on))", "rison": {"order_column": "changed_on_delta_humanized", "order_direction": "desc", "page": 0, "page_size": 25, "select_columns": ["id", "dashboard_title", "published", "url", "slug", "changed_by", "changed_by.id", "changed_by.first_name", "changed_by.last_name", "changed_on_delta_humanized", "owners", "owners.id", "owners.first_name", "owners.last_name", "tags.id", "tags.name", "tags.type", "status", "certified_by", "certification_details", "changed_on"]}}	2026-06-28 12:49:40.893162	\N	\N	24	http://localhost:8088/dashboard/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc&viewMode=table
150	log	1	{"impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782650980741, "event_name": "spa_navigation", "path": "/dashboard/list/", "event_type": "user", "event_id": "4SvAa7WLUy1Y1e1q4OtNg", "visibility": "visible"}	2026-06-28 12:49:42.674468	\N	\N	0	http://localhost:8088/tablemodelview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
151	log	1	{"impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782650981656, "event_name": "spa_navigation", "path": "/tablemodelview/list/", "event_type": "user", "event_id": "370HLAC4JJNd-Jte9hJkH", "visibility": "visible"}	2026-06-28 12:49:42.674471	\N	\N	0	http://localhost:8088/tablemodelview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
155	DatasetRestApi.get_list	1	{"path": "/api/v1/dataset/", "q": "(filters:!((col:database,opr:rel_o_m,value:1),(col:schema,opr:eq,value:public),(col:sql,opr:dataset_is_null_or_empty,value:!t)),page:0)", "rison": {"filters": [{"col": "database", "opr": "rel_o_m", "value": 1}, {"col": "schema", "opr": "eq", "value": "public"}, {"col": "sql", "opr": "dataset_is_null_or_empty", "value": true}], "page": 0}}	2026-06-28 12:49:50.99662	\N	\N	51	http://localhost:8088/dataset/add/
159	DatasetRestApi.post	1	{"path": "/api/v1/dataset/", "database": 1, "catalog": null, "schema": "public", "table_name": "ventas", "object_ref": "DatasetRestApi.post"}	2026-06-28 12:50:22.610849	\N	\N	173	http://localhost:8088/dataset/add/
164	log	1	{"impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651048784, "event_name": "spa_navigation", "path": "/explore/", "event_type": "user", "event_id": "lPRw64CzBKxcung51YHJf", "visibility": "visible"}	2026-06-28 12:50:50.323756	\N	\N	0	http://localhost:8088/explore/?viz_type=echarts_timeseries_bar&datasource=1__table
165	log	1	{"impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651049306, "event_name": "mount_explorer", "event_type": "user", "event_id": "5_QPrILz0c84JJ29GLTF2", "visibility": "visible"}	2026-06-28 12:50:50.323759	\N	\N	0	http://localhost:8088/explore/?viz_type=echarts_timeseries_bar&datasource=1__table
168	log	1	{"impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651076126, "event_name": "change_explore_controls", "event_type": "user", "event_id": "eNkGaQyUNVcsAo554fgZc", "visibility": "visible"}	2026-06-28 12:51:17.138017	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&viz_type=echarts_timeseries_bar&datasource=1__table&datasource_id=1&datasource_type=table
173	_get_data_response	1	\N	2026-06-28 12:51:21.445432	\N	\N	101	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&viz_type=echarts_timeseries_bar&datasource=1__table&datasource_id=1&datasource_type=table
178	ChartDataRestApi.json_dumps	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": [{"timeGrain": "P1D", "columnType": "BASE_AXIS", "sqlExpression": "categoria", "label": "categoria", "expressionType": "SQL", "isColumnReference": true}], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 1000, "series_columns": [], "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "viz_type": "echarts_timeseries_bar"}, "custom_params": {}, "custom_form_data": {}, "time_offsets": [], "post_processing": [{"operation": "pivot", "options": {"index": ["categoria"], "columns": [], "aggregates": {"count": {"operator": "mean"}}, "drop_missing_columns": false}}, {"operation": "flatten"}]}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": [{"timeGrain": "P1D", "columnType": "BASE_AXIS", "sqlExpression": "categoria", "label": "categoria", "expressionType": "SQL", "isColumnReference": true}], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 1000, "series_columns": [], "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "viz_type": "echarts_timeseries_bar"}, "custom_params": {}, "custom_form_data": {}, "time_offsets": [], "post_processing": [{"operation": "pivot", "options": {"index": ["categoria"], "columns": [], "aggregates": {"count": {"operator": "mean"}}, "drop_missing_columns": false}}, {"operation": "flatten"}]}, "result_format": "json", "result_type": "results"}	2026-06-28 12:51:21.569625	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&viz_type=echarts_timeseries_bar&datasource=1__table&datasource_id=1&datasource_type=table
182	log	1	{"impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651081459, "event_name": "load_chart", "slice_id": 0, "applied_filters": [{"column": "fecha"}], "is_cached": null, "force_refresh": false, "row_count": 3, "datasource": "1__table", "start_offset": 32492, "duration": 183, "viz_type": "echarts_timeseries_bar", "data_age": null, "event_type": "timing", "trigger_event": "eNkGaQyUNVcsAo554fgZc"}	2026-06-28 12:51:22.471402	\N	0	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&viz_type=echarts_timeseries_bar&datasource=1__table&datasource_id=1&datasource_type=table
186	DatabaseRestApi.schemas	1	{"path": "/api/v1/database/1/schemas/", "q": "(catalog:analytics,force:!f)", "url_rule": "/api/v1/database/<int:pk>/schemas/", "object_ref": "DatabaseRestApi.schemas", "pk": 1, "rison": {"catalog": "analytics", "force": false}}	2026-06-28 12:51:46.543543	\N	\N	86	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&viz_type=echarts_timeseries_bar&datasource=1__table&datasource_id=1&datasource_type=table
153	log	1	{"impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782650986344, "event_name": "spa_navigation", "path": "/dataset/add/", "event_type": "user", "event_id": "Zm4VL5V3faGr4_u9R-xNb", "visibility": "visible"}	2026-06-28 12:49:47.357732	\N	\N	0	http://localhost:8088/dataset/add/
158	DatabaseRestApi.table_metadata	1	{"path": "/api/v1/database/1/table_metadata/", "name": "ventas", "schema": "public", "url_rule": "/api/v1/database/<int:pk>/table_metadata/", "object_ref": "DatabaseRestApi.table_metadata", "pk": 1}	2026-06-28 12:49:55.937522	\N	\N	151	http://localhost:8088/dataset/add/
162	ExploreRestApi.get	1	{"path": "/api/v1/explore/", "viz_type": "echarts_timeseries_bar", "datasource_id": "1", "datasource_type": "table", "object_ref": "ExploreRestApi.get"}	2026-06-28 12:50:49.152509	\N	\N	16	http://localhost:8088/explore/?viz_type=echarts_timeseries_bar&datasource=1__table
166	ExploreFormDataRestApi.post	1	{"path": "/api/v1/explore/form_data", "tab_id": "3", "datasource_id": 1, "datasource_type": "table", "form_data": {}, "object_ref": "ExploreFormDataRestApi.post"}	2026-06-28 12:50:50.39651	\N	\N	18	http://localhost:8088/explore/?viz_type=echarts_timeseries_bar&datasource=1__table
171	QueryObject.post_processing	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": [{"timeGrain": "P1D", "columnType": "BASE_AXIS", "sqlExpression": "categoria", "label": "categoria", "expressionType": "SQL", "isColumnReference": true}], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 10000, "series_columns": [], "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "viz_type": "echarts_timeseries_bar"}, "custom_params": {}, "custom_form_data": {}, "time_offsets": [], "post_processing": [{"operation": "pivot", "options": {"index": ["categoria"], "columns": [], "aggregates": {"count": {"operator": "mean"}}, "drop_missing_columns": false}}, {"operation": "flatten"}]}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": [{"timeGrain": "P1D", "columnType": "BASE_AXIS", "sqlExpression": "categoria", "label": "categoria", "expressionType": "SQL", "isColumnReference": true}], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 10000, "series_columns": [], "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "viz_type": "echarts_timeseries_bar"}, "custom_params": {}, "custom_form_data": {}, "time_offsets": [], "post_processing": [{"operation": "pivot", "options": {"index": ["categoria"], "columns": [], "aggregates": {"count": {"operator": "mean"}}, "drop_missing_columns": false}}, {"operation": "flatten"}]}, "result_format": "json", "result_type": "full"}	2026-06-28 12:51:21.425884	\N	\N	8	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&viz_type=echarts_timeseries_bar&datasource=1__table&datasource_id=1&datasource_type=table
176	load_into_dataframe	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": [{"timeGrain": "P1D", "columnType": "BASE_AXIS", "sqlExpression": "categoria", "label": "categoria", "expressionType": "SQL", "isColumnReference": true}], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 1000, "series_columns": [], "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "viz_type": "echarts_timeseries_bar"}, "custom_params": {}, "custom_form_data": {}, "time_offsets": [], "post_processing": [{"operation": "pivot", "options": {"index": ["categoria"], "columns": [], "aggregates": {"count": {"operator": "mean"}}, "drop_missing_columns": false}}, {"operation": "flatten"}]}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": [{"timeGrain": "P1D", "columnType": "BASE_AXIS", "sqlExpression": "categoria", "label": "categoria", "expressionType": "SQL", "isColumnReference": true}], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 1000, "series_columns": [], "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "viz_type": "echarts_timeseries_bar"}, "custom_params": {}, "custom_form_data": {}, "time_offsets": [], "post_processing": [{"operation": "pivot", "options": {"index": ["categoria"], "columns": [], "aggregates": {"count": {"operator": "mean"}}, "drop_missing_columns": false}}, {"operation": "flatten"}]}, "result_format": "json", "result_type": "results", "object_ref": "Database.load_into_dataframe"}	2026-06-28 12:51:21.545878	\N	\N	1	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&viz_type=echarts_timeseries_bar&datasource=1__table&datasource_id=1&datasource_type=table
185	ChartRestApi.get_list	1	{"path": "/api/v1/chart/", "q": "(columns:!(slice_name,url,certified_by,certification_details,description,owners.first_name,owners.last_name,owners.id,changed_on_delta_humanized,changed_on,changed_by.first_name,changed_by.last_name,changed_by.id,dashboards.id,dashboards.dashboard_title,dashboards.url),filters:!((col:datasource_id,opr:eq,value:1)),order_column:changed_on_delta_humanized,order_direction:desc,page:0,page_size:25)", "rison": {"columns": ["slice_name", "url", "certified_by", "certification_details", "description", "owners.first_name", "owners.last_name", "owners.id", "changed_on_delta_humanized", "changed_on", "changed_by.first_name", "changed_by.last_name", "changed_by.id", "dashboards.id", "dashboards.dashboard_title", "dashboards.url"], "filters": [{"col": "datasource_id", "opr": "eq", "value": 1}], "order_column": "changed_on_delta_humanized", "order_direction": "desc", "page": 0, "page_size": 25}}	2026-06-28 12:51:46.533289	\N	\N	91	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&viz_type=echarts_timeseries_bar&datasource=1__table&datasource_id=1&datasource_type=table
160	DatasetRestApi.get_list	1	{"path": "/api/v1/dataset/", "q": "(columns:!(id,table_name,datasource_type,database.database_name,schema),filters:!((col:table_name,opr:eq,value:ventas)),order_column:table_name,order_direction:asc,page:0,page_size:1)", "rison": {"columns": ["id", "table_name", "datasource_type", "database.database_name", "schema"], "filters": [{"col": "table_name", "opr": "eq", "value": "ventas"}], "order_column": "table_name", "order_direction": "asc", "page": 0, "page_size": 1}}	2026-06-28 12:50:22.738117	\N	\N	47	http://localhost:8088/chart/add/?dataset=ventas
169	execute_sql	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": [{"timeGrain": "P1D", "columnType": "BASE_AXIS", "sqlExpression": "categoria", "label": "categoria", "expressionType": "SQL", "isColumnReference": true}], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 10000, "series_columns": [], "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "viz_type": "echarts_timeseries_bar"}, "custom_params": {}, "custom_form_data": {}, "time_offsets": [], "post_processing": [{"operation": "pivot", "options": {"index": ["categoria"], "columns": [], "aggregates": {"count": {"operator": "mean"}}, "drop_missing_columns": false}}, {"operation": "flatten"}]}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": [{"timeGrain": "P1D", "columnType": "BASE_AXIS", "sqlExpression": "categoria", "label": "categoria", "expressionType": "SQL", "isColumnReference": true}], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 10000, "series_columns": [], "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "viz_type": "echarts_timeseries_bar"}, "custom_params": {}, "custom_form_data": {}, "time_offsets": [], "post_processing": [{"operation": "pivot", "options": {"index": ["categoria"], "columns": [], "aggregates": {"count": {"operator": "mean"}}, "drop_missing_columns": false}}, {"operation": "flatten"}]}, "result_format": "json", "result_type": "full", "object_ref": "superset.models.core"}	2026-06-28 12:51:21.371698	\N	\N	1	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&viz_type=echarts_timeseries_bar&datasource=1__table&datasource_id=1&datasource_type=table
174	ChartDataRestApi.data	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": [{"timeGrain": "P1D", "columnType": "BASE_AXIS", "sqlExpression": "categoria", "label": "categoria", "expressionType": "SQL", "isColumnReference": true}], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 10000, "series_columns": [], "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "viz_type": "echarts_timeseries_bar"}, "custom_params": {}, "custom_form_data": {}, "time_offsets": [], "post_processing": [{"operation": "pivot", "options": {"index": ["categoria"], "columns": [], "aggregates": {"count": {"operator": "mean"}}, "drop_missing_columns": false}}, {"operation": "flatten"}]}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": [{"timeGrain": "P1D", "columnType": "BASE_AXIS", "sqlExpression": "categoria", "label": "categoria", "expressionType": "SQL", "isColumnReference": true}], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 10000, "series_columns": [], "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "viz_type": "echarts_timeseries_bar"}, "custom_params": {}, "custom_form_data": {}, "time_offsets": [], "post_processing": [{"operation": "pivot", "options": {"index": ["categoria"], "columns": [], "aggregates": {"count": {"operator": "mean"}}, "drop_missing_columns": false}}, {"operation": "flatten"}]}, "result_format": "json", "result_type": "full", "object_ref": "ChartDataRestApi.data", "is_cached": [null]}	2026-06-28 12:51:21.450409	\N	\N	127	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&viz_type=echarts_timeseries_bar&datasource=1__table&datasource_id=1&datasource_type=table
179	_get_data_response	1	\N	2026-06-28 12:51:21.575911	\N	\N	58	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&viz_type=echarts_timeseries_bar&datasource=1__table&datasource_id=1&datasource_type=table
187	DatabaseRestApi.tables	1	{"path": "/api/v1/database/1/tables/", "q": "(catalog_name:analytics,force:!f,schema_name:public)", "url_rule": "/api/v1/database/<int:pk>/tables/", "object_ref": "DatabaseRestApi.tables", "pk": 1, "rison": {"catalog_name": "analytics", "force": false, "schema_name": "public"}}	2026-06-28 12:51:46.827459	\N	\N	76	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&viz_type=echarts_timeseries_bar&datasource=1__table&datasource_id=1&datasource_type=table
188	execute_sql	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": [{"timeGrain": "P1D", "columnType": "BASE_AXIS", "sqlExpression": "categoria", "label": "categoria", "expressionType": "SQL", "isColumnReference": true}], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 10000, "series_columns": [], "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "viz_type": "echarts_timeseries_bar"}, "custom_params": {}, "custom_form_data": {}, "time_offsets": [], "post_processing": [{"operation": "pivot", "options": {"index": ["categoria"], "columns": [], "aggregates": {"count": {"operator": "mean"}}, "drop_missing_columns": false}}, {"operation": "flatten"}]}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": [{"timeGrain": "P1D", "columnType": "BASE_AXIS", "sqlExpression": "categoria", "label": "categoria", "expressionType": "SQL", "isColumnReference": true}], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 10000, "series_columns": [], "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "viz_type": "echarts_timeseries_bar"}, "custom_params": {}, "custom_form_data": {}, "time_offsets": [], "post_processing": [{"operation": "pivot", "options": {"index": ["categoria"], "columns": [], "aggregates": {"count": {"operator": "mean"}}, "drop_missing_columns": false}}, {"operation": "flatten"}]}, "result_format": "json", "result_type": "full", "object_ref": "superset.models.core"}	2026-06-28 12:54:02.927958	\N	\N	1	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&viz_type=echarts_timeseries_bar&datasource=1__table&datasource_id=1&datasource_type=table
189	load_into_dataframe	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": [{"timeGrain": "P1D", "columnType": "BASE_AXIS", "sqlExpression": "categoria", "label": "categoria", "expressionType": "SQL", "isColumnReference": true}], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 10000, "series_columns": [], "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "viz_type": "echarts_timeseries_bar"}, "custom_params": {}, "custom_form_data": {}, "time_offsets": [], "post_processing": [{"operation": "pivot", "options": {"index": ["categoria"], "columns": [], "aggregates": {"count": {"operator": "mean"}}, "drop_missing_columns": false}}, {"operation": "flatten"}]}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": [{"timeGrain": "P1D", "columnType": "BASE_AXIS", "sqlExpression": "categoria", "label": "categoria", "expressionType": "SQL", "isColumnReference": true}], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 10000, "series_columns": [], "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "viz_type": "echarts_timeseries_bar"}, "custom_params": {}, "custom_form_data": {}, "time_offsets": [], "post_processing": [{"operation": "pivot", "options": {"index": ["categoria"], "columns": [], "aggregates": {"count": {"operator": "mean"}}, "drop_missing_columns": false}}, {"operation": "flatten"}]}, "result_format": "json", "result_type": "full", "object_ref": "Database.load_into_dataframe"}	2026-06-28 12:54:02.940021	\N	\N	1	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&viz_type=echarts_timeseries_bar&datasource=1__table&datasource_id=1&datasource_type=table
190	QueryObject.post_processing	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": [{"timeGrain": "P1D", "columnType": "BASE_AXIS", "sqlExpression": "categoria", "label": "categoria", "expressionType": "SQL", "isColumnReference": true}], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 10000, "series_columns": [], "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "viz_type": "echarts_timeseries_bar"}, "custom_params": {}, "custom_form_data": {}, "time_offsets": [], "post_processing": [{"operation": "pivot", "options": {"index": ["categoria"], "columns": [], "aggregates": {"count": {"operator": "mean"}}, "drop_missing_columns": false}}, {"operation": "flatten"}]}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": [{"timeGrain": "P1D", "columnType": "BASE_AXIS", "sqlExpression": "categoria", "label": "categoria", "expressionType": "SQL", "isColumnReference": true}], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 10000, "series_columns": [], "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "viz_type": "echarts_timeseries_bar"}, "custom_params": {}, "custom_form_data": {}, "time_offsets": [], "post_processing": [{"operation": "pivot", "options": {"index": ["categoria"], "columns": [], "aggregates": {"count": {"operator": "mean"}}, "drop_missing_columns": false}}, {"operation": "flatten"}]}, "result_format": "json", "result_type": "full"}	2026-06-28 12:54:02.953648	\N	\N	2	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&viz_type=echarts_timeseries_bar&datasource=1__table&datasource_id=1&datasource_type=table
191	ChartDataRestApi.json_dumps	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": [{"timeGrain": "P1D", "columnType": "BASE_AXIS", "sqlExpression": "categoria", "label": "categoria", "expressionType": "SQL", "isColumnReference": true}], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 10000, "series_columns": [], "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "viz_type": "echarts_timeseries_bar"}, "custom_params": {}, "custom_form_data": {}, "time_offsets": [], "post_processing": [{"operation": "pivot", "options": {"index": ["categoria"], "columns": [], "aggregates": {"count": {"operator": "mean"}}, "drop_missing_columns": false}}, {"operation": "flatten"}]}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": [{"timeGrain": "P1D", "columnType": "BASE_AXIS", "sqlExpression": "categoria", "label": "categoria", "expressionType": "SQL", "isColumnReference": true}], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 10000, "series_columns": [], "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "viz_type": "echarts_timeseries_bar"}, "custom_params": {}, "custom_form_data": {}, "time_offsets": [], "post_processing": [{"operation": "pivot", "options": {"index": ["categoria"], "columns": [], "aggregates": {"count": {"operator": "mean"}}, "drop_missing_columns": false}}, {"operation": "flatten"}]}, "result_format": "json", "result_type": "full"}	2026-06-28 12:54:02.965978	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&viz_type=echarts_timeseries_bar&datasource=1__table&datasource_id=1&datasource_type=table
192	_get_data_response	1	\N	2026-06-28 12:54:02.973197	\N	\N	67	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&viz_type=echarts_timeseries_bar&datasource=1__table&datasource_id=1&datasource_type=table
194	ExploreFormDataRestApi.put	1	{"path": "/api/v1/explore/form_data/qmxrMRhqerk", "tab_id": "3", "datasource_id": 1, "datasource_type": "table", "form_data": {}, "url_rule": "/api/v1/explore/form_data/<string:key>", "object_ref": "ExploreFormDataRestApi.put", "key": "qmxrMRhqerk"}	2026-06-28 12:54:03.812325	\N	\N	12	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&viz_type=echarts_timeseries_bar&datasource=1__table&datasource_id=1&datasource_type=table
193	ChartDataRestApi.data	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": [{"timeGrain": "P1D", "columnType": "BASE_AXIS", "sqlExpression": "categoria", "label": "categoria", "expressionType": "SQL", "isColumnReference": true}], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 10000, "series_columns": [], "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "viz_type": "echarts_timeseries_bar"}, "custom_params": {}, "custom_form_data": {}, "time_offsets": [], "post_processing": [{"operation": "pivot", "options": {"index": ["categoria"], "columns": [], "aggregates": {"count": {"operator": "mean"}}, "drop_missing_columns": false}}, {"operation": "flatten"}]}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": [{"timeGrain": "P1D", "columnType": "BASE_AXIS", "sqlExpression": "categoria", "label": "categoria", "expressionType": "SQL", "isColumnReference": true}], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 10000, "series_columns": [], "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "viz_type": "echarts_timeseries_bar"}, "custom_params": {}, "custom_form_data": {}, "time_offsets": [], "post_processing": [{"operation": "pivot", "options": {"index": ["categoria"], "columns": [], "aggregates": {"count": {"operator": "mean"}}, "drop_missing_columns": false}}, {"operation": "flatten"}]}, "result_format": "json", "result_type": "full", "object_ref": "ChartDataRestApi.data", "is_cached": [null]}	2026-06-28 12:54:02.978484	\N	\N	86	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&viz_type=echarts_timeseries_bar&datasource=1__table&datasource_id=1&datasource_type=table
197	DatasetRestApi.get	1	{"path": "/api/v1/dataset/1", "q": "(columns:!(name,schema,database.id,select_star),keys:!(none))", "url_rule": "/api/v1/dataset/<id_or_uuid>", "object_ref": "DatasetRestApi.get", "id_or_uuid": "1", "rison": {"columns": ["name", "schema", "database.id", "select_star"], "keys": ["none"]}}	2026-06-28 12:54:13.349936	\N	\N	10	http://localhost:8088/sqllab
207	ChartRestApi.get_list	1	{"path": "/api/v1/chart/", "q": "(order_column:changed_on_delta_humanized,order_direction:desc,page:0,page_size:25)", "rison": {"order_column": "changed_on_delta_humanized", "order_direction": "desc", "page": 0, "page_size": 25}}	2026-06-28 12:54:18.416897	\N	\N	70	http://localhost:8088/chart/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc&viewMode=table
212	ExploreRestApi.get	1	{"path": "/api/v1/explore/", "datasource_type": "table", "datasource_id": "1", "object_ref": "ExploreRestApi.get"}	2026-06-28 12:54:22.154509	\N	\N	16	http://localhost:8088/explore/?datasource_type=table&datasource_id=1
216	ExploreFormDataRestApi.post	1	{"path": "/api/v1/explore/form_data", "tab_id": "3", "datasource_id": 1, "datasource_type": "table", "form_data": {}, "object_ref": "ExploreFormDataRestApi.post"}	2026-06-28 12:54:23.370658	\N	\N	16	http://localhost:8088/explore/?datasource_type=table&datasource_id=1
220	ExploreFormDataRestApi.put	1	{"path": "/api/v1/explore/form_data/qmxrMRhqerk", "tab_id": "3", "datasource_id": 1, "datasource_type": "table", "form_data": {}, "url_rule": "/api/v1/explore/form_data/<string:key>", "object_ref": "ExploreFormDataRestApi.put", "key": "qmxrMRhqerk"}	2026-06-28 12:54:31.398605	\N	\N	35	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
225	QueryObject.post_processing	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "full"}	2026-06-28 12:54:55.680188	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
230	load_into_dataframe	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "results", "object_ref": "Database.load_into_dataframe"}	2026-06-28 12:54:55.797553	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
237	execute_sql	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "results", "object_ref": "superset.models.core"}	2026-06-28 12:54:55.929393	\N	\N	2	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
256	DatabaseRestApi.get_list	1	{"path": "/api/v1/database/", "q": "(filters:!((col:database_name,opr:ct,value:'')),order_column:database_name,order_direction:asc,page:0,page_size:100)", "rison": {"filters": [{"col": "database_name", "opr": "ct", "value": ""}], "order_column": "database_name", "order_direction": "asc", "page": 0, "page_size": 100}}	2026-06-28 12:55:03.233698	\N	\N	56	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
310	log	1	{"impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651437452, "event_name": "change_explore_controls", "event_type": "user", "event_id": "KXD_MyXojMIls3mtLqE5r", "visibility": "visible"}	2026-06-28 12:57:18.468299	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
195	log	1	{"impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651242987, "event_name": "load_chart", "slice_id": 0, "applied_filters": [{"column": "fecha"}], "is_cached": null, "force_refresh": false, "row_count": 3, "datasource": "1__table", "start_offset": 194039, "duration": 164, "viz_type": "echarts_timeseries_bar", "data_age": null, "event_type": "timing", "trigger_event": "eNkGaQyUNVcsAo554fgZc"}	2026-06-28 12:54:04.000849	\N	0	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&viz_type=echarts_timeseries_bar&datasource=1__table&datasource_id=1&datasource_type=table
202	SqlLabRestApi.get_results	1	{"path": "/api/v1/sqllab/execute/", "client_id": "5isLAsg48yA", "database_id": 1, "runAsync": false, "schema": "public", "sql": "SELECT\\n  *\\nFROM public.ventas\\nLIMIT 100", "sql_editor_id": "HSbLp_Hb1ic", "tab": "Query public.ventas", "tmp_table_name": "", "select_as_cta": false, "ctas_method": "TABLE", "queryLimit": 1000, "expand_data": true, "object_ref": "SqlLabRestApi.execute_sql_query"}	2026-06-28 12:54:13.698674	\N	\N	142	http://localhost:8088/sqllab
209	DatasetRestApi.get_list	1	{"path": "/api/v1/dataset/", "q": "(order_column:changed_on_delta_humanized,order_direction:desc,page:0,page_size:25)", "rison": {"order_column": "changed_on_delta_humanized", "order_direction": "desc", "page": 0, "page_size": 25}}	2026-06-28 12:54:19.430642	\N	\N	25	http://localhost:8088/tablemodelview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
214	log	1	{"impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651262111, "event_name": "spa_navigation", "path": "/explore/", "event_type": "user", "event_id": "XeZDu2X1_fBMprJgjZn_J", "visibility": "visible"}	2026-06-28 12:54:23.29484	\N	\N	0	http://localhost:8088/explore/?datasource_type=table&datasource_id=1
215	log	1	{"impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651262281, "event_name": "mount_explorer", "event_type": "user", "event_id": "EGnOjCx_I1RzPNzsEXXDB", "visibility": "visible"}	2026-06-28 12:54:23.294845	\N	\N	0	http://localhost:8088/explore/?datasource_type=table&datasource_id=1
222	log	1	{"impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651291376, "event_name": "change_explore_controls", "event_type": "user", "event_id": "4S2ew_jTpEKRrzcVw1_nk", "visibility": "visible"}	2026-06-28 12:54:52.390334	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
227	_get_data_response	1	\N	2026-06-28 12:54:55.699426	\N	\N	60	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
232	ChartDataRestApi.json_dumps	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "results"}	2026-06-28 12:54:55.817253	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
236	execute_sql	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "results", "object_ref": "superset.models.core"}	2026-06-28 12:54:55.928564	\N	\N	2	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
241	QueryObject.post_processing	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "full"}	2026-06-28 12:54:55.953231	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
269	log	1	{"impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651377378, "event_name": "change_explore_controls", "event_type": "user", "event_id": "YiZESdJNcAJWc3TlHERoq", "visibility": "visible"}	2026-06-28 12:56:18.39544	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
390	log	1	{"source": "explore", "source_id": 1, "slice_id": 1, "impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651586055, "event_name": "sqllab_run_query", "payload": {"queryEditorId": "e1ruoVCft_R", "shortcut": false}, "event_type": "user", "event_id": "EWyhSUXxhs5SEhT1Z1wSt", "visibility": "visible"}	2026-06-28 12:59:47.066291	\N	1	0	http://localhost:8088/sqllab
199	DatabaseRestApi.validate_sql	1	{"path": "/api/v1/database/1/validate_sql/", "schema": "public", "sql": "SELECT\\n  *\\nFROM public.ventas\\nLIMIT 100", "url_rule": "/api/v1/database/<int:pk>/validate_sql/", "object_ref": "DatabaseRestApi.validate_sql", "pk": 1}	2026-06-28 12:54:13.581435	\N	\N	31	http://localhost:8088/sqllab
203	log	1	{"impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651253168, "event_name": "spa_navigation", "path": "/sqllab", "event_type": "user", "event_id": "bCaMFoUP4BmEBHvN8A8B6", "visibility": "visible"}	2026-06-28 12:54:14.454568	\N	\N	0	http://localhost:8088/sqllab
204	log	1	{"impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651253358, "event_name": "sqllab_monitor_local_storage_usage", "current_usage": 0.67, "query_count": 0, "event_type": "user", "event_id": "kkZx_SmTMBKiFK1nL_pa5", "visibility": "visible"}	2026-06-28 12:54:14.454572	\N	\N	0	http://localhost:8088/sqllab
205	log	1	{"impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651253436, "event_name": "sqllab_load_tab_state", "payload": {"queryEditorId": "HSbLp_Hb1ic", "duration": 268, "inLocalStorage": true, "hasLoaded": true}, "event_type": "timing", "trigger_event": "kkZx_SmTMBKiFK1nL_pa5"}	2026-06-28 12:54:14.454573	\N	\N	0	http://localhost:8088/sqllab
210	DatasetRestApi.info	1	{"path": "/api/v1/dataset/_info", "q": "(keys:!(permissions))", "rison": {"keys": ["permissions"]}}	2026-06-28 12:54:19.436211	\N	\N	35	http://localhost:8088/tablemodelview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
219	ExploreFormDataRestApi.put	1	{"path": "/api/v1/explore/form_data/qmxrMRhqerk", "tab_id": "3", "datasource_id": 1, "datasource_type": "table", "form_data": {}, "url_rule": "/api/v1/explore/form_data/<string:key>", "object_ref": "ExploreFormDataRestApi.put", "key": "qmxrMRhqerk"}	2026-06-28 12:54:28.867017	\N	\N	14	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
223	execute_sql	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "full", "object_ref": "superset.models.core"}	2026-06-28 12:54:55.660865	\N	\N	1	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
228	ChartDataRestApi.data	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "full", "object_ref": "ChartDataRestApi.data", "is_cached": [null]}	2026-06-28 12:54:55.703828	\N	\N	78	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
233	_get_data_response	1	\N	2026-06-28 12:54:55.82299	\N	\N	54	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
238	load_into_dataframe	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "full", "object_ref": "Database.load_into_dataframe"}	2026-06-28 12:54:55.937616	\N	\N	3	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
243	QueryObject.post_processing	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "results"}	2026-06-28 12:54:55.963038	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
200	DatabaseRestApi.schemas	1	{"path": "/api/v1/database/1/schemas/", "q": "(force:!f)", "url_rule": "/api/v1/database/<int:pk>/schemas/", "object_ref": "DatabaseRestApi.schemas", "pk": 1, "rison": {"force": false}}	2026-06-28 12:54:13.60052	\N	\N	53	http://localhost:8088/sqllab
201	execute_sql	1	{"path": "/", "object_ref": "superset.sql_lab"}	2026-06-28 12:54:13.670058	\N	\N	5	\N
206	ChartRestApi.info	1	{"path": "/api/v1/chart/_info", "q": "(keys:!(permissions))", "rison": {"keys": ["permissions"]}}	2026-06-28 12:54:18.368351	\N	\N	34	http://localhost:8088/chart/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc&viewMode=table
211	log	1	{"impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651259343, "event_name": "spa_navigation", "path": "/tablemodelview/list/", "event_type": "user", "event_id": "AgRORBg1R7mskhG-pJ5eQ", "visibility": "visible"}	2026-06-28 12:54:20.359082	\N	\N	0	http://localhost:8088/tablemodelview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
224	load_into_dataframe	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "full", "object_ref": "Database.load_into_dataframe"}	2026-06-28 12:54:55.670508	\N	\N	1	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
229	execute_sql	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "results", "object_ref": "superset.models.core"}	2026-06-28 12:54:55.788384	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
234	ChartDataRestApi.data	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "results", "object_ref": "ChartDataRestApi.data", "is_cached": [null]}	2026-06-28 12:54:55.827618	\N	\N	70	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
239	load_into_dataframe	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "results", "object_ref": "Database.load_into_dataframe"}	2026-06-28 12:54:55.943905	\N	\N	1	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
270	log	1	{"impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651381321, "event_name": "change_explore_controls", "event_type": "user", "event_id": "jG7yCgh7mKz55_t1GHzg3", "visibility": "visible"}	2026-06-28 12:56:22.337258	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
327	DashboardRestApi.get_list	1	{"path": "/api/v1/dashboard/", "q": "(columns:!(id,dashboard_title),filters:!((col:dashboard_title,opr:ct,value:''),(col:owners,opr:rel_m_m,value:1)),order_column:dashboard_title,page:0,page_size:100)", "rison": {"columns": ["id", "dashboard_title"], "filters": [{"col": "dashboard_title", "opr": "ct", "value": ""}, {"col": "owners", "opr": "rel_m_m", "value": 1}], "order_column": "dashboard_title", "page": 0, "page_size": 100}}	2026-06-28 12:59:25.200537	\N	\N	39	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
208	log	1	{"impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651258223, "event_name": "spa_navigation", "path": "/chart/list/", "event_type": "user", "event_id": "0EeuMJiCe2PyB9anK9zqT", "visibility": "visible"}	2026-06-28 12:54:19.241723	\N	\N	0	http://localhost:8088/chart/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc&viewMode=table
213	DatabaseRestApi.table_extra_metadata	1	{"path": "/api/v1/database/1/table_metadata/extra/", "name": "ventas", "catalog": "analytics", "schema": "public", "url_rule": "/api/v1/database/<int:pk>/table_metadata/extra/", "object_ref": "DatabaseRestApi.table_extra_metadata", "pk": 1}	2026-06-28 12:54:22.385389	\N	\N	7	http://localhost:8088/explore/?datasource_type=table&datasource_id=1
217	log	1	{"impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651265028, "event_name": "change_explore_controls", "event_type": "user", "event_id": "qMvi3ajn4jRe6PapoOywU", "visibility": "visible"}	2026-06-28 12:54:26.07552	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
218	log	1	{"impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651265061, "event_name": "change_explore_controls", "event_type": "user", "event_id": "nNoxlfGHEQNY7XoeH1A1c", "visibility": "visible"}	2026-06-28 12:54:26.075523	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
221	log	1	{"impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651282440, "event_name": "change_explore_controls", "event_type": "user", "event_id": "p-0fo_ZRqCo9pvJhpRKV-", "visibility": "visible"}	2026-06-28 12:54:43.456061	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
226	ChartDataRestApi.json_dumps	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "full"}	2026-06-28 12:54:55.693729	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
231	QueryObject.post_processing	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "results"}	2026-06-28 12:54:55.806524	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
235	execute_sql	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "full", "object_ref": "superset.models.core"}	2026-06-28 12:54:55.923818	\N	\N	1	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
240	load_into_dataframe	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "results", "object_ref": "Database.load_into_dataframe"}	2026-06-28 12:54:55.945556	\N	\N	3	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
306	log	1	{"impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651434475, "event_name": "change_explore_controls", "event_type": "user", "event_id": "K98ga9swiI6AzYNZ4loiP", "visibility": "visible"}	2026-06-28 12:57:15.492995	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
242	QueryObject.post_processing	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "results"}	2026-06-28 12:54:55.961598	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
247	_get_data_response	1	\N	2026-06-28 12:54:55.987848	\N	\N	97	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
251	ChartDataRestApi.data	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "results", "object_ref": "ChartDataRestApi.data", "is_cached": [null]}	2026-06-28 12:54:56.001062	\N	\N	133	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
257	ChartRestApi.get_list	1	{"path": "/api/v1/chart/", "q": "(columns:!(slice_name,url,certified_by,certification_details,description,owners.first_name,owners.last_name,owners.id,changed_on_delta_humanized,changed_on,changed_by.first_name,changed_by.last_name,changed_by.id,dashboards.id,dashboards.dashboard_title,dashboards.url),filters:!((col:datasource_id,opr:eq,value:1)),order_column:changed_on_delta_humanized,order_direction:desc,page:0,page_size:25)", "rison": {"columns": ["slice_name", "url", "certified_by", "certification_details", "description", "owners.first_name", "owners.last_name", "owners.id", "changed_on_delta_humanized", "changed_on", "changed_by.first_name", "changed_by.last_name", "changed_by.id", "dashboards.id", "dashboards.dashboard_title", "dashboards.url"], "filters": [{"col": "datasource_id", "opr": "eq", "value": 1}], "order_column": "changed_on_delta_humanized", "order_direction": "desc", "page": 0, "page_size": 25}}	2026-06-28 12:55:03.235746	\N	\N	64	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
260	DatasetRestApi.put	1	{"path": "/api/v1/dataset/1", "override_columns": "true", "table_name": "ventas", "database_id": 1, "sql": "", "filter_select_enabled": true, "fetch_values_predicate": null, "schema": "public", "description": null, "main_dttm_col": "fecha", "currency_code_column": null, "normalize_columns": false, "always_filter_main_dttm": false, "offset": 0, "default_endpoint": null, "cache_timeout": null, "is_sqllab_view": false, "template_params": null, "extra": null, "metrics": [{"expression": "", "metric_name": "suma", "d3format": null, "verbose_name": "SUM(precio * cantidad)", "extra": "{}"}], "columns": [{"id": 1, "column_name": "id", "type": "INTEGER", "advanced_data_type": null, "verbose_name": null, "description": null, "expression": null, "filterable": true, "groupby": true, "is_dttm": false, "python_date_format": null, "uuid": "e27e19d6-27ea-4ed9-b4ad-c54271933f96", "extra": "{\\"warning_markdown\\":null}"}, {"id": 2, "column_name": "fecha", "type": "DATE", "advanced_data_type": null, "verbose_name": null, "description": null, "expression": null, "filterable": true, "groupby": true, "is_dttm": true, "python_date_format": null, "uuid": "792a11ad-38c2-4cc7-a339-0079ca65752d", "extra": "{\\"warning_markdown\\":null}"}, {"id": 3, "column_name": "producto", "type": "VARCHAR(100)", "advanced_data_type": null, "verbose_name": null, "description": null, "expression": null, "filterable": true, "groupby": true, "is_dttm": false, "python_date_format": null, "uuid": "bf113e0d-566d-4968-bd7c-3628c6abcad1", "extra": "{\\"warning_markdown\\":null}"}, {"id": 4, "column_name": "categoria", "type": "VARCHAR(50)", "advanced_data_type": null, "verbose_name": null, "description": null, "expression": null, "filterable": true, "groupby": true, "is_dttm": false, "python_date_format": null, "uuid": "7337d995-bf57-4c6c-9572-87876ef215c9", "extra": "{\\"warning_markdown\\":null}"}, {"id": 5, "column_name": "cantidad", "type": "INTEGER", "advanced_data_type": null, "verbose_name": null, "description": null, "expression": null, "filterable": true, "groupby": true, "is_dttm": false, "python_date_format": null, "uuid": "697eec5b-f3ae-4d47-a608-9e2386e896c6", "extra": "{\\"warning_markdown\\":null}"}, {"id": 6, "column_name": "precio", "type": "NUMERIC(10, 2)", "advanced_data_type": null, "verbose_name": null, "description": null, "expression": null, "filterable": true, "groupby": true, "is_dttm": false, "python_date_format": null, "uuid": "fa9730f9-cbc0-4fa5-9cc9-5450ce5d1e09", "extra": "{\\"warning_markdown\\":null}"}, {"id": 7, "column_name": "region", "type": "VARCHAR(50)", "advanced_data_type": null, "verbose_name": null, "description": null, "expression": null, "filterable": true, "groupby": true, "is_dttm": false, "python_date_format": null, "uuid": "74f52944-8b51-49b1-86f2-02ba5833b7dc", "extra": "{\\"warning_markdown\\":null}"}], "owners": [1], "url_rule": "/api/v1/dataset/<pk>", "object_ref": "DatasetRestApi.put", "pk": "1"}	2026-06-28 12:55:43.12912	\N	\N	149	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
244	ChartDataRestApi.json_dumps	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "full"}	2026-06-28 12:54:55.971236	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
249	ChartDataRestApi.data	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "full", "object_ref": "ChartDataRestApi.data", "is_cached": [null]}	2026-06-28 12:54:55.994637	\N	\N	129	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
254	log	1	{"impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651295711, "event_name": "load_chart", "slice_id": 0, "applied_filters": [{"column": "fecha"}], "is_cached": null, "force_refresh": false, "row_count": 6, "datasource": "1__table", "start_offset": 33472, "duration": 128, "viz_type": "table", "data_age": null, "event_type": "timing", "trigger_event": "4S2ew_jTpEKRrzcVw1_nk"}	2026-06-28 12:54:57.026371	\N	0	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
255	log	1	{"impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651296013, "event_name": "load_chart", "slice_id": 0, "applied_filters": [{"column": "fecha"}], "is_cached": null, "force_refresh": false, "row_count": 6, "datasource": "1__table", "start_offset": 33706, "duration": 195, "viz_type": "table", "data_age": null, "event_type": "timing", "trigger_event": "4S2ew_jTpEKRrzcVw1_nk"}	2026-06-28 12:54:57.026374	\N	0	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
245	ChartDataRestApi.json_dumps	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "results"}	2026-06-28 12:54:55.985274	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
250	_get_data_response	1	\N	2026-06-28 12:54:55.996297	\N	\N	105	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
253	ExploreFormDataRestApi.put	1	{"path": "/api/v1/explore/form_data/qmxrMRhqerk", "tab_id": "3", "datasource_id": 1, "datasource_type": "table", "form_data": {}, "url_rule": "/api/v1/explore/form_data/<string:key>", "object_ref": "ExploreFormDataRestApi.put", "key": "qmxrMRhqerk"}	2026-06-28 12:54:56.82833	\N	\N	13	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
259	DatabaseRestApi.tables	1	{"path": "/api/v1/database/1/tables/", "q": "(catalog_name:analytics,force:!f,schema_name:public)", "url_rule": "/api/v1/database/<int:pk>/tables/", "object_ref": "DatabaseRestApi.tables", "pk": 1, "rison": {"catalog_name": "analytics", "force": false, "schema_name": "public"}}	2026-06-28 12:55:03.444675	\N	\N	85	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
262	DatabaseRestApi.table_extra_metadata	1	{"path": "/api/v1/database/1/table_metadata/extra/", "name": "ventas", "catalog": "analytics", "schema": "public", "url_rule": "/api/v1/database/<int:pk>/table_metadata/extra/", "object_ref": "DatabaseRestApi.table_extra_metadata", "pk": 1}	2026-06-28 12:55:43.493328	\N	\N	13	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
246	ChartDataRestApi.json_dumps	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "results"}	2026-06-28 12:54:55.986956	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
252	ChartDataRestApi.data	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": ["count"], "orderby": [["count", false]], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "results", "object_ref": "ChartDataRestApi.data", "is_cached": [null]}	2026-06-28 12:54:56.00397	\N	\N	132	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
258	DatabaseRestApi.schemas	1	{"path": "/api/v1/database/1/schemas/", "q": "(catalog:analytics,force:!f)", "url_rule": "/api/v1/database/<int:pk>/schemas/", "object_ref": "DatabaseRestApi.schemas", "pk": 1, "rison": {"catalog": "analytics", "force": false}}	2026-06-28 12:55:03.251111	\N	\N	98	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
261	DatasetRestApi.get	1	{"path": "/api/v1/dataset/1", "url_rule": "/api/v1/dataset/<id_or_uuid>", "object_ref": "DatasetRestApi.get", "id_or_uuid": "1", "rison": {}}	2026-06-28 12:55:43.168292	\N	\N	15	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
263	DatabaseRestApi.get_list	1	{"path": "/api/v1/database/", "q": "(filters:!((col:database_name,opr:ct,value:'')),order_column:database_name,order_direction:asc,page:0,page_size:100)", "rison": {"filters": [{"col": "database_name", "opr": "ct", "value": ""}], "order_column": "database_name", "order_direction": "asc", "page": 0, "page_size": 100}}	2026-06-28 12:56:02.453645	\N	\N	49	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
264	ChartRestApi.get_list	1	{"path": "/api/v1/chart/", "q": "(columns:!(slice_name,url,certified_by,certification_details,description,owners.first_name,owners.last_name,owners.id,changed_on_delta_humanized,changed_on,changed_by.first_name,changed_by.last_name,changed_by.id,dashboards.id,dashboards.dashboard_title,dashboards.url),filters:!((col:datasource_id,opr:eq,value:1)),order_column:changed_on_delta_humanized,order_direction:desc,page:0,page_size:25)", "rison": {"columns": ["slice_name", "url", "certified_by", "certification_details", "description", "owners.first_name", "owners.last_name", "owners.id", "changed_on_delta_humanized", "changed_on", "changed_by.first_name", "changed_by.last_name", "changed_by.id", "dashboards.id", "dashboards.dashboard_title", "dashboards.url"], "filters": [{"col": "datasource_id", "opr": "eq", "value": 1}], "order_column": "changed_on_delta_humanized", "order_direction": "desc", "page": 0, "page_size": 25}}	2026-06-28 12:56:02.455191	\N	\N	54	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
265	DatasetRestApi.put	1	{"path": "/api/v1/dataset/1", "override_columns": "false", "table_name": "ventas", "database_id": 1, "sql": "", "filter_select_enabled": true, "fetch_values_predicate": null, "schema": "public", "description": null, "main_dttm_col": "fecha", "currency_code_column": null, "normalize_columns": false, "always_filter_main_dttm": false, "offset": 0, "default_endpoint": null, "cache_timeout": null, "is_sqllab_view": false, "template_params": null, "extra": null, "is_managed_externally": false, "metrics": [{"expression": "", "description": null, "metric_name": "suma", "metric_type": null, "d3format": null, "currency": null, "verbose_name": "SUM(precio * cantidad)", "warning_text": null, "uuid": "83da04da-f8b4-479c-bb0f-17e206e63ed9", "extra": "{\\"warning_markdown\\":\\"\\"}", "id": 2}], "columns": [{"id": 1, "column_name": "id", "type": "INTEGER", "advanced_data_type": null, "verbose_name": null, "description": null, "expression": "", "filterable": true, "groupby": true, "is_active": true, "is_dttm": false, "python_date_format": null, "uuid": "e27e19d6-27ea-4ed9-b4ad-c54271933f96", "extra": "{}"}, {"id": 2, "column_name": "fecha", "type": "DATE", "advanced_data_type": null, "verbose_name": null, "description": null, "expression": "", "filterable": true, "groupby": true, "is_active": true, "is_dttm": true, "python_date_format": null, "uuid": "792a11ad-38c2-4cc7-a339-0079ca65752d", "extra": "{}"}, {"id": 3, "column_name": "producto", "type": "VARCHAR(100)", "advanced_data_type": null, "verbose_name": null, "description": null, "expression": "", "filterable": true, "groupby": true, "is_active": true, "is_dttm": false, "python_date_format": null, "uuid": "bf113e0d-566d-4968-bd7c-3628c6abcad1", "extra": "{}"}, {"id": 4, "column_name": "categoria", "type": "VARCHAR(50)", "advanced_data_type": null, "verbose_name": null, "description": null, "expression": "", "filterable": true, "groupby": true, "is_active": true, "is_dttm": false, "python_date_format": null, "uuid": "7337d995-bf57-4c6c-9572-87876ef215c9", "extra": "{}"}, {"id": 5, "column_name": "cantidad", "type": "INTEGER", "advanced_data_type": null, "verbose_name": null, "description": null, "expression": "", "filterable": true, "groupby": true, "is_active": true, "is_dttm": false, "python_date_format": null, "uuid": "697eec5b-f3ae-4d47-a608-9e2386e896c6", "extra": "{}"}, {"id": 6, "column_name": "precio", "type": "NUMERIC(10, 2)", "advanced_data_type": null, "verbose_name": null, "description": null, "expression": "", "filterable": true, "groupby": true, "is_active": true, "is_dttm": false, "python_date_format": null, "uuid": "fa9730f9-cbc0-4fa5-9cc9-5450ce5d1e09", "extra": "{}"}, {"id": 7, "column_name": "region", "type": "VARCHAR(50)", "advanced_data_type": null, "verbose_name": null, "description": null, "expression": "", "filterable": true, "groupby": true, "is_active": true, "is_dttm": false, "python_date_format": null, "uuid": "74f52944-8b51-49b1-86f2-02ba5833b7dc", "extra": "{}"}], "owners": [1], "url_rule": "/api/v1/dataset/<pk>", "object_ref": "DatasetRestApi.put", "pk": "1"}	2026-06-28 12:56:17.102305	\N	\N	30	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
266	DatasetRestApi.get	1	{"path": "/api/v1/dataset/1", "url_rule": "/api/v1/dataset/<id_or_uuid>", "object_ref": "DatasetRestApi.get", "id_or_uuid": "1", "rison": {}}	2026-06-28 12:56:17.138898	\N	\N	14	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
267	DatabaseRestApi.table_extra_metadata	1	{"path": "/api/v1/database/1/table_metadata/extra/", "name": "ventas", "catalog": "analytics", "schema": "public", "url_rule": "/api/v1/database/<int:pk>/table_metadata/extra/", "object_ref": "DatabaseRestApi.table_extra_metadata", "pk": 1}	2026-06-28 12:56:17.435335	\N	\N	13	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
268	log	1	{"impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651377192, "event_name": "change_explore_controls", "event_type": "user", "event_id": "JSFyKK5DN5-8y3OmhIDf_", "visibility": "visible"}	2026-06-28 12:56:18.395434	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
331	ChartRestApi.favorite_status	1	{"path": "/api/v1/chart/favorite_status/", "q": "!(1)", "object_ref": "ChartRestApi.favorite_status", "rison": [1]}	2026-06-28 12:59:27.33935	\N	\N	41	http://localhost:8088/explore/?datasource_type=table&datasource_id=1&slice_id=1
271	execute_sql	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": [], "orderby": [], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": [], "orderby": [], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "results", "object_ref": "superset.models.core"}	2026-06-28 12:56:26.372037	\N	\N	1	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
276	QueryObject.post_processing	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": [], "orderby": [], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": [], "orderby": [], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "full"}	2026-06-28 12:56:26.456814	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
281	ChartDataRestApi.data	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": [], "orderby": [], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": [], "orderby": [], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "results", "object_ref": "ChartDataRestApi.data", "is_cached": [null]}	2026-06-28 12:56:26.482272	\N	\N	149	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
285	log	1	{"impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651405594, "event_name": "change_explore_controls", "event_type": "user", "event_id": "e06_OGJ_YSFfDTZcUaw00", "visibility": "visible"}	2026-06-28 12:56:46.606616	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
290	QueryObject.post_processing	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": [{"expressionType": "SIMPLE", "column": {"advanced_data_type": null, "changed_on": "2026-06-28T12:55:43.092430", "column_name": "precio", "created_on": "2026-06-28T12:55:42.998705", "description": null, "expression": "", "extra": "{}", "filterable": true, "groupby": true, "id": 6, "is_active": true, "is_dttm": false, "python_date_format": null, "type": "NUMERIC(10, 2)", "type_generic": 0, "uuid": "fa9730f9-cbc0-4fa5-9cc9-5450ce5d1e09", "verbose_name": null}, "aggregate": "COUNT", "sqlExpression": null, "datasourceWarning": false, "hasCustomLabel": false, "label": "COUNT(precio)", "optionName": "metric_04okmh1lzygx_lh01aydpvec"}], "orderby": [[{"expressionType": "SIMPLE", "column": {"advanced_data_type": null, "changed_on": "2026-06-28T12:55:43.092430", "column_name": "precio", "created_on": "2026-06-28T12:55:42.998705", "description": null, "expression": "", "extra": "{}", "filterable": true, "groupby": true, "id": 6, "is_active": true, "is_dttm": false, "python_date_format": null, "type": "NUMERIC(10, 2)", "type_generic": 0, "uuid": "fa9730f9-cbc0-4fa5-9cc9-5450ce5d1e09", "verbose_name": null}, "aggregate": "COUNT", "sqlExpression": null, "datasourceWarning": false, "hasCustomLabel": false, "label": "COUNT(precio)", "optionName": "metric_04okmh1lzygx_lh01aydpvec"}, false]], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": [{"expressionType": "SIMPLE", "column": {"advanced_data_type": null, "changed_on": "2026-06-28T12:55:43.092430", "column_name": "precio", "created_on": "2026-06-28T12:55:42.998705", "description": null, "expression": "", "extra": "{}", "filterable": true, "groupby": true, "id": 6, "is_active": true, "is_dttm": false, "python_date_format": null, "type": "NUMERIC(10, 2)", "type_generic": 0, "uuid": "fa9730f9-cbc0-4fa5-9cc9-5450ce5d1e09", "verbose_name": null}, "aggregate": "COUNT", "sqlExpression": null, "datasourceWarning": false, "hasCustomLabel": false, "label": "COUNT(precio)", "optionName": "metric_04okmh1lzygx_lh01aydpvec"}], "orderby": [[{"expressionType": "SIMPLE", "column": {"advanced_data_type": null, "changed_on": "2026-06-28T12:55:43.092430", "column_name": "precio", "created_on": "2026-06-28T12:55:42.998705", "description": null, "expression": "", "extra": "{}", "filterable": true, "groupby": true, "id": 6, "is_active": true, "is_dttm": false, "python_date_format": null, "type": "NUMERIC(10, 2)", "type_generic": 0, "uuid": "fa9730f9-cbc0-4fa5-9cc9-5450ce5d1e09", "verbose_name": null}, "aggregate": "COUNT", "sqlExpression": null, "datasourceWarning": false, "hasCustomLabel": false, "label": "COUNT(precio)", "optionName": "metric_04okmh1lzygx_lh01aydpvec"}, false]], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "results"}	2026-06-28 12:56:48.275885	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
295	_get_data_response	1	\N	2026-06-28 12:56:48.304667	\N	\N	68	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
299	log	1	{"impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651408429, "event_name": "load_chart", "slice_id": 0, "applied_filters": [{"column": "fecha"}], "is_cached": null, "force_refresh": false, "row_count": 6, "datasource": "1__table", "start_offset": 146054, "duration": 264, "viz_type": "table", "data_age": null, "event_type": "timing", "trigger_event": "e06_OGJ_YSFfDTZcUaw00"}	2026-06-28 12:56:49.443583	\N	0	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
305	DatabaseRestApi.table_extra_metadata	1	{"path": "/api/v1/database/1/table_metadata/extra/", "name": "ventas", "catalog": "analytics", "schema": "public", "url_rule": "/api/v1/database/<int:pk>/table_metadata/extra/", "object_ref": "DatabaseRestApi.table_extra_metadata", "pk": 1}	2026-06-28 12:57:14.663718	\N	\N	10	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
363	log	1	{"source": "explore", "source_id": 1, "slice_id": 1, "impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651567125, "event_name": "change_explore_controls", "event_type": "user", "event_id": "eWYRU2R0YpdWJYT1TQhNq", "visibility": "visible"}	2026-06-28 12:59:28.748959	\N	1	0	http://localhost:8088/explore/?form_data_key=&datasource_type=table&datasource_id=1&slice_id=1
364	log	1	{"source": "explore", "source_id": 1, "slice_id": 1, "impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651567733, "event_name": "load_chart", "applied_filters": [{"column": "fecha"}], "is_cached": null, "force_refresh": false, "row_count": 6, "datasource": "1__table", "start_offset": 305092, "duration": 530, "viz_type": "histogram_v2", "data_age": null, "event_type": "timing", "trigger_event": "eWYRU2R0YpdWJYT1TQhNq"}	2026-06-28 12:59:28.748962	\N	1	0	http://localhost:8088/explore/?form_data_key=&datasource_type=table&datasource_id=1&slice_id=1
272	execute_sql	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": [], "orderby": [], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": [], "orderby": [], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "full", "object_ref": "superset.models.core"}	2026-06-28 12:56:26.372771	\N	\N	1	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
277	ChartDataRestApi.json_dumps	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": [], "orderby": [], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": [], "orderby": [], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "results"}	2026-06-28 12:56:26.469196	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
282	ChartDataRestApi.data	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": [], "orderby": [], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": [], "orderby": [], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "full", "object_ref": "ChartDataRestApi.data", "is_cached": [null]}	2026-06-28 12:56:26.483705	\N	\N	152	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
286	execute_sql	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": [{"expressionType": "SIMPLE", "column": {"advanced_data_type": null, "changed_on": "2026-06-28T12:55:43.092430", "column_name": "precio", "created_on": "2026-06-28T12:55:42.998705", "description": null, "expression": "", "extra": "{}", "filterable": true, "groupby": true, "id": 6, "is_active": true, "is_dttm": false, "python_date_format": null, "type": "NUMERIC(10, 2)", "type_generic": 0, "uuid": "fa9730f9-cbc0-4fa5-9cc9-5450ce5d1e09", "verbose_name": null}, "aggregate": "COUNT", "sqlExpression": null, "datasourceWarning": false, "hasCustomLabel": false, "label": "COUNT(precio)", "optionName": "metric_04okmh1lzygx_lh01aydpvec"}], "orderby": [[{"expressionType": "SIMPLE", "column": {"advanced_data_type": null, "changed_on": "2026-06-28T12:55:43.092430", "column_name": "precio", "created_on": "2026-06-28T12:55:42.998705", "description": null, "expression": "", "extra": "{}", "filterable": true, "groupby": true, "id": 6, "is_active": true, "is_dttm": false, "python_date_format": null, "type": "NUMERIC(10, 2)", "type_generic": 0, "uuid": "fa9730f9-cbc0-4fa5-9cc9-5450ce5d1e09", "verbose_name": null}, "aggregate": "COUNT", "sqlExpression": null, "datasourceWarning": false, "hasCustomLabel": false, "label": "COUNT(precio)", "optionName": "metric_04okmh1lzygx_lh01aydpvec"}, false]], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": [{"expressionType": "SIMPLE", "column": {"advanced_data_type": null, "changed_on": "2026-06-28T12:55:43.092430", "column_name": "precio", "created_on": "2026-06-28T12:55:42.998705", "description": null, "expression": "", "extra": "{}", "filterable": true, "groupby": true, "id": 6, "is_active": true, "is_dttm": false, "python_date_format": null, "type": "NUMERIC(10, 2)", "type_generic": 0, "uuid": "fa9730f9-cbc0-4fa5-9cc9-5450ce5d1e09", "verbose_name": null}, "aggregate": "COUNT", "sqlExpression": null, "datasourceWarning": false, "hasCustomLabel": false, "label": "COUNT(precio)", "optionName": "metric_04okmh1lzygx_lh01aydpvec"}], "orderby": [[{"expressionType": "SIMPLE", "column": {"advanced_data_type": null, "changed_on": "2026-06-28T12:55:43.092430", "column_name": "precio", "created_on": "2026-06-28T12:55:42.998705", "description": null, "expression": "", "extra": "{}", "filterable": true, "groupby": true, "id": 6, "is_active": true, "is_dttm": false, "python_date_format": null, "type": "NUMERIC(10, 2)", "type_generic": 0, "uuid": "fa9730f9-cbc0-4fa5-9cc9-5450ce5d1e09", "verbose_name": null}, "aggregate": "COUNT", "sqlExpression": null, "datasourceWarning": false, "hasCustomLabel": false, "label": "COUNT(precio)", "optionName": "metric_04okmh1lzygx_lh01aydpvec"}, false]], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "results", "object_ref": "superset.models.core"}	2026-06-28 12:56:48.250761	\N	\N	1	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
291	QueryObject.post_processing	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": [{"expressionType": "SIMPLE", "column": {"advanced_data_type": null, "changed_on": "2026-06-28T12:55:43.092430", "column_name": "precio", "created_on": "2026-06-28T12:55:42.998705", "description": null, "expression": "", "extra": "{}", "filterable": true, "groupby": true, "id": 6, "is_active": true, "is_dttm": false, "python_date_format": null, "type": "NUMERIC(10, 2)", "type_generic": 0, "uuid": "fa9730f9-cbc0-4fa5-9cc9-5450ce5d1e09", "verbose_name": null}, "aggregate": "COUNT", "sqlExpression": null, "datasourceWarning": false, "hasCustomLabel": false, "label": "COUNT(precio)", "optionName": "metric_04okmh1lzygx_lh01aydpvec"}], "orderby": [[{"expressionType": "SIMPLE", "column": {"advanced_data_type": null, "changed_on": "2026-06-28T12:55:43.092430", "column_name": "precio", "created_on": "2026-06-28T12:55:42.998705", "description": null, "expression": "", "extra": "{}", "filterable": true, "groupby": true, "id": 6, "is_active": true, "is_dttm": false, "python_date_format": null, "type": "NUMERIC(10, 2)", "type_generic": 0, "uuid": "fa9730f9-cbc0-4fa5-9cc9-5450ce5d1e09", "verbose_name": null}, "aggregate": "COUNT", "sqlExpression": null, "datasourceWarning": false, "hasCustomLabel": false, "label": "COUNT(precio)", "optionName": "metric_04okmh1lzygx_lh01aydpvec"}, false]], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": [{"expressionType": "SIMPLE", "column": {"advanced_data_type": null, "changed_on": "2026-06-28T12:55:43.092430", "column_name": "precio", "created_on": "2026-06-28T12:55:42.998705", "description": null, "expression": "", "extra": "{}", "filterable": true, "groupby": true, "id": 6, "is_active": true, "is_dttm": false, "python_date_format": null, "type": "NUMERIC(10, 2)", "type_generic": 0, "uuid": "fa9730f9-cbc0-4fa5-9cc9-5450ce5d1e09", "verbose_name": null}, "aggregate": "COUNT", "sqlExpression": null, "datasourceWarning": false, "hasCustomLabel": false, "label": "COUNT(precio)", "optionName": "metric_04okmh1lzygx_lh01aydpvec"}], "orderby": [[{"expressionType": "SIMPLE", "column": {"advanced_data_type": null, "changed_on": "2026-06-28T12:55:43.092430", "column_name": "precio", "created_on": "2026-06-28T12:55:42.998705", "description": null, "expression": "", "extra": "{}", "filterable": true, "groupby": true, "id": 6, "is_active": true, "is_dttm": false, "python_date_format": null, "type": "NUMERIC(10, 2)", "type_generic": 0, "uuid": "fa9730f9-cbc0-4fa5-9cc9-5450ce5d1e09", "verbose_name": null}, "aggregate": "COUNT", "sqlExpression": null, "datasourceWarning": false, "hasCustomLabel": false, "label": "COUNT(precio)", "optionName": "metric_04okmh1lzygx_lh01aydpvec"}, false]], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "full"}	2026-06-28 12:56:48.280879	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
296	ChartDataRestApi.data	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": [{"expressionType": "SIMPLE", "column": {"advanced_data_type": null, "changed_on": "2026-06-28T12:55:43.092430", "column_name": "precio", "created_on": "2026-06-28T12:55:42.998705", "description": null, "expression": "", "extra": "{}", "filterable": true, "groupby": true, "id": 6, "is_active": true, "is_dttm": false, "python_date_format": null, "type": "NUMERIC(10, 2)", "type_generic": 0, "uuid": "fa9730f9-cbc0-4fa5-9cc9-5450ce5d1e09", "verbose_name": null}, "aggregate": "COUNT", "sqlExpression": null, "datasourceWarning": false, "hasCustomLabel": false, "label": "COUNT(precio)", "optionName": "metric_04okmh1lzygx_lh01aydpvec"}], "orderby": [[{"expressionType": "SIMPLE", "column": {"advanced_data_type": null, "changed_on": "2026-06-28T12:55:43.092430", "column_name": "precio", "created_on": "2026-06-28T12:55:42.998705", "description": null, "expression": "", "extra": "{}", "filterable": true, "groupby": true, "id": 6, "is_active": true, "is_dttm": false, "python_date_format": null, "type": "NUMERIC(10, 2)", "type_generic": 0, "uuid": "fa9730f9-cbc0-4fa5-9cc9-5450ce5d1e09", "verbose_name": null}, "aggregate": "COUNT", "sqlExpression": null, "datasourceWarning": false, "hasCustomLabel": false, "label": "COUNT(precio)", "optionName": "metric_04okmh1lzygx_lh01aydpvec"}, false]], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": [{"expressionType": "SIMPLE", "column": {"advanced_data_type": null, "changed_on": "2026-06-28T12:55:43.092430", "column_name": "precio", "created_on": "2026-06-28T12:55:42.998705", "description": null, "expression": "", "extra": "{}", "filterable": true, "groupby": true, "id": 6, "is_active": true, "is_dttm": false, "python_date_format": null, "type": "NUMERIC(10, 2)", "type_generic": 0, "uuid": "fa9730f9-cbc0-4fa5-9cc9-5450ce5d1e09", "verbose_name": null}, "aggregate": "COUNT", "sqlExpression": null, "datasourceWarning": false, "hasCustomLabel": false, "label": "COUNT(precio)", "optionName": "metric_04okmh1lzygx_lh01aydpvec"}], "orderby": [[{"expressionType": "SIMPLE", "column": {"advanced_data_type": null, "changed_on": "2026-06-28T12:55:43.092430", "column_name": "precio", "created_on": "2026-06-28T12:55:42.998705", "description": null, "expression": "", "extra": "{}", "filterable": true, "groupby": true, "id": 6, "is_active": true, "is_dttm": false, "python_date_format": null, "type": "NUMERIC(10, 2)", "type_generic": 0, "uuid": "fa9730f9-cbc0-4fa5-9cc9-5450ce5d1e09", "verbose_name": null}, "aggregate": "COUNT", "sqlExpression": null, "datasourceWarning": false, "hasCustomLabel": false, "label": "COUNT(precio)", "optionName": "metric_04okmh1lzygx_lh01aydpvec"}, false]], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "results", "object_ref": "ChartDataRestApi.data", "is_cached": [null]}	2026-06-28 12:56:48.306364	\N	\N	98	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
300	DatabaseRestApi.table_extra_metadata	1	{"path": "/api/v1/database/1/table_metadata/extra/", "name": "ventas", "catalog": "analytics", "schema": "public", "url_rule": "/api/v1/database/<int:pk>/table_metadata/extra/", "object_ref": "DatabaseRestApi.table_extra_metadata", "pk": 1}	2026-06-28 12:56:57.661992	\N	\N	6	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
273	load_into_dataframe	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": [], "orderby": [], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": [], "orderby": [], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "results", "object_ref": "Database.load_into_dataframe"}	2026-06-28 12:56:26.442635	\N	\N	1	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
278	ChartDataRestApi.json_dumps	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": [], "orderby": [], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": [], "orderby": [], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "full"}	2026-06-28 12:56:26.471896	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
287	execute_sql	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": [{"expressionType": "SIMPLE", "column": {"advanced_data_type": null, "changed_on": "2026-06-28T12:55:43.092430", "column_name": "precio", "created_on": "2026-06-28T12:55:42.998705", "description": null, "expression": "", "extra": "{}", "filterable": true, "groupby": true, "id": 6, "is_active": true, "is_dttm": false, "python_date_format": null, "type": "NUMERIC(10, 2)", "type_generic": 0, "uuid": "fa9730f9-cbc0-4fa5-9cc9-5450ce5d1e09", "verbose_name": null}, "aggregate": "COUNT", "sqlExpression": null, "datasourceWarning": false, "hasCustomLabel": false, "label": "COUNT(precio)", "optionName": "metric_04okmh1lzygx_lh01aydpvec"}], "orderby": [[{"expressionType": "SIMPLE", "column": {"advanced_data_type": null, "changed_on": "2026-06-28T12:55:43.092430", "column_name": "precio", "created_on": "2026-06-28T12:55:42.998705", "description": null, "expression": "", "extra": "{}", "filterable": true, "groupby": true, "id": 6, "is_active": true, "is_dttm": false, "python_date_format": null, "type": "NUMERIC(10, 2)", "type_generic": 0, "uuid": "fa9730f9-cbc0-4fa5-9cc9-5450ce5d1e09", "verbose_name": null}, "aggregate": "COUNT", "sqlExpression": null, "datasourceWarning": false, "hasCustomLabel": false, "label": "COUNT(precio)", "optionName": "metric_04okmh1lzygx_lh01aydpvec"}, false]], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": [{"expressionType": "SIMPLE", "column": {"advanced_data_type": null, "changed_on": "2026-06-28T12:55:43.092430", "column_name": "precio", "created_on": "2026-06-28T12:55:42.998705", "description": null, "expression": "", "extra": "{}", "filterable": true, "groupby": true, "id": 6, "is_active": true, "is_dttm": false, "python_date_format": null, "type": "NUMERIC(10, 2)", "type_generic": 0, "uuid": "fa9730f9-cbc0-4fa5-9cc9-5450ce5d1e09", "verbose_name": null}, "aggregate": "COUNT", "sqlExpression": null, "datasourceWarning": false, "hasCustomLabel": false, "label": "COUNT(precio)", "optionName": "metric_04okmh1lzygx_lh01aydpvec"}], "orderby": [[{"expressionType": "SIMPLE", "column": {"advanced_data_type": null, "changed_on": "2026-06-28T12:55:43.092430", "column_name": "precio", "created_on": "2026-06-28T12:55:42.998705", "description": null, "expression": "", "extra": "{}", "filterable": true, "groupby": true, "id": 6, "is_active": true, "is_dttm": false, "python_date_format": null, "type": "NUMERIC(10, 2)", "type_generic": 0, "uuid": "fa9730f9-cbc0-4fa5-9cc9-5450ce5d1e09", "verbose_name": null}, "aggregate": "COUNT", "sqlExpression": null, "datasourceWarning": false, "hasCustomLabel": false, "label": "COUNT(precio)", "optionName": "metric_04okmh1lzygx_lh01aydpvec"}, false]], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "full", "object_ref": "superset.models.core"}	2026-06-28 12:56:48.257303	\N	\N	1	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
292	ChartDataRestApi.json_dumps	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": [{"expressionType": "SIMPLE", "column": {"advanced_data_type": null, "changed_on": "2026-06-28T12:55:43.092430", "column_name": "precio", "created_on": "2026-06-28T12:55:42.998705", "description": null, "expression": "", "extra": "{}", "filterable": true, "groupby": true, "id": 6, "is_active": true, "is_dttm": false, "python_date_format": null, "type": "NUMERIC(10, 2)", "type_generic": 0, "uuid": "fa9730f9-cbc0-4fa5-9cc9-5450ce5d1e09", "verbose_name": null}, "aggregate": "COUNT", "sqlExpression": null, "datasourceWarning": false, "hasCustomLabel": false, "label": "COUNT(precio)", "optionName": "metric_04okmh1lzygx_lh01aydpvec"}], "orderby": [[{"expressionType": "SIMPLE", "column": {"advanced_data_type": null, "changed_on": "2026-06-28T12:55:43.092430", "column_name": "precio", "created_on": "2026-06-28T12:55:42.998705", "description": null, "expression": "", "extra": "{}", "filterable": true, "groupby": true, "id": 6, "is_active": true, "is_dttm": false, "python_date_format": null, "type": "NUMERIC(10, 2)", "type_generic": 0, "uuid": "fa9730f9-cbc0-4fa5-9cc9-5450ce5d1e09", "verbose_name": null}, "aggregate": "COUNT", "sqlExpression": null, "datasourceWarning": false, "hasCustomLabel": false, "label": "COUNT(precio)", "optionName": "metric_04okmh1lzygx_lh01aydpvec"}, false]], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": [{"expressionType": "SIMPLE", "column": {"advanced_data_type": null, "changed_on": "2026-06-28T12:55:43.092430", "column_name": "precio", "created_on": "2026-06-28T12:55:42.998705", "description": null, "expression": "", "extra": "{}", "filterable": true, "groupby": true, "id": 6, "is_active": true, "is_dttm": false, "python_date_format": null, "type": "NUMERIC(10, 2)", "type_generic": 0, "uuid": "fa9730f9-cbc0-4fa5-9cc9-5450ce5d1e09", "verbose_name": null}, "aggregate": "COUNT", "sqlExpression": null, "datasourceWarning": false, "hasCustomLabel": false, "label": "COUNT(precio)", "optionName": "metric_04okmh1lzygx_lh01aydpvec"}], "orderby": [[{"expressionType": "SIMPLE", "column": {"advanced_data_type": null, "changed_on": "2026-06-28T12:55:43.092430", "column_name": "precio", "created_on": "2026-06-28T12:55:42.998705", "description": null, "expression": "", "extra": "{}", "filterable": true, "groupby": true, "id": 6, "is_active": true, "is_dttm": false, "python_date_format": null, "type": "NUMERIC(10, 2)", "type_generic": 0, "uuid": "fa9730f9-cbc0-4fa5-9cc9-5450ce5d1e09", "verbose_name": null}, "aggregate": "COUNT", "sqlExpression": null, "datasourceWarning": false, "hasCustomLabel": false, "label": "COUNT(precio)", "optionName": "metric_04okmh1lzygx_lh01aydpvec"}, false]], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "results"}	2026-06-28 12:56:48.289801	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
297	ChartDataRestApi.data	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": [{"expressionType": "SIMPLE", "column": {"advanced_data_type": null, "changed_on": "2026-06-28T12:55:43.092430", "column_name": "precio", "created_on": "2026-06-28T12:55:42.998705", "description": null, "expression": "", "extra": "{}", "filterable": true, "groupby": true, "id": 6, "is_active": true, "is_dttm": false, "python_date_format": null, "type": "NUMERIC(10, 2)", "type_generic": 0, "uuid": "fa9730f9-cbc0-4fa5-9cc9-5450ce5d1e09", "verbose_name": null}, "aggregate": "COUNT", "sqlExpression": null, "datasourceWarning": false, "hasCustomLabel": false, "label": "COUNT(precio)", "optionName": "metric_04okmh1lzygx_lh01aydpvec"}], "orderby": [[{"expressionType": "SIMPLE", "column": {"advanced_data_type": null, "changed_on": "2026-06-28T12:55:43.092430", "column_name": "precio", "created_on": "2026-06-28T12:55:42.998705", "description": null, "expression": "", "extra": "{}", "filterable": true, "groupby": true, "id": 6, "is_active": true, "is_dttm": false, "python_date_format": null, "type": "NUMERIC(10, 2)", "type_generic": 0, "uuid": "fa9730f9-cbc0-4fa5-9cc9-5450ce5d1e09", "verbose_name": null}, "aggregate": "COUNT", "sqlExpression": null, "datasourceWarning": false, "hasCustomLabel": false, "label": "COUNT(precio)", "optionName": "metric_04okmh1lzygx_lh01aydpvec"}, false]], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": [{"expressionType": "SIMPLE", "column": {"advanced_data_type": null, "changed_on": "2026-06-28T12:55:43.092430", "column_name": "precio", "created_on": "2026-06-28T12:55:42.998705", "description": null, "expression": "", "extra": "{}", "filterable": true, "groupby": true, "id": 6, "is_active": true, "is_dttm": false, "python_date_format": null, "type": "NUMERIC(10, 2)", "type_generic": 0, "uuid": "fa9730f9-cbc0-4fa5-9cc9-5450ce5d1e09", "verbose_name": null}, "aggregate": "COUNT", "sqlExpression": null, "datasourceWarning": false, "hasCustomLabel": false, "label": "COUNT(precio)", "optionName": "metric_04okmh1lzygx_lh01aydpvec"}], "orderby": [[{"expressionType": "SIMPLE", "column": {"advanced_data_type": null, "changed_on": "2026-06-28T12:55:43.092430", "column_name": "precio", "created_on": "2026-06-28T12:55:42.998705", "description": null, "expression": "", "extra": "{}", "filterable": true, "groupby": true, "id": 6, "is_active": true, "is_dttm": false, "python_date_format": null, "type": "NUMERIC(10, 2)", "type_generic": 0, "uuid": "fa9730f9-cbc0-4fa5-9cc9-5450ce5d1e09", "verbose_name": null}, "aggregate": "COUNT", "sqlExpression": null, "datasourceWarning": false, "hasCustomLabel": false, "label": "COUNT(precio)", "optionName": "metric_04okmh1lzygx_lh01aydpvec"}, false]], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "full", "object_ref": "ChartDataRestApi.data", "is_cached": [null]}	2026-06-28 12:56:48.31204	\N	\N	99	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
301	log	1	{"impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651417485, "event_name": "change_explore_controls", "event_type": "user", "event_id": "asRPVBwsvrpAeLUmdUegg", "visibility": "visible"}	2026-06-28 12:56:58.589319	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
302	log	1	{"impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651417568, "event_name": "change_explore_controls", "event_type": "user", "event_id": "ZRZn281ORd-ETJXVz55DM", "visibility": "visible"}	2026-06-28 12:56:58.589324	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
307	log	1	{"impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651437378, "event_name": "change_explore_controls", "event_type": "user", "event_id": "Jpq4iqPKhEVedKHyKRSYI", "visibility": "visible"}	2026-06-28 12:57:18.468293	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
308	log	1	{"impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651437402, "event_name": "change_explore_controls", "event_type": "user", "event_id": "0g5kXPsCeRY9BlLXkk6Tp", "visibility": "visible"}	2026-06-28 12:57:18.468296	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
309	log	1	{"impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651437429, "event_name": "change_explore_controls", "event_type": "user", "event_id": "plF9nqNUKu28aoJUkQwzF", "visibility": "visible"}	2026-06-28 12:57:18.468298	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
274	load_into_dataframe	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": [], "orderby": [], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": [], "orderby": [], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "full", "object_ref": "Database.load_into_dataframe"}	2026-06-28 12:56:26.443611	\N	\N	1	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
279	_get_data_response	1	\N	2026-06-28 12:56:26.477637	\N	\N	130	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
283	ExploreFormDataRestApi.put	1	{"path": "/api/v1/explore/form_data/qmxrMRhqerk", "tab_id": "3", "datasource_id": 1, "datasource_type": "table", "form_data": {}, "url_rule": "/api/v1/explore/form_data/<string:key>", "object_ref": "ExploreFormDataRestApi.put", "key": "qmxrMRhqerk"}	2026-06-28 12:56:27.254621	\N	\N	12	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
288	load_into_dataframe	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": [{"expressionType": "SIMPLE", "column": {"advanced_data_type": null, "changed_on": "2026-06-28T12:55:43.092430", "column_name": "precio", "created_on": "2026-06-28T12:55:42.998705", "description": null, "expression": "", "extra": "{}", "filterable": true, "groupby": true, "id": 6, "is_active": true, "is_dttm": false, "python_date_format": null, "type": "NUMERIC(10, 2)", "type_generic": 0, "uuid": "fa9730f9-cbc0-4fa5-9cc9-5450ce5d1e09", "verbose_name": null}, "aggregate": "COUNT", "sqlExpression": null, "datasourceWarning": false, "hasCustomLabel": false, "label": "COUNT(precio)", "optionName": "metric_04okmh1lzygx_lh01aydpvec"}], "orderby": [[{"expressionType": "SIMPLE", "column": {"advanced_data_type": null, "changed_on": "2026-06-28T12:55:43.092430", "column_name": "precio", "created_on": "2026-06-28T12:55:42.998705", "description": null, "expression": "", "extra": "{}", "filterable": true, "groupby": true, "id": 6, "is_active": true, "is_dttm": false, "python_date_format": null, "type": "NUMERIC(10, 2)", "type_generic": 0, "uuid": "fa9730f9-cbc0-4fa5-9cc9-5450ce5d1e09", "verbose_name": null}, "aggregate": "COUNT", "sqlExpression": null, "datasourceWarning": false, "hasCustomLabel": false, "label": "COUNT(precio)", "optionName": "metric_04okmh1lzygx_lh01aydpvec"}, false]], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": [{"expressionType": "SIMPLE", "column": {"advanced_data_type": null, "changed_on": "2026-06-28T12:55:43.092430", "column_name": "precio", "created_on": "2026-06-28T12:55:42.998705", "description": null, "expression": "", "extra": "{}", "filterable": true, "groupby": true, "id": 6, "is_active": true, "is_dttm": false, "python_date_format": null, "type": "NUMERIC(10, 2)", "type_generic": 0, "uuid": "fa9730f9-cbc0-4fa5-9cc9-5450ce5d1e09", "verbose_name": null}, "aggregate": "COUNT", "sqlExpression": null, "datasourceWarning": false, "hasCustomLabel": false, "label": "COUNT(precio)", "optionName": "metric_04okmh1lzygx_lh01aydpvec"}], "orderby": [[{"expressionType": "SIMPLE", "column": {"advanced_data_type": null, "changed_on": "2026-06-28T12:55:43.092430", "column_name": "precio", "created_on": "2026-06-28T12:55:42.998705", "description": null, "expression": "", "extra": "{}", "filterable": true, "groupby": true, "id": 6, "is_active": true, "is_dttm": false, "python_date_format": null, "type": "NUMERIC(10, 2)", "type_generic": 0, "uuid": "fa9730f9-cbc0-4fa5-9cc9-5450ce5d1e09", "verbose_name": null}, "aggregate": "COUNT", "sqlExpression": null, "datasourceWarning": false, "hasCustomLabel": false, "label": "COUNT(precio)", "optionName": "metric_04okmh1lzygx_lh01aydpvec"}, false]], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "results", "object_ref": "Database.load_into_dataframe"}	2026-06-28 12:56:48.263427	\N	\N	2	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
293	ChartDataRestApi.json_dumps	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": [{"expressionType": "SIMPLE", "column": {"advanced_data_type": null, "changed_on": "2026-06-28T12:55:43.092430", "column_name": "precio", "created_on": "2026-06-28T12:55:42.998705", "description": null, "expression": "", "extra": "{}", "filterable": true, "groupby": true, "id": 6, "is_active": true, "is_dttm": false, "python_date_format": null, "type": "NUMERIC(10, 2)", "type_generic": 0, "uuid": "fa9730f9-cbc0-4fa5-9cc9-5450ce5d1e09", "verbose_name": null}, "aggregate": "COUNT", "sqlExpression": null, "datasourceWarning": false, "hasCustomLabel": false, "label": "COUNT(precio)", "optionName": "metric_04okmh1lzygx_lh01aydpvec"}], "orderby": [[{"expressionType": "SIMPLE", "column": {"advanced_data_type": null, "changed_on": "2026-06-28T12:55:43.092430", "column_name": "precio", "created_on": "2026-06-28T12:55:42.998705", "description": null, "expression": "", "extra": "{}", "filterable": true, "groupby": true, "id": 6, "is_active": true, "is_dttm": false, "python_date_format": null, "type": "NUMERIC(10, 2)", "type_generic": 0, "uuid": "fa9730f9-cbc0-4fa5-9cc9-5450ce5d1e09", "verbose_name": null}, "aggregate": "COUNT", "sqlExpression": null, "datasourceWarning": false, "hasCustomLabel": false, "label": "COUNT(precio)", "optionName": "metric_04okmh1lzygx_lh01aydpvec"}, false]], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": [{"expressionType": "SIMPLE", "column": {"advanced_data_type": null, "changed_on": "2026-06-28T12:55:43.092430", "column_name": "precio", "created_on": "2026-06-28T12:55:42.998705", "description": null, "expression": "", "extra": "{}", "filterable": true, "groupby": true, "id": 6, "is_active": true, "is_dttm": false, "python_date_format": null, "type": "NUMERIC(10, 2)", "type_generic": 0, "uuid": "fa9730f9-cbc0-4fa5-9cc9-5450ce5d1e09", "verbose_name": null}, "aggregate": "COUNT", "sqlExpression": null, "datasourceWarning": false, "hasCustomLabel": false, "label": "COUNT(precio)", "optionName": "metric_04okmh1lzygx_lh01aydpvec"}], "orderby": [[{"expressionType": "SIMPLE", "column": {"advanced_data_type": null, "changed_on": "2026-06-28T12:55:43.092430", "column_name": "precio", "created_on": "2026-06-28T12:55:42.998705", "description": null, "expression": "", "extra": "{}", "filterable": true, "groupby": true, "id": 6, "is_active": true, "is_dttm": false, "python_date_format": null, "type": "NUMERIC(10, 2)", "type_generic": 0, "uuid": "fa9730f9-cbc0-4fa5-9cc9-5450ce5d1e09", "verbose_name": null}, "aggregate": "COUNT", "sqlExpression": null, "datasourceWarning": false, "hasCustomLabel": false, "label": "COUNT(precio)", "optionName": "metric_04okmh1lzygx_lh01aydpvec"}, false]], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "full"}	2026-06-28 12:56:48.296722	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
303	log	1	{"impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651419262, "event_name": "change_explore_controls", "event_type": "user", "event_id": "t1XngCj3U8jOPThj3WT3v", "visibility": "visible"}	2026-06-28 12:57:00.275683	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
311	log	1	{"impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651444124, "event_name": "change_explore_controls", "event_type": "user", "event_id": "16cebTIxdSoO4QIFZIitb", "visibility": "visible"}	2026-06-28 12:57:25.136083	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
316	load_into_dataframe	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}, "result_format": "json", "result_type": "full", "object_ref": "Database.load_into_dataframe"}	2026-06-28 12:57:34.961818	\N	\N	1	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
321	_get_data_response	1	\N	2026-06-28 12:57:35.02241	\N	\N	99	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
325	ExploreFormDataRestApi.put	1	{"path": "/api/v1/explore/form_data/qmxrMRhqerk", "tab_id": "3", "datasource_id": 1, "datasource_type": "table", "form_data": {}, "url_rule": "/api/v1/explore/form_data/<string:key>", "object_ref": "ExploreFormDataRestApi.put", "key": "qmxrMRhqerk"}	2026-06-28 12:57:35.805749	\N	\N	11	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
368	SavedQueryRestApi.info	1	{"path": "/api/v1/saved_query/_info", "q": "(keys:!(permissions))", "rison": {"keys": ["permissions"]}}	2026-06-28 12:59:33.993409	\N	\N	28	http://localhost:8088/savedqueryview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
373	DashboardRestApi.info	1	{"path": "/api/v1/dashboard/_info", "q": "(keys:!(permissions))", "rison": {"keys": ["permissions"]}}	2026-06-28 12:59:37.134508	\N	\N	43	http://localhost:8088/dashboard/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc&viewMode=table
379	SqlLabRestApi.get	1	{"path": "/api/v1/sqllab/", "object_ref": "SqlLabRestApi.get"}	2026-06-28 12:59:43.691592	\N	\N	6	http://localhost:8088/sqllab?queryId=1
275	QueryObject.post_processing	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": [], "orderby": [], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": [], "orderby": [], "annotation_layers": [], "row_limit": 1000, "row_offset": 0, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "results"}	2026-06-28 12:56:26.455927	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
280	_get_data_response	1	\N	2026-06-28 12:56:26.478119	\N	\N	133	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
284	log	1	{"impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651386629, "event_name": "load_chart", "slice_id": 0, "applied_filters": [{"column": "fecha"}], "is_cached": null, "force_refresh": false, "row_count": 6, "datasource": "1__table", "start_offset": 124151, "duration": 367, "viz_type": "table", "data_age": null, "event_type": "timing", "trigger_event": "jG7yCgh7mKz55_t1GHzg3"}	2026-06-28 12:56:27.641586	\N	0	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
289	load_into_dataframe	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": [{"expressionType": "SIMPLE", "column": {"advanced_data_type": null, "changed_on": "2026-06-28T12:55:43.092430", "column_name": "precio", "created_on": "2026-06-28T12:55:42.998705", "description": null, "expression": "", "extra": "{}", "filterable": true, "groupby": true, "id": 6, "is_active": true, "is_dttm": false, "python_date_format": null, "type": "NUMERIC(10, 2)", "type_generic": 0, "uuid": "fa9730f9-cbc0-4fa5-9cc9-5450ce5d1e09", "verbose_name": null}, "aggregate": "COUNT", "sqlExpression": null, "datasourceWarning": false, "hasCustomLabel": false, "label": "COUNT(precio)", "optionName": "metric_04okmh1lzygx_lh01aydpvec"}], "orderby": [[{"expressionType": "SIMPLE", "column": {"advanced_data_type": null, "changed_on": "2026-06-28T12:55:43.092430", "column_name": "precio", "created_on": "2026-06-28T12:55:42.998705", "description": null, "expression": "", "extra": "{}", "filterable": true, "groupby": true, "id": 6, "is_active": true, "is_dttm": false, "python_date_format": null, "type": "NUMERIC(10, 2)", "type_generic": 0, "uuid": "fa9730f9-cbc0-4fa5-9cc9-5450ce5d1e09", "verbose_name": null}, "aggregate": "COUNT", "sqlExpression": null, "datasourceWarning": false, "hasCustomLabel": false, "label": "COUNT(precio)", "optionName": "metric_04okmh1lzygx_lh01aydpvec"}, false]], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"time_grain_sqla": "P1D", "having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto"], "metrics": [{"expressionType": "SIMPLE", "column": {"advanced_data_type": null, "changed_on": "2026-06-28T12:55:43.092430", "column_name": "precio", "created_on": "2026-06-28T12:55:42.998705", "description": null, "expression": "", "extra": "{}", "filterable": true, "groupby": true, "id": 6, "is_active": true, "is_dttm": false, "python_date_format": null, "type": "NUMERIC(10, 2)", "type_generic": 0, "uuid": "fa9730f9-cbc0-4fa5-9cc9-5450ce5d1e09", "verbose_name": null}, "aggregate": "COUNT", "sqlExpression": null, "datasourceWarning": false, "hasCustomLabel": false, "label": "COUNT(precio)", "optionName": "metric_04okmh1lzygx_lh01aydpvec"}], "orderby": [[{"expressionType": "SIMPLE", "column": {"advanced_data_type": null, "changed_on": "2026-06-28T12:55:43.092430", "column_name": "precio", "created_on": "2026-06-28T12:55:42.998705", "description": null, "expression": "", "extra": "{}", "filterable": true, "groupby": true, "id": 6, "is_active": true, "is_dttm": false, "python_date_format": null, "type": "NUMERIC(10, 2)", "type_generic": 0, "uuid": "fa9730f9-cbc0-4fa5-9cc9-5450ce5d1e09", "verbose_name": null}, "aggregate": "COUNT", "sqlExpression": null, "datasourceWarning": false, "hasCustomLabel": false, "label": "COUNT(precio)", "optionName": "metric_04okmh1lzygx_lh01aydpvec"}, false]], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [], "time_offsets": []}, "result_format": "json", "result_type": "full", "object_ref": "Database.load_into_dataframe"}	2026-06-28 12:56:48.268942	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
294	_get_data_response	1	\N	2026-06-28 12:56:48.299457	\N	\N	73	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
298	ExploreFormDataRestApi.put	1	{"path": "/api/v1/explore/form_data/qmxrMRhqerk", "tab_id": "3", "datasource_id": 1, "datasource_type": "table", "form_data": {}, "url_rule": "/api/v1/explore/form_data/<string:key>", "object_ref": "ExploreFormDataRestApi.put", "key": "qmxrMRhqerk"}	2026-06-28 12:56:49.17266	\N	\N	11	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
304	log	1	{"impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651420949, "event_name": "change_explore_controls", "event_type": "user", "event_id": "r2YB-guqMH4t421IK5JJ0", "visibility": "visible"}	2026-06-28 12:57:01.95991	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
312	log	1	{"impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651451258, "event_name": "change_explore_controls", "event_type": "user", "event_id": "65IDkt26dG9IAG9sS_-fx", "visibility": "visible"}	2026-06-28 12:57:32.269755	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
318	QueryObject.post_processing	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 1000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 1000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}, "result_format": "json", "result_type": "results"}	2026-06-28 12:57:35.000667	\N	\N	35	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
323	ChartDataRestApi.data	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}, "result_format": "json", "result_type": "full", "object_ref": "ChartDataRestApi.data", "is_cached": [null]}	2026-06-28 12:57:35.028023	\N	\N	125	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
313	execute_sql	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 1000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 1000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}, "result_format": "json", "result_type": "results", "object_ref": "superset.models.core"}	2026-06-28 12:57:34.939368	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
317	QueryObject.post_processing	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}, "result_format": "json", "result_type": "full"}	2026-06-28 12:57:34.99993	\N	\N	16	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
322	_get_data_response	1	\N	2026-06-28 12:57:35.024128	\N	\N	109	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
326	log	1	{"impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651455036, "event_name": "load_chart", "slice_id": 0, "applied_filters": [{"column": "fecha"}], "is_cached": null, "force_refresh": false, "row_count": 6, "datasource": "1__table", "start_offset": 192694, "duration": 231, "viz_type": "histogram_v2", "data_age": null, "event_type": "timing", "trigger_event": "65IDkt26dG9IAG9sS_-fx"}	2026-06-28 12:57:36.05251	\N	0	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
330	ExploreRestApi.get	1	{"path": "/api/v1/explore/", "datasource_type": "table", "datasource_id": "1", "slice_id": "1", "object_ref": "ExploreRestApi.get"}	2026-06-28 12:59:27.112963	\N	1	30	http://localhost:8088/explore/?datasource_type=table&datasource_id=1&slice_id=1
333	execute_sql	1	{"path": "/api/v1/chart/data", "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 1000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}], "slice_id": 1}, "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 1000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}], "result_format": "json", "result_type": "results", "object_ref": "superset.models.core"}	2026-06-28 12:59:27.446982	\N	1	1	http://localhost:8088/explore/?datasource_type=table&datasource_id=1&slice_id=1
339	load_into_dataframe	1	{"path": "/api/v1/chart/data", "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 1000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}], "slice_id": 1}, "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 1000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}], "result_format": "json", "result_type": "results", "object_ref": "Database.load_into_dataframe"}	2026-06-28 12:59:27.480911	\N	1	3	http://localhost:8088/explore/?datasource_type=table&datasource_id=1&slice_id=1
384	log	1	{"source": "explore", "source_id": 1, "slice_id": 1, "impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651583654, "event_name": "spa_navigation", "path": "/sqllab", "event_type": "user", "event_id": "6mOdW-Vs6SrggX_IsCw1T", "visibility": "visible"}	2026-06-28 12:59:44.954908	\N	1	0	http://localhost:8088/sqllab
314	execute_sql	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}, "result_format": "json", "result_type": "full", "object_ref": "superset.models.core"}	2026-06-28 12:57:34.94993	\N	\N	1	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
319	ChartDataRestApi.json_dumps	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}, "result_format": "json", "result_type": "full"}	2026-06-28 12:57:35.013527	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
324	ChartDataRestApi.data	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 1000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 1000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}, "result_format": "json", "result_type": "results", "object_ref": "ChartDataRestApi.data", "is_cached": [null]}	2026-06-28 12:57:35.029305	\N	\N	129	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
328	DashboardRestApi.get_list	1	{"path": "/api/v1/dashboard/", "q": "(columns:!(id,dashboard_title),filters:!((col:dashboard_title,opr:ct,value:''),(col:owners,opr:rel_m_m,value:1)),order_column:dashboard_title,page:0,page_size:100)", "object_ref": "DashboardRestApi.get_list"}	2026-06-28 12:59:25.208078	\N	\N	60	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
332	DatabaseRestApi.table_extra_metadata	1	{"path": "/api/v1/database/1/table_metadata/extra/", "name": "ventas", "catalog": "analytics", "schema": "public", "url_rule": "/api/v1/database/<int:pk>/table_metadata/extra/", "object_ref": "DatabaseRestApi.table_extra_metadata", "pk": 1}	2026-06-28 12:59:27.340666	\N	\N	33	http://localhost:8088/explore/?datasource_type=table&datasource_id=1&slice_id=1
338	load_into_dataframe	1	{"path": "/api/v1/chart/data", "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 1000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}], "slice_id": 1}, "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 1000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}], "result_format": "json", "result_type": "results", "object_ref": "Database.load_into_dataframe"}	2026-06-28 12:59:27.480359	\N	1	6	http://localhost:8088/explore/?datasource_type=table&datasource_id=1&slice_id=1
385	log	1	{"source": "explore", "source_id": 1, "slice_id": 1, "impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651583807, "event_name": "sqllab_load_tab_state", "payload": {"queryEditorId": "HSbLp_Hb1ic", "duration": 153, "inLocalStorage": true, "hasLoaded": true}, "event_type": "timing", "trigger_event": "6mOdW-Vs6SrggX_IsCw1T"}	2026-06-28 12:59:44.954913	\N	1	0	http://localhost:8088/sqllab
386	log	1	{"source": "explore", "source_id": 1, "slice_id": 1, "impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651583871, "event_name": "sqllab_monitor_local_storage_usage", "current_usage": 1.23, "query_count": 0, "event_type": "user", "event_id": "hvs691bqA9lRS6UF6rIPJ", "visibility": "visible"}	2026-06-28 12:59:44.954915	\N	1	0	http://localhost:8088/sqllab
315	load_into_dataframe	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 1000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 1000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}, "result_format": "json", "result_type": "results", "object_ref": "Database.load_into_dataframe"}	2026-06-28 12:57:34.951926	\N	\N	2	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
320	ChartDataRestApi.json_dumps	1	{"path": "/api/v1/chart/data", "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 1000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}], "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 1000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}, "result_format": "json", "result_type": "results"}	2026-06-28 12:57:35.016972	\N	\N	0	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
334	execute_sql	1	{"path": "/api/v1/chart/data", "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}], "slice_id": 1}, "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}], "result_format": "json", "result_type": "full", "object_ref": "superset.models.core"}	2026-06-28 12:59:27.450321	\N	1	1	http://localhost:8088/explore/?datasource_type=table&datasource_id=1&slice_id=1
340	load_into_dataframe	1	{"path": "/api/v1/chart/data", "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}], "slice_id": 1}, "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}], "result_format": "json", "result_type": "full", "object_ref": "Database.load_into_dataframe"}	2026-06-28 12:59:27.490619	\N	1	0	http://localhost:8088/explore/?datasource_type=table&datasource_id=1&slice_id=1
347	ChartDataRestApi.json_dumps	1	{"path": "/api/v1/chart/data", "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 1000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}], "slice_id": 1}, "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 1000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}], "result_format": "json", "result_type": "results"}	2026-06-28 12:59:27.574363	\N	1	0	http://localhost:8088/explore/?datasource_type=table&datasource_id=1&slice_id=1
356	_get_data_response	1	\N	2026-06-28 12:59:27.61362	\N	1	215	http://localhost:8088/explore/?datasource_type=table&datasource_id=1&slice_id=1
329	ChartRestApi.post	1	{"path": "/api/v1/chart/", "params": "{\\"datasource\\":\\"1__table\\",\\"viz_type\\":\\"histogram_v2\\",\\"matrixify_enable\\":false,\\"matrixify_mode_columns\\":\\"disabled\\",\\"matrixify_dimension_selection_mode_columns\\":\\"members\\",\\"matrixify_dimension_columns\\":{\\"dimension\\":\\"\\",\\"values\\":[]},\\"matrixify_topn_value_columns\\":10,\\"matrixify_all_sort_by_columns\\":\\"a_to_z\\",\\"matrixify_topn_order_columns\\":true,\\"matrixify_show_column_headers\\":true,\\"matrixify_fit_columns_dynamically\\":true,\\"matrixify_mode_rows\\":\\"disabled\\",\\"matrixify_dimension_selection_mode_rows\\":\\"members\\",\\"matrixify_dimension_rows\\":{\\"dimension\\":\\"\\",\\"values\\":[]},\\"matrixify_topn_value_rows\\":10,\\"matrixify_all_sort_by_rows\\":\\"a_to_z\\",\\"matrixify_topn_order_rows\\":true,\\"matrixify_show_row_labels\\":true,\\"matrixify_row_height\\":300,\\"matrixify_charts_per_row\\":4,\\"matrixify_cell_title_template\\":\\"\\",\\"column\\":\\"cantidad\\",\\"groupby\\":[\\"producto\\",\\"precio\\"],\\"adhoc_filters\\":[{\\"clause\\":\\"WHERE\\",\\"subject\\":\\"fecha\\",\\"operator\\":\\"TEMPORAL_RANGE\\",\\"comparator\\":\\"No filter\\",\\"expressionType\\":\\"SIMPLE\\"}],\\"row_limit\\":10000,\\"bins\\":5,\\"normalize\\":false,\\"cumulative\\":false,\\"color_scheme\\":\\"supersetColors\\",\\"show_value\\":false,\\"show_legend\\":true,\\"x_axis_title\\":\\"\\",\\"x_axis_format\\":\\"SMART_NUMBER\\",\\"y_axis_title\\":\\"\\",\\"y_axis_format\\":\\"SMART_NUMBER\\",\\"extra_form_data\\":{},\\"dashboards\\":[]}", "slice_name": "fdsf", "viz_type": "histogram_v2", "datasource_id": 1, "datasource_type": "table", "dashboards": [], "owners": [], "query_context": "{\\"datasource\\":{\\"id\\":1,\\"type\\":\\"table\\"},\\"force\\":false,\\"queries\\":[{\\"filters\\":[{\\"col\\":\\"fecha\\",\\"op\\":\\"TEMPORAL_RANGE\\",\\"val\\":\\"No filter\\"}],\\"extras\\":{\\"having\\":\\"\\",\\"where\\":\\"\\"},\\"applied_time_extras\\":{},\\"columns\\":[\\"producto\\",\\"precio\\",\\"cantidad\\"],\\"annotation_layers\\":[],\\"row_limit\\":10000,\\"series_limit\\":0,\\"group_others_when_limit_reached\\":false,\\"order_desc\\":true,\\"url_params\\":{},\\"custom_params\\":{},\\"custom_form_data\\":{},\\"post_processing\\":[{\\"operation\\":\\"histogram\\",\\"options\\":{\\"column\\":\\"cantidad\\",\\"groupby\\":[\\"producto\\",\\"precio\\"],\\"bins\\":5,\\"cumulative\\":false,\\"normalize\\":false}}]}],\\"form_data\\":{\\"datasource\\":\\"1__table\\",\\"viz_type\\":\\"histogram_v2\\",\\"matrixify_enable\\":false,\\"matrixify_mode_columns\\":\\"disabled\\",\\"matrixify_dimension_selection_mode_columns\\":\\"members\\",\\"matrixify_dimension_columns\\":{\\"dimension\\":\\"\\",\\"values\\":[]},\\"matrixify_topn_value_columns\\":10,\\"matrixify_all_sort_by_columns\\":\\"a_to_z\\",\\"matrixify_topn_order_columns\\":true,\\"matrixify_show_column_headers\\":true,\\"matrixify_fit_columns_dynamically\\":true,\\"matrixify_mode_rows\\":\\"disabled\\",\\"matrixify_dimension_selection_mode_rows\\":\\"members\\",\\"matrixify_dimension_rows\\":{\\"dimension\\":\\"\\",\\"values\\":[]},\\"matrixify_topn_value_rows\\":10,\\"matrixify_all_sort_by_rows\\":\\"a_to_z\\",\\"matrixify_topn_order_rows\\":true,\\"matrixify_show_row_labels\\":true,\\"matrixify_row_height\\":300,\\"matrixify_charts_per_row\\":4,\\"matrixify_cell_title_template\\":\\"\\",\\"column\\":\\"cantidad\\",\\"groupby\\":[\\"producto\\",\\"precio\\"],\\"adhoc_filters\\":[{\\"clause\\":\\"WHERE\\",\\"subject\\":\\"fecha\\",\\"operator\\":\\"TEMPORAL_RANGE\\",\\"comparator\\":\\"No filter\\",\\"expressionType\\":\\"SIMPLE\\"}],\\"row_limit\\":10000,\\"bins\\":5,\\"normalize\\":false,\\"cumulative\\":false,\\"color_scheme\\":\\"supersetColors\\",\\"show_value\\":false,\\"show_legend\\":true,\\"x_axis_title\\":\\"\\",\\"x_axis_format\\":\\"SMART_NUMBER\\",\\"y_axis_title\\":\\"\\",\\"y_axis_format\\":\\"SMART_NUMBER\\",\\"extra_form_data\\":{},\\"dashboards\\":[],\\"force\\":false,\\"result_format\\":\\"json\\",\\"result_type\\":\\"full\\"},\\"result_format\\":\\"json\\",\\"result_type\\":\\"full\\"}", "object_ref": "ChartRestApi.post"}	2026-06-28 12:59:26.937954	\N	\N	198	http://localhost:8088/explore/?form_data_key=qmxrMRhqerk&datasource_type=table&datasource_id=1
335	execute_sql	1	{"path": "/api/v1/chart/data", "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 1000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}], "slice_id": 1}, "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 1000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}], "result_format": "json", "result_type": "results", "object_ref": "superset.models.core"}	2026-06-28 12:59:27.455683	\N	1	2	http://localhost:8088/explore/?datasource_type=table&datasource_id=1&slice_id=1
336	execute_sql	1	{"path": "/api/v1/chart/data", "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}], "slice_id": 1}, "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}], "result_format": "json", "result_type": "full", "object_ref": "superset.models.core"}	2026-06-28 12:59:27.472751	\N	1	1	http://localhost:8088/explore/?datasource_type=table&datasource_id=1&slice_id=1
342	QueryObject.post_processing	1	{"path": "/api/v1/chart/data", "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}], "slice_id": 1}, "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}], "result_format": "json", "result_type": "full"}	2026-06-28 12:59:27.523966	\N	1	25	http://localhost:8088/explore/?datasource_type=table&datasource_id=1&slice_id=1
343	QueryObject.post_processing	1	{"path": "/api/v1/chart/data", "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 1000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}], "slice_id": 1}, "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 1000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}], "result_format": "json", "result_type": "results"}	2026-06-28 12:59:27.537082	\N	1	18	http://localhost:8088/explore/?datasource_type=table&datasource_id=1&slice_id=1
387	log	1	{"source": "explore", "source_id": 1, "slice_id": 1, "impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651583940, "event_name": "sqllab_load_tab_state", "payload": {"queryEditorId": "e1ruoVCft_R", "duration": 286, "inLocalStorage": true, "hasLoaded": true}, "event_type": "timing", "trigger_event": "hvs691bqA9lRS6UF6rIPJ"}	2026-06-28 12:59:44.954916	\N	1	0	http://localhost:8088/sqllab
337	load_into_dataframe	1	{"path": "/api/v1/chart/data", "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}], "slice_id": 1}, "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}], "result_format": "json", "result_type": "full", "object_ref": "Database.load_into_dataframe"}	2026-06-28 12:59:27.479341	\N	1	2	http://localhost:8088/explore/?datasource_type=table&datasource_id=1&slice_id=1
341	execute_sql	1	{"path": "/api/v1/chart/data", "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 1000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}], "slice_id": 1}, "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 1000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}], "result_format": "json", "result_type": "results", "object_ref": "superset.models.core"}	2026-06-28 12:59:27.493385	\N	1	4	http://localhost:8088/explore/?datasource_type=table&datasource_id=1&slice_id=1
344	QueryObject.post_processing	1	{"path": "/api/v1/chart/data", "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 1000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}], "slice_id": 1}, "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 1000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}], "result_format": "json", "result_type": "results"}	2026-06-28 12:59:27.542609	\N	1	36	http://localhost:8088/explore/?datasource_type=table&datasource_id=1&slice_id=1
348	ChartDataRestApi.json_dumps	1	{"path": "/api/v1/chart/data", "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}], "slice_id": 1}, "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}], "result_format": "json", "result_type": "full"}	2026-06-28 12:59:27.575469	\N	1	0	http://localhost:8088/explore/?datasource_type=table&datasource_id=1&slice_id=1
353	QueryObject.post_processing	1	{"path": "/api/v1/chart/data", "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 1000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}], "slice_id": 1}, "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 1000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}], "result_format": "json", "result_type": "results"}	2026-06-28 12:59:27.609984	\N	1	22	http://localhost:8088/explore/?datasource_type=table&datasource_id=1&slice_id=1
355	_get_data_response	1	\N	2026-06-28 12:59:27.612876	\N	1	178	http://localhost:8088/explore/?datasource_type=table&datasource_id=1&slice_id=1
345	QueryObject.post_processing	1	{"path": "/api/v1/chart/data", "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}], "slice_id": 1}, "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}], "result_format": "json", "result_type": "full"}	2026-06-28 12:59:27.55414	\N	1	16	http://localhost:8088/explore/?datasource_type=table&datasource_id=1&slice_id=1
351	_get_data_response	1	\N	2026-06-28 12:59:27.596063	\N	1	168	http://localhost:8088/explore/?datasource_type=table&datasource_id=1&slice_id=1
360	ChartDataRestApi.json_dumps	1	{"path": "/api/v1/chart/data", "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 1000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}], "slice_id": 1}, "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 1000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}], "result_format": "json", "result_type": "results"}	2026-06-28 12:59:27.634614	\N	1	0	http://localhost:8088/explore/?datasource_type=table&datasource_id=1&slice_id=1
346	load_into_dataframe	1	{"path": "/api/v1/chart/data", "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 1000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}], "slice_id": 1}, "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 1000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}], "result_format": "json", "result_type": "results", "object_ref": "Database.load_into_dataframe"}	2026-06-28 12:59:27.557193	\N	1	9	http://localhost:8088/explore/?datasource_type=table&datasource_id=1&slice_id=1
352	_get_data_response	1	\N	2026-06-28 12:59:27.601172	\N	1	186	http://localhost:8088/explore/?datasource_type=table&datasource_id=1&slice_id=1
359	ChartDataRestApi.data	1	{"path": "/api/v1/chart/data", "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 1000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}], "slice_id": 1}, "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 1000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}], "result_format": "json", "result_type": "results", "object_ref": "ChartDataRestApi.data", "is_cached": [null]}	2026-06-28 12:59:27.625166	\N	1	281	http://localhost:8088/explore/?datasource_type=table&datasource_id=1&slice_id=1
349	ChartDataRestApi.json_dumps	1	{"path": "/api/v1/chart/data", "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 1000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}], "slice_id": 1}, "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 1000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}], "result_format": "json", "result_type": "results"}	2026-06-28 12:59:27.581384	\N	1	0	http://localhost:8088/explore/?datasource_type=table&datasource_id=1&slice_id=1
354	ChartDataRestApi.data	1	{"path": "/api/v1/chart/data", "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 1000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}], "slice_id": 1}, "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 1000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}], "result_format": "json", "result_type": "results", "object_ref": "ChartDataRestApi.data", "is_cached": [null]}	2026-06-28 12:59:27.612299	\N	1	246	http://localhost:8088/explore/?datasource_type=table&datasource_id=1&slice_id=1
361	_get_data_response	1	\N	2026-06-28 12:59:27.641998	\N	1	184	http://localhost:8088/explore/?datasource_type=table&datasource_id=1&slice_id=1
367	log	1	{"source": "explore", "source_id": 1, "slice_id": 1, "impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651569136, "event_name": "spa_navigation", "path": "/tablemodelview/list/", "event_type": "user", "event_id": "MbqyhQYaqbYUtTYgWKnQc", "visibility": "visible"}	2026-06-28 12:59:30.148795	\N	1	0	http://localhost:8088/tablemodelview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
372	DashboardRestApi.get_list	1	{"path": "/api/v1/dashboard/", "q": "(order_column:changed_on_delta_humanized,order_direction:desc,page:0,page_size:25,select_columns:!(id,dashboard_title,published,url,slug,changed_by,changed_by.id,changed_by.first_name,changed_by.last_name,changed_on_delta_humanized,owners,owners.id,owners.first_name,owners.last_name,tags.id,tags.name,tags.type,status,certified_by,certification_details,changed_on))", "rison": {"order_column": "changed_on_delta_humanized", "order_direction": "desc", "page": 0, "page_size": 25, "select_columns": ["id", "dashboard_title", "published", "url", "slug", "changed_by", "changed_by.id", "changed_by.first_name", "changed_by.last_name", "changed_on_delta_humanized", "owners", "owners.id", "owners.first_name", "owners.last_name", "tags.id", "tags.name", "tags.type", "status", "certified_by", "certification_details", "changed_on"]}}	2026-06-28 12:59:37.131506	\N	\N	25	http://localhost:8088/dashboard/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc&viewMode=table
378	log	1	{"source": "explore", "source_id": 1, "slice_id": 1, "impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651579781, "event_name": "spa_navigation", "path": "/sqllab/history/", "event_type": "user", "event_id": "QAeZl464zLmXC2g5Egte4", "visibility": "visible"}	2026-06-28 12:59:40.794408	\N	1	0	http://localhost:8088/sqllab/history/?pageIndex=0&sortColumn=start_time&sortOrder=desc
382	DatabaseRestApi.function_names	1	{"path": "/api/v1/database/1/function_names/", "url_rule": "/api/v1/database/<int:pk>/function_names/", "object_ref": "DatabaseRestApi.function_names", "pk": 1}	2026-06-28 12:59:44.009686	\N	\N	7	http://localhost:8088/sqllab
350	ChartDataRestApi.json_dumps	1	{"path": "/api/v1/chart/data", "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}], "slice_id": 1}, "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}], "result_format": "json", "result_type": "full"}	2026-06-28 12:59:27.59381	\N	1	0	http://localhost:8088/explore/?datasource_type=table&datasource_id=1&slice_id=1
357	ChartDataRestApi.data	1	{"path": "/api/v1/chart/data", "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}], "slice_id": 1}, "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}], "result_format": "json", "result_type": "full", "object_ref": "ChartDataRestApi.data", "is_cached": [null]}	2026-06-28 12:59:27.616598	\N	1	286	http://localhost:8088/explore/?datasource_type=table&datasource_id=1&slice_id=1
365	DatasetRestApi.info	1	{"path": "/api/v1/dataset/_info", "q": "(keys:!(permissions))", "rison": {"keys": ["permissions"]}}	2026-06-28 12:59:29.222086	\N	\N	37	http://localhost:8088/tablemodelview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
370	log	1	{"source": "explore", "source_id": 1, "slice_id": 1, "impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651573837, "event_name": "spa_navigation", "path": "/savedqueryview/list/", "event_type": "user", "event_id": "CUFrai5hGG2s2b0s1aEZQ", "visibility": "visible"}	2026-06-28 12:59:34.854372	\N	1	0	http://localhost:8088/savedqueryview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
375	log	1	{"source": "explore", "source_id": 1, "slice_id": 1, "impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651576227, "event_name": "spa_navigation", "path": "/sqllab/history/", "event_type": "user", "event_id": "ANsfBfyHyh2APaLfPFwie", "visibility": "visible"}	2026-06-28 12:59:38.043628	\N	1	0	http://localhost:8088/dashboard/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc&viewMode=table
376	log	1	{"source": "explore", "source_id": 1, "slice_id": 1, "impression_id": "RzLfIb0KwLy9eKSSTpb69", "version": "v2", "ts": 1782651577031, "event_name": "spa_navigation", "path": "/dashboard/list/", "event_type": "user", "event_id": "2fXVqeVWTpnFFwOH6X6BJ", "visibility": "visible"}	2026-06-28 12:59:38.043632	\N	1	0	http://localhost:8088/dashboard/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc&viewMode=table
380	QueryRestApi.get	1	{"path": "/api/v1/query/1", "url_rule": "/api/v1/query/<int:pk>", "rison": {}}	2026-06-28 12:59:43.860693	\N	\N	17	http://localhost:8088/sqllab?queryId=1
388	execute_sql	1	{"path": "/", "object_ref": "superset.sql_lab"}	2026-06-28 12:59:46.176677	\N	\N	5	\N
358	ChartDataRestApi.data	1	{"path": "/api/v1/chart/data", "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}], "slice_id": 1}, "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 10000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}], "result_format": "json", "result_type": "full", "object_ref": "ChartDataRestApi.data", "is_cached": [null]}	2026-06-28 12:59:27.623433	\N	1	271	http://localhost:8088/explore/?datasource_type=table&datasource_id=1&slice_id=1
366	DatasetRestApi.get_list	1	{"path": "/api/v1/dataset/", "q": "(order_column:changed_on_delta_humanized,order_direction:desc,page:0,page_size:25)", "rison": {"order_column": "changed_on_delta_humanized", "order_direction": "desc", "page": 0, "page_size": 25}}	2026-06-28 12:59:29.233038	\N	\N	35	http://localhost:8088/tablemodelview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
371	QueryRestApi.get_list	1	{"path": "/api/v1/query/", "q": "(order_column:start_time,order_direction:desc,page:0,page_size:25)", "rison": {"order_column": "start_time", "order_direction": "desc", "page": 0, "page_size": 25}}	2026-06-28 12:59:36.373144	\N	\N	54	http://localhost:8088/sqllab/history/?pageIndex=0&sortColumn=start_time&sortOrder=desc
377	QueryRestApi.get_list	1	{"path": "/api/v1/query/", "q": "(order_column:start_time,order_direction:desc,page:0,page_size:25)", "rison": {"order_column": "start_time", "order_direction": "desc", "page": 0, "page_size": 25}}	2026-06-28 12:59:39.886958	\N	\N	41	http://localhost:8088/sqllab/history/?pageIndex=0&sortColumn=start_time&sortOrder=desc
383	DatabaseRestApi.validate_sql	1	{"path": "/api/v1/database/1/validate_sql/", "schema": "public", "sql": "SELECT\\n  *\\nFROM public.ventas\\nLIMIT 100", "url_rule": "/api/v1/database/<int:pk>/validate_sql/", "object_ref": "DatabaseRestApi.validate_sql", "pk": 1}	2026-06-28 12:59:44.011195	\N	\N	11	http://localhost:8088/sqllab
389	SqlLabRestApi.get_results	1	{"path": "/api/v1/sqllab/execute/", "client_id": "4wLNvPguWM4", "database_id": 1, "runAsync": false, "schema": "public", "sql": "SELECT\\n  *\\nFROM public.ventas\\nLIMIT 100", "sql_editor_id": "e1ruoVCft_R", "tab": "Copy of Query public.ventas", "tmp_table_name": "", "select_as_cta": false, "ctas_method": "TABLE", "queryLimit": 1000, "expand_data": true, "object_ref": "SqlLabRestApi.execute_sql_query"}	2026-06-28 12:59:46.199808	\N	\N	94	http://localhost:8088/sqllab
362	ChartDataRestApi.data	1	{"path": "/api/v1/chart/data", "form_data": {"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 1000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}], "slice_id": 1}, "datasource": {"id": 1, "type": "table"}, "force": false, "queries": [{"filters": [{"col": "fecha", "op": "TEMPORAL_RANGE", "val": "No filter"}], "extras": {"having": "", "where": ""}, "applied_time_extras": {}, "columns": ["producto", "precio", "cantidad"], "annotation_layers": [], "row_limit": 1000, "series_limit": 0, "group_others_when_limit_reached": false, "order_desc": true, "url_params": {"datasource_id": "1", "datasource_type": "table", "slice_id": "1"}, "custom_params": {}, "custom_form_data": {}, "post_processing": [{"operation": "histogram", "options": {"column": "cantidad", "groupby": ["producto", "precio"], "bins": 5, "cumulative": false, "normalize": false}}]}], "result_format": "json", "result_type": "results", "object_ref": "ChartDataRestApi.data", "is_cached": [null]}	2026-06-28 12:59:27.646795	\N	1	249	http://localhost:8088/explore/?datasource_type=table&datasource_id=1&slice_id=1
369	SavedQueryRestApi.get_list	1	{"path": "/api/v1/saved_query/", "q": "(order_column:changed_on_delta_humanized,order_direction:desc,page:0,page_size:25)", "rison": {"order_column": "changed_on_delta_humanized", "order_direction": "desc", "page": 0, "page_size": 25}}	2026-06-28 12:59:34.023225	\N	\N	52	http://localhost:8088/savedqueryview/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc
374	DashboardRestApi.get_list	1	{"path": "/api/v1/dashboard/", "q": "(order_column:changed_on_delta_humanized,order_direction:desc,page:0,page_size:25,select_columns:!(id,dashboard_title,published,url,slug,changed_by,changed_by.id,changed_by.first_name,changed_by.last_name,changed_on_delta_humanized,owners,owners.id,owners.first_name,owners.last_name,tags.id,tags.name,tags.type,status,certified_by,certification_details,changed_on))", "object_ref": "DashboardRestApi.get_list"}	2026-06-28 12:59:37.140062	\N	\N	52	http://localhost:8088/dashboard/list/?pageIndex=0&sortColumn=changed_on_delta_humanized&sortOrder=desc&viewMode=table
381	DatabaseRestApi.schemas	1	{"path": "/api/v1/database/1/schemas/", "q": "(force:!f)", "url_rule": "/api/v1/database/<int:pk>/schemas/", "object_ref": "DatabaseRestApi.schemas", "pk": 1, "rison": {"force": false}}	2026-06-28 12:59:43.877881	\N	\N	40	http://localhost:8088/sqllab?queryId=1
\.


--
-- Data for Name: query; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.query (id, client_id, database_id, tmp_table_name, tab_name, sql_editor_id, user_id, status, schema, sql, select_sql, executed_sql, "limit", select_as_cta, select_as_cta_used, progress, rows, error_message, start_time, changed_on, end_time, results_key, start_running_time, end_result_backend_time, tracking_url, extra_json, tmp_schema_name, ctas_method, limiting_factor, catalog) FROM stdin;
1	5isLAsg48yA	1	\N	Query public.ventas	HSbLp_Hb1ic	1	success	public	SELECT\n  *\nFROM public.ventas\nLIMIT 100	\N	SELECT\n  *\nFROM public.ventas\nLIMIT 101	100	f	f	100	10	\N	1782651253577.844000	2026-06-28 12:54:13.687294	1782651253677.912800	\N	1782651253616.852000	\N	\N	{"cancel_query": 1973, "progress": null, "columns": [{"column_name": "id", "name": "id", "type": "INTEGER", "type_generic": 0, "is_dttm": false}, {"column_name": "fecha", "name": "fecha", "type": "DATE", "type_generic": 2, "is_dttm": true}, {"column_name": "producto", "name": "producto", "type": "STRING", "type_generic": 1, "is_dttm": false}, {"column_name": "categoria", "name": "categoria", "type": "STRING", "type_generic": 1, "is_dttm": false}, {"column_name": "cantidad", "name": "cantidad", "type": "INTEGER", "type_generic": 0, "is_dttm": false}, {"column_name": "precio", "name": "precio", "type": "DECIMAL", "type_generic": 0, "is_dttm": false}, {"column_name": "region", "name": "region", "type": "STRING", "type_generic": 1, "is_dttm": false}]}	\N	TABLE	NOT_LIMITED	analytics
2	4wLNvPguWM4	1	\N	Copy of Query public.ventas	e1ruoVCft_R	1	success	public	SELECT\n  *\nFROM public.ventas\nLIMIT 100	\N	SELECT\n  *\nFROM public.ventas\nLIMIT 101	100	f	f	100	10	\N	1782651586109.903000	2026-06-28 12:59:46.188712	1782651586183.479000	\N	1782651586129.501200	\N	\N	{"cancel_query": 2288, "progress": null, "columns": [{"column_name": "id", "name": "id", "type": "INTEGER", "type_generic": 0, "is_dttm": false}, {"column_name": "fecha", "name": "fecha", "type": "DATE", "type_generic": 2, "is_dttm": true}, {"column_name": "producto", "name": "producto", "type": "STRING", "type_generic": 1, "is_dttm": false}, {"column_name": "categoria", "name": "categoria", "type": "STRING", "type_generic": 1, "is_dttm": false}, {"column_name": "cantidad", "name": "cantidad", "type": "INTEGER", "type_generic": 0, "is_dttm": false}, {"column_name": "precio", "name": "precio", "type": "DECIMAL", "type_generic": 0, "is_dttm": false}, {"column_name": "region", "name": "region", "type": "STRING", "type_generic": 1, "is_dttm": false}]}	\N	TABLE	NOT_LIMITED	analytics
\.


--
-- Data for Name: report_execution_log; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.report_execution_log (id, scheduled_dttm, start_dttm, end_dttm, value, value_row_json, state, error_message, report_schedule_id, uuid) FROM stdin;
\.


--
-- Data for Name: report_recipient; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.report_recipient (id, type, recipient_config_json, report_schedule_id, created_on, changed_on, created_by_fk, changed_by_fk) FROM stdin;
\.


--
-- Data for Name: report_schedule; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.report_schedule (id, type, name, description, context_markdown, active, crontab, sql, chart_id, dashboard_id, database_id, last_eval_dttm, last_state, last_value, last_value_row_json, validator_type, validator_config_json, log_retention, grace_period, created_on, changed_on, created_by_fk, changed_by_fk, working_timeout, report_format, creation_method, timezone, extra_json, force_screenshot, custom_width, custom_height, email_subject) FROM stdin;
\.


--
-- Data for Name: report_schedule_user; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.report_schedule_user (id, user_id, report_schedule_id) FROM stdin;
\.


--
-- Data for Name: rls_filter_roles; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.rls_filter_roles (id, role_id, rls_filter_id) FROM stdin;
\.


--
-- Data for Name: rls_filter_tables; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.rls_filter_tables (id, table_id, rls_filter_id) FROM stdin;
\.


--
-- Data for Name: row_level_security_filters; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.row_level_security_filters (created_on, changed_on, id, clause, created_by_fk, changed_by_fk, filter_type, group_key, name, description) FROM stdin;
\.


--
-- Data for Name: saved_query; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.saved_query (created_on, changed_on, id, user_id, db_id, label, schema, sql, description, changed_by_fk, created_by_fk, extra_json, last_run, rows, uuid, template_parameters, catalog) FROM stdin;
\.


--
-- Data for Name: slice_user; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.slice_user (id, user_id, slice_id) FROM stdin;
1	1	1
\.


--
-- Data for Name: slices; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.slices (created_on, changed_on, id, slice_name, druid_datasource_id, table_id, datasource_type, datasource_name, viz_type, params, created_by_fk, changed_by_fk, description, cache_timeout, perm, datasource_id, schema_perm, uuid, query_context, last_saved_at, last_saved_by_fk, certified_by, certification_details, is_managed_externally, external_url, catalog_perm) FROM stdin;
2026-06-28 12:59:26.746081	2026-06-28 12:59:26.746088	1	fdsf	\N	\N	table	public.ventas	histogram_v2	{"datasource":"1__table","viz_type":"histogram_v2","matrixify_enable":false,"matrixify_mode_columns":"disabled","matrixify_dimension_selection_mode_columns":"members","matrixify_dimension_columns":{"dimension":"","values":[]},"matrixify_topn_value_columns":10,"matrixify_all_sort_by_columns":"a_to_z","matrixify_topn_order_columns":true,"matrixify_show_column_headers":true,"matrixify_fit_columns_dynamically":true,"matrixify_mode_rows":"disabled","matrixify_dimension_selection_mode_rows":"members","matrixify_dimension_rows":{"dimension":"","values":[]},"matrixify_topn_value_rows":10,"matrixify_all_sort_by_rows":"a_to_z","matrixify_topn_order_rows":true,"matrixify_show_row_labels":true,"matrixify_row_height":300,"matrixify_charts_per_row":4,"matrixify_cell_title_template":"","column":"cantidad","groupby":["producto","precio"],"adhoc_filters":[{"clause":"WHERE","subject":"fecha","operator":"TEMPORAL_RANGE","comparator":"No filter","expressionType":"SIMPLE"}],"row_limit":10000,"bins":5,"normalize":false,"cumulative":false,"color_scheme":"supersetColors","show_value":false,"show_legend":true,"x_axis_title":"","x_axis_format":"SMART_NUMBER","y_axis_title":"","y_axis_format":"SMART_NUMBER","extra_form_data":{},"dashboards":[]}	1	1	\N	\N	[Analytics PostgreSQL].[ventas](id:1)	1	[Analytics PostgreSQL].[analytics].[public]	c428d6b2-a26c-4488-a376-cff6bd3ece14	{"datasource":{"id":1,"type":"table"},"force":false,"queries":[{"filters":[{"col":"fecha","op":"TEMPORAL_RANGE","val":"No filter"}],"extras":{"having":"","where":""},"applied_time_extras":{},"columns":["producto","precio","cantidad"],"annotation_layers":[],"row_limit":10000,"series_limit":0,"group_others_when_limit_reached":false,"order_desc":true,"url_params":{},"custom_params":{},"custom_form_data":{},"post_processing":[{"operation":"histogram","options":{"column":"cantidad","groupby":["producto","precio"],"bins":5,"cumulative":false,"normalize":false}}]}],"form_data":{"datasource":"1__table","viz_type":"histogram_v2","matrixify_enable":false,"matrixify_mode_columns":"disabled","matrixify_dimension_selection_mode_columns":"members","matrixify_dimension_columns":{"dimension":"","values":[]},"matrixify_topn_value_columns":10,"matrixify_all_sort_by_columns":"a_to_z","matrixify_topn_order_columns":true,"matrixify_show_column_headers":true,"matrixify_fit_columns_dynamically":true,"matrixify_mode_rows":"disabled","matrixify_dimension_selection_mode_rows":"members","matrixify_dimension_rows":{"dimension":"","values":[]},"matrixify_topn_value_rows":10,"matrixify_all_sort_by_rows":"a_to_z","matrixify_topn_order_rows":true,"matrixify_show_row_labels":true,"matrixify_row_height":300,"matrixify_charts_per_row":4,"matrixify_cell_title_template":"","column":"cantidad","groupby":["producto","precio"],"adhoc_filters":[{"clause":"WHERE","subject":"fecha","operator":"TEMPORAL_RANGE","comparator":"No filter","expressionType":"SIMPLE"}],"row_limit":10000,"bins":5,"normalize":false,"cumulative":false,"color_scheme":"supersetColors","show_value":false,"show_legend":true,"x_axis_title":"","x_axis_format":"SMART_NUMBER","y_axis_title":"","y_axis_format":"SMART_NUMBER","extra_form_data":{},"dashboards":[],"force":false,"result_format":"json","result_type":"full"},"result_format":"json","result_type":"full"}	2026-06-28 12:59:26.740038	1	\N	\N	f	\N	[Analytics PostgreSQL].[analytics]
\.


--
-- Data for Name: sql_metrics; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.sql_metrics (created_on, changed_on, id, metric_name, verbose_name, metric_type, table_id, expression, description, created_by_fk, changed_by_fk, d3format, warning_text, extra, uuid, currency) FROM stdin;
2026-06-28 12:55:43.002849	2026-06-28 12:55:43.002855	2	suma	SUM(precio * cantidad)	\N	1		\N	1	1	\N	\N	{"warning_markdown":""}	83da04da-f8b4-479c-bb0f-17e206e63ed9	null
\.


--
-- Data for Name: sqlatable_user; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.sqlatable_user (id, user_id, table_id) FROM stdin;
1	1	1
\.


--
-- Data for Name: ssh_tunnels; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.ssh_tunnels (created_on, changed_on, created_by_fk, changed_by_fk, extra_json, uuid, id, database_id, server_address, server_port, username, password, private_key, private_key_password) FROM stdin;
\.


--
-- Data for Name: tab_state; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.tab_state (created_on, changed_on, extra_json, id, user_id, label, active, database_id, schema, sql, query_limit, latest_query_id, autorun, template_params, created_by_fk, changed_by_fk, hide_left_bar, saved_query_id, catalog) FROM stdin;
2026-06-28 12:59:48.824088	2026-06-28 12:59:59.656527	{}	1	1	Query public.ventas	f	1	public	SELECT\n  *\nFROM public.ventas\nLIMIT 100	\N	\N	f	\N	1	1	f	\N	\N
2026-06-28 12:59:54.65612	2026-06-28 12:59:59.656527	{}	2	1	Copy of Query public.ventas	t	1	public	SELECT\n  *\nFROM public.ventas\nLIMIT 100	\N	\N	f	\N	1	1	f	\N	\N
\.


--
-- Data for Name: table_columns; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.table_columns (created_on, changed_on, id, table_id, column_name, is_dttm, is_active, type, groupby, filterable, description, created_by_fk, changed_by_fk, expression, verbose_name, python_date_format, uuid, extra, advanced_data_type, datetime_format) FROM stdin;
2026-06-28 12:55:42.998513	2026-06-28 12:55:43.092359	1	1	id	f	t	INTEGER	t	t	\N	1	1		\N	\N	e27e19d6-27ea-4ed9-b4ad-c54271933f96	{}	\N	\N
2026-06-28 12:55:42.998589	2026-06-28 12:55:43.092399	2	1	fecha	t	t	DATE	t	t	\N	1	1		\N	\N	792a11ad-38c2-4cc7-a339-0079ca65752d	{}	\N	\N
2026-06-28 12:55:42.998619	2026-06-28 12:55:43.092408	3	1	producto	f	t	VARCHAR(100)	t	t	\N	1	1		\N	\N	bf113e0d-566d-4968-bd7c-3628c6abcad1	{}	\N	\N
2026-06-28 12:55:42.998648	2026-06-28 12:55:43.092416	4	1	categoria	f	t	VARCHAR(50)	t	t	\N	1	1		\N	\N	7337d995-bf57-4c6c-9572-87876ef215c9	{}	\N	\N
2026-06-28 12:55:42.998677	2026-06-28 12:55:43.092423	5	1	cantidad	f	t	INTEGER	t	t	\N	1	1		\N	\N	697eec5b-f3ae-4d47-a608-9e2386e896c6	{}	\N	\N
2026-06-28 12:55:42.998705	2026-06-28 12:55:43.09243	6	1	precio	f	t	NUMERIC(10, 2)	t	t	\N	1	1		\N	\N	fa9730f9-cbc0-4fa5-9cc9-5450ce5d1e09	{}	\N	\N
2026-06-28 12:55:42.998735	2026-06-28 12:55:43.092437	7	1	region	f	t	VARCHAR(50)	t	t	\N	1	1		\N	\N	74f52944-8b51-49b1-86f2-02ba5833b7dc	{}	\N	\N
\.


--
-- Data for Name: table_schema; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.table_schema (created_on, changed_on, extra_json, id, tab_state_id, database_id, schema, "table", description, expanded, created_by_fk, changed_by_fk, catalog) FROM stdin;
\.


--
-- Data for Name: tables; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.tables (created_on, changed_on, id, table_name, main_dttm_col, default_endpoint, database_id, created_by_fk, changed_by_fk, "offset", description, is_featured, cache_timeout, schema, sql, params, perm, filter_select_enabled, fetch_values_predicate, is_sqllab_view, template_params, schema_perm, extra, uuid, is_managed_externally, external_url, normalize_columns, always_filter_main_dttm, catalog, catalog_perm, folders, currency_code_column) FROM stdin;
2026-06-28 12:50:22.550801	2026-06-28 12:56:17.091314	1	ventas	fecha	\N	1	1	1	0	\N	f	\N	public		\N	[Analytics PostgreSQL].[ventas](id:1)	t	\N	f	\N	[Analytics PostgreSQL].[analytics].[public]	\N	e5c8f275-362e-4aff-a9e1-91ea126fc9ae	f	\N	f	f	analytics	[Analytics PostgreSQL].[analytics]	\N	\N
\.


--
-- Data for Name: tag; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.tag (created_on, changed_on, id, name, type, created_by_fk, changed_by_fk, description) FROM stdin;
\.


--
-- Data for Name: tagged_object; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.tagged_object (created_on, changed_on, id, tag_id, object_id, object_type, created_by_fk, changed_by_fk) FROM stdin;
\.


--
-- Data for Name: task_subscribers; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.task_subscribers (id, task_id, user_id, subscribed_at, created_on, created_by_fk, changed_on, changed_by_fk) FROM stdin;
\.


--
-- Data for Name: tasks; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.tasks (id, uuid, task_key, task_type, task_name, scope, status, dedup_key, created_on, changed_on, created_by_fk, changed_by_fk, started_at, ended_at, user_id, payload, properties) FROM stdin;
\.


--
-- Data for Name: themes; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.themes (uuid, created_on, changed_on, id, theme_name, json_data, is_system, created_by_fk, changed_by_fk, is_system_default, is_system_dark) FROM stdin;
cefef61b-9012-4577-abee-f9855414c844	2026-06-28 12:19:41.753296	2026-06-28 12:19:41.7533	1	THEME_DEFAULT	{"token": {"brandAppName": "Superset", "brandLogoAlt": "Apache Superset", "brandLogoUrl": "/static/assets/images/superset-logo-horiz.png", "brandLogoMargin": "18px 0", "brandLogoHref": "/", "brandLogoHeight": "24px", "brandSpinnerUrl": null, "brandSpinnerSvg": null, "colorPrimary": "#2893B3", "colorLink": "#2893B3", "colorError": "#e04355", "colorWarning": "#fcc700", "colorSuccess": "#5ac189", "colorInfo": "#66bcfe", "fontUrls": [], "fontFamily": "Inter, Helvetica, Arial, sans-serif", "fontFamilyCode": "'IBM Plex Mono', 'Courier New', monospace", "transitionTiming": 0.3, "brandIconMaxWidth": 37, "fontSizeXS": "8", "fontSizeXXL": "28", "fontWeightNormal": "400", "fontWeightLight": "300", "fontWeightStrong": "500", "fontWeightBold": "700", "colorEditorSelection": "#fff5cf"}, "algorithm": "default"}	t	\N	\N	f	f
ebc6d8fa-2edf-47f5-9e92-99b6f8590096	2026-06-28 12:19:41.759571	2026-06-28 12:19:41.759573	2	THEME_DARK	{"token": {"brandAppName": "Superset", "brandLogoAlt": "Apache Superset", "brandLogoUrl": "/static/assets/images/superset-logo-horiz.png", "brandLogoMargin": "18px 0", "brandLogoHref": "/", "brandLogoHeight": "24px", "brandSpinnerUrl": null, "brandSpinnerSvg": null, "colorPrimary": "#2893B3", "colorLink": "#2893B3", "colorError": "#e04355", "colorWarning": "#fcc700", "colorSuccess": "#5ac189", "colorInfo": "#66bcfe", "fontUrls": [], "fontFamily": "Inter, Helvetica, Arial, sans-serif", "fontFamilyCode": "'IBM Plex Mono', 'Courier New', monospace", "transitionTiming": 0.3, "brandIconMaxWidth": 37, "fontSizeXS": "8", "fontSizeXXL": "28", "fontWeightNormal": "400", "fontWeightLight": "300", "fontWeightStrong": "500", "fontWeightBold": "700", "colorEditorSelection": "#5c4d1a"}, "algorithm": "dark"}	t	\N	\N	f	f
\.


--
-- Data for Name: user_attribute; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.user_attribute (created_on, changed_on, id, user_id, welcome_dashboard_id, created_by_fk, changed_by_fk, avatar_url) FROM stdin;
\.


--
-- Data for Name: user_favorite_tag; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.user_favorite_tag (user_id, tag_id) FROM stdin;
\.


--
-- Data for Name: ventas; Type: TABLE DATA; Schema: public; Owner: analytics
--

COPY public.ventas (id, fecha, producto, categoria, cantidad, precio, region) FROM stdin;
1	2025-01-15	Laptop Pro	Electrónica	5	1200.00	Norte
2	2025-01-20	Teclado USB	Periféricos	20	45.00	Sur
3	2025-02-03	Monitor 27"	Electrónica	8	350.00	Este
4	2025-02-14	Ratón Inalámbrico	Periféricos	15	29.99	Norte
5	2025-03-01	Laptop Pro	Electrónica	3	1200.00	Oeste
6	2025-03-10	Auriculares BT	Audio	12	89.99	Sur
7	2025-04-05	Webcam HD	Periféricos	18	65.00	Este
8	2025-04-22	Monitor 27"	Electrónica	4	350.00	Norte
9	2025-05-11	Teclado USB	Periféricos	25	45.00	Oeste
10	2025-05-30	Auriculares BT	Audio	9	89.99	Norte
\.


--
-- Name: ab_group_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.ab_group_id_seq', 1, false);


--
-- Name: ab_group_role_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.ab_group_role_id_seq', 1, false);


--
-- Name: ab_permission_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.ab_permission_id_seq', 92, true);


--
-- Name: ab_permission_view_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.ab_permission_view_id_seq', 239, true);


--
-- Name: ab_permission_view_role_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.ab_permission_view_role_id_seq', 468, true);


--
-- Name: ab_register_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.ab_register_user_id_seq', 1, false);


--
-- Name: ab_role_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.ab_role_id_seq', 5, true);


--
-- Name: ab_user_group_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.ab_user_group_id_seq', 1, false);


--
-- Name: ab_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.ab_user_id_seq', 2, true);


--
-- Name: ab_user_role_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.ab_user_role_id_seq', 2, true);


--
-- Name: ab_view_menu_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.ab_view_menu_id_seq', 102, true);


--
-- Name: annotation_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.annotation_id_seq', 1, false);


--
-- Name: annotation_layer_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.annotation_layer_id_seq', 1, false);


--
-- Name: cache_keys_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.cache_keys_id_seq', 1, false);


--
-- Name: clientes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.clientes_id_seq', 5, true);


--
-- Name: css_templates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.css_templates_id_seq', 1, false);


--
-- Name: dashboard_roles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.dashboard_roles_id_seq', 1, false);


--
-- Name: dashboard_slices_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.dashboard_slices_id_seq', 1, false);


--
-- Name: dashboard_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.dashboard_user_id_seq', 1, false);


--
-- Name: dashboards_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.dashboards_id_seq', 1, false);


--
-- Name: database_user_oauth2_tokens_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.database_user_oauth2_tokens_id_seq', 1, false);


--
-- Name: dbs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.dbs_id_seq', 2, true);


--
-- Name: dynamic_plugin_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.dynamic_plugin_id_seq', 1, false);


--
-- Name: favstar_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.favstar_id_seq', 1, false);


--
-- Name: key_value_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.key_value_id_seq', 2, true);


--
-- Name: keyvalue_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.keyvalue_id_seq', 1, false);


--
-- Name: logs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.logs_id_seq', 390, true);


--
-- Name: query_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.query_id_seq', 2, true);


--
-- Name: report_execution_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.report_execution_log_id_seq', 1, false);


--
-- Name: report_recipient_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.report_recipient_id_seq', 1, false);


--
-- Name: report_schedule_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.report_schedule_id_seq', 1, false);


--
-- Name: report_schedule_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.report_schedule_user_id_seq', 1, false);


--
-- Name: rls_filter_roles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.rls_filter_roles_id_seq', 1, false);


--
-- Name: rls_filter_tables_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.rls_filter_tables_id_seq', 1, false);


--
-- Name: row_level_security_filters_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.row_level_security_filters_id_seq', 1, false);


--
-- Name: saved_query_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.saved_query_id_seq', 1, false);


--
-- Name: slice_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.slice_user_id_seq', 1, true);


--
-- Name: slices_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.slices_id_seq', 1, true);


--
-- Name: sql_metrics_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.sql_metrics_id_seq', 3, true);


--
-- Name: sqlatable_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.sqlatable_user_id_seq', 1, true);


--
-- Name: ssh_tunnels_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.ssh_tunnels_id_seq', 1, false);


--
-- Name: tab_state_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.tab_state_id_seq', 2, true);


--
-- Name: table_columns_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.table_columns_id_seq', 7, true);


--
-- Name: table_schema_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.table_schema_id_seq', 1, false);


--
-- Name: tables_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.tables_id_seq', 1, true);


--
-- Name: tag_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.tag_id_seq', 1, false);


--
-- Name: tagged_object_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.tagged_object_id_seq', 1, false);


--
-- Name: task_subscribers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.task_subscribers_id_seq', 1, false);


--
-- Name: tasks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.tasks_id_seq', 1, false);


--
-- Name: themes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.themes_id_seq', 2, true);


--
-- Name: user_attribute_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.user_attribute_id_seq', 1, false);


--
-- Name: ventas_id_seq; Type: SEQUENCE SET; Schema: public; Owner: analytics
--

SELECT pg_catalog.setval('public.ventas_id_seq', 10, true);


--
-- Name: tables _customer_location_uc; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.tables
    ADD CONSTRAINT _customer_location_uc UNIQUE (database_id, schema, table_name);


--
-- Name: ab_group ab_group_name_key; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.ab_group
    ADD CONSTRAINT ab_group_name_key UNIQUE (name);


--
-- Name: ab_group ab_group_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.ab_group
    ADD CONSTRAINT ab_group_pkey PRIMARY KEY (id);


--
-- Name: ab_group_role ab_group_role_group_id_role_id_key; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.ab_group_role
    ADD CONSTRAINT ab_group_role_group_id_role_id_key UNIQUE (group_id, role_id);


--
-- Name: ab_group_role ab_group_role_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.ab_group_role
    ADD CONSTRAINT ab_group_role_pkey PRIMARY KEY (id);


--
-- Name: ab_permission ab_permission_name_key; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.ab_permission
    ADD CONSTRAINT ab_permission_name_key UNIQUE (name);


--
-- Name: ab_permission ab_permission_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.ab_permission
    ADD CONSTRAINT ab_permission_pkey PRIMARY KEY (id);


--
-- Name: ab_permission_view ab_permission_view_permission_id_view_menu_id_key; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.ab_permission_view
    ADD CONSTRAINT ab_permission_view_permission_id_view_menu_id_key UNIQUE (permission_id, view_menu_id);


--
-- Name: ab_permission_view ab_permission_view_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.ab_permission_view
    ADD CONSTRAINT ab_permission_view_pkey PRIMARY KEY (id);


--
-- Name: ab_permission_view_role ab_permission_view_role_permission_view_id_role_id_key; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.ab_permission_view_role
    ADD CONSTRAINT ab_permission_view_role_permission_view_id_role_id_key UNIQUE (permission_view_id, role_id);


--
-- Name: ab_permission_view_role ab_permission_view_role_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.ab_permission_view_role
    ADD CONSTRAINT ab_permission_view_role_pkey PRIMARY KEY (id);


--
-- Name: ab_register_user ab_register_user_email_key; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.ab_register_user
    ADD CONSTRAINT ab_register_user_email_key UNIQUE (email);


--
-- Name: ab_register_user ab_register_user_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.ab_register_user
    ADD CONSTRAINT ab_register_user_pkey PRIMARY KEY (id);


--
-- Name: ab_register_user ab_register_user_username_key; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.ab_register_user
    ADD CONSTRAINT ab_register_user_username_key UNIQUE (username);


--
-- Name: ab_role ab_role_name_key; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.ab_role
    ADD CONSTRAINT ab_role_name_key UNIQUE (name);


--
-- Name: ab_role ab_role_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.ab_role
    ADD CONSTRAINT ab_role_pkey PRIMARY KEY (id);


--
-- Name: ab_user ab_user_email_key; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.ab_user
    ADD CONSTRAINT ab_user_email_key UNIQUE (email);


--
-- Name: ab_user_group ab_user_group_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.ab_user_group
    ADD CONSTRAINT ab_user_group_pkey PRIMARY KEY (id);


--
-- Name: ab_user_group ab_user_group_user_id_group_id_key; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.ab_user_group
    ADD CONSTRAINT ab_user_group_user_id_group_id_key UNIQUE (user_id, group_id);


--
-- Name: ab_user ab_user_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.ab_user
    ADD CONSTRAINT ab_user_pkey PRIMARY KEY (id);


--
-- Name: ab_user_role ab_user_role_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.ab_user_role
    ADD CONSTRAINT ab_user_role_pkey PRIMARY KEY (id);


--
-- Name: ab_user_role ab_user_role_user_id_role_id_key; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.ab_user_role
    ADD CONSTRAINT ab_user_role_user_id_role_id_key UNIQUE (user_id, role_id);


--
-- Name: ab_user ab_user_username_key; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.ab_user
    ADD CONSTRAINT ab_user_username_key UNIQUE (username);


--
-- Name: ab_view_menu ab_view_menu_name_key; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.ab_view_menu
    ADD CONSTRAINT ab_view_menu_name_key UNIQUE (name);


--
-- Name: ab_view_menu ab_view_menu_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.ab_view_menu
    ADD CONSTRAINT ab_view_menu_pkey PRIMARY KEY (id);


--
-- Name: alembic_version alembic_version_pkc; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.alembic_version
    ADD CONSTRAINT alembic_version_pkc PRIMARY KEY (version_num);


--
-- Name: annotation_layer annotation_layer_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.annotation_layer
    ADD CONSTRAINT annotation_layer_pkey PRIMARY KEY (id);


--
-- Name: annotation annotation_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.annotation
    ADD CONSTRAINT annotation_pkey PRIMARY KEY (id);


--
-- Name: cache_keys cache_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.cache_keys
    ADD CONSTRAINT cache_keys_pkey PRIMARY KEY (id);


--
-- Name: query client_id; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.query
    ADD CONSTRAINT client_id UNIQUE (client_id);


--
-- Name: clientes clientes_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.clientes
    ADD CONSTRAINT clientes_pkey PRIMARY KEY (id);


--
-- Name: css_templates css_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.css_templates
    ADD CONSTRAINT css_templates_pkey PRIMARY KEY (id);


--
-- Name: dashboard_roles dashboard_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.dashboard_roles
    ADD CONSTRAINT dashboard_roles_pkey PRIMARY KEY (id);


--
-- Name: dashboard_slices dashboard_slices_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.dashboard_slices
    ADD CONSTRAINT dashboard_slices_pkey PRIMARY KEY (id);


--
-- Name: dashboard_user dashboard_user_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.dashboard_user
    ADD CONSTRAINT dashboard_user_pkey PRIMARY KEY (id);


--
-- Name: dashboards dashboards_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.dashboards
    ADD CONSTRAINT dashboards_pkey PRIMARY KEY (id);


--
-- Name: database_user_oauth2_tokens database_user_oauth2_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.database_user_oauth2_tokens
    ADD CONSTRAINT database_user_oauth2_tokens_pkey PRIMARY KEY (id);


--
-- Name: dbs dbs_database_name_key; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.dbs
    ADD CONSTRAINT dbs_database_name_key UNIQUE (database_name);


--
-- Name: dbs dbs_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.dbs
    ADD CONSTRAINT dbs_pkey PRIMARY KEY (id);


--
-- Name: dbs dbs_verbose_name_key; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.dbs
    ADD CONSTRAINT dbs_verbose_name_key UNIQUE (verbose_name);


--
-- Name: dynamic_plugin dynamic_plugin_key_key; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.dynamic_plugin
    ADD CONSTRAINT dynamic_plugin_key_key UNIQUE (key);


--
-- Name: dynamic_plugin dynamic_plugin_name_key; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.dynamic_plugin
    ADD CONSTRAINT dynamic_plugin_name_key UNIQUE (name);


--
-- Name: dynamic_plugin dynamic_plugin_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.dynamic_plugin
    ADD CONSTRAINT dynamic_plugin_pkey PRIMARY KEY (id);


--
-- Name: favstar favstar_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.favstar
    ADD CONSTRAINT favstar_pkey PRIMARY KEY (id);


--
-- Name: dashboards idx_unique_slug; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.dashboards
    ADD CONSTRAINT idx_unique_slug UNIQUE (slug);


--
-- Name: key_value key_value_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.key_value
    ADD CONSTRAINT key_value_pkey PRIMARY KEY (id);


--
-- Name: keyvalue keyvalue_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.keyvalue
    ADD CONSTRAINT keyvalue_pkey PRIMARY KEY (id);


--
-- Name: logs logs_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.logs
    ADD CONSTRAINT logs_pkey PRIMARY KEY (id);


--
-- Name: query query_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.query
    ADD CONSTRAINT query_pkey PRIMARY KEY (id);


--
-- Name: report_execution_log report_execution_log_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.report_execution_log
    ADD CONSTRAINT report_execution_log_pkey PRIMARY KEY (id);


--
-- Name: report_recipient report_recipient_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.report_recipient
    ADD CONSTRAINT report_recipient_pkey PRIMARY KEY (id);


--
-- Name: report_schedule report_schedule_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.report_schedule
    ADD CONSTRAINT report_schedule_pkey PRIMARY KEY (id);


--
-- Name: report_schedule_user report_schedule_user_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.report_schedule_user
    ADD CONSTRAINT report_schedule_user_pkey PRIMARY KEY (id);


--
-- Name: rls_filter_roles rls_filter_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.rls_filter_roles
    ADD CONSTRAINT rls_filter_roles_pkey PRIMARY KEY (id);


--
-- Name: rls_filter_tables rls_filter_tables_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.rls_filter_tables
    ADD CONSTRAINT rls_filter_tables_pkey PRIMARY KEY (id);


--
-- Name: row_level_security_filters row_level_security_filters_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.row_level_security_filters
    ADD CONSTRAINT row_level_security_filters_pkey PRIMARY KEY (id);


--
-- Name: saved_query saved_query_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.saved_query
    ADD CONSTRAINT saved_query_pkey PRIMARY KEY (id);


--
-- Name: slice_user slice_user_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.slice_user
    ADD CONSTRAINT slice_user_pkey PRIMARY KEY (id);


--
-- Name: slices slices_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.slices
    ADD CONSTRAINT slices_pkey PRIMARY KEY (id);


--
-- Name: sql_metrics sql_metrics_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.sql_metrics
    ADD CONSTRAINT sql_metrics_pkey PRIMARY KEY (id);


--
-- Name: sqlatable_user sqlatable_user_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.sqlatable_user
    ADD CONSTRAINT sqlatable_user_pkey PRIMARY KEY (id);


--
-- Name: ssh_tunnels ssh_tunnels_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.ssh_tunnels
    ADD CONSTRAINT ssh_tunnels_pkey PRIMARY KEY (id);


--
-- Name: tab_state tab_state_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.tab_state
    ADD CONSTRAINT tab_state_pkey PRIMARY KEY (id);


--
-- Name: table_columns table_columns_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.table_columns
    ADD CONSTRAINT table_columns_pkey PRIMARY KEY (id);


--
-- Name: table_schema table_schema_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.table_schema
    ADD CONSTRAINT table_schema_pkey PRIMARY KEY (id);


--
-- Name: tables tables_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.tables
    ADD CONSTRAINT tables_pkey PRIMARY KEY (id);


--
-- Name: tag tag_name_key; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.tag
    ADD CONSTRAINT tag_name_key UNIQUE (name);


--
-- Name: tag tag_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.tag
    ADD CONSTRAINT tag_pkey PRIMARY KEY (id);


--
-- Name: tagged_object tagged_object_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.tagged_object
    ADD CONSTRAINT tagged_object_pkey PRIMARY KEY (id);


--
-- Name: task_subscribers task_subscribers_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.task_subscribers
    ADD CONSTRAINT task_subscribers_pkey PRIMARY KEY (id);


--
-- Name: tasks tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_pkey PRIMARY KEY (id);


--
-- Name: tasks tasks_uuid_key; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_uuid_key UNIQUE (uuid);


--
-- Name: themes themes_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.themes
    ADD CONSTRAINT themes_pkey PRIMARY KEY (id);


--
-- Name: themes themes_uuid_key; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.themes
    ADD CONSTRAINT themes_uuid_key UNIQUE (uuid);


--
-- Name: tagged_object uix_tagged_object; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.tagged_object
    ADD CONSTRAINT uix_tagged_object UNIQUE (tag_id, object_id, object_type);


--
-- Name: dashboard_slices uq_dashboard_slice; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.dashboard_slices
    ADD CONSTRAINT uq_dashboard_slice UNIQUE (dashboard_id, slice_id);


--
-- Name: dashboards uq_dashboards_uuid; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.dashboards
    ADD CONSTRAINT uq_dashboards_uuid UNIQUE (uuid);


--
-- Name: dbs uq_dbs_uuid; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.dbs
    ADD CONSTRAINT uq_dbs_uuid UNIQUE (uuid);


--
-- Name: report_schedule uq_report_schedule_name_type; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.report_schedule
    ADD CONSTRAINT uq_report_schedule_name_type UNIQUE (name, type);


--
-- Name: row_level_security_filters uq_rls_name; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.row_level_security_filters
    ADD CONSTRAINT uq_rls_name UNIQUE (name);


--
-- Name: saved_query uq_saved_query_uuid; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.saved_query
    ADD CONSTRAINT uq_saved_query_uuid UNIQUE (uuid);


--
-- Name: slices uq_slices_uuid; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.slices
    ADD CONSTRAINT uq_slices_uuid UNIQUE (uuid);


--
-- Name: sql_metrics uq_sql_metrics_metric_name; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.sql_metrics
    ADD CONSTRAINT uq_sql_metrics_metric_name UNIQUE (metric_name, table_id);


--
-- Name: sql_metrics uq_sql_metrics_uuid; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.sql_metrics
    ADD CONSTRAINT uq_sql_metrics_uuid UNIQUE (uuid);


--
-- Name: table_columns uq_table_columns_column_name; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.table_columns
    ADD CONSTRAINT uq_table_columns_column_name UNIQUE (column_name, table_id);


--
-- Name: table_columns uq_table_columns_uuid; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.table_columns
    ADD CONSTRAINT uq_table_columns_uuid UNIQUE (uuid);


--
-- Name: tables uq_tables_uuid; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.tables
    ADD CONSTRAINT uq_tables_uuid UNIQUE (uuid);


--
-- Name: task_subscribers uq_task_subscribers_task_user; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.task_subscribers
    ADD CONSTRAINT uq_task_subscribers_task_user UNIQUE (task_id, user_id);


--
-- Name: user_attribute user_attribute_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.user_attribute
    ADD CONSTRAINT user_attribute_pkey PRIMARY KEY (id);


--
-- Name: ventas ventas_pkey; Type: CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.ventas
    ADD CONSTRAINT ventas_pkey PRIMARY KEY (id);


--
-- Name: idx_group_id; Type: INDEX; Schema: public; Owner: analytics
--

CREATE INDEX idx_group_id ON public.ab_group_role USING btree (group_id);


--
-- Name: idx_group_role_id; Type: INDEX; Schema: public; Owner: analytics
--

CREATE INDEX idx_group_role_id ON public.ab_group_role USING btree (role_id);


--
-- Name: idx_permission_id; Type: INDEX; Schema: public; Owner: analytics
--

CREATE INDEX idx_permission_id ON public.ab_permission_view USING btree (permission_id);


--
-- Name: idx_permission_view_id; Type: INDEX; Schema: public; Owner: analytics
--

CREATE INDEX idx_permission_view_id ON public.ab_permission_view_role USING btree (permission_view_id);


--
-- Name: idx_role_id; Type: INDEX; Schema: public; Owner: analytics
--

CREATE INDEX idx_role_id ON public.ab_permission_view_role USING btree (role_id);


--
-- Name: idx_task_subscribers_user_id; Type: INDEX; Schema: public; Owner: analytics
--

CREATE INDEX idx_task_subscribers_user_id ON public.task_subscribers USING btree (user_id);


--
-- Name: idx_tasks_created_by; Type: INDEX; Schema: public; Owner: analytics
--

CREATE INDEX idx_tasks_created_by ON public.tasks USING btree (created_by_fk);


--
-- Name: idx_tasks_created_on; Type: INDEX; Schema: public; Owner: analytics
--

CREATE INDEX idx_tasks_created_on ON public.tasks USING btree (created_on);


--
-- Name: idx_tasks_dedup_key; Type: INDEX; Schema: public; Owner: analytics
--

CREATE UNIQUE INDEX idx_tasks_dedup_key ON public.tasks USING btree (dedup_key);


--
-- Name: idx_tasks_ended_at; Type: INDEX; Schema: public; Owner: analytics
--

CREATE INDEX idx_tasks_ended_at ON public.tasks USING btree (ended_at);


--
-- Name: idx_tasks_scope; Type: INDEX; Schema: public; Owner: analytics
--

CREATE INDEX idx_tasks_scope ON public.tasks USING btree (scope);


--
-- Name: idx_tasks_status; Type: INDEX; Schema: public; Owner: analytics
--

CREATE INDEX idx_tasks_status ON public.tasks USING btree (status);


--
-- Name: idx_tasks_task_key; Type: INDEX; Schema: public; Owner: analytics
--

CREATE INDEX idx_tasks_task_key ON public.tasks USING btree (task_key);


--
-- Name: idx_tasks_task_type; Type: INDEX; Schema: public; Owner: analytics
--

CREATE INDEX idx_tasks_task_type ON public.tasks USING btree (task_type);


--
-- Name: idx_tasks_uuid; Type: INDEX; Schema: public; Owner: analytics
--

CREATE UNIQUE INDEX idx_tasks_uuid ON public.tasks USING btree (uuid);


--
-- Name: idx_theme_is_system_dark; Type: INDEX; Schema: public; Owner: analytics
--

CREATE INDEX idx_theme_is_system_dark ON public.themes USING btree (is_system_dark);


--
-- Name: idx_theme_is_system_default; Type: INDEX; Schema: public; Owner: analytics
--

CREATE INDEX idx_theme_is_system_default ON public.themes USING btree (is_system_default);


--
-- Name: idx_user_group_id; Type: INDEX; Schema: public; Owner: analytics
--

CREATE INDEX idx_user_group_id ON public.ab_user_group USING btree (group_id);


--
-- Name: idx_user_id; Type: INDEX; Schema: public; Owner: analytics
--

CREATE INDEX idx_user_id ON public.ab_user_group USING btree (user_id);


--
-- Name: idx_user_id_database_id; Type: INDEX; Schema: public; Owner: analytics
--

CREATE INDEX idx_user_id_database_id ON public.database_user_oauth2_tokens USING btree (user_id, database_id);


--
-- Name: idx_view_menu_id; Type: INDEX; Schema: public; Owner: analytics
--

CREATE INDEX idx_view_menu_id ON public.ab_permission_view USING btree (view_menu_id);


--
-- Name: ix_cache_keys_datasource_uid; Type: INDEX; Schema: public; Owner: analytics
--

CREATE INDEX ix_cache_keys_datasource_uid ON public.cache_keys USING btree (datasource_uid);


--
-- Name: ix_creation_method; Type: INDEX; Schema: public; Owner: analytics
--

CREATE INDEX ix_creation_method ON public.report_schedule USING btree (creation_method);


--
-- Name: ix_key_value_expires_on; Type: INDEX; Schema: public; Owner: analytics
--

CREATE INDEX ix_key_value_expires_on ON public.key_value USING btree (expires_on);


--
-- Name: ix_key_value_uuid; Type: INDEX; Schema: public; Owner: analytics
--

CREATE UNIQUE INDEX ix_key_value_uuid ON public.key_value USING btree (uuid);


--
-- Name: ix_logs_user_id_dttm; Type: INDEX; Schema: public; Owner: analytics
--

CREATE INDEX ix_logs_user_id_dttm ON public.logs USING btree (user_id, dttm);


--
-- Name: ix_query_results_key; Type: INDEX; Schema: public; Owner: analytics
--

CREATE INDEX ix_query_results_key ON public.query USING btree (results_key);


--
-- Name: ix_report_execution_log_report_schedule_id; Type: INDEX; Schema: public; Owner: analytics
--

CREATE INDEX ix_report_execution_log_report_schedule_id ON public.report_execution_log USING btree (report_schedule_id);


--
-- Name: ix_report_execution_log_start_dttm; Type: INDEX; Schema: public; Owner: analytics
--

CREATE INDEX ix_report_execution_log_start_dttm ON public.report_execution_log USING btree (start_dttm);


--
-- Name: ix_report_recipient_report_schedule_id; Type: INDEX; Schema: public; Owner: analytics
--

CREATE INDEX ix_report_recipient_report_schedule_id ON public.report_recipient USING btree (report_schedule_id);


--
-- Name: ix_report_schedule_active; Type: INDEX; Schema: public; Owner: analytics
--

CREATE INDEX ix_report_schedule_active ON public.report_schedule USING btree (active);


--
-- Name: ix_row_level_security_filters_filter_type; Type: INDEX; Schema: public; Owner: analytics
--

CREATE INDEX ix_row_level_security_filters_filter_type ON public.row_level_security_filters USING btree (filter_type);


--
-- Name: ix_sql_editor_id; Type: INDEX; Schema: public; Owner: analytics
--

CREATE INDEX ix_sql_editor_id ON public.query USING btree (sql_editor_id);


--
-- Name: ix_ssh_tunnels_database_id; Type: INDEX; Schema: public; Owner: analytics
--

CREATE UNIQUE INDEX ix_ssh_tunnels_database_id ON public.ssh_tunnels USING btree (database_id);


--
-- Name: ix_ssh_tunnels_uuid; Type: INDEX; Schema: public; Owner: analytics
--

CREATE UNIQUE INDEX ix_ssh_tunnels_uuid ON public.ssh_tunnels USING btree (uuid);


--
-- Name: ix_tab_state_id; Type: INDEX; Schema: public; Owner: analytics
--

CREATE UNIQUE INDEX ix_tab_state_id ON public.tab_state USING btree (id);


--
-- Name: ix_table_schema_id; Type: INDEX; Schema: public; Owner: analytics
--

CREATE UNIQUE INDEX ix_table_schema_id ON public.table_schema USING btree (id);


--
-- Name: ix_tagged_object_object_id; Type: INDEX; Schema: public; Owner: analytics
--

CREATE INDEX ix_tagged_object_object_id ON public.tagged_object USING btree (object_id);


--
-- Name: ti_dag_state; Type: INDEX; Schema: public; Owner: analytics
--

CREATE INDEX ti_dag_state ON public.annotation USING btree (layer_id, start_dttm, end_dttm);


--
-- Name: ti_user_id_changed_on; Type: INDEX; Schema: public; Owner: analytics
--

CREATE INDEX ti_user_id_changed_on ON public.query USING btree (user_id, changed_on);


--
-- Name: ab_group_role ab_group_role_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.ab_group_role
    ADD CONSTRAINT ab_group_role_group_id_fkey FOREIGN KEY (group_id) REFERENCES public.ab_group(id) ON DELETE CASCADE;


--
-- Name: ab_group_role ab_group_role_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.ab_group_role
    ADD CONSTRAINT ab_group_role_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.ab_role(id) ON DELETE CASCADE;


--
-- Name: ab_permission_view ab_permission_view_permission_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.ab_permission_view
    ADD CONSTRAINT ab_permission_view_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES public.ab_permission(id);


--
-- Name: ab_permission_view_role ab_permission_view_role_permission_view_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.ab_permission_view_role
    ADD CONSTRAINT ab_permission_view_role_permission_view_id_fkey FOREIGN KEY (permission_view_id) REFERENCES public.ab_permission_view(id) ON DELETE CASCADE;


--
-- Name: ab_permission_view_role ab_permission_view_role_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.ab_permission_view_role
    ADD CONSTRAINT ab_permission_view_role_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.ab_role(id) ON DELETE CASCADE;


--
-- Name: ab_permission_view ab_permission_view_view_menu_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.ab_permission_view
    ADD CONSTRAINT ab_permission_view_view_menu_id_fkey FOREIGN KEY (view_menu_id) REFERENCES public.ab_view_menu(id);


--
-- Name: ab_user ab_user_changed_by_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.ab_user
    ADD CONSTRAINT ab_user_changed_by_fk_fkey FOREIGN KEY (changed_by_fk) REFERENCES public.ab_user(id);


--
-- Name: ab_user ab_user_created_by_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.ab_user
    ADD CONSTRAINT ab_user_created_by_fk_fkey FOREIGN KEY (created_by_fk) REFERENCES public.ab_user(id);


--
-- Name: ab_user_group ab_user_group_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.ab_user_group
    ADD CONSTRAINT ab_user_group_group_id_fkey FOREIGN KEY (group_id) REFERENCES public.ab_group(id) ON DELETE CASCADE;


--
-- Name: ab_user_group ab_user_group_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.ab_user_group
    ADD CONSTRAINT ab_user_group_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.ab_user(id) ON DELETE CASCADE;


--
-- Name: ab_user_role ab_user_role_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.ab_user_role
    ADD CONSTRAINT ab_user_role_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.ab_role(id) ON DELETE CASCADE;


--
-- Name: ab_user_role ab_user_role_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.ab_user_role
    ADD CONSTRAINT ab_user_role_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.ab_user(id) ON DELETE CASCADE;


--
-- Name: annotation annotation_changed_by_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.annotation
    ADD CONSTRAINT annotation_changed_by_fk_fkey FOREIGN KEY (changed_by_fk) REFERENCES public.ab_user(id);


--
-- Name: annotation annotation_created_by_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.annotation
    ADD CONSTRAINT annotation_created_by_fk_fkey FOREIGN KEY (created_by_fk) REFERENCES public.ab_user(id);


--
-- Name: annotation_layer annotation_layer_changed_by_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.annotation_layer
    ADD CONSTRAINT annotation_layer_changed_by_fk_fkey FOREIGN KEY (changed_by_fk) REFERENCES public.ab_user(id);


--
-- Name: annotation_layer annotation_layer_created_by_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.annotation_layer
    ADD CONSTRAINT annotation_layer_created_by_fk_fkey FOREIGN KEY (created_by_fk) REFERENCES public.ab_user(id);


--
-- Name: annotation annotation_layer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.annotation
    ADD CONSTRAINT annotation_layer_id_fkey FOREIGN KEY (layer_id) REFERENCES public.annotation_layer(id);


--
-- Name: css_templates css_templates_changed_by_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.css_templates
    ADD CONSTRAINT css_templates_changed_by_fk_fkey FOREIGN KEY (changed_by_fk) REFERENCES public.ab_user(id);


--
-- Name: css_templates css_templates_created_by_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.css_templates
    ADD CONSTRAINT css_templates_created_by_fk_fkey FOREIGN KEY (created_by_fk) REFERENCES public.ab_user(id);


--
-- Name: dashboards dashboards_changed_by_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.dashboards
    ADD CONSTRAINT dashboards_changed_by_fk_fkey FOREIGN KEY (changed_by_fk) REFERENCES public.ab_user(id);


--
-- Name: dashboards dashboards_created_by_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.dashboards
    ADD CONSTRAINT dashboards_created_by_fk_fkey FOREIGN KEY (created_by_fk) REFERENCES public.ab_user(id);


--
-- Name: database_user_oauth2_tokens database_user_oauth2_tokens_changed_by_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.database_user_oauth2_tokens
    ADD CONSTRAINT database_user_oauth2_tokens_changed_by_fk_fkey FOREIGN KEY (changed_by_fk) REFERENCES public.ab_user(id);


--
-- Name: database_user_oauth2_tokens database_user_oauth2_tokens_created_by_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.database_user_oauth2_tokens
    ADD CONSTRAINT database_user_oauth2_tokens_created_by_fk_fkey FOREIGN KEY (created_by_fk) REFERENCES public.ab_user(id);


--
-- Name: database_user_oauth2_tokens database_user_oauth2_tokens_database_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.database_user_oauth2_tokens
    ADD CONSTRAINT database_user_oauth2_tokens_database_id_fkey FOREIGN KEY (database_id) REFERENCES public.dbs(id) ON DELETE CASCADE;


--
-- Name: database_user_oauth2_tokens database_user_oauth2_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.database_user_oauth2_tokens
    ADD CONSTRAINT database_user_oauth2_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.ab_user(id) ON DELETE CASCADE;


--
-- Name: dbs dbs_changed_by_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.dbs
    ADD CONSTRAINT dbs_changed_by_fk_fkey FOREIGN KEY (changed_by_fk) REFERENCES public.ab_user(id);


--
-- Name: dbs dbs_created_by_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.dbs
    ADD CONSTRAINT dbs_created_by_fk_fkey FOREIGN KEY (created_by_fk) REFERENCES public.ab_user(id);


--
-- Name: dynamic_plugin dynamic_plugin_changed_by_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.dynamic_plugin
    ADD CONSTRAINT dynamic_plugin_changed_by_fk_fkey FOREIGN KEY (changed_by_fk) REFERENCES public.ab_user(id);


--
-- Name: dynamic_plugin dynamic_plugin_created_by_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.dynamic_plugin
    ADD CONSTRAINT dynamic_plugin_created_by_fk_fkey FOREIGN KEY (created_by_fk) REFERENCES public.ab_user(id);


--
-- Name: favstar favstar_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.favstar
    ADD CONSTRAINT favstar_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.ab_user(id);


--
-- Name: dashboard_roles fk_dashboard_roles_dashboard_id_dashboards; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.dashboard_roles
    ADD CONSTRAINT fk_dashboard_roles_dashboard_id_dashboards FOREIGN KEY (dashboard_id) REFERENCES public.dashboards(id) ON DELETE CASCADE;


--
-- Name: dashboard_roles fk_dashboard_roles_role_id_ab_role; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.dashboard_roles
    ADD CONSTRAINT fk_dashboard_roles_role_id_ab_role FOREIGN KEY (role_id) REFERENCES public.ab_role(id) ON DELETE CASCADE;


--
-- Name: dashboard_slices fk_dashboard_slices_dashboard_id_dashboards; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.dashboard_slices
    ADD CONSTRAINT fk_dashboard_slices_dashboard_id_dashboards FOREIGN KEY (dashboard_id) REFERENCES public.dashboards(id) ON DELETE CASCADE;


--
-- Name: dashboard_slices fk_dashboard_slices_slice_id_slices; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.dashboard_slices
    ADD CONSTRAINT fk_dashboard_slices_slice_id_slices FOREIGN KEY (slice_id) REFERENCES public.slices(id) ON DELETE CASCADE;


--
-- Name: dashboard_user fk_dashboard_user_dashboard_id_dashboards; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.dashboard_user
    ADD CONSTRAINT fk_dashboard_user_dashboard_id_dashboards FOREIGN KEY (dashboard_id) REFERENCES public.dashboards(id) ON DELETE CASCADE;


--
-- Name: dashboard_user fk_dashboard_user_user_id_ab_user; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.dashboard_user
    ADD CONSTRAINT fk_dashboard_user_user_id_ab_user FOREIGN KEY (user_id) REFERENCES public.ab_user(id) ON DELETE CASCADE;


--
-- Name: dashboards fk_dashboards_theme_id_themes; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.dashboards
    ADD CONSTRAINT fk_dashboards_theme_id_themes FOREIGN KEY (theme_id) REFERENCES public.themes(id);


--
-- Name: embedded_dashboards fk_embedded_dashboards_dashboard_id_dashboards; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.embedded_dashboards
    ADD CONSTRAINT fk_embedded_dashboards_dashboard_id_dashboards FOREIGN KEY (dashboard_id) REFERENCES public.dashboards(id) ON DELETE CASCADE;


--
-- Name: report_schedule_user fk_report_schedule_user_report_schedule_id_report_schedule; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.report_schedule_user
    ADD CONSTRAINT fk_report_schedule_user_report_schedule_id_report_schedule FOREIGN KEY (report_schedule_id) REFERENCES public.report_schedule(id) ON DELETE CASCADE;


--
-- Name: report_schedule_user fk_report_schedule_user_user_id_ab_user; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.report_schedule_user
    ADD CONSTRAINT fk_report_schedule_user_user_id_ab_user FOREIGN KEY (user_id) REFERENCES public.ab_user(id) ON DELETE CASCADE;


--
-- Name: slice_user fk_slice_user_slice_id_slices; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.slice_user
    ADD CONSTRAINT fk_slice_user_slice_id_slices FOREIGN KEY (slice_id) REFERENCES public.slices(id) ON DELETE CASCADE;


--
-- Name: slice_user fk_slice_user_user_id_ab_user; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.slice_user
    ADD CONSTRAINT fk_slice_user_user_id_ab_user FOREIGN KEY (user_id) REFERENCES public.ab_user(id) ON DELETE CASCADE;


--
-- Name: sql_metrics fk_sql_metrics_table_id_tables; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.sql_metrics
    ADD CONSTRAINT fk_sql_metrics_table_id_tables FOREIGN KEY (table_id) REFERENCES public.tables(id) ON DELETE CASCADE;


--
-- Name: sqlatable_user fk_sqlatable_user_table_id_tables; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.sqlatable_user
    ADD CONSTRAINT fk_sqlatable_user_table_id_tables FOREIGN KEY (table_id) REFERENCES public.tables(id) ON DELETE CASCADE;


--
-- Name: sqlatable_user fk_sqlatable_user_user_id_ab_user; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.sqlatable_user
    ADD CONSTRAINT fk_sqlatable_user_user_id_ab_user FOREIGN KEY (user_id) REFERENCES public.ab_user(id) ON DELETE CASCADE;


--
-- Name: table_columns fk_table_columns_table_id_tables; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.table_columns
    ADD CONSTRAINT fk_table_columns_table_id_tables FOREIGN KEY (table_id) REFERENCES public.tables(id) ON DELETE CASCADE;


--
-- Name: task_subscribers fk_task_subscribers_changed_by_fk_ab_user; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.task_subscribers
    ADD CONSTRAINT fk_task_subscribers_changed_by_fk_ab_user FOREIGN KEY (changed_by_fk) REFERENCES public.ab_user(id) ON DELETE SET NULL;


--
-- Name: task_subscribers fk_task_subscribers_created_by_fk_ab_user; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.task_subscribers
    ADD CONSTRAINT fk_task_subscribers_created_by_fk_ab_user FOREIGN KEY (created_by_fk) REFERENCES public.ab_user(id) ON DELETE SET NULL;


--
-- Name: task_subscribers fk_task_subscribers_task_id_tasks; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.task_subscribers
    ADD CONSTRAINT fk_task_subscribers_task_id_tasks FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;


--
-- Name: task_subscribers fk_task_subscribers_user_id_ab_user; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.task_subscribers
    ADD CONSTRAINT fk_task_subscribers_user_id_ab_user FOREIGN KEY (user_id) REFERENCES public.ab_user(id) ON DELETE CASCADE;


--
-- Name: tasks fk_tasks_changed_by_fk_ab_user; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT fk_tasks_changed_by_fk_ab_user FOREIGN KEY (changed_by_fk) REFERENCES public.ab_user(id) ON DELETE SET NULL;


--
-- Name: tasks fk_tasks_created_by_fk_ab_user; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT fk_tasks_created_by_fk_ab_user FOREIGN KEY (created_by_fk) REFERENCES public.ab_user(id) ON DELETE SET NULL;


--
-- Name: tasks fk_tasks_user_id_ab_user; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT fk_tasks_user_id_ab_user FOREIGN KEY (user_id) REFERENCES public.ab_user(id) ON DELETE SET NULL;


--
-- Name: themes fk_themes_changed_by_fk_ab_user; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.themes
    ADD CONSTRAINT fk_themes_changed_by_fk_ab_user FOREIGN KEY (changed_by_fk) REFERENCES public.ab_user(id);


--
-- Name: themes fk_themes_created_by_fk_ab_user; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.themes
    ADD CONSTRAINT fk_themes_created_by_fk_ab_user FOREIGN KEY (created_by_fk) REFERENCES public.ab_user(id);


--
-- Name: key_value key_value_changed_by_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.key_value
    ADD CONSTRAINT key_value_changed_by_fk_fkey FOREIGN KEY (changed_by_fk) REFERENCES public.ab_user(id);


--
-- Name: key_value key_value_created_by_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.key_value
    ADD CONSTRAINT key_value_created_by_fk_fkey FOREIGN KEY (created_by_fk) REFERENCES public.ab_user(id);


--
-- Name: logs logs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.logs
    ADD CONSTRAINT logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.ab_user(id);


--
-- Name: query query_database_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.query
    ADD CONSTRAINT query_database_id_fkey FOREIGN KEY (database_id) REFERENCES public.dbs(id);


--
-- Name: query query_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.query
    ADD CONSTRAINT query_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.ab_user(id);


--
-- Name: report_execution_log report_execution_log_report_schedule_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.report_execution_log
    ADD CONSTRAINT report_execution_log_report_schedule_id_fkey FOREIGN KEY (report_schedule_id) REFERENCES public.report_schedule(id);


--
-- Name: report_recipient report_recipient_changed_by_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.report_recipient
    ADD CONSTRAINT report_recipient_changed_by_fk_fkey FOREIGN KEY (changed_by_fk) REFERENCES public.ab_user(id);


--
-- Name: report_recipient report_recipient_created_by_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.report_recipient
    ADD CONSTRAINT report_recipient_created_by_fk_fkey FOREIGN KEY (created_by_fk) REFERENCES public.ab_user(id);


--
-- Name: report_recipient report_recipient_report_schedule_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.report_recipient
    ADD CONSTRAINT report_recipient_report_schedule_id_fkey FOREIGN KEY (report_schedule_id) REFERENCES public.report_schedule(id);


--
-- Name: report_schedule report_schedule_changed_by_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.report_schedule
    ADD CONSTRAINT report_schedule_changed_by_fk_fkey FOREIGN KEY (changed_by_fk) REFERENCES public.ab_user(id);


--
-- Name: report_schedule report_schedule_chart_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.report_schedule
    ADD CONSTRAINT report_schedule_chart_id_fkey FOREIGN KEY (chart_id) REFERENCES public.slices(id);


--
-- Name: report_schedule report_schedule_created_by_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.report_schedule
    ADD CONSTRAINT report_schedule_created_by_fk_fkey FOREIGN KEY (created_by_fk) REFERENCES public.ab_user(id);


--
-- Name: report_schedule report_schedule_dashboard_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.report_schedule
    ADD CONSTRAINT report_schedule_dashboard_id_fkey FOREIGN KEY (dashboard_id) REFERENCES public.dashboards(id);


--
-- Name: report_schedule report_schedule_database_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.report_schedule
    ADD CONSTRAINT report_schedule_database_id_fkey FOREIGN KEY (database_id) REFERENCES public.dbs(id);


--
-- Name: rls_filter_roles rls_filter_roles_rls_filter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.rls_filter_roles
    ADD CONSTRAINT rls_filter_roles_rls_filter_id_fkey FOREIGN KEY (rls_filter_id) REFERENCES public.row_level_security_filters(id);


--
-- Name: rls_filter_roles rls_filter_roles_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.rls_filter_roles
    ADD CONSTRAINT rls_filter_roles_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.ab_role(id);


--
-- Name: rls_filter_tables rls_filter_tables_rls_filter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.rls_filter_tables
    ADD CONSTRAINT rls_filter_tables_rls_filter_id_fkey FOREIGN KEY (rls_filter_id) REFERENCES public.row_level_security_filters(id);


--
-- Name: rls_filter_tables rls_filter_tables_table_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.rls_filter_tables
    ADD CONSTRAINT rls_filter_tables_table_id_fkey FOREIGN KEY (table_id) REFERENCES public.tables(id);


--
-- Name: row_level_security_filters row_level_security_filters_changed_by_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.row_level_security_filters
    ADD CONSTRAINT row_level_security_filters_changed_by_fk_fkey FOREIGN KEY (changed_by_fk) REFERENCES public.ab_user(id);


--
-- Name: row_level_security_filters row_level_security_filters_created_by_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.row_level_security_filters
    ADD CONSTRAINT row_level_security_filters_created_by_fk_fkey FOREIGN KEY (created_by_fk) REFERENCES public.ab_user(id);


--
-- Name: saved_query saved_query_changed_by_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.saved_query
    ADD CONSTRAINT saved_query_changed_by_fk_fkey FOREIGN KEY (changed_by_fk) REFERENCES public.ab_user(id);


--
-- Name: saved_query saved_query_created_by_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.saved_query
    ADD CONSTRAINT saved_query_created_by_fk_fkey FOREIGN KEY (created_by_fk) REFERENCES public.ab_user(id);


--
-- Name: saved_query saved_query_db_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.saved_query
    ADD CONSTRAINT saved_query_db_id_fkey FOREIGN KEY (db_id) REFERENCES public.dbs(id);


--
-- Name: tab_state saved_query_id; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.tab_state
    ADD CONSTRAINT saved_query_id FOREIGN KEY (saved_query_id) REFERENCES public.saved_query(id) ON DELETE SET NULL;


--
-- Name: saved_query saved_query_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.saved_query
    ADD CONSTRAINT saved_query_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.ab_user(id);


--
-- Name: slices slices_changed_by_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.slices
    ADD CONSTRAINT slices_changed_by_fk_fkey FOREIGN KEY (changed_by_fk) REFERENCES public.ab_user(id);


--
-- Name: slices slices_created_by_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.slices
    ADD CONSTRAINT slices_created_by_fk_fkey FOREIGN KEY (created_by_fk) REFERENCES public.ab_user(id);


--
-- Name: slices slices_last_saved_by_fk; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.slices
    ADD CONSTRAINT slices_last_saved_by_fk FOREIGN KEY (last_saved_by_fk) REFERENCES public.ab_user(id);


--
-- Name: slices slices_table_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.slices
    ADD CONSTRAINT slices_table_id_fkey FOREIGN KEY (table_id) REFERENCES public.tables(id);


--
-- Name: sql_metrics sql_metrics_changed_by_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.sql_metrics
    ADD CONSTRAINT sql_metrics_changed_by_fk_fkey FOREIGN KEY (changed_by_fk) REFERENCES public.ab_user(id);


--
-- Name: sql_metrics sql_metrics_created_by_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.sql_metrics
    ADD CONSTRAINT sql_metrics_created_by_fk_fkey FOREIGN KEY (created_by_fk) REFERENCES public.ab_user(id);


--
-- Name: ssh_tunnels ssh_tunnels_database_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.ssh_tunnels
    ADD CONSTRAINT ssh_tunnels_database_id_fkey FOREIGN KEY (database_id) REFERENCES public.dbs(id);


--
-- Name: tab_state tab_state_changed_by_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.tab_state
    ADD CONSTRAINT tab_state_changed_by_fk_fkey FOREIGN KEY (changed_by_fk) REFERENCES public.ab_user(id);


--
-- Name: tab_state tab_state_created_by_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.tab_state
    ADD CONSTRAINT tab_state_created_by_fk_fkey FOREIGN KEY (created_by_fk) REFERENCES public.ab_user(id);


--
-- Name: tab_state tab_state_database_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.tab_state
    ADD CONSTRAINT tab_state_database_id_fkey FOREIGN KEY (database_id) REFERENCES public.dbs(id) ON DELETE CASCADE;


--
-- Name: tab_state tab_state_latest_query_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.tab_state
    ADD CONSTRAINT tab_state_latest_query_id_fkey FOREIGN KEY (latest_query_id) REFERENCES public.query(client_id) ON DELETE SET NULL;


--
-- Name: tab_state tab_state_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.tab_state
    ADD CONSTRAINT tab_state_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.ab_user(id);


--
-- Name: table_columns table_columns_changed_by_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.table_columns
    ADD CONSTRAINT table_columns_changed_by_fk_fkey FOREIGN KEY (changed_by_fk) REFERENCES public.ab_user(id);


--
-- Name: table_columns table_columns_created_by_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.table_columns
    ADD CONSTRAINT table_columns_created_by_fk_fkey FOREIGN KEY (created_by_fk) REFERENCES public.ab_user(id);


--
-- Name: table_schema table_schema_changed_by_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.table_schema
    ADD CONSTRAINT table_schema_changed_by_fk_fkey FOREIGN KEY (changed_by_fk) REFERENCES public.ab_user(id);


--
-- Name: table_schema table_schema_created_by_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.table_schema
    ADD CONSTRAINT table_schema_created_by_fk_fkey FOREIGN KEY (created_by_fk) REFERENCES public.ab_user(id);


--
-- Name: table_schema table_schema_database_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.table_schema
    ADD CONSTRAINT table_schema_database_id_fkey FOREIGN KEY (database_id) REFERENCES public.dbs(id) ON DELETE CASCADE;


--
-- Name: table_schema table_schema_tab_state_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.table_schema
    ADD CONSTRAINT table_schema_tab_state_id_fkey FOREIGN KEY (tab_state_id) REFERENCES public.tab_state(id) ON DELETE CASCADE;


--
-- Name: tables tables_changed_by_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.tables
    ADD CONSTRAINT tables_changed_by_fk_fkey FOREIGN KEY (changed_by_fk) REFERENCES public.ab_user(id);


--
-- Name: tables tables_created_by_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.tables
    ADD CONSTRAINT tables_created_by_fk_fkey FOREIGN KEY (created_by_fk) REFERENCES public.ab_user(id);


--
-- Name: tables tables_database_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.tables
    ADD CONSTRAINT tables_database_id_fkey FOREIGN KEY (database_id) REFERENCES public.dbs(id);


--
-- Name: tag tag_changed_by_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.tag
    ADD CONSTRAINT tag_changed_by_fk_fkey FOREIGN KEY (changed_by_fk) REFERENCES public.ab_user(id);


--
-- Name: tag tag_created_by_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.tag
    ADD CONSTRAINT tag_created_by_fk_fkey FOREIGN KEY (created_by_fk) REFERENCES public.ab_user(id);


--
-- Name: tagged_object tagged_object_changed_by_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.tagged_object
    ADD CONSTRAINT tagged_object_changed_by_fk_fkey FOREIGN KEY (changed_by_fk) REFERENCES public.ab_user(id);


--
-- Name: tagged_object tagged_object_created_by_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.tagged_object
    ADD CONSTRAINT tagged_object_created_by_fk_fkey FOREIGN KEY (created_by_fk) REFERENCES public.ab_user(id);


--
-- Name: tagged_object tagged_object_tag_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.tagged_object
    ADD CONSTRAINT tagged_object_tag_id_fkey FOREIGN KEY (tag_id) REFERENCES public.tag(id);


--
-- Name: user_attribute user_attribute_changed_by_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.user_attribute
    ADD CONSTRAINT user_attribute_changed_by_fk_fkey FOREIGN KEY (changed_by_fk) REFERENCES public.ab_user(id);


--
-- Name: user_attribute user_attribute_created_by_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.user_attribute
    ADD CONSTRAINT user_attribute_created_by_fk_fkey FOREIGN KEY (created_by_fk) REFERENCES public.ab_user(id);


--
-- Name: user_attribute user_attribute_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.user_attribute
    ADD CONSTRAINT user_attribute_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.ab_user(id);


--
-- Name: user_attribute user_attribute_welcome_dashboard_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.user_attribute
    ADD CONSTRAINT user_attribute_welcome_dashboard_id_fkey FOREIGN KEY (welcome_dashboard_id) REFERENCES public.dashboards(id);


--
-- Name: user_favorite_tag user_favorite_tag_tag_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.user_favorite_tag
    ADD CONSTRAINT user_favorite_tag_tag_id_fkey FOREIGN KEY (tag_id) REFERENCES public.tag(id);


--
-- Name: user_favorite_tag user_favorite_tag_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: analytics
--

ALTER TABLE ONLY public.user_favorite_tag
    ADD CONSTRAINT user_favorite_tag_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.ab_user(id);


--
-- PostgreSQL database dump complete
--

\unrestrict NhjxLFPxF0YleGExx5pt7F6N2DC1rxIA1QtqNpK3tjg82BHsGPMYrHMHcwhq79o

