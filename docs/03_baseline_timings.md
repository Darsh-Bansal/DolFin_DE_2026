# Phase 3: Baseline timings (30 queries, no tuning)

## How these numbers were produced

- Database: schema from `sql/01_schema.sql`, data from `sql/02_load_data.sql` (all 12 files, row counts match), then `VACUUM ANALYZE`.
- Only the 20 indexes that PostgreSQL creates for PRIMARY KEY and UNIQUE constraints exist. No tuning index, default server settings.
- Command: `./benchmarks/run_benchmark.sh dolfin baseline 3` -> `benchmarks/results/baseline/summary.csv` and the raw plans `R01.txt … W05.txt` (all 3 runs of each query).
- Method: `EXPLAIN (ANALYZE, BUFFERS)`, 3 runs per query, the table below shows each run's `Execution Time` and their average. Write queries ran inside `BEGIN; … ROLLBACK;`.
- **Machine:** PostgreSQL 16.15 on a Linux cloud container with 2 vCPU and 8 GB RAM, `shared_buffers = 128MB`, `work_mem = 4MB`, session time zone UTC. **TEAM TO CHECK:** `team.json` asks for the laptop used for benchmarks; if you re-run on your own laptop, replace this file and the results folder with that run so the numbers and plans stay consistent.
- Runs are warm (data already in cache after the first run), so these times show CPU and buffer work, not disk reads.

## Timing table

| SQL Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
|---|---|---:|---:|---:|---:|
| R01: Rent search: active 2 BHK homes in Koramangala up to ₹40,000/month, furnished or semi-furnished | READ | 15.116 | 13.787 | 14.216 | 14.373 |
| R02: Buy search: 3 BHK apartments for sale in Pune under ₹1.2 crore, best price per sq ft first | READ | 14.967 | 12.718 | 12.080 | 13.255 |
| R03: Property page: property 6897 with its project, builder and project amenities | READ | 0.158 | 0.158 | 0.152 | 0.156 |
| R04: Price trends: average sale price per sq ft of apartments in Whitefield, per month in 2026 | READ | 20.596 | 17.671 | 18.005 | 18.757 |
| R05: Map view: active rentals inside the visible map area of central Bengaluru | READ | 13.779 | 14.432 | 13.802 | 14.004 |
| R06: Owner dashboard: owner 1033's listings with enquiry and site-visit counts | READ | 20.593 | 20.811 | 20.433 | 20.612 |
| R07: Agent app: site visits scheduled on 1 July 2026 for properties listed by user 4723 | READ | 3.308 | 3.430 | 3.308 | 3.349 |
| R08: Price-drop alerts: active properties whose price fell by 10% or more in June 2026 | READ | 2.512 | 2.796 | 2.496 | 2.601 |
| R09: Amenity filter: active properties in projects that have a gym AND a swimming pool AND power backup | READ | 16.630 | 16.835 | 23.369 | 18.945 |
| R10: Buyer due diligence: look up a project by its RERA registration id | READ | 0.087 | 0.083 | 0.084 | 0.085 |
| R11: Project page: available listings in project 217 by BHK with the price range | READ | 17.077 | 16.442 | 11.593 | 15.037 |
| R12: Lead follow-up: June 2026 enquiries with no site visit booked for that property by that user | READ | 13.943 | 13.658 | 15.658 | 14.420 |
| R13: Builder partnerships: projects with no property listed on Housing.com | READ | 21.648 | 22.034 | 33.355 | 25.679 |
| R14: Agent leaderboard: agents with the most properties sold or rented in 2026 | READ | 19.488 | 19.220 | 19.446 | 19.385 |
| R15: Investor insights: rental yield by Bengaluru locality (yearly rent per sq ft ÷ sale price per sq ft) | READ | 19.983 | 20.437 | 20.878 | 20.433 |
| R16: Search box: projects with "greens" in the name | READ | 0.510 | 0.829 | 0.472 | 0.604 |
| R17: Owner nudges: active listings older than 90 days that have never received an enquiry | READ | 38.073 | 40.645 | 38.348 | 39.022 |
| R18: Fraud checks: the same flat (locality, area, floor, BHK) listed more than once by the same lister | READ | 27.330 | 26.519 | 26.601 | 26.817 |
| R19: City report: enquiries and latest enquiry for every active sale property in Bengaluru | READ | 8340.167 | 8645.794 | 9280.009 | 8755.323 |
| R20: Growth: new listings per day and running total, June 2026 | READ | 23.229 | 23.190 | 27.780 | 24.733 |
| R21: Experience: average site-visit rating per locality (at least 10 rated visits) | READ | 22.134 | 20.382 | 25.585 | 22.700 |
| R22: Listing moderation console: all listings, newest first, page 2,001 (25 per page) | READ | 63.274 | 61.459 | 65.834 | 63.522 |
| R23: Sign-in with mobile number | READ | 0.049 | 0.044 | 0.042 | 0.045 |
| R24: Buyer protection: under-construction projects whose promised possession date has already passed | READ | 0.255 | 0.283 | 0.408 | 0.315 |
| R25: Funnel: shortlists that turned into an enquiry, per city | READ | 911.930 | 881.790 | 939.897 | 911.206 |
| W01: Post property: owner 1033 lists a 2 BHK for rent in Koramangala | WRITE | 1.315 | 1.323 | 0.856 | 1.165 |
| W02: Price cut: owner 1033 reduces the rent of their most recent active rental by 5% | WRITE | 1.175 | 1.269 | 1.214 | 1.219 |
| W03: Book a site visit: seeker 1042 visits property 6897 on 4 July 2026 at 11:00 | WRITE | 1.138 | 1.191 | 0.726 | 1.018 |
| W04: Nightly job: deactivate active listings older than 120 days | WRITE | 154.613 | 91.768 | 86.993 | 111.125 |
| W05: Owner 1033 marks their oldest active rental as rented | WRITE | 16.642 | 10.391 | 16.776 | 14.603 |
| **Total (sum of all 30)** | | | | | **10174.508** |

Total = 10,174.5 ms. R19 alone is 86.1% of it.

## Scan type and why each query is slow or fast

| Query | Scan types in the plan (last run) | Why |
|---|---|---|
| R01 | Seq Scan on properties | Seq Scan on localities | Parallel Seq Scan reads all 120,060 properties and throws 116k away; no index on `properties(locality_id, …)` or any filter column. Only the sort of 25 rows is cheap. |
| R02 | Seq Scan on properties | Seq Scan on localities | Same pattern as R01: Parallel Seq Scan on `properties` with 5 filters, then a top-30 sort on the computed price per sq ft. No index exists for city/listing/status/bhk. |
| R03 | Index Scan using properties_pkey on properties | Index Scan using projects_pkey on projects | Index Scan using builders_pkey on builders | Index Only Scan using project_amenities_pkey on project_amenities | Index Scan using amenities_pkey on amenities | Fast: primary-key lookup on `properties`, then PK lookups on projects, builders and the amenity join tables. One row in, a handful out. |
| R04 | Seq Scan on localities | Seq Scan on properties | Seq Scan of `properties` because `EXTRACT(YEAR FROM posted_at) = 2026` wraps the column in a function, so no index on `posted_at` could be used even if one existed. Locality filter happens in a nested loop join filter that discards 13,865 rows. |
| R05 | Seq Scan on properties | Parallel Seq Scan. Filters on type, status and lat/lng range cannot use any index (none exist). `LIMIT 200` stops it early, which is why it is not slower. |
| R06 | Seq Scan on site_visits | Seq Scan on enquiries | Seq Scan on properties | `listed_by = 1033` has no index, so all 120,060 properties are scanned; `enquiries` (100k) and `site_visits` (35k) are scanned in full because `property_id` is a foreign key and PostgreSQL does not index foreign keys. Joining both children multiplies rows, hence the `count(DISTINCT …)`. |
| R07 | Seq Scan on site_visits | Index Scan using properties_pkey on properties | Index Scan using users_pkey on users | Seq Scan of 35,120 site_visits because `DATE(scheduled_at) = …` puts a function on the column. Then a PK lookup in `properties` per candidate visit (75 of them) to check the lister. |
| R08 | Seq Scan on price_changes | Index Scan using properties_pkey on properties | Seq Scan of 23,425 price_changes (no index on `changed_at`), then 657 PK lookups into `properties` to check status. Small tables, so it is cheap in absolute terms. |
| R09 | Seq Scan on properties | Seq Scan on project_amenities | Seq Scan on amenities | Seq Scan of `properties` for `status = 'ACTIVE'` (36,819 rows) joined to the 58 projects that have all 3 amenities, then a top-50 sort. `properties.project_id` is not indexed, so the project list cannot be used to go straight to the rows. |
| R10 | Seq Scan on builders | Index Scan using uq_projects_rera_id on projects | Fast: the UNIQUE index on `projects.rera_id` finds the single row. The Seq Scan on `builders` is only 150 rows. |
| R11 | Seq Scan on properties | Seq Scan of all of `properties` to find 19 rows of project 217: no index on `properties.project_id` (foreign key columns are not indexed automatically). |
| R12 | Seq Scan on enquiries | Seq Scan on site_visits | Seq Scan of `enquiries` for the date range (5,928 rows) and a hash anti join against all of `site_visits`. No index on `enquiries.created_at` or on `site_visits(property_id, user_id)`. |
| R13 | Seq Scan on projects | Seq Scan on properties | **Wrong result.** `NOT IN (SELECT project_id FROM properties)` returns 0 rows because 54,009 properties have `project_id = NULL`; a single NULL in the list makes `NOT IN` never true. The plan itself is a hashed subplan over a full scan of `properties`. `NOT EXISTS` gives 120 projects. |
| R14 | Seq Scan on properties | Seq Scan on users | Seq Scan of `properties` for sold/rented since 1 Jan 2026 (10,544 rows) and of `users` for agents (2,049), hash join, group, top-20. Needs most of both filtered sets; there is no index on status or posted_at. |
| R15 | Seq Scan on properties | Seq Scan on localities | Seq Scan of `properties` for every APARTMENT (97,695 rows) to aggregate 9,926 Bengaluru rows after the join. Reads far more than it needs because the city filter is applied after the scan. |
| R16 | Seq Scan on projects | Seq Scan of 1,200 projects. `ILIKE '%greens%'` has a leading wildcard so a normal B-tree cannot help. Tiny table, so 0.6 ms. |
| R17 | Seq Scan on enquiries | Seq Scan on properties | Seq Scan of `properties` for old active listings (20,006 rows) and a hash anti join against a full Seq Scan of `enquiries` (100k). No index on `enquiries.property_id`. |
| R18 | Seq Scan on properties | Seq Scan of `properties` for active rows (36,819) and a HashAggregate over 5 columns. The grouping has to look at every active listing, so an index helps only partially. |
| R19 | Seq Scan on properties | Seq Scan on localities | Seq Scan on enquiries | **The slow one (several seconds).** Two correlated subqueries run once per Bengaluru sale listing (1,780 rows each) and each does a Seq Scan of all 100,000 enquiries: 1,780 × 2 × 100k rows read, 3.09 million buffer hits. `enquiries.property_id` has no index. |
| R20 | Seq Scan on properties | Seq Scan of `properties`; `posted_at::date BETWEEN …` casts the column so an index on `posted_at` would not be used. 6,550 June rows are sorted and grouped by day. |
| R21 | Seq Scan on properties | Seq Scan on site_visits | Seq Scan on localities | Parallel Seq Scan of `properties` joined to the 14,694 rated site visits, grouped per locality. Reads the whole table because every rated visit needs its property's locality. |
| R22 | Seq Scan on properties | Seq Scan of the entire `properties` table, then an external-merge sort (5.7 MB to disk) of 50,025 rows only to throw away the first 50,000 (`OFFSET`). No index on `posted_at`. |
| R23 | Index Scan using uq_users_phone on users | Fast: UNIQUE index on `users.phone`. |
| R24 | Seq Scan on projects | Seq Scan on builders | Seq Scan of 1,200 projects (180 match) and 150 builders; hash join and a tiny sort. Small tables, so 0.3 ms. |
| R25 | Index Scan using uq_localities_city_name on localities | Seq Scan on shortlists | Seq Scan on properties | Seq Scan on enquiries | Seq Scans of shortlists (69,999), properties (120,060) and a SubPlan scan of enquiries (100k, hashed); the planner also picked a nested loop against `localities` that discards 6.9 million join rows, and JIT compilation added ~189 ms. No index on `enquiries(property_id, user_id)`. |
| W01 | (no scan) | Single-row INSERT; cost is maintaining the only index on `properties` (the primary key) plus the CHECK and foreign-key constraint checks. |
| W02 | Index Scan using properties_pkey on properties | The inner `max(property_id) … WHERE listed_by = 1033` walks `properties_pkey` backwards filtering 3,150 rows before it finds a match, then updates one row. |
| W03 | (no scan) | Single-row INSERT into `site_visits`; checks two foreign keys (property, user) and the CHECK constraints. |
| W04 | Seq Scan on properties | Seq Scan of `properties` and an UPDATE of 14,440 rows. Dominated by writing the rows, not finding them. |
| W05 | Index Scan using properties_pkey on properties | `min(property_id)` walks `properties_pkey` forward and filters 53,025 rows before finding owner 1033's oldest active rental (15,713 buffer hits). A composite index would find it immediately. |

## What the baseline shows

- **27 of 30 queries are under 65 ms; three are not.** R19 (8.8 s), R25 (0.9 s) and W04 (111 ms) are the only ones above 100 ms. On 120k rows a Seq Scan is cheap, so the baseline looks fine until the data grows 20×.
- **Nearly everything is a Seq Scan on `properties`.** The only indexes are the 20 from PRIMARY KEY/UNIQUE constraints. No foreign-key column is indexed, so every join into `enquiries`, `site_visits`, `shortlists` and every `properties.project_id` / `listed_by` / `locality_id` lookup scans a whole table.
- **Four functions-on-columns block index use:** `EXTRACT(YEAR FROM posted_at)` (R04), `DATE(scheduled_at)` (R07), `posted_at::date` (R20), and the leading-wildcard `ILIKE` (R16).
- **R13 returns the wrong answer** (0 rows instead of 120) because of NULLs in `properties.project_id`; see `docs/04_optimization_report.md`.
- **R22 is `OFFSET 50000`,** which sorts 50,025 rows and discards 50,000. It will grow with the table.

## Assumptions

- 'Today' in the workload is 1 July 2026, as in the queries themselves.
- The session time zone is UTC. Queries that compare timestamps with plain dates (`'2026-06-01'`, R08/R12) are interpreted at UTC midnight. Row counts for R07/R12/R20 can differ by a few rows on a laptop running in IST; the plan shape and timing do not.
