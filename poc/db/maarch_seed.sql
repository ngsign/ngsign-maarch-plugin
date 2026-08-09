--
-- PostgreSQL database dump
--

\restrict xVQ7DAGQsYbZEzFbgHJH54nOao5rbBkCPYqdUcgDieBxsLDoOeHPCmQrhcgcInZ

-- Dumped from database version 14.23
-- Dumped by pg_dump version 14.23

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
-- Name: unaccent; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA public;


--
-- Name: EXTENSION unaccent; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION unaccent IS 'text search dictionary that removes accents';


--
-- Name: custom_fields_modes; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.custom_fields_modes AS ENUM (
    'form',
    'technical'
);


--
-- Name: users_modes; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.users_modes AS ENUM (
    'standard',
    'rest',
    'root_visible',
    'root_invisible'
);


--
-- Name: increase_chrono(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.increase_chrono(chrono_seq_name text, chrono_id_name text) RETURNS TABLE(chrono_id bigint)
    LANGUAGE plpgsql
    AS $$
DECLARE
    retval bigint;
BEGIN
    -- Check if sequence exist, if not create
	IF NOT EXISTS (SELECT 0 FROM pg_class where relname = chrono_seq_name ) THEN
      EXECUTE 'CREATE SEQUENCE "' || chrono_seq_name || '" INCREMENT 1 MINVALUE 1 MAXVALUE 9223372036854775807 START 1 CACHE 1;';
    END IF;
    -- Check if chrono exist in parameters table, if not create
    IF NOT EXISTS (SELECT 0 FROM parameters where id = chrono_id_name ) THEN
      EXECUTE 'INSERT INTO parameters (id, param_value_int) VALUES ( ''' || chrono_id_name || ''', 1)';
    END IF;
    -- Get next value of sequence, update the value in parameters table before returning the value
    SELECT nextval(chrono_seq_name) INTO retval;
	  UPDATE parameters set param_value_int = retval WHERE id =  chrono_id_name;
	  RETURN QUERY SELECT retval;
END;
$$;


--
-- Name: order_alphanum(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.order_alphanum(text) RETURNS text
    LANGUAGE plpgsql
    AS $_$
declare
    tmp text;
begin
    tmp := $1;
    tmp := tmp || 'Z';
    tmp := regexp_replace(tmp, E'(\\D)', E'\\1/', 'g');

    IF count(regexp_match(tmp, E'(\\D(\\d{8})\\D)')) > 0 THEN
        tmp := regexp_replace(tmp, E'(\\D)(\\d{8}\\D)', E'\\10\\2', 'g');
    END IF;
    IF count(regexp_match(tmp, E'(\\D)(\\d{7}\\D)')) > 0 THEN
        tmp := regexp_replace(tmp, E'(\\D)(\\d{7}\\D)', E'\\100\\2', 'g');
    END IF;
    IF count(regexp_match(tmp, E'(\\D)(\\d{6}\\D)')) > 0 THEN
        tmp := regexp_replace(tmp, E'(\\D)(\\d{6}\\D)', E'\\1000\\2', 'g');
    END IF;
    IF count(regexp_match(tmp, E'(\\D)(\\d{5}\\D)')) > 0 THEN
        tmp := regexp_replace(tmp, E'(\\D)(\\d{5}\\D)', E'\\10000\\2', 'g');
    END IF;
    IF count(regexp_match(tmp, E'(\\D)(\\d{4}\\D)')) > 0 THEN
        tmp := regexp_replace(tmp, E'(\\D)(\\d{4}\\D)', E'\\100000\\2', 'g');
    END IF;
    IF count(regexp_match(tmp, E'(\\D)(\\d{3}\\D)')) > 0 THEN
        tmp := regexp_replace(tmp, E'(\\D)(\\d{3}\\D)', E'\\1000000\\2', 'g');
    END IF;
    IF count(regexp_match(tmp, E'(\\D)(\\d{2}\\D)')) > 0 THEN
        tmp := regexp_replace(tmp, E'(\\D)(\\d{2}\\D)', E'\\10000000\\2', 'g');
    END IF;
    IF count(regexp_match(tmp, E'(\\D)(\\d{1}\\D)')) > 0 THEN
        tmp := regexp_replace(tmp, E'(\\D)(\\d{1}\\D)', E'\\100000000\\2', 'g');
    END IF;

    RETURN tmp;
end;
$_$;


--
-- Name: reset_chronos(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reset_chronos() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
  chrono record;
BEGIN
  -- Loop through each chrono found in parameters table
	FOR chrono IN (SELECT * FROM parameters WHERE id LIKE '%_' || extract(YEAR FROM current_date)) LOOP
    EXECUTE 'SELECT setVal(''' || CONCAT(chrono.id, '_seq') || ''', 1)';
    UPDATE parameters SET param_value_int = '1' WHERE id = chrono.id;
  END LOOP;
END
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: acknowledgement_receipts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.acknowledgement_receipts (
    id integer NOT NULL,
    res_id integer NOT NULL,
    type character varying(16) NOT NULL,
    format character varying(8) NOT NULL,
    user_id integer NOT NULL,
    contact_id integer NOT NULL,
    creation_date timestamp without time zone NOT NULL,
    send_date timestamp without time zone,
    docserver_id character varying(128) NOT NULL,
    path character varying(256) NOT NULL,
    filename character varying(256) NOT NULL,
    fingerprint character varying(256) NOT NULL,
    cc jsonb DEFAULT '[]'::jsonb,
    cci jsonb DEFAULT '[]'::jsonb
);


--
-- Name: acknowledgement_receipts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.acknowledgement_receipts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: acknowledgement_receipts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.acknowledgement_receipts_id_seq OWNED BY public.acknowledgement_receipts.id;


--
-- Name: actions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.actions (
    id integer NOT NULL,
    keyword character varying(32) DEFAULT ''::bpchar NOT NULL,
    label_action character varying(255),
    id_status character varying(10),
    is_system character(1) DEFAULT 'N'::bpchar NOT NULL,
    action_page character varying(255),
    component character varying(128),
    history character(1) DEFAULT 'N'::bpchar NOT NULL,
    parameters jsonb DEFAULT '{}'::jsonb NOT NULL
);


--
-- Name: actions_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.actions_categories (
    action_id bigint NOT NULL,
    category_id character varying(255) NOT NULL
);


--
-- Name: actions_groupbaskets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.actions_groupbaskets (
    id_action bigint NOT NULL,
    where_clause text,
    group_id character varying(32) NOT NULL,
    basket_id character varying(32) NOT NULL,
    used_in_basketlist character(1) DEFAULT 'Y'::bpchar NOT NULL,
    used_in_action_page character(1) DEFAULT 'Y'::bpchar NOT NULL,
    default_action_list character(1) DEFAULT 'N'::bpchar NOT NULL
);


--
-- Name: actions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.actions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: actions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.actions_id_seq OWNED BY public.actions.id;


--
-- Name: address_sectors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.address_sectors (
    id integer NOT NULL,
    address_number character varying(256),
    address_street character varying(256),
    address_postcode character varying(256),
    address_town character varying(256),
    label character varying(256),
    ban_id character varying(256)
);


--
-- Name: address_sectors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.address_sectors_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: address_sectors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.address_sectors_id_seq OWNED BY public.address_sectors.id;


--
-- Name: adr_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.adr_attachments (
    id integer NOT NULL,
    res_id bigint NOT NULL,
    type character varying(32) NOT NULL,
    docserver_id character varying(32) NOT NULL,
    path character varying(255) NOT NULL,
    filename character varying(255) NOT NULL,
    fingerprint character varying(255) DEFAULT NULL::character varying
);


--
-- Name: adr_attachments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.adr_attachments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: adr_attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.adr_attachments_id_seq OWNED BY public.adr_attachments.id;


--
-- Name: adr_letterbox; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.adr_letterbox (
    id integer NOT NULL,
    res_id bigint NOT NULL,
    type character varying(32) NOT NULL,
    version integer NOT NULL,
    docserver_id character varying(32) NOT NULL,
    path character varying(255) NOT NULL,
    filename character varying(255) NOT NULL,
    fingerprint character varying(255) DEFAULT NULL::character varying
);


--
-- Name: adr_letterbox_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.adr_letterbox_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: adr_letterbox_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.adr_letterbox_id_seq OWNED BY public.adr_letterbox.id;


--
-- Name: attachment_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.attachment_types (
    id integer NOT NULL,
    type_id text NOT NULL,
    label text NOT NULL,
    visible boolean NOT NULL,
    email_link boolean NOT NULL,
    signable boolean NOT NULL,
    signed_by_default boolean NOT NULL,
    icon text,
    chrono boolean NOT NULL,
    version_enabled boolean NOT NULL,
    new_version_default boolean NOT NULL
);


--
-- Name: attachment_types_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.attachment_types_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: attachment_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.attachment_types_id_seq OWNED BY public.attachment_types.id;


--
-- Name: blacklist; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.blacklist (
    id integer NOT NULL,
    term character varying(128) NOT NULL
);


--
-- Name: notes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notes (
    id integer NOT NULL,
    identifier bigint NOT NULL,
    user_id bigint NOT NULL,
    creation_date timestamp without time zone NOT NULL,
    note_text text NOT NULL
);


--
-- Name: bad_notes; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.bad_notes AS
 SELECT notes.id,
    notes.identifier,
    notes.user_id,
    notes.creation_date,
    notes.note_text
   FROM public.notes
  WHERE (public.unaccent(notes.note_text) ~* concat('m(', array_to_string(ARRAY( SELECT public.unaccent((blacklist.term)::text) AS unaccent
           FROM public.blacklist), '|'::text, ''::text), ')M'));


--
-- Name: basket_persistent_mode; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.basket_persistent_mode (
    res_id bigint,
    user_id integer NOT NULL,
    is_persistent character varying(1)
);


--
-- Name: baskets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.baskets (
    id integer NOT NULL,
    coll_id character varying(32) NOT NULL,
    basket_id character varying(32) NOT NULL,
    basket_name character varying(255) NOT NULL,
    basket_desc character varying(255) NOT NULL,
    basket_clause text NOT NULL,
    is_visible character(1) DEFAULT 'Y'::bpchar NOT NULL,
    enabled character(1) DEFAULT 'Y'::bpchar NOT NULL,
    basket_order integer,
    color character varying(16),
    basket_res_order character varying(255) DEFAULT 'res_id desc'::character varying NOT NULL,
    flag_notif character varying(1)
);


--
-- Name: baskets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.baskets_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: baskets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.baskets_id_seq OWNED BY public.baskets.id;


--
-- Name: blacklist_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.blacklist_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: blacklist_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.blacklist_id_seq OWNED BY public.blacklist.id;


--
-- Name: chrono_incoming_2026_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chrono_incoming_2026_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chrono_outgoing_2026_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chrono_outgoing_2026_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: configurations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.configurations (
    id integer NOT NULL,
    privilege character varying(64) NOT NULL,
    value jsonb DEFAULT '{}'::jsonb NOT NULL
);


--
-- Name: configurations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.configurations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: configurations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.configurations_id_seq OWNED BY public.configurations.id;


--
-- Name: contacts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contacts (
    id integer NOT NULL,
    civility integer,
    firstname character varying(256),
    lastname character varying(256),
    company character varying(256),
    department character varying(256),
    function character varying(256),
    address_number character varying(256),
    address_street character varying(256),
    address_additional1 character varying(256),
    address_additional2 character varying(256),
    address_postcode character varying(256),
    address_town character varying(256),
    address_country character varying(256),
    email character varying(256),
    phone character varying(256),
    communication_means jsonb,
    notes text,
    creator integer NOT NULL,
    creation_date timestamp without time zone DEFAULT now() NOT NULL,
    modification_date timestamp without time zone,
    enabled boolean DEFAULT true NOT NULL,
    custom_fields jsonb DEFAULT '{}'::jsonb,
    external_id jsonb DEFAULT '{}'::jsonb,
    sector character varying(256),
    lad_indexation boolean DEFAULT false NOT NULL
);


--
-- Name: contacts_civilities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contacts_civilities (
    id integer NOT NULL,
    label text NOT NULL,
    abbreviation character varying(16) NOT NULL
);


--
-- Name: contacts_civilities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.contacts_civilities_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: contacts_civilities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.contacts_civilities_id_seq OWNED BY public.contacts_civilities.id;


--
-- Name: contacts_custom_fields_list; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contacts_custom_fields_list (
    id integer NOT NULL,
    label character varying(256) NOT NULL,
    type character varying(256) NOT NULL,
    "values" jsonb
);


--
-- Name: contacts_custom_fields_list_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.contacts_custom_fields_list_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: contacts_custom_fields_list_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.contacts_custom_fields_list_id_seq OWNED BY public.contacts_custom_fields_list.id;


--
-- Name: contacts_filling; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contacts_filling (
    id integer NOT NULL,
    enable boolean NOT NULL,
    first_threshold integer NOT NULL,
    second_threshold integer NOT NULL
);


--
-- Name: contacts_filling_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.contacts_filling_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: contacts_filling_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.contacts_filling_id_seq OWNED BY public.contacts_filling.id;


--
-- Name: contacts_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contacts_groups (
    id integer NOT NULL,
    label text NOT NULL,
    description text NOT NULL,
    owner integer NOT NULL,
    entities jsonb DEFAULT '{}'::jsonb NOT NULL
);


--
-- Name: contacts_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.contacts_groups_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: contacts_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.contacts_groups_id_seq OWNED BY public.contacts_groups.id;


--
-- Name: contacts_groups_lists; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contacts_groups_lists (
    id integer NOT NULL,
    contacts_groups_id integer NOT NULL,
    correspondent_id integer NOT NULL,
    correspondent_type character varying(256) NOT NULL
);


--
-- Name: contacts_groups_lists_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.contacts_groups_lists_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: contacts_groups_lists_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.contacts_groups_lists_id_seq OWNED BY public.contacts_groups_lists.id;


--
-- Name: contacts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.contacts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: contacts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.contacts_id_seq OWNED BY public.contacts.id;


--
-- Name: contacts_parameters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contacts_parameters (
    id integer NOT NULL,
    identifier text NOT NULL,
    mandatory boolean DEFAULT false NOT NULL,
    filling boolean DEFAULT false NOT NULL,
    searchable boolean DEFAULT false NOT NULL,
    displayable boolean DEFAULT false NOT NULL
);


--
-- Name: contacts_parameters_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.contacts_parameters_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: contacts_parameters_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.contacts_parameters_id_seq OWNED BY public.contacts_parameters.id;


--
-- Name: convert_stack; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.convert_stack (
    coll_id character varying(32) NOT NULL,
    res_id bigint NOT NULL,
    convert_format character varying(32) DEFAULT 'pdf'::character varying NOT NULL,
    cnt_retry integer,
    status character(1) NOT NULL,
    work_batch bigint,
    regex character varying(32)
);


--
-- Name: custom_fields; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.custom_fields (
    id integer NOT NULL,
    label character varying(256) NOT NULL,
    type character varying(256) NOT NULL,
    mode public.custom_fields_modes DEFAULT 'form'::public.custom_fields_modes NOT NULL,
    "values" jsonb
);


--
-- Name: custom_fields_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.custom_fields_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: custom_fields_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.custom_fields_id_seq OWNED BY public.custom_fields.id;


--
-- Name: difflist_roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.difflist_roles (
    id integer NOT NULL,
    role_id character varying(32) NOT NULL,
    label character varying(255) NOT NULL,
    keep_in_list_instance boolean DEFAULT false NOT NULL
);


--
-- Name: difflist_roles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.difflist_roles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: difflist_roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.difflist_roles_id_seq OWNED BY public.difflist_roles.id;


--
-- Name: difflist_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.difflist_types (
    difflist_type_id character varying(50) NOT NULL,
    difflist_type_label character varying(100) NOT NULL,
    difflist_type_roles text,
    allow_entities character varying(1) DEFAULT 'N'::bpchar NOT NULL,
    is_system character varying(1) DEFAULT 'N'::bpchar NOT NULL
);


--
-- Name: docserver_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.docserver_types (
    docserver_type_id character varying(32) NOT NULL,
    docserver_type_label character varying(255) DEFAULT NULL::character varying,
    enabled character(1) DEFAULT 'Y'::bpchar NOT NULL,
    fingerprint_mode character varying(32) DEFAULT NULL::character varying
);


--
-- Name: docservers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.docservers (
    id integer NOT NULL,
    docserver_id character varying(32) DEFAULT '1'::character varying NOT NULL,
    docserver_type_id character varying(32) NOT NULL,
    device_label character varying(255) DEFAULT NULL::character varying,
    is_readonly character(1) DEFAULT 'N'::bpchar NOT NULL,
    is_encrypted boolean DEFAULT false NOT NULL,
    size_limit_number bigint DEFAULT (0)::bigint NOT NULL,
    actual_size_number bigint DEFAULT (0)::bigint NOT NULL,
    path_template character varying(255) NOT NULL,
    creation_date timestamp without time zone NOT NULL,
    coll_id character varying(32) DEFAULT 'coll_1'::character varying NOT NULL
);


--
-- Name: docservers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.docservers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: docservers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.docservers_id_seq OWNED BY public.docservers.id;


--
-- Name: doctypes_type_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.doctypes_type_id_seq
    START WITH 500
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: doctypes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.doctypes (
    coll_id character varying(32) DEFAULT ''::character varying NOT NULL,
    type_id integer DEFAULT nextval('public.doctypes_type_id_seq'::regclass) NOT NULL,
    description character varying(255) DEFAULT ''::character varying NOT NULL,
    enabled character(1) DEFAULT 'Y'::bpchar NOT NULL,
    doctypes_first_level_id integer,
    doctypes_second_level_id integer,
    retention_final_disposition character varying(255) DEFAULT NULL::character varying,
    retention_rule character varying(15) DEFAULT NULL::character varying,
    action_current_use character varying(255) DEFAULT NULL::character varying,
    duration_current_use integer,
    process_delay integer NOT NULL,
    delay1 integer NOT NULL,
    delay2 integer NOT NULL,
    process_mode character varying(256) NOT NULL
);


--
-- Name: doctypes_first_level_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.doctypes_first_level_id_seq
    START WITH 200
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: doctypes_first_level; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.doctypes_first_level (
    doctypes_first_level_id integer DEFAULT nextval('public.doctypes_first_level_id_seq'::regclass) NOT NULL,
    doctypes_first_level_label character varying(255) NOT NULL,
    css_style character varying(255),
    enabled character(1) DEFAULT 'Y'::bpchar NOT NULL
);


--
-- Name: doctypes_indexes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.doctypes_indexes (
    type_id bigint NOT NULL,
    coll_id character varying(32) NOT NULL,
    field_name character varying(255) NOT NULL,
    mandatory character(1) DEFAULT 'N'::bpchar NOT NULL
);


--
-- Name: doctypes_second_level_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.doctypes_second_level_id_seq
    START WITH 200
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: doctypes_second_level; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.doctypes_second_level (
    doctypes_second_level_id integer DEFAULT nextval('public.doctypes_second_level_id_seq'::regclass) NOT NULL,
    doctypes_second_level_label character varying(255) NOT NULL,
    doctypes_first_level_id integer NOT NULL,
    css_style character varying(255),
    enabled character(1) DEFAULT 'Y'::bpchar NOT NULL
);


--
-- Name: emails; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.emails (
    id integer NOT NULL,
    user_id integer NOT NULL,
    sender json DEFAULT '{}'::json NOT NULL,
    recipients json DEFAULT '[]'::json NOT NULL,
    cc json DEFAULT '[]'::json NOT NULL,
    cci json DEFAULT '[]'::json NOT NULL,
    object character varying(256),
    body text,
    document json,
    is_html boolean DEFAULT true NOT NULL,
    status character varying(16) NOT NULL,
    message_exchange_id text,
    creation_date timestamp without time zone NOT NULL,
    send_date timestamp without time zone
);


--
-- Name: emails_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.emails_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: emails_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.emails_id_seq OWNED BY public.emails.id;


--
-- Name: entities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.entities (
    id integer NOT NULL,
    entity_id character varying(32) NOT NULL,
    entity_label character varying(255),
    short_label character varying(50),
    entity_full_name text,
    enabled character(1) DEFAULT 'Y'::bpchar NOT NULL,
    address_number character varying(255),
    address_street character varying(255),
    address_additional1 character varying(255),
    address_additional2 character varying(256),
    address_postcode character varying(32),
    address_town character varying(255),
    address_country character varying(255),
    email character varying(255),
    business_id character varying(32),
    parent_entity_id character varying(32),
    entity_type character varying(64),
    ldap_id character varying(255),
    producer_service character varying(255),
    folder_import character varying(64),
    external_id jsonb DEFAULT '{}'::jsonb
);


--
-- Name: entities_folders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.entities_folders (
    id integer NOT NULL,
    folder_id integer NOT NULL,
    entity_id integer,
    edition boolean NOT NULL,
    keyword character varying(255)
);


--
-- Name: entities_folders_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.entities_folders_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: entities_folders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.entities_folders_id_seq OWNED BY public.entities_folders.id;


--
-- Name: entities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.entities_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: entities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.entities_id_seq OWNED BY public.entities.id;


--
-- Name: exports_templates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.exports_templates (
    id integer NOT NULL,
    user_id integer NOT NULL,
    delimiter character varying(3),
    format character varying(3) NOT NULL,
    data json DEFAULT '[]'::json NOT NULL
);


--
-- Name: exports_templates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.exports_templates_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: exports_templates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.exports_templates_id_seq OWNED BY public.exports_templates.id;


--
-- Name: folders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.folders (
    id integer NOT NULL,
    label character varying(255) NOT NULL,
    public boolean NOT NULL,
    user_id integer NOT NULL,
    parent_id integer,
    level integer NOT NULL
);


--
-- Name: folders_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.folders_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: folders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.folders_id_seq OWNED BY public.folders.id;


--
-- Name: groupbasket; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.groupbasket (
    id integer NOT NULL,
    group_id character varying(32) NOT NULL,
    basket_id character varying(32) NOT NULL,
    list_display json DEFAULT '[]'::json,
    list_event character varying(255) DEFAULT 'documentDetails'::character varying NOT NULL,
    list_event_data jsonb
);


--
-- Name: groupbasket_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.groupbasket_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: groupbasket_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.groupbasket_id_seq OWNED BY public.groupbasket.id;


--
-- Name: groupbasket_redirect_system_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.groupbasket_redirect_system_id_seq
    START WITH 600
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: groupbasket_redirect; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.groupbasket_redirect (
    system_id integer DEFAULT nextval('public.groupbasket_redirect_system_id_seq'::regclass) NOT NULL,
    group_id character varying(32) NOT NULL,
    basket_id character varying(32) NOT NULL,
    action_id integer NOT NULL,
    entity_id character varying(32),
    keyword character varying(255),
    redirect_mode character varying(32) NOT NULL
);


--
-- Name: history_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.history (
    id bigint DEFAULT nextval('public.history_id_seq'::regclass) NOT NULL,
    table_name character varying(32) DEFAULT NULL::character varying,
    record_id character varying(255) DEFAULT NULL::character varying,
    event_type character varying(32) NOT NULL,
    user_id integer,
    event_date timestamp without time zone NOT NULL,
    info text,
    id_module character varying(50) DEFAULT 'admin'::character varying NOT NULL,
    remote_ip character varying(32) DEFAULT NULL::character varying,
    event_id character varying(50)
);


--
-- Name: history_batch_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.history_batch_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: history_batch; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.history_batch (
    id bigint DEFAULT nextval('public.history_batch_id_seq'::regclass) NOT NULL,
    module_name character varying(32) DEFAULT NULL::character varying,
    batch_id bigint,
    event_date timestamp without time zone NOT NULL,
    total_processed bigint,
    total_errors bigint,
    info text
);


--
-- Name: indexing_models; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.indexing_models (
    id integer NOT NULL,
    label character varying(256) NOT NULL,
    category character varying(256) NOT NULL,
    "default" boolean NOT NULL,
    owner integer NOT NULL,
    private boolean NOT NULL,
    master integer,
    enabled boolean DEFAULT true NOT NULL,
    mandatory_file boolean DEFAULT false NOT NULL,
    lad_processing boolean DEFAULT false NOT NULL
);


--
-- Name: indexing_models_entities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.indexing_models_entities (
    id integer NOT NULL,
    model_id integer NOT NULL,
    entity_id character varying(32),
    keyword character varying(255)
);


--
-- Name: indexing_models_entities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.indexing_models_entities_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: indexing_models_entities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.indexing_models_entities_id_seq OWNED BY public.indexing_models_entities.id;


--
-- Name: indexing_models_fields; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.indexing_models_fields (
    id integer NOT NULL,
    model_id integer NOT NULL,
    identifier text NOT NULL,
    mandatory boolean NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    default_value json,
    unit text NOT NULL,
    allowed_values jsonb
);


--
-- Name: indexing_models_fields_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.indexing_models_fields_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: indexing_models_fields_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.indexing_models_fields_id_seq OWNED BY public.indexing_models_fields.id;


--
-- Name: indexing_models_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.indexing_models_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: indexing_models_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.indexing_models_id_seq OWNED BY public.indexing_models.id;


--
-- Name: lc_cycle_steps; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lc_cycle_steps (
    policy_id character varying(32) NOT NULL,
    cycle_id character varying(32) NOT NULL,
    cycle_step_id character varying(32) NOT NULL,
    cycle_step_desc character varying(255) NOT NULL,
    docserver_type_id character varying(32) NOT NULL,
    is_allow_failure character(1) DEFAULT 'N'::bpchar NOT NULL,
    step_operation character varying(32) NOT NULL,
    sequence_number integer NOT NULL,
    is_must_complete character(1) DEFAULT 'N'::bpchar NOT NULL,
    preprocess_script character varying(255) DEFAULT NULL::character varying,
    postprocess_script character varying(255) DEFAULT NULL::character varying
);


--
-- Name: lc_cycles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lc_cycles (
    policy_id character varying(32) NOT NULL,
    cycle_id character varying(32) NOT NULL,
    cycle_desc character varying(255) NOT NULL,
    sequence_number integer NOT NULL,
    where_clause text,
    break_key character varying(255) DEFAULT NULL::character varying,
    validation_mode character varying(32) NOT NULL
);


--
-- Name: lc_policies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lc_policies (
    policy_id character varying(32) NOT NULL,
    policy_name character varying(255) NOT NULL,
    policy_desc character varying(255) NOT NULL
);


--
-- Name: lc_stack; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lc_stack (
    policy_id character varying(32) NOT NULL,
    cycle_id character varying(32) NOT NULL,
    cycle_step_id character varying(32) NOT NULL,
    coll_id character varying(32) NOT NULL,
    res_id bigint NOT NULL,
    cnt_retry integer,
    status character(1) NOT NULL,
    work_batch bigint,
    regex character varying(32)
);


--
-- Name: list_templates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.list_templates (
    id integer NOT NULL,
    title text NOT NULL,
    description text,
    type character varying(32) NOT NULL,
    entity_id integer,
    owner integer
);


--
-- Name: list_templates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.list_templates_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: list_templates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.list_templates_id_seq OWNED BY public.list_templates.id;


--
-- Name: list_templates_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.list_templates_items (
    id integer NOT NULL,
    list_template_id integer NOT NULL,
    item_id integer NOT NULL,
    item_type character varying(32) NOT NULL,
    item_mode character varying(64) NOT NULL,
    sequence integer NOT NULL
);


--
-- Name: list_templates_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.list_templates_items_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: list_templates_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.list_templates_items_id_seq OWNED BY public.list_templates_items.id;


--
-- Name: listinstance_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.listinstance_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: listinstance; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.listinstance (
    listinstance_id bigint DEFAULT nextval('public.listinstance_id_seq'::regclass) NOT NULL,
    res_id bigint NOT NULL,
    sequence bigint NOT NULL,
    item_id integer,
    item_type character varying(255) NOT NULL,
    item_mode character varying(50) NOT NULL,
    added_by_user integer,
    viewed bigint,
    difflist_type character varying(50),
    process_date timestamp without time zone,
    process_comment character varying(255),
    signatory boolean DEFAULT false,
    requested_signature boolean DEFAULT false,
    delegate integer
);


--
-- Name: listinstance_history_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.listinstance_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: listinstance_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.listinstance_history (
    listinstance_history_id bigint DEFAULT nextval('public.listinstance_history_id_seq'::regclass) NOT NULL,
    coll_id character varying(50) NOT NULL,
    res_id bigint NOT NULL,
    user_id integer NOT NULL,
    updated_date timestamp without time zone NOT NULL
);


--
-- Name: listinstance_history_details_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.listinstance_history_details_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: listinstance_history_details; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.listinstance_history_details (
    listinstance_history_details_id bigint DEFAULT nextval('public.listinstance_history_details_id_seq'::regclass) NOT NULL,
    listinstance_history_id bigint NOT NULL,
    coll_id character varying(50) NOT NULL,
    res_id bigint NOT NULL,
    listinstance_type character varying(50) DEFAULT 'DOC'::character varying,
    sequence bigint NOT NULL,
    item_id integer,
    item_type character varying(255) NOT NULL,
    item_mode character varying(50) NOT NULL,
    added_by_user integer,
    visible character varying(1) DEFAULT 'Y'::bpchar NOT NULL,
    viewed bigint,
    difflist_type character varying(50),
    process_date timestamp without time zone,
    process_comment character varying(255),
    requested_signature boolean DEFAULT false,
    signatory boolean DEFAULT false
);


--
-- Name: message_exchange; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.message_exchange (
    message_id text NOT NULL,
    schema text,
    type text NOT NULL,
    status text NOT NULL,
    date timestamp without time zone NOT NULL,
    reference text NOT NULL,
    account_id integer,
    sender_org_identifier text NOT NULL,
    sender_org_name text,
    recipient_org_identifier text NOT NULL,
    recipient_org_name text,
    archival_agreement_reference text,
    reply_code text,
    operation_date timestamp without time zone,
    reception_date timestamp without time zone,
    related_reference text,
    request_reference text,
    reply_reference text,
    derogation boolean,
    data_object_count integer,
    size numeric,
    data text,
    active boolean,
    archived boolean,
    res_id_master numeric,
    docserver_id character varying(32) DEFAULT NULL::character varying,
    path character varying(255) DEFAULT NULL::character varying,
    filename character varying(255) DEFAULT NULL::character varying,
    fingerprint character varying(255) DEFAULT NULL::character varying,
    filesize bigint,
    file_path text
);


--
-- Name: notes_entities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.notes_entities_id_seq
    START WITH 20
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: note_entities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.note_entities (
    id bigint DEFAULT nextval('public.notes_entities_id_seq'::regclass) NOT NULL,
    note_id bigint NOT NULL,
    item_id character varying(50)
);


--
-- Name: notes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.notes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.notes_id_seq OWNED BY public.notes.id;


--
-- Name: notif_email_stack_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.notif_email_stack_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notif_email_stack; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notif_email_stack (
    email_stack_sid bigint DEFAULT nextval('public.notif_email_stack_seq'::regclass) NOT NULL,
    reply_to character varying(255),
    recipient text NOT NULL,
    cc text,
    bcc text,
    subject character varying(255),
    html_body text,
    attachments text,
    exec_date timestamp without time zone,
    exec_result character varying(50)
);


--
-- Name: notif_event_stack_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.notif_event_stack_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notif_event_stack; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notif_event_stack (
    event_stack_sid bigint DEFAULT nextval('public.notif_event_stack_seq'::regclass) NOT NULL,
    notification_sid bigint NOT NULL,
    table_name character varying(50) NOT NULL,
    record_id character varying(128) NOT NULL,
    user_id integer NOT NULL,
    event_info character varying(255) NOT NULL,
    event_date timestamp without time zone NOT NULL,
    exec_date timestamp without time zone,
    exec_result character varying(50)
);


--
-- Name: notifications_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.notifications_seq
    START WITH 100
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notifications (
    notification_sid bigint DEFAULT nextval('public.notifications_seq'::regclass) NOT NULL,
    notification_id character varying(50) NOT NULL,
    description character varying(255),
    is_enabled character varying(1) DEFAULT 'Y'::bpchar NOT NULL,
    event_id character varying(255) NOT NULL,
    notification_mode character varying(30) NOT NULL,
    template_id bigint,
    diffusion_type character varying(50) NOT NULL,
    diffusion_properties text,
    attachfor_type character varying(50),
    attachfor_properties character varying(2048),
    send_as_recap boolean DEFAULT false
);


--
-- Name: parameters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.parameters (
    id character varying(255) NOT NULL,
    description text,
    param_value_string text DEFAULT NULL::character varying,
    param_value_int integer,
    param_value_date timestamp without time zone
);


--
-- Name: password_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.password_history (
    id integer NOT NULL,
    user_serial_id integer NOT NULL,
    password character varying(255) NOT NULL
);


--
-- Name: password_history_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.password_history_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: password_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.password_history_id_seq OWNED BY public.password_history.id;


--
-- Name: password_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.password_rules (
    id integer NOT NULL,
    label character varying(64) NOT NULL,
    value integer NOT NULL,
    enabled boolean DEFAULT false NOT NULL
);


--
-- Name: password_rules_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.password_rules_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: password_rules_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.password_rules_id_seq OWNED BY public.password_rules.id;


--
-- Name: priorities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.priorities (
    id character varying(16) NOT NULL,
    label character varying(128) NOT NULL,
    color character varying(128) NOT NULL,
    delays integer NOT NULL,
    "order" integer
);


--
-- Name: redirected_baskets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.redirected_baskets (
    id integer NOT NULL,
    actual_user_id integer NOT NULL,
    owner_user_id integer NOT NULL,
    basket_id character varying(255) NOT NULL,
    group_id integer NOT NULL
);


--
-- Name: redirected_baskets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.redirected_baskets_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: redirected_baskets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.redirected_baskets_id_seq OWNED BY public.redirected_baskets.id;


--
-- Name: registered_mail_issuing_sites; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.registered_mail_issuing_sites (
    id integer NOT NULL,
    label character varying(256) NOT NULL,
    post_office_label character varying(256),
    account_number integer,
    address_number character varying(256) NOT NULL,
    address_street character varying(256) NOT NULL,
    address_additional1 character varying(256),
    address_additional2 character varying(256),
    address_postcode character varying(256) NOT NULL,
    address_town character varying(256) NOT NULL,
    address_country character varying(256)
);


--
-- Name: registered_mail_issuing_sites_entities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.registered_mail_issuing_sites_entities (
    id integer NOT NULL,
    site_id integer NOT NULL,
    entity_id integer NOT NULL
);


--
-- Name: registered_mail_issuing_sites_entities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.registered_mail_issuing_sites_entities_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: registered_mail_issuing_sites_entities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.registered_mail_issuing_sites_entities_id_seq OWNED BY public.registered_mail_issuing_sites_entities.id;


--
-- Name: registered_mail_issuing_sites_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.registered_mail_issuing_sites_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: registered_mail_issuing_sites_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.registered_mail_issuing_sites_id_seq OWNED BY public.registered_mail_issuing_sites.id;


--
-- Name: registered_mail_number_range; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.registered_mail_number_range (
    id integer NOT NULL,
    type character varying(15) NOT NULL,
    tracking_account_number character varying(256) NOT NULL,
    range_start integer NOT NULL,
    range_end integer NOT NULL,
    creator integer NOT NULL,
    creation_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    status character varying(10) NOT NULL,
    current_number integer
);


--
-- Name: registered_mail_number_range_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.registered_mail_number_range_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: registered_mail_number_range_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.registered_mail_number_range_id_seq OWNED BY public.registered_mail_number_range.id;


--
-- Name: registered_mail_resources; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.registered_mail_resources (
    id integer NOT NULL,
    res_id integer NOT NULL,
    type character varying(2) NOT NULL,
    issuing_site integer NOT NULL,
    warranty character varying(2) NOT NULL,
    letter boolean DEFAULT false NOT NULL,
    recipient jsonb NOT NULL,
    number integer NOT NULL,
    reference text,
    generated boolean DEFAULT false NOT NULL,
    deposit_id integer,
    received_date timestamp without time zone,
    return_reason character varying(256)
);


--
-- Name: registered_mail_resources_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.registered_mail_resources_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: registered_mail_resources_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.registered_mail_resources_id_seq OWNED BY public.registered_mail_resources.id;


--
-- Name: res_attachment_res_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.res_attachment_res_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: res_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.res_attachments (
    res_id bigint DEFAULT nextval('public.res_attachment_res_id_seq'::regclass) NOT NULL,
    title character varying(255) DEFAULT NULL::character varying,
    format character varying(50) NOT NULL,
    typist integer,
    creation_date timestamp without time zone NOT NULL,
    modification_date timestamp without time zone DEFAULT now(),
    modified_by integer,
    identifier character varying(255) DEFAULT NULL::character varying,
    relation bigint,
    docserver_id character varying(32) NOT NULL,
    path character varying(255) DEFAULT NULL::character varying,
    filename character varying(255) DEFAULT NULL::character varying,
    fingerprint character varying(255) DEFAULT NULL::character varying,
    filesize bigint,
    status character varying(10) DEFAULT NULL::character varying,
    validation_date timestamp without time zone,
    effective_date timestamp without time zone,
    work_batch bigint,
    origin character varying(50) DEFAULT NULL::character varying,
    res_id_master bigint,
    origin_id integer,
    attachment_type character varying(255) DEFAULT NULL::character varying,
    recipient_id integer,
    recipient_type character varying(256),
    in_signature_book boolean DEFAULT false,
    in_send_attach boolean DEFAULT false,
    signatory_user_serial_id integer,
    fulltext_result character varying(10) DEFAULT NULL::character varying,
    external_id jsonb DEFAULT '{}'::jsonb,
    external_state jsonb DEFAULT '{}'::jsonb
);


--
-- Name: res_id_mlb_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.res_id_mlb_seq
    START WITH 100
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: res_letterbox; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.res_letterbox (
    res_id bigint DEFAULT nextval('public.res_id_mlb_seq'::regclass) NOT NULL,
    subject text,
    type_id bigint NOT NULL,
    format character varying(50),
    typist integer,
    creation_date timestamp without time zone NOT NULL,
    modification_date timestamp without time zone DEFAULT now(),
    doc_date timestamp without time zone,
    docserver_id character varying(32),
    path character varying(255) DEFAULT NULL::character varying,
    filename character varying(255) DEFAULT NULL::character varying,
    fingerprint character varying(255) DEFAULT NULL::character varying,
    filesize bigint,
    status character varying(10),
    destination character varying(50) DEFAULT NULL::character varying,
    work_batch bigint,
    origin character varying(50) DEFAULT NULL::character varying,
    priority character varying(16),
    policy_id character varying(32) DEFAULT NULL::character varying,
    cycle_id character varying(32) DEFAULT NULL::character varying,
    initiator character varying(50) DEFAULT NULL::character varying,
    dest_user integer,
    locker_user_id integer,
    locker_time timestamp without time zone,
    confidentiality character(1),
    fulltext_result character varying(10) DEFAULT NULL::character varying,
    external_id jsonb DEFAULT '{}'::jsonb,
    external_state jsonb DEFAULT '{}'::jsonb,
    departure_date timestamp without time zone,
    opinion_limit_date timestamp without time zone,
    barcode text,
    category_id character varying(32) NOT NULL,
    alt_identifier character varying(255),
    admission_date timestamp without time zone,
    process_limit_date timestamp without time zone,
    closing_date timestamp without time zone,
    alarm1_date timestamp without time zone,
    alarm2_date timestamp without time zone,
    flag_alarm1 character(1) DEFAULT 'N'::character varying,
    flag_alarm2 character(1) DEFAULT 'N'::character varying,
    model_id integer NOT NULL,
    version integer NOT NULL,
    integrations jsonb DEFAULT '{}'::jsonb NOT NULL,
    custom_fields jsonb,
    linked_resources jsonb DEFAULT '[]'::jsonb NOT NULL,
    retention_frozen boolean DEFAULT false NOT NULL,
    binding boolean
);


--
-- Name: res_mark_as_read; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.res_mark_as_read (
    res_id bigint,
    user_id integer NOT NULL,
    basket_id character varying(32)
);


--
-- Name: res_view_letterbox; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.res_view_letterbox AS
 SELECT r.res_id,
    r.type_id,
    r.policy_id,
    r.cycle_id,
    d.description AS type_label,
    d.doctypes_first_level_id,
    dfl.doctypes_first_level_label,
    dfl.css_style AS doctype_first_level_style,
    d.doctypes_second_level_id,
    dsl.doctypes_second_level_label,
    dsl.css_style AS doctype_second_level_style,
    r.format,
    r.typist,
    r.creation_date,
    r.modification_date,
    r.docserver_id,
    r.path,
    r.filename,
    r.fingerprint,
    r.filesize,
    r.status,
    r.work_batch,
    r.doc_date,
    r.external_id,
    r.departure_date,
    r.opinion_limit_date,
    r.barcode,
    r.initiator,
    r.destination,
    r.dest_user,
    r.confidentiality,
    r.category_id,
    r.alt_identifier,
    r.admission_date,
    r.process_limit_date,
    r.closing_date,
    r.alarm1_date,
    r.alarm2_date,
    r.flag_alarm1,
    r.flag_alarm2,
    r.subject,
    r.priority,
    r.locker_user_id,
    r.locker_time,
    r.custom_fields,
    r.retention_frozen,
    r.binding,
    r.model_id,
    r.version,
    r.integrations,
    r.linked_resources,
    r.fulltext_result,
    en.entity_label,
    en.entity_type AS entitytype
   FROM (((((public.res_letterbox r
     LEFT JOIN public.doctypes d ON ((r.type_id = d.type_id)))
     LEFT JOIN public.doctypes_first_level dfl ON ((d.doctypes_first_level_id = dfl.doctypes_first_level_id)))
     LEFT JOIN public.doctypes_second_level dsl ON ((d.doctypes_second_level_id = dsl.doctypes_second_level_id)))
     LEFT JOIN public.entities en ON (((r.destination)::text = (en.entity_id)::text)))
     LEFT JOIN public.docservers ds ON (((r.docserver_id)::text = (ds.docserver_id)::text)));


--
-- Name: resource_contacts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.resource_contacts (
    id integer NOT NULL,
    res_id integer NOT NULL,
    item_id integer NOT NULL,
    type character varying(32) NOT NULL,
    mode character varying(32) NOT NULL
);


--
-- Name: resource_contacts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.resource_contacts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: resource_contacts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.resource_contacts_id_seq OWNED BY public.resource_contacts.id;


--
-- Name: resources_folders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.resources_folders (
    id integer NOT NULL,
    folder_id integer NOT NULL,
    res_id integer NOT NULL
);


--
-- Name: resources_folders_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.resources_folders_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: resources_folders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.resources_folders_id_seq OWNED BY public.resources_folders.id;


--
-- Name: resources_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.resources_tags (
    id integer NOT NULL,
    res_id integer NOT NULL,
    tag_id integer NOT NULL
);


--
-- Name: resources_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.resources_tags_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: resources_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.resources_tags_id_seq OWNED BY public.resources_tags.id;


--
-- Name: search_templates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.search_templates (
    id integer NOT NULL,
    user_id integer NOT NULL,
    label character varying(255) NOT NULL,
    creation_date timestamp without time zone NOT NULL,
    query json NOT NULL
);


--
-- Name: search_templates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.search_templates_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: search_templates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.search_templates_id_seq OWNED BY public.search_templates.id;


--
-- Name: security_security_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.security_security_id_seq
    START WITH 600
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: security; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.security (
    security_id bigint DEFAULT nextval('public.security_security_id_seq'::regclass) NOT NULL,
    group_id character varying(32) NOT NULL,
    coll_id character varying(32) NOT NULL,
    where_clause text,
    maarch_comment text
);


--
-- Name: shipping_templates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.shipping_templates (
    id integer NOT NULL,
    label character varying(64) NOT NULL,
    description character varying(255) NOT NULL,
    options json DEFAULT '{}'::json,
    fee json DEFAULT '{}'::json,
    entities jsonb DEFAULT '{}'::jsonb,
    account jsonb DEFAULT '{}'::jsonb,
    subscriptions jsonb DEFAULT '[]'::jsonb,
    token_min_iat timestamp without time zone DEFAULT now()
);


--
-- Name: shipping_templates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.shipping_templates_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: shipping_templates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.shipping_templates_id_seq OWNED BY public.shipping_templates.id;


--
-- Name: shippings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.shippings (
    id integer NOT NULL,
    user_id integer NOT NULL,
    document_id integer NOT NULL,
    document_type character varying(255) NOT NULL,
    options json DEFAULT '{}'::json,
    fee double precision NOT NULL,
    recipient_entity_id integer NOT NULL,
    recipients jsonb DEFAULT '[]'::jsonb,
    account_id character varying(64) NOT NULL,
    creation_date timestamp without time zone NOT NULL,
    history jsonb DEFAULT '[]'::jsonb,
    attachments jsonb DEFAULT '[]'::jsonb,
    sending_id character varying(64),
    action_id integer
);


--
-- Name: shippings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.shippings_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: shippings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.shippings_id_seq OWNED BY public.shippings.id;


--
-- Name: status; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.status (
    identifier integer NOT NULL,
    id character varying(10) NOT NULL,
    label_status character varying(50) NOT NULL,
    is_system character(1) DEFAULT 'Y'::bpchar NOT NULL,
    img_filename character varying(255),
    maarch_module character varying(255) DEFAULT 'apps'::character varying NOT NULL,
    can_be_searched character(1) DEFAULT 'Y'::bpchar NOT NULL,
    can_be_modified character(1) DEFAULT 'Y'::bpchar NOT NULL
);


--
-- Name: status_identifier_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.status_identifier_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: status_identifier_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.status_identifier_seq OWNED BY public.status.identifier;


--
-- Name: status_images; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.status_images (
    id integer NOT NULL,
    image_name character varying(128) NOT NULL
);


--
-- Name: status_images_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.status_images_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: status_images_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.status_images_id_seq OWNED BY public.status_images.id;


--
-- Name: tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tags (
    id integer NOT NULL,
    label character varying(128) NOT NULL,
    description text,
    parent_id integer,
    creation_date timestamp without time zone DEFAULT now(),
    links jsonb DEFAULT '[]'::jsonb,
    usage text
);


--
-- Name: tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tags_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tags_id_seq OWNED BY public.tags.id;


--
-- Name: templates_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.templates_seq
    START WITH 110
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: templates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.templates (
    template_id bigint DEFAULT nextval('public.templates_seq'::regclass) NOT NULL,
    template_label character varying(255) DEFAULT NULL::character varying,
    template_comment character varying(255) DEFAULT NULL::character varying,
    template_content text,
    template_type character varying(32) DEFAULT 'HTML'::character varying NOT NULL,
    template_path character varying(255),
    template_file_name character varying(255),
    template_style character varying(255),
    template_datasource character varying(32),
    template_target character varying(255),
    template_attachment_type character varying(255) DEFAULT NULL::character varying,
    subject character varying(255),
    options jsonb DEFAULT '{}'::jsonb
);


--
-- Name: templates_association; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.templates_association (
    id integer NOT NULL,
    template_id bigint NOT NULL,
    value_field character varying(255) NOT NULL
);


--
-- Name: templates_association_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.templates_association_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: templates_association_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.templates_association_id_seq OWNED BY public.templates_association.id;


--
-- Name: tiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tiles (
    id integer NOT NULL,
    user_id integer NOT NULL,
    type text NOT NULL,
    view text NOT NULL,
    "position" integer NOT NULL,
    color text,
    parameters jsonb DEFAULT '{}'::jsonb NOT NULL
);


--
-- Name: tiles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tiles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tiles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tiles_id_seq OWNED BY public.tiles.id;


--
-- Name: unit_identifier; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.unit_identifier (
    message_id text NOT NULL,
    tablename text NOT NULL,
    res_id text NOT NULL,
    disposition text
);


--
-- Name: user_signatures; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_signatures (
    id integer NOT NULL,
    user_serial_id integer NOT NULL,
    signature_label character varying(255) DEFAULT NULL::character varying,
    signature_path character varying(255) DEFAULT NULL::character varying,
    signature_file_name character varying(255) DEFAULT NULL::character varying,
    fingerprint character varying(255) DEFAULT NULL::character varying
);


--
-- Name: user_signatures_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_signatures_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_signatures_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_signatures_id_seq OWNED BY public.user_signatures.id;


--
-- Name: usergroup_content; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.usergroup_content (
    user_id integer NOT NULL,
    group_id integer NOT NULL,
    role character varying(255)
);


--
-- Name: usergroups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.usergroups (
    id integer NOT NULL,
    group_id character varying(32) NOT NULL,
    group_desc character varying(255),
    can_index boolean DEFAULT false NOT NULL,
    indexation_parameters jsonb DEFAULT '{"actions": [], "entities": [], "keywords": []}'::jsonb NOT NULL,
    external_id jsonb DEFAULT '{}'::jsonb
);


--
-- Name: usergroups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.usergroups_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: usergroups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.usergroups_id_seq OWNED BY public.usergroups.id;


--
-- Name: usergroups_services; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.usergroups_services (
    group_id character varying NOT NULL,
    service_id character varying NOT NULL,
    parameters jsonb
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id integer NOT NULL,
    user_id character varying(128) NOT NULL,
    password character varying(255) DEFAULT NULL::character varying,
    firstname character varying(255) DEFAULT NULL::character varying,
    lastname character varying(255) DEFAULT NULL::character varying,
    phone character varying(32) DEFAULT NULL::character varying,
    mail character varying(255) DEFAULT NULL::character varying,
    initials character varying(32) DEFAULT NULL::character varying,
    preferences jsonb DEFAULT '{"documentEdition": "java"}'::jsonb NOT NULL,
    status character varying(10) DEFAULT 'OK'::character varying NOT NULL,
    password_modification_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    mode public.users_modes DEFAULT 'standard'::public.users_modes NOT NULL,
    refresh_token jsonb DEFAULT '[]'::jsonb NOT NULL,
    reset_token text,
    failed_authentication integer DEFAULT 0,
    locked_until timestamp without time zone,
    authorized_api jsonb DEFAULT '[]'::jsonb NOT NULL,
    external_id jsonb DEFAULT '{}'::jsonb,
    feature_tour jsonb DEFAULT '[]'::jsonb NOT NULL,
    absence jsonb
);


--
-- Name: users_baskets_preferences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users_baskets_preferences (
    id integer NOT NULL,
    user_serial_id integer NOT NULL,
    group_serial_id integer NOT NULL,
    basket_id character varying(32) NOT NULL,
    display boolean NOT NULL,
    color character varying(16)
);


--
-- Name: users_baskets_preferences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_baskets_preferences_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_baskets_preferences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_baskets_preferences_id_seq OWNED BY public.users_baskets_preferences.id;


--
-- Name: users_email_signatures; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users_email_signatures (
    id integer NOT NULL,
    user_id integer NOT NULL,
    html_body text NOT NULL,
    title character varying NOT NULL
);


--
-- Name: users_email_signatures_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_email_signatures_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_email_signatures_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_email_signatures_id_seq OWNED BY public.users_email_signatures.id;


--
-- Name: users_entities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users_entities (
    user_id integer NOT NULL,
    entity_id character varying(32) NOT NULL,
    user_role character varying(255),
    primary_entity character(1) DEFAULT 'N'::bpchar NOT NULL
);


--
-- Name: users_followed_resources; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users_followed_resources (
    id integer NOT NULL,
    res_id integer NOT NULL,
    user_id integer NOT NULL
);


--
-- Name: users_followed_resources_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_followed_resources_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_followed_resources_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_followed_resources_id_seq OWNED BY public.users_followed_resources.id;


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: users_pinned_folders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users_pinned_folders (
    id integer NOT NULL,
    folder_id integer NOT NULL,
    user_id integer NOT NULL
);


--
-- Name: users_pinned_folders_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_pinned_folders_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_pinned_folders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_pinned_folders_id_seq OWNED BY public.users_pinned_folders.id;


--
-- Name: acknowledgement_receipts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.acknowledgement_receipts ALTER COLUMN id SET DEFAULT nextval('public.acknowledgement_receipts_id_seq'::regclass);


--
-- Name: actions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.actions ALTER COLUMN id SET DEFAULT nextval('public.actions_id_seq'::regclass);


--
-- Name: address_sectors id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.address_sectors ALTER COLUMN id SET DEFAULT nextval('public.address_sectors_id_seq'::regclass);


--
-- Name: adr_attachments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.adr_attachments ALTER COLUMN id SET DEFAULT nextval('public.adr_attachments_id_seq'::regclass);


--
-- Name: adr_letterbox id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.adr_letterbox ALTER COLUMN id SET DEFAULT nextval('public.adr_letterbox_id_seq'::regclass);


--
-- Name: attachment_types id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attachment_types ALTER COLUMN id SET DEFAULT nextval('public.attachment_types_id_seq'::regclass);


--
-- Name: baskets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.baskets ALTER COLUMN id SET DEFAULT nextval('public.baskets_id_seq'::regclass);


--
-- Name: blacklist id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blacklist ALTER COLUMN id SET DEFAULT nextval('public.blacklist_id_seq'::regclass);


--
-- Name: configurations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.configurations ALTER COLUMN id SET DEFAULT nextval('public.configurations_id_seq'::regclass);


--
-- Name: contacts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contacts ALTER COLUMN id SET DEFAULT nextval('public.contacts_id_seq'::regclass);


--
-- Name: contacts_civilities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contacts_civilities ALTER COLUMN id SET DEFAULT nextval('public.contacts_civilities_id_seq'::regclass);


--
-- Name: contacts_custom_fields_list id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contacts_custom_fields_list ALTER COLUMN id SET DEFAULT nextval('public.contacts_custom_fields_list_id_seq'::regclass);


--
-- Name: contacts_filling id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contacts_filling ALTER COLUMN id SET DEFAULT nextval('public.contacts_filling_id_seq'::regclass);


--
-- Name: contacts_groups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contacts_groups ALTER COLUMN id SET DEFAULT nextval('public.contacts_groups_id_seq'::regclass);


--
-- Name: contacts_groups_lists id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contacts_groups_lists ALTER COLUMN id SET DEFAULT nextval('public.contacts_groups_lists_id_seq'::regclass);


--
-- Name: contacts_parameters id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contacts_parameters ALTER COLUMN id SET DEFAULT nextval('public.contacts_parameters_id_seq'::regclass);


--
-- Name: custom_fields id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_fields ALTER COLUMN id SET DEFAULT nextval('public.custom_fields_id_seq'::regclass);


--
-- Name: difflist_roles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.difflist_roles ALTER COLUMN id SET DEFAULT nextval('public.difflist_roles_id_seq'::regclass);


--
-- Name: docservers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.docservers ALTER COLUMN id SET DEFAULT nextval('public.docservers_id_seq'::regclass);


--
-- Name: emails id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.emails ALTER COLUMN id SET DEFAULT nextval('public.emails_id_seq'::regclass);


--
-- Name: entities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entities ALTER COLUMN id SET DEFAULT nextval('public.entities_id_seq'::regclass);


--
-- Name: entities_folders id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entities_folders ALTER COLUMN id SET DEFAULT nextval('public.entities_folders_id_seq'::regclass);


--
-- Name: exports_templates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exports_templates ALTER COLUMN id SET DEFAULT nextval('public.exports_templates_id_seq'::regclass);


--
-- Name: folders id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.folders ALTER COLUMN id SET DEFAULT nextval('public.folders_id_seq'::regclass);


--
-- Name: groupbasket id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.groupbasket ALTER COLUMN id SET DEFAULT nextval('public.groupbasket_id_seq'::regclass);


--
-- Name: indexing_models id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.indexing_models ALTER COLUMN id SET DEFAULT nextval('public.indexing_models_id_seq'::regclass);


--
-- Name: indexing_models_entities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.indexing_models_entities ALTER COLUMN id SET DEFAULT nextval('public.indexing_models_entities_id_seq'::regclass);


--
-- Name: indexing_models_fields id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.indexing_models_fields ALTER COLUMN id SET DEFAULT nextval('public.indexing_models_fields_id_seq'::regclass);


--
-- Name: list_templates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.list_templates ALTER COLUMN id SET DEFAULT nextval('public.list_templates_id_seq'::regclass);


--
-- Name: list_templates_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.list_templates_items ALTER COLUMN id SET DEFAULT nextval('public.list_templates_items_id_seq'::regclass);


--
-- Name: notes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notes ALTER COLUMN id SET DEFAULT nextval('public.notes_id_seq'::regclass);


--
-- Name: password_history id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.password_history ALTER COLUMN id SET DEFAULT nextval('public.password_history_id_seq'::regclass);


--
-- Name: password_rules id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.password_rules ALTER COLUMN id SET DEFAULT nextval('public.password_rules_id_seq'::regclass);


--
-- Name: redirected_baskets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.redirected_baskets ALTER COLUMN id SET DEFAULT nextval('public.redirected_baskets_id_seq'::regclass);


--
-- Name: registered_mail_issuing_sites id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.registered_mail_issuing_sites ALTER COLUMN id SET DEFAULT nextval('public.registered_mail_issuing_sites_id_seq'::regclass);


--
-- Name: registered_mail_issuing_sites_entities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.registered_mail_issuing_sites_entities ALTER COLUMN id SET DEFAULT nextval('public.registered_mail_issuing_sites_entities_id_seq'::regclass);


--
-- Name: registered_mail_number_range id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.registered_mail_number_range ALTER COLUMN id SET DEFAULT nextval('public.registered_mail_number_range_id_seq'::regclass);


--
-- Name: registered_mail_resources id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.registered_mail_resources ALTER COLUMN id SET DEFAULT nextval('public.registered_mail_resources_id_seq'::regclass);


--
-- Name: resource_contacts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_contacts ALTER COLUMN id SET DEFAULT nextval('public.resource_contacts_id_seq'::regclass);


--
-- Name: resources_folders id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resources_folders ALTER COLUMN id SET DEFAULT nextval('public.resources_folders_id_seq'::regclass);


--
-- Name: resources_tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resources_tags ALTER COLUMN id SET DEFAULT nextval('public.resources_tags_id_seq'::regclass);


--
-- Name: search_templates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.search_templates ALTER COLUMN id SET DEFAULT nextval('public.search_templates_id_seq'::regclass);


--
-- Name: shipping_templates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shipping_templates ALTER COLUMN id SET DEFAULT nextval('public.shipping_templates_id_seq'::regclass);


--
-- Name: shippings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shippings ALTER COLUMN id SET DEFAULT nextval('public.shippings_id_seq'::regclass);


--
-- Name: status identifier; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.status ALTER COLUMN identifier SET DEFAULT nextval('public.status_identifier_seq'::regclass);


--
-- Name: status_images id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.status_images ALTER COLUMN id SET DEFAULT nextval('public.status_images_id_seq'::regclass);


--
-- Name: tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags ALTER COLUMN id SET DEFAULT nextval('public.tags_id_seq'::regclass);


--
-- Name: templates_association id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.templates_association ALTER COLUMN id SET DEFAULT nextval('public.templates_association_id_seq'::regclass);


--
-- Name: tiles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tiles ALTER COLUMN id SET DEFAULT nextval('public.tiles_id_seq'::regclass);


--
-- Name: user_signatures id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_signatures ALTER COLUMN id SET DEFAULT nextval('public.user_signatures_id_seq'::regclass);


--
-- Name: usergroups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usergroups ALTER COLUMN id SET DEFAULT nextval('public.usergroups_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: users_baskets_preferences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users_baskets_preferences ALTER COLUMN id SET DEFAULT nextval('public.users_baskets_preferences_id_seq'::regclass);


--
-- Name: users_email_signatures id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users_email_signatures ALTER COLUMN id SET DEFAULT nextval('public.users_email_signatures_id_seq'::regclass);


--
-- Name: users_followed_resources id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users_followed_resources ALTER COLUMN id SET DEFAULT nextval('public.users_followed_resources_id_seq'::regclass);


--
-- Name: users_pinned_folders id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users_pinned_folders ALTER COLUMN id SET DEFAULT nextval('public.users_pinned_folders_id_seq'::regclass);


--
-- Data for Name: acknowledgement_receipts; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.acknowledgement_receipts (id, res_id, type, format, user_id, contact_id, creation_date, send_date, docserver_id, path, filename, fingerprint, cc, cci) FROM stdin;
\.


--
-- Data for Name: actions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.actions (id, keyword, label_action, id_status, is_system, action_page, component, history, parameters) FROM stdin;
3		Retourner au service Courrier	RET	N	confirm_status	confirmAction	Y	{}
5		Remettre en traitement	COU	N	confirm_status	confirmAction	Y	{}
6		Supprimer le courrier	DEL	N	confirm_status	confirmAction	Y	{}
19		Traiter courrier	COU	N	confirm_status	confirmAction	N	{}
20		Cloturer	END	N	close_mail	closeMailAction	Y	{"requiredFields": []}
21		Envoyer le courrier en validation	VAL	N	\N	confirmAction	Y	{}
22		Attribuer au service	NEW	N	confirm_status	confirmAction	Y	{}
24	indexing	Remettre en validation	VAL	N	confirm_status	confirmAction	Y	{}
36		Envoyer pour avis	EAVIS	N	send_docs_to_recommendation	sendToParallelOpinion	Y	{}
37		Donner un avis	_NOSTATUS_	N	avis_workflow_simple	giveOpinionParallelAction	Y	{}
114		Marquer comme lu		N	mark_as_read	resMarkAsReadAction	N	{}
400		Envoyer un AR	_NOSTATUS_	N	send_attachments_to_contact	createAcknowledgementReceiptsAction	Y	{"mode": "manual"}
405		Viser le courrier	_NOSTATUS_	N	confirm_status	confirmAction	Y	{}
407		Renvoyer pour traitement	COU	N	confirm_status	confirmAction	Y	{}
408		Refuser le visa et remonter le circuit	_NOSTATUS_	N	rejection_visa_previous	rejectVisaBackToPreviousAction	N	{}
410		Transmettre la réponse signée	EENV	N	interrupt_status	continueVisaCircuitAction	Y	{}
416		Valider et poursuivre le circuit	_NOSTATUS_	N	visa_workflow	continueVisaCircuitAction	Y	{"errorStatus": "END", "successStatus": "_NOSTATUS_"}
420		Classer sans suite	SSUITE	N	confirm_status	confirmAction	Y	{}
421		Retourner au Service Courrier	RET	N	confirm_status	confirmAction	Y	{}
431		Envoyer en GRC	GRC	N	confirm_status	confirmAction	Y	{}
500		Transférer au système d'archivage	SEND_SEDA	N	export_seda	sendToRecordManagementAction	Y	{"errorStatus": "END", "successStatus": "SEND_SEDA"}
501		Valider la réception du courrier par le système d'archivage	ACK_SEDA	N	check_acknowledgment	checkAcknowledgmentRecordManagementAction	Y	{}
502		Valider l'archivage du courrier	REPLY_SEDA	N	check_reply	checkReplyRecordManagementAction	Y	{}
503		Purger le courrier	DEL	N	purge_letter	confirmAction	Y	{}
504		Remise à zero du courrier	END	N	reset_letter	resetRecordManagementAction	Y	{}
505		Clôturer avec suivi	STDBY	N	close_mail	closeMailAction	Y	{"requiredFields": []}
506		Terminer le suivi	END	N	confirm_status	confirmAction	Y	{}
507		Acter l’envoi	ENVDONE	N	confirm_status	confirmAction	Y	{}
524		Activer la persistance	_NOSTATUS_	N	set_persistent_mode_on	enabledBasketPersistenceAction	N	{}
525		Désactiver la persistance	_NOSTATUS_	N	set_persistent_mode_off	disabledBasketPersistenceAction	N	{}
527		Envoyer sur la tablette (Maarch Parapheur)	ATT_MP	N	sendToExternalSignatureBook	sendExternalSignatoryBookAction	Y	{"errorStatus": "END", "successStatus": "ATT_MP"}
528		Générer les accusés de réception	_NOSTATUS_	N	create_acknowledgement_receipt	createAcknowledgementReceiptsAction	Y	{"mode": "both"}
529		Envoyer un pli postal Maileva	_NOSTATUS_	N	send_shipping	sendShippingAction	Y	{}
531		Envoyer pour annotation sur la tablette (Maarch Parapheur)	ATT_MP	N	sendToExternalSignatureBook	sendExternalSignatoryBookAction	Y	{}
532		Enregistrer et imprimer le recommandé	NEW	N	saveAndPrintRegisteredMail	saveAndPrintRegisteredMailAction	Y	{}
533		Enregistrer le recommandé et rester sur la page d'indexation	NEW	N	saveAndIndexRegisteredMail	saveAndIndexRegisteredMailAction	Y	{}
534		Imprimer le recommandé	_NOSTATUS_	N	printRegisteredMail	printRegisteredMailAction	Y	{}
535		Imprimer le descriptif de pli	_NOSTATUS_	N	printDepositList	printDepositListAction	Y	{}
536		Enregistrer le recommandé	NEW	N	saveRegisteredMail	saveRegisteredMailAction	Y	{}
537		Quitter le traitement	_NOSTATUS_	N	no_confirm_status	noConfirmAction	N	{}
530		Générer à nouveau les accusés de réception pour impression	_NOSTATUS_	N	create_acknowledgement_receipt	createAcknowledgementReceiptsAction	Y	{"mode": "both"}
4		Enregistrer les modifications	_NOSTATUS_	N	no_confirm_status	noConfirmAction	N	{}
414		Envoyer au parapheur interne	_NOSTATUS_	N	send_to_visa	sendSignatureBookAction	Y	{"errorStatus": "_NOSTATUS_", "successStatus": "EVIS"}
1	redirect	Rediriger	NEW	Y	redirect	redirectAction	Y	{"keepCopyForRedirection": false, "keepDestForRedirection:": false, "keepOtherRoleForRedirection": false}
18	redirect	Qualifier le courrier	NEW	N	redirect	redirectAction	Y	{"keepCopyForRedirection": false, "keepDestForRedirection:": false, "keepOtherRoleForRedirection": false}
\.


--
-- Data for Name: actions_categories; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.actions_categories (action_id, category_id) FROM stdin;
20	incoming
20	outgoing
20	internal
20	ged_doc
22	incoming
22	outgoing
22	internal
22	ged_doc
532	registeredMail
533	registeredMail
534	registeredMail
535	registeredMail
536	registeredMail
537	incoming
537	outgoing
537	internal
537	ged_doc
537	registeredMail
530	incoming
530	outgoing
530	internal
530	ged_doc
530	registeredMail
4	incoming
4	outgoing
4	internal
4	ged_doc
4	registeredMail
414	ged_doc
414	incoming
414	internal
414	outgoing
\.


--
-- Data for Name: actions_groupbaskets; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.actions_groupbaskets (id_action, where_clause, group_id, basket_id, used_in_basketlist, used_in_action_page, default_action_list) FROM stdin;
24		COURRIER	RetourCourrier	N	Y	Y
22		COURRIER	RetourCourrier	N	Y	N
531		COURRIER	RetourCourrier	N	Y	N
18		COURRIER	QualificationBasket	N	Y	Y
18		COURRIER	NumericBasket	N	Y	Y
19		AGENT	CopyMailBasket	N	Y	Y
114		AGENT	CopyMailBasket	Y	N	N
37		ELU	DdeAvisBasket	N	Y	Y
4		ELU	DdeAvisBasket	N	Y	N
19		AGENT	DepartmentBasket	N	Y	Y
20		AGENT	DepartmentBasket	Y	N	N
3		AGENT	DepartmentBasket	Y	N	N
1		AGENT	DepartmentBasket	Y	N	N
4		AGENT	RetAvisBasket	N	Y	Y
5		AGENT	RetAvisBasket	Y	Y	N
37		AGENT	DdeAvisBasket	N	Y	N
4		AGENT	DdeAvisBasket	N	Y	Y
4		AGENT	SupAvisBasket	N	Y	Y
5		AGENT	SupAvisBasket	Y	Y	N
19		AGENT	SuiviParafBasket	N	Y	Y
19		RESPONSABLE	MyBasket	N	Y	Y
1		RESPONSABLE	MyBasket	N	Y	N
414		RESPONSABLE	MyBasket	N	Y	N
36		RESPONSABLE	MyBasket	N	Y	N
3		RESPONSABLE	MyBasket	N	Y	N
20	closing_date IS NULL	RESPONSABLE	MyBasket	N	Y	N
506	closing_date IS NOT NULL	RESPONSABLE	MyBasket	N	Y	N
400		RESPONSABLE	MyBasket	N	Y	N
527		RESPONSABLE	MyBasket	Y	Y	N
19		RESPONSABLE	CopyMailBasket	N	Y	Y
114		RESPONSABLE	CopyMailBasket	Y	N	N
19		RESPONSABLE	ValidAnswerBasket	N	Y	Y
19		RESPONSABLE	DepartmentBasket	N	Y	Y
20		RESPONSABLE	DepartmentBasket	Y	N	N
3		RESPONSABLE	DepartmentBasket	Y	N	N
1		RESPONSABLE	DepartmentBasket	Y	N	N
37		RESPONSABLE	DdeAvisBasket	N	Y	N
4		RESPONSABLE	DdeAvisBasket	N	Y	Y
4		RESPONSABLE	SupAvisBasket	N	Y	Y
5		RESPONSABLE	SupAvisBasket	Y	Y	N
4		RESPONSABLE	RetAvisBasket	N	Y	Y
5		RESPONSABLE	RetAvisBasket	Y	Y	N
405		RESPONSABLE	ParafBasket	N	Y	Y
416		RESPONSABLE	ParafBasket	N	Y	N
407		RESPONSABLE	ParafBasket	N	Y	N
408		RESPONSABLE	ParafBasket	N	Y	N
410		RESPONSABLE	ParafBasket	N	Y	N
19		RESPONSABLE	SuiviParafBasket	N	Y	Y
19		AGENT	SendToSignatoryBook	N	Y	Y
5		AGENT	SendToSignatoryBook	Y	N	N
19		RESPONSABLE	SendToSignatoryBook	N	Y	Y
5		RESPONSABLE	SendToSignatoryBook	Y	N	N
19		ELU	MyBasket	N	Y	Y
19		ARCHIVISTE	ToArcBasket	N	Y	Y
500		ARCHIVISTE	ToArcBasket	Y	N	N
501		ARCHIVISTE	ToArcBasket	Y	N	N
502		ARCHIVISTE	SentArcBasket	Y	N	N
19		ARCHIVISTE	SentArcBasket	N	Y	Y
19		ARCHIVISTE	AckArcBasket	N	Y	Y
503		ARCHIVISTE	AckArcBasket	Y	N	N
504		ARCHIVISTE	AckArcBasket	Y	N	N
19		CABINET	SuiviBasket	N	Y	Y
524		CABINET	SuiviBasket	Y	N	N
525		CABINET	SuiviBasket	Y	N	N
19		SERVICE	ValidationBasket	N	Y	Y
19		AGENT	Maileva_Sended	N	Y	Y
22		RESP_COURRIER	ValidationBasket	Y	Y	Y
420		RESP_COURRIER	ValidationBasket	Y	Y	N
3		RESP_COURRIER	ValidationBasket	Y	Y	N
528		AGENT	AR_Create	Y	N	N
537		AGENT	AR_Create	N	Y	Y
507		AGENT	EenvBasket	Y	Y	N
20		AGENT	EenvBasket	Y	Y	N
19		AGENT	EenvBasket	N	Y	Y
530		AGENT	AR_AlreadySend	Y	N	N
537		AGENT	AR_AlreadySend	N	Y	Y
507		RESPONSABLE	EenvBasket	Y	Y	N
20		RESPONSABLE	EenvBasket	Y	Y	N
19		RESPONSABLE	EenvBasket	N	Y	Y
20		AGENT	MyBasket	N	Y	N
505		AGENT	MyBasket	N	Y	N
414		AGENT	MyBasket	N	Y	N
36		AGENT	MyBasket	N	Y	N
1		AGENT	MyBasket	N	Y	N
19		AGENT	MyBasket	N	Y	Y
18		AGENT	outlook_mails	N	Y	Y
18		DIRECTEUR	outlook_mails	N	Y	Y
18		RESPONSABLE	outlook_mails	N	Y	Y
18		COURRIER	outlook_mails	N	Y	Y
18		RESP_COURRIER	outlook_mails	N	Y	Y
527	\N	AGENT	MyBasket	Y	Y	N
\.


--
-- Data for Name: address_sectors; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.address_sectors (id, address_number, address_street, address_postcode, address_town, label, ban_id) FROM stdin;
\.


--
-- Data for Name: adr_attachments; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.adr_attachments (id, res_id, type, docserver_id, path, filename, fingerprint) FROM stdin;
1	1	PDF	CONVERT_ATTACH	2026/08/0001/	0001_1448593683.pdf	ffffae4bcf477847992f9c7ef7a66f13226070e5c2944687b33c9ba6aa2189b9
2	1	TNL	TNL_ATTACH	2026/08/0001/	0001_1212320736.png	\N
3	2	PDF	CONVERT_ATTACH	2026/08/0001/	0002_161267485.pdf	ffffae4bcf477847992f9c7ef7a66f13226070e5c2944687b33c9ba6aa2189b9
4	2	TNL	TNL_ATTACH	2026/08/0001/	0002_1965294297.png	\N
5	3	PDF	CONVERT_ATTACH	2026/08/0001/	0003_287348718.pdf	ffffae4bcf477847992f9c7ef7a66f13226070e5c2944687b33c9ba6aa2189b9
6	3	TNL	TNL_ATTACH	2026/08/0001/	0003_2103994405.png	\N
7	4	PDF	CONVERT_ATTACH	2026/08/0001/	0004_1970391210.pdf	ffffae4bcf477847992f9c7ef7a66f13226070e5c2944687b33c9ba6aa2189b9
8	4	TNL	TNL_ATTACH	2026/08/0001/	0004_17659559.png	\N
9	5	PDF	CONVERT_ATTACH	2026/08/0001/	0005_628864923.pdf	ffffae4bcf477847992f9c7ef7a66f13226070e5c2944687b33c9ba6aa2189b9
10	5	TNL	TNL_ATTACH	2026/08/0001/	0005_2086642480.png	\N
11	6	PDF	CONVERT_ATTACH	2026/08/0001/	0006_177961236.pdf	f4e9354bcf45a66447553e4ee4f1d001a00fad00c14f343aadd7e6bea27dc04a
12	7	PDF	CONVERT_ATTACH	2026/08/0001/	0007_804666541.pdf	ffffae4bcf477847992f9c7ef7a66f13226070e5c2944687b33c9ba6aa2189b9
13	7	TNL	TNL_ATTACH	2026/08/0001/	0006_1200520730.png	\N
14	8	PDF	CONVERT_ATTACH	2026/08/0001/	0008_118687705.pdf	d43aff5623f3f8726b5f38698686af0cb81bd4114cfd4ac29f113bc6a0edde55
\.


--
-- Data for Name: adr_letterbox; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.adr_letterbox (id, res_id, type, version, docserver_id, path, filename, fingerprint) FROM stdin;
1	106	PDF	1	CONVERT_MLB	2026/08/0001/	0001_1104405154.pdf	ffffae4bcf477847992f9c7ef7a66f13226070e5c2944687b33c9ba6aa2189b9
2	107	PDF	1	CONVERT_MLB	2026/08/0001/	0002_378503467.pdf	ffffae4bcf477847992f9c7ef7a66f13226070e5c2944687b33c9ba6aa2189b9
3	107	TNL	1	TNL_MLB	2026/08/0001/	0001_831071875.png	\N
4	108	PDF	1	CONVERT_MLB	2026/08/0001/	0003_2000149193.pdf	ffffae4bcf477847992f9c7ef7a66f13226070e5c2944687b33c9ba6aa2189b9
5	109	PDF	1	CONVERT_MLB	2026/08/0001/	0004_1351236963.pdf	ffffae4bcf477847992f9c7ef7a66f13226070e5c2944687b33c9ba6aa2189b9
6	109	TNL	1	TNL_MLB	2026/08/0001/	0002_1481590661.png	\N
8	110	PDF	1	CONVERT_MLB	2026/08/0001/	0005_1897726117.pdf	ffffae4bcf477847992f9c7ef7a66f13226070e5c2944687b33c9ba6aa2189b9
\.


--
-- Data for Name: attachment_types; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.attachment_types (id, type_id, label, visible, email_link, signable, signed_by_default, icon, chrono, version_enabled, new_version_default) FROM stdin;
2	response_project	Projet de réponse	t	t	t	f	R	t	t	t
3	signed_response	Réponse signée	f	t	f	f		t	t	t
4	simple_attachment	Pièce jointe	t	f	f	f	PJ	f	t	t
5	incoming_mail_attachment	Pièce jointe capturée	t	f	f	f		f	t	t
6	outgoing_mail	Courrier départ spontané	t	f	t	f	DS	t	t	t
7	summary_sheet	Fiche de liaison	f	f	f	f		t	t	t
8	acknowledgement_record_management	Accusé de réception (Archivage)	f	f	f	f		t	t	t
9	reply_record_management	Réponse au transfert (Archivage)	f	f	f	f		t	t	t
10	shipping_deposit_proof	Preuve de dépôt Maileva	f	f	f	f	M	f	f	f
11	shipping_acknowledgement_of_receipt	Accusé de réception Maileva	f	f	f	f	M	f	f	f
\.


--
-- Data for Name: basket_persistent_mode; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.basket_persistent_mode (res_id, user_id, is_persistent) FROM stdin;
\.


--
-- Data for Name: baskets; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.baskets (id, coll_id, basket_id, basket_name, basket_desc, basket_clause, is_visible, enabled, basket_order, color, basket_res_order, flag_notif) FROM stdin;
5	letterbox_coll	CopyMailBasket	Courriers en copie	Courriers en copie non clos ou sans suite	(res_id in (select res_id from listinstance WHERE item_type = 'user_id' and item_id = @user_id and item_mode = 'cc') or res_id in (select res_id from listinstance WHERE item_type = 'entity_id' and item_mode = 'cc' and item_id in (@my_entities_id))) and status not in ( 'DEL', 'END', 'SSUITE') and res_id not in (select res_id from res_mark_as_read WHERE user_id = @user_id)	Y	Y	7	\N	res_id desc	N
9	letterbox_coll	DdeAvisBasket	Avis : Avis à émettre	Courriers nécessitant un avis	status = 'EAVIS' AND res_id IN (SELECT res_id FROM listinstance WHERE item_type = 'user_id' AND item_id = @user_id AND item_mode = 'avis' and process_date is NULL)	Y	Y	8	\N	res_id desc	N
8	letterbox_coll	RetourCourrier	Retours Courrier	Courriers retournés au service Courrier	STATUS='RET'	Y	Y	4	\N	res_id desc	N
6	letterbox_coll	AR_Create	AR - A Envoyer	AR non envoyés	dest_user = @user_id AND res_id NOT IN(select distinct res_id from acknowledgement_receipts) and status not in ('END') and category_id = 'incoming'	Y	Y	5	\N	res_id desc	N
11	letterbox_coll	RetAvisBasket	Avis : Retours partiels	Courriers avec avis reçus	status='EAVIS' and ((dest_user = @user_id) OR (DEST_USER IN (select user_id from users_entities WHERE entity_id IN( @my_entities)) or DESTINATION in (@subentities[@my_entities]))) and res_id IN (SELECT res_id FROM listinstance WHERE item_mode = 'avis' and difflist_type = 'entity_id' and process_date is not NULL and res_view_letterbox.res_id = res_id group by res_id)	Y	Y	10	\N	res_id desc	N
12	letterbox_coll	ValidationBasket	Attributions à vérifier	Courriers signalés en attente d'instruction pour les services	status='VAL'	Y	Y	11	\N	res_id desc	N
13	letterbox_coll	InValidationBasket	Courriers signalés en attente d'instruction	Courriers signalés en attente d'instruction par le responsable	destination in (@my_entities, @subentities[@my_entities]) and status='VAL'	Y	Y	12	\N	res_id desc	N
14	letterbox_coll	LateMailBasket	Courriers en retard	Courriers en retard	destination in (@my_entities, @subentities[@my_primary_entity]) and (status <> 'DEL' AND status <> 'REP') and (now() > process_limit_date)	Y	Y	13	\N	res_id desc	N
15	letterbox_coll	DepartmentBasket	Courriers de ma direction	Bannette de supervision	destination in (@my_entities, @subentities[@my_primary_entity]) and (status <> 'DEL' AND status <> 'REP' and status <> 'VAL')	Y	Y	14	\N	res_id desc	N
16	letterbox_coll	ParafBasket	Parapheur électronique	Courriers à viser ou signer dans mon parapheur	status in ('ESIG', 'EVIS') AND ((res_id, @user_id) IN (SELECT res_id, item_id FROM listinstance WHERE difflist_type = 'VISA_CIRCUIT' and process_date ISNULL and res_view_letterbox.res_id = res_id order by listinstance_id asc limit 1))	Y	Y	15	\N	res_id desc	N
17	letterbox_coll	SuiviParafBasket	Courriers en circuit de visa/signature	Courriers en circulation dans les parapheurs électroniques	status in ('ESIG', 'EVIS') AND dest_user = @user_id	Y	Y	16	\N	res_id desc	N
18	letterbox_coll	SendToSignatoryBook	Courriers envoyés au parapheur Maarch en attente ou rejetés	Courriers envoyés au parapheur Maarch en attente ou rejetés	(status = 'ATT_MP' or status = 'REJ_SIGN') AND dest_user = @user_id	Y	Y	17	\N	res_id desc	Y
19	letterbox_coll	Maileva_Sended	Courriers transmis via Maileva	Courriers transmis via Maileva	dest_user = @user_id AND res_id IN(SELECT distinct r.res_id_master from res_attachments r inner join shippings s on s.document_id = r.res_id) and status not in ('END')	Y	Y	18	\N	res_id desc	N
20	letterbox_coll	ToArcBasket	Courriers à archiver	Courriers arrivés en fin de DUC à envoyer en archive intermédiaire	status = 'EXP_SEDA' OR status = 'END' OR status = 'SEND_SEDA'	Y	Y	19	\N	res_id desc	N
21	letterbox_coll	SentArcBasket	Courriers en cours d'archivage	Courriers envoyés au SAE, en attente de réponse de transfert	status='ACK_SEDA'	Y	Y	20	\N	res_id desc	N
23	letterbox_coll	GedSampleBasket	Contrats arrivant à expiration (date fin contrat < 3mois)	Contrats arrivant à expiration (date fin contrat < 3mois)	custom_fields->>'1' is not null and custom_fields->>'1' <> '' and date(custom_fields->>'1') < now()+ interval '3 months'	Y	Y	22	\N	res_id desc	Y
7	letterbox_coll	AR_AlreadySend	AR transmis	AR en masse : transmis	dest_user = @user_id AND ((res_id IN(SELECT distinct res_id FROM acknowledgement_receipts WHERE creation_date is not null AND send_date is not null) and status not in ('END')) OR res_id IN (SELECT distinct res_id FROM acknowledgement_receipts WHERE creation_date is not null AND send_date is null ))	Y	Y	6	\N	res_id desc	N
24	letterbox_coll	IntervBasket	Demandes d''intervention voirie à traiter	Demandes d''intervention voirie à traiter	status in ('NEW', 'COU', 'STDBY', 'ENVDONE') and dest_user = @user_id and type_id = 1202	Y	Y	23	\N	res_id desc	Y
1	letterbox_coll	QualificationBasket	Courriers à qualifier	Bannette de qualification	status='INIT'	Y	Y	0	\N	res_id desc	N
2	letterbox_coll	NumericBasket	Plis numériques à qualifier	Plis numériques à qualifier	status = 'NUMQUAL'	Y	Y	1	\N	res_id desc	N
3	letterbox_coll	EenvBasket	Courriers à envoyer	Courriers visés/signés prêts à être envoyés	status='EENV' and dest_user = @user_id	Y	Y	2	\N	res_id desc	N
22	letterbox_coll	AckArcBasket	Courriers archivés	Courriers archivés et acceptés dans le SAE	status='REPLY_SEDA'	Y	Y	21	\N	res_id desc	N
4	letterbox_coll	MyBasket	Courriers à traiter	Bannette de traitement	status in ('NEW', 'COU', 'STDBY', 'ENVDONE') and dest_user = @user_id	Y	Y	3	\N	res_id desc	Y
10	letterbox_coll	SupAvisBasket	Avis : En attente de réponse	Courriers en attente d'avis	status='EAVIS' and ((dest_user = @user_id) OR (DEST_USER IN (select user_id from users_entities WHERE entity_id IN( @my_entities)) or DESTINATION in (@subentities[@my_entities]))) and res_id NOT IN (SELECT res_id FROM listinstance WHERE item_mode = 'avis' and difflist_type = 'entity_id' and process_date is not NULL and res_view_letterbox.res_id = res_id group by res_id) AND res_id IN (SELECT res_id FROM listinstance WHERE item_mode = 'avis' and difflist_type = 'entity_id' and process_date is NULL and res_view_letterbox.res_id = res_id group by res_id)	Y	Y	9	\N	res_id desc	N
25	letterbox_coll	outlook_mails	Courriels importés	Bannette des courriels importés de MS Outlook	status in ('OUT') and typist = @user_id	Y	Y	1	\N	res_id desc	N
\.


--
-- Data for Name: blacklist; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.blacklist (id, term) FROM stdin;
\.


--
-- Data for Name: configurations; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.configurations (id, privilege, value) FROM stdin;
1	admin_email_server	{"auth": true, "from": "test.maarch.courrier@maarch.org", "host": "smtp.globalsp.com", "port": 587, "type": "smtp", "user": "", "online": false, "secure": "tls", "charset": "utf-8", "password": ""}
2	admin_search	{"listEvent": {"defaultTab": "dashboard"}, "listDisplay": {"subInfos": [{"icon": "fa-traffic-light", "value": "getPriority", "cssClasses": ["align_leftData"]}, {"icon": "fa-calendar", "value": "getCreationAndProcessLimitDates", "cssClasses": ["align_leftData"]}, {"icon": "fa-sitemap", "value": "getAssignee", "cssClasses": ["align_leftData"]}, {"icon": "fa-suitcase", "value": "getDoctype", "cssClasses": ["align_leftData"]}, {"icon": "fa-user", "value": "getRecipients", "cssClasses": ["align_leftData"]}, {"icon": "fa-book", "value": "getSenders", "cssClasses": ["align_leftData"]}], "templateColumns": 6}}
3	admin_sso	{"url": "", "mapping": [{"ssoId": "", "maarchId": "login"}]}
4	admin_document_editors	{"java": [], "default": "", "onlyoffice": {"ssl": true, "uri": "onlyoffice7.maarchcourrier.com", "port": "443", "token": "", "authorizationHeader": "Authorization"}}
5	admin_parameters_watermark	{"font": "helvetica", "posX": 30, "posY": 35, "size": 10, "text": "Copie conforme de [alt_identifier] le [date_now] [hour_now]", "angle": 0, "color": [20, 192, 30], "enabled": true, "opacity": 0.5}
6	admin_shippings	{"uri": "", "authUri": "", "enabled": false}
7	admin_addin_outlook	{"typeId": 1203, "statusId": 42, "indexingModelId": 8, "attachmentTypeId": 5}
8	admin_organization_email_signatures	{"signatures": [{"label": "Signature Organisation", "content": "<div><span><span><strong>[user.firstname] </strong></span></span><span>[user.lastname]</span></div>\\\\n<div><span><span><span><span><strong>[userPrimaryEntity.entity_label]</strong></span></span></span></span></div>\\\\n<div><span>[user.phone]</span></div>\\\\n<div><span><span>[userPrimaryEntity.address_number] [userPrimaryEntity.address_street], [userPrimaryEntity.address_postcode] [userPrimaryEntity.address_town]</span></span></div>\\\\n<div>&nbsp;</div>"}]}
9	admin_export_seda	{}
10	admin_mercure	{"mws": {"url": "", "login": "", "password": "", "tokenMws": "", "loginMaarch": "", "passwordMaarch": ""}, "enabledLad": true, "mwsLadPriority": false}
\.


--
-- Data for Name: contacts; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.contacts (id, civility, firstname, lastname, company, department, function, address_number, address_street, address_additional1, address_additional2, address_postcode, address_town, address_country, email, phone, communication_means, notes, creator, creation_date, modification_date, enabled, custom_fields, external_id, sector, lad_indexation) FROM stdin;
1	1	Jean-Louis	ERCOLANI	MAARCH		Directeur Général	11	Boulevard du Sud-Est			99000	MAARCH LES BAINS	France	dev.maarch@maarch.org		\N	Editeur du logiciel libre Maarch	21	2015-04-24 12:43:54.97424	2016-07-25 16:28:38.498185	t	{}	{}	\N	f
4	1	Nicolas	MARTIN	Préfecture de Maarch Les Bains	\N	\N	13	RUE LA PREFECTURE	\N	\N	99000	MAARCH LES BAINS	\N	\N	\N	{"url": "https://cchaplin:maarch@demo.maarchcourrier.com"}	\N	21	2018-04-18 12:43:54.97424	2020-03-24 15:06:58.16582	t	\N	{"m2m": "45239273100025/COU"}	\N	f
5	2	Brigitte	BERGER	ACME		Directrice Générale	25	PLACE DES MIMOSAS	\N		99000	MAARCH LES BAINS	FRANCE	dev.maarch@maarch.org		\N	Archivage et Conservation des Mémoires Electroniques	21	2015-04-24 12:43:54.97424	2016-07-25 16:28:38.498185	t	{}	{}	\N	f
6	1	Bernard	PASCONTENT				25	route de Pampelone	\N		99000	MAARCH-LES-BAINS		bernard.pascontent@gmail.com	06 08 09 07 55	\N		21	2019-03-20 13:59:09.23436	\N	t	{}	{}	\N	f
7	1	Jacques	DUPONT				1	rue du Peuplier	\N		92000	NANTERRE				\N		21	2019-03-20 13:59:09.23436	\N	t	{}	{}	\N	f
8	1	Pierre	BRUNEL				5	allée des Pommiers	\N		99000	MAARCH-LES-BAINS		dev.maarch@maarch.org	06 08 09 07 55	\N		21	2019-03-20 13:59:09.23436	\N	t	{}	{}	\N	f
9	1	Eric	MACKIN				13	rue du Square Carré	\N		99000	MAARCH-LES-BAINS			06 11 12 13 14	\N		21	2019-03-20 13:59:09.23436	\N	t	{}	{}	\N	f
10	2	Carole	COTIN	MAARCH		Directrice Administrative et Qualité	11	Boulevard du Sud-Est	\N		99000	MAARCH LES BAINS	FRANCE	dev.maarch@maarch.org		\N	Editeur du logiciel libre Maarch	21	2015-04-24 12:43:54.97424	2016-07-25 16:28:38.498185	t	{}	{}	\N	f
11	1	Martin Donald	PELLE				17	rue de la Demande	\N		99000	MAARCH-LES-BAINS		dev.maarch@maarch.org	01 23 24 21 22	\N		21	2019-03-20 13:59:09.23436	\N	t	{}	{}	\N	f
12	\N	\N	\N	NGSign	\N	\N	\N	\N	\N	\N	\N	\N	\N	testmaarchngsign@yopmail.com	\N	\N	\N	9	2026-08-09 00:08:06.006482	\N	t	{}	{}	\N	f
\.


--
-- Data for Name: contacts_civilities; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.contacts_civilities (id, label, abbreviation) FROM stdin;
1	Monsieur	M.
2	Madame	Mme
3	Mademoiselle	Mlle
4	Messieurs	MM.
5	Mesdames	Mmes
6	Mesdemoiselles	Mlles
\.


--
-- Data for Name: contacts_custom_fields_list; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.contacts_custom_fields_list (id, label, type, "values") FROM stdin;
\.


--
-- Data for Name: contacts_filling; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.contacts_filling (id, enable, first_threshold, second_threshold) FROM stdin;
1	t	33	66
\.


--
-- Data for Name: contacts_groups; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.contacts_groups (id, label, description, owner, entities) FROM stdin;
\.


--
-- Data for Name: contacts_groups_lists; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.contacts_groups_lists (id, contacts_groups_id, correspondent_id, correspondent_type) FROM stdin;
\.


--
-- Data for Name: contacts_parameters; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.contacts_parameters (id, identifier, mandatory, filling, searchable, displayable) FROM stdin;
1	civility	f	f	f	f
2	firstname	f	t	t	t
3	lastname	t	t	t	t
4	company	t	f	t	t
5	department	f	f	f	f
6	function	f	f	f	f
7	addressNumber	f	f	t	t
8	addressStreet	f	t	t	t
9	addressAdditional1	f	f	f	f
10	addressAdditional2	f	f	f	f
11	addressPostcode	f	t	t	t
12	addressTown	f	t	t	t
13	addressCountry	f	f	f	f
14	email	f	t	f	f
15	phone	f	t	f	f
16	notes	f	f	f	f
17	sector	f	f	f	f
\.


--
-- Data for Name: convert_stack; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.convert_stack (coll_id, res_id, convert_format, cnt_retry, status, work_batch, regex) FROM stdin;
\.


--
-- Data for Name: custom_fields; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.custom_fields (id, label, type, mode, "values") FROM stdin;
1	Date de fin de contrat	date	form	[]
2	Adresse d'intervention	banAutocomplete	form	[]
3	Nature	select	form	["Courrier simple", "Courriel", "Courrier suivi", "Courrier avec AR", "Fax", "Chronopost", "Fedex", "Courrier AR", "Coursier", "Pli numérique", "Autre"]
4	Référence courrier expéditeur	string	form	[]
5	Num recommandé	string	form	[]
\.


--
-- Data for Name: difflist_roles; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.difflist_roles (id, role_id, label, keep_in_list_instance) FROM stdin;
1	dest	Destinataire	f
2	copy	En copie	t
3	visa	Pour visa	f
4	sign	Pour signature	f
5	avis	Pour avis	f
6	avis_copy	En copie (avis)	f
7	avis_info	Pour information (avis)	f
\.


--
-- Data for Name: difflist_types; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.difflist_types (difflist_type_id, difflist_type_label, difflist_type_roles, allow_entities, is_system) FROM stdin;
entity_id	Diffusion aux services	dest copy avis	Y	Y
type_id	Diffusion selon le type de document	dest copy	Y	Y
VISA_CIRCUIT	Circuit de visa	visa sign 	N	Y
AVIS_CIRCUIT	Circuit d'avis	avis 	N	Y
\.


--
-- Data for Name: docserver_types; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.docserver_types (docserver_type_id, docserver_type_label, enabled, fingerprint_mode) FROM stdin;
DOC	Documents numériques	Y	SHA512
CONVERT	Conversions de formats	Y	SHA256
FULLTEXT	Plein texte	Y	SHA256
TNL	Miniatures	Y	NONE
TEMPLATES	Modèles de documents	Y	NONE
ARCHIVETRANSFER	Archives numériques	Y	SHA256
ACKNOWLEDGEMENT_RECEIPTS	Accusés de réception	Y	\N
MIGRATION	Sauvegarde des migrations	Y	\N
\.


--
-- Data for Name: docservers; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.docservers (id, docserver_id, docserver_type_id, device_label, is_readonly, is_encrypted, size_limit_number, actual_size_number, path_template, creation_date, coll_id) FROM stdin;
1	FASTHD_AI	DOC	Dépôt documentaire issue d'imports de masse	Y	f	50000000000	1	/opt/maarch/docservers/ai/	2011-01-07 13:43:48.696644	letterbox_coll
8	FULLTEXT_MLB	FULLTEXT	Dépôt de l'extraction plein texte des documents numérisés	N	f	50000000000	0	/opt/maarch/docservers/fulltext_resources/	2015-03-16 14:47:49.197164	letterbox_coll
9	FULLTEXT_ATTACH	FULLTEXT	Dépôt de l'extraction plein texte des pièces jointes	N	f	50000000000	0	/opt/maarch/docservers/fulltext_attachments/	2015-03-16 14:47:49.197164	attachments_coll
11	ARCHIVETRANSFER	ARCHIVETRANSFER	Dépôt des archives numériques	N	f	50000000000	1	/opt/maarch/docservers/archive_transfer/	2017-01-13 14:47:49.197164	archive_transfer_coll
10	TEMPLATES	TEMPLATES	Dépôt des modèles de documents	N	f	50000000000	71511	/opt/maarch/docservers/templates/	2012-04-01 14:49:05.095119	templates
12	ACKNOWLEDGEMENT_RECEIPTS	ACKNOWLEDGEMENT_RECEIPTS	Dépôt des AR	N	f	50000000000	0	/opt/maarch/docservers/acknowledgement_receipts/	2019-04-19 22:22:22.201904	letterbox_coll
13	MIGRATION	MIGRATION	Dêpot de sauvegarde des migrations	N	f	50000000000	0	/opt/maarch/docservers/migration/	2023-09-05 22:22:22.201904	migration
6	TNL_MLB	TNL	Dépôt des maniatures des documents numérisés	N	f	50000000000	0	/opt/maarch/docservers/thumbnails_resources/	2015-03-16 14:47:49.197164	letterbox_coll
2	FASTHD_MAN	DOC	Dépôt documentaire de numérisation manuelle	N	f	50000000000	1290730	/opt/maarch/docservers/resources/	2011-01-13 14:47:49.197164	letterbox_coll
4	CONVERT_MLB	CONVERT	Dépôt des formats des documents numérisés	N	f	50000000000	0	/opt/maarch/docservers/convert_resources/	2015-03-16 14:47:49.197164	letterbox_coll
7	TNL_ATTACH	TNL	Dépôt des maniatures des pièces jointes	N	f	50000000000	0	/opt/maarch/docservers/thumbnails_attachments/	2015-03-16 14:47:49.197164	attachments_coll
3	FASTHD_ATTACH	DOC	Dépôt des pièces jointes	N	f	50000000000	1	/opt/maarch/docservers/attachments/	2011-01-13 14:47:49.197164	attachments_coll
5	CONVERT_ATTACH	CONVERT	Dépôt des formats des pièces jointes	N	f	50000000000	0	/opt/maarch/docservers/convert_attachments/	2015-03-16 14:47:49.197164	attachments_coll
\.


--
-- Data for Name: doctypes; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.doctypes (coll_id, type_id, description, enabled, doctypes_first_level_id, doctypes_second_level_id, retention_final_disposition, retention_rule, action_current_use, duration_current_use, process_delay, delay1, delay2, process_mode) FROM stdin;
	101	Abonnements – documentation – archives	Y	1	1	destruction	compta_3_03	\N	365	30	14	1	NORMAL
	102	Convocation	Y	1	1	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	103	Demande de documents	Y	1	1	destruction	compta_3_03	\N	365	30	14	1	NORMAL
	104	Demande de fournitures et matériels	Y	1	1	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	105	Demande de RDV	Y	1	1	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	106	Demande de renseignements	Y	1	1	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	107	Demande mise à jour de fichiers	Y	1	1	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	108	Demande Multi-Objet	Y	1	1	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	109	Installation provisoire dans un équipement ville	Y	1	1	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	110	Invitation	Y	1	1	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	111	Rapport – Compte-rendu – Bilan	Y	1	1	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	112	Réservation d'un local communal et scolaire	Y	1	1	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	201	Pétition	Y	1	2	destruction	compta_3_03	\N	365	15	14	1	NORMAL
	202	Communication	Y	1	2	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	203	Politique	Y	1	2	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	204	Relations et solidarité internationales 	Y	1	2	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	205	Remerciements et félicitations	Y	1	2	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	206	Sécurité	Y	1	2	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	207	Suggestion	Y	1	2	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	301	Culture	Y	1	3	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	302	Demande scolaire hors inscription et dérogation	Y	1	3	destruction	compta_3_03	\N	365	60	14	1	SVR
	303	Éducation nationale	Y	1	3	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	304	Jeunesse	Y	1	3	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	305	Lycées et collèges	Y	1	3	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	306	Parentalité	Y	1	3	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	307	Petite Enfance	Y	1	3	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	308	Sport	Y	1	3	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	401	Contestation financière	Y	1	4	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	402	Contrat de prêt	Y	1	4	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	403	Garantie d'emprunt	Y	1	4	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	404	Paiement	Y	1	4	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	405	Quotient familial	Y	1	4	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	406	Subvention	Y	1	4	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	407	Facture ou avoir	Y	1	4	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	408	Proposition financière	Y	1	4	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	501	Hospitalisation d'office	Y	1	5	destruction	compta_3_03	\N	365	2	14	1	NORMAL
	502	Mise en demeure	Y	1	5	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	503	Plainte	Y	1	5	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	504	Recours contentieux	Y	1	5	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	505	Recours gracieux et réclamations	Y	1	5	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	601	Débits de boisson	Y	1	6	destruction	compta_3_03	\N	365	60	14	1	SVR
	602	Demande d’État Civil	Y	1	6	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	603	Élections	Y	1	6	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	604	Étrangers	Y	1	6	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	605	Marché	Y	1	6	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	606	Médaille du travail	Y	1	6	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	607	Stationnement taxi	Y	1	6	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	608	Vente au déballage	Y	1	6	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	701	Arrêts de travail et maladie	Y	1	7	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	702	Assurance du personnel	Y	1	7	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	703	Candidature	Y	1	7	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	704	Carrière	Y	1	7	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	705	Conditions de travail santé	Y	1	7	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	706	Congés exceptionnels et concours	Y	1	7	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	707	Formation	Y	1	7	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	708	Instances RH	Y	1	7	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	709	Retraite	Y	1	7	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	710	Stage	Y	1	7	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	711	Syndicats	Y	1	7	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	801	Aide à domicile	Y	1	8	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	802	Aide Financière	Y	1	8	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	803	Animations retraités	Y	1	8	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	804	Domiciliation	Y	1	8	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	805	Dossier de logement	Y	1	8	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	806	Expulsion	Y	1	8	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	807	Foyer	Y	1	8	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	808	Obligation alimentaire	Y	1	8	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	809	RSA	Y	1	8	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	810	Scolarisation à domicile	Y	1	8	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	901	Aire d'accueil des gens du voyage	Y	1	9	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	902	Assainissement	Y	1	9	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	903	Assurance et sinistre	Y	1	9	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	904	Autorisation d'occupation du domaine public	Y	1	9	destruction	compta_3_03	\N	365	60	14	1	SVR
	905	Contrat et convention hors marchés publics	Y	1	9	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	906	Détention de chiens dangereux	Y	1	9	destruction	compta_3_03	\N	365	60	14	1	SVR
	907	Espaces verts – Environnement – Développement durable	Y	1	9	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	908	Hygiène et Salubrité	Y	1	9	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	909	Marchés Publics	Y	1	9	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	910	Mobiliers urbains	Y	1	9	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	911	NTIC	Y	1	9	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	912	Opération d'aménagement	Y	1	9	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	913	Patrimoine	Y	1	9	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	914	Problème de voisinage	Y	1	9	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	915	Propreté	Y	1	9	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	916	Stationnement et circulation	Y	1	9	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	917	Transports	Y	1	9	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	918	Travaux	Y	1	9	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	1001	Alignement	Y	1	10	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	1002	Avis d'urbanisme	Y	1	10	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	1003	Commerces	Y	1	10	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	1004	Numérotation	Y	1	10	destruction	compta_3_03	\N	365	60	14	1	NORMAL
	1101	Autorisation de buvette	Y	1	11	destruction	compta_3_03	\N	365	60	14	1	SVA
	1102	Cimetière	Y	1	11	destruction	compta_3_03	\N	365	60	14	1	SVA
	1103	Demande de dérogation scolaire	Y	1	11	destruction	compta_3_03	\N	365	60	14	1	SVA
	1104	Inscription à la cantine et activités périscolaires 	Y	1	11	destruction	compta_3_03	\N	365	60	14	1	SVA
	1105	Inscription toutes petites sections	Y	1	11	destruction	compta_3_03	\N	365	90	14	1	SVA
	1106	Travaux ERP	Y	1	11	destruction	compta_3_03	\N	365	60	14	1	SVA
	1201	Appel téléphonique	Y	1	12	destruction	compta_3_03	\N	365	21	14	1	NORMAL
	1202	Demande intervention voirie	Y	1	12	destruction	compta_3_03	\N	365	21	14	1	NORMAL
	1203	Courriel importé	Y	1	12	destruction	compta_3_03	\N	365	21	14	1	NORMAL
\.


--
-- Data for Name: doctypes_first_level; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.doctypes_first_level (doctypes_first_level_id, doctypes_first_level_label, css_style, enabled) FROM stdin;
1	COURRIERS	#000000	Y
\.


--
-- Data for Name: doctypes_indexes; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.doctypes_indexes (type_id, coll_id, field_name, mandatory) FROM stdin;
\.


--
-- Data for Name: doctypes_second_level; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.doctypes_second_level (doctypes_second_level_id, doctypes_second_level_label, doctypes_first_level_id, css_style, enabled) FROM stdin;
1	01. Correspondances	1	#000000	Y
2	02. Cabinet	1	#000000	Y
3	03. Éducation	1	#000000	Y
4	04. Finances	1	#000000	Y
5	05. Juridique	1	#000000	Y
6	06. Population 	1	#000000	Y
7	07. Ressources Humaines	1	#000000	Y
8	08. Social	1	#000000	Y
9	09. Technique	1	#000000	Y
10	10. Urbanisme	1	#000000	Y
11	11. Silence vaut acceptation	1	#000000	Y
12	12. Formulaires	1	#000000	Y
\.


--
-- Data for Name: emails; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.emails (id, user_id, sender, recipients, cc, cci, object, body, document, is_html, status, message_exchange_id, creation_date, send_date) FROM stdin;
\.


--
-- Data for Name: entities; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.entities (id, entity_id, entity_label, short_label, entity_full_name, enabled, address_number, address_street, address_additional1, address_additional2, address_postcode, address_town, address_country, email, business_id, parent_entity_id, entity_type, ldap_id, producer_service, folder_import, external_id) FROM stdin;
1	VILLE	Ville de Maarch-les-Bains	Ville de Maarch-les-Bains	\N	Y		Place de la liberté	Hôtel de Ville	\N	99000	Maarch-les-Bains	FRANCE	mairie@maarchlesbains.fr	45239273100025/VILLE		Direction	\N	\N	\N	{}
2	CAB	Cabinet du Maire	Cabinet du Maire	\N	Y		Place de la liberté	Hôtel de Ville	\N	99000	Maarch-les-Bains	FRANCE	mairie@maarchlesbains.fr	45239273100025/CAB	VILLE	Direction	\N	\N	\N	{}
4	DGA	Direction Générale Adjointe	Direction Générale Adjointe	\N	Y		Place de la liberté	Hôtel de Ville	\N	99000	Maarch-les-Bains	FRANCE	mairie@maarchlesbains.fr	45239273100025/DGA	DGS	Bureau	\N	\N	\N	{}
3	DGS	Direction Générale des Services	Direction Générale des Services	\N	Y		Place de la liberté	Hôtel de Ville	\N	99000	Maarch-les-Bains	FRANCE	mairie@maarchlesbains.fr	45239273100025/DGS	VILLE	Direction	\N	\N	\N	{}
5	PCU	Pôle Culturel	Pôle Culturel	\N	Y		Place de la liberté	Hôtel de Ville	\N	99000	Maarch-les-Bains	FRANCE	mairie@maarchlesbains.fr	45239273100025/PCU	DGA	Service	\N	\N	\N	{}
6	PJS	Pôle Jeunesse et Sport	Pôle Jeunesse et Sport	\N	Y		Place de la liberté	Hôtel de Ville	\N	99000	Maarch-les-Bains	FRANCE	mairie@maarchlesbains.fr	45239273100025/PJS	DGA	Service	\N	\N	\N	{}
7	PE	Petite enfance	Petite enfance	\N	Y		Place de la liberté	Hôtel de Ville	\N	99000	Maarch-les-Bains	FRANCE	mairie@maarchlesbains.fr	45239273100025/PE	PJS	Service	\N	\N	\N	{}
8	SP	Sport	Sport	\N	Y		Place de la liberté	Hôtel de Ville	\N	99000	Maarch-les-Bains	FRANCE	mairie@maarchlesbains.fr	45239273100025/SP	PJS	Service	\N	\N	\N	{}
9	PSO	Pôle Social	Pôle Social	\N	Y		Place de la liberté	Hôtel de Ville	\N	99000	Maarch-les-Bains	FRANCE	mairie@maarchlesbains.fr	45239273100025/PSO	DGA	Service	\N	\N	\N	{}
10	PTE	Pôle Technique	Pôle Technique	\N	Y		Place de la liberté	Hôtel de Ville	\N	99000	Maarch-les-Bains	FRANCE	mairie@maarchlesbains.fr	45239273100025/PTE	DGA	Service	\N	\N	\N	{}
11	DRH	Direction des Ressources Humaines	Direction des Ressources Humaines	\N	Y		Place de la liberté	Hôtel de Ville	\N	99000	Maarch-les-Bains	FRANCE	mairie@maarchlesbains.fr	45239273100025/DRH	DGS	Service	\N	\N	\N	{}
12	DSG	Secrétariat Général	Secrétariat Général	\N	Y		Place de la liberté	Hôtel de Ville	\N	99000	Maarch-les-Bains	FRANCE	mairie@maarchlesbains.fr	45239273100025/DSG	DGS	Direction	\N	\N	\N	{}
15	PSF	Pôle des Services Fonctionnels	Services Fonctionnels	\N	Y		Place de la liberté	Hôtel de Ville	\N	99000	Maarch-les-Bains	FRANCE	mairie@maarchlesbains.fr	45239273100025/PSF	DSG	Service	\N	\N	\N	{}
13	COU	Service Courrier	Service Courrier	\N	Y		Place de la liberté	Hôtel de Ville	\N	99000	Maarch-les-Bains	FRANCE	mairie@maarchlesbains.fr	45239273100025/COU	DSG	Service	\N	\N	\N	{}
14	COR	Correspondants Archive	Correspondants Archive	\N	Y		Place de la liberté	Hôtel de Ville	\N	99000	Maarch-les-Bains	FRANCE	mairie@maarchlesbains.fr	45239273100025/COR	COU	Service	\N	\N	\N	{}
17	FIN	Direction des Finances	Direction des Finances	\N	Y		Place de la liberté	Hôtel de Ville	\N	99000	Maarch-les-Bains	FRANCE	mairie@maarchlesbains.fr	45239273100025/FIN	DGS	Service	\N	\N	\N	{}
18	PJU	Pôle Juridique	Pôle Juridique	\N	Y		Place de la liberté	Hôtel de Ville	\N	99000	Maarch-les-Bains	FRANCE	mairie@maarchlesbains.fr	45239273100025/PJU	FIN	Service	\N	\N	\N	{}
16	DSI	Direction des Systèmes d'Information	Direction des Systèmes d'Information	\N	Y		Place de la liberté	Hôtel de Ville	\N	99000	Maarch-les-Bains	FRANCE	mairie@maarchlesbains.fr	45239273100025/DSI	DGS	Service	\N	\N	\N	{}
19	ELUS	Ensemble des élus	ELUS:Ensemble des élus	\N	Y		Place de la liberté	Hôtel de Ville	\N	99000	Maarch-les-Bains	FRANCE	mairie@maarchlesbains.fr	45239273100025/ELUS	VILLE	Direction	\N	\N	\N	{}
20	CCAS	Centre Communal d'Action Sociale	Centre Communal d'Action Sociale	\N	Y		Place de la liberté	Hôtel de Ville	\N	99000	Maarch-les-Bains	France	mairie@maarchlesbains.fr	45239273100025/CCAS		Direction	\N	\N	\N	{}
\.


--
-- Data for Name: entities_folders; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.entities_folders (id, folder_id, entity_id, edition, keyword) FROM stdin;
1	1	1	f	\N
2	1	2	f	\N
3	1	4	f	\N
4	1	3	f	\N
5	1	5	f	\N
6	1	6	f	\N
7	1	7	f	\N
8	1	8	f	\N
9	1	9	f	\N
10	1	10	f	\N
11	1	11	f	\N
12	1	12	f	\N
13	1	15	f	\N
14	1	13	f	\N
15	1	14	f	\N
16	1	17	f	\N
17	1	18	f	\N
18	1	16	f	\N
19	1	19	f	\N
20	1	20	f	\N
21	2	1	f	\N
22	2	2	f	\N
23	2	4	f	\N
24	2	3	f	\N
25	2	5	f	\N
26	2	6	f	\N
27	2	7	f	\N
28	2	8	f	\N
29	2	9	f	\N
30	2	10	f	\N
31	2	11	f	\N
32	2	12	f	\N
33	2	15	f	\N
34	2	13	f	\N
35	2	14	f	\N
36	2	17	f	\N
37	2	18	f	\N
38	2	16	f	\N
39	2	19	f	\N
40	2	20	f	\N
41	3	1	f	\N
42	3	2	f	\N
43	3	4	f	\N
44	3	3	f	\N
45	3	5	f	\N
46	3	6	f	\N
47	3	7	f	\N
48	3	8	f	\N
49	3	9	f	\N
50	3	10	f	\N
51	3	11	f	\N
52	3	12	f	\N
53	3	15	f	\N
54	3	13	f	\N
55	3	14	f	\N
56	3	17	f	\N
57	3	18	f	\N
58	3	16	f	\N
59	3	19	f	\N
60	3	20	f	\N
61	4	1	f	\N
62	4	2	f	\N
63	4	4	f	\N
64	4	3	f	\N
65	4	5	f	\N
66	4	6	f	\N
67	4	7	f	\N
68	4	8	f	\N
69	4	9	f	\N
70	4	10	f	\N
71	4	11	f	\N
72	4	12	f	\N
73	4	15	f	\N
74	4	13	f	\N
75	4	14	f	\N
76	4	17	f	\N
77	4	18	f	\N
78	4	16	f	\N
79	4	19	f	\N
80	4	20	f	\N
81	5	1	f	\N
82	5	2	f	\N
83	5	4	f	\N
84	5	3	f	\N
85	5	5	f	\N
86	5	6	f	\N
87	5	7	f	\N
88	5	8	f	\N
89	5	9	f	\N
90	5	10	f	\N
91	5	11	f	\N
92	5	12	f	\N
93	5	15	f	\N
94	5	13	f	\N
95	5	14	f	\N
96	5	17	f	\N
97	5	18	f	\N
98	5	16	f	\N
99	5	19	f	\N
100	5	20	f	\N
101	6	1	f	\N
102	6	2	f	\N
103	6	4	f	\N
104	6	3	f	\N
105	6	5	f	\N
106	6	6	f	\N
107	6	7	f	\N
108	6	8	f	\N
109	6	9	f	\N
110	6	10	f	\N
111	6	11	f	\N
112	6	12	f	\N
113	6	15	f	\N
114	6	13	f	\N
115	6	14	f	\N
116	6	17	f	\N
117	6	18	f	\N
118	6	16	f	\N
119	6	19	f	\N
120	6	20	f	\N
121	7	1	f	\N
122	7	2	f	\N
123	7	4	f	\N
124	7	3	f	\N
125	7	5	f	\N
126	7	6	f	\N
127	7	7	f	\N
128	7	8	f	\N
129	7	9	f	\N
130	7	10	f	\N
131	7	11	f	\N
132	7	12	f	\N
133	7	15	f	\N
134	7	13	f	\N
135	7	14	f	\N
136	7	17	f	\N
137	7	18	f	\N
138	7	16	f	\N
139	7	19	f	\N
140	7	20	f	\N
141	8	1	f	\N
142	8	2	f	\N
143	8	4	f	\N
144	8	3	f	\N
145	8	5	f	\N
146	8	6	f	\N
147	8	7	f	\N
148	8	8	f	\N
149	8	9	f	\N
150	8	10	f	\N
151	8	11	f	\N
152	8	12	f	\N
153	8	15	f	\N
154	8	13	f	\N
155	8	14	f	\N
156	8	17	f	\N
157	8	18	f	\N
158	8	16	f	\N
159	8	19	f	\N
160	8	20	f	\N
161	9	1	f	\N
162	9	2	f	\N
163	9	4	f	\N
164	9	3	f	\N
165	9	5	f	\N
166	9	6	f	\N
167	9	7	f	\N
168	9	8	f	\N
169	9	9	f	\N
170	9	10	f	\N
171	9	11	f	\N
172	9	12	f	\N
173	9	15	f	\N
174	9	13	f	\N
175	9	14	f	\N
176	9	17	f	\N
177	9	18	f	\N
178	9	16	f	\N
179	9	19	f	\N
180	9	20	f	\N
181	10	1	f	\N
182	10	2	f	\N
183	10	4	f	\N
184	10	3	f	\N
185	10	5	f	\N
186	10	6	f	\N
187	10	7	f	\N
188	10	8	f	\N
189	10	9	f	\N
190	10	10	f	\N
191	10	11	f	\N
192	10	12	f	\N
193	10	15	f	\N
194	10	13	f	\N
195	10	14	f	\N
196	10	17	f	\N
197	10	18	f	\N
198	10	16	f	\N
199	10	19	f	\N
200	10	20	f	\N
201	11	1	f	\N
202	11	2	f	\N
203	11	4	f	\N
204	11	3	f	\N
205	11	5	f	\N
206	11	6	f	\N
207	11	7	f	\N
208	11	8	f	\N
209	11	9	f	\N
210	11	10	f	\N
211	11	11	f	\N
212	11	12	f	\N
213	11	15	f	\N
214	11	13	f	\N
215	11	14	f	\N
216	11	17	f	\N
217	11	18	f	\N
218	11	16	f	\N
219	11	19	f	\N
220	11	20	f	\N
221	12	1	f	\N
222	12	2	f	\N
223	12	4	f	\N
224	12	3	f	\N
225	12	5	f	\N
226	12	6	f	\N
227	12	7	f	\N
228	12	8	f	\N
229	12	9	f	\N
230	12	10	f	\N
231	12	11	f	\N
232	12	12	f	\N
233	12	15	f	\N
234	12	13	f	\N
235	12	14	f	\N
236	12	17	f	\N
237	12	18	f	\N
238	12	16	f	\N
239	12	19	f	\N
240	12	20	f	\N
241	13	1	f	\N
242	13	2	f	\N
243	13	4	f	\N
244	13	3	f	\N
245	13	5	f	\N
246	13	6	f	\N
247	13	7	f	\N
248	13	8	f	\N
249	13	9	f	\N
250	13	10	f	\N
251	13	11	f	\N
252	13	12	f	\N
253	13	15	f	\N
254	13	13	f	\N
255	13	14	f	\N
256	13	17	f	\N
257	13	18	f	\N
258	13	16	f	\N
259	13	19	f	\N
260	13	20	f	\N
261	14	1	f	\N
262	14	2	f	\N
263	14	4	f	\N
264	14	3	f	\N
265	14	5	f	\N
266	14	6	f	\N
267	14	7	f	\N
268	14	8	f	\N
269	14	9	f	\N
270	14	10	f	\N
271	14	11	f	\N
272	14	12	f	\N
273	14	15	f	\N
274	14	13	f	\N
275	14	14	f	\N
276	14	17	f	\N
277	14	18	f	\N
278	14	16	f	\N
279	14	19	f	\N
280	14	20	f	\N
281	15	1	f	\N
282	15	2	f	\N
283	15	4	f	\N
284	15	3	f	\N
285	15	5	f	\N
286	15	6	f	\N
287	15	7	f	\N
288	15	8	f	\N
289	15	9	f	\N
290	15	10	f	\N
291	15	11	f	\N
292	15	12	f	\N
293	15	15	f	\N
294	15	13	f	\N
295	15	14	f	\N
296	15	17	f	\N
297	15	18	f	\N
298	15	16	f	\N
299	15	19	f	\N
300	15	20	f	\N
301	16	1	f	\N
302	16	2	f	\N
303	16	4	f	\N
304	16	3	f	\N
305	16	5	f	\N
306	16	6	f	\N
307	16	7	f	\N
308	16	8	f	\N
309	16	9	f	\N
310	16	10	f	\N
311	16	11	f	\N
312	16	12	f	\N
313	16	15	f	\N
314	16	13	f	\N
315	16	14	f	\N
316	16	17	f	\N
317	16	18	f	\N
318	16	16	f	\N
319	16	19	f	\N
320	16	20	f	\N
321	17	1	f	\N
322	17	2	f	\N
323	17	4	f	\N
324	17	3	f	\N
325	17	5	f	\N
326	17	6	f	\N
327	17	7	f	\N
328	17	8	f	\N
329	17	9	f	\N
330	17	10	f	\N
331	17	11	f	\N
332	17	12	f	\N
333	17	15	f	\N
334	17	13	f	\N
335	17	14	f	\N
336	17	17	f	\N
337	17	18	f	\N
338	17	16	f	\N
339	17	19	f	\N
340	17	20	f	\N
341	18	1	f	\N
342	18	2	f	\N
343	18	4	f	\N
344	18	3	f	\N
345	18	5	f	\N
346	18	6	f	\N
347	18	7	f	\N
348	18	8	f	\N
349	18	9	f	\N
350	18	10	f	\N
351	18	11	f	\N
352	18	12	f	\N
353	18	15	f	\N
354	18	13	f	\N
355	18	14	f	\N
356	18	17	f	\N
357	18	18	f	\N
358	18	16	f	\N
359	18	19	f	\N
360	18	20	f	\N
361	19	1	f	\N
362	19	2	f	\N
363	19	4	f	\N
364	19	3	f	\N
365	19	5	f	\N
366	19	6	f	\N
367	19	7	f	\N
368	19	8	f	\N
369	19	9	f	\N
370	19	10	f	\N
371	19	11	f	\N
372	19	12	f	\N
373	19	15	f	\N
374	19	13	f	\N
375	19	14	f	\N
376	19	17	f	\N
377	19	18	f	\N
378	19	16	f	\N
379	19	19	f	\N
380	19	20	f	\N
381	20	1	f	\N
382	20	2	f	\N
383	20	4	f	\N
384	20	3	f	\N
385	20	5	f	\N
386	20	6	f	\N
387	20	7	f	\N
388	20	8	f	\N
389	20	9	f	\N
390	20	10	f	\N
391	20	11	f	\N
392	20	12	f	\N
393	20	15	f	\N
394	20	13	f	\N
395	20	14	f	\N
396	20	17	f	\N
397	20	18	f	\N
398	20	16	f	\N
399	20	19	f	\N
400	20	20	f	\N
401	21	1	f	\N
402	21	2	f	\N
403	21	4	f	\N
404	21	3	f	\N
405	21	5	f	\N
406	21	6	f	\N
407	21	7	f	\N
408	21	8	f	\N
409	21	9	f	\N
410	21	10	f	\N
411	21	11	f	\N
412	21	12	f	\N
413	21	15	f	\N
414	21	13	f	\N
415	21	14	f	\N
416	21	17	f	\N
417	21	18	f	\N
418	21	16	f	\N
419	21	19	f	\N
420	21	20	f	\N
421	22	1	f	\N
422	22	2	f	\N
423	22	4	f	\N
424	22	3	f	\N
425	22	5	f	\N
426	22	6	f	\N
427	22	7	f	\N
428	22	8	f	\N
429	22	9	f	\N
430	22	10	f	\N
431	22	11	f	\N
432	22	12	f	\N
433	22	15	f	\N
434	22	13	f	\N
435	22	14	f	\N
436	22	17	f	\N
437	22	18	f	\N
438	22	16	f	\N
439	22	19	f	\N
440	22	20	f	\N
441	23	1	f	\N
442	23	2	f	\N
443	23	4	f	\N
444	23	3	f	\N
445	23	5	f	\N
446	23	6	f	\N
447	23	7	f	\N
448	23	8	f	\N
449	23	9	f	\N
450	23	10	f	\N
451	23	11	f	\N
452	23	12	f	\N
453	23	15	f	\N
454	23	13	f	\N
455	23	14	f	\N
456	23	17	f	\N
457	23	18	f	\N
458	23	16	f	\N
459	23	19	f	\N
460	23	20	f	\N
461	24	1	f	\N
462	24	2	f	\N
463	24	4	f	\N
464	24	3	f	\N
465	24	5	f	\N
466	24	6	f	\N
467	24	7	f	\N
468	24	8	f	\N
469	24	9	f	\N
470	24	10	f	\N
471	24	11	f	\N
472	24	12	f	\N
473	24	15	f	\N
474	24	13	f	\N
475	24	14	f	\N
476	24	17	f	\N
477	24	18	f	\N
478	24	16	f	\N
479	24	19	f	\N
480	24	20	f	\N
481	25	1	f	\N
482	25	2	f	\N
483	25	4	f	\N
484	25	3	f	\N
485	25	5	f	\N
486	25	6	f	\N
487	25	7	f	\N
488	25	8	f	\N
489	25	9	f	\N
490	25	10	f	\N
491	25	11	f	\N
492	25	12	f	\N
493	25	15	f	\N
494	25	13	f	\N
495	25	14	f	\N
496	25	17	f	\N
497	25	18	f	\N
498	25	16	f	\N
499	25	19	f	\N
500	25	20	f	\N
501	26	1	f	\N
502	26	2	f	\N
503	26	4	f	\N
504	26	3	f	\N
505	26	5	f	\N
506	26	6	f	\N
507	26	7	f	\N
508	26	8	f	\N
509	26	9	f	\N
510	26	10	f	\N
511	26	11	f	\N
512	26	12	f	\N
513	26	15	f	\N
514	26	13	f	\N
515	26	14	f	\N
516	26	17	f	\N
517	26	18	f	\N
518	26	16	f	\N
519	26	19	f	\N
520	26	20	f	\N
521	27	1	f	\N
522	27	2	f	\N
523	27	4	f	\N
524	27	3	f	\N
525	27	5	f	\N
526	27	6	f	\N
527	27	7	f	\N
528	27	8	f	\N
529	27	9	f	\N
530	27	10	f	\N
531	27	11	f	\N
532	27	12	f	\N
533	27	15	f	\N
534	27	13	f	\N
535	27	14	f	\N
536	27	17	f	\N
537	27	18	f	\N
538	27	16	f	\N
539	27	19	f	\N
540	27	20	f	\N
541	28	1	f	\N
542	28	2	f	\N
543	28	4	f	\N
544	28	3	f	\N
545	28	5	f	\N
546	28	6	f	\N
547	28	7	f	\N
548	28	8	f	\N
549	28	9	f	\N
550	28	10	f	\N
551	28	11	f	\N
552	28	12	f	\N
553	28	15	f	\N
554	28	13	f	\N
555	28	14	f	\N
556	28	17	f	\N
557	28	18	f	\N
558	28	16	f	\N
559	28	19	f	\N
560	28	20	f	\N
561	29	1	f	\N
562	29	2	f	\N
563	29	4	f	\N
564	29	3	f	\N
565	29	5	f	\N
566	29	6	f	\N
567	29	7	f	\N
568	29	8	f	\N
569	29	9	f	\N
570	29	10	f	\N
571	29	11	f	\N
572	29	12	f	\N
573	29	15	f	\N
574	29	13	f	\N
575	29	14	f	\N
576	29	17	f	\N
577	29	18	f	\N
578	29	16	f	\N
579	29	19	f	\N
580	29	20	f	\N
581	30	1	f	\N
582	30	2	f	\N
583	30	4	f	\N
584	30	3	f	\N
585	30	5	f	\N
586	30	6	f	\N
587	30	7	f	\N
588	30	8	f	\N
589	30	9	f	\N
590	30	10	f	\N
591	30	11	f	\N
592	30	12	f	\N
593	30	15	f	\N
594	30	13	f	\N
595	30	14	f	\N
596	30	17	f	\N
597	30	18	f	\N
598	30	16	f	\N
599	30	19	f	\N
600	30	20	f	\N
601	31	1	f	\N
602	31	2	f	\N
603	31	4	f	\N
604	31	3	f	\N
605	31	5	f	\N
606	31	6	f	\N
607	31	7	f	\N
608	31	8	f	\N
609	31	9	f	\N
610	31	10	f	\N
611	31	11	f	\N
612	31	12	f	\N
613	31	15	f	\N
614	31	13	f	\N
615	31	14	f	\N
616	31	17	f	\N
617	31	18	f	\N
618	31	16	f	\N
619	31	19	f	\N
620	31	20	f	\N
621	32	1	f	\N
622	32	2	f	\N
623	32	4	f	\N
624	32	3	f	\N
625	32	5	f	\N
626	32	6	f	\N
627	32	7	f	\N
628	32	8	f	\N
629	32	9	f	\N
630	32	10	f	\N
631	32	11	f	\N
632	32	12	f	\N
633	32	15	f	\N
634	32	13	f	\N
635	32	14	f	\N
636	32	17	f	\N
637	32	18	f	\N
638	32	16	f	\N
639	32	19	f	\N
640	32	20	f	\N
641	33	1	f	\N
642	33	2	f	\N
643	33	4	f	\N
644	33	3	f	\N
645	33	5	f	\N
646	33	6	f	\N
647	33	7	f	\N
648	33	8	f	\N
649	33	9	f	\N
650	33	10	f	\N
651	33	11	f	\N
652	33	12	f	\N
653	33	15	f	\N
654	33	13	f	\N
655	33	14	f	\N
656	33	17	f	\N
657	33	18	f	\N
658	33	16	f	\N
659	33	19	f	\N
660	33	20	f	\N
661	34	1	f	\N
662	34	2	f	\N
663	34	4	f	\N
664	34	3	f	\N
665	34	5	f	\N
666	34	6	f	\N
667	34	7	f	\N
668	34	8	f	\N
669	34	9	f	\N
670	34	10	f	\N
671	34	11	f	\N
672	34	12	f	\N
673	34	15	f	\N
674	34	13	f	\N
675	34	14	f	\N
676	34	17	f	\N
677	34	18	f	\N
678	34	16	f	\N
679	34	19	f	\N
680	34	20	f	\N
681	35	1	f	\N
682	35	2	f	\N
683	35	4	f	\N
684	35	3	f	\N
685	35	5	f	\N
686	35	6	f	\N
687	35	7	f	\N
688	35	8	f	\N
689	35	9	f	\N
690	35	10	f	\N
691	35	11	f	\N
692	35	12	f	\N
693	35	15	f	\N
694	35	13	f	\N
695	35	14	f	\N
696	35	17	f	\N
697	35	18	f	\N
698	35	16	f	\N
699	35	19	f	\N
700	35	20	f	\N
701	36	1	f	\N
702	36	2	f	\N
703	36	4	f	\N
704	36	3	f	\N
705	36	5	f	\N
706	36	6	f	\N
707	36	7	f	\N
708	36	8	f	\N
709	36	9	f	\N
710	36	10	f	\N
711	36	11	f	\N
712	36	12	f	\N
713	36	15	f	\N
714	36	13	f	\N
715	36	14	f	\N
716	36	17	f	\N
717	36	18	f	\N
718	36	16	f	\N
719	36	19	f	\N
720	36	20	f	\N
721	37	1	f	\N
722	37	2	f	\N
723	37	4	f	\N
724	37	3	f	\N
725	37	5	f	\N
726	37	6	f	\N
727	37	7	f	\N
728	37	8	f	\N
729	37	9	f	\N
730	37	10	f	\N
731	37	11	f	\N
732	37	12	f	\N
733	37	15	f	\N
734	37	13	f	\N
735	37	14	f	\N
736	37	17	f	\N
737	37	18	f	\N
738	37	16	f	\N
739	37	19	f	\N
740	37	20	f	\N
741	38	1	f	\N
742	38	2	f	\N
743	38	4	f	\N
744	38	3	f	\N
745	38	5	f	\N
746	38	6	f	\N
747	38	7	f	\N
748	38	8	f	\N
749	38	9	f	\N
750	38	10	f	\N
751	38	11	f	\N
752	38	12	f	\N
753	38	15	f	\N
754	38	13	f	\N
755	38	14	f	\N
756	38	17	f	\N
757	38	18	f	\N
758	38	16	f	\N
759	38	19	f	\N
760	38	20	f	\N
\.


--
-- Data for Name: exports_templates; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.exports_templates (id, user_id, delimiter, format, data) FROM stdin;
2	4	;	csv	[{"value":"doc_date","label":"Date du courrier","isFunction":false},{"value":"getAssignee","label":"Attributaire","isFunction":true},{"value":"getDestinationEntity","label":"Libell\\u00e9 de l'entit\\u00e9 traitante","isFunction":true},{"value":"subject","label":"Objet","isFunction":false},{"value":"process_limit_date","label":"Date limite de traitement","isFunction":false}]
1	4	;	pdf	[{"value":"doc_date","label":"Date du courrier","isFunction":false},{"value":"type_label","label":"Type de courrier","isFunction":false},{"value":"getAssignee","label":"Attributaire","isFunction":true},{"value":"subject","label":"Objet","isFunction":false},{"value":"process_limit_date","label":"Date limite de traitement","isFunction":false}]
\.


--
-- Data for Name: folders; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.folders (id, label, public, user_id, parent_id, level) FROM stdin;
1	Compétences fonctionnelles	t	21	\N	0
2	Vie politique	t	21	1	1
3	Vie citoyenne	t	21	1	1
4	Administration municipale	t	21	1	1
5	Ressources humaines	t	21	1	1
6	Candidatures sur postes ouverts	t	21	5	2
7	Candidatures spontanées	t	21	5	2
8	Affaires juridiques	t	21	1	1
9	Finances	t	21	1	1
10	Marchés publics	t	21	1	1
11	Informatique	t	21	1	1
12	Communication	t	21	1	1
13	Événements	t	21	1	1
14	Moyens généraux (matériels et logistiques)	t	21	1	1
15	Archives	t	21	1	1
16	Compétences techniques	t	21	\N	0
17	Population	t	21	16	1
18	Police - ordre public	t	21	16	1
19	Stationnement	t	21	18	2
20	Politique de la ville	t	21	16	1
21	Urbanisme opérationnel	t	21	16	1
22	Urbanisme réglementaire	t	21	16	1
23	Affaires foncières 	t	21	16	1
24	Développement du territoire 	t	21	16	1
25	Habitat	t	21	16	1
26	Biens communaux (domaine privé)	t	21	16	1
27	Espaces publics urbains (domaine public - voiries -réseaux)	t	21	16	1
28	Éclairage public	t	21	27	2
29	Ouvrages d'art	t	21	27	2
30	Hygiène	t	21	16	1
31	Santé publique	t	21	16	1
32	Enseignement	t	21	16	1
33	Sports	t	21	16	1
34	Centre de loisirs nautiques	t	21	33	2
35	Jeunesse	t	21	16	1
36	Culture	t	21	16	1
37	Actions sociales	t	21	16	1
38	Cohésion sociale	t	21	16	1
\.


--
-- Data for Name: groupbasket; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.groupbasket (id, group_id, basket_id, list_display, list_event, list_event_data) FROM stdin;
1	COURRIER	QualificationBasket	{"templateColumns":7,"subInfos":[{"value":"getPriority","cssClasses":[],"icon":"fa-traffic-light"},{"value":"getCategory","cssClasses":[],"icon":"fa-exchange-alt"},{"value":"getDoctype","cssClasses":[],"icon":"fa-suitcase"},{"value":"getAssignee","cssClasses":[],"icon":"fa-sitemap"},{"value":"getRecipients","cssClasses":[],"icon":"fa-user"},{"value":"getSenders","cssClasses":[],"icon":"fa-book"},{"value":"getCreationAndProcessLimitDates","cssClasses":["align_rightData"],"icon":"fa-calendar"}]}	processDocument	{"defaultTab": "info", "canUpdateData": true}
2	AGENT	CopyMailBasket	{"templateColumns":7,"subInfos":[{"value":"getPriority","cssClasses":[],"icon":"fa-traffic-light"},{"value":"getCategory","cssClasses":[],"icon":"fa-exchange-alt"},{"value":"getDoctype","cssClasses":[],"icon":"fa-suitcase"},{"value":"getAssignee","cssClasses":[],"icon":"fa-sitemap"},{"value":"getRecipients","cssClasses":[],"icon":"fa-user"},{"value":"getSenders","cssClasses":[],"icon":"fa-book"},{"value":"getCreationAndProcessLimitDates","cssClasses":["align_rightData"],"icon":"fa-calendar"}]}	documentDetails	[]
3	RESPONSABLE	CopyMailBasket	{"templateColumns":7,"subInfos":[{"value":"getPriority","cssClasses":[],"icon":"fa-traffic-light"},{"value":"getCategory","cssClasses":[],"icon":"fa-exchange-alt"},{"value":"getDoctype","cssClasses":[],"icon":"fa-suitcase"},{"value":"getAssignee","cssClasses":[],"icon":"fa-sitemap"},{"value":"getRecipients","cssClasses":[],"icon":"fa-user"},{"value":"getSenders","cssClasses":[],"icon":"fa-book"},{"value":"getCreationAndProcessLimitDates","cssClasses":["align_rightData"],"icon":"fa-calendar"}]}	documentDetails	[]
4	COURRIER	RetourCourrier	{"templateColumns":7,"subInfos":[{"value":"getPriority","cssClasses":[],"icon":"fa-traffic-light"},{"value":"getCategory","cssClasses":[],"icon":"fa-exchange-alt"},{"value":"getDoctype","cssClasses":[],"icon":"fa-suitcase"},{"value":"getAssignee","cssClasses":[],"icon":"fa-sitemap"},{"value":"getRecipients","cssClasses":[],"icon":"fa-user"},{"value":"getSenders","cssClasses":[],"icon":"fa-book"},{"value":"getCreationAndProcessLimitDates","cssClasses":["align_rightData"],"icon":"fa-calendar"}]}	processDocument	{"defaultTab": "info", "canUpdateData": true}
5	AGENT	DdeAvisBasket	{"templateColumns":5,"subInfos":[{"value":"getPriority","cssClasses":[],"icon":"fa-traffic-light"},{"value":"getCategory","cssClasses":[],"icon":"fa-exchange-alt"},{"value":"getDoctype","cssClasses":[],"icon":"fa-suitcase"},{"value":"getParallelOpinionsNumber","cssClasses":["align_rightData"],"icon":"fa-comment-alt"},{"value":"getOpinionLimitDate","cssClasses":["align_rightData"],"icon":"fa-stopwatch"}]}	processDocument	{"defaultTab": "dashboard"}
6	RESPONSABLE	DdeAvisBasket	{"templateColumns":5,"subInfos":[{"value":"getPriority","cssClasses":[],"icon":"fa-traffic-light"},{"value":"getCategory","cssClasses":[],"icon":"fa-exchange-alt"},{"value":"getDoctype","cssClasses":[],"icon":"fa-suitcase"},{"value":"getParallelOpinionsNumber","cssClasses":["align_rightData"],"icon":"fa-comment-alt"},{"value":"getOpinionLimitDate","cssClasses":["align_rightData"],"icon":"fa-stopwatch"}]}	processDocument	{"defaultTab": "dashboard"}
9	RESPONSABLE	SupAvisBasket	{"templateColumns":5,"subInfos":[{"value":"getPriority","cssClasses":[],"icon":"fa-traffic-light"},{"value":"getCategory","cssClasses":[],"icon":"fa-exchange-alt"},{"value":"getDoctype","cssClasses":[],"icon":"fa-suitcase"},{"value":"getParallelOpinionsNumber","cssClasses":["align_rightData"],"icon":"fa-comment-alt"},{"value":"getOpinionLimitDate","cssClasses":["align_rightData"],"icon":"fa-stopwatch"}]}	processDocument	{"defaultTab": "opinionCircuit"}
10	AGENT	RetAvisBasket	{"templateColumns":5,"subInfos":[{"value":"getPriority","cssClasses":[],"icon":"fa-traffic-light"},{"value":"getCategory","cssClasses":[],"icon":"fa-exchange-alt"},{"value":"getDoctype","cssClasses":[],"icon":"fa-suitcase"},{"value":"getParallelOpinionsNumber","cssClasses":["align_rightData"],"icon":"fa-comment-alt"},{"value":"getOpinionLimitDate","cssClasses":["align_rightData"],"icon":"fa-stopwatch"}]}	processDocument	{"defaultTab": "notes"}
11	RESPONSABLE	RetAvisBasket	{"templateColumns":5,"subInfos":[{"value":"getPriority","cssClasses":[],"icon":"fa-traffic-light"},{"value":"getCategory","cssClasses":[],"icon":"fa-exchange-alt"},{"value":"getDoctype","cssClasses":[],"icon":"fa-suitcase"},{"value":"getParallelOpinionsNumber","cssClasses":["align_rightData"],"icon":"fa-comment-alt"},{"value":"getOpinionLimitDate","cssClasses":["align_rightData"],"icon":"fa-stopwatch"}]}	processDocument	{"defaultTab": "notes"}
12	RESP_COURRIER	ValidationBasket	{"templateColumns":7,"subInfos":[{"value":"getPriority","cssClasses":[],"icon":"fa-traffic-light"},{"value":"getCategory","cssClasses":[],"icon":"fa-exchange-alt"},{"value":"getDoctype","cssClasses":[],"icon":"fa-suitcase"},{"value":"getAssignee","cssClasses":[],"icon":"fa-sitemap"},{"value":"getRecipients","cssClasses":[],"icon":"fa-user"},{"value":"getSenders","cssClasses":[],"icon":"fa-book"},{"value":"getCreationAndProcessLimitDates","cssClasses":["align_rightData"],"icon":"fa-calendar"}]}	processDocument	{"defaultTab": "diffusionList", "canUpdateData": true}
8	AGENT	SupAvisBasket	{"templateColumns":5,"subInfos":[{"value":"getPriority","label":"Priorit\\u00e9","sample":"Urgent","cssClasses":[],"icon":"fa-traffic-light"},{"value":"getCategory","label":"Cat\\u00e9gorie","sample":"Courrier arriv\\u00e9e","cssClasses":[],"icon":"fa-exchange-alt"},{"value":"getDoctype","label":"Type de courrier","sample":"R\\u00e9clamation","cssClasses":[],"icon":"fa-suitcase"},{"value":"getParallelOpinionsNumber","label":"Nombre d'avis donn\\u00e9s","sample":"<b>3<\\/b> avis donn\\u00e9(s)","cssClasses":["align_rightData"],"icon":"fa-comment-alt"},{"value":"getOpinionLimitDate","label":"Date limite d'envoi des avis","sample":"01-01-2019","cssClasses":["align_rightData"],"icon":"fa-stopwatch"}]}	processDocument	{"defaultTab": "dashboard", "canUpdateData": true, "canUpdateModel": false}
15	ELU	MyBasket	{"templateColumns":7,"subInfos":[{"value":"getPriority","cssClasses":[],"icon":"fa-traffic-light"},{"value":"getCategory","cssClasses":[],"icon":"fa-exchange-alt"},{"value":"getDoctype","cssClasses":[],"icon":"fa-suitcase"},{"value":"getAssignee","cssClasses":[],"icon":"fa-sitemap"},{"value":"getRecipients","cssClasses":[],"icon":"fa-user"},{"value":"getSenders","cssClasses":[],"icon":"fa-book"},{"value":"getCreationAndProcessLimitDates","cssClasses":["align_rightData"],"icon":"fa-calendar"}]}	processDocument	{"defaultTab": "dashboard"}
16	AGENT	LateMailBasket	{"templateColumns":7,"subInfos":[{"value":"getPriority","cssClasses":[],"icon":"fa-traffic-light"},{"value":"getCategory","cssClasses":[],"icon":"fa-exchange-alt"},{"value":"getDoctype","cssClasses":[],"icon":"fa-suitcase"},{"value":"getAssignee","cssClasses":[],"icon":"fa-sitemap"},{"value":"getRecipients","cssClasses":[],"icon":"fa-user"},{"value":"getSenders","cssClasses":[],"icon":"fa-book"},{"value":"getCreationAndProcessLimitDates","cssClasses":["align_rightData"],"icon":"fa-calendar"}]}	processDocument	{"defaultTab": "dashboard"}
17	RESPONSABLE	DepartmentBasket	{"templateColumns":7,"subInfos":[{"value":"getPriority","cssClasses":[],"icon":"fa-traffic-light"},{"value":"getCategory","cssClasses":[],"icon":"fa-exchange-alt"},{"value":"getDoctype","cssClasses":[],"icon":"fa-suitcase"},{"value":"getAssignee","cssClasses":[],"icon":"fa-sitemap"},{"value":"getRecipients","cssClasses":[],"icon":"fa-user"},{"value":"getSenders","cssClasses":[],"icon":"fa-book"},{"value":"getCreationAndProcessLimitDates","cssClasses":["align_rightData"],"icon":"fa-calendar"}]}	documentDetails	[]
19	AGENT	SuiviParafBasket	{"templateColumns":7,"subInfos":[{"value":"getPriority","cssClasses":[],"icon":"fa-traffic-light"},{"value":"getCategory","cssClasses":[],"icon":"fa-exchange-alt"},{"value":"getDoctype","cssClasses":[],"icon":"fa-suitcase"},{"value":"getAssignee","cssClasses":[],"icon":"fa-sitemap"},{"value":"getRecipients","cssClasses":[],"icon":"fa-user"},{"value":"getSenders","cssClasses":[],"icon":"fa-book"},{"value":"getCreationAndProcessLimitDates","cssClasses":["align_rightData"],"icon":"fa-calendar"}]}	documentDetails	[]
20	RESPONSABLE	SuiviParafBasket	{"templateColumns":7,"subInfos":[{"value":"getPriority","cssClasses":[],"icon":"fa-traffic-light"},{"value":"getCategory","cssClasses":[],"icon":"fa-exchange-alt"},{"value":"getDoctype","cssClasses":[],"icon":"fa-suitcase"},{"value":"getAssignee","cssClasses":[],"icon":"fa-sitemap"},{"value":"getRecipients","cssClasses":[],"icon":"fa-user"},{"value":"getSenders","cssClasses":[],"icon":"fa-book"},{"value":"getCreationAndProcessLimitDates","cssClasses":["align_rightData"],"icon":"fa-calendar"}]}	documentDetails	[]
21	AGENT	EenvBasket	{"templateColumns":7,"subInfos":[{"value":"getPriority","cssClasses":[],"icon":"fa-traffic-light"},{"value":"getCategory","cssClasses":[],"icon":"fa-exchange-alt"},{"value":"getDoctype","cssClasses":[],"icon":"fa-suitcase"},{"value":"getAssignee","cssClasses":[],"icon":"fa-sitemap"},{"value":"getRecipients","cssClasses":[],"icon":"fa-user"},{"value":"getSenders","cssClasses":[],"icon":"fa-book"},{"value":"getCreationAndProcessLimitDates","cssClasses":["align_rightData"],"icon":"fa-calendar"}]}	processDocument	{"defaultTab": "dashboard"}
22	RESPONSABLE	EenvBasket	{"templateColumns":7,"subInfos":[{"value":"getPriority","cssClasses":[],"icon":"fa-traffic-light"},{"value":"getCategory","cssClasses":[],"icon":"fa-exchange-alt"},{"value":"getDoctype","cssClasses":[],"icon":"fa-suitcase"},{"value":"getAssignee","cssClasses":[],"icon":"fa-sitemap"},{"value":"getRecipients","cssClasses":[],"icon":"fa-user"},{"value":"getSenders","cssClasses":[],"icon":"fa-book"},{"value":"getCreationAndProcessLimitDates","cssClasses":["align_rightData"],"icon":"fa-calendar"}]}	processDocument	{"defaultTab": "dashboard"}
23	ARCHIVISTE	ToArcBasket	{"templateColumns":7,"subInfos":[{"value":"getPriority","cssClasses":[],"icon":"fa-traffic-light"},{"value":"getCategory","cssClasses":[],"icon":"fa-exchange-alt"},{"value":"getDoctype","cssClasses":[],"icon":"fa-suitcase"},{"value":"getAssignee","cssClasses":[],"icon":"fa-sitemap"},{"value":"getRecipients","cssClasses":[],"icon":"fa-user"},{"value":"getSenders","cssClasses":[],"icon":"fa-book"},{"value":"getCreationAndProcessLimitDates","cssClasses":["align_rightData"],"icon":"fa-calendar"}]}	processDocument	{"defaultTab": "dashboard"}
24	ARCHIVISTE	SentArcBasket	{"templateColumns":7,"subInfos":[{"value":"getPriority","cssClasses":[],"icon":"fa-traffic-light"},{"value":"getCategory","cssClasses":[],"icon":"fa-exchange-alt"},{"value":"getDoctype","cssClasses":[],"icon":"fa-suitcase"},{"value":"getAssignee","cssClasses":[],"icon":"fa-sitemap"},{"value":"getRecipients","cssClasses":[],"icon":"fa-user"},{"value":"getSenders","cssClasses":[],"icon":"fa-book"},{"value":"getCreationAndProcessLimitDates","cssClasses":["align_rightData"],"icon":"fa-calendar"}]}	processDocument	{"defaultTab": "dashboard"}
25	ARCHIVISTE	AckArcBasket	{"templateColumns":7,"subInfos":[{"value":"getPriority","cssClasses":[],"icon":"fa-traffic-light"},{"value":"getCategory","cssClasses":[],"icon":"fa-exchange-alt"},{"value":"getDoctype","cssClasses":[],"icon":"fa-suitcase"},{"value":"getAssignee","cssClasses":[],"icon":"fa-sitemap"},{"value":"getRecipients","cssClasses":[],"icon":"fa-user"},{"value":"getSenders","cssClasses":[],"icon":"fa-book"},{"value":"getCreationAndProcessLimitDates","cssClasses":["align_rightData"],"icon":"fa-calendar"}]}	processDocument	{"defaultTab": "dashboard"}
26	COURRIER	NumericBasket	{"templateColumns":7,"subInfos":[{"value":"getPriority","cssClasses":[],"icon":"fa-traffic-light"},{"value":"getCategory","cssClasses":[],"icon":"fa-exchange-alt"},{"value":"getDoctype","cssClasses":[],"icon":"fa-suitcase"},{"value":"getAssignee","cssClasses":[],"icon":"fa-sitemap"},{"value":"getRecipients","cssClasses":[],"icon":"fa-user"},{"value":"getSenders","cssClasses":[],"icon":"fa-book"},{"value":"getCreationAndProcessLimitDates","cssClasses":["align_rightData"],"icon":"fa-calendar"}]}	processDocument	{"defaultTab": "info", "canUpdateData": true}
27	AGENT	SendToSignatoryBook	{"templateColumns":7,"subInfos":[{"value":"getPriority","cssClasses":[],"icon":"fa-traffic-light"},{"value":"getCategory","cssClasses":[],"icon":"fa-exchange-alt"},{"value":"getDoctype","cssClasses":[],"icon":"fa-suitcase"},{"value":"getAssignee","cssClasses":[],"icon":"fa-sitemap"},{"value":"getRecipients","cssClasses":[],"icon":"fa-user"},{"value":"getSenders","cssClasses":[],"icon":"fa-book"},{"value":"getCreationAndProcessLimitDates","cssClasses":["align_rightData"],"icon":"fa-calendar"}]}	documentDetails	[]
28	RESPONSABLE	SendToSignatoryBook	{"templateColumns":7,"subInfos":[{"value":"getPriority","cssClasses":[],"icon":"fa-traffic-light"},{"value":"getCategory","cssClasses":[],"icon":"fa-exchange-alt"},{"value":"getDoctype","cssClasses":[],"icon":"fa-suitcase"},{"value":"getAssignee","cssClasses":[],"icon":"fa-sitemap"},{"value":"getRecipients","cssClasses":[],"icon":"fa-user"},{"value":"getSenders","cssClasses":[],"icon":"fa-book"},{"value":"getCreationAndProcessLimitDates","cssClasses":["align_rightData"],"icon":"fa-calendar"}]}	documentDetails	[]
31	AGENT	Maileva_Sended	{"templateColumns":7,"subInfos":[{"value":"getPriority","cssClasses":[],"icon":"fa-traffic-light"},{"value":"getCategory","cssClasses":[],"icon":"fa-exchange-alt"},{"value":"getDoctype","cssClasses":[],"icon":"fa-suitcase"},{"value":"getAssignee","cssClasses":[],"icon":"fa-sitemap"},{"value":"getRecipients","cssClasses":[],"icon":"fa-user"},{"value":"getSenders","cssClasses":[],"icon":"fa-book"},{"value":"getCreationAndProcessLimitDates","cssClasses":["align_rightData"],"icon":"fa-calendar"}]}	processDocument	{"defaultTab": "dashboard"}
13	AGENT	MyBasket	{"templateColumns":7,"subInfos":[{"value":"getPriority","label":"Priorit\\u00e9","sample":"Urgent","cssClasses":[],"icon":"fa-traffic-light"},{"value":"getCategory","label":"Cat\\u00e9gorie","sample":"Courrier arriv\\u00e9e","cssClasses":[],"icon":"fa-exchange-alt"},{"value":"getDoctype","label":"Type de courrier","sample":"R\\u00e9clamation","cssClasses":[],"icon":"fa-suitcase"},{"value":"getAssignee","label":"Attributaire (entit\\u00e9 traitante)","sample":"Barbara BAIN (P\\u00f4le Jeunesse et Sport)","cssClasses":[],"icon":"fa-sitemap"},{"value":"getRecipients","label":"Destinataire","sample":"Patricia PETIT","cssClasses":[],"icon":"fa-user"},{"value":"getSenders","label":"Exp\\u00e9diteur","sample":"Alain DUBOIS (MAARCH)","cssClasses":[],"icon":"fa-book"},{"value":"getCreationAndProcessLimitDates","cssClasses":["align_rightData"],"icon":"fa-calendar"},{"value":"getFolders","label":"Dossiers (emplacement fixe)","sample":"Litiges","cssClasses":["align_leftData"],"icon":"fa-folder"}]}	processDocument	{"defaultTab": "dashboard", "canUpdateData": true, "canUpdateModel": false}
29	AGENT	AR_Create	{"templateColumns":7,"subInfos":[{"value":"getPriority","label":"Priorit\\u00e9","sample":"Urgent","cssClasses":[],"icon":"fa-traffic-light"},{"value":"getCategory","label":"Cat\\u00e9gorie","sample":"Courrier arriv\\u00e9e","cssClasses":[],"icon":"fa-exchange-alt"},{"value":"getDoctype","label":"Type de courrier","sample":"R\\u00e9clamation","cssClasses":[],"icon":"fa-suitcase"},{"value":"getAssignee","label":"Attributaire (entit\\u00e9 traitante)","sample":"Barbara BAIN (P\\u00f4le Jeunesse et Sport)","cssClasses":[],"icon":"fa-sitemap"},{"value":"getRecipients","label":"Destinataire","sample":"Patricia PETIT","cssClasses":[],"icon":"fa-user"},{"value":"getSenders","label":"Exp\\u00e9diteur","sample":"Alain DUBOIS (MAARCH)","cssClasses":[],"icon":"fa-book"},{"value":"getCreationAndProcessLimitDates","cssClasses":["align_rightData"],"icon":"fa-calendar"}]}	processDocument	{"defaultTab": "emails", "canUpdateData": true, "canUpdateModel": false}
30	AGENT	AR_AlreadySend	{"templateColumns":7,"subInfos":[{"value":"getPriority","label":"Priorit\\u00e9","sample":"Urgent","cssClasses":[],"icon":"fa-traffic-light"},{"value":"getCategory","label":"Cat\\u00e9gorie","sample":"Courrier arriv\\u00e9e","cssClasses":[],"icon":"fa-exchange-alt"},{"value":"getDoctype","label":"Type de courrier","sample":"R\\u00e9clamation","cssClasses":[],"icon":"fa-suitcase"},{"value":"getAssignee","label":"Attributaire (entit\\u00e9 traitante)","sample":"Barbara BAIN (P\\u00f4le Jeunesse et Sport)","cssClasses":[],"icon":"fa-sitemap"},{"value":"getRecipients","label":"Destinataire","sample":"Patricia PETIT","cssClasses":[],"icon":"fa-user"},{"value":"getSenders","label":"Exp\\u00e9diteur","sample":"Alain DUBOIS (MAARCH)","cssClasses":[],"icon":"fa-book"},{"value":"getCreationAndProcessLimitDates","cssClasses":["align_rightData"],"icon":"fa-calendar"}]}	documentDetails	\N
7	ELU	DdeAvisBasket	{"templateColumns":5,"subInfos":[{"value":"getPriority","label":"Priorit\\u00e9","sample":"Urgent","cssClasses":[],"icon":"fa-traffic-light"},{"value":"getCategory","label":"Cat\\u00e9gorie","sample":"Courrier arriv\\u00e9e","cssClasses":[],"icon":"fa-exchange-alt"},{"value":"getDoctype","label":"Type de courrier","sample":"R\\u00e9clamation","cssClasses":[],"icon":"fa-suitcase"},{"value":"getParallelOpinionsNumber","label":"Nombre d'avis donn\\u00e9s","sample":"<b>3<\\/b> avis donn\\u00e9(s)","cssClasses":["align_rightData"],"icon":"fa-comment-alt"},{"value":"getOpinionLimitDate","label":"Date limite d'envoi des avis","sample":"01-01-2019","cssClasses":["align_rightData"],"icon":"fa-stopwatch"}]}	processDocument	{"defaultTab": "notes", "canUpdateData": false, "canUpdateModel": false}
14	RESPONSABLE	MyBasket	{"templateColumns":7,"subInfos":[{"value":"getPriority","label":"Priorit\\u00e9","sample":"Urgent","cssClasses":[],"icon":"fa-traffic-light"},{"value":"getCategory","label":"Cat\\u00e9gorie","sample":"Courrier arriv\\u00e9e","cssClasses":[],"icon":"fa-exchange-alt"},{"value":"getDoctype","label":"Type de courrier","sample":"R\\u00e9clamation","cssClasses":[],"icon":"fa-suitcase"},{"value":"getAssignee","label":"Attributaire (entit\\u00e9 traitante)","sample":"Barbara BAIN (P\\u00f4le Jeunesse et Sport)","cssClasses":[],"icon":"fa-sitemap"},{"value":"getRecipients","label":"Destinataire","sample":"Patricia PETIT","cssClasses":[],"icon":"fa-user"},{"value":"getSenders","label":"Exp\\u00e9diteur","sample":"Alain DUBOIS (MAARCH)","cssClasses":[],"icon":"fa-book"},{"value":"getCreationAndProcessLimitDates","cssClasses":["align_rightData"],"icon":"fa-calendar"},{"value":"getFolders","label":"Dossiers (emplacement fixe)","sample":"Litiges","cssClasses":["align_leftData"],"icon":"fa-folder"}]}	processDocument	{"defaultTab": "dashboard", "canUpdateData": false, "canUpdateModel": false}
18	RESPONSABLE	ParafBasket	{"templateColumns":7,"subInfos":[{"value":"getPriority","label":"Priorit\\u00e9","sample":"Urgent","cssClasses":[],"icon":"fa-traffic-light"},{"value":"getCategory","label":"Cat\\u00e9gorie","sample":"Courrier arriv\\u00e9e","cssClasses":[],"icon":"fa-exchange-alt"},{"value":"getDoctype","label":"Type de courrier","sample":"R\\u00e9clamation","cssClasses":[],"icon":"fa-suitcase"},{"value":"getAssignee","label":"Attributaire (entit\\u00e9 traitante)","sample":"Barbara BAIN (P\\u00f4le Jeunesse et Sport)","cssClasses":[],"icon":"fa-sitemap"},{"value":"getRecipients","label":"Destinataire","sample":"Patricia PETIT","cssClasses":[],"icon":"fa-user"},{"value":"getSenders","label":"Exp\\u00e9diteur","sample":"Alain DUBOIS (MAARCH)","cssClasses":[],"icon":"fa-book"},{"value":"getCreationAndProcessLimitDates","cssClasses":["align_rightData"],"icon":"fa-calendar"},{"value":"getFolders","label":"Dossiers (emplacement fixe)","sample":"Litiges","cssClasses":["align_leftData"],"icon":"fa-folder"}]}	signatureBookAction	{"canUpdateDocuments": true}
33	AGENT	outlook_mails	{"templateColumns":0,"subInfos":[]}	processDocument	{"defaultTab": "info", "canUpdateData": true, "canUpdateModel": true}
34	DIRECTEUR	outlook_mails	{"templateColumns":0,"subInfos":[]}	processDocument	{"defaultTab": "info", "canUpdateData": true, "canUpdateModel": true}
35	RESPONSABLE	outlook_mails	{"templateColumns":0,"subInfos":[]}	processDocument	{"defaultTab": "info", "canUpdateData": true, "canUpdateModel": true}
36	COURRIER	outlook_mails	{"templateColumns":0,"subInfos":[]}	processDocument	{"defaultTab": "info", "canUpdateData": true, "canUpdateModel": true}
37	RESP_COURRIER	outlook_mails	{"templateColumns":0,"subInfos":[]}	processDocument	{"defaultTab": "info", "canUpdateData": true, "canUpdateModel": true}
\.


--
-- Data for Name: groupbasket_redirect; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.groupbasket_redirect (system_id, group_id, basket_id, action_id, entity_id, keyword, redirect_mode) FROM stdin;
600	COURRIER	QualificationBasket	18		ALL_ENTITIES	ENTITY
601	COURRIER	NumericBasket	18		ALL_ENTITIES	ENTITY
607	RESPONSABLE	MyBasket	1		MY_ENTITIES	ENTITY
608	RESPONSABLE	MyBasket	1		ENTITIES_BELOW	ENTITY
609	RESPONSABLE	MyBasket	1		ENTITIES_JUST_UP	ENTITY
610	RESPONSABLE	MyBasket	1		SAME_LEVEL_ENTITIES	ENTITY
611	RESPONSABLE	MyBasket	1		MY_ENTITIES	USERS
612	RESPONSABLE	DepartmentBasket	1		MY_ENTITIES	ENTITY
613	RESPONSABLE	DepartmentBasket	1		ENTITIES_BELOW	ENTITY
614	RESPONSABLE	DepartmentBasket	1		ENTITIES_JUST_UP	ENTITY
615	RESPONSABLE	DepartmentBasket	1		SAME_LEVEL_ENTITIES	ENTITY
616	RESPONSABLE	DepartmentBasket	1		MY_ENTITIES	USERS
617	ELU	MyBasket	1		ALL_ENTITIES	ENTITY
619	AGENT	DepartmentBasket	1		ALL_ENTITIES	ENTITY
620	RESPONSABLE	MyBasket	1		ALL_ENTITIES	ENTITY
621	RESPONSABLE	DepartmentBasket	1		ALL_ENTITIES	ENTITY
678	AGENT	MyBasket	1		MY_ENTITIES	ENTITY
679	AGENT	MyBasket	1		SAME_LEVEL_ENTITIES	ENTITY
680	AGENT	MyBasket	1		MY_PRIMARY_ENTITY	ENTITY
681	AGENT	MyBasket	1		ENTITIES_JUST_UP	ENTITY
726	DIRECTEUR	outlook_mails	18		ALL_ENTITIES	ENTITY
727	DIRECTEUR	outlook_mails	18		ALL_ENTITIES	USERS
728	RESPONSABLE	outlook_mails	18		ALL_ENTITIES	ENTITY
729	RESPONSABLE	outlook_mails	18		ALL_ENTITIES	USERS
730	COURRIER	outlook_mails	18		ALL_ENTITIES	ENTITY
731	COURRIER	outlook_mails	18		ALL_ENTITIES	USERS
732	RESP_COURRIER	outlook_mails	18		ALL_ENTITIES	ENTITY
733	RESP_COURRIER	outlook_mails	18		ALL_ENTITIES	USERS
724	AGENT	outlook_mails	18		ALL_ENTITIES	ENTITY
725	AGENT	outlook_mails	18		ALL_ENTITIES	USERS
\.


--
-- Data for Name: history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.history (id, table_name, record_id, event_type, user_id, event_date, info, id_module, remote_ip, event_id) FROM stdin;
1	users	23	LOGIN	23	2026-08-03 23:36:53.907404	Connexion de l'utilisateur : superadmin	authentication	192.168.65.1	userlogin
2	users	23	LOGIN	23	2026-08-03 23:41:35.518047	Connexion de l'utilisateur : superadmin	authentication	192.168.65.1	userlogin
3	users	9	LOGIN	9	2026-08-03 23:55:28.366358	Connexion de l'utilisateur : bboule	authentication	192.168.65.1	userlogin
4	users	9	LOGIN	9	2026-08-08 23:46:29.830366	Connexion de l'utilisateur : bboule	authentication	172.18.0.1	userlogin
5	users	9	LOGOUT	9	2026-08-08 23:47:09.355251	Déconnexion de l'utilisateur : bboule	authentication	172.18.0.1	userlogout
6	users	23	LOGIN	23	2026-08-08 23:47:17.131636	Connexion de l'utilisateur : superadmin	authentication	172.18.0.1	userlogin
7	users	23	LOGOUT	23	2026-08-08 23:51:46.468762	Déconnexion de l'utilisateur : superadmin	authentication	172.18.0.1	userlogout
8	users	9	LOGIN	9	2026-08-08 23:51:55.040363	Connexion de l'utilisateur : bboule	authentication	172.18.0.1	userlogin
9	contacts	12	ADD	9	2026-08-09 00:08:06.008466	Contact créé : NGSign	contact	172.18.0.1	contactCreation
10	none	2301.1.0.sql	UP	23	2026-08-09 00:14:22.021682	Base de données mise à jour avec le fichier : 2301.1.0.sql	admin	172.18.0.1	databaseUpdate
11	none	2301.1.1.sql	UP	23	2026-08-09 00:14:22.025176	Base de données mise à jour avec le fichier : 2301.1.1.sql	admin	172.18.0.1	databaseUpdate
12	none	2301.1.3.sql	UP	23	2026-08-09 00:14:22.068791	Base de données mise à jour avec le fichier : 2301.1.3.sql	admin	172.18.0.1	databaseUpdate
13	none	2301.2.0.sql	UP	23	2026-08-09 00:14:22.074297	Base de données mise à jour avec le fichier : 2301.2.0.sql	admin	172.18.0.1	databaseUpdate
14	users	23	LOGIN	23	2026-08-09 00:16:10.246261	Connexion de l'utilisateur : superadmin	authentication	172.18.0.1	userlogin
15	res_letterbox	106	ADD	9	2026-08-09 00:35:39.736739	Courrier créé	resource	172.18.0.1	resourceCreation
16	res_letterbox	106	ACTION#22	9	2026-08-09 00:35:39.804914	Attribuer au service	resource	172.18.0.1	22
17	users	15	LOGIN	15	2026-08-09 00:58:31.345143	Connexion de l'utilisateur : ssaporta	authentication	172.18.0.1	userlogin
18	res_letterbox	106	VIEW	15	2026-08-09 00:58:40.80792	Visualisation du document : 106	resource	172.18.0.1	resview
19	res_letterbox	106	UP	15	2026-08-09 00:59:33.448489	Circuit de visa mis à jour	listinstance	172.18.0.1	diffsignuser
20	res_letterbox	106	UP	15	2026-08-09 00:59:33.448489	Circuit de visa mis à jour	listinstance	172.18.0.1	listinstanceCreation
21	res_letterbox	106	DEL	15	2026-08-09 00:59:48.056617	Circuit de visa supprimé	listinstance	172.18.0.1	listinstanceCreation
22	res_letterbox	106	UP	15	2026-08-09 01:00:23.82874	Circuit de visa mis à jour	listinstance	172.18.0.1	diffsignuser
23	res_letterbox	106	UP	15	2026-08-09 01:00:23.82874	Circuit de visa mis à jour	listinstance	172.18.0.1	listinstanceCreation
24	res_letterbox	106	VIEW	15	2026-08-09 01:00:54.882707	Visualisation du document : 106	resource	172.18.0.1	resview
25	res_letterbox	106	UP	15	2026-08-09 01:01:12.351868	Courrier intégré au parapheur électronique : MAARCH/2026A/2	resource	172.18.0.1	resourceModification
26	res_letterbox	106	UP	15	2026-08-09 01:01:27.367898	Circuit de visa mis à jour	listinstance	172.18.0.1	diffsignuser
27	res_letterbox	106	UP	15	2026-08-09 01:01:27.367898	Circuit de visa mis à jour	listinstance	172.18.0.1	listinstanceCreation
28	res_letterbox	106	ACTION#414	15	2026-08-09 01:01:27.492071	Courriers à traiter : Envoyer au parapheur interne	resource	172.18.0.1	414
29	res_letterbox	106	VIEW	15	2026-08-09 01:01:32.343317	Visualisation du document : 106	resource	172.18.0.1	resview
30	users	15	LOGOUT	15	2026-08-09 01:21:27.302026	Déconnexion de l'utilisateur : ssaporta	authentication	172.18.0.1	userlogout
31	users	15	LOGIN	15	2026-08-09 01:22:15.528495	Connexion de l'utilisateur : ssaporta	authentication	172.18.0.1	userlogin
32	res_letterbox	106	VIEW	15	2026-08-09 01:22:16.338848	Visualisation du document : 106	resource	172.18.0.1	resview
33	users	15	LOGIN	15	2026-08-09 01:22:26.886204	Connexion de l'utilisateur : ssaporta	authentication	172.18.0.1	userlogin
34	res_letterbox	106	VIEW	15	2026-08-09 01:22:27.603171	Visualisation du document : 106	resource	172.18.0.1	resview
35	users	15	LOGIN	15	2026-08-09 01:22:44.604122	Connexion de l'utilisateur : ssaporta	authentication	172.18.0.1	userlogin
36	res_letterbox	106	VIEW	15	2026-08-09 01:22:45.354892	Visualisation du document : 106	resource	172.18.0.1	resview
37	res_letterbox	106	UP	15	2026-08-09 01:23:59.828988	Courrier retiré du parapheur électronique : MAARCH/2026A/2	resource	172.18.0.1	resourceModification
38	res_attachments	1	ADD	15	2026-08-09 01:24:12.680448	Pièce jointe ajoutée	attachment	172.18.0.1	attachmentAdd
39	res_letterbox	106	ADD	15	2026-08-09 01:24:12.683202	Pièce jointe ajoutée : Document test	attachment	172.18.0.1	attachmentAdd
40	users	15	LOGIN	15	2026-08-09 01:26:07.081687	Connexion de l'utilisateur : ssaporta	authentication	172.18.0.1	userlogin
41	res_letterbox	106	VIEW	15	2026-08-09 01:26:07.929485	Visualisation du document : 106	resource	172.18.0.1	resview
42	res_letterbox	106	VIEW	15	2026-08-09 01:26:29.308974	Visualisation du document : 106	resource	172.18.0.1	resview
43	res_letterbox	106	DEL	15	2026-08-09 01:26:48.475295	Circuit de visa supprimé	listinstance	172.18.0.1	listinstanceCreation
44	res_letterbox	106	VIEW	15	2026-08-09 01:26:56.341026	Visualisation du document : 106	resource	172.18.0.1	resview
45	res_letterbox	106	VIEW	15	2026-08-09 01:29:03.101649	Visualisation du document : 106	resource	172.18.0.1	resview
46	res_letterbox	106	VIEW	15	2026-08-09 01:29:33.844937	Visualisation du document : 106	resource	172.18.0.1	resview
47	res_letterbox	106	UP	15	2026-08-09 01:29:51.991212	Circuit de visa mis à jour	listinstance	172.18.0.1	diffsignuser
48	res_letterbox	106	UP	15	2026-08-09 01:29:51.991212	Circuit de visa mis à jour	listinstance	172.18.0.1	listinstanceCreation
49	res_letterbox	106	VIEW	15	2026-08-09 01:29:59.933607	Visualisation du document : 106	resource	172.18.0.1	resview
50	users	15	LOGOUT	15	2026-08-09 01:34:34.448876	Déconnexion de l'utilisateur : ssaporta	authentication	172.18.0.1	userlogout
51	users	15	LOGIN	15	2026-08-09 01:34:48.895106	Connexion de l'utilisateur : ssaporta	authentication	172.18.0.1	userlogin
52	users	15	LOGOUT	15	2026-08-09 01:38:15.935495	Déconnexion de l'utilisateur : ssaporta	authentication	172.18.0.1	userlogout
53	users	15	LOGIN	15	2026-08-09 01:38:25.544893	Connexion de l'utilisateur : ssaporta	authentication	172.18.0.1	userlogin
54	res_letterbox	107	ADD	15	2026-08-09 01:42:51.943194	Courrier créé	resource	172.18.0.1	resourceCreation
55	res_letterbox	107	ACTION#22	15	2026-08-09 01:42:51.992713	Attribuer au service	resource	172.18.0.1	22
56	res_attachments	2	ADD	15	2026-08-09 01:42:52.238232	Pièce jointe ajoutée	attachment	172.18.0.1	attachmentAdd
57	res_letterbox	107	ADD	15	2026-08-09 01:42:52.241131	Pièce jointe ajoutée : Document test	attachment	172.18.0.1	attachmentAdd
58	res_letterbox	107	VIEW	15	2026-08-09 01:42:52.606871	Visualisation du document : 107	resource	172.18.0.1	resview
59	res_letterbox	107	VIEW	15	2026-08-09 01:43:20.992904	Visualisation du document : 107	resource	172.18.0.1	resview
60	res_letterbox	106	VIEW	15	2026-08-09 01:43:52.365761	Visualisation du document : 106	resource	172.18.0.1	resview
61	res_letterbox	107	VIEW	15	2026-08-09 01:43:58.870857	Visualisation du document : 107	resource	172.18.0.1	resview
62	res_letterbox	107	UP	15	2026-08-09 01:44:47.564867	Circuit de visa mis à jour	listinstance	172.18.0.1	diffsignuser
63	res_letterbox	107	UP	15	2026-08-09 01:44:47.564867	Circuit de visa mis à jour	listinstance	172.18.0.1	listinstanceCreation
64	users	15	LOGOUT	15	2026-08-09 01:53:12.149549	Déconnexion de l'utilisateur : ssaporta	authentication	172.18.0.1	userlogout
65	users	15	LOGIN	15	2026-08-09 01:53:25.374174	Connexion de l'utilisateur : ssaporta	authentication	172.18.0.1	userlogin
66	res_letterbox	106	VIEW	15	2026-08-09 02:08:12.654527	Visualisation du document : 106	resource	172.18.0.1	resview
67	res_letterbox	106	VIEW	15	2026-08-09 02:08:23.602891	Visualisation du document : 106	resource	172.18.0.1	resview
68	res_letterbox	106	VIEW	15	2026-08-09 02:08:36.237792	Visualisation du document : 106	resource	172.18.0.1	resview
69	res_letterbox	106	VIEW	15	2026-08-09 02:11:56.107887	Visualisation du document : 106	resource	172.18.0.1	resview
70	res_letterbox	106	UP	15	2026-08-09 02:12:34.81046	Courrier intégré au parapheur électronique : MAARCH/2026A/2	resource	172.18.0.1	resourceModification
71	res_letterbox	106	UP	15	2026-08-09 02:12:35.896378	Courrier retiré du parapheur électronique : MAARCH/2026A/2	resource	172.18.0.1	resourceModification
72	res_letterbox	106	UP	15	2026-08-09 02:12:51.420961	Courrier intégré au parapheur électronique : MAARCH/2026A/2	resource	172.18.0.1	resourceModification
73	users	15	LOGIN	15	2026-08-09 02:16:12.928169	Connexion de l'utilisateur : ssaporta	authentication	172.18.0.1	userlogin
74	users	15	LOGIN	15	2026-08-09 02:16:47.532687	Connexion de l'utilisateur : ssaporta	authentication	172.18.0.1	userlogin
75	users	15	LOGIN	15	2026-08-09 02:19:52.085581	Connexion de l'utilisateur : ssaporta	authentication	172.18.0.1	userlogin
76	res_letterbox	106	VIEW	15	2026-08-09 02:24:04.931762	Visualisation du document : 106	resource	172.18.0.1	resview
77	res_letterbox	107	VIEW	15	2026-08-09 02:25:43.328383	Visualisation du document : 107	resource	172.18.0.1	resview
78	res_letterbox	106	VIEW	15	2026-08-09 02:25:49.467493	Visualisation du document : 106	resource	172.18.0.1	resview
79	res_letterbox	108	ADD	15	2026-08-09 02:36:16.110335	Courrier créé	resource	172.18.0.1	resourceCreation
80	res_letterbox	108	ACTION#22	15	2026-08-09 02:36:16.155326	Attribuer au service	resource	172.18.0.1	22
81	res_attachments	3	ADD	15	2026-08-09 02:36:16.353372	Pièce jointe ajoutée	attachment	172.18.0.1	attachmentAdd
82	res_letterbox	108	ADD	15	2026-08-09 02:36:16.355555	Pièce jointe ajoutée : Document test	attachment	172.18.0.1	attachmentAdd
83	res_letterbox	108	VIEW	15	2026-08-09 02:36:16.680116	Visualisation du document : 108	resource	172.18.0.1	resview
84	res_letterbox	108	VIEW	15	2026-08-09 02:36:39.708965	Visualisation du document : 108	resource	172.18.0.1	resview
85	res_letterbox	108	UP	15	2026-08-09 02:36:47.796872	Circuit de visa mis à jour	listinstance	172.18.0.1	diffsignuser
86	res_letterbox	108	UP	15	2026-08-09 02:36:47.796872	Circuit de visa mis à jour	listinstance	172.18.0.1	listinstanceCreation
87	users	15	LOGIN	15	2026-08-09 02:41:26.518783	Connexion de l'utilisateur : ssaporta	authentication	172.18.0.1	userlogin
88	res_letterbox	108	VIEW	15	2026-08-09 02:42:16.033797	Visualisation du document : 108	resource	172.18.0.1	resview
89	res_letterbox	108	ACTION#527	15	2026-08-09 02:42:33.039446	Courriers à traiter : Envoyer sur la tablette (Maarch Parapheur)Document(s) envoyé(s) au parapheur NGSign	resource	172.18.0.1	527
90	res_letterbox	108	VIEW	15	2026-08-09 02:46:34.341692	Visualisation du document : 108	resource	172.18.0.1	resview
91	res_attachments	3	VIEW	15	2026-08-09 02:46:42.048776	Visualisation de la pièce jointe : 3	attachment	172.18.0.1	resview
92	res_letterbox	108	VIEW	15	2026-08-09 02:46:42.055263	Visualisation de la pièce jointe : Document test	attachment	172.18.0.1	resview
93	users	15	LOGIN	15	2026-08-09 10:47:30.041782	Connexion de l'utilisateur : ssaporta	authentication	172.18.0.1	userlogin
94	res_letterbox	108	VIEW	15	2026-08-09 10:47:31.092202	Visualisation du document : 108	resource	172.18.0.1	resview
95	users	15	LOGIN	15	2026-08-09 10:47:57.223829	Connexion de l'utilisateur : ssaporta	authentication	172.18.0.1	userlogin
96	res_letterbox	108	VIEW	15	2026-08-09 10:47:57.967428	Visualisation du document : 108	resource	172.18.0.1	resview
97	res_letterbox	109	ADD	15	2026-08-09 10:49:49.007071	Courrier créé	resource	172.18.0.1	resourceCreation
98	res_letterbox	109	ACTION#22	15	2026-08-09 10:49:49.059522	Attribuer au service	resource	172.18.0.1	22
99	res_attachments	4	ADD	15	2026-08-09 10:49:49.309085	Pièce jointe ajoutée	attachment	172.18.0.1	attachmentAdd
100	res_letterbox	109	ADD	15	2026-08-09 10:49:49.312325	Pièce jointe ajoutée : NoteInterne	attachment	172.18.0.1	attachmentAdd
101	res_letterbox	109	VIEW	15	2026-08-09 10:49:49.677279	Visualisation du document : 109	resource	172.18.0.1	resview
102	res_letterbox	109	VIEW	15	2026-08-09 10:50:43.058286	Visualisation du document : 109	resource	172.18.0.1	resview
103	users	15	LOGIN	15	2026-08-09 11:03:07.790213	Connexion de l'utilisateur : ssaporta	authentication	172.18.0.1	userlogin
104	res_letterbox	109	VIEW	15	2026-08-09 11:45:20.992789	Visualisation du document : 109	resource	172.18.0.1	resview
105	res_attachments	4	DEL	15	2026-08-09 12:05:27.12203	Pièce-jointe supprimée : NoteInterne	admin	172.18.0.1	attachmentSuppression
106	res_letterbox	109	DEL	15	2026-08-09 12:05:27.124707	Pièce-jointe supprimée : NoteInterne	attachment	172.18.0.1	attachmentAdd
107	res_attachments	5	ADD	15	2026-08-09 12:05:41.09904	Pièce jointe ajoutée	attachment	172.18.0.1	attachmentAdd
108	res_letterbox	109	ADD	15	2026-08-09 12:05:41.103482	Pièce jointe ajoutée : Document test	attachment	172.18.0.1	attachmentAdd
109	res_letterbox	109	UP	15	2026-08-09 12:06:02.294131	Circuit de visa mis à jour	listinstance	172.18.0.1	diffsignuser
110	res_letterbox	109	UP	15	2026-08-09 12:06:02.294131	Circuit de visa mis à jour	listinstance	172.18.0.1	listinstanceCreation
111	res_letterbox	109	ACTION#527	15	2026-08-09 12:06:09.27893	Courriers à traiter : Envoyer sur la tablette (Maarch Parapheur)Document(s) envoyé(s) au parapheur NGSign	resource	172.18.0.1	527
112	res_letterbox	109	VIEW	15	2026-08-09 12:07:24.405741	Visualisation du document : 109	resource	172.18.0.1	resview
113	res_letterbox	109	VIEW	15	2026-08-09 12:12:03.354853	Visualisation du document : 109	resource	172.18.0.1	resview
114	res_attachments	6	ADD	23	2026-08-09 12:56:56.137321	Pièce jointe ajoutée	attachment	127.0.0.1	attachmentAdd
115	res_letterbox	109	ADD	23	2026-08-09 12:56:56.140307	Pièce jointe ajoutée : Document test	attachment	127.0.0.1	attachmentAdd
116	res_attachments	5	UP	23	2026-08-09 12:56:56.156451	La signature de la pièce jointe MAARCH/2026D/7 a été validée dans le parapheur externe	admin		attachup
117	res_letterbox	109	ACTION#1	23	2026-08-09 12:56:56.159816	La signature de la pièce jointe MAARCH/2026D/7 a été validée dans le parapheur externe	admin		1
118	res_letterbox	110	ADD	15	2026-08-09 14:01:40.877873	Courrier créé	resource	172.18.0.1	resourceCreation
119	res_letterbox	110	ACTION#22	15	2026-08-09 14:01:40.944288	Attribuer au service	resource	172.18.0.1	22
120	res_attachments	7	ADD	15	2026-08-09 14:01:41.169524	Pièce jointe ajoutée	attachment	172.18.0.1	attachmentAdd
121	res_letterbox	110	ADD	15	2026-08-09 14:01:41.172948	Pièce jointe ajoutée : Document test	attachment	172.18.0.1	attachmentAdd
122	res_letterbox	110	VIEW	15	2026-08-09 14:01:41.625423	Visualisation du document : 110	resource	172.18.0.1	resview
123	res_letterbox	110	UP	15	2026-08-09 14:01:46.718688	Circuit de visa mis à jour	listinstance	172.18.0.1	diffsignuser
124	res_letterbox	110	UP	15	2026-08-09 14:01:46.718688	Circuit de visa mis à jour	listinstance	172.18.0.1	listinstanceCreation
125	res_letterbox	110	VIEW	15	2026-08-09 14:01:54.45411	Visualisation du document : 110	resource	172.18.0.1	resview
126	res_letterbox	110	VIEW	15	2026-08-09 14:02:09.700341	Visualisation du document : 110	resource	172.18.0.1	resview
127	res_letterbox	110	VIEW	15	2026-08-09 14:16:40.883346	Visualisation du document : 110	resource	172.18.0.1	resview
128	res_letterbox	110	ACTION#527	15	2026-08-09 14:16:58.131723	Courriers à traiter : Envoyer sur la tablette (Maarch Parapheur)Document(s) envoyé(s) au parapheur NGSign	resource	172.18.0.1	527
129	res_attachments	8	ADD	23	2026-08-09 14:20:06.019503	Pièce jointe ajoutée	attachment	127.0.0.1	attachmentAdd
130	res_letterbox	110	ADD	23	2026-08-09 14:20:06.02118	Pièce jointe ajoutée : Document test	attachment	127.0.0.1	attachmentAdd
131	res_attachments	7	UP	23	2026-08-09 14:20:06.03192	La signature de la pièce jointe MAARCH/2026D/8 a été validée dans le parapheur externe	admin		attachup
132	res_letterbox	110	ACTION#1	23	2026-08-09 14:20:06.034555	La signature de la pièce jointe MAARCH/2026D/8 a été validée dans le parapheur externe	admin		1
133	res_letterbox	110	VIEW	15	2026-08-09 14:21:00.46332	Visualisation du document : 110	resource	172.18.0.1	resview
134	res_attachments	7	VIEW	15	2026-08-09 14:21:08.013075	Visualisation de la pièce jointe : 7	attachment	172.18.0.1	resview
135	res_letterbox	110	VIEW	15	2026-08-09 14:21:08.01611	Visualisation de la pièce jointe : Document test	attachment	172.18.0.1	resview
136	res_attachments	8	VIEW	15	2026-08-09 14:21:08.024674	Visualisation de la pièce jointe : 8	attachment	172.18.0.1	resview
137	res_letterbox	110	VIEW	15	2026-08-09 14:21:08.028268	Visualisation de la pièce jointe : Document test	attachment	172.18.0.1	resview
138	res_attachments	8	VIEW	15	2026-08-09 14:21:19.167213	Visualisation de la pièce jointe : 8	attachment	172.18.0.1	resview
139	res_letterbox	110	VIEW	15	2026-08-09 14:21:19.170377	Visualisation de la pièce jointe : Document test	attachment	172.18.0.1	resview
\.


--
-- Data for Name: history_batch; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.history_batch (id, module_name, batch_id, event_date, total_processed, total_errors, info) FROM stdin;
1	retrieveMailsFromSignatoryBook	1	2026-08-09 12:30:13.192556	0	0	0 attachment(s) retrieved from ngsign
2	retrieveMailsFromSignatoryBook	1	2026-08-09 12:30:13.19635	0	0	0 document(s) retrieved from ngsign
3	retrieveMailsFromSignatoryBook	2	2026-08-09 12:35:11.090191	0	0	0 attachment(s) retrieved from ngsign
4	retrieveMailsFromSignatoryBook	2	2026-08-09 12:35:11.091586	0	0	0 document(s) retrieved from ngsign
5	retrieveMailsFromSignatoryBook	3	2026-08-09 12:40:07.648924	0	0	0 attachment(s) retrieved from ngsign
6	retrieveMailsFromSignatoryBook	3	2026-08-09 12:40:07.650383	0	0	0 document(s) retrieved from ngsign
7	retrieveMailsFromSignatoryBook	4	2026-08-09 12:45:16.866691	0	0	0 attachment(s) retrieved from ngsign
8	retrieveMailsFromSignatoryBook	4	2026-08-09 12:45:16.869257	0	0	0 document(s) retrieved from ngsign
9	retrieveMailsFromSignatoryBook	5	2026-08-09 12:55:04.800128	0	0	0 attachment(s) retrieved from ngsign
10	retrieveMailsFromSignatoryBook	5	2026-08-09 12:55:04.812465	0	0	0 document(s) retrieved from ngsign
11	retrieveMailsFromSignatoryBook	6	2026-08-09 12:55:13.583558	0	0	0 attachment(s) retrieved from ngsign
12	retrieveMailsFromSignatoryBook	6	2026-08-09 12:55:13.58567	0	0	0 document(s) retrieved from ngsign
13	retrieveMailsFromSignatoryBook	7	2026-08-09 12:56:56.166883	1	0	1 attachment(s) retrieved from ngsign
14	retrieveMailsFromSignatoryBook	7	2026-08-09 12:56:56.167834	0	0	0 document(s) retrieved from ngsign
15	retrieveMailsFromSignatoryBook	8	2026-08-09 13:00:03.761976	0	0	0 attachment(s) retrieved from ngsign
16	retrieveMailsFromSignatoryBook	8	2026-08-09 13:00:03.763546	0	0	0 document(s) retrieved from ngsign
17	retrieveMailsFromSignatoryBook	9	2026-08-09 13:05:04.745792	0	0	0 attachment(s) retrieved from ngsign
18	retrieveMailsFromSignatoryBook	9	2026-08-09 13:05:04.748917	0	0	0 document(s) retrieved from ngsign
19	retrieveMailsFromSignatoryBook	10	2026-08-09 13:10:05.163559	0	0	0 attachment(s) retrieved from ngsign
20	retrieveMailsFromSignatoryBook	10	2026-08-09 13:10:05.164913	0	0	0 document(s) retrieved from ngsign
21	retrieveMailsFromSignatoryBook	11	2026-08-09 13:15:09.799167	0	0	0 attachment(s) retrieved from ngsign
22	retrieveMailsFromSignatoryBook	11	2026-08-09 13:15:09.80102	0	0	0 document(s) retrieved from ngsign
23	retrieveMailsFromSignatoryBook	12	2026-08-09 13:20:04.648043	0	0	0 attachment(s) retrieved from ngsign
24	retrieveMailsFromSignatoryBook	12	2026-08-09 13:20:04.649646	0	0	0 document(s) retrieved from ngsign
25	retrieveMailsFromSignatoryBook	13	2026-08-09 13:25:05.295301	0	0	0 attachment(s) retrieved from ngsign
26	retrieveMailsFromSignatoryBook	13	2026-08-09 13:25:05.296761	0	0	0 document(s) retrieved from ngsign
27	retrieveMailsFromSignatoryBook	14	2026-08-09 13:30:03.802913	0	0	0 attachment(s) retrieved from ngsign
28	retrieveMailsFromSignatoryBook	14	2026-08-09 13:30:03.805498	0	0	0 document(s) retrieved from ngsign
29	retrieveMailsFromSignatoryBook	15	2026-08-09 13:35:05.417522	0	0	0 attachment(s) retrieved from ngsign
30	retrieveMailsFromSignatoryBook	15	2026-08-09 13:35:05.419351	0	0	0 document(s) retrieved from ngsign
31	retrieveMailsFromSignatoryBook	16	2026-08-09 13:40:06.811239	0	0	0 attachment(s) retrieved from ngsign
32	retrieveMailsFromSignatoryBook	16	2026-08-09 13:40:06.812814	0	0	0 document(s) retrieved from ngsign
33	retrieveMailsFromSignatoryBook	17	2026-08-09 13:55:03.637169	0	0	0 attachment(s) retrieved from ngsign
34	retrieveMailsFromSignatoryBook	17	2026-08-09 13:55:03.640318	0	0	0 document(s) retrieved from ngsign
35	retrieveMailsFromSignatoryBook	18	2026-08-09 14:00:04.495936	0	0	0 attachment(s) retrieved from ngsign
36	retrieveMailsFromSignatoryBook	18	2026-08-09 14:00:04.497933	0	0	0 document(s) retrieved from ngsign
37	retrieveMailsFromSignatoryBook	19	2026-08-09 14:05:03.235423	0	0	0 attachment(s) retrieved from ngsign
38	retrieveMailsFromSignatoryBook	19	2026-08-09 14:05:03.236969	0	0	0 document(s) retrieved from ngsign
39	retrieveMailsFromSignatoryBook	20	2026-08-09 14:10:03.162722	0	0	0 attachment(s) retrieved from ngsign
40	retrieveMailsFromSignatoryBook	20	2026-08-09 14:10:03.165773	0	0	0 document(s) retrieved from ngsign
41	retrieveMailsFromSignatoryBook	21	2026-08-09 14:15:03.488311	0	0	0 attachment(s) retrieved from ngsign
42	retrieveMailsFromSignatoryBook	21	2026-08-09 14:15:03.489811	0	0	0 document(s) retrieved from ngsign
43	retrieveMailsFromSignatoryBook	22	2026-08-09 14:20:06.038842	1	0	1 attachment(s) retrieved from ngsign
44	retrieveMailsFromSignatoryBook	22	2026-08-09 14:20:06.039972	0	0	0 document(s) retrieved from ngsign
45	retrieveMailsFromSignatoryBook	23	2026-08-09 14:25:02.736787	0	0	0 attachment(s) retrieved from ngsign
46	retrieveMailsFromSignatoryBook	23	2026-08-09 14:25:02.739186	0	0	0 document(s) retrieved from ngsign
47	retrieveMailsFromSignatoryBook	24	2026-08-09 14:30:03.4779	0	0	0 attachment(s) retrieved from ngsign
48	retrieveMailsFromSignatoryBook	24	2026-08-09 14:30:03.479544	0	0	0 document(s) retrieved from ngsign
49	retrieveMailsFromSignatoryBook	25	2026-08-09 14:35:02.991579	0	0	0 attachment(s) retrieved from ngsign
50	retrieveMailsFromSignatoryBook	25	2026-08-09 14:35:02.993718	0	0	0 document(s) retrieved from ngsign
51	retrieveMailsFromSignatoryBook	26	2026-08-09 14:40:03.831382	0	0	0 attachment(s) retrieved from ngsign
52	retrieveMailsFromSignatoryBook	26	2026-08-09 14:40:03.834529	0	0	0 document(s) retrieved from ngsign
53	retrieveMailsFromSignatoryBook	27	2026-08-09 14:45:06.949365	0	0	0 attachment(s) retrieved from ngsign
54	retrieveMailsFromSignatoryBook	27	2026-08-09 14:45:06.971194	0	0	0 document(s) retrieved from ngsign
55	retrieveMailsFromSignatoryBook	28	2026-08-09 14:50:03.001167	0	0	0 attachment(s) retrieved from ngsign
56	retrieveMailsFromSignatoryBook	28	2026-08-09 14:50:03.003202	0	0	0 document(s) retrieved from ngsign
57	retrieveMailsFromSignatoryBook	29	2026-08-09 15:00:03.407557	0	0	0 attachment(s) retrieved from ngsign
58	retrieveMailsFromSignatoryBook	29	2026-08-09 15:00:03.410117	0	0	0 document(s) retrieved from ngsign
59	retrieveMailsFromSignatoryBook	30	2026-08-09 15:05:03.514163	0	0	0 attachment(s) retrieved from ngsign
60	retrieveMailsFromSignatoryBook	30	2026-08-09 15:05:03.518539	0	0	0 document(s) retrieved from ngsign
61	retrieveMailsFromSignatoryBook	31	2026-08-09 15:10:04.737714	0	0	0 attachment(s) retrieved from ngsign
62	retrieveMailsFromSignatoryBook	31	2026-08-09 15:10:04.739991	0	0	0 document(s) retrieved from ngsign
63	retrieveMailsFromSignatoryBook	32	2026-08-09 15:15:02.490053	0	0	0 attachment(s) retrieved from ngsign
64	retrieveMailsFromSignatoryBook	32	2026-08-09 15:15:02.49146	0	0	0 document(s) retrieved from ngsign
65	retrieveMailsFromSignatoryBook	33	2026-08-09 15:20:02.659807	0	0	0 attachment(s) retrieved from ngsign
66	retrieveMailsFromSignatoryBook	33	2026-08-09 15:20:02.661216	0	0	0 document(s) retrieved from ngsign
67	retrieveMailsFromSignatoryBook	34	2026-08-09 15:25:13.533512	0	0	0 attachment(s) retrieved from ngsign
68	retrieveMailsFromSignatoryBook	34	2026-08-09 15:25:13.536682	0	0	0 document(s) retrieved from ngsign
69	retrieveMailsFromSignatoryBook	35	2026-08-09 15:30:14.523744	0	0	0 attachment(s) retrieved from ngsign
70	retrieveMailsFromSignatoryBook	35	2026-08-09 15:30:14.525319	0	0	0 document(s) retrieved from ngsign
71	retrieveMailsFromSignatoryBook	36	2026-08-09 15:35:02.962476	0	0	0 attachment(s) retrieved from ngsign
72	retrieveMailsFromSignatoryBook	36	2026-08-09 15:35:02.965037	0	0	0 document(s) retrieved from ngsign
73	retrieveMailsFromSignatoryBook	37	2026-08-09 15:55:02.368187	0	0	0 attachment(s) retrieved from ngsign
74	retrieveMailsFromSignatoryBook	37	2026-08-09 15:55:02.371108	0	0	0 document(s) retrieved from ngsign
75	retrieveMailsFromSignatoryBook	38	2026-08-09 16:00:01.874221	0	0	0 attachment(s) retrieved from ngsign
76	retrieveMailsFromSignatoryBook	38	2026-08-09 16:00:01.875784	0	0	0 document(s) retrieved from ngsign
77	retrieveMailsFromSignatoryBook	39	2026-08-09 16:05:02.393335	0	0	0 attachment(s) retrieved from ngsign
78	retrieveMailsFromSignatoryBook	39	2026-08-09 16:05:02.395479	0	0	0 document(s) retrieved from ngsign
79	retrieveMailsFromSignatoryBook	40	2026-08-09 16:35:55.306238	0	0	0 attachment(s) retrieved from ngsign
80	retrieveMailsFromSignatoryBook	40	2026-08-09 16:35:55.307355	0	0	0 document(s) retrieved from ngsign
81	retrieveMailsFromSignatoryBook	41	2026-08-09 16:40:01.965998	0	0	0 attachment(s) retrieved from ngsign
82	retrieveMailsFromSignatoryBook	41	2026-08-09 16:40:01.968054	0	0	0 document(s) retrieved from ngsign
83	retrieveMailsFromSignatoryBook	42	2026-08-09 17:00:02.758501	0	0	0 attachment(s) retrieved from ngsign
84	retrieveMailsFromSignatoryBook	42	2026-08-09 17:00:02.770642	0	0	0 document(s) retrieved from ngsign
85	retrieveMailsFromSignatoryBook	43	2026-08-09 17:15:38.33304	0	0	0 attachment(s) retrieved from ngsign
86	retrieveMailsFromSignatoryBook	43	2026-08-09 17:15:38.334326	0	0	0 document(s) retrieved from ngsign
87	retrieveMailsFromSignatoryBook	44	2026-08-09 17:20:01.789287	0	0	0 attachment(s) retrieved from ngsign
88	retrieveMailsFromSignatoryBook	44	2026-08-09 17:20:01.791368	0	0	0 document(s) retrieved from ngsign
89	retrieveMailsFromSignatoryBook	45	2026-08-09 17:40:02.84888	0	0	0 attachment(s) retrieved from ngsign
90	retrieveMailsFromSignatoryBook	45	2026-08-09 17:40:02.852155	0	0	0 document(s) retrieved from ngsign
91	retrieveMailsFromSignatoryBook	46	2026-08-09 18:00:02.450801	0	0	0 attachment(s) retrieved from ngsign
92	retrieveMailsFromSignatoryBook	46	2026-08-09 18:00:02.455236	0	0	0 document(s) retrieved from ngsign
93	retrieveMailsFromSignatoryBook	47	2026-08-09 18:20:02.212508	0	0	0 attachment(s) retrieved from ngsign
94	retrieveMailsFromSignatoryBook	47	2026-08-09 18:20:02.213695	0	0	0 document(s) retrieved from ngsign
95	retrieveMailsFromSignatoryBook	48	2026-08-09 18:25:01.753513	0	0	0 attachment(s) retrieved from ngsign
96	retrieveMailsFromSignatoryBook	48	2026-08-09 18:25:01.755565	0	0	0 document(s) retrieved from ngsign
97	retrieveMailsFromSignatoryBook	49	2026-08-09 18:40:59.796686	0	0	0 attachment(s) retrieved from ngsign
98	retrieveMailsFromSignatoryBook	49	2026-08-09 18:40:59.799747	0	0	0 document(s) retrieved from ngsign
99	retrieveMailsFromSignatoryBook	50	2026-08-09 18:45:02.32369	0	0	0 attachment(s) retrieved from ngsign
100	retrieveMailsFromSignatoryBook	50	2026-08-09 18:45:02.325571	0	0	0 document(s) retrieved from ngsign
\.


--
-- Data for Name: indexing_models; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.indexing_models (id, label, category, "default", owner, private, master, enabled, mandatory_file, lad_processing) FROM stdin;
2	Courrier Départ	outgoing	f	23	f	\N	t	f	f
3	Note Interne	internal	f	23	f	\N	t	f	f
4	Document GED	ged_doc	f	23	f	\N	t	f	f
1	Courrier Arrivée	incoming	t	23	f	\N	t	t	t
5	Exemple de données pré-enregistrées	incoming	f	21	t	1	t	t	f
7	Demande de documents	outgoing	f	16	t	2	t	f	f
8	Courriels importés	incoming	f	23	f	\N	t	f	f
\.


--
-- Data for Name: indexing_models_entities; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.indexing_models_entities (id, model_id, entity_id, keyword) FROM stdin;
1	2	\N	ALL_ENTITIES
2	3	\N	ALL_ENTITIES
3	4	\N	ALL_ENTITIES
4	1	\N	ALL_ENTITIES
5	8	\N	ALL_ENTITIES
6	2	\N	ALL_ENTITIES
7	3	\N	ALL_ENTITIES
8	4	\N	ALL_ENTITIES
9	1	\N	ALL_ENTITIES
10	8	\N	ALL_ENTITIES
\.


--
-- Data for Name: indexing_models_fields; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.indexing_models_fields (id, model_id, identifier, mandatory, enabled, default_value, unit, allowed_values) FROM stdin;
9	2	doctype	t	t	\N	mail	\N
10	2	priority	t	t	\N	mail	\N
11	2	confidentiality	t	t	\N	mail	\N
12	2	documentDate	t	t	\N	mail	\N
13	2	departureDate	t	t	\N	mail	\N
14	2	subject	t	t	\N	mail	\N
15	2	senders	f	t	\N	contact	\N
16	2	recipients	t	t	\N	contact	\N
17	2	initiator	t	t	\N	process	\N
18	2	destination	t	t	\N	process	\N
19	2	processLimitDate	t	t	\N	process	\N
20	2	folders	f	t	\N	classifying	\N
21	2	tags	f	t	\N	classifying	\N
22	3	doctype	t	t	\N	mail	\N
23	3	priority	t	t	\N	mail	\N
24	3	confidentiality	t	t	\N	mail	\N
25	3	documentDate	t	t	"_TODAY"	mail	\N
26	3	subject	t	t	\N	mail	\N
27	3	senders	f	t	[]	contact	\N
28	3	initiator	t	t	\N	process	\N
29	3	destination	t	t	\N	process	\N
30	3	processLimitDate	t	t	\N	process	\N
31	3	folders	f	t	\N	classifying	\N
32	3	tags	f	t	\N	classifying	\N
33	4	doctype	t	t	\N	mail	\N
34	4	documentDate	t	t	\N	mail	\N
35	4	subject	t	t	\N	mail	\N
36	4	senders	f	t	\N	contact	\N
37	4	destination	t	t	\N	process	\N
38	4	indexingCustomField_1	f	t	\N	process	\N
39	4	folders	f	t	\N	classifying	\N
40	4	tags	f	t	\N	classifying	\N
41	1	doctype	t	t	\N	mail	\N
42	1	priority	t	t	\N	mail	\N
43	1	documentDate	t	t	\N	mail	\N
44	1	arrivalDate	t	t	"_TODAY"	mail	\N
45	1	subject	t	t	\N	mail	\N
46	1	senders	t	t	\N	contact	\N
47	1	destination	t	t	\N	process	\N
48	1	processLimitDate	t	t	\N	process	\N
49	5	doctype	t	t	1202	mail	\N
50	5	priority	t	t	"poiuytre1391nbvc"	mail	\N
51	5	documentDate	t	t	"2021-03-24"	mail	\N
52	5	arrivalDate	t	t	"2021-03-24"	mail	\N
53	5	subject	t	t	"Demande d'interventions"	mail	\N
54	5	senders	t	t	[{"type":"contact","id":6,"label":"Bernard PASCONTENT"}]	contact	\N
55	5	destination	t	t	10	process	\N
56	5	diffusionList	f	t	[{"id":16,"mode":"dest","type":"user"},{"id":12,"mode":"cc","type":"entity"},{"id":20,"mode":"cc","type":"entity"}]	process	\N
57	5	processLimitDate	t	t	"2021-03-30"	process	\N
72	7	doctype	t	t	106	mail	\N
73	7	priority	t	t	"poiuytre1357nbvc"	mail	\N
74	7	confidentiality	t	t	false	mail	\N
75	7	documentDate	t	t	"2021-03-25"	mail	\N
76	7	departureDate	t	t	"2021-03-30"	mail	\N
77	7	subject	t	t	"Demande de Kbis"	mail	\N
78	7	senders	f	t	[{"type":"entity","id":10,"label":"P\\u00f4le Technique"}]	contact	\N
79	7	recipients	t	t	[{"type":"contact","id":10,"label":"Carole COTIN (MAARCH)"}]	contact	\N
80	7	initiator	t	t	10	process	\N
81	7	destination	t	t	10	process	\N
82	7	diffusionList	f	t	[{"id":16,"mode":"dest","type":"user"},{"id":12,"mode":"cc","type":"entity"},{"id":20,"mode":"cc","type":"entity"}]	process	\N
83	7	processLimitDate	t	t	"2021-06-18"	process	\N
84	7	folders	f	t	[16]	classifying	\N
85	7	tags	f	t	[4]	classifying	\N
86	8	doctype	t	t	\N	mail	\N
87	8	documentDate	f	t	\N	mail	\N
88	8	priority	f	t	"poiuytre1357nbvc"	mail	\N
89	8	subject	t	t	\N	mail	\N
90	8	senders	f	t	\N	contact	\N
91	8	destination	f	t	"#myPrimaryEntity"	process	\N
92	8	processLimitDate	f	t	"2021-05-13"	process	\N
\.


--
-- Data for Name: lc_cycle_steps; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.lc_cycle_steps (policy_id, cycle_id, cycle_step_id, cycle_step_desc, docserver_type_id, is_allow_failure, step_operation, sequence_number, is_must_complete, preprocess_script, postprocess_script) FROM stdin;
\.


--
-- Data for Name: lc_cycles; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.lc_cycles (policy_id, cycle_id, cycle_desc, sequence_number, where_clause, break_key, validation_mode) FROM stdin;
\.


--
-- Data for Name: lc_policies; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.lc_policies (policy_id, policy_name, policy_desc) FROM stdin;
\.


--
-- Data for Name: lc_stack; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.lc_stack (policy_id, cycle_id, cycle_step_id, coll_id, res_id, cnt_retry, status, work_batch, regex) FROM stdin;
\.


--
-- Data for Name: list_templates; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.list_templates (id, title, description, type, entity_id, owner) FROM stdin;
1	Ville de Maarch-les-bains	Ville de Maarch-les-bains	diffusionList	1	\N
2	Cabinet du Maire	Cabinet du Maire	diffusionList	2	\N
3	Direction Générale des Services	Direction Générale des Services	diffusionList	3	\N
4	Direction Générale Adjointe	Direction Générale Adjointe	diffusionList	4	\N
5	Pôle Culturel	Pôle Culturel	diffusionList	5	\N
6	Pôle Jeunesse et Sport	Pôle Jeunesse et Sport	diffusionList	6	\N
7	Petite enfance	Petite enfance	diffusionList	7	\N
8	Sport	Sport	diffusionList	8	\N
9	Pôle Social	Pôle Social	diffusionList	9	\N
1009	visa Pôle Social	visa Pôle Social	visaCircuit	9	\N
10	Pôle Technique	Pôle Technique	diffusionList	10	\N
1010	visa Pôle Technique	visa Pôle Technique	visaCircuit	10	\N
11	Direction des Ressources Humaines	Direction des Ressources Humaines	diffusionList	11	\N
12	Secrétariat Général	Secrétariat Général	diffusionList	12	\N
13	Service Courrier	Service Courrier	diffusionList	13	\N
14	Correspondants Archive	Correspondants Archive	diffusionList	14	\N
15	Services Fonctionnels	Pôle des Services Fonctionnels	diffusionList	15	\N
16	Direction des Systèmes d'Information	Direction des Systèmes d'Information	diffusionList	16	\N
17	Direction des Finances	Direction des Finances	diffusionList	17	\N
18	Pôle Juridique	Pôle Juridique	diffusionList	18	\N
\.


--
-- Data for Name: list_templates_items; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.list_templates_items (id, list_template_id, item_id, item_type, item_mode, sequence) FROM stdin;
1	1	15	user	dest	0
2	2	7	user	dest	0
3	2	12	entity	cc	1
4	2	10	user	cc	2
5	2	3	user	cc	3
6	3	1	user	dest	0
7	3	10	user	cc	1
8	4	17	user	dest	0
9	4	12	entity	cc	1
10	4	8	user	cc	2
11	5	9	user	dest	0
12	5	12	entity	cc	1
13	6	19	user	dest	0
14	6	1	entity	cc	1
15	7	15	user	dest	0
16	7	12	entity	cc	1
17	8	13	user	dest	0
18	8	12	entity	cc	1
19	9	4	user	dest	0
20	9	12	entity	cc	1
21	1009	17	user	visa	0
22	1009	10	user	sign	1
23	10	16	user	dest	0
24	10	12	entity	cc	1
25	10	20	entity	cc	2
26	1010	17	user	visa	0
27	1010	10	user	sign	1
28	11	12	user	dest	0
29	11	12	entity	cc	1
30	12	18	user	dest	0
31	13	21	user	dest	0
32	13	12	entity	cc	1
33	14	22	user	dest	0
34	14	14	user	cc	1
35	15	11	user	dest	0
36	15	12	entity	cc	1
37	16	3	user	dest	0
38	16	12	entity	cc	1
39	16	2	user	cc	2
40	17	14	user	dest	0
41	17	12	entity	cc	1
42	17	6	user	cc	2
43	18	20	user	dest	0
44	18	12	entity	cc	1
\.


--
-- Data for Name: listinstance; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.listinstance (listinstance_id, res_id, sequence, item_id, item_type, item_mode, added_by_user, viewed, difflist_type, process_date, process_comment, signatory, requested_signature, delegate) FROM stdin;
1	106	0	15	user_id	dest	9	0	entity_id	\N	\N	f	f	\N
5	106	0	18	user_id	sign	15	0	VISA_CIRCUIT	\N	\N	f	t	\N
6	107	0	15	user_id	dest	15	0	entity_id	\N	\N	f	f	\N
7	107	0	12	entity_id	cc	15	0	entity_id	\N	\N	f	f	\N
8	107	0	18	user_id	sign	15	0	VISA_CIRCUIT	\N	\N	f	t	\N
9	108	0	15	user_id	dest	15	0	entity_id	\N	\N	f	f	\N
10	108	0	12	entity_id	cc	15	0	entity_id	\N	\N	f	f	\N
11	108	0	18	user_id	sign	15	0	VISA_CIRCUIT	\N	\N	f	t	\N
12	109	0	15	user_id	dest	15	0	entity_id	\N	\N	f	f	\N
13	109	0	12	entity_id	cc	15	0	entity_id	\N	\N	f	f	\N
14	109	0	18	user_id	sign	15	0	VISA_CIRCUIT	\N	\N	f	t	\N
15	110	0	15	user_id	dest	15	0	entity_id	\N	\N	f	f	\N
16	110	0	12	entity_id	cc	15	0	entity_id	\N	\N	f	f	\N
17	110	0	18	user_id	sign	15	0	VISA_CIRCUIT	\N	\N	f	t	\N
\.


--
-- Data for Name: listinstance_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.listinstance_history (listinstance_history_id, coll_id, res_id, user_id, updated_date) FROM stdin;
1	letterbox_coll	106	15	2026-08-09 00:59:33.448489
2	letterbox_coll	106	15	2026-08-09 01:00:23.82874
3	letterbox_coll	106	15	2026-08-09 01:01:27.367898
4	letterbox_coll	106	15	2026-08-09 01:29:51.991212
5	letterbox_coll	107	15	2026-08-09 01:44:47.564867
6	letterbox_coll	108	15	2026-08-09 02:36:47.796872
7	letterbox_coll	109	15	2026-08-09 12:06:02.294131
8	letterbox_coll	110	15	2026-08-09 14:01:46.718688
\.


--
-- Data for Name: listinstance_history_details; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.listinstance_history_details (listinstance_history_details_id, listinstance_history_id, coll_id, res_id, listinstance_type, sequence, item_id, item_type, item_mode, added_by_user, visible, viewed, difflist_type, process_date, process_comment, requested_signature, signatory) FROM stdin;
1	1	letterbox_coll	106	DOC	0	18	user_id	sign	15	Y	0	VISA_CIRCUIT	\N	\N	t	f
2	2	letterbox_coll	106	DOC	0	18	user_id	sign	15	Y	0	VISA_CIRCUIT	\N	\N	t	f
3	3	letterbox_coll	106	DOC	0	18	user_id	sign	15	Y	0	VISA_CIRCUIT	\N	\N	t	f
4	4	letterbox_coll	106	DOC	0	18	user_id	sign	15	Y	0	VISA_CIRCUIT	\N	\N	t	f
5	5	letterbox_coll	107	DOC	0	18	user_id	sign	15	Y	0	VISA_CIRCUIT	\N	\N	t	f
6	6	letterbox_coll	108	DOC	0	18	user_id	sign	15	Y	0	VISA_CIRCUIT	\N	\N	t	f
7	7	letterbox_coll	109	DOC	0	18	user_id	sign	15	Y	0	VISA_CIRCUIT	\N	\N	t	f
8	8	letterbox_coll	110	DOC	0	18	user_id	sign	15	Y	0	VISA_CIRCUIT	\N	\N	t	f
\.


--
-- Data for Name: message_exchange; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.message_exchange (message_id, schema, type, status, date, reference, account_id, sender_org_identifier, sender_org_name, recipient_org_identifier, recipient_org_name, archival_agreement_reference, reply_code, operation_date, reception_date, related_reference, request_reference, reply_reference, derogation, data_object_count, size, data, active, archived, res_id_master, docserver_id, path, filename, fingerprint, filesize, file_path) FROM stdin;
\.


--
-- Data for Name: note_entities; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.note_entities (id, note_id, item_id) FROM stdin;
\.


--
-- Data for Name: notes; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.notes (id, identifier, user_id, creation_date, note_text) FROM stdin;
1	109	23	2026-08-09 12:56:56.152001	Signé via NGSign (transaction 5931d244-8e11-4610-b94f-ce13b086aa74)
2	110	23	2026-08-09 14:20:06.029771	Signé via NGSign (transaction af3e520a-c9c7-4004-a470-1ba53f35f2dc)
\.


--
-- Data for Name: notif_email_stack; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.notif_email_stack (email_stack_sid, reply_to, recipient, cc, bcc, subject, html_body, attachments, exec_date, exec_result) FROM stdin;
\.


--
-- Data for Name: notif_event_stack; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.notif_event_stack (event_stack_sid, notification_sid, table_name, record_id, user_id, event_info, event_date, exec_date, exec_result) FROM stdin;
1	7	res_letterbox	109	23	La signature de la pièce jointe MAARCH/2026D/7 a été validée dans le parapheur externe	2026-08-09 12:56:56.161634	\N	\N
2	7	res_letterbox	110	23	La signature de la pièce jointe MAARCH/2026D/8 a été validée dans le parapheur externe	2026-08-09 14:20:06.035803	\N	\N
\.


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.notifications (notification_sid, notification_id, description, is_enabled, event_id, notification_mode, template_id, diffusion_type, diffusion_properties, attachfor_type, attachfor_properties, send_as_recap) FROM stdin;
1	USERS	[administration] Actions sur les utilisateurs de l'application	Y	users%	EMAIL	2	user	superadmin			f
2	RET2	Courriers en retard de traitement	Y	alert2	EMAIL	5	dest_user				f
3	RET1	Courriers arrivant à échéance	Y	alert1	EMAIL	6	dest_user				f
4	BASKETS	Notification de bannettes	Y	baskets	EMAIL	7	dest_user				f
5	ANC	Nouvelle annotation sur courrier en copie	Y	noteadd	EMAIL	8	copy_list				f
6	AND	Nouvelle annotation sur courrier destinataire	Y	noteadd	EMAIL	8	dest_user				f
7	RED	Redirection de courrier	Y	1	EMAIL	7	dest_user				f
100	QUOTA	Alerte lorsque le quota est dépassé	Y	user_quota	EMAIL	110	user	superadmin	\N	\N	f
\.


--
-- Data for Name: parameters; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.parameters (id, description, param_value_string, param_value_int, param_value_date) FROM stdin;
work_batch_autoimport_id	\N	\N	1	\N
user_quota	\N		0	\N
defaultDepartment	Département par défaut sélectionné dans les autocomplétions de la Base Adresse Nationale	75	\N	\N
thumbnailsSize	Résolution des imagettes	750x900	\N	\N
QrCodePrefix	Si activé (1), ajoute "Maarch_" dans le contenu des QrCode générés. (Utilisable avec MaarchCapture >= 1.4)	\N	0	\N
workingDays	Si activé (1), les délais de traitement sont calculés en jours ouvrés (Lundi à Vendredi). Sinon, en jours calendaire	\N	1	\N
last_deposit_id	\N	\N	0	\N
registeredMailNotDistributedStatus	\N	PND	\N	\N
registeredMailDistributedStatus	\N	DSTRIBUTED	\N	\N
registeredMailImportedStatus	\N	NEW	\N	\N
keepDiffusionRoleInOutgoingIndexation	Si activé (1), prend en compte les roles du modèle de diffusion de l'entité.	\N	1	\N
bindingDocumentFinalAction	\N	copy	\N	\N
nonBindingDocumentFinalAction	\N	delete	\N	\N
minimumVisaRole	\N	\N	0	\N
maximumSignRole	\N	\N	0	\N
workflowSignatoryRole	Rôle de signataire dans le circuit	mandatory	\N	\N
siret	Numéro SIRET de l'entreprise	45239273100025	\N	\N
homepage_message		<p><span style="font-size: 14pt;">Bienvenue sur <strong>Maarch Courrier 2301</strong> </span><br /><span style="font-size: 14pt;">Suivez le <a title="notre guide de visite" href="https://docs.maarch.org/" target="_blank" rel="noopener"><span style="color: #f99830;"><strong>guide de visite en ligne</strong></span></a></span></p>	\N	\N
loginpage_message		<p><span style="font-size: 14pt; color: #ecf0f1;"><span style="color: #000000;"><strong>Acc&eacute;der au</strong> </span><a style="color: ##3598db;" title="le guide de visite" href="https://docs.maarch.org/gitbook/html/MaarchCourrier/2301/guu/home.html" target="_blank" rel="noopener"><strong>guide de visite en ligne</strong></a></span></p>	\N	\N
traffic_record_summary_sheet			\N	\N
chrono_outgoing_2021		\N	3	\N
chrono_incoming_2021		\N	4	\N
suggest_links_n_days_ago	Le nombre de jours sur lequel sont cherchés les courriers à lier	\N	0	\N
noteVisibilityOffAction	Visibilité par défaut des annotations hors actions (0 = toutes les entités, 1 = restreint)	\N	0	\N
noteVisibilityOnAction	Visibilité par défaut des annotations sur les actions (0 = toutes les entités, 1 = restreint)	\N	0	\N
allowMultipleAvisAssignment	Un utilisateur peut fournir plusieurs avis tout en conservant le même rôle	\N	0	\N
database_version	\N	2301.2.0	\N	\N
retrieveMailsFromSignatoryBook_id		\N	50	\N
chrono_incoming_2026	\N	\N	6	\N
chrono_outgoing_2026	\N	\N	8	\N
\.


--
-- Data for Name: password_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.password_history (id, user_serial_id, password) FROM stdin;
\.


--
-- Data for Name: password_rules; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.password_rules (id, label, value, enabled) FROM stdin;
1	minLength	6	t
2	complexityUpper	0	f
3	complexityNumber	0	f
4	complexitySpecial	0	f
5	lockAttempts	3	f
6	lockTime	5	f
7	historyLastUse	2	f
8	renewal	90	f
\.


--
-- Data for Name: priorities; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.priorities (id, label, color, delays, "order") FROM stdin;
poiuytre1357nbvc	Normal	#009dc5	30	1
poiuytre1379nbvc	Urgent	#ffa500	8	2
poiuytre1391nbvc	Très urgent	#ff0000	4	3
\.


--
-- Data for Name: redirected_baskets; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.redirected_baskets (id, actual_user_id, owner_user_id, basket_id, group_id) FROM stdin;
\.


--
-- Data for Name: registered_mail_issuing_sites; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.registered_mail_issuing_sites (id, label, post_office_label, account_number, address_number, address_street, address_additional1, address_additional2, address_postcode, address_town, address_country) FROM stdin;
1	MAARCH - Nanterre	La poste Nanterre	1234567	10	AVENUE DE LA GRANDE ARMEE			75017	PARIS	FRANCE
\.


--
-- Data for Name: registered_mail_issuing_sites_entities; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.registered_mail_issuing_sites_entities (id, site_id, entity_id) FROM stdin;
1	1	6
2	1	13
\.


--
-- Data for Name: registered_mail_number_range; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.registered_mail_number_range (id, type, tracking_account_number, range_start, range_end, creator, creation_date, status, current_number) FROM stdin;
1	2C	SuiviNumber	1	10	23	2020-09-14 14:38:09.008644	OK	1
2	RW	SuiviNumberInternational	1	10	23	2020-09-14 14:39:32.972626	OK	1
3	2D	suiviNumber	1	10	23	2020-09-14 14:39:16.779322	OK	1
\.


--
-- Data for Name: registered_mail_resources; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.registered_mail_resources (id, res_id, type, issuing_site, warranty, letter, recipient, number, reference, generated, deposit_id, received_date, return_reason) FROM stdin;
\.


--
-- Data for Name: res_attachments; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.res_attachments (res_id, title, format, typist, creation_date, modification_date, modified_by, identifier, relation, docserver_id, path, filename, fingerprint, filesize, status, validation_date, effective_date, work_batch, origin, res_id_master, origin_id, attachment_type, recipient_id, recipient_type, in_signature_book, in_send_attach, signatory_user_serial_id, fulltext_result, external_id, external_state) FROM stdin;
1	Document test	pdf	15	2026-08-09 01:24:12.66283	2026-08-09 01:24:12.66283	\N	MAARCH/2026D/6	1	FASTHD_ATTACH	2026/08/0001/	0001_791443737.pdf	3bdc2d1eb909c86432f6e6bb3b5d2d00c71e642bba0978388b5abd48b427b7a5bfac3157d86144a59e7ec824885dc863086ee3a25354136e58aacb70abb5e244	141226	A_TRA	\N	\N	\N	\N	106	\N	response_project	12	contact	t	f	\N	SUCCESS	{}	{}
2	Document test	pdf	15	2026-08-09 01:42:52.219811	2026-08-09 01:42:52.219811	\N	\N	1	FASTHD_ATTACH	2026/08/0001/	0002_2031538250.pdf	3bdc2d1eb909c86432f6e6bb3b5d2d00c71e642bba0978388b5abd48b427b7a5bfac3157d86144a59e7ec824885dc863086ee3a25354136e58aacb70abb5e244	141226	A_TRA	\N	\N	\N	\N	107	\N	simple_attachment	\N	\N	f	f	\N	SUCCESS	{}	{}
3	Document test	pdf	15	2026-08-09 02:36:16.34244	2026-08-09 02:36:16.34244	\N	\N	1	FASTHD_ATTACH	2026/08/0001/	0003_1698841922.pdf	3bdc2d1eb909c86432f6e6bb3b5d2d00c71e642bba0978388b5abd48b427b7a5bfac3157d86144a59e7ec824885dc863086ee3a25354136e58aacb70abb5e244	141226	FRZ	\N	\N	\N	\N	108	\N	response_project	\N	\N	t	f	\N	SUCCESS	{"signatureBookId": "ddad7074-3d20-43a6-8410-8c0c8ebb0667/27b04b45-727e-4982-bdda-250f61f0d9a0"}	{}
4	NoteInterne	pdf	15	2026-08-09 10:49:49.288622	2026-08-09 10:49:49.288622	\N	\N	1	FASTHD_ATTACH	2026/08/0001/	0004_194088791.pdf	3bdc2d1eb909c86432f6e6bb3b5d2d00c71e642bba0978388b5abd48b427b7a5bfac3157d86144a59e7ec824885dc863086ee3a25354136e58aacb70abb5e244	141226	DEL	\N	\N	\N	\N	109	\N	simple_attachment	\N	\N	f	f	\N	SUCCESS	{}	{}
5	Document test	pdf	15	2026-08-09 12:05:41.081639	2026-08-09 12:05:41.081639	\N	MAARCH/2026D/7	1	FASTHD_ATTACH	2026/08/0001/	0005_556454559.pdf	3bdc2d1eb909c86432f6e6bb3b5d2d00c71e642bba0978388b5abd48b427b7a5bfac3157d86144a59e7ec824885dc863086ee3a25354136e58aacb70abb5e244	141226	SIGN	\N	\N	\N	\N	109	\N	response_project	12	contact	f	f	\N	SUCCESS	{}	{}
6	Document test	pdf	15	2026-08-09 12:56:56.126832	2026-08-09 12:56:56.126832	\N	MAARCH/2026D/7	1	FASTHD_ATTACH	2026/08/0001/	0006_710572027.pdf	4f0df54cd2df7d0fc3a8a1c62328e1e9052ffb1b70e7b2c9ab595a5b75562a642dbe6a7a201ea708354547e4703ff0767873e99d71254d5d16dc68775e2d4ed0	187503	TRA	\N	\N	\N	5,res_attachments	109	\N	signed_response	12	contact	t	f	\N	SUCCESS	{}	{}
7	Document test	pdf	15	2026-08-09 14:01:41.15406	2026-08-09 14:01:41.15406	\N	MAARCH/2026D/8	1	FASTHD_ATTACH	2026/08/0001/	0007_943587773.pdf	3bdc2d1eb909c86432f6e6bb3b5d2d00c71e642bba0978388b5abd48b427b7a5bfac3157d86144a59e7ec824885dc863086ee3a25354136e58aacb70abb5e244	141226	SIGN	\N	\N	\N	\N	110	\N	response_project	\N	\N	f	f	\N	SUCCESS	{}	{}
8	Document test	pdf	15	2026-08-09 14:20:06.010718	2026-08-09 14:20:06.010718	\N	MAARCH/2026D/8	1	FASTHD_ATTACH	2026/08/0001/	0008_1980679099.pdf	f32db388c15d700a5f1301bb3269a59cf36ee48da4ecce97cf589ab808a97687e68ca24cb77af323b2a8b0e9c4c0fd808501fbd9995e6721ab3b5a92b01928d8	184044	TRA	\N	\N	\N	7,res_attachments	110	\N	signed_response	\N	\N	t	f	\N	SUCCESS	{}	{}
\.


--
-- Data for Name: res_letterbox; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.res_letterbox (res_id, subject, type_id, format, typist, creation_date, modification_date, doc_date, docserver_id, path, filename, fingerprint, filesize, status, destination, work_batch, origin, priority, policy_id, cycle_id, initiator, dest_user, locker_user_id, locker_time, confidentiality, fulltext_result, external_id, external_state, departure_date, opinion_limit_date, barcode, category_id, alt_identifier, admission_date, process_limit_date, closing_date, alarm1_date, alarm2_date, flag_alarm1, flag_alarm2, model_id, version, integrations, custom_fields, linked_resources, retention_frozen, binding) FROM stdin;
108	Test 500	101	pdf	15	2026-08-09 02:36:16.090697	2026-08-09 02:42:33.035682	2026-08-09 00:00:00	FASTHD_MAN	2026/08/0001/	0006_76732128.pdf	3bdc2d1eb909c86432f6e6bb3b5d2d00c71e642bba0978388b5abd48b427b7a5bfac3157d86144a59e7ec824885dc863086ee3a25354136e58aacb70abb5e244	141226	ATT_MP	PE	\N	\N	poiuytre1357nbvc	\N	\N	\N	15	\N	\N	N	SUCCESS	{}	{}	\N	\N	\N	incoming	MAARCH/2026A/4	2026-08-09 00:00:00	2026-09-18 23:59:59	\N	\N	\N	N	N	1	1	{"inShipping": false, "inSignatureBook": false}	\N	[]	f	\N
107	Test NGSign 10	101	pdf	15	2026-08-09 01:42:51.924412	2026-08-09 01:42:51.990103	2026-08-09 00:00:00	FASTHD_MAN	2026/08/0001/	0005_1271643814.pdf	3bdc2d1eb909c86432f6e6bb3b5d2d00c71e642bba0978388b5abd48b427b7a5bfac3157d86144a59e7ec824885dc863086ee3a25354136e58aacb70abb5e244	141226	NEW	PE	\N	\N	poiuytre1357nbvc	\N	\N	\N	15	\N	\N	N	SUCCESS	{}	{}	\N	\N	\N	incoming	MAARCH/2026A/3	2026-08-09 00:00:00	2026-09-18 23:59:59	\N	\N	\N	N	N	1	1	{"inShipping": false, "inSignatureBook": false}	\N	[]	f	\N
110	Test Signature 200	101	pdf	15	2026-08-09 14:01:40.836484	2026-08-09 14:16:58.127399	2026-08-06 00:00:00	FASTHD_MAN	2026/08/0001/	0008_97479380.pdf	3bdc2d1eb909c86432f6e6bb3b5d2d00c71e642bba0978388b5abd48b427b7a5bfac3157d86144a59e7ec824885dc863086ee3a25354136e58aacb70abb5e244	141226	EENV	PE	\N	\N	poiuytre1357nbvc	\N	\N	\N	15	15	2026-08-09 18:59:02.23734	N	SUCCESS	{}	{}	\N	\N	\N	incoming	MAARCH/2026A/6	2026-08-09 00:00:00	2026-09-18 23:59:59	\N	\N	\N	N	N	1	1	{"inShipping": false, "inSignatureBook": false}	\N	[]	f	\N
106	Test NGSign 2	101	pdf	9	2026-08-09 00:35:39.694186	2026-08-09 02:24:08.078916	2026-08-09 00:00:00	FASTHD_MAN	2026/08/0001/	0004_1091947460.pdf	3bdc2d1eb909c86432f6e6bb3b5d2d00c71e642bba0978388b5abd48b427b7a5bfac3157d86144a59e7ec824885dc863086ee3a25354136e58aacb70abb5e244	141226	COU	VILLE	\N	\N	poiuytre1357nbvc	\N	\N	\N	15	\N	\N	N	SUCCESS	{}	{}	\N	\N	\N	incoming	MAARCH/2026A/2	2026-08-09 00:00:00	2026-09-18 23:59:59	\N	\N	\N	N	N	1	1	{"inShipping": false, "inSignatureBook": true}	\N	[]	f	\N
109	Test Signature	101	pdf	15	2026-08-09 10:49:48.979797	2026-08-09 12:06:09.27537	2026-08-09 00:00:00	FASTHD_MAN	2026/08/0001/	0007_2078261132.pdf	3bdc2d1eb909c86432f6e6bb3b5d2d00c71e642bba0978388b5abd48b427b7a5bfac3157d86144a59e7ec824885dc863086ee3a25354136e58aacb70abb5e244	141226	EENV	PE	\N	\N	poiuytre1357nbvc	\N	\N	\N	15	\N	\N	N	SUCCESS	{}	{}	\N	\N	\N	incoming	MAARCH/2026A/5	2026-08-09 00:00:00	2026-09-18 23:59:59	\N	\N	\N	N	N	1	1	{"inShipping": false, "inSignatureBook": false}	\N	[]	f	\N
\.


--
-- Data for Name: res_mark_as_read; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.res_mark_as_read (res_id, user_id, basket_id) FROM stdin;
\.


--
-- Data for Name: resource_contacts; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.resource_contacts (id, res_id, item_id, type, mode) FROM stdin;
1	106	12	contact	sender
2	107	12	contact	sender
3	108	12	contact	sender
4	109	12	contact	sender
5	110	12	contact	sender
\.


--
-- Data for Name: resources_folders; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.resources_folders (id, folder_id, res_id) FROM stdin;
\.


--
-- Data for Name: resources_tags; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.resources_tags (id, res_id, tag_id) FROM stdin;
\.


--
-- Data for Name: search_templates; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.search_templates (id, user_id, label, creation_date, query) FROM stdin;
1	23	Tous les courriers	2021-03-25 11:54:30.273871	[{"identifier":"category","values":""},{"identifier":"meta"}]
2	18	Courriers arrivés	2021-03-25 11:59:29.500487	[{"identifier":"category","values":[{"id":"incoming","label":"Courrier Arriv\\u00e9e"}]},{"identifier":"meta"}]
\.


--
-- Data for Name: security; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.security (security_id, group_id, coll_id, where_clause, maarch_comment) FROM stdin;
600	COURRIER	letterbox_coll	1=1	Tous les courriers
601	AGENT	letterbox_coll	destination in (@my_entities, @subentities[@my_primary_entity])	Les courriers de mes services et sous-services
602	RESP_COURRIER	letterbox_coll	1=1	Tous les courriers
603	RESPONSABLE	letterbox_coll	destination in (@my_entities, @subentities[@my_primary_entity])	Les courriers de mes services et sous-services
604	ADMINISTRATEUR_N1	letterbox_coll	1=1	Tous les courriers
605	ADMINISTRATEUR_N2	letterbox_coll	1=0	Aucun courrier
606	DIRECTEUR	letterbox_coll	1=0	Aucun courrier
607	ELU	letterbox_coll	1=0	Aucun courrier
608	CABINET	letterbox_coll	1=0	Aucun courrier
609	ARCHIVISTE	letterbox_coll	1=1	Tous les courriers
610	MAARCHTOGEC	letterbox_coll	1=0	Aucun courrier
611	SERVICE	letterbox_coll	1=0	Aucun courrier
612	WEBSERVICE	letterbox_coll	1=0	Tous les courriers
\.


--
-- Data for Name: shipping_templates; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.shipping_templates (id, label, description, options, fee, entities, account, subscriptions, token_min_iat) FROM stdin;
1	Modèle d'exemple d'envoi postal	Modèle d'exemple d'envoi postal	{"shapingOptions":[],"sendMode":"fast"}	{"firstPagePrice":0.4,"nextPagePrice":0.5,"postagePrice":0.9}	["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "17", "18", "16", "19", "20"]	{"id": "sandbox.562", "password": "VPh5AY6i::82f88fe97cead428e0885084f93a684c"}	[]	2026-08-03 23:15:30.874406
\.


--
-- Data for Name: shippings; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.shippings (id, user_id, document_id, document_type, options, fee, recipient_entity_id, recipients, account_id, creation_date, history, attachments, sending_id, action_id) FROM stdin;
\.


--
-- Data for Name: status; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.status (identifier, id, label_status, is_system, img_filename, maarch_module, can_be_searched, can_be_modified) FROM stdin;
1	ATT	En attente	Y	fm-letter-status-attr	apps	Y	Y
2	COU	En cours	Y	fm-letter-status-inprogress	apps	Y	Y
3	DEL	Supprimé	Y	fm-letter-del	apps	N	Y
4	END	Clos / fin du workflow	Y	fm-letter-status-end	apps	Y	Y
5	NEW	Nouveau courrier pour le service	Y	fm-letter-status-new	apps	Y	Y
6	RET	Retour courrier ou document en qualification	N	fm-letter-status-rejected	apps	Y	Y
7	VAL	Courrier signalé	Y	fm-letter-status-aval	apps	Y	Y
8	INIT	Nouveau courrier ou document non qualifié	Y	fm-letter-status-attr	apps	Y	Y
9	VALSG	Nouveau courrier ou document en validation SG	Y	fm-letter-status-attr	apps	Y	Y
10	ATT_MP	En attente tablette (MP)	Y	fm-letter-status-wait	apps	Y	Y
11	EAVIS	Avis demandé	N	fa-lightbulb	apps	Y	Y
12	EENV	A e-envoyer	N	fm-letter-status-aenv	apps	Y	Y
13	ESIG	A e-signer	N	fm-file-fingerprint	apps	Y	Y
14	EVIS	A e-viser	N	fm-letter-status-aval	apps	Y	Y
15	ESIGAR	AR à e-signer	N	fm-file-fingerprint	apps	Y	Y
16	EENVAR	AR à e-envoyer	N	fm-letter-status-aenv	apps	Y	Y
17	SVX	En attente  de traitement SVE	N	fm-letter-status-wait	apps	Y	Y
18	SSUITE	Sans suite	Y	fm-letter-del	apps	Y	Y
19	A_TRA	PJ à traiter	Y	fa-question	apps	Y	Y
20	FRZ	PJ gelée	Y	fa-pause	apps	Y	Y
21	TRA	PJ traitée	Y	fa-check	apps	Y	Y
22	OBS	PJ obsolète	Y	fa-pause	apps	Y	Y
23	TMP	PJ brouillon	Y	fm-letter-status-inprogress	apps	N	N
24	EXP_SEDA	A archiver	Y	fm-letter-status-acla	apps	Y	Y
25	SEND_SEDA	Courrier envoyé au système d'archivage	Y	fm-letter-status-inprogress	apps	Y	Y
26	ACK_SEDA	Accusé de réception reçu	Y	fm-letter-status-acla	apps	Y	Y
27	REPLY_SEDA	Courrier archivé	Y	fm-letter-status-acla	apps	Y	Y
28	GRC	Envoyé en GRC	N	fm-letter-status-inprogress	apps	Y	Y
29	GRC_TRT	En traitement GRC	N	fm-letter-status-inprogress	apps	Y	Y
30	GRC_ALERT	Retourné par la GRC	N	fm-letter-status-inprogress	apps	Y	Y
31	RETRN	Retourné	Y	fm-letter-outgoing	apps	N	N
32	NO_RETRN	Pas de retour	Y	fm-letter-status-rejected	apps	N	N
33	PJQUAL	PJ à réconcilier	Y	fm-letter-status-attr	apps	Y	Y
34	NUMQUAL	Plis à qualifier	Y	fm-letter-status-attr	apps	Y	Y
35	SEND_MASS	Pour publipostage	Y	fa-mail-bulk	apps	Y	Y
36	SIGN	PJ signée	Y	fa-check	apps	Y	Y
37	STDBY	Clôturé avec suivi	Y	fm-letter-status-wait	apps	Y	Y
38	ENVDONE	Courrier envoyé	Y	fm-letter-status-aenv	apps	Y	Y
39	REJ_SIGN	Signature refusée sur la tablette (MP)	Y	fm-letter-status-rejected	apps	Y	Y
40	PND	AR Non distribué	Y	fm-letter-status-rejected	apps	Y	Y
41	DSTRIBUTED	AR distribué	Y	fa-check	apps	Y	Y
42	OUT	Courriels importés à qualifier	N	fm-letter-incoming	apps	Y	Y
\.


--
-- Data for Name: status_images; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.status_images (id, image_name) FROM stdin;
1	fm-letter-status-new
2	fm-letter-status-inprogress
3	fm-letter-status-info
4	fm-letter-status-wait
5	fm-letter-status-validated
6	fm-letter-status-rejected
7	fm-letter-status-end
8	fm-letter-status-newmail
9	fm-letter-status-attr
10	fm-letter-status-arev
11	fm-letter-status-aval
12	fm-letter-status-aimp
13	fm-letter-status-imp
14	fm-letter-status-aenv
15	fm-letter-status-acla
16	fm-letter-status-aarch
17	fm-letter
18	fm-letter-add
19	fm-letter-search
20	fm-letter-del
21	fm-letter-incoming
22	fm-letter-outgoing
23	fm-letter-internal
24	fm-file-fingerprint
25	fm-classification-plan-l1
26	fa-question
27	fa-check
28	fa-pause
29	fa-mail-bulk
30	fa-lightbulb
\.


--
-- Data for Name: tags; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tags (id, label, description, parent_id, creation_date, links, usage) FROM stdin;
1	SEMINAIRE	\N	\N	2021-03-24 10:17:02.66594	[]	\N
2	INNOVATION	\N	\N	2021-03-24 10:17:02.66594	[]	\N
3	MAARCH	\N	\N	2021-03-24 10:17:02.66594	[]	\N
4	ENVIRONNEMENT	\N	\N	2021-03-24 10:17:02.66594	[]	\N
5	PARTENARIAT	\N	\N	2021-03-24 10:17:02.66594	[]	\N
6	JUMELAGE	\N	\N	2021-03-24 10:17:02.66594	[]	\N
7	ECONOMIE	\N	\N	2021-03-24 10:17:02.66594	[]	\N
8	ASSOCIATIONS	\N	\N	2021-03-24 10:17:02.66594	[]	\N
9	RH	\N	\N	2021-03-24 10:17:02.66594	[]	\N
10	BUDGET	\N	\N	2021-03-24 10:17:02.66594	[]	\N
11	QUARTIERS	\N	\N	2021-03-24 10:17:02.66594	[]	\N
12	LITTORAL	\N	\N	2021-03-24 10:17:02.66594	[]	\N
13	SPORT	\N	\N	2021-03-24 10:17:02.66594	[]	\N
\.


--
-- Data for Name: templates; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.templates (template_id, template_label, template_comment, template_content, template_type, template_path, template_file_name, template_style, template_datasource, template_target, template_attachment_type, subject, options) FROM stdin;
2	[notification] Notifications événement	Notifications des événements système	<p><font face="verdana,geneva" size="1">Bonjour [recipient.firstname] [recipient.lastname],</font></p>\n<p><font face="verdana,geneva" size="1"> </font></p>\n<p><font face="verdana,geneva" size="1">Voici la liste des &eacute;v&eacute;nements de l'application qui vous sont notifi&eacute;s ([notification.description]) :</font></p>\n<table style="width: 800px; height: 36px;" border="0" cellspacing="1" cellpadding="1">\n<tbody>\n<tr>\n<td style="width: 150px; background-color: #0099ff;"><font face="verdana,geneva" size="1"><strong><font color="#FFFFFF">Date</font></strong></font></td>\n<td style="width: 150px; background-color: #0099ff;"><font face="verdana,geneva" size="1"><strong><font color="#FFFFFF">Utilisateur </font></strong></font><font face="verdana,geneva" size="1"><strong></strong></font></td>\n<td style="width: 500px; background-color: #0099ff;"><font face="verdana,geneva" size="1"><strong><font color="#FFFFFF">Description</font></strong></font></td>\n</tr>\n<tr>\n<td><font face="verdana,geneva" size="1">[events.event_date;block=tr;frm=dd/mm/yyyy hh:nn:ss]</font></td>\n<td><font face="verdana,geneva" size="1">[events.user_id]</font></td>\n<td><font face="verdana,geneva" size="1">[events.event_info]</font></td>\n</tr>\n</tbody>\n</table>	HTML	\N	\N		notif_events	notifications	\N	\N	{}
5	[notification courrier] Alerte 2	[notification] Alerte 2	<p><font face="arial,helvetica,sans-serif" size="2">Bonjour [recipient.firstname] [recipient.lastname],</font></p>\n<p> </p>\n<p><font face="arial,helvetica,sans-serif" size="2">Voici la liste des courriers dont la date limite de traitement est dépassée :n</font></p>\n<table style="border: 1pt solid #000000; width: 1582px; height: 77px;" border="1" cellspacing="1" cellpadding="5" frame="box">\n<tbody>\n<tr>\n<td><font face="arial,helvetica,sans-serif"><strong><font size="2">Référence</font></strong></font></td>\n<td><font face="arial,helvetica,sans-serif"><strong><font size="2">Origine</font></strong></font></td>\n<td><font face="arial,helvetica,sans-serif"><strong><font size="2">Emetteur</font></strong></font></td>\n<td><font face="arial,helvetica,sans-serif" size="2" color="#000000"><strong>Date</strong></font></td>\n<td><font face="arial,helvetica,sans-serif" size="2" color="#000000"><strong>Objet</strong></font></td>\n<td><font face="arial,helvetica,sans-serif" size="2" color="#000000"><strong>Type</strong></font></td>\n<td><font face="arial,helvetica,sans-serif" size="2" color="#FFFFFF"><strong>Liens</strong></font></td>\n</tr>\n<tr>\n<td><font face="arial,helvetica,sans-serif" size="2">[res_letterbox.res_id]</font></td>\n<td><font face="arial,helvetica,sans-serif" size="2">[res_letterbox.typist_label]</font></td>\n<td>\n<p><font face="arial,helvetica,sans-serif" size="2">[sender.company;block=tr] [sender.firstname] [sender.lastname] [sender.function] [sender.address_number] [sender.address_street] [sender.address_postcode] [sender.address_town]</font></p>\n</td>\n<td><font face="arial,helvetica,sans-serif" size="2">[res_letterbox.doc_date;block=tr;frm=dd/mm/yyyy]</font></td>\n<td><font face="arial,helvetica,sans-serif" color="#FF0000"><strong><font size="2">[res_letterbox.subject]</font></strong></font></td>\n<td><font face="arial,helvetica,sans-serif" size="2">[res_letterbox.type_label]</font></td>\n<td><font face="arial,helvetica,sans-serif"><a href="[res_letterbox.linktoprocess]" name="traiter">traiter</a> <a href="[res_letterbox.linktodoc]" name="doc">Afficher</a></font></td>\n</tr>\n</tbody>\n</table>	HTML	\N	\N	ODP: open_office_presentation	letterbox_events	notifications	\N	\N	{}
6	[notification courrier] Alerte 1	[notification] Alerte 1	<p><font face="arial,helvetica,sans-serif" size="2">Bonjour [recipient.firstname] [recipient.lastname],</font></p>\n<p> </p>\n<p><font face="arial,helvetica,sans-serif" size="2"> </font></p>\n<p> </p>\n<p><font face="arial,helvetica,sans-serif" size="2">Voici la liste des courriers toujours en attente de traitement :</font></p>\n<p> </p>\n<table style="border: 1pt solid #000000; width: 1582px; height: 77px;" border="1" cellspacing="1" cellpadding="5" frame="box">\n<tbody>\n<tr>\n<td><font face="arial,helvetica,sans-serif"><strong><font size="2">Référence</font></strong></font></td>\n<td><font face="arial,helvetica,sans-serif"><strong><font size="2">Origine</font></strong></font></td>\n<td><font face="arial,helvetica,sans-serif"><strong><font size="2">Emetteur</font></strong></font></td>\n<td><font face="arial,helvetica,sans-serif" size="2" color="#000000"><strong>Date</strong></font></td>\n<td><font face="arial,helvetica,sans-serif" size="2" color="#000000"><strong>Objet</strong></font></td>\n<td><font face="arial,helvetica,sans-serif" size="2" color="#000000"><strong>Type</strong></font></td>\n<td><font face="arial,helvetica,sans-serif" size="2" color="#FFFFFF"><strong>Liens</strong></font></td>\n</tr>\n<tr>\n<td><font face="arial,helvetica,sans-serif" size="2">[res_letterbox.res_id]</font></td>\n<td><font face="arial,helvetica,sans-serif" size="2">[res_letterbox.typist_label]</font></td>\n<td>\n<p><font face="arial,helvetica,sans-serif" size="2">[sender.company;block=tr] [sender.firstname] [sender.lastname] [sender.function] [sender.address_number] [sender.address_street] [sender.address_postcode] [sender.address_town]</font></p>\n</td>\n<td><font face="arial,helvetica,sans-serif" size="2">[res_letterbox.doc_date;block=tr;frm=dd/mm/yyyy]</font></td>\n<td><font face="arial,helvetica,sans-serif" color="#FF0000"><strong><font size="2">[res_letterbox.subject]</font></strong></font></td>\n<td><font face="arial,helvetica,sans-serif" size="2">[res_letterbox.type_label]</font></td>\n<td><font face="arial,helvetica,sans-serif"><a href="[res_letterbox.linktoprocess]" name="traiter">traiter</a> <a href="[res_letterbox.linktodoc]" name="doc">Afficher</a></font></td>\n</tr>\n</tbody>\n</table>	HTML	\N	\N	ODP: open_office_presentation	letterbox_events	notifications	\N	\N	{}
7	[notification courrier] Diffusion de courrier	Alerte de courriers présents dans les bannettes	<p style="font-family: Trebuchet MS, Arial, Helvetica, sans-serif;">Bonjour <strong>[recipient.firstname] [recipient.lastname]</strong>,</p>\n<p>&nbsp;</p>\n<p style="font-family: Trebuchet MS, Arial, Helvetica, sans-serif;">Voici la liste des nouveaux courriers pr&eacute;sents dans cette bannette :</p>\n<table style="font-family: Trebuchet MS, Arial, Helvetica, sans-serif; border-collapse: collapse; width: 100%;">\n<tbody>\n<tr>\n<th style="border: 1px solid #ddd; padding: 8px; padding-top: 12px; padding-bottom: 12px; text-align: left; background-color: #135f7f; color: white;">R&eacute;f&eacute;rence</th>\n<th style="border: 1px solid #ddd; padding: 8px; padding-top: 12px; padding-bottom: 12px; text-align: left; background-color: #135f7f; color: white;">Origine</th>\n<th style="border: 1px solid #ddd; padding: 8px; padding-top: 12px; padding-bottom: 12px; text-align: left; background-color: #135f7f; color: white;">Emetteur</th>\n<th style="border: 1px solid #ddd; padding: 8px; padding-top: 12px; padding-bottom: 12px; text-align: left; background-color: #135f7f; color: white;">Date</th>\n<th style="border: 1px solid #ddd; padding: 8px; padding-top: 12px; padding-bottom: 12px; text-align: left; background-color: #135f7f; color: white;">Objet</th>\n<th style="border: 1px solid #ddd; padding: 8px; padding-top: 12px; padding-bottom: 12px; text-align: left; background-color: #135f7f; color: white;">Type</th>\n<th style="border: 1px solid #ddd; padding: 8px; padding-top: 12px; padding-bottom: 12px; text-align: left; background-color: #135f7f; color: white;">&nbsp;</th>\n</tr>\n<tr>\n<td style="border: 1px solid #ddd; padding: 8px;">[res_letterbox.res_id]</td>\n<td style="border: 1px solid #ddd; padding: 8px;">[res_letterbox.typist_label]</td>\n<td style="border: 1px solid #ddd; padding: 8px;">[sender.company;block=tr] [sender.firstname] [sender.lastname][sender.function][sender.address_number][sender.address_street][sender.address_postcode][sender.address_town]</td>\n<td style="border: 1px solid #ddd; padding: 8px;">[res_letterbox.doc_date;block=tr;frm=dd/mm/yyyy]</td>\n<td style="border: 1px solid #ddd; padding: 8px;">[res_letterbox.subject]</td>\n<td style="border: 1px solid #ddd; padding: 8px;">[res_letterbox.type_label]</td>\n<td style="border: 1px solid #ddd; padding: 8px; text-align: right;"><a style="text-decoration: none; background: #135f7f; padding: 5px; color: white; -webkit-box-shadow: 6px 4px 5px 0px rgba(0,0,0,0.75); -moz-box-shadow: 6px 4px 5px 0px rgba(0,0,0,0.75); box-shadow: 6px 4px 5px 0px rgba(0,0,0,0.75);" href="[res_letterbox.linktodetail]" name="detail">D&eacute;tail</a> <a style="text-decoration: none; background: #135f7f; padding: 5px; color: white; -webkit-box-shadow: 6px 4px 5px 0px rgba(0,0,0,0.75); -moz-box-shadow: 6px 4px 5px 0px rgba(0,0,0,0.75); box-shadow: 6px 4px 5px 0px rgba(0,0,0,0.75);" href="[res_letterbox.linktodoc]" name="doc">Afficher</a></td>\n</tr>\n</tbody>\n</table>\n<p>&nbsp;</p>\n<p style="font-family: Trebuchet MS, Arial, Helvetica, sans-serif; width: 100%; text-align: center; font-size: 9px; font-style: italic; opacity: 0.5;">Message g&eacute;n&eacute;r&eacute; via l'application MaarchCourrier</p>	HTML	\N	\N	ODP: open_office_presentation	letterbox_events	notifications	\N	\N	{}
8	[notification courrier] Nouvelle annotation	[notification] Nouvelle annotation	<p style="font-family: Trebuchet MS, Arial, Helvetica, sans-serif;">Bonjour <strong>[recipient.firstname] [recipient.lastname]</strong>,</p>\n<p>&nbsp;</p>\n<p style="font-family: Trebuchet MS, Arial, Helvetica, sans-serif;">Voici les nouvelles annotations sur les courriers suivants :</p>\n<table style="font-family: Trebuchet MS, Arial, Helvetica, sans-serif; border-collapse: collapse; width: 100%;">\n<tbody>\n<tr>\n<th style="border: 1px solid #ddd; padding: 8px; padding-top: 12px; padding-bottom: 12px; text-align: left; background-color: #135f7f; color: white;">R&eacute;f&eacute;rence</th>\n<th style="border: 1px solid #ddd; padding: 8px; padding-top: 12px; padding-bottom: 12px; text-align: left; background-color: #135f7f; color: white;">Num</th>\n<th style="border: 1px solid #ddd; padding: 8px; padding-top: 12px; padding-bottom: 12px; text-align: left; background-color: #135f7f; color: white;">Date</th>\n<th style="border: 1px solid #ddd; padding: 8px; padding-top: 12px; padding-bottom: 12px; text-align: left; background-color: #135f7f; color: white;">Objet</th>\n<th style="border: 1px solid #ddd; padding: 8px; padding-top: 12px; padding-bottom: 12px; text-align: left; background-color: #135f7f; color: white;">Note</th>\n<th style="border: 1px solid #ddd; padding: 8px; padding-top: 12px; padding-bottom: 12px; text-align: left; background-color: #135f7f; color: white;">Contact</th>\n<th style="border: 1px solid #ddd; padding: 8px; padding-top: 12px; padding-bottom: 12px; text-align: left; background-color: #135f7f; color: white;">&nbsp;</th>\n</tr>\n<tr>\n<td style="border: 1px solid #ddd; padding: 8px;">[res_letterbox.res_id]</td>\n<td style="border: 1px solid #ddd; padding: 8px;">[res_letterbox.# ;frm=0000]</td>\n<td style="border: 1px solid #ddd; padding: 8px;">[res_letterbox.doc_date;block=tr;frm=dd/mm/yyyy]</td>\n<td style="border: 1px solid #ddd; padding: 8px;">[res_letterbox.subject]</td>\n<td style="border: 1px solid #ddd; padding: 8px;">[notes.content;block=tr]</td>\n<td style="border: 1px solid #ddd; padding: 8px;">[sender.company;block=tr] [sender.firstname] [sender.lastname]</td>\n<td style="border: 1px solid #ddd; padding: 8px; text-align: right;"><a style="text-decoration: none; background: #135f7f; padding: 5px; color: white; -webkit-box-shadow: 6px 4px 5px 0px rgba(0,0,0,0.75); -moz-box-shadow: 6px 4px 5px 0px rgba(0,0,0,0.75); box-shadow: 6px 4px 5px 0px rgba(0,0,0,0.75);" href="[res_letterbox.linktodetail]" name="detail">D&eacute;tail</a> <a style="text-decoration: none; background: #135f7f; padding: 5px; color: white; -webkit-box-shadow: 6px 4px 5px 0px rgba(0,0,0,0.75); -moz-box-shadow: 6px 4px 5px 0px rgba(0,0,0,0.75); box-shadow: 6px 4px 5px 0px rgba(0,0,0,0.75);" href="[res_letterbox.linktodoc]" name="doc">Afficher</a></td>\n</tr>\n</tbody>\n</table>\n<p>&nbsp;</p>\n<p style="font-family: Trebuchet MS, Arial, Helvetica, sans-serif; width: 100%; text-align: center; font-size: 9px; font-style: italic; opacity: 0.5;">Message g&eacute;n&eacute;r&eacute; via l'application MaarchCourrier</p>	HTML	\N	\N	ODP: open_office_presentation	notes	notifications	\N	\N	{}
900	[TRT] Passer me voir	Passer me voir	Passer me voir à mon bureau, merci.	TXT	\N	\N	XLSX: demo_spreadsheet_msoffice		notes	all	\N	{}
901	[TRT] Compléter	Compléter	Le projet de réponse doit être complété/révisé sur les points suivants :\n\n- 	TXT	\N	\N	XLSX: demo_spreadsheet_msoffice		notes	all	\N	{}
902	[AVIS] Demande avis	Demande avis	Merci de me fournir les éléments de langage pour répondre à ce courrier.	TXT	\N	\N	XLSX: demo_spreadsheet_msoffice		notes	all	\N	{}
904	[AVIS] Avis favorable	Avis favorable	Merci de répondre favorablement à la demande inscrite dans ce courrier	TXT	\N	\N	XLSX: demo_spreadsheet_msoffice		notes	all	\N	{}
905	[CLOTURE] Clôture pour REJET	Clôture pour REJET	Clôture pour REJET	TXT	\N	\N	XLSX: demo_spreadsheet_msoffice		notes	all	\N	{}
906	[CLOTURE] Clôture pour ABANDON	Clôture pour ABANDON	Clôture pour ABANDON	TXT	\N	\N	XLSX: demo_spreadsheet_msoffice		notes	all	\N	{}
907	[CLOTURE] Clôture RAS	Clôture RAS	Clôture NORMALE	TXT	\N	\N	XLSX: demo_spreadsheet_msoffice		notes	all	\N	{}
908	[CLOTURE] Clôture AUTRE	Clôture AUTRE	Clôture pour ce motif : 	TXT	\N	\N	XLSX: demo_spreadsheet_msoffice		notes	all	\N	{}
909	[REJET] Erreur affectation	Erreur affectation	Ce courrier ne semble pas concerner mon service	TXT	\N	\N	XLSX: demo_spreadsheet_msoffice		notes	all	\N	{}
910	[REJET] Anomalie de numérisation	Anomalie de numérisation	Le courrier présente des anomalies de numérisation	TXT	\N	\N	XLSX: demo_spreadsheet_msoffice		notes	all	\N	{}
1033	AR EN MASSE TYPE SIMPLE	Cas d’une demande n’impliquant pas de décision implicite de l’administration	<div id="write" class="is-node"><br /><hr /><span style="color: #236fa1;">H&ocirc;tel de ville</span><br /><span style="color: #236fa1;">Place de la Libert&eacute;</span><br /><span style="color: #236fa1;">99000 Maarch-les-bains</span>\n<p>&nbsp;</p>\n<p><span style="color: #236fa1;"><strong>Accus&eacute; de r&eacute;ception</strong></span></p>\n<p>Service instructeur : <strong>[userPrimaryEntity.entity_label]</strong> <br />Courriel : [userPrimaryEntity.email]</p>\n<p>[userPrimaryEntity.address_town], le [datetime.date;frm=dddd dd mmmm yyyy (locale)]</p>\n<hr />\n<p>Bonjour,</p>\n<p>Votre demande concernant :</p>\n<p><strong>[res_letterbox.subject]</strong></p>\n<p>&agrave; bien &eacute;t&eacute; r&eacute;ceptionn&eacute;e par nos services le [res_letterbox.admission_date].</p>\n<p><br />La r&eacute;f&eacute;rence de votre dossier est : <strong>[res_letterbox.alt_identifier]</strong></p>\n<p>Le pr&eacute;sent accus&eacute; de r&eacute;ception atteste de la r&eacute;ception de votre demande. Il ne pr&eacute;juge pas de la conformit&eacute; de son contenu qui d&eacute;pend entre autres de l'&eacute;tude des pi&egrave;ces fournies.</p>\n<p>Si l'instruction de votre demande n&eacute;cessite des informations ou des pi&egrave;ces compl&eacute;mentaires, nos services vous en ferons la demande</p>\n<p>&nbsp;</p>\n<p>Nous vous conseillons de conserver ce message jusqu'&agrave; la fin du traitement de votre dossier.</p>\n<p>&nbsp;</p>\n<p>[userPrimaryEntity.entity_label]</p>\n<p>Ville de Maarch-les-Bains</p>\n<p>&nbsp;</p>\n</div>	OFFICE_HTML	2021/03/0001/	0011_1443263267.docx		letterbox_attachment	acknowledgementReceipt	simple	\N	{"acknowledgementReceiptFrom": "destination"}
1034	AR EN MASSE TYPE SVA	Cas d’une demande impliquant une décision implicite d'acceptation de l’administration	<div id="write" class="is-node"><br /><hr /><span style="color: #236fa1;">H&ocirc;tel de ville</span><br /><span style="color: #236fa1;">Place de la Libert&eacute;</span><br /><span style="color: #236fa1;">99000 Maarch-les-bains</span>\n<p>&nbsp;</p>\n<p><span style="color: #236fa1;"><strong>Accus&eacute; de r&eacute;ception de votre demande intervenant<br />dans le cadre d'une d&eacute;cision implicite d'acceptation<br /></strong></span></p>\n<p>Num&eacute;ro d'enregistrement :<strong> [res_letterbox.alt_identifier]</strong></p>\n<p>Service instructeur : <strong>[userPrimaryEntity.entity_label]</strong> <br />Courriel : [userPrimaryEntity.email]</p>\n<p>[userPrimaryEntity.address_town], le [datetime.date;frm=dddd dd mmmm yyyy (locale)]</p>\n<hr />\n<p>Bonjour,</p>\n<p>Votre demande concernant :</p>\n<p><strong>[res_letterbox.subject]</strong></p>\n<p>&agrave; bien &eacute;t&eacute; r&eacute;ceptionn&eacute;e par nos services le [res_letterbox.admission_date].</p>\n<p><br />La r&eacute;f&eacute;rence de votre dossier est : <strong>[res_letterbox.alt_identifier]</strong></p>\nLe pr&eacute;sent accus&eacute; de r&eacute;ception atteste de la r&eacute;ception de votre demande. il ne pr&eacute;juge pas de la conformit&eacute; de son contenu qui d&eacute;pend entre autres de l''&eacute;tude des pi&egrave;ces fournies.<br /><br />Votre demande est susceptible de faire l'objet d''une d&eacute;cision implicite d''acceptation en l'absence de r&eacute;ponse dans les jours suivant sa r&eacute;ception, soit le <strong>[res_letterbox.process_limit_date]</strong>.<br /><br />Si l'instruction de votre demande n&eacute;cessite des informations ou pi&egrave;ces compl&eacute;mentaires, la Ville vous contactera afin de les fournir, dans un d&eacute;lai de production qui sera fix&eacute;.<br /><br />Le cas &eacute;ch&eacute;ant, le d&eacute;lai de d&eacute;cision implicite d'acceptation ne d&eacute;butera qu''apr&egrave;s la production des pi&egrave;ces demand&eacute;es.<br /><br />En cas de d&eacute;cision implicite d''acceptation vous avez la possibilit&eacute; de demander au service charg&eacute; du dossier une attestation conform&eacute;ment aux dispositions de l'article 22 de la loi n&deg; 2000-321 du 12 avril 2000 relative aux droits des citoyens dans leurs relations avec les administrations modifi&eacute;e.\n<p>Nous vous conseillons de conserver ce message jusqu'&agrave; la fin du traitement de votre dossier.</p>\n<p>&nbsp;</p>\n<p><span style="color: #236fa1;">Ville de Maarch-les-Bains</span><br />[userPrimaryEntity.entity_label]</p>\n<p>Courriel : [userPrimaryEntity.email]<br />T&eacute;l&eacute;phone : [user.phone]</p>\n</div>	OFFICE_HTML	\N	\N	DOCX: AR_Masse_SVA	letterbox_attachment	acknowledgementReceipt	sva	\N	{"acknowledgementReceiptFrom": "destination"}
1045	AR TYPE SVR - Courriel Manuel	A utiliser avec l'action "Générer les AR"	<div id="write" class="is-node"><br /><hr /><span style="color: #236fa1;">H&ocirc;tel de ville</span><br /><span style="color: #236fa1;">Place de la Libert&eacute;</span><br /><span style="color: #236fa1;">99000 Maarch-les-bains</span>\n<p>&nbsp;</p>\n<p><span style="color: #236fa1;"><strong>Accus&eacute; de r&eacute;ception de votre demande intervenant<br />dans le cadre d'une d&eacute;cision implicite de rejet<br /></strong></span></p>\n<p>Num&eacute;ro d'enregistrement :<strong> [res_letterbox.alt_identifier]</strong></p>\n<p>Service instructeur : <strong>[userPrimaryEntity.entity_label]</strong> <br />Courriel : [userPrimaryEntity.email]</p>\n<p>[userPrimaryEntity.address_town], le [datetime.date;frm=dddd dd mmmm yyyy (locale)]</p>\n<hr />\n<p>Bonjour,</p>\n<p>Votre demande concernant :</p>\n<p><strong>[res_letterbox.subject]</strong></p>\n<p>&agrave; bien &eacute;t&eacute; r&eacute;ceptionn&eacute;e par nos services le [res_letterbox.admission_date].</p>\n<p><br />La r&eacute;f&eacute;rence de votre dossier est : <strong>[res_letterbox.alt_identifier]</strong></p>\nLe pr&eacute;sent accus&eacute; de r&eacute;ception atteste de la r&eacute;ception de votre demande. il ne pr&eacute;juge pas de la conformit&eacute; de son contenu qui d&eacute;pend entre autres de l''&eacute;tude des pi&egrave;ces fournies.<br /><br />Votre demande est susceptible de faire l'objet d'une d&eacute;cision implicite de rejet en l'absence de r&eacute;ponse dans les jours suivant sa r&eacute;ception, soit le <strong>[res_letterbox.process_limit_date]</strong>.<br /><br />Si l'instruction de votre demande n&eacute;cessite des informations ou pi&egrave;ces compl&eacute;mentaires, la Ville vous contactera afin de les fournir, dans un d&eacute;lai de production qui sera fix&eacute;.<br /><br />Dans ce cas, le d&eacute;lai de d&eacute;cision implicite de rejet serait alors suspendu le temps de produire les pi&egrave;ces demand&eacute;es.<br /><br />Si vous estimez que la d&eacute;cision qui sera prise par l'administration est contestable, vous pourrez formuler :<br /><br />- Soit un recours gracieux devant l'auteur de la d&eacute;cision<br />- Soit un recours hi&eacute;rarchique devant le Maire<br />- Soit un recours contentieux devant le Tribunal Administratif territorialement comp&eacute;tent.<br /><br />Le recours gracieux ou le recours hi&eacute;rarchique peuvent &ecirc;tre faits sans condition de d&eacute;lais.<br /><br />Le recours contentieux doit intervenir dans un d&eacute;lai de deux mois &agrave; compter de la notification de la d&eacute;cision.<br /><br />Toutefois, si vous souhaitez en cas de rejet du recours gracieux ou du recours hi&eacute;rarchique former un recours contentieux, ce recours gracieux ou hi&eacute;rarchique devra avoir &eacute;t&eacute; introduit dans le d&eacute;lai sus-indiqu&eacute; du recours contentieux.<br /><br />Vous conserverez ainsi la possibilit&eacute; de former un recours contentieux, dans un d&eacute;lai de deux mois &agrave; compter de la d&eacute;cision intervenue sur ledit recours gracieux ou hi&eacute;rarchique.<br />\n<p>Nous vous conseillons de conserver ce message jusqu'&agrave; la fin du traitement de votre dossier.</p>\n<p>&nbsp;</p>\n<p><span style="color: #236fa1;">Ville de Maarch-les-Bains</span><br />[userPrimaryEntity.entity_label]</p>\n<p>Courriel : [userPrimaryEntity.email]<br />T&eacute;l&eacute;phone : [user.phone]</p>\n</div>	HTML	\N	\N	\N	letterbox_attachment	sendmail	all	\N	{}
1035	AR EN MASSE TYPE SVR	Cas d’une demande impliquant une décision implicite de rejet de l’administration	<div id="write" class="is-node"><br /><hr /><span style="color: #236fa1;">H&ocirc;tel de ville</span><br /><span style="color: #236fa1;">Place de la Libert&eacute;</span><br /><span style="color: #236fa1;">99000 Maarch-les-bains</span>\n<p>&nbsp;</p>\n<p><span style="color: #236fa1;"><strong>Accus&eacute; de r&eacute;ception de votre demande intervenant<br />dans le cadre d'une d&eacute;cision implicite de rejet<br /></strong></span></p>\n<p>Num&eacute;ro d'enregistrement :<strong> [res_letterbox.alt_identifier]</strong></p>\n<p>Service instructeur : <strong>[userPrimaryEntity.entity_label]</strong> <br />Courriel : [userPrimaryEntity.email]</p>\n<p>[userPrimaryEntity.address_town], le [datetime.date;frm=dddd dd mmmm yyyy (locale)]</p>\n<hr />\n<p>Bonjour,</p>\n<p>Votre demande concernant :</p>\n<p><strong>[res_letterbox.subject]</strong></p>\n<p>&agrave; bien &eacute;t&eacute; r&eacute;ceptionn&eacute;e par nos services le [res_letterbox.admission_date].</p>\n<p><br />La r&eacute;f&eacute;rence de votre dossier est : <strong>[res_letterbox.alt_identifier]</strong></p>\nLe pr&eacute;sent accus&eacute; de r&eacute;ception atteste de la r&eacute;ception de votre demande. il ne pr&eacute;juge pas de la conformit&eacute; de son contenu qui d&eacute;pend entre autres de l''&eacute;tude des pi&egrave;ces fournies.<br /><br />Votre demande est susceptible de faire l'objet d'une d&eacute;cision implicite de rejet en l'absence de r&eacute;ponse dans les jours suivant sa r&eacute;ception, soit le <strong>[res_letterbox.process_limit_date]</strong>.<br /><br />Si l'instruction de votre demande n&eacute;cessite des informations ou pi&egrave;ces compl&eacute;mentaires, la Ville vous contactera afin de les fournir, dans un d&eacute;lai de production qui sera fix&eacute;.<br /><br />Dans ce cas, le d&eacute;lai de d&eacute;cision implicite de rejet serait alors suspendu le temps de produire les pi&egrave;ces demand&eacute;es.<br /><br />Si vous estimez que la d&eacute;cision qui sera prise par l'administration est contestable, vous pourrez formuler :<br /><br />- Soit un recours gracieux devant l'auteur de la d&eacute;cision<br />- Soit un recours hi&eacute;rarchique devant le Maire<br />- Soit un recours contentieux devant le Tribunal Administratif territorialement comp&eacute;tent.<br /><br />Le recours gracieux ou le recours hi&eacute;rarchique peuvent &ecirc;tre faits sans condition de d&eacute;lais.<br /><br />Le recours contentieux doit intervenir dans un d&eacute;lai de deux mois &agrave; compter de la notification de la d&eacute;cision.<br /><br />Toutefois, si vous souhaitez en cas de rejet du recours gracieux ou du recours hi&eacute;rarchique former un recours contentieux, ce recours gracieux ou hi&eacute;rarchique devra avoir &eacute;t&eacute; introduit dans le d&eacute;lai sus-indiqu&eacute; du recours contentieux.<br /><br />Vous conserverez ainsi la possibilit&eacute; de former un recours contentieux, dans un d&eacute;lai de deux mois &agrave; compter de la d&eacute;cision intervenue sur ledit recours gracieux ou hi&eacute;rarchique.<br />\n<p>Nous vous conseillons de conserver ce message jusqu'&agrave; la fin du traitement de votre dossier.</p>\n<p>&nbsp;</p>\n<p><span style="color: #236fa1;">Ville de Maarch-les-Bains</span><br />[userPrimaryEntity.entity_label]</p>\n<p>Courriel : [userPrimaryEntity.email]<br />T&eacute;l&eacute;phone : [user.phone]</p>\n</div>	OFFICE_HTML	\N	\N	DOCX: AR_Masse_SVR	letterbox_attachment	acknowledgementReceipt	svr	\N	{"acknowledgementReceiptFrom": "destination"}
1036	SVE - Courriel de réorientation	Modèle de courriel de réorientation d'une saisine SVE	<div id="write" class="is-node"><br /><hr /><span style="color: #236fa1;">H&ocirc;tel de ville</span><br /><span style="color: #236fa1;">Place de la Libert&eacute;</span><br /><span style="color: #236fa1;">99000 Maarch-les-bains</span>\n<p>[destination.entity_label]<br /><br />T&eacute;l&eacute;phone : &nbsp;&nbsp; &nbsp;[user.phone]<br />Courriel : &nbsp;&nbsp;&nbsp; [destination.email]</p>\n<p>[destination.address_town], le [datetime.date;frm=dddd dd mmmm yyyy (locale)]</p>\n<hr />\n<p>Bonjour,</p>\nLe [res_letterbox.doc_date], vous avez transmis par voie &eacute;lectronique &agrave; la Ville une demande qui ne rel&egrave;ve pas de sa comp&eacute;tence.<br /><br />Votre demande cit&eacute;e en objet de ce courriel a &eacute;t&eacute; transmise &agrave;</div>\n<div class="is-node">&nbsp;</div>\n<div class="is-node">(veuillez renseigner le nom de l'AUTORITE COMPETENTE).<br />\n<p><br /><br /></p>\n<p>&nbsp;</p>\n<p>&nbsp;</p>\n</div>	HTML	\N	\N	DOCX: AR_Masse_SVA	letterbox_attachment	sendmail	all	\N	{}
1043	AR TYPE SIMPLE- Courriel Manuel	A utiliser avec l'action "Générer les AR"	<div id="write" class="is-node"><br /><hr /><span style="color: #236fa1;">H&ocirc;tel de ville</span><br /><span style="color: #236fa1;">Place de la Libert&eacute;</span><br /><span style="color: #236fa1;">99000 Maarch-les-bains</span>\n<p>&nbsp;</p>\n<p><span style="color: #236fa1;"><strong>Accus&eacute; de r&eacute;ception</strong></span></p>\n<p>Service instructeur : <strong>[userPrimaryEntity.entity_label]</strong> <br />Courriel : [userPrimaryEntity.email]</p>\n<p>[userPrimaryEntity.address_town], le [datetime.date;frm=dddd dd mmmm yyyy (locale)]</p>\n<hr />\n<p>Bonjour,</p>\n<p>Votre demande concernant :</p>\n<p><strong>[res_letterbox.subject]</strong></p>\n<p>&agrave; bien &eacute;t&eacute; r&eacute;ceptionn&eacute;e par nos services le [res_letterbox.admission_date].</p>\n<p><br />La r&eacute;f&eacute;rence de votre dossier est : <strong>[res_letterbox.alt_identifier]</strong></p>\n<p>Le pr&eacute;sent accus&eacute; de r&eacute;ception atteste de la r&eacute;ception de votre demande. Il ne pr&eacute;juge pas de la conformit&eacute; de son contenu qui d&eacute;pend entre autres de l'&eacute;tude des pi&egrave;ces fournies.</p>\n<p>Si l'instruction de votre demande n&eacute;cessite des informations ou des pi&egrave;ces compl&eacute;mentaires, nos services vous en ferons la demande</p>\n<p>&nbsp;</p>\n<p>Nous vous conseillons de conserver ce message jusqu'&agrave; la fin du traitement de votre dossier.</p>\n<p>&nbsp;</p>\n<p>[userPrimaryEntity.entity_label]</p>\n<p>Ville de Maarch-les-Bains</p>\n<p>&nbsp;</p>\n</div>	HTML	\N	\N	\N	letterbox_attachment	sendmail	all	\N	{}
1044	AR TYPE SVA - Courriel Manuel	A utiliser avec l'action "Générer les AR"	<div id="write" class="is-node"><br /><hr /><span style="color: #236fa1;">H&ocirc;tel de ville</span><br /><span style="color: #236fa1;">Place de la Libert&eacute;</span><br /><span style="color: #236fa1;">99000 Maarch-les-bains</span>\n<p>&nbsp;</p>\n<p><span style="color: #236fa1;"><strong>Accus&eacute; de r&eacute;ception de votre demande intervenant<br />dans le cadre d'une d&eacute;cision implicite d'acceptation<br /></strong></span></p>\n<p>Num&eacute;ro d'enregistrement :<strong> [res_letterbox.alt_identifier]</strong></p>\n<p>Service instructeur : <strong>[userPrimaryEntity.entity_label]</strong> <br />Courriel : [userPrimaryEntity.email]</p>\n<p>[userPrimaryEntity.address_town], le [datetime.date;frm=dddd dd mmmm yyyy (locale)]</p>\n<hr />\n<p>Bonjour,</p>\n<p>Votre demande concernant :</p>\n<p><strong>[res_letterbox.subject]</strong></p>\n<p>&agrave; bien &eacute;t&eacute; r&eacute;ceptionn&eacute;e par nos services le [res_letterbox.admission_date].</p>\n<p><br />La r&eacute;f&eacute;rence de votre dossier est : <strong>[res_letterbox.alt_identifier]</strong></p>\nLe pr&eacute;sent accus&eacute; de r&eacute;ception atteste de la r&eacute;ception de votre demande. il ne pr&eacute;juge pas de la conformit&eacute; de son contenu qui d&eacute;pend entre autres de l''&eacute;tude des pi&egrave;ces fournies.<br /><br />Votre demande est susceptible de faire l'objet d''une d&eacute;cision implicite d''acceptation en l'absence de r&eacute;ponse dans les jours suivant sa r&eacute;ception, soit le <strong>[res_letterbox.process_limit_date]</strong>.<br /><br />Si l'instruction de votre demande n&eacute;cessite des informations ou pi&egrave;ces compl&eacute;mentaires, la Ville vous contactera afin de les fournir, dans un d&eacute;lai de production qui sera fix&eacute;.<br /><br />Le cas &eacute;ch&eacute;ant, le d&eacute;lai de d&eacute;cision implicite d'acceptation ne d&eacute;butera qu''apr&egrave;s la production des pi&egrave;ces demand&eacute;es.<br /><br />En cas de d&eacute;cision implicite d''acceptation vous avez la possibilit&eacute; de demander au service charg&eacute; du dossier une attestation conform&eacute;ment aux dispositions de l'article 22 de la loi n&deg; 2000-321 du 12 avril 2000 relative aux droits des citoyens dans leurs relations avec les administrations modifi&eacute;e.\n<p>Nous vous conseillons de conserver ce message jusqu'&agrave; la fin du traitement de votre dossier.</p>\n<p>&nbsp;</p>\n<p><span style="color: #236fa1;">Ville de Maarch-les-Bains</span><br />[userPrimaryEntity.entity_label]</p>\n<p>Courriel : [userPrimaryEntity.email]<br />T&eacute;l&eacute;phone : [user.phone]</p>\n</div>	HTML	\N	\N	\N	letterbox_attachment	sendmail	all	\N	{}
1041	PR - Invitation (Visa interne)	Projet de réponse invitation pour visa interne	\N	OFFICE	2021/03/0001/	0001_742130848.docx	DOCX: PR02_INVITATION	letterbox_attachment	attachments	response_project	\N	{}
1047	EC - Générique (Visa externe)	Enregistrement de courrier générique	\N	OFFICE	2021/03/0001/	0005_1707546937.docx	DOCX: EC01_GENERIC	letterbox_attachment	indexingFile	all	\N	{}
20	Courriel d'accompagnement	Modèle de courriel d'accompagnement	<div id="write" class="is-node"><br /><hr /><span style="color: #236fa1;">H&ocirc;tel de ville</span><br /><span style="color: #236fa1;">Place de la Libert&eacute;</span><br /><span style="color: #236fa1;">99000 Maarch-les-bains</span>\n<p>[user.firstname] [user.lastname]<br />[userPrimaryEntity.role]<br />[userPrimaryEntity.entity_label]<br /><br />T&eacute;l&eacute;phone : &nbsp;&nbsp; &nbsp;[user.phone]<br />Courriel : &nbsp;&nbsp; &nbsp;[user.mail]</p>\n<p>[userPrimaryEntity.address_town], le [datetime.date;frm=dddd dd mmmm yyyy (locale)]</p>\n<hr />\n<p>Bonjour,</p>\n<p>Veuillez trouver en pi&egrave;ce jointe &agrave; ce courriel notre r&eacute;ponse &agrave; votre demande du [res_letterbox.admission_date].</p>\n<p>Bien cordialement.</p>\n<p>[user.firstname] [user.lastname]<br />[userPrimaryEntity.role]<br />[userPrimaryEntity.entity_label]<br /><br /></p>\n<p>&nbsp;</p>\n<p>&nbsp;</p>\n</div>	HTML	\N	\N	DOCX: standard_nosign	letterbox_attachment	sendmail	all	\N	{}
1048	PR - Générique (Visa externe)	Projet de réponse générique	\N	OFFICE	2021/03/0001/	0008_1397704541.docx	DOCX: PR01_GENERIC	letterbox_attachment	attachments	response_project	\N	{}
1038	EC - Générique (Visa interne)	Enregistrement de courrier générique	\N	OFFICE	2021/03/0001/	0003_320653448.docx	DOCX: EC01_GENERIC	letterbox_attachment	indexingFile	all	\N	{}
1040	PR - Générique (Visa interne)	Projet de réponse générique	\N	OFFICE	2021/03/0001/	0006_1786637551.docx	DOCX: PR01_GENERIC	letterbox_attachment	attachments	response_project	\N	{}
1046	PR - Invitation (Visa externe)	Modèle invitation pour visa externe	\N	OFFICE	2021/03/0001/	0002_705367294.docx	\N	letterbox_attachment	attachments	response_project	\N	{}
\.


--
-- Data for Name: templates_association; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.templates_association (id, template_id, value_field) FROM stdin;
1	900	VILLE
2	901	VILLE
3	902	VILLE
4	904	VILLE
5	905	VILLE
6	906	VILLE
7	907	VILLE
8	908	VILLE
9	909	VILLE
10	910	VILLE
11	1033	VILLE
12	1034	VILLE
572	1046	CAB
573	1046	COR
15	1035	VILLE
574	1046	FIN
575	1046	DRH
576	1046	DSI
577	1046	DGA
20	900	CAB
21	901	CAB
22	902	CAB
23	904	CAB
24	905	CAB
25	906	CAB
26	907	CAB
27	908	CAB
28	909	CAB
29	910	CAB
30	1033	CAB
31	1034	CAB
578	1046	DGS
579	1046	PE
34	1035	CAB
580	1046	PCU
581	1046	PSF
582	1046	PJS
583	1046	PJU
39	900	DGS
40	901	DGS
41	902	DGS
42	904	DGS
43	905	DGS
44	906	DGS
45	907	DGS
46	908	DGS
47	909	DGS
48	910	DGS
49	1033	DGS
50	1034	DGS
584	1046	PSO
585	1046	PTE
53	1035	DGS
586	1046	DSG
587	1046	COU
588	1046	SP
589	1046	VILLE
58	900	DGA
59	901	DGA
60	902	DGA
61	904	DGA
62	905	DGA
63	906	DGA
64	907	DGA
65	908	DGA
66	909	DGA
67	910	DGA
68	1033	DGA
69	1034	DGA
72	1035	DGA
77	900	PCU
78	901	PCU
79	902	PCU
80	904	PCU
81	905	PCU
82	906	PCU
83	907	PCU
84	908	PCU
85	909	PCU
86	910	PCU
87	1033	PCU
88	1034	PCU
91	1035	PCU
96	900	PJS
97	901	PJS
98	902	PJS
99	904	PJS
100	905	PJS
101	906	PJS
102	907	PJS
103	908	PJS
104	909	PJS
105	910	PJS
106	1033	PJS
107	1034	PJS
110	1035	PJS
115	900	PE
116	901	PE
117	902	PE
118	904	PE
119	905	PE
120	906	PE
121	907	PE
122	908	PE
123	909	PE
124	910	PE
125	1033	PE
126	1034	PE
129	1035	PE
134	900	SP
135	901	SP
136	902	SP
137	904	SP
138	905	SP
139	906	SP
140	907	SP
141	908	SP
142	909	SP
143	910	SP
144	1033	SP
145	1034	SP
148	1035	SP
153	900	PSO
154	901	PSO
155	902	PSO
156	904	PSO
157	905	PSO
158	906	PSO
159	907	PSO
160	908	PSO
161	909	PSO
162	910	PSO
163	1033	PSO
164	1034	PSO
590	1041	CAB
591	1041	COR
167	1035	PSO
592	1041	FIN
593	1041	DRH
594	1041	DSI
595	1041	DGA
172	900	PTE
173	901	PTE
174	902	PTE
175	904	PTE
176	905	PTE
177	906	PTE
178	907	PTE
179	908	PTE
180	909	PTE
181	910	PTE
182	1033	PTE
183	1034	PTE
596	1041	DGS
597	1041	PE
186	1035	PTE
598	1041	PCU
599	1041	PSF
600	1041	PJS
601	1041	PJU
191	900	DRH
192	901	DRH
193	902	DRH
194	904	DRH
195	905	DRH
196	906	DRH
197	907	DRH
198	908	DRH
199	909	DRH
200	910	DRH
201	1033	DRH
202	1034	DRH
602	1041	PSO
603	1041	PTE
205	1035	DRH
604	1041	DSG
605	1041	COU
606	1041	SP
607	1041	VILLE
210	900	DSG
211	901	DSG
212	902	DSG
213	904	DSG
214	905	DSG
215	906	DSG
216	907	DSG
217	908	DSG
218	909	DSG
219	910	DSG
220	1033	DSG
221	1034	DSG
224	1035	DSG
229	900	COU
230	901	COU
231	902	COU
232	904	COU
233	905	COU
234	906	COU
235	907	COU
236	908	COU
237	909	COU
238	910	COU
239	1033	COU
240	1034	COU
243	1035	COU
248	900	COR
249	901	COR
250	902	COR
251	904	COR
252	905	COR
253	906	COR
254	907	COR
255	908	COR
256	909	COR
257	910	COR
258	1033	COR
259	1034	COR
262	1035	COR
267	900	PSF
268	901	PSF
269	902	PSF
270	904	PSF
271	905	PSF
272	906	PSF
273	907	PSF
274	908	PSF
275	909	PSF
276	910	PSF
277	1033	PSF
278	1034	PSF
281	1035	PSF
286	900	DSI
287	901	DSI
288	902	DSI
289	904	DSI
290	905	DSI
291	906	DSI
292	907	DSI
293	908	DSI
294	909	DSI
295	910	DSI
296	1033	DSI
297	1034	DSI
300	1035	DSI
305	900	FIN
306	901	FIN
307	902	FIN
308	904	FIN
309	905	FIN
310	906	FIN
311	907	FIN
312	908	FIN
313	909	FIN
314	910	FIN
315	1033	FIN
316	1034	FIN
608	20	CAB
609	20	COR
319	1035	FIN
610	20	FIN
611	20	DRH
612	20	DSI
613	20	DGA
324	900	PJU
325	901	PJU
326	902	PJU
327	904	PJU
328	905	PJU
329	906	PJU
330	907	PJU
331	908	PJU
332	909	PJU
333	910	PJU
334	1033	PJU
335	1034	PJU
614	20	DGS
615	20	ELUS
338	1035	PJU
616	20	PE
617	20	PCU
618	20	PSF
619	20	PJS
343	900	ELUS
344	901	ELUS
345	902	ELUS
346	904	ELUS
347	905	ELUS
348	906	ELUS
349	907	ELUS
350	908	ELUS
351	909	ELUS
352	910	ELUS
353	1033	ELUS
354	1034	ELUS
620	20	PJU
621	20	PSO
357	1035	ELUS
622	20	PTE
623	20	DSG
624	20	COU
625	20	SP
362	900	CCAS
363	901	CCAS
364	902	CCAS
365	904	CCAS
366	905	CCAS
367	906	CCAS
368	907	CCAS
369	908	CCAS
370	909	CCAS
371	910	CCAS
372	1033	CCAS
373	1034	CCAS
626	20	VILLE
376	1035	CCAS
499	1048	CAB
500	1048	COR
501	1048	FIN
502	1048	DRH
503	1048	DSI
504	1048	DGA
505	1048	DGS
506	1048	ELUS
507	1048	PE
508	1048	PCU
509	1048	PSF
510	1048	PJS
511	1048	PJU
512	1048	PSO
513	1048	PTE
514	1048	DSG
515	1048	COU
516	1048	SP
517	1048	VILLE
518	1038	CAB
519	1038	COR
520	1038	FIN
521	1038	DRH
522	1038	DSI
523	1038	DGA
524	1038	DGS
525	1038	PE
526	1038	PCU
527	1038	PSF
528	1038	PJS
529	1038	PJU
530	1038	PSO
531	1038	PTE
532	1038	DSG
533	1038	COU
534	1038	SP
535	1038	VILLE
536	1047	CAB
537	1047	COR
538	1047	FIN
539	1047	DRH
540	1047	DSI
541	1047	DGA
542	1047	DGS
543	1047	PE
544	1047	PCU
545	1047	PSF
546	1047	PJS
547	1047	PJU
548	1047	PSO
549	1047	PTE
550	1047	DSG
551	1047	COU
552	1047	SP
553	1047	VILLE
554	1040	CAB
555	1040	COR
556	1040	FIN
557	1040	DRH
558	1040	DSI
559	1040	DGA
560	1040	DGS
561	1040	PE
562	1040	PCU
563	1040	PSF
564	1040	PJS
565	1040	PJU
566	1040	PSO
567	1040	PTE
568	1040	DSG
569	1040	COU
570	1040	SP
571	1040	VILLE
\.


--
-- Data for Name: tiles; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tiles (id, user_id, type, view, "position", color, parameters) FROM stdin;
2	21	myLastResources	list	0	#80cbc4	{}
3	21	shortcut	summary	1	#9fa8da	{"privilegeId": "admin_tag"}
1	21	basket	summary	3	#90caf9	{"groupId": 1, "basketId": 1}
5	16	myLastResources	list	0	#90caf9	{"groupId": 2, "basketId": 3}
8	23	searchTemplate	chart	1	#bcaaa4	{"chartMode": "creationDate", "chartType": "line", "searchTemplateId": 1}
7	23	searchTemplate	chart	0	#b0bec5	{"chartMode": "status", "chartType": "vertical-bar", "searchTemplateId": 1}
9	18	searchTemplate	chart	1	#ce93d8	{"chartMode": "destination", "chartType": "pie", "searchTemplateId": 2}
11	18	basket	list	0	#ef9a9a	{"groupId": 3, "basketId": 12}
12	5	basket	list	0	#90caf9	{"groupId": 8, "basketId": 9}
13	4	myLastResources	list	0	#90caf9	{"groupId": 2, "basketId": 3}
14	4	basket	summary	1	#ffcc80	{"groupId": 2, "basketId": 17}
16	17	basket	chart	1	#90caf9	{"groupId": 4, "basketId": 15, "chartMode": "doctype", "chartType": "pie"}
15	17	basket	summary	0	#ef9a9a	{"groupId": 4, "basketId": 16}
17	10	basket	summary	0	#ef9a9a	{"groupId": 4, "basketId": 16}
18	10	basket	chart	1	#b39ddb	{"groupId": 4, "basketId": 15, "chartMode": "destination", "chartType": "pie"}
19	10	basket	chart	2	#bcaaa4	{"groupId": 4, "basketId": 15, "chartMode": "doctype", "chartType": "vertical-bar"}
\.


--
-- Data for Name: unit_identifier; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.unit_identifier (message_id, tablename, res_id, disposition) FROM stdin;
\.


--
-- Data for Name: user_signatures; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.user_signatures (id, user_serial_id, signature_label, signature_path, signature_file_name, fingerprint) FROM stdin;
\.


--
-- Data for Name: usergroup_content; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.usergroup_content (user_id, group_id, role) FROM stdin;
1	4	
1	7	
2	2	
3	4	
4	2	
5	8	
6	4	
7	4	
7	7	
8	2	
9	2	
10	4	
11	2	
12	2	
13	2	
14	4	
15	2	
16	2	
17	4	
18	1	
18	3	
19	2	
20	2	
21	1	
21	5	
22	10	
24	11	
24	13	
15	4	\N
\.


--
-- Data for Name: usergroups; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.usergroups (id, group_id, group_desc, can_index, indexation_parameters, external_id) FROM stdin;
4	RESPONSABLE	Manager	t	{"actions": ["22", "20"], "entities": [], "keywords": ["ALL_ENTITIES"]}	{}
5	ADMINISTRATEUR_N1	Admin. Fonctionnel N1	f	{"actions": [], "entities": [], "keywords": []}	{}
6	ADMINISTRATEUR_N2	Admin. Fonctionnel N2	f	{"actions": [], "entities": [], "keywords": []}	{}
7	DIRECTEUR	Directeur	f	{"actions": [], "entities": [], "keywords": []}	{}
8	ELU	Elu	f	{"actions": [], "entities": [], "keywords": []}	{}
9	CABINET	Cabinet	f	{"actions": [], "entities": [], "keywords": []}	{}
10	ARCHIVISTE	Archiviste	f	{"actions": [], "entities": [], "keywords": []}	{}
11	MAARCHTOGEC	Envoi dématérialisé	f	{"actions": [], "entities": [], "keywords": []}	{}
12	SERVICE	Service	f	{"actions": [], "entities": [], "keywords": []}	{}
13	WEBSERVICE	Utilisateurs de WebService	t	{"actions": ["22", "20"], "entities": [], "keywords": ["ALL_ENTITIES"]}	{}
1	COURRIER	Opérateur de numérisation	t	{"actions": ["21", "22"], "entities": [], "keywords": ["ALL_ENTITIES"]}	{}
3	RESP_COURRIER	Superviseur Courrier	t	{"actions": ["21", "22"], "entities": [], "keywords": ["ALL_ENTITIES"]}	{}
2	AGENT	Utilisateur	t	{"actions": ["22", "414", "20"], "entities": [], "keywords": ["ALL_ENTITIES"]}	{}
\.


--
-- Data for Name: usergroups_services; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.usergroups_services (group_id, service_id, parameters) FROM stdin;
COURRIER	admin	\N
COURRIER	adv_search_mlb	\N
COURRIER	create_contacts	\N
COURRIER	update_contacts	\N
COURRIER	update_status_mail	\N
COURRIER	view_technical_infos	\N
COURRIER	view_doc_history	\N
COURRIER	view_full_history	\N
COURRIER	add_links	\N
COURRIER	update_resources	\N
COURRIER	update_diffusion_indexing	\N
COURRIER	update_diffusion_details	\N
COURRIER	entities_print_sep_mlb	\N
COURRIER	sendmail	\N
COURRIER	use_mail_services	\N
COURRIER	admin_registered_mail	\N
COURRIER	include_folders_and_followed_resources_perimeter	\N
COURRIER	update_delete_attachments	\N
COURRIER	view_documents_with_notes	\N
COURRIER	add_new_version	\N
COURRIER	view_version_letterbox	\N
COURRIER	print_folder_doc	\N
COURRIER	manage_tags_application	\N
COURRIER	private_tag	\N
COURRIER	_print_sep	\N
COURRIER	physical_archive_print_sep_mlb	\N
COURRIER	manage_numeric_package	\N
AGENT	adv_search_mlb	\N
AGENT	create_contacts	\N
AGENT	update_contacts	\N
AGENT	view_doc_history	\N
AGENT	add_links	\N
AGENT	update_diffusion_indexing	\N
AGENT	update_diffusion_details	\N
AGENT	sendmail	\N
AGENT	use_mail_services	\N
AGENT	include_folders_and_followed_resources_perimeter	\N
AGENT	update_delete_attachments	\N
AGENT	view_documents_with_notes	\N
AGENT	add_new_version	\N
AGENT	view_version_letterbox	\N
AGENT	config_visa_workflow	\N
AGENT	config_visa_workflow_in_detail	\N
AGENT	print_folder_doc	\N
AGENT	config_avis_workflow	\N
AGENT	config_avis_workflow_in_detail	\N
AGENT	private_tag	\N
AGENT	manage_numeric_package	\N
AGENT	add_correspondent_in_shared_groups_on_profile	\N
RESP_COURRIER	adv_search_mlb	\N
RESP_COURRIER	create_contacts	\N
RESP_COURRIER	update_contacts	\N
RESP_COURRIER	view_doc_history	\N
RESP_COURRIER	view_full_history	\N
RESP_COURRIER	add_links	\N
RESP_COURRIER	update_resources	\N
RESP_COURRIER	update_diffusion_indexing	\N
RESP_COURRIER	update_diffusion_details	\N
RESP_COURRIER	update_diffusion_process	\N
RESP_COURRIER	sendmail	\N
RESP_COURRIER	use_mail_services	\N
RESP_COURRIER	admin_registered_mail	\N
RESP_COURRIER	include_folders_and_followed_resources_perimeter	\N
RESP_COURRIER	view_documents_with_notes	\N
RESP_COURRIER	add_new_version	\N
RESP_COURRIER	view_version_letterbox	\N
RESP_COURRIER	sign_document	\N
RESP_COURRIER	visa_documents	\N
RESP_COURRIER	print_folder_doc	\N
RESP_COURRIER	private_tag	\N
RESP_COURRIER	manage_numeric_package	\N
RESPONSABLE	adv_search_mlb	\N
RESPONSABLE	create_contacts	\N
RESPONSABLE	update_contacts	\N
RESPONSABLE	view_doc_history	\N
RESPONSABLE	add_links	\N
RESPONSABLE	update_diffusion_indexing	\N
RESPONSABLE	update_diffusion_details	\N
RESPONSABLE	sendmail	\N
RESPONSABLE	use_mail_services	\N
RESPONSABLE	include_folders_and_followed_resources_perimeter	\N
RESPONSABLE	update_delete_attachments	\N
RESPONSABLE	view_documents_with_notes	\N
RESPONSABLE	add_new_version	\N
RESPONSABLE	view_version_letterbox	\N
RESPONSABLE	config_visa_workflow	\N
RESPONSABLE	config_visa_workflow_in_detail	\N
RESPONSABLE	sign_document	\N
RESPONSABLE	visa_documents	\N
RESPONSABLE	modify_visa_in_signatureBook	\N
RESPONSABLE	print_folder_doc	\N
RESPONSABLE	config_avis_workflow	\N
RESPONSABLE	config_avis_workflow_in_detail	\N
RESPONSABLE	avis_documents	\N
RESPONSABLE	private_tag	\N
RESPONSABLE	manage_numeric_package	\N
RESPONSABLE	add_correspondent_in_shared_groups_on_profile	\N
ADMINISTRATEUR_N1	admin	\N
ADMINISTRATEUR_N1	adv_search_mlb	\N
ADMINISTRATEUR_N1	admin_groups	\N
ADMINISTRATEUR_N1	admin_architecture	\N
ADMINISTRATEUR_N1	view_history	\N
ADMINISTRATEUR_N1	view_history_batch	\N
ADMINISTRATEUR_N1	admin_status	\N
ADMINISTRATEUR_N1	admin_actions	\N
ADMINISTRATEUR_N1	admin_contacts	\N
ADMINISTRATEUR_N1	admin_indexing_models	\N
ADMINISTRATEUR_N1	admin_custom_fields	\N
ADMINISTRATEUR_N1	create_contacts	\N
ADMINISTRATEUR_N1	update_contacts	\N
ADMINISTRATEUR_N1	update_status_mail	\N
ADMINISTRATEUR_N1	view_technical_infos	\N
ADMINISTRATEUR_N1	view_doc_history	\N
ADMINISTRATEUR_N1	view_full_history	\N
ADMINISTRATEUR_N1	add_links	\N
ADMINISTRATEUR_N1	admin_parameters	\N
ADMINISTRATEUR_N1	admin_priorities	\N
ADMINISTRATEUR_N1	update_resources	\N
ADMINISTRATEUR_N1	admin_email_server	\N
ADMINISTRATEUR_N1	admin_shippings	\N
ADMINISTRATEUR_N1	admin_baskets	\N
ADMINISTRATEUR_N1	manage_entities	\N
ADMINISTRATEUR_N1	admin_difflist_types	\N
ADMINISTRATEUR_N1	admin_listmodels	\N
ADMINISTRATEUR_N1	update_diffusion_indexing	\N
ADMINISTRATEUR_N1	update_diffusion_details	\N
ADMINISTRATEUR_N1	update_diffusion_process	\N
ADMINISTRATEUR_N1	entities_print_sep_mlb	\N
ADMINISTRATEUR_N1	sendmail	\N
ADMINISTRATEUR_N1	use_mail_services	\N
ADMINISTRATEUR_N1	admin_registered_mail	\N
ADMINISTRATEUR_N1	include_folders_and_followed_resources_perimeter	\N
ADMINISTRATEUR_N1	admin_alfresco	\N
ADMINISTRATEUR_N1	admin_search	\N
ADMINISTRATEUR_N1	update_delete_attachments	\N
ADMINISTRATEUR_N1	view_documents_with_notes	\N
ADMINISTRATEUR_N1	add_new_version	\N
ADMINISTRATEUR_N1	view_version_letterbox	\N
ADMINISTRATEUR_N1	config_visa_workflow	\N
ADMINISTRATEUR_N1	config_visa_workflow_in_detail	\N
ADMINISTRATEUR_N1	print_folder_doc	\N
ADMINISTRATEUR_N1	config_avis_workflow	\N
ADMINISTRATEUR_N1	admin_templates	\N
ADMINISTRATEUR_N1	admin_tag	\N
ADMINISTRATEUR_N1	manage_tags_application	\N
ADMINISTRATEUR_N1	private_tag	\N
ADMINISTRATEUR_N1	admin_notif	\N
ADMINISTRATEUR_N1	_print_sep	\N
ADMINISTRATEUR_N1	physical_archive_print_sep_mlb	\N
ADMINISTRATEUR_N1	physical_archive_batch_manage	\N
ADMINISTRATEUR_N1	admin_life_cycle	\N
ADMINISTRATEUR_N1	add_correspondent_in_shared_groups_on_profile	\N
ADMINISTRATEUR_N2	admin	\N
ADMINISTRATEUR_N2	view_doc_history	\N
ADMINISTRATEUR_N2	view_full_history	\N
ADMINISTRATEUR_N2	update_resources	\N
ADMINISTRATEUR_N2	include_folders_and_followed_resources_perimeter	\N
ADMINISTRATEUR_N2	admin_templates	\N
ADMINISTRATEUR_N2	admin_tag	\N
ELU	include_folders_and_followed_resources_perimeter	\N
ELU	sign_document	\N
ELU	visa_documents	\N
ELU	avis_documents	\N
ARCHIVISTE	adv_search_mlb	\N
ARCHIVISTE	create_contacts	\N
ARCHIVISTE	update_contacts	\N
ARCHIVISTE	view_technical_infos	\N
ARCHIVISTE	view_doc_history	\N
ARCHIVISTE	view_full_history	\N
ARCHIVISTE	sendmail	\N
ARCHIVISTE	include_folders_and_followed_resources_perimeter	\N
ARCHIVISTE	avis_documents	\N
ARCHIVISTE	export_seda_view	\N
MAARCHTOGEC	include_folders_and_followed_resources_perimeter	\N
MAARCHTOGEC	manage_numeric_package	\N
WEBSERVICE	include_folders_and_followed_resources_perimeter	\N
ADMINISTRATEUR_N1	admin_users	{"groups": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]}
ADMINISTRATEUR_N1	manage_personal_data	\N
AGENT	update_resources	\N
RESPONSABLE	update_diffusion_process	\N
ADMINISTRATEUR_N1	admin_mercure	\N
CABINET	sign_document	\N
CABINET	visa_documents	\N
DIRECTEUR	sign_document	\N
DIRECTEUR	visa_documents	\N
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.users (id, user_id, password, firstname, lastname, phone, mail, initials, preferences, status, password_modification_date, mode, refresh_token, reset_token, failed_authentication, locked_until, authorized_api, external_id, feature_tour, absence) FROM stdin;
5	ddur	$2y$10$C.QSslBKD3yNMfRPuZfcaubFwPKiCkqqOUyAdOr5FSGKPaePwuEjG	Dominique	DUR	\N	yourEmail@domain.com	\N	{"documentEdition": "onlyoffice"}	OK	2021-03-24 10:17:02.66594	standard	["eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTcyOTMxNjMsInVzZXIiOnsiaWQiOjV9fQ.-xHs1HNXaF04o5inFZeCOSOuodW8vrsPcVqsaiPnNww", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTcyOTMzMzgsInVzZXIiOnsiaWQiOjV9fQ.jY7jDCHyojZScH2FEDst825Rk3-M1ZspQXg0P5ZwQfQ"]	\N	0	\N	[]	{"internalParapheur": 5}	[]	\N
1	rrenaud	$2y$10$C.QSslBKD3yNMfRPuZfcaubFwPKiCkqqOUyAdOr5FSGKPaePwuEjG	Robert	RENAUD	\N	yourEmail@domain.com	\N	{"documentEdition": "onlyoffice"}	OK	2021-03-24 10:17:02.66594	standard	[]	\N	0	\N	[]	{"internalParapheur": 24}	[]	\N
2	ccordy	$2y$10$C.QSslBKD3yNMfRPuZfcaubFwPKiCkqqOUyAdOr5FSGKPaePwuEjG	Chloé	CORDY	\N	yourEmail@domain.com	\N	{"documentEdition": "onlyoffice"}	OK	2021-03-24 10:17:02.66594	standard	[]	\N	0	\N	[]	{"internalParapheur": 25}	[]	\N
3	ssissoko	$2y$10$C.QSslBKD3yNMfRPuZfcaubFwPKiCkqqOUyAdOr5FSGKPaePwuEjG	Sylvain	SISSOKO	\N	yourEmail@domain.com	\N	{"documentEdition": "onlyoffice"}	OK	2021-03-24 10:17:02.66594	standard	[]	\N	0	\N	[]	{"internalParapheur": 3}	[]	\N
7	eerina	$2y$10$C.QSslBKD3yNMfRPuZfcaubFwPKiCkqqOUyAdOr5FSGKPaePwuEjG	Edith	ERINA	\N	yourEmail@domain.com	\N	{"documentEdition": "onlyoffice"}	OK	2021-03-24 10:17:02.66594	standard	[]	\N	0	\N	[]	{"internalParapheur": 7}	[]	\N
8	kkaar	$2y$10$C.QSslBKD3yNMfRPuZfcaubFwPKiCkqqOUyAdOr5FSGKPaePwuEjG	Katy	KAAR	\N	yourEmail@domain.com	\N	{"documentEdition": "onlyoffice"}	OK	2021-03-24 10:17:02.66594	standard	[]	\N	0	\N	[]	{"internalParapheur": 4}	[]	\N
11	aackermann	$2y$10$C.QSslBKD3yNMfRPuZfcaubFwPKiCkqqOUyAdOr5FSGKPaePwuEjG	Amanda	ACKERMANN	\N	yourEmail@domain.com	\N	{"documentEdition": "onlyoffice"}	OK	2021-03-24 10:17:02.66594	standard	[]	\N	0	\N	[]	{"internalParapheur": 8}	[]	\N
12	ppruvost	$2y$10$C.QSslBKD3yNMfRPuZfcaubFwPKiCkqqOUyAdOr5FSGKPaePwuEjG	Pierre	PRUVOST	\N	yourEmail@domain.com	\N	{"documentEdition": "onlyoffice"}	OK	2021-03-24 10:17:02.66594	standard	[]	\N	0	\N	[]	{"internalParapheur": 11}	[]	\N
13	ttong	$2y$10$C.QSslBKD3yNMfRPuZfcaubFwPKiCkqqOUyAdOr5FSGKPaePwuEjG	Tony	TONG	\N	yourEmail@domain.com	\N	{"documentEdition": "onlyoffice"}	OK	2021-03-24 10:17:02.66594	standard	[]	\N	0	\N	[]	{"internalParapheur": 14}	[]	\N
14	sstar	$2y$10$C.QSslBKD3yNMfRPuZfcaubFwPKiCkqqOUyAdOr5FSGKPaePwuEjG	Suzanne	STAR	\N	yourEmail@domain.com	\N	{"documentEdition": "onlyoffice"}	OK	2021-03-24 10:17:02.66594	standard	[]	\N	0	\N	[]	{"internalParapheur": 15}	[]	\N
10	ppetit	$2y$10$C.QSslBKD3yNMfRPuZfcaubFwPKiCkqqOUyAdOr5FSGKPaePwuEjG	Patricia	PETIT	\N	yourEmail@domain.com	\N	{"documentEdition": "onlyoffice"}	OK	2021-03-24 10:17:02.66594	standard	["eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTczNzI2MTksInVzZXIiOnsiaWQiOjEwfX0.Ae49KoDeVxlFwVo4ET3nhuVt5syqsZT_f00-M1pEfFI", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTczODM0NDMsInVzZXIiOnsiaWQiOjEwfX0.G8Mw5nN-TkOZcRbWkmbhPqKCAPb3IHEJUkvLgcUMelE"]	\N	0	\N	[]	{"maarchParapheur": 10, "internalParapheur": 10}	[]	\N
20	jjonasz	$2y$10$C.QSslBKD3yNMfRPuZfcaubFwPKiCkqqOUyAdOr5FSGKPaePwuEjG	Jean	JONASZ	\N	yourEmail@domain.com	\N	{"documentEdition": "onlyoffice"}	OK	2021-03-24 10:17:02.66594	standard	[]	\N	0	\N	[]	{"internalParapheur": 17}	[]	\N
22	ggrand	$2y$10$C.QSslBKD3yNMfRPuZfcaubFwPKiCkqqOUyAdOr5FSGKPaePwuEjG	Georges	GRAND	\N	yourEmail@domain.com	\N	{"documentEdition": "onlyoffice"}	OK	2021-03-24 10:17:02.66594	standard	[]	\N	0	\N	[]	{"internalParapheur": 18}	[]	\N
6	jjane	$2y$10$C.QSslBKD3yNMfRPuZfcaubFwPKiCkqqOUyAdOr5FSGKPaePwuEjG	Jenny	JANE	\N	yourEmail@domain.com	\N	{"documentEdition": "onlyoffice"}	OK	2021-03-24 10:17:02.66594	standard	[]	\N	0	\N	[]	{"maarchParapheur": 13, "internalParapheur": 13}	[]	\N
17	mmanfred	$2y$10$C.QSslBKD3yNMfRPuZfcaubFwPKiCkqqOUyAdOr5FSGKPaePwuEjG	Martin	MANFRED	\N	yourEmail@domain.com	\N	{"documentEdition": "onlyoffice"}	OK	2021-03-24 10:17:02.66594	standard	["eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTczNzE1NTMsInVzZXIiOnsiaWQiOjE3fX0.eEecd_WTB_6vi8VbaVa2K7fpezUcfZ3ERRrGPw-_u8E", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTczNzIwMzgsInVzZXIiOnsiaWQiOjE3fX0.C0onpkSOTdb0wBooyiGv3k3rHMgGPK6XDZ9DhiZAtfk", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTczODI1MDgsInVzZXIiOnsiaWQiOjE3fX0.pnx3TTituAWYRfDrOBRe1w1HHnVFRi_qpM5WB4px13U"]	\N	0	\N	[]	{"maarchParapheur": 12, "internalParapheur": 12}	[]	\N
24	cchaplin	$2y$10$C.QSslBKD3yNMfRPuZfcaubFwPKiCkqqOUyAdOr5FSGKPaePwuEjG	Charlie	CHAPLIN	\N	yourEmail@domain.com	\N	{"documentEdition": "onlyoffice"}	OK	2021-03-24 10:17:02.66594	rest	[]	\N	0	\N	[]	{"internalParapheur": 19}	[]	\N
4	nnataly	$2y$10$C.QSslBKD3yNMfRPuZfcaubFwPKiCkqqOUyAdOr5FSGKPaePwuEjG	Nancy	NATALY	01 47 24 51 59	yourEmail@domain.com	NNA	{"documentEdition": "onlyoffice"}	OK	2021-03-24 10:17:02.66594	standard	["eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTczNzgwMjgsInVzZXIiOnsiaWQiOjR9fQ.I35ctVjGU98nEVZF58YfjF6O0rJ-9kBKuxfaQB33500", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTczNzg2OTYsInVzZXIiOnsiaWQiOjR9fQ.MFPGLYw0movM2-9u7OU5Ps1v3ydT78il2p5wOspD4_E", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTczNzg3NzcsInVzZXIiOnsiaWQiOjR9fQ.2GXoECa6AGRzFIrjx724Ie2ClpOmcVN5hcM8q6Wmhxk", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTczNzkzNTcsInVzZXIiOnsiaWQiOjR9fQ.pyi9SB-2XVjN6NwF2Ogf-C3s76bXsZxpfALfTlAkHZY", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTczODEwOTcsInVzZXIiOnsiaWQiOjR9fQ.UKS-X2axMLc383ox6V8iSkeTdU-iLFRqxUMjkr6yGzE", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTczODExOTUsInVzZXIiOnsiaWQiOjR9fQ.pPum2U9YxvyNpHbX8gql_5WVqBsjjuFsJyUSY2G_jqk", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTczODE0NzksInVzZXIiOnsiaWQiOjR9fQ.aFWso_KzJI_KM4gQ-o0TcR9gyYkyGLPRvpVSgIMvBq0", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTczODE3ODksInVzZXIiOnsiaWQiOjR9fQ.JV1dS4l_XQ_lysG6fiifDbz9_F5Z8FCoEfkwQk33G44", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTczODIxMTQsInVzZXIiOnsiaWQiOjR9fQ.wLG4aGupayZ2zaNwXd_jhJ-mANae_fc0Bx5tUguiOlI", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTczODIyNTYsInVzZXIiOnsiaWQiOjR9fQ.FYE8o4kg4EBiIx08_X514TQ0gGBRs8YPWWh0QPIJ3bg", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTczODM0MjMsInVzZXIiOnsiaWQiOjR9fQ.G0Uj3cJd8DOcqi1vtV63S9nBYTsT0sgjXiv49DmIm8Q"]	\N	0	\N	[]	{"internalParapheur": 20}	[]	\N
19	bbain	$2y$10$C.QSslBKD3yNMfRPuZfcaubFwPKiCkqqOUyAdOr5FSGKPaePwuEjG	Barbara	BAIN	\N	yourEmail@domain.com	\N	{"documentEdition": "onlyoffice"}	OK	2021-03-24 10:17:02.66594	standard	["eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTcxOTc1MTMsInVzZXIiOnsiaWQiOjE5fX0.3JD_K31gj_Cpzg2fDPv3ikwY8bEXHXHAgiPxBNP7Lks", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTcxOTgxOTMsInVzZXIiOnsiaWQiOjE5fX0.4IazyqfSoU_-kgOijesVIgwlfW6Zr1yofv2aOE9gZNM", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTcyMDE2NjUsInVzZXIiOnsiaWQiOjE5fX0.2noUw3WeSigdUK_y0a8O8edoOI97lPLh0VLs2zZ4zqA", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTcyNzAxOTksInVzZXIiOnsiaWQiOjE5fX0.reqaQ_wBiJ9GEMMqqeSHyPRXoHGemU8pWh2QOygo4ic", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTcyNzE3NzUsInVzZXIiOnsiaWQiOjE5fX0.bIG_XRegpDHdvT1Bqgkmw6yBB_KoNAk6an-Bmo4Sey0"]	\N	0	\N	[]	{"internalParapheur": 9}	[]	\N
21	bblier	$2y$10$C.QSslBKD3yNMfRPuZfcaubFwPKiCkqqOUyAdOr5FSGKPaePwuEjG	Bernard	BLIER	\N	yourEmail@domain.com	\N	{"documentEdition": "onlyoffice"}	OK	2021-03-24 10:17:02.66594	standard	["eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTcxOTc1MjgsInVzZXIiOnsiaWQiOjIxfX0.plGMlETEhHn_OySZhYOsDhbiXbn6CG9yv8teMXURDz0", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTcxOTc2MzgsInVzZXIiOnsiaWQiOjIxfX0.8fxQFdyselx4IFRDaBBDFr3k3PlG66IMAaX5HrnQYfA", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTcxOTgyMDksInVzZXIiOnsiaWQiOjIxfX0.Q06K2dqzzSRUHapFcPGMud-FwZpwKC0B8zLsMZ0VFEM", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTcxOTgyODgsInVzZXIiOnsiaWQiOjIxfX0.zIdDXtyl0rYZEuSbNwFbo6yw5NtqNnWiNKGX5dGhZY0", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTcxOTgzODQsInVzZXIiOnsiaWQiOjIxfX0.e0bKwQY8KJtfpKWZA92gdqrGAeRpdIRjUu0YoONpu4k", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTcyMDE2ODEsInVzZXIiOnsiaWQiOjIxfX0.GCPm6k81zdjHwSk_SdivRduSyQEBzEM3R_zGlrZNtdg", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTczODI3NzksInVzZXIiOnsiaWQiOjIxfX0.zc1Ua1yDsIn_mAFTBFKNA0fqp2B2yPBqg-jkkdy54cw", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTczODI4NzksInVzZXIiOnsiaWQiOjIxfX0.3p1rQntbBkj0QQol_7c1s6Yt6UOs3iXD8XMgZ9wU7AE", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTczODMyOTMsInVzZXIiOnsiaWQiOjIxfX0.3AQOob8RWZN26xvb7cKZoBK5UUECcgqFhAw_kedDBoM", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTczODQ2OTgsInVzZXIiOnsiaWQiOjIxfX0.NrjZGTE3CnItgkeKA9VpZv-egRMhfHEKHkTVRe_kR8E", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTczODQ5NTksInVzZXIiOnsiaWQiOjIxfX0.3W8l3CxftN-nZft758ovsTEXfK3CCZTY_4UxpqzD-IE"]	\N	0	\N	[]	{"internalParapheur": 22}	[]	\N
16	ccharles	$2y$10$C.QSslBKD3yNMfRPuZfcaubFwPKiCkqqOUyAdOr5FSGKPaePwuEjG	Charlotte	CHARLES	01 47 24 51 59	yourEmail@domain.com	CCH	{"documentEdition": "onlyoffice"}	OK	2021-03-24 10:17:02.66594	standard	["eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTcyOTMwNTMsInVzZXIiOnsiaWQiOjE2fX0._rHmsXcO-0vRCsW3G3XL71w4VDjIMebe4aSphm0vOcA", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTcyOTM5MjksInVzZXIiOnsiaWQiOjE2fX0.eiW-ayIAUkqa-UIbc6nTNGJgxqRUqC3df8P5QXNpPoY", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTczNTMxNDYsInVzZXIiOnsiaWQiOjE2fX0.srfJhsaLYx3dKhdqxXKtpCtPbN39L4HvdmNZ7oFMhZk", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTczNTMxNjYsInVzZXIiOnsiaWQiOjE2fX0.IHXvQhJ55loCeOVbnAQYEAdijsL27ldalGje2XQLOD8", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTczNTYyNDYsInVzZXIiOnsiaWQiOjE2fX0.5sNOhAqGGve7Yw9z2h3rH8Gfrnr1TQhgXmBYmaVbRSw", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTczNTcyMTUsInVzZXIiOnsiaWQiOjE2fX0.oxVhj7NNXf0DJq53cKKpXuSqxwop9jYJRkWH9UD5HlM", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTczNTc0MTAsInVzZXIiOnsiaWQiOjE2fX0.XWeCumwk3I4sQOIhsrGiIxU6LaZ7EIUWMwYg95Y5qjU", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTczNTc2MDIsInVzZXIiOnsiaWQiOjE2fX0.uPLIIIQqZoVc7UlNhj-DWKsbHzO_bJmsNPSPLlf3CQA", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTczNTc2OTksInVzZXIiOnsiaWQiOjE2fX0.rFsF0YNxAZDR7ATQ0F-irDVwWi10TL-mO520jKl5siM", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTczNzg3NDMsInVzZXIiOnsiaWQiOjE2fX0.U9Jv6X7ol87FyshBaGszRCpYVKSLWAID9YXX5CV15NU", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTczODM0MDUsInVzZXIiOnsiaWQiOjE2fX0.-kGf7-jXxJ47Q-CKq9ihFxZjZdhhMBmCChSdQh7-3YI"]	\N	0	\N	[]	{"internalParapheur": 23}	[]	\N
18	ddaull	$2y$10$C.QSslBKD3yNMfRPuZfcaubFwPKiCkqqOUyAdOr5FSGKPaePwuEjG	Denis	DAULL	\N	yourEmail@domain.com	DDE	{"documentEdition": "onlyoffice"}	OK	2021-03-24 10:17:02.66594	standard	["eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTcyNzQyNzgsInVzZXIiOnsiaWQiOjE4fX0.jjGCRbta3QIJekhRITCShxGSM_iXTSG9N3kijeZhpcE", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTcyNzQ3MjksInVzZXIiOnsiaWQiOjE4fX0.NM69b97AA4Q3fNhKdliSl2ZDw8N8JJXqmsh7I3wfhrE", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTcyNzUzODUsInVzZXIiOnsiaWQiOjE4fX0.lF9yhGCoC9W-Hafdp0Ll6wrC1fQEJ7qw6h1y92U0gik", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTcyODIyOTksInVzZXIiOnsiaWQiOjE4fX0.y7dTpSBDHYKaX0y_mWd4zY5xNuoj0cMYLcH2Nr8g6ds"]	\N	0	\N	[]	{"internalParapheur": 21}	[]	\N
23	superadmin	$2y$10$Vq244c5s2zmldjblmMXEN./Q2qZrqtGVgrbz/l1WfsUJbLco4E.e.	Super	ADMIN	0147245159	yourEmail@domain.com	\N	{"documentEdition": "onlyoffice"}	OK	2021-03-24 10:17:02.66594	root_invisible	["eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE3ODY0MDUwMTMsInVzZXIiOnsiaWQiOjIzfX0.C2s3vi3FLRKXensd_W5ouSkZQSWziAHMSgPrZKspXi0", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE3ODY0MDUyOTUsInVzZXIiOnsiaWQiOjIzfX0.r6IWpaWOehy5orUXM-QVciOy5RyPOSIWFTRmdSp3gBI", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE3ODY4Mzc2MzcsInVzZXIiOnsiaWQiOjIzfX0.z1TaNXGKz6J0SKIdBCzjI1V__nyMecQVP7ZDgSdy-Yk", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE3ODY4MzkzNzAsInVzZXIiOnsiaWQiOjIzfX0.r1hwiQjvgpbE8ldn4SzK9w5YpHaAOuxywnuLg21nDUI"]	\N	0	\N	[]	{"internalParapheur": 1}	["welcome", "email", "notification"]	\N
15	ssaporta	$2y$10$C.QSslBKD3yNMfRPuZfcaubFwPKiCkqqOUyAdOr5FSGKPaePwuEjG	Sabrina	SAPORTA	\N	yourEmail@domain.com	\N	{"documentEdition": "onlyoffice"}	OK	2021-03-24 10:17:02.66594	standard	["eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE3ODY4NDM1NjcsInVzZXIiOnsiaWQiOjE1fX0.GaKjUDG_POwc0WKdYMyONoAW8eGH_TcmTYjSSRoWuPA", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE3ODY4NDQwODgsInVzZXIiOnsiaWQiOjE1fX0.IQzraXMtL205rrXLebw3v4fiAu-7-MZQA3UjT41Cb1Q", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE3ODY4NDQzMDUsInVzZXIiOnsiaWQiOjE1fX0.hk6Jy1rEqPSnYgizzFeUEoVqiB6UbHyh2PheuTS0zfc", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE3ODY4NDUyMDUsInVzZXIiOnsiaWQiOjE1fX0.DZy3Rj8gZh9SzHTqaDHE402ct60ohHkvhke1zrXaDek", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE3ODY4NDY1NzIsInVzZXIiOnsiaWQiOjE1fX0.ysHuE4toKWpyUvtNM3HolYJYHKxbfA3DaOlBnvNKjR8", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE3ODY4NDY2MDcsInVzZXIiOnsiaWQiOjE1fX0.E3q53hxhX4BnWQRBaOZvgJM4CazElYPOaacnQUogCwE", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE3ODY4NDY3OTIsInVzZXIiOnsiaWQiOjE1fX0.dru6UciuVlQi9GnRpUM6REtJS0bukux1sSv-HkhWSB4", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE3ODY4NDgwODYsInVzZXIiOnsiaWQiOjE1fX0.OKHgMTZgzAbEh5WVlv-T3FmriUkPOr_Ka1F7nlpPpdQ", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE3ODY4NzcyNTAsInVzZXIiOnsiaWQiOjE1fX0.l5mbIHsrQRSgaKZ2XR2EZe823RUAy34hAqofpSin-sU", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE3ODY4NzcyNzcsInVzZXIiOnsiaWQiOjE1fX0.Jj2Pka4n_NFgYgATzXEq23IGsuDjRQ9AOTMJOgIq1hU", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE3ODY4NzgxODcsInVzZXIiOnsiaWQiOjE1fX0.MbNWAXAOxhRb_vCQNB-LFEfpiEPubZQfG7tLYgs7BfM"]	\N	0	\N	[]	{"internalParapheur": 16}	[]	\N
9	bboule	$2y$10$C.QSslBKD3yNMfRPuZfcaubFwPKiCkqqOUyAdOr5FSGKPaePwuEjG	Bruno	BOULE	\N	yourEmail@domain.com	\N	{"documentEdition": "onlyoffice"}	OK	2021-03-24 10:17:02.66594	standard	["eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE3ODY0MDYxMjgsInVzZXIiOnsiaWQiOjl9fQ.HYHyqdBIJLt95PmFL0mFVhef9XSnt8C6ftY5DAgIao4", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE3ODY4Mzc1ODksInVzZXIiOnsiaWQiOjl9fQ.P4Sa803Qiu3vzt32eUZmkht_TkqOInQE1x-LD8mtJW0", "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE3ODY4Mzc5MTUsInVzZXIiOnsiaWQiOjl9fQ.9gjdlyagczjObYYDA0E_FESNLj5qmYaBc1HZgOPqt5c"]	\N	0	\N	[]	{"internalParapheur": 6}	[]	\N
\.


--
-- Data for Name: users_baskets_preferences; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.users_baskets_preferences (id, user_serial_id, group_serial_id, basket_id, display, color) FROM stdin;
1	1	4	SendToSignatoryBook	t	\N
2	1	4	EenvBasket	t	\N
3	1	4	SuiviParafBasket	t	\N
4	1	4	ParafBasket	t	\N
5	1	4	DepartmentBasket	t	\N
6	1	4	MyBasket	t	\N
7	1	4	RetAvisBasket	t	\N
8	1	4	SupAvisBasket	t	\N
9	1	4	DdeAvisBasket	t	\N
10	1	4	CopyMailBasket	t	\N
13	2	2	Maileva_Sended	t	\N
14	2	2	AR_AlreadySend	t	\N
15	2	2	AR_Create	t	\N
16	2	2	SendToSignatoryBook	t	\N
17	2	2	EenvBasket	t	\N
18	2	2	SuiviParafBasket	t	\N
19	2	2	LateMailBasket	t	\N
20	2	2	MyBasket	t	\N
21	2	2	RetAvisBasket	t	\N
22	2	2	SupAvisBasket	t	\N
23	2	2	DdeAvisBasket	t	\N
24	2	2	CopyMailBasket	t	\N
25	3	4	SendToSignatoryBook	t	\N
26	3	4	EenvBasket	t	\N
27	3	4	SuiviParafBasket	t	\N
28	3	4	ParafBasket	t	\N
29	3	4	DepartmentBasket	t	\N
30	3	4	MyBasket	t	\N
31	3	4	RetAvisBasket	t	\N
32	3	4	SupAvisBasket	t	\N
33	3	4	DdeAvisBasket	t	\N
34	3	4	CopyMailBasket	t	\N
38	4	2	AR_AlreadySend	t	\N
39	4	2	AR_Create	t	\N
41	4	2	EenvBasket	t	\N
42	4	2	SuiviParafBasket	t	\N
43	4	2	LateMailBasket	t	\N
44	4	2	MyBasket	t	\N
45	4	2	RetAvisBasket	t	\N
46	4	2	SupAvisBasket	t	\N
47	4	2	DdeAvisBasket	t	\N
48	4	2	CopyMailBasket	t	\N
49	5	8	MyBasket	t	\N
50	5	8	DdeAvisBasket	t	\N
51	6	4	SendToSignatoryBook	t	\N
52	6	4	EenvBasket	t	\N
53	6	4	SuiviParafBasket	t	\N
54	6	4	ParafBasket	t	\N
55	6	4	DepartmentBasket	t	\N
56	6	4	MyBasket	t	\N
57	6	4	RetAvisBasket	t	\N
58	6	4	SupAvisBasket	t	\N
59	6	4	DdeAvisBasket	t	\N
60	6	4	CopyMailBasket	t	\N
61	7	4	SendToSignatoryBook	t	\N
62	7	4	EenvBasket	t	\N
63	7	4	SuiviParafBasket	t	\N
64	7	4	ParafBasket	t	\N
65	7	4	DepartmentBasket	t	\N
66	7	4	MyBasket	t	\N
67	7	4	RetAvisBasket	t	\N
68	7	4	SupAvisBasket	t	\N
69	7	4	DdeAvisBasket	t	\N
70	7	4	CopyMailBasket	t	\N
73	8	2	Maileva_Sended	t	\N
74	8	2	AR_AlreadySend	t	\N
75	8	2	AR_Create	t	\N
76	8	2	SendToSignatoryBook	t	\N
77	8	2	EenvBasket	t	\N
78	8	2	SuiviParafBasket	t	\N
79	8	2	LateMailBasket	t	\N
80	8	2	MyBasket	t	\N
81	8	2	RetAvisBasket	t	\N
82	8	2	SupAvisBasket	t	\N
83	8	2	DdeAvisBasket	t	\N
84	8	2	CopyMailBasket	t	\N
87	9	2	Maileva_Sended	t	\N
88	9	2	AR_AlreadySend	t	\N
89	9	2	AR_Create	t	\N
90	9	2	SendToSignatoryBook	t	\N
91	9	2	EenvBasket	t	\N
92	9	2	SuiviParafBasket	t	\N
93	9	2	LateMailBasket	t	\N
94	9	2	MyBasket	t	\N
95	9	2	RetAvisBasket	t	\N
96	9	2	SupAvisBasket	t	\N
97	9	2	DdeAvisBasket	t	\N
98	9	2	CopyMailBasket	t	\N
101	10	4	SuiviParafBasket	t	\N
102	10	4	ParafBasket	t	\N
103	10	4	DepartmentBasket	t	\N
105	10	4	RetAvisBasket	t	\N
106	10	4	SupAvisBasket	t	\N
107	10	4	DdeAvisBasket	t	\N
108	10	4	CopyMailBasket	t	\N
111	11	2	Maileva_Sended	t	\N
112	11	2	AR_AlreadySend	t	\N
113	11	2	AR_Create	t	\N
114	11	2	SendToSignatoryBook	t	\N
115	11	2	EenvBasket	t	\N
116	11	2	SuiviParafBasket	t	\N
117	11	2	LateMailBasket	t	\N
118	11	2	MyBasket	t	\N
119	11	2	RetAvisBasket	t	\N
120	11	2	SupAvisBasket	t	\N
121	11	2	DdeAvisBasket	t	\N
122	11	2	CopyMailBasket	t	\N
125	12	2	Maileva_Sended	t	\N
126	12	2	AR_AlreadySend	t	\N
127	12	2	AR_Create	t	\N
128	12	2	SendToSignatoryBook	t	\N
129	12	2	EenvBasket	t	\N
130	12	2	SuiviParafBasket	t	\N
131	12	2	LateMailBasket	t	\N
132	12	2	MyBasket	t	\N
133	12	2	RetAvisBasket	t	\N
134	12	2	SupAvisBasket	t	\N
135	12	2	DdeAvisBasket	t	\N
136	12	2	CopyMailBasket	t	\N
139	13	2	Maileva_Sended	t	\N
140	13	2	AR_AlreadySend	t	\N
141	13	2	AR_Create	t	\N
142	13	2	SendToSignatoryBook	t	\N
143	13	2	EenvBasket	t	\N
144	13	2	SuiviParafBasket	t	\N
145	13	2	LateMailBasket	t	\N
146	13	2	MyBasket	t	\N
147	13	2	RetAvisBasket	t	\N
148	13	2	SupAvisBasket	t	\N
149	13	2	DdeAvisBasket	t	\N
150	13	2	CopyMailBasket	t	\N
151	14	4	SendToSignatoryBook	t	\N
152	14	4	EenvBasket	t	\N
153	14	4	SuiviParafBasket	t	\N
154	14	4	ParafBasket	t	\N
155	14	4	DepartmentBasket	t	\N
156	14	4	MyBasket	t	\N
157	14	4	RetAvisBasket	t	\N
158	14	4	SupAvisBasket	t	\N
159	14	4	DdeAvisBasket	t	\N
160	14	4	CopyMailBasket	t	\N
163	15	2	Maileva_Sended	t	\N
164	15	2	AR_AlreadySend	t	\N
165	15	2	AR_Create	t	\N
166	15	2	SendToSignatoryBook	t	\N
167	15	2	EenvBasket	t	\N
168	15	2	SuiviParafBasket	t	\N
169	15	2	LateMailBasket	t	\N
170	15	2	MyBasket	t	\N
171	15	2	RetAvisBasket	t	\N
172	15	2	SupAvisBasket	t	\N
173	15	2	DdeAvisBasket	t	\N
174	15	2	CopyMailBasket	t	\N
177	16	2	Maileva_Sended	t	\N
178	16	2	AR_AlreadySend	t	\N
179	16	2	AR_Create	t	\N
180	16	2	SendToSignatoryBook	t	\N
181	16	2	EenvBasket	t	\N
182	16	2	SuiviParafBasket	t	\N
183	16	2	LateMailBasket	t	\N
184	16	2	MyBasket	t	\N
185	16	2	RetAvisBasket	t	\N
186	16	2	SupAvisBasket	t	\N
187	16	2	DdeAvisBasket	t	\N
188	16	2	CopyMailBasket	t	\N
189	17	4	SendToSignatoryBook	t	\N
190	17	4	EenvBasket	t	\N
191	17	4	SuiviParafBasket	t	\N
192	17	4	ParafBasket	t	\N
193	17	4	DepartmentBasket	t	\N
194	17	4	MyBasket	t	\N
195	17	4	RetAvisBasket	t	\N
196	17	4	SupAvisBasket	t	\N
197	17	4	DdeAvisBasket	t	\N
198	17	4	CopyMailBasket	t	\N
199	18	1	NumericBasket	t	\N
200	18	1	RetourCourrier	t	\N
201	18	1	QualificationBasket	t	\N
202	18	3	ValidationBasket	t	\N
205	19	2	Maileva_Sended	t	\N
206	19	2	AR_AlreadySend	t	\N
207	19	2	AR_Create	t	\N
208	19	2	SendToSignatoryBook	t	\N
209	19	2	EenvBasket	t	\N
210	19	2	SuiviParafBasket	t	\N
211	19	2	LateMailBasket	t	\N
212	19	2	MyBasket	t	\N
213	19	2	RetAvisBasket	t	\N
214	19	2	SupAvisBasket	t	\N
215	19	2	DdeAvisBasket	t	\N
216	19	2	CopyMailBasket	t	\N
219	20	2	Maileva_Sended	t	\N
220	20	2	AR_AlreadySend	t	\N
221	20	2	AR_Create	t	\N
222	20	2	SendToSignatoryBook	t	\N
223	20	2	EenvBasket	t	\N
224	20	2	SuiviParafBasket	t	\N
225	20	2	LateMailBasket	t	\N
226	20	2	MyBasket	t	\N
227	20	2	RetAvisBasket	t	\N
228	20	2	SupAvisBasket	t	\N
229	20	2	DdeAvisBasket	t	\N
230	20	2	CopyMailBasket	t	\N
231	21	1	NumericBasket	t	\N
232	21	1	RetourCourrier	t	\N
233	21	1	QualificationBasket	t	\N
234	22	10	AckArcBasket	t	\N
235	22	10	SentArcBasket	t	\N
236	22	10	ToArcBasket	t	\N
237	10	4	EenvBasket	t	\N
238	10	4	MyBasket	t	\N
251	2	2	outlook_mails	t	\N
252	4	2	outlook_mails	t	\N
253	8	2	outlook_mails	t	\N
254	9	2	outlook_mails	t	\N
255	11	2	outlook_mails	t	\N
256	12	2	outlook_mails	t	\N
257	13	2	outlook_mails	t	\N
258	15	2	outlook_mails	t	\N
259	16	2	outlook_mails	t	\N
260	19	2	outlook_mails	t	\N
261	20	2	outlook_mails	t	\N
262	1	7	outlook_mails	t	\N
263	7	7	outlook_mails	t	\N
264	1	4	outlook_mails	t	\N
265	3	4	outlook_mails	t	\N
266	6	4	outlook_mails	t	\N
267	7	4	outlook_mails	t	\N
268	10	4	outlook_mails	t	\N
269	14	4	outlook_mails	t	\N
270	17	4	outlook_mails	t	\N
271	18	1	outlook_mails	t	\N
272	21	1	outlook_mails	t	\N
273	18	3	outlook_mails	t	\N
\.


--
-- Data for Name: users_email_signatures; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.users_email_signatures (id, user_id, html_body, title) FROM stdin;
\.


--
-- Data for Name: users_entities; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.users_entities (user_id, entity_id, user_role, primary_entity) FROM stdin;
1	DGS		Y
2	DSI		Y
3	DSI		Y
5	ELUS		Y
6	CCAS		Y
7	CAB		Y
8	DGA		Y
9	PCU		Y
10	VILLE		Y
11	PSF		Y
12	DRH		Y
13	SP		Y
14	FIN		Y
15	PE		Y
17	DGA		Y
19	PJS		Y
20	PJU		Y
22	COR		Y
24	VILLE		Y
23	VILLE		Y
23	CCAS		N
21	COU	Agent service courrier	Y
16	PTE	Responsable de pôle	Y
18	DSG	Superviseur courrier	Y
4	PSO	Responsable Pole Social	Y
\.


--
-- Data for Name: users_followed_resources; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.users_followed_resources (id, res_id, user_id) FROM stdin;
\.


--
-- Data for Name: users_pinned_folders; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.users_pinned_folders (id, folder_id, user_id) FROM stdin;
\.


--
-- Name: acknowledgement_receipts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.acknowledgement_receipts_id_seq', 1, false);


--
-- Name: actions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.actions_id_seq', 538, false);


--
-- Name: address_sectors_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.address_sectors_id_seq', 1, false);


--
-- Name: adr_attachments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.adr_attachments_id_seq', 14, true);


--
-- Name: adr_letterbox_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.adr_letterbox_id_seq', 8, true);


--
-- Name: attachment_types_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.attachment_types_id_seq', 12, false);


--
-- Name: baskets_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.baskets_id_seq', 26, false);


--
-- Name: blacklist_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.blacklist_id_seq', 1, false);


--
-- Name: chrono_incoming_2026_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.chrono_incoming_2026_seq', 6, true);


--
-- Name: chrono_outgoing_2026_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.chrono_outgoing_2026_seq', 8, true);


--
-- Name: configurations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.configurations_id_seq', 11, false);


--
-- Name: contacts_civilities_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.contacts_civilities_id_seq', 7, false);


--
-- Name: contacts_custom_fields_list_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.contacts_custom_fields_list_id_seq', 1, false);


--
-- Name: contacts_filling_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.contacts_filling_id_seq', 2, false);


--
-- Name: contacts_groups_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.contacts_groups_id_seq', 1, false);


--
-- Name: contacts_groups_lists_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.contacts_groups_lists_id_seq', 1, false);


--
-- Name: contacts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.contacts_id_seq', 12, true);


--
-- Name: contacts_parameters_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.contacts_parameters_id_seq', 18, false);


--
-- Name: custom_fields_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.custom_fields_id_seq', 6, false);


--
-- Name: difflist_roles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.difflist_roles_id_seq', 1, false);


--
-- Name: docservers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.docservers_id_seq', 14, false);


--
-- Name: doctypes_first_level_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.doctypes_first_level_id_seq', 2, false);


--
-- Name: doctypes_second_level_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.doctypes_second_level_id_seq', 13, false);


--
-- Name: doctypes_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.doctypes_type_id_seq', 1204, false);


--
-- Name: emails_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.emails_id_seq', 1, false);


--
-- Name: entities_folders_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.entities_folders_id_seq', 761, false);


--
-- Name: entities_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.entities_id_seq', 21, false);


--
-- Name: exports_templates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.exports_templates_id_seq', 3, false);


--
-- Name: folders_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.folders_id_seq', 39, false);


--
-- Name: groupbasket_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.groupbasket_id_seq', 38, false);


--
-- Name: groupbasket_redirect_system_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.groupbasket_redirect_system_id_seq', 734, false);


--
-- Name: history_batch_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.history_batch_id_seq', 100, true);


--
-- Name: history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.history_id_seq', 139, true);


--
-- Name: indexing_models_entities_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.indexing_models_entities_id_seq', 10, true);


--
-- Name: indexing_models_fields_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.indexing_models_fields_id_seq', 93, false);


--
-- Name: indexing_models_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.indexing_models_id_seq', 9, false);


--
-- Name: list_templates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.list_templates_id_seq', 1011, false);


--
-- Name: list_templates_items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.list_templates_items_id_seq', 45, false);


--
-- Name: listinstance_history_details_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.listinstance_history_details_id_seq', 8, true);


--
-- Name: listinstance_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.listinstance_history_id_seq', 8, true);


--
-- Name: listinstance_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.listinstance_id_seq', 17, true);


--
-- Name: notes_entities_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.notes_entities_id_seq', 20, false);


--
-- Name: notes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.notes_id_seq', 2, true);


--
-- Name: notif_email_stack_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.notif_email_stack_seq', 1, false);


--
-- Name: notif_event_stack_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.notif_event_stack_seq', 2, true);


--
-- Name: notifications_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.notifications_seq', 101, false);


--
-- Name: password_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.password_history_id_seq', 1, false);


--
-- Name: password_rules_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.password_rules_id_seq', 9, false);


--
-- Name: redirected_baskets_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.redirected_baskets_id_seq', 1, false);


--
-- Name: registered_mail_issuing_sites_entities_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.registered_mail_issuing_sites_entities_id_seq', 3, false);


--
-- Name: registered_mail_issuing_sites_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.registered_mail_issuing_sites_id_seq', 2, false);


--
-- Name: registered_mail_number_range_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.registered_mail_number_range_id_seq', 4, false);


--
-- Name: registered_mail_resources_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.registered_mail_resources_id_seq', 1, false);


--
-- Name: res_attachment_res_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.res_attachment_res_id_seq', 8, true);


--
-- Name: res_id_mlb_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.res_id_mlb_seq', 110, true);


--
-- Name: resource_contacts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.resource_contacts_id_seq', 5, true);


--
-- Name: resources_folders_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.resources_folders_id_seq', 1, false);


--
-- Name: resources_tags_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.resources_tags_id_seq', 1, false);


--
-- Name: search_templates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.search_templates_id_seq', 3, false);


--
-- Name: security_security_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.security_security_id_seq', 613, false);


--
-- Name: shipping_templates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.shipping_templates_id_seq', 2, false);


--
-- Name: shippings_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.shippings_id_seq', 1, false);


--
-- Name: status_identifier_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.status_identifier_seq', 43, false);


--
-- Name: status_images_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.status_images_id_seq', 31, false);


--
-- Name: tags_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.tags_id_seq', 14, false);


--
-- Name: templates_association_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.templates_association_id_seq', 627, false);


--
-- Name: templates_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.templates_seq', 1049, false);


--
-- Name: tiles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.tiles_id_seq', 20, false);


--
-- Name: user_signatures_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.user_signatures_id_seq', 1, false);


--
-- Name: usergroups_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.usergroups_id_seq', 14, false);


--
-- Name: users_baskets_preferences_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.users_baskets_preferences_id_seq', 274, false);


--
-- Name: users_email_signatures_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.users_email_signatures_id_seq', 1, false);


--
-- Name: users_followed_resources_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.users_followed_resources_id_seq', 1, false);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.users_id_seq', 25, false);


--
-- Name: users_pinned_folders_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.users_pinned_folders_id_seq', 1, false);


--
-- Name: acknowledgement_receipts acknowledgement_receipts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.acknowledgement_receipts
    ADD CONSTRAINT acknowledgement_receipts_pkey PRIMARY KEY (id);


--
-- Name: actions_categories actions_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.actions_categories
    ADD CONSTRAINT actions_categories_pkey PRIMARY KEY (action_id, category_id);


--
-- Name: actions_groupbaskets actions_groupbaskets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.actions_groupbaskets
    ADD CONSTRAINT actions_groupbaskets_pkey PRIMARY KEY (id_action, group_id, basket_id);


--
-- Name: actions actions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.actions
    ADD CONSTRAINT actions_pkey PRIMARY KEY (id);


--
-- Name: address_sectors address_sectors_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.address_sectors
    ADD CONSTRAINT address_sectors_key UNIQUE (address_number, address_street, address_postcode, address_town);


--
-- Name: address_sectors address_sectors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.address_sectors
    ADD CONSTRAINT address_sectors_pkey PRIMARY KEY (id);


--
-- Name: adr_attachments adr_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.adr_attachments
    ADD CONSTRAINT adr_attachments_pkey PRIMARY KEY (id);


--
-- Name: adr_attachments adr_attachments_unique_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.adr_attachments
    ADD CONSTRAINT adr_attachments_unique_key UNIQUE (res_id, type);


--
-- Name: adr_letterbox adr_letterbox_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.adr_letterbox
    ADD CONSTRAINT adr_letterbox_pkey PRIMARY KEY (id);


--
-- Name: adr_letterbox adr_letterbox_unique_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.adr_letterbox
    ADD CONSTRAINT adr_letterbox_unique_key UNIQUE (res_id, type, version);


--
-- Name: attachment_types attachment_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attachment_types
    ADD CONSTRAINT attachment_types_pkey PRIMARY KEY (id);


--
-- Name: attachment_types attachment_types_unique_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attachment_types
    ADD CONSTRAINT attachment_types_unique_key UNIQUE (type_id);


--
-- Name: baskets baskets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.baskets
    ADD CONSTRAINT baskets_pkey PRIMARY KEY (coll_id, basket_id);


--
-- Name: baskets baskets_unique_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.baskets
    ADD CONSTRAINT baskets_unique_key UNIQUE (id);


--
-- Name: blacklist blacklist_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blacklist
    ADD CONSTRAINT blacklist_pkey PRIMARY KEY (id);


--
-- Name: blacklist blacklist_term_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blacklist
    ADD CONSTRAINT blacklist_term_key UNIQUE (term);


--
-- Name: configurations configuration_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.configurations
    ADD CONSTRAINT configuration_pkey PRIMARY KEY (id);


--
-- Name: configurations configuration_unique_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.configurations
    ADD CONSTRAINT configuration_unique_key UNIQUE (privilege);


--
-- Name: contacts_civilities contacts_civilities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contacts_civilities
    ADD CONSTRAINT contacts_civilities_pkey PRIMARY KEY (id);


--
-- Name: contacts_custom_fields_list contacts_custom_fields_list_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contacts_custom_fields_list
    ADD CONSTRAINT contacts_custom_fields_list_pkey PRIMARY KEY (id);


--
-- Name: contacts_custom_fields_list contacts_custom_fields_list_unique_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contacts_custom_fields_list
    ADD CONSTRAINT contacts_custom_fields_list_unique_key UNIQUE (label);


--
-- Name: contacts_filling contacts_filling_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contacts_filling
    ADD CONSTRAINT contacts_filling_pkey PRIMARY KEY (id);


--
-- Name: contacts_groups_lists contacts_groups_lists_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contacts_groups_lists
    ADD CONSTRAINT contacts_groups_lists_pkey PRIMARY KEY (id);


--
-- Name: contacts_groups contacts_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contacts_groups
    ADD CONSTRAINT contacts_groups_pkey PRIMARY KEY (id);


--
-- Name: contacts_parameters contacts_parameters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contacts_parameters
    ADD CONSTRAINT contacts_parameters_pkey PRIMARY KEY (id);


--
-- Name: contacts contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contacts
    ADD CONSTRAINT contacts_pkey PRIMARY KEY (id);


--
-- Name: convert_stack convert_stack_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.convert_stack
    ADD CONSTRAINT convert_stack_pkey PRIMARY KEY (coll_id, res_id, convert_format);


--
-- Name: custom_fields custom_fields_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_fields
    ADD CONSTRAINT custom_fields_pkey PRIMARY KEY (id);


--
-- Name: custom_fields custom_fields_unique_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_fields
    ADD CONSTRAINT custom_fields_unique_key UNIQUE (label);


--
-- Name: difflist_roles difflist_roles_role_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.difflist_roles
    ADD CONSTRAINT difflist_roles_role_id_key UNIQUE (role_id);


--
-- Name: difflist_types difflist_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.difflist_types
    ADD CONSTRAINT difflist_types_pkey PRIMARY KEY (difflist_type_id);


--
-- Name: docserver_types docserver_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.docserver_types
    ADD CONSTRAINT docserver_types_pkey PRIMARY KEY (docserver_type_id);


--
-- Name: docservers docservers_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.docservers
    ADD CONSTRAINT docservers_id_key UNIQUE (id);


--
-- Name: docservers docservers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.docservers
    ADD CONSTRAINT docservers_pkey PRIMARY KEY (docserver_id);


--
-- Name: doctypes_first_level doctypes_first_level_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.doctypes_first_level
    ADD CONSTRAINT doctypes_first_level_pkey PRIMARY KEY (doctypes_first_level_id);


--
-- Name: doctypes_indexes doctypes_indexes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.doctypes_indexes
    ADD CONSTRAINT doctypes_indexes_pkey PRIMARY KEY (type_id, coll_id, field_name);


--
-- Name: doctypes doctypes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.doctypes
    ADD CONSTRAINT doctypes_pkey PRIMARY KEY (type_id);


--
-- Name: doctypes_second_level doctypes_second_level_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.doctypes_second_level
    ADD CONSTRAINT doctypes_second_level_pkey PRIMARY KEY (doctypes_second_level_id);


--
-- Name: users_email_signatures email_signatures_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users_email_signatures
    ADD CONSTRAINT email_signatures_pkey PRIMARY KEY (id);


--
-- Name: emails emails_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.emails
    ADD CONSTRAINT emails_pkey PRIMARY KEY (id);


--
-- Name: entities entities_folder_import_unique_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entities
    ADD CONSTRAINT entities_folder_import_unique_key UNIQUE (folder_import);


--
-- Name: entities_folders entities_folders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entities_folders
    ADD CONSTRAINT entities_folders_pkey PRIMARY KEY (id);


--
-- Name: entities_folders entities_folders_unique_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entities_folders
    ADD CONSTRAINT entities_folders_unique_key UNIQUE (folder_id, entity_id, keyword);


--
-- Name: entities entities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entities
    ADD CONSTRAINT entities_pkey PRIMARY KEY (entity_id);


--
-- Name: exports_templates exports_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exports_templates
    ADD CONSTRAINT exports_templates_pkey PRIMARY KEY (id);


--
-- Name: exports_templates exports_templates_unique_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exports_templates
    ADD CONSTRAINT exports_templates_unique_key UNIQUE (user_id, format);


--
-- Name: folders folders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.folders
    ADD CONSTRAINT folders_pkey PRIMARY KEY (id);


--
-- Name: groupbasket groupbasket_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.groupbasket
    ADD CONSTRAINT groupbasket_pkey PRIMARY KEY (group_id, basket_id);


--
-- Name: groupbasket_redirect groupbasket_redirect_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.groupbasket_redirect
    ADD CONSTRAINT groupbasket_redirect_pkey PRIMARY KEY (system_id);


--
-- Name: groupbasket groupbasket_unique_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.groupbasket
    ADD CONSTRAINT groupbasket_unique_key UNIQUE (id);


--
-- Name: history_batch history_batch_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.history_batch
    ADD CONSTRAINT history_batch_pkey PRIMARY KEY (id);


--
-- Name: history history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.history
    ADD CONSTRAINT history_pkey PRIMARY KEY (id);


--
-- Name: indexing_models_entities indexing_models_entities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.indexing_models_entities
    ADD CONSTRAINT indexing_models_entities_pkey PRIMARY KEY (id);


--
-- Name: indexing_models_fields indexing_models_fields_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.indexing_models_fields
    ADD CONSTRAINT indexing_models_fields_pkey PRIMARY KEY (id);


--
-- Name: indexing_models indexing_models_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.indexing_models
    ADD CONSTRAINT indexing_models_pkey PRIMARY KEY (id);


--
-- Name: lc_cycles lc_cycle_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lc_cycles
    ADD CONSTRAINT lc_cycle_pkey PRIMARY KEY (policy_id, cycle_id);


--
-- Name: lc_cycle_steps lc_cycle_steps_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lc_cycle_steps
    ADD CONSTRAINT lc_cycle_steps_pkey PRIMARY KEY (policy_id, cycle_id, cycle_step_id, docserver_type_id);


--
-- Name: lc_policies lc_policies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lc_policies
    ADD CONSTRAINT lc_policies_pkey PRIMARY KEY (policy_id);


--
-- Name: lc_stack lc_stack_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lc_stack
    ADD CONSTRAINT lc_stack_pkey PRIMARY KEY (policy_id, cycle_id, cycle_step_id, res_id);


--
-- Name: list_templates_items list_templates_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.list_templates_items
    ADD CONSTRAINT list_templates_items_pkey PRIMARY KEY (id);


--
-- Name: list_templates list_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.list_templates
    ADD CONSTRAINT list_templates_pkey PRIMARY KEY (id);


--
-- Name: listinstance_history_details listinstance_history_details_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.listinstance_history_details
    ADD CONSTRAINT listinstance_history_details_pkey PRIMARY KEY (listinstance_history_details_id);


--
-- Name: listinstance_history listinstance_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.listinstance_history
    ADD CONSTRAINT listinstance_history_pkey PRIMARY KEY (listinstance_history_id);


--
-- Name: listinstance listinstance_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.listinstance
    ADD CONSTRAINT listinstance_pkey PRIMARY KEY (listinstance_id);


--
-- Name: message_exchange message_exchange_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_exchange
    ADD CONSTRAINT message_exchange_pkey PRIMARY KEY (message_id);


--
-- Name: note_entities note_entities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.note_entities
    ADD CONSTRAINT note_entities_pkey PRIMARY KEY (id);


--
-- Name: notes notes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notes
    ADD CONSTRAINT notes_pkey PRIMARY KEY (id);


--
-- Name: notif_email_stack notif_email_stack_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notif_email_stack
    ADD CONSTRAINT notif_email_stack_pkey PRIMARY KEY (email_stack_sid);


--
-- Name: notif_event_stack notif_event_stack_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notif_event_stack
    ADD CONSTRAINT notif_event_stack_pkey PRIMARY KEY (event_stack_sid);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (notification_sid);


--
-- Name: parameters parameters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parameters
    ADD CONSTRAINT parameters_pkey PRIMARY KEY (id);


--
-- Name: password_history password_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.password_history
    ADD CONSTRAINT password_history_pkey PRIMARY KEY (id);


--
-- Name: password_rules password_rules_label_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.password_rules
    ADD CONSTRAINT password_rules_label_key UNIQUE (label);


--
-- Name: password_rules password_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.password_rules
    ADD CONSTRAINT password_rules_pkey PRIMARY KEY (id);


--
-- Name: priorities priorities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.priorities
    ADD CONSTRAINT priorities_pkey PRIMARY KEY (id);


--
-- Name: redirected_baskets redirected_baskets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.redirected_baskets
    ADD CONSTRAINT redirected_baskets_pkey PRIMARY KEY (id);


--
-- Name: redirected_baskets redirected_baskets_unique_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.redirected_baskets
    ADD CONSTRAINT redirected_baskets_unique_key UNIQUE (owner_user_id, basket_id, group_id);


--
-- Name: registered_mail_issuing_sites_entities registered_mail_issuing_sites_entities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.registered_mail_issuing_sites_entities
    ADD CONSTRAINT registered_mail_issuing_sites_entities_pkey PRIMARY KEY (id);


--
-- Name: registered_mail_issuing_sites_entities registered_mail_issuing_sites_entities_unique_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.registered_mail_issuing_sites_entities
    ADD CONSTRAINT registered_mail_issuing_sites_entities_unique_key UNIQUE (site_id, entity_id);


--
-- Name: registered_mail_issuing_sites registered_mail_issuing_sites_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.registered_mail_issuing_sites
    ADD CONSTRAINT registered_mail_issuing_sites_pkey PRIMARY KEY (id);


--
-- Name: registered_mail_number_range registered_mail_number_range_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.registered_mail_number_range
    ADD CONSTRAINT registered_mail_number_range_pkey PRIMARY KEY (id);


--
-- Name: registered_mail_number_range registered_mail_number_range_unique_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.registered_mail_number_range
    ADD CONSTRAINT registered_mail_number_range_unique_key UNIQUE (tracking_account_number);


--
-- Name: registered_mail_resources registered_mail_resources_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.registered_mail_resources
    ADD CONSTRAINT registered_mail_resources_pkey PRIMARY KEY (id);


--
-- Name: registered_mail_resources registered_mail_resources_unique_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.registered_mail_resources
    ADD CONSTRAINT registered_mail_resources_unique_key UNIQUE (res_id);


--
-- Name: res_attachments res_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.res_attachments
    ADD CONSTRAINT res_attachments_pkey PRIMARY KEY (res_id);


--
-- Name: res_letterbox res_letterbox_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.res_letterbox
    ADD CONSTRAINT res_letterbox_pkey PRIMARY KEY (res_id);


--
-- Name: resource_contacts resource_contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_contacts
    ADD CONSTRAINT resource_contacts_pkey PRIMARY KEY (id);


--
-- Name: resources_folders resources_folders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resources_folders
    ADD CONSTRAINT resources_folders_pkey PRIMARY KEY (id);


--
-- Name: resources_folders resources_folders_unique_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resources_folders
    ADD CONSTRAINT resources_folders_unique_key UNIQUE (folder_id, res_id);


--
-- Name: resources_tags resources_tags_id_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resources_tags
    ADD CONSTRAINT resources_tags_id_pkey PRIMARY KEY (id);


--
-- Name: resources_tags resources_tags_unique_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resources_tags
    ADD CONSTRAINT resources_tags_unique_key UNIQUE (res_id, tag_id);


--
-- Name: difflist_roles roles_id_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.difflist_roles
    ADD CONSTRAINT roles_id_pkey PRIMARY KEY (id);


--
-- Name: search_templates search_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.search_templates
    ADD CONSTRAINT search_templates_pkey PRIMARY KEY (id);


--
-- Name: security security_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.security
    ADD CONSTRAINT security_pkey PRIMARY KEY (security_id);


--
-- Name: shipping_templates shipping_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shipping_templates
    ADD CONSTRAINT shipping_templates_pkey PRIMARY KEY (id);


--
-- Name: shippings shippings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shippings
    ADD CONSTRAINT shippings_pkey PRIMARY KEY (id);


--
-- Name: status_images status_images_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.status_images
    ADD CONSTRAINT status_images_pkey PRIMARY KEY (id);


--
-- Name: status status_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.status
    ADD CONSTRAINT status_pkey PRIMARY KEY (id);


--
-- Name: tags tags_id_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_id_pkey PRIMARY KEY (id);


--
-- Name: templates_association templates_association_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.templates_association
    ADD CONSTRAINT templates_association_pkey PRIMARY KEY (id);


--
-- Name: templates templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.templates
    ADD CONSTRAINT templates_pkey PRIMARY KEY (template_id);


--
-- Name: tiles tiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tiles
    ADD CONSTRAINT tiles_pkey PRIMARY KEY (id);


--
-- Name: user_signatures user_signatures_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_signatures
    ADD CONSTRAINT user_signatures_pkey PRIMARY KEY (id);


--
-- Name: usergroup_content usergroup_content_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usergroup_content
    ADD CONSTRAINT usergroup_content_pkey PRIMARY KEY (user_id, group_id);


--
-- Name: usergroups usergroups_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usergroups
    ADD CONSTRAINT usergroups_id_key UNIQUE (id);


--
-- Name: usergroups usergroups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usergroups
    ADD CONSTRAINT usergroups_pkey PRIMARY KEY (group_id);


--
-- Name: usergroups_services usergroups_services_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usergroups_services
    ADD CONSTRAINT usergroups_services_pkey PRIMARY KEY (group_id, service_id);


--
-- Name: users_baskets_preferences users_baskets_preferences_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users_baskets_preferences
    ADD CONSTRAINT users_baskets_preferences_key UNIQUE (user_serial_id, group_serial_id, basket_id);


--
-- Name: users_baskets_preferences users_baskets_preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users_baskets_preferences
    ADD CONSTRAINT users_baskets_preferences_pkey PRIMARY KEY (id);


--
-- Name: users_entities users_entities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users_entities
    ADD CONSTRAINT users_entities_pkey PRIMARY KEY (user_id, entity_id);


--
-- Name: users_followed_resources users_followed_resources_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users_followed_resources
    ADD CONSTRAINT users_followed_resources_pkey PRIMARY KEY (id);


--
-- Name: users users_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_id_key UNIQUE (id);


--
-- Name: users_pinned_folders users_pinned_folders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users_pinned_folders
    ADD CONSTRAINT users_pinned_folders_pkey PRIMARY KEY (id);


--
-- Name: users_pinned_folders users_pinned_folders_unique_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users_pinned_folders
    ADD CONSTRAINT users_pinned_folders_unique_key UNIQUE (folder_id, user_id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (user_id);


--
-- Name: alt_identifier_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX alt_identifier_idx ON public.res_letterbox USING btree (alt_identifier);


--
-- Name: attachment_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX attachment_type_idx ON public.res_attachments USING btree (attachment_type);


--
-- Name: category_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX category_id_idx ON public.res_letterbox USING btree (category_id);


--
-- Name: company_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX company_idx ON public.contacts USING btree (company);


--
-- Name: description_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX description_idx ON public.doctypes USING btree (description);


--
-- Name: dest_user_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX dest_user_idx ON public.res_letterbox USING btree (dest_user);


--
-- Name: destination_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX destination_idx ON public.res_letterbox USING btree (destination);


--
-- Name: doc_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX doc_date_idx ON public.res_letterbox USING btree (doc_date);


--
-- Name: docserver_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX docserver_id_idx ON public.res_attachments USING btree (docserver_id);


--
-- Name: doctypes_first_level_label_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX doctypes_first_level_label_idx ON public.doctypes_first_level USING btree (doctypes_first_level_label);


--
-- Name: doctypes_second_level_label_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX doctypes_second_level_label_idx ON public.doctypes_second_level USING btree (doctypes_second_level_label);


--
-- Name: entity_folder_import_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX entity_folder_import_idx ON public.entities USING btree (folder_import);


--
-- Name: entity_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX entity_id_idx ON public.entities USING btree (entity_id);


--
-- Name: entity_label_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX entity_label_idx ON public.entities USING btree (entity_label);


--
-- Name: event_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX event_type_idx ON public.history USING btree (event_type);


--
-- Name: firstname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX firstname_idx ON public.contacts USING btree (firstname);


--
-- Name: folder_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX folder_id_idx ON public.resources_folders USING btree (folder_id);


--
-- Name: groupbasket_redirect_action_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX groupbasket_redirect_action_id_idx ON public.groupbasket_redirect USING btree (action_id);


--
-- Name: groupbasket_redirect_basket_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX groupbasket_redirect_basket_id_idx ON public.groupbasket_redirect USING btree (basket_id);


--
-- Name: groupbasket_redirect_entity_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX groupbasket_redirect_entity_id_idx ON public.groupbasket_redirect USING btree (entity_id);


--
-- Name: groupbasket_redirect_group_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX groupbasket_redirect_group_id_idx ON public.groupbasket_redirect USING btree (group_id);


--
-- Name: identifier_attachments_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX identifier_attachments_idx ON public.res_attachments USING btree (identifier);


--
-- Name: identifier_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX identifier_idx ON public.notes USING btree (identifier);


--
-- Name: initiator_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX initiator_idx ON public.res_letterbox USING btree (initiator);


--
-- Name: item_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX item_id_idx ON public.listinstance USING btree (item_id);


--
-- Name: item_mode_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX item_mode_idx ON public.listinstance USING btree (item_mode);


--
-- Name: item_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX item_type_idx ON public.listinstance USING btree (item_type);


--
-- Name: lastname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX lastname_idx ON public.contacts USING btree (lastname);


--
-- Name: lastname_users_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX lastname_users_idx ON public.users USING btree (lastname);


--
-- Name: listinstance_difflist_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX listinstance_difflist_type_idx ON public.listinstance USING btree (difflist_type);


--
-- Name: listinstance_history_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX listinstance_history_id_idx ON public.listinstance_history_details USING btree (listinstance_history_id);


--
-- Name: notes_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notes_user_id_idx ON public.notes USING btree (user_id);


--
-- Name: parent_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX parent_id_idx ON public.folders USING btree (parent_id);


--
-- Name: record_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX record_id_idx ON public.history USING btree (record_id);


--
-- Name: res_att_external_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX res_att_external_id_idx ON public.res_attachments USING btree (external_id);


--
-- Name: res_barcode_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX res_barcode_idx ON public.res_letterbox USING btree (barcode);


--
-- Name: res_departure_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX res_departure_date_idx ON public.res_letterbox USING btree (departure_date);


--
-- Name: res_id_folders_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX res_id_folders_idx ON public.resources_folders USING btree (res_id);


--
-- Name: res_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX res_id_idx ON public.res_attachments USING btree (res_id);


--
-- Name: res_id_listinstance_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX res_id_listinstance_idx ON public.listinstance USING btree (res_id);


--
-- Name: res_id_master_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX res_id_master_idx ON public.res_attachments USING btree (res_id_master);


--
-- Name: res_letterbox_docserver_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX res_letterbox_docserver_id_idx ON public.res_letterbox USING btree (docserver_id);


--
-- Name: res_letterbox_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX res_letterbox_filename_idx ON public.res_letterbox USING btree (filename);


--
-- Name: resource_contacts_res_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX resource_contacts_res_id_idx ON public.resource_contacts USING btree (res_id);


--
-- Name: sequence_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sequence_idx ON public.listinstance USING btree (sequence);


--
-- Name: status_attachments_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX status_attachments_idx ON public.res_attachments USING btree (status);


--
-- Name: status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX status_idx ON public.res_letterbox USING btree (status);


--
-- Name: table_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX table_name_idx ON public.history USING btree (table_name);


--
-- Name: type_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX type_id_idx ON public.res_letterbox USING btree (type_id);


--
-- Name: typist_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX typist_idx ON public.res_letterbox USING btree (typist);


--
-- Name: user_id_folders_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX user_id_folders_idx ON public.folders USING btree (user_id);


--
-- Name: user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX user_id_idx ON public.history USING btree (user_id);


--
-- Name: user_id_res_mark_as_read_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX user_id_res_mark_as_read_idx ON public.res_mark_as_read USING btree (user_id);


--
-- PostgreSQL database dump complete
--

\unrestrict xVQ7DAGQsYbZEzFbgHJH54nOao5rbBkCPYqdUcgDieBxsLDoOeHPCmQrhcgcInZ

