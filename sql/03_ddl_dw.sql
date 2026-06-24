-- ==========================================
-- 1. PEMBUATAN TABEL DIMENSI (5 TABEL)
-- ==========================================

-- Tabel Dimensi Waktu (digunakan oleh semua fact)
CREATE TABLE dim_waktu (
    waktu_id SERIAL PRIMARY KEY,
    tahun_akademik VARCHAR(20) NOT NULL,  -- Contoh: '2023/2024'
    semester VARCHAR(10) NOT NULL         -- Contoh: 'Ganjil', 'Genap'
);

-- Tabel Dimensi Mahasiswa (digunakan oleh semua fact)
CREATE TABLE dim_mahasiswa (
    mahasiswa_id SERIAL PRIMARY KEY,
    nim VARCHAR(20) UNIQUE NOT NULL,
    nama VARCHAR(150) NOT NULL,
    jenis_kelamin VARCHAR(15) NOT NULL,   -- 'Laki-laki', 'Perempuan'
    angkatan INTEGER NOT NULL             -- Contoh: 2022
);

-- Tabel Dimensi Program Studi (hanya untuk fact_rekap_ip)
CREATE TABLE dim_program_studi (
    program_studi_id SERIAL PRIMARY KEY,
    jenjang VARCHAR(10) NOT NULL,         -- 'S1', 'S2', 'D4'
    nama_program_studi VARCHAR(100) NOT NULL,
    kelas VARCHAR(20) NOT NULL            -- 'Reguler', 'Internasional'
);

-- Tabel Dimensi Mata Kuliah (hanya untuk fact_detail_nilai)
CREATE TABLE dim_mata_kuliah (
    mata_kuliah_id SERIAL PRIMARY KEY,
    kode_mata_kuliah VARCHAR(20) UNIQUE NOT NULL,
    nama_mata_kuliah VARCHAR(150) NOT NULL,
    bobot_sks INTEGER NOT NULL,
    jenis_mata_kuliah VARCHAR(20) NOT NULL  -- 'Wajib', 'Pilihan'
);

-- Tabel Dimensi Kategori Buku (hanya untuk fact_rekap_pinjam)
CREATE TABLE dim_kategori_buku (
    kategori_id SERIAL PRIMARY KEY,
    nama_kategori VARCHAR(100) NOT NULL,    -- 'Textbook', 'Fiksi', 'Teknologi'
    deskripsi TEXT                          -- Penjelasan singkat kategori
);

-- ==========================================
-- 2. PEMBUATAN TABEL FAKTA (3 TABEL)
-- ==========================================

-- Tabel Fakta 1: Detail Nilai Akademik (per mahasiswa per semester per mata kuliah)
-- Dimensi: waktu, mahasiswa, mata_kuliah
CREATE TABLE fact_detail_nilai (
    waktu_id INTEGER NOT NULL,
    mahasiswa_id INTEGER NOT NULL,
    mata_kuliah_id INTEGER NOT NULL,
    
    -- Measurements
    nilai_angka DECIMAL(3,2),          -- Grade 0-4 (contoh: 3.50)
    status_lulus BOOLEAN,              -- TRUE = lulus, FALSE = tidak lulus
    bobot_nilai DECIMAL(5,2),          -- nilai_angka × bobot_sks
    
    -- Primary Key (Composite)
    PRIMARY KEY (waktu_id, mahasiswa_id, mata_kuliah_id),
    
    -- Foreign Keys
    CONSTRAINT fk_detail_nilai_waktu FOREIGN KEY (waktu_id) REFERENCES dim_waktu(waktu_id),
    CONSTRAINT fk_detail_nilai_mahasiswa FOREIGN KEY (mahasiswa_id) REFERENCES dim_mahasiswa(mahasiswa_id),
    CONSTRAINT fk_detail_nilai_matkul FOREIGN KEY (mata_kuliah_id) REFERENCES dim_mata_kuliah(mata_kuliah_id)
);

-- Tabel Fakta 2: Rekap IP Semester (per mahasiswa per semester)
-- Dimensi: waktu, program_studi, mahasiswa
CREATE TABLE fact_rekap_ip (
    waktu_id INTEGER NOT NULL,
    program_studi_id INTEGER NOT NULL,
    mahasiswa_id INTEGER NOT NULL,
    
    -- Measurements
    ip_semester DECIMAL(3,2),          -- Indeks Prestasi semester 0-4
    total_sks INTEGER,                 -- Total SKS yang ditempuh
    jumlah_mata_kuliah INTEGER,        -- Jumlah mata kuliah yang diambil
    
    -- Primary Key (Composite)
    PRIMARY KEY (waktu_id, mahasiswa_id),
    
    -- Foreign Keys
    CONSTRAINT fk_rekap_ip_waktu FOREIGN KEY (waktu_id) REFERENCES dim_waktu(waktu_id),
    CONSTRAINT fk_rekap_ip_prodi FOREIGN KEY (program_studi_id) REFERENCES dim_program_studi(program_studi_id),
    CONSTRAINT fk_rekap_ip_mahasiswa FOREIGN KEY (mahasiswa_id) REFERENCES dim_mahasiswa(mahasiswa_id)
);

-- Tabel Fakta 3: Rekap Peminjaman (per mahasiswa per semester per kategori)
-- Dimensi: waktu, mahasiswa, kategori_buku
CREATE TABLE fact_rekap_pinjam (
    waktu_id INTEGER NOT NULL,
    mahasiswa_id INTEGER NOT NULL,
    kategori_id INTEGER NOT NULL,
    
    -- Measurements
    total_peminjaman INTEGER DEFAULT 0,   -- Berapa kali pinjam dalam semester
    jumlah_denda INTEGER DEFAULT 0,       -- Total denda dalam Rupiah
    jumlah_buku INTEGER DEFAULT 0,        -- Jumlah judul buku unik yang dipinjam
    
    -- Primary Key (Composite)
    PRIMARY KEY (waktu_id, mahasiswa_id, kategori_id),
    
    -- Foreign Keys
    CONSTRAINT fk_pinjam_waktu FOREIGN KEY (waktu_id) REFERENCES dim_waktu(waktu_id),
    CONSTRAINT fk_pinjam_mahasiswa FOREIGN KEY (mahasiswa_id) REFERENCES dim_mahasiswa(mahasiswa_id),
    CONSTRAINT fk_pinjam_kategori FOREIGN KEY (kategori_id) REFERENCES dim_kategori_buku(kategori_id)
);

CREATE TABLE log_proses_etl (
    log_id SERIAL PRIMARY KEY,
    nama_proses VARCHAR(100) NOT NULL,
    waktu_mulai TIMESTAMP NOT NULL,
    waktu_selesai TIMESTAMP,
    durasi_detik INTEGER,
    status VARCHAR(20) NOT NULL, -- 'RUNNING', 'SUCCESS', 'FAILED'
    pesan_error text
);

-- ==========================================
-- 3. PEMBUATAN INDEX UNTUK OPTIMASI QUERY
-- ==========================================

-- Index untuk fact_detail_nilai
CREATE INDEX idx_fdn_waktu ON fact_detail_nilai(waktu_id);
CREATE INDEX idx_fdn_mahasiswa ON fact_detail_nilai(mahasiswa_id);
CREATE INDEX idx_fdn_matkul ON fact_detail_nilai(mata_kuliah_id);
CREATE INDEX idx_fdn_mhs_waktu ON fact_detail_nilai(mahasiswa_id, waktu_id);
CREATE INDEX idx_fdn_status ON fact_detail_nilai(status_lulus);

-- Index untuk fact_rekap_ip
CREATE INDEX idx_fri_waktu ON fact_rekap_ip(waktu_id);
CREATE INDEX idx_fri_prodi ON fact_rekap_ip(program_studi_id);
CREATE INDEX idx_fri_mahasiswa ON fact_rekap_ip(mahasiswa_id);
CREATE INDEX idx_fri_mhs_waktu ON fact_rekap_ip(mahasiswa_id, waktu_id);
CREATE INDEX idx_fri_ip ON fact_rekap_ip(ip_semester);

-- Index untuk fact_rekap_pinjam
CREATE INDEX idx_fsp_waktu ON fact_rekap_pinjam(waktu_id);
CREATE INDEX idx_fsp_mahasiswa ON fact_rekap_pinjam(mahasiswa_id);
CREATE INDEX idx_fsp_kategori ON fact_rekap_pinjam(kategori_id);
CREATE INDEX idx_fsp_mhs_waktu ON fact_rekap_pinjam(mahasiswa_id, waktu_id);
CREATE INDEX idx_fsp_total_pinjam ON fact_rekap_pinjam(total_peminjaman);

-- Index untuk dimensi (filtering)
CREATE INDEX idx_dim_waktu_semester ON dim_waktu(tahun_akademik, semester);
CREATE INDEX idx_dim_mhs_angkatan ON dim_mahasiswa(angkatan);
CREATE INDEX idx_dim_mhs_kelamin ON dim_mahasiswa(jenis_kelamin);
CREATE INDEX idx_dim_prodi_nama ON dim_program_studi(nama_program_studi);
CREATE INDEX idx_dim_matkul_kode ON dim_mata_kuliah(kode_mata_kuliah);
CREATE INDEX idx_dim_kategori_nama ON dim_kategori_buku(nama_kategori);

CREATE INDEX idx_log_etl_waktu ON log_proses_etl(waktu_mulai DESC);