-- =============================================================
-- BLOK 1: SETUP FOREIGN DATA WRAPPER (FDW)
-- =============================================================

-- 1.1 Aktifkan extension postgres_fdw
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- 1.2 Buat foreign server ke db_akademik
CREATE SERVER IF NOT EXISTS server_akademik
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS (
    host 'localhost',
    port '5432',
    dbname 'db_akademik'
);

-- 1.3 Buat foreign server ke db_perpus
CREATE SERVER IF NOT EXISTS server_perpus
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS (
    host 'localhost',
    port '5432',
    dbname 'db_perpus'
);

-- 1.4 Buat user mapping (sesuaikan user & password)
CREATE USER MAPPING IF NOT EXISTS FOR current_user
SERVER server_akademik
OPTIONS (user 'postgres', password 'password_anda');

CREATE USER MAPPING IF NOT EXISTS FOR current_user
SERVER server_perpus
OPTIONS (user 'postgres', password 'password_anda');

-- 1.5 Import foreign tables dari db_akademik
IMPORT FOREIGN SCHEMA public
LIMIT TO (
    program_studi,
    mata_kuliah,
    mahasiswa,
    hasil_studi,
    detail_nilai
)
FROM SERVER server_akademik
INTO public;

-- 1.6 Import foreign tables dari db_perpus
IMPORT FOREIGN SCHEMA public
LIMIT TO (
    kategori_buku,
    buku,
    eksemplar_buku,
    anggota,
    peminjaman,
    detail_peminjaman,
    denda
)
FROM SERVER server_perpus
INTO public;