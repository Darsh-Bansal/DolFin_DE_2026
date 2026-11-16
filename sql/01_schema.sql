-- =====================================================================
-- sql/01_schema.sql : Housing.com Property Search DB (Team T0019 DolFin)
-- PostgreSQL 15+.  Runs top-to-bottom on an empty database.
--
-- Phase 2 rule: ONLY constraints here (PK, FK, UNIQUE, NOT NULL, CHECK).
-- No tuning indexes. The only indexes are the ones PostgreSQL creates
-- automatically for PRIMARY KEY and UNIQUE (listed at the bottom).
-- Every constraint below was verified against all 12 seed CSV files;
-- see docs/02_schema_design.md for the "why" of each one.
-- =====================================================================

DROP SCHEMA IF EXISTS housing CASCADE;
CREATE SCHEMA housing;
SET search_path TO housing;

-- ---------------------------------------------------------------------
-- cities
-- ---------------------------------------------------------------------
CREATE TABLE cities (
    city_id    smallint     PRIMARY KEY,
    city_name  varchar(50)  NOT NULL,
    state      varchar(50)  NOT NULL,
    CONSTRAINT uq_cities_city_name UNIQUE (city_name)
);

-- ---------------------------------------------------------------------
-- localities
-- ---------------------------------------------------------------------
CREATE TABLE localities (
    locality_id    smallint      PRIMARY KEY,
    city_id        smallint      NOT NULL
                   REFERENCES cities (city_id) ON DELETE RESTRICT,
    locality_name  varchar(60)   NOT NULL,
    pincode        char(6)       NOT NULL,
    center_lat     numeric(9,6)  NOT NULL,
    center_lng     numeric(9,6)  NOT NULL,
    CONSTRAINT uq_localities_city_name UNIQUE (city_id, locality_name),
    CONSTRAINT ck_localities_pincode   CHECK (pincode ~ '^[0-9]{6}$'),
    CONSTRAINT ck_localities_lat       CHECK (center_lat BETWEEN 6 AND 38),
    CONSTRAINT ck_localities_lng       CHECK (center_lng BETWEEN 68 AND 98)
);

-- ---------------------------------------------------------------------
-- builders
-- ---------------------------------------------------------------------
CREATE TABLE builders (
    builder_id    smallint     PRIMARY KEY,
    builder_name  varchar(80)  NOT NULL,
    founded_year  smallint     NOT NULL,
    CONSTRAINT uq_builders_name  UNIQUE (builder_name),
    CONSTRAINT ck_builders_year  CHECK (founded_year BETWEEN 1800 AND 2100)
);

-- ---------------------------------------------------------------------
-- projects  (rera_id is UNIQUE but nullable: 171 projects have none yet)
-- ---------------------------------------------------------------------
CREATE TABLE projects (
    project_id         integer      PRIMARY KEY,
    builder_id         smallint     NOT NULL
                       REFERENCES builders (builder_id)   ON DELETE RESTRICT,
    locality_id        smallint     NOT NULL
                       REFERENCES localities (locality_id) ON DELETE RESTRICT,
    project_name       varchar(80)  NOT NULL,
    rera_id            varchar(19),
    possession_status  varchar(20)  NOT NULL,
    possession_date    date         NOT NULL,
    total_units        integer      NOT NULL,
    CONSTRAINT uq_projects_rera_id  UNIQUE (rera_id),
    CONSTRAINT ck_projects_rera_fmt CHECK (rera_id ~ '^[A-Z]{2}-RERA-PR-[0-9]{8}$'),
    CONSTRAINT ck_projects_status   CHECK (possession_status IN ('READY_TO_MOVE', 'UNDER_CONSTRUCTION')),
    CONSTRAINT ck_projects_units    CHECK (total_units > 0)
);

-- ---------------------------------------------------------------------
-- amenities
-- ---------------------------------------------------------------------
CREATE TABLE amenities (
    amenity_id    smallint     PRIMARY KEY,
    amenity_name  varchar(40)  NOT NULL,
    CONSTRAINT uq_amenities_name UNIQUE (amenity_name)
);

-- ---------------------------------------------------------------------
-- project_amenities : M:N link, composite primary key
-- ---------------------------------------------------------------------
CREATE TABLE project_amenities (
    project_id  integer   NOT NULL
                REFERENCES projects (project_id)  ON DELETE CASCADE,
    amenity_id  smallint  NOT NULL
                REFERENCES amenities (amenity_id) ON DELETE CASCADE,
    PRIMARY KEY (project_id, amenity_id)
);

-- ---------------------------------------------------------------------
-- users : seekers, owners and agents
-- ---------------------------------------------------------------------
CREATE TABLE users (
    user_id        integer      PRIMARY KEY,
    full_name      varchar(80)  NOT NULL,
    phone          varchar(10)  NOT NULL,
    email          varchar(100),
    user_type      varchar(10)  NOT NULL,
    agent_rera_id  varchar(16),
    created_at     timestamptz  NOT NULL,
    CONSTRAINT uq_users_phone          UNIQUE (phone),
    CONSTRAINT uq_users_email          UNIQUE (email),
    CONSTRAINT uq_users_agent_rera_id  UNIQUE (agent_rera_id),
    CONSTRAINT ck_users_type           CHECK (user_type IN ('SEEKER', 'OWNER', 'AGENT')),
    CONSTRAINT ck_users_phone          CHECK (phone ~ '^[6-9][0-9]{9}$'),
    CONSTRAINT ck_users_email          CHECK (email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'),
    CONSTRAINT ck_users_agent_rera_fmt CHECK (agent_rera_id ~ '^AG-RERA-[0-9]{8}$'),
    -- only agents have an agent RERA id, and every agent has one
    CONSTRAINT ck_users_agent_rera_iff_agent
        CHECK ((user_type = 'AGENT') = (agent_rera_id IS NOT NULL))
);

-- ---------------------------------------------------------------------
-- properties
-- ---------------------------------------------------------------------
CREATE TABLE properties (
    property_id          integer       PRIMARY KEY,
    listed_by            integer       NOT NULL
                         REFERENCES users (user_id)         ON DELETE RESTRICT,
    project_id           integer
                         REFERENCES projects (project_id)   ON DELETE RESTRICT,
    locality_id          smallint      NOT NULL
                         REFERENCES localities (locality_id) ON DELETE RESTRICT,
    listing_type         varchar(4)    NOT NULL,
    property_type        varchar(20)   NOT NULL,
    bhk                  smallint,
    carpet_area_sqft     integer       NOT NULL,
    floor_no             smallint,
    total_floors         smallint,
    furnishing           varchar(20),
    facing               varchar(12)   NOT NULL,
    price                numeric(14,2) NOT NULL,
    maintenance_monthly  numeric(10,2),
    security_deposit     numeric(12,2),
    available_from       date          NOT NULL,
    latitude             numeric(9,6)  NOT NULL,
    longitude            numeric(9,6)  NOT NULL,
    is_verified          boolean       NOT NULL DEFAULT false,  -- new listings start unverified (W01 omits it)
    status               varchar(10)   NOT NULL,
    posted_at            timestamptz   NOT NULL,

    -- allowed values
    CONSTRAINT ck_prop_listing_type  CHECK (listing_type  IN ('RENT', 'SALE')),
    CONSTRAINT ck_prop_property_type CHECK (property_type IN ('APARTMENT', 'INDEPENDENT_HOUSE', 'VILLA', 'PLOT')),
    CONSTRAINT ck_prop_furnishing    CHECK (furnishing IN ('UNFURNISHED', 'SEMI_FURNISHED', 'FULLY_FURNISHED')),
    CONSTRAINT ck_prop_facing        CHECK (facing IN ('NORTH', 'SOUTH', 'EAST', 'WEST',
                                                       'NORTH_EAST', 'NORTH_WEST', 'SOUTH_EAST', 'SOUTH_WEST')),
    CONSTRAINT ck_prop_status        CHECK (status IN ('ACTIVE', 'INACTIVE', 'RENTED', 'SOLD')),

    -- ranges
    CONSTRAINT ck_prop_bhk           CHECK (bhk BETWEEN 1 AND 10),
    CONSTRAINT ck_prop_area          CHECK (carpet_area_sqft > 0),
    CONSTRAINT ck_prop_price         CHECK (price > 0),
    CONSTRAINT ck_prop_maintenance   CHECK (maintenance_monthly >= 0),
    CONSTRAINT ck_prop_deposit       CHECK (security_deposit >= 0),
    CONSTRAINT ck_prop_floor_no      CHECK (floor_no >= 0),
    CONSTRAINT ck_prop_total_floors  CHECK (total_floors >= 1),
    CONSTRAINT ck_prop_floor_le_tot  CHECK (floor_no <= total_floors),
    CONSTRAINT ck_prop_lat_india     CHECK (latitude  BETWEEN 6 AND 38),
    CONSTRAINT ck_prop_lng_india     CHECK (longitude BETWEEN 68 AND 98),

    -- plots have no BHK / furnishing / floors; every built property has BHK, furnishing, total floors
    CONSTRAINT ck_prop_plot_no_bhk        CHECK ((property_type = 'PLOT') = (bhk IS NULL)),
    CONSTRAINT ck_prop_plot_no_furnishing CHECK ((property_type = 'PLOT') = (furnishing IS NULL)),
    CONSTRAINT ck_prop_plot_no_totfloors  CHECK ((property_type = 'PLOT') = (total_floors IS NULL)),
    -- only apartments have a floor number (houses, villas and plots occupy the whole building/land)
    CONSTRAINT ck_prop_floor_only_apt     CHECK ((property_type = 'APARTMENT') = (floor_no IS NOT NULL)),

    -- deposits only for rentals
    CONSTRAINT ck_prop_deposit_rent_only  CHECK ((listing_type = 'RENT') = (security_deposit IS NOT NULL)),
    -- RENTED only for rentals, SOLD only for sales
    CONSTRAINT ck_prop_rented_only_rent   CHECK (status <> 'RENTED' OR listing_type = 'RENT'),
    CONSTRAINT ck_prop_sold_only_sale     CHECK (status <> 'SOLD'   OR listing_type = 'SALE'),

    -- project membership: villas always belong to a project, houses and plots never do
    CONSTRAINT ck_prop_project_by_type    CHECK (
          (property_type = 'VILLA'  AND project_id IS NOT NULL)
       OR (property_type = 'APARTMENT')
       OR (property_type IN ('INDEPENDENT_HOUSE', 'PLOT') AND project_id IS NULL)),
    -- society maintenance is charged only for listings inside a project
    CONSTRAINT ck_prop_maint_iff_project  CHECK ((project_id IS NULL) = (maintenance_monthly IS NULL))
);

-- ---------------------------------------------------------------------
-- price_changes : history of price cuts of a listing (1:N)
-- ---------------------------------------------------------------------
CREATE TABLE price_changes (
    change_id    integer        PRIMARY KEY,
    property_id  integer        NOT NULL
                 REFERENCES properties (property_id) ON DELETE CASCADE,
    old_price    numeric(14,2)  NOT NULL,
    new_price    numeric(14,2)  NOT NULL,
    changed_at   timestamptz    NOT NULL,
    CONSTRAINT ck_pc_old_positive CHECK (old_price > 0),
    CONSTRAINT ck_pc_new_positive CHECK (new_price > 0),
    CONSTRAINT ck_pc_differs      CHECK (new_price <> old_price)
);

-- ---------------------------------------------------------------------
-- enquiries
-- ---------------------------------------------------------------------
CREATE TABLE enquiries (
    enquiry_id   integer      PRIMARY KEY,
    property_id  integer      NOT NULL
                 REFERENCES properties (property_id) ON DELETE RESTRICT,
    user_id      integer      NOT NULL
                 REFERENCES users (user_id)          ON DELETE RESTRICT,
    channel      varchar(10)  NOT NULL,
    message      varchar(200),
    created_at   timestamptz  NOT NULL,
    CONSTRAINT ck_enq_channel CHECK (channel IN ('CALL', 'WHATSAPP', 'FORM'))
);

-- ---------------------------------------------------------------------
-- site_visits
-- ---------------------------------------------------------------------
CREATE TABLE site_visits (
    visit_id         integer      PRIMARY KEY,
    property_id      integer      NOT NULL
                     REFERENCES properties (property_id) ON DELETE RESTRICT,
    user_id          integer      NOT NULL
                     REFERENCES users (user_id)          ON DELETE RESTRICT,
    scheduled_at     timestamptz  NOT NULL,
    status           varchar(10)  NOT NULL,
    feedback_rating  smallint,
    CONSTRAINT ck_sv_status  CHECK (status IN ('SCHEDULED', 'COMPLETED', 'CANCELLED', 'NO_SHOW')),
    CONSTRAINT ck_sv_rating  CHECK (feedback_rating BETWEEN 1 AND 5),
    -- a rating exists only after a completed visit
    CONSTRAINT ck_sv_rating_only_completed
        CHECK (feedback_rating IS NULL OR status = 'COMPLETED')
);

-- ---------------------------------------------------------------------
-- shortlists : M:N between users and properties, composite primary key
-- ---------------------------------------------------------------------
CREATE TABLE shortlists (
    user_id      integer      NOT NULL
                 REFERENCES users (user_id)          ON DELETE CASCADE,
    property_id  integer      NOT NULL
                 REFERENCES properties (property_id) ON DELETE CASCADE,
    added_at     timestamptz  NOT NULL,
    PRIMARY KEY (user_id, property_id)
);

-- =====================================================================
-- Indexes that exist after this script (all automatic, from PK / UNIQUE):
--   PK:     cities_pkey, localities_pkey, builders_pkey, projects_pkey,
--           amenities_pkey, project_amenities_pkey (project_id, amenity_id),
--           users_pkey, properties_pkey, price_changes_pkey, enquiries_pkey,
--           site_visits_pkey, shortlists_pkey (user_id, property_id)
--   UNIQUE: uq_cities_city_name, uq_localities_city_name (city_id, locality_name),
--           uq_builders_name, uq_projects_rera_id, uq_amenities_name,
--           uq_users_phone, uq_users_email, uq_users_agent_rera_id
-- Foreign-key columns are NOT indexed by PostgreSQL; that is a Phase 4 topic.
-- =====================================================================
