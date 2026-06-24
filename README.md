# Academic & Library Data Warehouse

A PostgreSQL-based data warehouse project for analyzing student academic performance, library activity, and cross-domain patterns between the two. The project integrates two operational databases, `db_akademik` and `db_perpus`, into a centralized analytical warehouse named `DWakadperpus`.

The repository includes Docker-based setup, source database dumps, initial load and incremental load workflows, PL/pgSQL ETL procedures, `pg_cron` scheduling, ETL monitoring, and analytical views/materialized views.

## Overview

This project models a campus data warehouse scenario with two source systems:

- Academic system: student records, study results, courses, grades, and study programs.
- Library system: members, books, categories, visits, borrowing transactions, and fines.

The warehouse is designed to support analytical questions such as:

- Which courses have the highest failure rate?
- How does academic performance trend across semesters?
- Which book categories are borrowed the most?
- Does library borrowing intensity relate to semester GPA?
- Do students with library fines show different academic performance?

## Tech Stack

- PostgreSQL 15
- Docker and Docker Compose
- PostgreSQL Foreign Data Wrapper (`postgres_fdw`)
- PostgreSQL `pg_cron`
- PL/pgSQL stored procedures
- View and materialized view based analytics
- DBeaver for query exploration and result screenshots

## Database Architecture

The project uses three PostgreSQL databases:

| Database | Role | Description |
| --- | --- | --- |
| `db_akademik` | Source OLTP | Stores academic data such as students, courses, study results, and grades. |
| `db_perpus` | Source OLTP | Stores library data such as members, books, borrowing transactions, visits, and fines. |
| `DWakadperpus` | Data Warehouse | Stores dimensions, facts, ETL logs, views, and materialized views for analytics. |

## Warehouse Schema

The warehouse uses a constellation schema because multiple fact tables share common dimensions.

### Dimension Tables

- `dim_waktu`
- `dim_mahasiswa`
- `dim_program_studi`
- `dim_mata_kuliah`
- `dim_kategori_buku`

### Fact Tables

- `fact_detail_nilai`
- `fact_rekap_ip`
- `fact_rekap_pinjam`

### Supporting Table

- `log_proses_etl`

The `log_proses_etl` table records ETL execution history, including process name, start time, end time, duration, status, and error message if a process fails.

## Key Features

- Dockerized PostgreSQL environment with three databases.
- Initial load from full historical source data.
- Incremental load simulation for new operational data.
- Cross-database extraction using `postgres_fdw`.
- ETL orchestration through PL/pgSQL stored procedures.
- Automated scheduling with `pg_cron`.
- Materialized view refresh as the final dashboard refresh step.
- ETL monitoring through database logs.
- Analytical queries for academic, library, and cross-domain insights.
- WIB timezone configuration (`Asia/Jakarta`) for PostgreSQL and `pg_cron`.

## Repository Structure

```text
.
|-- docker-compose.yml
|-- Dockerfile
|-- 01_pgcron.sql
|-- 02_init_cron.sql
|-- README1_initial_load.txt
|-- README2_incremental_load.txt
|-- monitoring_etl.sql
|-- hasil_analisis.sql
|-- dump-db_akademik.dump
|-- dump-db_perpus.dump
|-- dump-db_dw.dump
|-- incremental_akademik1.dump
|-- incremental_akademik2.dump
|-- incremental_perpus1.dump
|-- incremental_perpus2.dump
|-- incremental_perpus3.dump
`-- sql/
    |-- 01_ddl_akademik.sql
    |-- 02_ddl_perpus.sql
    |-- 03_ddl_dw.sql
    |-- 04_setup_fdw.sql
    |-- 05_stored_procedure.sql
    |-- 06_init_load.sql
    |-- 07_incremental_load.sql
    |-- 08_query_analisis.sql
    `-- output_analisis.txt
```

## Setup

Make sure Docker Desktop or Docker Engine is running.

Start the containers:

```bash
docker compose up -d --build
```

If the containers have already been built before, run:

```bash
docker compose up -d
```

## Initial Load

The initial load restores the source databases and initializes the warehouse with full historical data.

Copy the dump files into their respective containers:

```bash
docker cp "dump-db_akademik.dump" db_akademik:/tmp/dump.dump
docker cp "dump-db_perpus.dump" db_perpus:/tmp/dump.dump
docker cp "dump-db_dw.dump" db_dw:/tmp/dump.dump
```

Restore the academic source database:

```bash
docker exec -it db_akademik pg_restore -U user -d db_akademik /tmp/dump.dump
```

Restore the library source database:

```bash
docker exec -it db_perpus pg_restore -U user -d db_perpus /tmp/dump.dump
```

Restore the warehouse structure:

```bash
docker exec -it db_dw pg_restore -U user -d DWakadperpus /tmp/dump.dump
```

Run the warehouse initial load procedure:

```bash
docker exec -it db_dw psql -U user -d DWakadperpus -c "CALL sp_initial_load_dw();"
```

Detailed initial load instructions are available in:

```text
README1_initial_load.txt
```

This runbook is written in Indonesian because it was prepared as the operational submission guide for the project demo.

## Incremental Load

The incremental load simulates new operational data entering the academic and library source systems, then refreshes the warehouse.

Copy the incremental dump files:

```bash
docker cp "incremental_akademik1.dump" db_akademik:/tmp/dump1.dump
docker cp "incremental_akademik2.dump" db_akademik:/tmp/dump2.dump
docker cp "incremental_perpus1.dump" db_perpus:/tmp/dump1.dump
docker cp "incremental_perpus2.dump" db_perpus:/tmp/dump2.dump
docker cp "incremental_perpus3.dump" db_perpus:/tmp/dump3.dump
```

Restore academic incremental data:

```bash
docker exec -it db_akademik pg_restore -U user -d db_akademik /tmp/dump1.dump
docker exec -it db_akademik pg_restore -U user -d db_akademik /tmp/dump2.dump
```

Restore library incremental data:

```bash
docker exec -it db_perpus pg_restore -U user -d db_perpus /tmp/dump1.dump
docker exec -it db_perpus pg_restore -U user -d db_perpus /tmp/dump2.dump
docker exec -it db_perpus pg_restore -U user -d db_perpus /tmp/dump3.dump
```

Run the incremental ETL procedures manually:

```bash
docker exec -it db_dw psql -U user -d DWakadperpus -c "CALL sp_load_shared_dimensions();"
docker exec -it db_dw psql -U user -d DWakadperpus -c "CALL sp_load_perpus_dw();"
docker exec -it db_dw psql -U user -d DWakadperpus -c "CALL sp_build_cross_domain_facts();"
docker exec -it db_dw psql -U user -d DWakadperpus -c "CALL sp_load_akademik_dw();"
docker exec -it db_dw psql -U user -d DWakadperpus -c "CALL sp_refresh_semua_dashboard_dw();"
```

Detailed incremental load instructions are available in:

```text
README2_incremental_load.txt
```

This runbook is also written in Indonesian and includes the demo flow, ETL monitoring commands, and final validation queries.

## ETL Pipeline

The warehouse ETL process is implemented in PL/pgSQL stored procedures.

Main procedures include:

- `sp_initial_load_dw()`
- `sp_load_shared_dimensions()`
- `sp_load_perpus_dw()`
- `sp_build_cross_domain_facts()`
- `sp_load_akademik_dw()`
- `sp_refresh_semua_dashboard_dw()`

The final procedure refreshes materialized views used by the analytical dashboard layer.

Stored procedure definitions are available in:

```text
sql/05_stored_procedure.sql
```

## Scheduling with pg_cron

Incremental ETL jobs are scheduled using `pg_cron` inside the warehouse database. The schedule is sequenced so that shared dimensions are loaded first, fact tables are updated afterward, and materialized views are refreshed at the end.

Check active cron jobs:

```bash
docker exec -it db_dw psql -U user -d DWakadperpus -P pager=off -c "SELECT jobid, schedule, command, active, jobname FROM cron.job;"
```

Check recent cron execution history:

```bash
docker exec -it db_dw psql -U user -d DWakadperpus -P pager=off -c "SELECT jobid, status, start_time, end_time, return_message FROM cron.job_run_details ORDER BY start_time DESC LIMIT 10;"
```

## ETL Monitoring

ETL execution logs are stored in the `log_proses_etl` table.

Copy the monitoring script into the warehouse container:

```bash
docker cp "monitoring_etl.sql" db_dw:/tmp/monitoring_etl.sql
```

Run the monitoring script:

```bash
docker exec -it db_dw psql -U user -d DWakadperpus -P pager=off -f /tmp/monitoring_etl.sql
```

## Analytical Queries

Analytical view and materialized view definitions are available in:

```text
sql/08_query_analisis.sql
```

The analysis covers:

- Course failure rate.
- Academic performance trend by semester.
- Academic performance comparison by class type.
- Cohort analysis by student intake year.
- Critical courses by student intake year.
- Most popular book categories.
- Borrowing and fine trends by semester.
- Relationship between borrowing intensity and semester GPA.
- Diagnostic GPA distribution.
- Relationship between library fines and semester GPA.
- Favorite book categories among high-performing students.
- Academic and library activity comparison by gender.

To display a command-line summary of the analytical outputs:

```bash
docker cp "hasil_analisis.sql" db_dw:/tmp/hasil_analisis.sql
docker exec -it db_dw psql -U user -d DWakadperpus -P pager=off -f /tmp/hasil_analisis.sql
```

The full captured output from a previous run is stored in:

```text
sql/output_analisis.txt
```

## Timezone

The Docker Compose configuration sets PostgreSQL and `pg_cron` to WIB (`Asia/Jakarta`).

Validate timezone settings:

```bash
docker exec -it db_dw psql -U user -d DWakadperpus -c "SHOW timezone; SHOW cron.timezone; SELECT now();"
```

## Reset

To reset the project and start over:

```bash
docker compose down -v
docker compose up -d --build
```

After resetting, repeat the dump restore and initial load steps.

## Notes

- Dump files are included so the project can be reproduced without regenerating source data.
- `README.md` is the English overview for GitHub and portfolio use.
- `README1_initial_load.txt` and `README2_incremental_load.txt` are Indonesian operational runbooks for the project demo.
- SQL source files are stored in the `sql/` directory.
- Query output files are supporting artifacts and are not required to understand the implementation.
