-- =============================================================
--  DDL: DATABASE PERPUSTAKAAN (OLTP)
--  Database : db_perpustakaan
--  NIM sebagai foreign key logis ke db_akademik
-- =============================================================

-- ─────────────────────────────────────────────
-- 0. Buat database (jalankan sebagai superuser)
-- ─────────────────────────────────────────────
-- CREATE DATABASE db_perpustakaan
--     ENCODING   'UTF8'
--     TEMPLATE   template0;
-- \c db_perpustakaan

-- ─────────────────────────────────────────────
-- 1. Bersihkan jika perlu (hati-hati di produksi)
-- ─────────────────────────────────────────────
DROP TABLE IF EXISTS
    denda,
    detail_peminjaman,
    peminjaman,
    kunjungan,
    anggota,
    eksemplar_buku,
    buku,
    kategori_buku
CASCADE;

-- =============================================================
-- TABEL REFERENSI
-- =============================================================

CREATE TABLE kategori_buku (
    kategori_id     SMALLINT        NOT NULL,
    nama_kategori   VARCHAR(60)     NOT NULL,
    kode_ddc        VARCHAR(20),                -- Dewey Decimal Classification
    CONSTRAINT pk_kategori_buku PRIMARY KEY (kategori_id)
);

COMMENT ON TABLE  kategori_buku IS 'Klasifikasi koleksi buku berdasarkan DDC';
COMMENT ON COLUMN kategori_buku.kode_ddc IS 'Kode Dewey Decimal Classification, misal 005-005';


-- =============================================================
-- KOLEKSI BUKU
-- =============================================================

CREATE TABLE buku (
    buku_id         VARCHAR(8)      NOT NULL,
    isbn            VARCHAR(20)     UNIQUE,
    judul           VARCHAR(200)    NOT NULL,
    penulis         VARCHAR(100)    NOT NULL,
    penerbit        VARCHAR(80),
    tahun_terbit    SMALLINT        CHECK (tahun_terbit BETWEEN 1900 AND 2099),
    kategori_id     SMALLINT        NOT NULL,

    CONSTRAINT pk_buku         PRIMARY KEY (buku_id),
    CONSTRAINT fk_buku_kategori FOREIGN KEY (kategori_id)
        REFERENCES kategori_buku (kategori_id)
);

CREATE INDEX idx_buku_kategori ON buku (kategori_id);
CREATE INDEX idx_buku_judul    ON buku USING gin (to_tsvector('indonesian', judul));

COMMENT ON TABLE buku IS 'Master koleksi buku (1 baris = 1 judul)';


CREATE TABLE eksemplar_buku (
    eksemplar_id    VARCHAR(10)     NOT NULL,
    buku_id         VARCHAR(8)      NOT NULL,
    kondisi         VARCHAR(15)     NOT NULL DEFAULT 'Baik'
                        CHECK (kondisi IN ('Baik','Rusak Ringan','Rusak Berat')),
    tersedia        CHAR(1)         NOT NULL DEFAULT 'Y'
                        CHECK (tersedia IN ('Y','N')),

    CONSTRAINT pk_eksemplar         PRIMARY KEY (eksemplar_id),
    CONSTRAINT fk_eksemplar_buku    FOREIGN KEY (buku_id)
        REFERENCES buku (buku_id)
);

CREATE INDEX idx_eksemplar_buku      ON eksemplar_buku (buku_id);
CREATE INDEX idx_eksemplar_tersedia  ON eksemplar_buku (tersedia);

COMMENT ON TABLE  eksemplar_buku IS 'Fisik eksemplar — 1 buku bisa punya banyak eksemplar';
COMMENT ON COLUMN eksemplar_buku.tersedia IS 'Y=ada di rak, N=sedang dipinjam atau rusak berat';


-- =============================================================
-- ANGGOTA
-- NIM adalah referensi logis ke db_akademik.mahasiswa
-- (tidak ada FK fisik karena beda database)
-- =============================================================

CREATE TABLE anggota (
    anggota_id      VARCHAR(25)     NOT NULL,
    nim             VARCHAR(20)     NOT NULL UNIQUE,    -- referensi logis ke db_akademik
    nama_lengkap    VARCHAR(100)    NOT NULL,
    jenis_kelamin   CHAR(1)         NOT NULL CHECK (jenis_kelamin IN ('L','P')),
    tgl_daftar      DATE            NOT NULL,
    tgl_expired     DATE            NOT NULL,
    status_aktif    CHAR(1)         NOT NULL DEFAULT 'Y'
                        CHECK (status_aktif IN ('Y','N')),

    CONSTRAINT pk_anggota          PRIMARY KEY (anggota_id),
    CONSTRAINT chk_tgl_anggota     CHECK (tgl_expired > tgl_daftar)
);

CREATE INDEX idx_anggota_nim    ON anggota (nim);
CREATE INDEX idx_anggota_status ON anggota (status_aktif);

COMMENT ON TABLE  anggota IS 'Anggota perpustakaan; NIM merujuk ke db_akademik.mahasiswa';
COMMENT ON COLUMN anggota.nim IS 'FK logis ke db_akademik — tidak ada constraint fisik lintas DB';


-- =============================================================
-- KUNJUNGAN
-- =============================================================

CREATE TABLE kunjungan (
    kunjungan_id    BIGINT          NOT NULL,
    anggota_id      VARCHAR(25)     NOT NULL,
    tanggal         DATE            NOT NULL,
    jam_masuk       TIME            NOT NULL,
    durasi_menit    SMALLINT        NOT NULL CHECK (durasi_menit > 0),

    CONSTRAINT pk_kunjungan         PRIMARY KEY (kunjungan_id),
    CONSTRAINT fk_kunjungan_anggota FOREIGN KEY (anggota_id)
        REFERENCES anggota (anggota_id),
    -- Satu anggota maksimal 1 kunjungan per hari
    CONSTRAINT uq_kunjungan_harian  UNIQUE (anggota_id, tanggal)
);

CREATE INDEX idx_kunjungan_anggota  ON kunjungan (anggota_id);
CREATE INDEX idx_kunjungan_tanggal  ON kunjungan (tanggal);

COMMENT ON TABLE kunjungan IS 'Log kunjungan harian anggota ke perpustakaan';


-- =============================================================
-- PEMINJAMAN (header transaksi)
-- =============================================================

CREATE TABLE peminjaman (
    peminjaman_id           BIGINT          NOT NULL,
    anggota_id              VARCHAR(25)     NOT NULL,
    tgl_pinjam              DATE            NOT NULL,
    tgl_kembali_rencana     DATE            NOT NULL,
    tgl_kembali_aktual      DATE,                       -- NULL = belum dikembalikan
    status                  VARCHAR(15)     NOT NULL DEFAULT 'Dipinjam'
                                CHECK (status IN ('Dipinjam','Dikembalikan','Hilang')),
    petugas_id              VARCHAR(10)     NOT NULL,

    CONSTRAINT pk_peminjaman            PRIMARY KEY (peminjaman_id),
    CONSTRAINT fk_peminjaman_anggota    FOREIGN KEY (anggota_id)
        REFERENCES anggota (anggota_id),
    CONSTRAINT chk_tgl_rencana         CHECK (tgl_kembali_rencana >= tgl_pinjam),
    CONSTRAINT chk_tgl_aktual          CHECK (
        tgl_kembali_aktual IS NULL OR tgl_kembali_aktual >= tgl_pinjam
    )
);

CREATE INDEX idx_peminjaman_anggota ON peminjaman (anggota_id);
CREATE INDEX idx_peminjaman_status  ON peminjaman (status);
CREATE INDEX idx_peminjaman_tgl     ON peminjaman (tgl_pinjam);

COMMENT ON TABLE  peminjaman IS 'Header transaksi peminjaman — 1 transaksi bisa mencakup beberapa buku';
COMMENT ON COLUMN peminjaman.petugas_id IS 'ID petugas perpustakaan yang melayani (referensi ke tabel staf, opsional)';


-- =============================================================
-- DETAIL PEMINJAMAN (baris per buku per transaksi)
-- =============================================================

CREATE TABLE detail_peminjaman (
    detail_id       BIGINT          NOT NULL,
    peminjaman_id   BIGINT          NOT NULL,
    buku_id         VARCHAR(8)      NOT NULL,
    eksemplar_id    VARCHAR(10)     NOT NULL,

    CONSTRAINT pk_detail_peminjaman         PRIMARY KEY (detail_id),
    CONSTRAINT fk_detail_peminjaman_header  FOREIGN KEY (peminjaman_id)
        REFERENCES peminjaman (peminjaman_id),
    CONSTRAINT fk_detail_buku              FOREIGN KEY (buku_id)
        REFERENCES buku (buku_id),
    CONSTRAINT fk_detail_eksemplar         FOREIGN KEY (eksemplar_id)
        REFERENCES eksemplar_buku (eksemplar_id)
);

CREATE INDEX idx_detail_peminjaman ON detail_peminjaman (peminjaman_id);
CREATE INDEX idx_detail_buku       ON detail_peminjaman (buku_id);

COMMENT ON TABLE detail_peminjaman IS 'Rincian buku per transaksi peminjaman';


-- =============================================================
-- DENDA
-- =============================================================

CREATE TABLE denda (
    denda_id                BIGINT          NOT NULL,
    peminjaman_id           BIGINT          NOT NULL UNIQUE,    -- 1 peminjaman max 1 denda
    hari_keterlambatan      SMALLINT        NOT NULL CHECK (hari_keterlambatan > 0),
    total_denda             INTEGER         NOT NULL CHECK (total_denda > 0),
    status_pembayaran       VARCHAR(15)     NOT NULL DEFAULT 'Belum Dibayar'
                                CHECK (status_pembayaran IN ('Lunas','Belum Dibayar','Dihapuskan')),
    tgl_bayar               DATE,                               -- NULL jika belum lunas

    CONSTRAINT pk_denda             PRIMARY KEY (denda_id),
    CONSTRAINT fk_denda_peminjaman  FOREIGN KEY (peminjaman_id)
        REFERENCES peminjaman (peminjaman_id)
);

CREATE INDEX idx_denda_status ON denda (status_pembayaran);

COMMENT ON TABLE  denda IS 'Denda keterlambatan pengembalian buku';
COMMENT ON COLUMN denda.total_denda IS 'Dalam Rupiah: hari_keterlambatan × tarif × jumlah_eksemplar';


-- =============================================================
-- VIEW BERGUNA (opsional, untuk kemudahan query)
-- =============================================================

-- Ringkasan anggota aktif beserta total peminjaman & kunjungan
CREATE OR REPLACE VIEW v_ringkasan_anggota AS
SELECT
    a.anggota_id,
    a.nim,
    a.nama_lengkap,
    a.status_aktif,
    COUNT(DISTINCT p.peminjaman_id)  AS total_peminjaman,
    COUNT(DISTINCT k.kunjungan_id)   AS total_kunjungan,
    COALESCE(SUM(d.total_denda), 0)  AS total_denda_rp,
    SUM(CASE WHEN d.status_pembayaran = 'Belum Dibayar'
             THEN d.total_denda ELSE 0 END) AS denda_belum_bayar_rp
FROM       anggota     a
LEFT JOIN  peminjaman  p ON a.anggota_id = p.anggota_id
LEFT JOIN  kunjungan   k ON a.anggota_id = k.anggota_id
LEFT JOIN  denda       d ON p.peminjaman_id = d.peminjaman_id
GROUP BY   a.anggota_id, a.nim, a.nama_lengkap, a.status_aktif;

COMMENT ON VIEW v_ringkasan_anggota IS 'Ringkasan aktivitas per anggota perpustakaan';


-- Stok tersedia per judul buku
CREATE OR REPLACE VIEW v_stok_buku AS
SELECT
    b.buku_id,
    b.judul,
    k.nama_kategori,
    COUNT(e.eksemplar_id)                                    AS total_eksemplar,
    SUM(CASE WHEN e.tersedia = 'Y' THEN 1 ELSE 0 END)       AS tersedia,
    SUM(CASE WHEN e.tersedia = 'N' THEN 1 ELSE 0 END)       AS dipinjam
FROM       buku           b
JOIN       kategori_buku  k ON b.kategori_id = k.kategori_id
LEFT JOIN  eksemplar_buku e ON b.buku_id     = e.buku_id
GROUP BY   b.buku_id, b.judul, k.nama_kategori;

COMMENT ON VIEW v_stok_buku IS 'Stok dan ketersediaan eksemplar per judul buku';
