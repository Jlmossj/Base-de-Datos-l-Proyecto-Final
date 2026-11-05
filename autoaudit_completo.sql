--
-- PostgreSQL database dump
--

\restrict kaSrdY25ww9OY8DD6bMS2OULekcrGRUbt3flzidHcjww6hLzEOcwsx7nbGBXmky

-- Dumped from database version 18.6
-- Dumped by pg_dump version 18.6

-- Started on 2026-10-29 13:57:44

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
-- TOC entry 243 (class 1255 OID 16855)
-- Name: fn_autoaudit_registrar(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_autoaudit_registrar() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_antes JSONB;
    v_despues JSONB;
    v_clave TEXT;
    v_id_config INT;
    v_estacion INT;
    v_usuario TEXT := current_user;
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_antes := '{}'::jsonb;
        v_despues := to_jsonb(NEW);
    ELSIF TG_OP = 'DELETE' THEN
        v_antes := to_jsonb(OLD);
        v_despues := '{}'::jsonb;
    ELSE
        v_antes := to_jsonb(OLD);
        v_despues := to_jsonb(NEW);
    END IF;
    FOR v_clave IN SELECT jsonb_object_keys(CASE WHEN TG_OP = 'DELETE' THEN v_antes ELSE v_despues END)
    LOOP
        IF TG_OP = 'UPDATE' AND (v_antes -> v_clave) IS NOT DISTINCT FROM (v_despues -> v_clave) THEN
            CONTINUE;
        END IF;
        SELECT co.id_configuracion INTO v_id_config
        FROM tablas_auditadas ta
        JOIN columnas_auditadas ca ON ca.id_tabla = ta.id_tabla
        JOIN configuracion_auditoria co ON co.id_columna = ca.id_columna
        JOIN eventos e ON e.id_evento = co.id_evento
        WHERE ta.esquema = TG_TABLE_SCHEMA AND ta.nombre_tabla = TG_TABLE_NAME
          AND ta.activa AND ca.activa AND co.activa
          AND ca.nombre_columna = v_clave AND e.nombre_evento = TG_OP
          AND ((TG_OP = 'INSERT' AND co.auditar_insert)
            OR (TG_OP = 'UPDATE' AND co.auditar_update)
            OR (TG_OP = 'DELETE' AND co.auditar_delete))
        LIMIT 1;
        IF v_id_config IS NULL THEN CONTINUE; END IF;
        INSERT INTO estaciones_trabajo(ip) VALUES (COALESCE(inet_client_addr()::text, 'local'))
        ON CONFLICT (ip) DO NOTHING;
        SELECT id_estacion INTO v_estacion FROM estaciones_trabajo
        WHERE ip = COALESCE(inet_client_addr()::text, 'local');
        INSERT INTO usuarios_auditados(user_auditado,nombre,puesto)
        VALUES(v_usuario,v_usuario,'usuario de sistema') ON CONFLICT(user_auditado) DO NOTHING;
        INSERT INTO bitacora(dato_anterior,dato_nuevo,id_estacion,user_auditado,tabla_modificada,columna_modificada,accion_realizada,id_configuracion)
        VALUES(CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE v_antes ->> v_clave END,
               CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE v_despues ->> v_clave END,
               v_estacion,v_usuario,TG_TABLE_NAME,v_clave,TG_OP,v_id_config);
    END LOOP;
    RETURN NULL;
END;
$$;


ALTER FUNCTION public.fn_autoaudit_registrar() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 242 (class 1259 OID 16824)
-- Name: bitacora; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bitacora (
    id_bitacora bigint NOT NULL,
    dato_anterior text,
    dato_nuevo text,
    id_estacion integer NOT NULL,
    fecha_hora timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    user_auditado character varying(100) NOT NULL,
    tabla_modificada character varying(100) NOT NULL,
    columna_modificada character varying(100) NOT NULL,
    accion_realizada character varying(10) NOT NULL,
    id_configuracion integer
);


ALTER TABLE public.bitacora OWNER TO postgres;

--
-- TOC entry 241 (class 1259 OID 16823)
-- Name: bitacora_id_bitacora_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.bitacora_id_bitacora_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.bitacora_id_bitacora_seq OWNER TO postgres;

--
-- TOC entry 5099 (class 0 OID 0)
-- Dependencies: 241
-- Name: bitacora_id_bitacora_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.bitacora_id_bitacora_seq OWNED BY public.bitacora.id_bitacora;


--
-- TOC entry 229 (class 1259 OID 16705)
-- Name: calificaciones; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.calificaciones (
    id_calificacion integer NOT NULL,
    carnet character varying(12) NOT NULL,
    id_curso integer NOT NULL,
    cod_docente integer NOT NULL,
    nota numeric(5,2) NOT NULL
);


ALTER TABLE public.calificaciones OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 16704)
-- Name: calificaciones_id_calificacion_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.calificaciones_id_calificacion_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.calificaciones_id_calificacion_seq OWNER TO postgres;

--
-- TOC entry 5100 (class 0 OID 0)
-- Dependencies: 228
-- Name: calificaciones_id_calificacion_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.calificaciones_id_calificacion_seq OWNED BY public.calificaciones.id_calificacion;


--
-- TOC entry 222 (class 1259 OID 16629)
-- Name: catedraticos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.catedraticos (
    cod_docente integer NOT NULL,
    nombre character varying(30) NOT NULL,
    apellido character varying(30) NOT NULL,
    telefono character varying(8),
    id_facultad integer NOT NULL
);


ALTER TABLE public.catedraticos OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 16628)
-- Name: catedraticos_cod_docente_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.catedraticos_cod_docente_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.catedraticos_cod_docente_seq OWNER TO postgres;

--
-- TOC entry 5101 (class 0 OID 0)
-- Dependencies: 221
-- Name: catedraticos_cod_docente_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.catedraticos_cod_docente_seq OWNED BY public.catedraticos.cod_docente;


--
-- TOC entry 233 (class 1259 OID 16746)
-- Name: columnas_auditadas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.columnas_auditadas (
    id_columna integer NOT NULL,
    id_tabla integer NOT NULL,
    nombre_columna character varying(63) NOT NULL,
    activa boolean DEFAULT true NOT NULL
);


ALTER TABLE public.columnas_auditadas OWNER TO postgres;

--
-- TOC entry 232 (class 1259 OID 16745)
-- Name: columnas_auditadas_id_columna_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.columnas_auditadas_id_columna_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.columnas_auditadas_id_columna_seq OWNER TO postgres;

--
-- TOC entry 5102 (class 0 OID 0)
-- Dependencies: 232
-- Name: columnas_auditadas_id_columna_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.columnas_auditadas_id_columna_seq OWNED BY public.columnas_auditadas.id_columna;


--
-- TOC entry 237 (class 1259 OID 16776)
-- Name: configuracion_auditoria; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.configuracion_auditoria (
    id_configuracion integer NOT NULL,
    id_columna integer NOT NULL,
    id_evento integer NOT NULL,
    auditar_insert boolean DEFAULT false NOT NULL,
    auditar_update boolean DEFAULT false NOT NULL,
    auditar_delete boolean DEFAULT false NOT NULL,
    activa boolean DEFAULT true NOT NULL
);


ALTER TABLE public.configuracion_auditoria OWNER TO postgres;

--
-- TOC entry 236 (class 1259 OID 16775)
-- Name: configuracion_auditoria_id_configuracion_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.configuracion_auditoria_id_configuracion_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.configuracion_auditoria_id_configuracion_seq OWNER TO postgres;

--
-- TOC entry 5103 (class 0 OID 0)
-- Dependencies: 236
-- Name: configuracion_auditoria_id_configuracion_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.configuracion_auditoria_id_configuracion_seq OWNED BY public.configuracion_auditoria.id_configuracion;


--
-- TOC entry 225 (class 1259 OID 16662)
-- Name: cursos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cursos (
    id_curso integer NOT NULL,
    nombre character varying(50) NOT NULL,
    id_facultad integer NOT NULL,
    cod_docente integer NOT NULL
);


ALTER TABLE public.cursos OWNER TO postgres;

--
-- TOC entry 224 (class 1259 OID 16661)
-- Name: cursos_id_curso_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.cursos_id_curso_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.cursos_id_curso_seq OWNER TO postgres;

--
-- TOC entry 5104 (class 0 OID 0)
-- Dependencies: 224
-- Name: cursos_id_curso_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.cursos_id_curso_seq OWNED BY public.cursos.id_curso;


--
-- TOC entry 239 (class 1259 OID 16806)
-- Name: estaciones_trabajo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.estaciones_trabajo (
    id_estacion integer NOT NULL,
    ip character varying(45) NOT NULL
);


ALTER TABLE public.estaciones_trabajo OWNER TO postgres;

--
-- TOC entry 238 (class 1259 OID 16805)
-- Name: estaciones_trabajo_id_estacion_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.estaciones_trabajo_id_estacion_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.estaciones_trabajo_id_estacion_seq OWNER TO postgres;

--
-- TOC entry 5105 (class 0 OID 0)
-- Dependencies: 238
-- Name: estaciones_trabajo_id_estacion_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.estaciones_trabajo_id_estacion_seq OWNED BY public.estaciones_trabajo.id_estacion;


--
-- TOC entry 223 (class 1259 OID 16644)
-- Name: estudiantes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.estudiantes (
    carnet character varying(12) NOT NULL,
    nombre character varying(20) NOT NULL,
    apellido character varying(20) NOT NULL,
    correo character varying(50) NOT NULL,
    id_facultad integer NOT NULL
);


ALTER TABLE public.estudiantes OWNER TO postgres;

--
-- TOC entry 235 (class 1259 OID 16765)
-- Name: eventos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.eventos (
    id_evento integer NOT NULL,
    nombre_evento character varying(20) NOT NULL
);


ALTER TABLE public.eventos OWNER TO postgres;

--
-- TOC entry 234 (class 1259 OID 16764)
-- Name: eventos_id_evento_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.eventos_id_evento_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.eventos_id_evento_seq OWNER TO postgres;

--
-- TOC entry 5106 (class 0 OID 0)
-- Dependencies: 234
-- Name: eventos_id_evento_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.eventos_id_evento_seq OWNED BY public.eventos.id_evento;


--
-- TOC entry 220 (class 1259 OID 16620)
-- Name: facultad; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.facultad (
    id_facultad integer NOT NULL,
    nombre character varying(50) NOT NULL
);


ALTER TABLE public.facultad OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 16619)
-- Name: facultad_id_facultad_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.facultad_id_facultad_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.facultad_id_facultad_seq OWNER TO postgres;

--
-- TOC entry 5107 (class 0 OID 0)
-- Dependencies: 219
-- Name: facultad_id_facultad_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.facultad_id_facultad_seq OWNED BY public.facultad.id_facultad;


--
-- TOC entry 227 (class 1259 OID 16685)
-- Name: inscripcion; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.inscripcion (
    id_inscripcion integer NOT NULL,
    carnet character varying(12) NOT NULL,
    id_curso integer NOT NULL
);


ALTER TABLE public.inscripcion OWNER TO postgres;

--
-- TOC entry 226 (class 1259 OID 16684)
-- Name: inscripcion_id_inscripcion_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.inscripcion_id_inscripcion_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.inscripcion_id_inscripcion_seq OWNER TO postgres;

--
-- TOC entry 5108 (class 0 OID 0)
-- Dependencies: 226
-- Name: inscripcion_id_inscripcion_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.inscripcion_id_inscripcion_seq OWNED BY public.inscripcion.id_inscripcion;


--
-- TOC entry 231 (class 1259 OID 16732)
-- Name: tablas_auditadas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tablas_auditadas (
    id_tabla integer NOT NULL,
    esquema character varying(63) NOT NULL,
    nombre_tabla character varying(63) NOT NULL,
    activa boolean DEFAULT true NOT NULL
);


ALTER TABLE public.tablas_auditadas OWNER TO postgres;

--
-- TOC entry 230 (class 1259 OID 16731)
-- Name: tablas_auditadas_id_tabla_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tablas_auditadas_id_tabla_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.tablas_auditadas_id_tabla_seq OWNER TO postgres;

--
-- TOC entry 5109 (class 0 OID 0)
-- Dependencies: 230
-- Name: tablas_auditadas_id_tabla_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tablas_auditadas_id_tabla_seq OWNED BY public.tablas_auditadas.id_tabla;


--
-- TOC entry 240 (class 1259 OID 16816)
-- Name: usuarios_auditados; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.usuarios_auditados (
    user_auditado character varying(100) NOT NULL,
    nombre character varying(100) NOT NULL,
    puesto character varying(50)
);


ALTER TABLE public.usuarios_auditados OWNER TO postgres;

--
-- TOC entry 4884 (class 2604 OID 16827)
-- Name: bitacora id_bitacora; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bitacora ALTER COLUMN id_bitacora SET DEFAULT nextval('public.bitacora_id_bitacora_seq'::regclass);


--
-- TOC entry 4872 (class 2604 OID 16708)
-- Name: calificaciones id_calificacion; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.calificaciones ALTER COLUMN id_calificacion SET DEFAULT nextval('public.calificaciones_id_calificacion_seq'::regclass);


--
-- TOC entry 4869 (class 2604 OID 16632)
-- Name: catedraticos cod_docente; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.catedraticos ALTER COLUMN cod_docente SET DEFAULT nextval('public.catedraticos_cod_docente_seq'::regclass);


--
-- TOC entry 4875 (class 2604 OID 16749)
-- Name: columnas_auditadas id_columna; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.columnas_auditadas ALTER COLUMN id_columna SET DEFAULT nextval('public.columnas_auditadas_id_columna_seq'::regclass);


--
-- TOC entry 4878 (class 2604 OID 16779)
-- Name: configuracion_auditoria id_configuracion; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.configuracion_auditoria ALTER COLUMN id_configuracion SET DEFAULT nextval('public.configuracion_auditoria_id_configuracion_seq'::regclass);


--
-- TOC entry 4870 (class 2604 OID 16665)
-- Name: cursos id_curso; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cursos ALTER COLUMN id_curso SET DEFAULT nextval('public.cursos_id_curso_seq'::regclass);


--
-- TOC entry 4883 (class 2604 OID 16809)
-- Name: estaciones_trabajo id_estacion; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estaciones_trabajo ALTER COLUMN id_estacion SET DEFAULT nextval('public.estaciones_trabajo_id_estacion_seq'::regclass);


--
-- TOC entry 4877 (class 2604 OID 16768)
-- Name: eventos id_evento; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.eventos ALTER COLUMN id_evento SET DEFAULT nextval('public.eventos_id_evento_seq'::regclass);


--
-- TOC entry 4868 (class 2604 OID 16623)
-- Name: facultad id_facultad; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.facultad ALTER COLUMN id_facultad SET DEFAULT nextval('public.facultad_id_facultad_seq'::regclass);


--
-- TOC entry 4871 (class 2604 OID 16688)
-- Name: inscripcion id_inscripcion; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inscripcion ALTER COLUMN id_inscripcion SET DEFAULT nextval('public.inscripcion_id_inscripcion_seq'::regclass);


--
-- TOC entry 4873 (class 2604 OID 16735)
-- Name: tablas_auditadas id_tabla; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tablas_auditadas ALTER COLUMN id_tabla SET DEFAULT nextval('public.tablas_auditadas_id_tabla_seq'::regclass);


--
-- TOC entry 4925 (class 2606 OID 16839)
-- Name: bitacora bitacora_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bitacora
    ADD CONSTRAINT bitacora_pkey PRIMARY KEY (id_bitacora);


--
-- TOC entry 4901 (class 2606 OID 16715)
-- Name: calificaciones calificaciones_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.calificaciones
    ADD CONSTRAINT calificaciones_pkey PRIMARY KEY (id_calificacion);


--
-- TOC entry 4889 (class 2606 OID 16638)
-- Name: catedraticos catedraticos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.catedraticos
    ADD CONSTRAINT catedraticos_pkey PRIMARY KEY (cod_docente);


--
-- TOC entry 4907 (class 2606 OID 16758)
-- Name: columnas_auditadas columnas_auditadas_id_tabla_nombre_columna_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.columnas_auditadas
    ADD CONSTRAINT columnas_auditadas_id_tabla_nombre_columna_key UNIQUE (id_tabla, nombre_columna);


--
-- TOC entry 4909 (class 2606 OID 16756)
-- Name: columnas_auditadas columnas_auditadas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.columnas_auditadas
    ADD CONSTRAINT columnas_auditadas_pkey PRIMARY KEY (id_columna);


--
-- TOC entry 4915 (class 2606 OID 16794)
-- Name: configuracion_auditoria configuracion_auditoria_id_columna_id_evento_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.configuracion_auditoria
    ADD CONSTRAINT configuracion_auditoria_id_columna_id_evento_key UNIQUE (id_columna, id_evento);


--
-- TOC entry 4917 (class 2606 OID 16792)
-- Name: configuracion_auditoria configuracion_auditoria_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.configuracion_auditoria
    ADD CONSTRAINT configuracion_auditoria_pkey PRIMARY KEY (id_configuracion);


--
-- TOC entry 4895 (class 2606 OID 16673)
-- Name: cursos cursos_nombre_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cursos
    ADD CONSTRAINT cursos_nombre_key UNIQUE (nombre);


--
-- TOC entry 4897 (class 2606 OID 16671)
-- Name: cursos cursos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cursos
    ADD CONSTRAINT cursos_pkey PRIMARY KEY (id_curso);


--
-- TOC entry 4919 (class 2606 OID 16815)
-- Name: estaciones_trabajo estaciones_trabajo_ip_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estaciones_trabajo
    ADD CONSTRAINT estaciones_trabajo_ip_key UNIQUE (ip);


--
-- TOC entry 4921 (class 2606 OID 16813)
-- Name: estaciones_trabajo estaciones_trabajo_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estaciones_trabajo
    ADD CONSTRAINT estaciones_trabajo_pkey PRIMARY KEY (id_estacion);


--
-- TOC entry 4891 (class 2606 OID 16655)
-- Name: estudiantes estudiantes_correo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estudiantes
    ADD CONSTRAINT estudiantes_correo_key UNIQUE (correo);


--
-- TOC entry 4893 (class 2606 OID 16653)
-- Name: estudiantes estudiantes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estudiantes
    ADD CONSTRAINT estudiantes_pkey PRIMARY KEY (carnet);


--
-- TOC entry 4911 (class 2606 OID 16774)
-- Name: eventos eventos_nombre_evento_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.eventos
    ADD CONSTRAINT eventos_nombre_evento_key UNIQUE (nombre_evento);


--
-- TOC entry 4913 (class 2606 OID 16772)
-- Name: eventos eventos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.eventos
    ADD CONSTRAINT eventos_pkey PRIMARY KEY (id_evento);


--
-- TOC entry 4887 (class 2606 OID 16627)
-- Name: facultad facultad_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.facultad
    ADD CONSTRAINT facultad_pkey PRIMARY KEY (id_facultad);


--
-- TOC entry 4899 (class 2606 OID 16693)
-- Name: inscripcion inscripcion_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inscripcion
    ADD CONSTRAINT inscripcion_pkey PRIMARY KEY (id_inscripcion);


--
-- TOC entry 4903 (class 2606 OID 16744)
-- Name: tablas_auditadas tablas_auditadas_esquema_nombre_tabla_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tablas_auditadas
    ADD CONSTRAINT tablas_auditadas_esquema_nombre_tabla_key UNIQUE (esquema, nombre_tabla);


--
-- TOC entry 4905 (class 2606 OID 16742)
-- Name: tablas_auditadas tablas_auditadas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tablas_auditadas
    ADD CONSTRAINT tablas_auditadas_pkey PRIMARY KEY (id_tabla);


--
-- TOC entry 4923 (class 2606 OID 16822)
-- Name: usuarios_auditados usuarios_auditados_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios_auditados
    ADD CONSTRAINT usuarios_auditados_pkey PRIMARY KEY (user_auditado);


--
-- TOC entry 4946 (class 2620 OID 16861)
-- Name: calificaciones trg_autoaudit_calificaciones; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_autoaudit_calificaciones AFTER INSERT OR DELETE OR UPDATE ON public.calificaciones FOR EACH ROW EXECUTE FUNCTION public.fn_autoaudit_registrar();


--
-- TOC entry 4942 (class 2620 OID 16857)
-- Name: catedraticos trg_autoaudit_catedraticos; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_autoaudit_catedraticos AFTER INSERT OR DELETE OR UPDATE ON public.catedraticos FOR EACH ROW EXECUTE FUNCTION public.fn_autoaudit_registrar();


--
-- TOC entry 4944 (class 2620 OID 16859)
-- Name: cursos trg_autoaudit_cursos; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_autoaudit_cursos AFTER INSERT OR DELETE OR UPDATE ON public.cursos FOR EACH ROW EXECUTE FUNCTION public.fn_autoaudit_registrar();


--
-- TOC entry 4943 (class 2620 OID 16858)
-- Name: estudiantes trg_autoaudit_estudiantes; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_autoaudit_estudiantes AFTER INSERT OR DELETE OR UPDATE ON public.estudiantes FOR EACH ROW EXECUTE FUNCTION public.fn_autoaudit_registrar();


--
-- TOC entry 4941 (class 2620 OID 16856)
-- Name: facultad trg_autoaudit_facultad; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_autoaudit_facultad AFTER INSERT OR DELETE OR UPDATE ON public.facultad FOR EACH ROW EXECUTE FUNCTION public.fn_autoaudit_registrar();


--
-- TOC entry 4945 (class 2620 OID 16860)
-- Name: inscripcion trg_autoaudit_inscripcion; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_autoaudit_inscripcion AFTER INSERT OR DELETE OR UPDATE ON public.inscripcion FOR EACH ROW EXECUTE FUNCTION public.fn_autoaudit_registrar();


--
-- TOC entry 4938 (class 2606 OID 16850)
-- Name: bitacora bitacora_id_configuracion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bitacora
    ADD CONSTRAINT bitacora_id_configuracion_fkey FOREIGN KEY (id_configuracion) REFERENCES public.configuracion_auditoria(id_configuracion);


--
-- TOC entry 4939 (class 2606 OID 16840)
-- Name: bitacora bitacora_id_estacion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bitacora
    ADD CONSTRAINT bitacora_id_estacion_fkey FOREIGN KEY (id_estacion) REFERENCES public.estaciones_trabajo(id_estacion);


--
-- TOC entry 4940 (class 2606 OID 16845)
-- Name: bitacora bitacora_user_auditado_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bitacora
    ADD CONSTRAINT bitacora_user_auditado_fkey FOREIGN KEY (user_auditado) REFERENCES public.usuarios_auditados(user_auditado);


--
-- TOC entry 4932 (class 2606 OID 16716)
-- Name: calificaciones calificaciones_carnet_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.calificaciones
    ADD CONSTRAINT calificaciones_carnet_fkey FOREIGN KEY (carnet) REFERENCES public.estudiantes(carnet);


--
-- TOC entry 4933 (class 2606 OID 16726)
-- Name: calificaciones calificaciones_cod_docente_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.calificaciones
    ADD CONSTRAINT calificaciones_cod_docente_fkey FOREIGN KEY (cod_docente) REFERENCES public.catedraticos(cod_docente);


--
-- TOC entry 4934 (class 2606 OID 16721)
-- Name: calificaciones calificaciones_id_curso_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.calificaciones
    ADD CONSTRAINT calificaciones_id_curso_fkey FOREIGN KEY (id_curso) REFERENCES public.cursos(id_curso);


--
-- TOC entry 4926 (class 2606 OID 16639)
-- Name: catedraticos catedraticos_id_facultad_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.catedraticos
    ADD CONSTRAINT catedraticos_id_facultad_fkey FOREIGN KEY (id_facultad) REFERENCES public.facultad(id_facultad);


--
-- TOC entry 4935 (class 2606 OID 16759)
-- Name: columnas_auditadas columnas_auditadas_id_tabla_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.columnas_auditadas
    ADD CONSTRAINT columnas_auditadas_id_tabla_fkey FOREIGN KEY (id_tabla) REFERENCES public.tablas_auditadas(id_tabla);


--
-- TOC entry 4936 (class 2606 OID 16795)
-- Name: configuracion_auditoria configuracion_auditoria_id_columna_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.configuracion_auditoria
    ADD CONSTRAINT configuracion_auditoria_id_columna_fkey FOREIGN KEY (id_columna) REFERENCES public.columnas_auditadas(id_columna);


--
-- TOC entry 4937 (class 2606 OID 16800)
-- Name: configuracion_auditoria configuracion_auditoria_id_evento_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.configuracion_auditoria
    ADD CONSTRAINT configuracion_auditoria_id_evento_fkey FOREIGN KEY (id_evento) REFERENCES public.eventos(id_evento);


--
-- TOC entry 4928 (class 2606 OID 16679)
-- Name: cursos cursos_cod_docente_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cursos
    ADD CONSTRAINT cursos_cod_docente_fkey FOREIGN KEY (cod_docente) REFERENCES public.catedraticos(cod_docente);


--
-- TOC entry 4929 (class 2606 OID 16674)
-- Name: cursos cursos_id_facultad_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cursos
    ADD CONSTRAINT cursos_id_facultad_fkey FOREIGN KEY (id_facultad) REFERENCES public.facultad(id_facultad);


--
-- TOC entry 4927 (class 2606 OID 16656)
-- Name: estudiantes estudiantes_id_facultad_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estudiantes
    ADD CONSTRAINT estudiantes_id_facultad_fkey FOREIGN KEY (id_facultad) REFERENCES public.facultad(id_facultad);


--
-- TOC entry 4930 (class 2606 OID 16694)
-- Name: inscripcion inscripcion_carnet_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inscripcion
    ADD CONSTRAINT inscripcion_carnet_fkey FOREIGN KEY (carnet) REFERENCES public.estudiantes(carnet);


--
-- TOC entry 4931 (class 2606 OID 16699)
-- Name: inscripcion inscripcion_id_curso_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inscripcion
    ADD CONSTRAINT inscripcion_id_curso_fkey FOREIGN KEY (id_curso) REFERENCES public.cursos(id_curso);


-- Completed on 2026-10-29 13:57:45

--
-- PostgreSQL database dump complete
--

\unrestrict kaSrdY25ww9OY8DD6bMS2OULekcrGRUbt3flzidHcjww6hLzEOcwsx7nbGBXmky

