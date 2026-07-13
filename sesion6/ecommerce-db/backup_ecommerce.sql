--
-- PostgreSQL database dump
--

\restrict kRTFjiDNRYK0gUCyZbHWlbJsJUHnYpQKPOgD5wuz4ZMjTdJ9IPMEQgd6NIAKgdx

-- Dumped from database version 16.14
-- Dumped by pg_dump version 16.14 (Ubuntu 16.14-0ubuntu0.24.04.1)

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

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: categories; Type: TABLE; Schema: public; Owner: ecommerce_user
--

CREATE TABLE public.categories (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    description text
);


ALTER TABLE public.categories OWNER TO ecommerce_user;

--
-- Name: categories_id_seq; Type: SEQUENCE; Schema: public; Owner: ecommerce_user
--

CREATE SEQUENCE public.categories_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.categories_id_seq OWNER TO ecommerce_user;

--
-- Name: categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ecommerce_user
--

ALTER SEQUENCE public.categories_id_seq OWNED BY public.categories.id;


--
-- Name: customers; Type: TABLE; Schema: public; Owner: ecommerce_user
--

CREATE TABLE public.customers (
    id integer NOT NULL,
    first_name character varying(100) NOT NULL,
    last_name character varying(100) NOT NULL,
    email character varying(150) NOT NULL,
    phone character varying(30),
    city character varying(100),
    country character varying(100),
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.customers OWNER TO ecommerce_user;

--
-- Name: customers_id_seq; Type: SEQUENCE; Schema: public; Owner: ecommerce_user
--

CREATE SEQUENCE public.customers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.customers_id_seq OWNER TO ecommerce_user;

--
-- Name: customers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ecommerce_user
--

ALTER SEQUENCE public.customers_id_seq OWNED BY public.customers.id;


--
-- Name: order_items; Type: TABLE; Schema: public; Owner: ecommerce_user
--

CREATE TABLE public.order_items (
    id integer NOT NULL,
    order_id integer NOT NULL,
    product_id integer NOT NULL,
    quantity integer NOT NULL,
    unit_price numeric(10,2) NOT NULL,
    CONSTRAINT order_items_quantity_check CHECK ((quantity > 0))
);


ALTER TABLE public.order_items OWNER TO ecommerce_user;

--
-- Name: order_items_id_seq; Type: SEQUENCE; Schema: public; Owner: ecommerce_user
--

CREATE SEQUENCE public.order_items_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.order_items_id_seq OWNER TO ecommerce_user;

--
-- Name: order_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ecommerce_user
--

ALTER SEQUENCE public.order_items_id_seq OWNED BY public.order_items.id;


--
-- Name: orders; Type: TABLE; Schema: public; Owner: ecommerce_user
--

CREATE TABLE public.orders (
    id integer NOT NULL,
    customer_id integer NOT NULL,
    status character varying(20) DEFAULT 'pending'::character varying NOT NULL,
    order_date timestamp without time zone DEFAULT now() NOT NULL,
    total numeric(10,2) DEFAULT 0 NOT NULL,
    CONSTRAINT orders_status_check CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'paid'::character varying, 'shipped'::character varying, 'delivered'::character varying, 'cancelled'::character varying])::text[])))
);


ALTER TABLE public.orders OWNER TO ecommerce_user;

--
-- Name: orders_id_seq; Type: SEQUENCE; Schema: public; Owner: ecommerce_user
--

CREATE SEQUENCE public.orders_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.orders_id_seq OWNER TO ecommerce_user;

--
-- Name: orders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ecommerce_user
--

ALTER SEQUENCE public.orders_id_seq OWNED BY public.orders.id;


--
-- Name: products; Type: TABLE; Schema: public; Owner: ecommerce_user
--

CREATE TABLE public.products (
    id integer NOT NULL,
    sku character varying(50) NOT NULL,
    name character varying(200) NOT NULL,
    description text,
    category_id integer,
    price numeric(10,2) NOT NULL,
    stock integer DEFAULT 0 NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    CONSTRAINT products_price_check CHECK ((price >= (0)::numeric)),
    CONSTRAINT products_stock_check CHECK ((stock >= 0))
);


ALTER TABLE public.products OWNER TO ecommerce_user;

--
-- Name: products_id_seq; Type: SEQUENCE; Schema: public; Owner: ecommerce_user
--

CREATE SEQUENCE public.products_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.products_id_seq OWNER TO ecommerce_user;

--
-- Name: products_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ecommerce_user
--

ALTER SEQUENCE public.products_id_seq OWNED BY public.products.id;


--
-- Name: categories id; Type: DEFAULT; Schema: public; Owner: ecommerce_user
--

ALTER TABLE ONLY public.categories ALTER COLUMN id SET DEFAULT nextval('public.categories_id_seq'::regclass);


--
-- Name: customers id; Type: DEFAULT; Schema: public; Owner: ecommerce_user
--

ALTER TABLE ONLY public.customers ALTER COLUMN id SET DEFAULT nextval('public.customers_id_seq'::regclass);


--
-- Name: order_items id; Type: DEFAULT; Schema: public; Owner: ecommerce_user
--

ALTER TABLE ONLY public.order_items ALTER COLUMN id SET DEFAULT nextval('public.order_items_id_seq'::regclass);


--
-- Name: orders id; Type: DEFAULT; Schema: public; Owner: ecommerce_user
--

ALTER TABLE ONLY public.orders ALTER COLUMN id SET DEFAULT nextval('public.orders_id_seq'::regclass);


--
-- Name: products id; Type: DEFAULT; Schema: public; Owner: ecommerce_user
--

ALTER TABLE ONLY public.products ALTER COLUMN id SET DEFAULT nextval('public.products_id_seq'::regclass);


--
-- Data for Name: categories; Type: TABLE DATA; Schema: public; Owner: ecommerce_user
--

COPY public.categories (id, name, description) FROM stdin;
1	Electronics	Phones, laptops, gadgets and accessories
2	Books	Fiction, non-fiction and technical books
3	Clothing	Apparel for men, women and children
4	Home & Garden	Furniture, decor and gardening tools
5	Sports	Sporting goods and outdoor equipment
\.


--
-- Data for Name: customers; Type: TABLE DATA; Schema: public; Owner: ecommerce_user
--

COPY public.customers (id, first_name, last_name, email, phone, city, country, created_at) FROM stdin;
1	Maria	Garcia	maria.garcia@example.com	+34600111222	Madrid	Spain	2026-07-12 18:17:46.615177
2	John	Smith	john.smith@example.com	+44700222333	London	United Kingdom	2026-07-12 18:17:46.615177
3	Sophie	Martin	sophie.martin@example.com	+33611333444	Paris	France	2026-07-12 18:17:46.615177
4	Luca	Rossi	luca.rossi@example.com	+39320444555	Rome	Italy	2026-07-12 18:17:46.615177
5	Anna	Müller	anna.muller@example.com	+49150555666	Berlin	Germany	2026-07-12 18:17:46.615177
6	Carlos	Fernandez	carlos.fernandez@example.com	+34611666777	Barcelona	Spain	2026-07-12 18:17:46.615177
7	Emma	Johnson	emma.johnson@example.com	+1202777888	New York	USA	2026-07-12 18:17:46.615177
8	Lucas	Silva	lucas.silva@example.com	+5511988999000	Sao Paulo	Brazil	2026-07-12 18:17:46.615177
9	Mia	Wagner	mia.wagner@example.com	+49160888999	Munich	Germany	2026-07-12 18:17:46.615177
10	Noah	Brown	noah.brown@example.com	+1305999000	Miami	USA	2026-07-12 18:17:46.615177
\.


--
-- Data for Name: order_items; Type: TABLE DATA; Schema: public; Owner: ecommerce_user
--

COPY public.order_items (id, order_id, product_id, quantity, unit_price) FROM stdin;
1	1	1	1	19.99
2	1	2	1	79.99
3	2	3	1	349.00
4	3	6	1	34.90
5	3	7	1	29.95
6	3	8	1	14.50
7	4	9	2	12.00
8	4	10	1	59.99
9	4	11	1	89.00
10	5	12	1	149.00
11	5	13	1	24.99
12	5	14	1	22.50
13	6	15	1	18.75
14	6	16	1	119.00
15	6	17	1	45.00
16	7	5	1	599.00
17	7	4	1	129.50
18	7	9	1	12.00
19	8	1	2	19.99
20	9	7	1	29.95
21	9	14	1	22.50
22	10	15	1	18.75
23	10	16	1	119.00
24	10	9	2	12.00
\.


--
-- Data for Name: orders; Type: TABLE DATA; Schema: public; Owner: ecommerce_user
--

COPY public.orders (id, customer_id, status, order_date, total) FROM stdin;
1	1	delivered	2026-06-22 18:17:46.619925	99.98
2	2	shipped	2026-07-02 18:17:46.624376	349.00
3	3	delivered	2026-06-07 18:17:46.627392	79.35
4	4	paid	2026-07-09 18:17:46.629937	161.99
5	5	pending	2026-07-11 18:17:46.63305	196.48
6	6	delivered	2026-05-23 18:17:46.63605	182.75
7	7	cancelled	2026-06-27 18:17:46.638851	729.50
8	8	delivered	2026-07-05 18:17:46.641631	39.99
9	9	shipped	2026-07-08 18:17:46.644396	51.95
10	10	pending	2026-07-12 18:17:46.647141	163.75
\.


--
-- Data for Name: products; Type: TABLE DATA; Schema: public; Owner: ecommerce_user
--

COPY public.products (id, sku, name, description, category_id, price, stock, created_at) FROM stdin;
1	ELEC-001	Wireless Mouse	Ergonomic 2.4GHz wireless mouse	1	19.99	150	2026-07-12 18:17:46.617165
2	ELEC-002	Mechanical Keyboard	RGB backlit mechanical keyboard	1	79.99	80	2026-07-12 18:17:46.617165
3	ELEC-003	27" 4K Monitor	IPS 4K UHD monitor with HDR	1	349.00	25	2026-07-12 18:17:46.617165
4	ELEC-004	Noise Cancelling Headphones	Over-ear Bluetooth headphones	1	129.50	60	2026-07-12 18:17:46.617165
5	ELEC-005	Smartphone X12	128GB, 6.5" AMOLED display	1	599.00	40	2026-07-12 18:17:46.617165
6	BOOK-001	The Pragmatic Programmer	Software craftsmanship classic	2	34.90	100	2026-07-12 18:17:46.617165
7	BOOK-002	Clean Code	A Handbook of Agile Software Craftsmanship	2	29.95	75	2026-07-12 18:17:46.617165
8	BOOK-003	Dune	Sci-fi novel by Frank Herbert	2	14.50	200	2026-07-12 18:17:46.617165
9	CLOT-001	Cotton T-Shirt	Unisex 100% cotton t-shirt	3	12.00	300	2026-07-12 18:17:46.617165
10	CLOT-002	Denim Jacket	Classic blue denim jacket	3	59.99	90	2026-07-12 18:17:46.617165
11	CLOT-003	Running Shoes	Lightweight breathable running shoes	3	89.00	120	2026-07-12 18:17:46.617165
12	HOME-001	Office Chair	Ergonomic mesh office chair	4	149.00	35	2026-07-12 18:17:46.617165
13	HOME-002	LED Desk Lamp	Adjustable LED lamp with USB charging	4	24.99	140	2026-07-12 18:17:46.617165
14	HOME-003	Indoor Plant Pot Set	Set of 3 ceramic plant pots	4	22.50	85	2026-07-12 18:17:46.617165
15	SPRT-001	Yoga Mat	Non-slip eco-friendly yoga mat	5	18.75	160	2026-07-12 18:17:46.617165
16	SPRT-002	Adjustable Dumbbells	2x10kg adjustable dumbbell set	5	119.00	30	2026-07-12 18:17:46.617165
17	SPRT-003	Cycling Helmet	Lightweight ventilated cycling helmet	5	45.00	55	2026-07-12 18:17:46.617165
\.


--
-- Name: categories_id_seq; Type: SEQUENCE SET; Schema: public; Owner: ecommerce_user
--

SELECT pg_catalog.setval('public.categories_id_seq', 5, true);


--
-- Name: customers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: ecommerce_user
--

SELECT pg_catalog.setval('public.customers_id_seq', 10, true);


--
-- Name: order_items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: ecommerce_user
--

SELECT pg_catalog.setval('public.order_items_id_seq', 24, true);


--
-- Name: orders_id_seq; Type: SEQUENCE SET; Schema: public; Owner: ecommerce_user
--

SELECT pg_catalog.setval('public.orders_id_seq', 10, true);


--
-- Name: products_id_seq; Type: SEQUENCE SET; Schema: public; Owner: ecommerce_user
--

SELECT pg_catalog.setval('public.products_id_seq', 17, true);


--
-- Name: categories categories_name_key; Type: CONSTRAINT; Schema: public; Owner: ecommerce_user
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_name_key UNIQUE (name);


--
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: ecommerce_user
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: customers customers_email_key; Type: CONSTRAINT; Schema: public; Owner: ecommerce_user
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_email_key UNIQUE (email);


--
-- Name: customers customers_pkey; Type: CONSTRAINT; Schema: public; Owner: ecommerce_user
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_pkey PRIMARY KEY (id);


--
-- Name: order_items order_items_pkey; Type: CONSTRAINT; Schema: public; Owner: ecommerce_user
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_pkey PRIMARY KEY (id);


--
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: public; Owner: ecommerce_user
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id);


--
-- Name: products products_pkey; Type: CONSTRAINT; Schema: public; Owner: ecommerce_user
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_pkey PRIMARY KEY (id);


--
-- Name: products products_sku_key; Type: CONSTRAINT; Schema: public; Owner: ecommerce_user
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_sku_key UNIQUE (sku);


--
-- Name: idx_order_items_order; Type: INDEX; Schema: public; Owner: ecommerce_user
--

CREATE INDEX idx_order_items_order ON public.order_items USING btree (order_id);


--
-- Name: idx_order_items_product; Type: INDEX; Schema: public; Owner: ecommerce_user
--

CREATE INDEX idx_order_items_product ON public.order_items USING btree (product_id);


--
-- Name: idx_orders_customer; Type: INDEX; Schema: public; Owner: ecommerce_user
--

CREATE INDEX idx_orders_customer ON public.orders USING btree (customer_id);


--
-- Name: idx_products_category; Type: INDEX; Schema: public; Owner: ecommerce_user
--

CREATE INDEX idx_products_category ON public.products USING btree (category_id);


--
-- Name: order_items order_items_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ecommerce_user
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;


--
-- Name: order_items order_items_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ecommerce_user
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: orders orders_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ecommerce_user
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: products products_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ecommerce_user
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id);


--
-- PostgreSQL database dump complete
--

\unrestrict kRTFjiDNRYK0gUCyZbHWlbJsJUHnYpQKPOgD5wuz4ZMjTdJ9IPMEQgd6NIAKgdx

