-- ANALISIS AKADEMIK

-- 1. Mata kuliah apa yang memiliki tingkat ketidaklulusan tertinggi?
-- Query ini menghitung persentase ketidaklulusan per mata kuliah dan diurutkan dari yang paling banyak mahasiswa gagalnya.
-- Menghasilkan juga pemeringkatan (ranking) otomatis untuk melihat top mata kuliah yang paling kritis.
CREATE MATERIALIZED VIEW mv_tingkat_ketidaklulusan AS
WITH BaseHitung AS (
    SELECT 
        dmk.kode_mata_kuliah,
        dmk.nama_mata_kuliah,
        COUNT(fdn.mahasiswa_id) AS total_mahasiswa_mengambil,
        SUM(CASE WHEN fdn.status_lulus = FALSE THEN 1 ELSE 0 END) AS total_tidak_lulus,
        ROUND((SUM(CASE WHEN fdn.status_lulus = FALSE THEN 1 ELSE 0 END) * 100.0) / COUNT(fdn.mahasiswa_id), 2) AS persentase_tidak_lulus
    FROM fact_detail_nilai fdn
    JOIN dim_mata_kuliah dmk ON fdn.mata_kuliah_id = dmk.mata_kuliah_id
    GROUP BY dmk.kode_mata_kuliah, dmk.nama_mata_kuliah
)
SELECT 
    kode_mata_kuliah,
    nama_mata_kuliah,
    total_mahasiswa_mengambil,
    total_tidak_lulus,
    persentase_tidak_lulus,
    DENSE_RANK() OVER (ORDER BY persentase_tidak_lulus DESC) AS peringkat_kritis
FROM BaseHitung;

-- tampilkan tabel
select * from mv_tingkat_ketidaklulusan;

-- 2. Bagaimana tren performa akademik mahasiswa per semester?
-- Query ini menampilkan tren performa akademik mahasiswa per semester,
-- sekaligus menyertakan baris rekapitulasi (sub-total) performa per tahun akademik dan total keseluruhan (grand total).
CREATE VIEW v_tren_performa_akademik AS
SELECT 
    COALESCE(CAST(dw.tahun_akademik AS TEXT), 'Semua Tahun (Grand Total)') AS tahun_akademik,
    COALESCE(CAST(dw.semester AS TEXT), 'Semua Semester (Sub-Total)') AS semester,
    COUNT(DISTINCT fri.mahasiswa_id) AS total_mahasiswa_aktif,
    ROUND(AVG(fri.ip_semester), 2) AS rata_rata_ip_semester
FROM fact_rekap_ip fri
JOIN dim_waktu dw ON fri.waktu_id = dw.waktu_id
GROUP BY ROLLUP (dw.tahun_akademik, dw.semester)
ORDER BY dw.tahun_akademik ASC, dw.semester DESC;

-- tampilkan tabel
select * from v_tren_performa_akademik;

-- 3. Apakah mahasiswa reguler dan internasional memiliki perbedaan performa?
-- Query ini membandingkan rata-rata IPK berdasarkan kelas (Reguler/Internasional),
-- dilengkapi dengan baris grand total untuk melihat rata-rata IPK keseluruhan populasi.
CREATE MATERIALIZED VIEW mv_perbandingan_kelas_reguler_inter AS
SELECT 
    COALESCE(dps.kelas, 'Grand Total Keseluruhan') AS kelas,
    COUNT(DISTINCT fri.mahasiswa_id) AS populasi_mahasiswa,
    ROUND(AVG(fri.ip_semester), 2) AS rata_rata_ipk_keseluruhan
FROM fact_rekap_ip fri
JOIN dim_program_studi dps ON fri.program_studi_id = dps.program_studi_id
GROUP BY GROUPING SETS (
    (dps.kelas), 
    ()
)
ORDER BY rata_rata_ipk_keseluruhan DESC;

-- tampilkan tabel
select * from mv_perbandingan_kelas_reguler_inter;

-- ANALISIS TAMBAHAN PADA AKADEMIK

-- Analisis cohort tren performa akademik berdasarkan angkatan masuk
-- Analisis ini ditujukan untuk mengevaluasi apakah kualitas input mahasiswa (berdasarkan tahun angkatan)
-- mengalami peningkatan atau penurunan kualitas seiring berjalannya semester. Menghasilkan semua kemungkinan
-- kombinasi agregasi (angkatan, tahun akademik, semester) dalam satu view.
CREATE MATERIALIZED VIEW mv_analisis_cohort_angkatan AS
SELECT 
    COALESCE(CAST(dm.angkatan AS TEXT), 'Semua Angkatan') AS angkatan,
    COALESCE(CAST(dw.tahun_akademik AS TEXT), 'Semua Tahun') AS tahun_akademik,
    COALESCE(CAST(dw.semester AS TEXT), 'Semua Semester') AS semester,
    COUNT(DISTINCT fri.mahasiswa_id) AS jumlah_mahasiswa_aktif,
    ROUND(AVG(fri.ip_semester), 2) AS rata_rata_ip_angkatan,
    ROUND(AVG(fri.total_sks), 0) AS rata_rata_sks_diambil
FROM fact_rekap_ip fri
JOIN dim_mahasiswa dm ON fri.mahasiswa_id = dm.mahasiswa_id
JOIN dim_waktu dw ON fri.waktu_id = dw.waktu_id
GROUP BY CUBE (dm.angkatan, dw.tahun_akademik, dw.semester)
ORDER BY dm.angkatan DESC, dw.tahun_akademik ASC, dw.semester DESC;

-- tampilkan tabel
select * from mv_analisis_cohort_angkatan;

-- Analisis kritis mata kuliah pembunuh (killer course) spesifik per angkatan.
-- Analisis ini sebagai bentuk analisis mendalam (drill-down) yang menghubungkan fact_detail_nilai, 
-- dim_mahasiswa, dan dim_mata_kuliah. Tujuannya untuk melihat mata kuliah apa yang paling banyak 
-- membuat mahasiswa dari angkatan terbaru gagal, dipisahkan berdasarkan ranking dalam masing-masing angkatan.
CREATE MATERIALIZED VIEW mv_evaluasi_matkul_angkatan_kritis AS
WITH EvaluasiMatkul AS (
    SELECT 
        dm.angkatan,
        dmk.nama_mata_kuliah,
        dmk.jenis_mata_kuliah,
        COUNT(fdn.mahasiswa_id) AS total_pengambil,
        SUM(CASE WHEN fdn.status_lulus = FALSE THEN 1 ELSE 0 END) AS total_gagal,
        ROUND((SUM(CASE WHEN fdn.status_lulus = FALSE THEN 1 ELSE 0 END) * 100.0) / COUNT(fdn.mahasiswa_id), 2) AS persen_gagal
    FROM fact_detail_nilai fdn
    JOIN dim_mahasiswa dm ON fdn.mahasiswa_id = dm.mahasiswa_id
    JOIN dim_mata_kuliah dmk ON fdn.mata_kuliah_id = dmk.mata_kuliah_id
    GROUP BY dm.angkatan, dmk.nama_mata_kuliah, dmk.jenis_mata_kuliah
    HAVING COUNT(fdn.mahasiswa_id) > 10
)
SELECT 
    angkatan,
    nama_mata_kuliah,
    jenis_mata_kuliah,
    total_pengambil,
    total_gagal,
    persen_gagal,
    ROW_NUMBER() OVER (PARTITION BY angkatan ORDER BY persen_gagal DESC) AS ranking_matkul_kritis_angkatan
FROM EvaluasiMatkul;

-- tampilkan tabel
select * from mv_evaluasi_matkul_angkatan_kritis;

-- ANALISIS PERPUSTAKAAN

-- 1. Kategori buku apa yang paling banyak dipinjam mahasiswa?
-- Query ini menghitung frekuensi peminjaman tiap kategori dan langsung 
-- menyematkan urutan peringkat kepopuleran kategorinya.
CREATE MATERIALIZED VIEW mv_kategori_buku_populer AS
WITH RekapBuku AS (
    SELECT 
        dkb.nama_kategori,
        SUM(frp.total_peminjaman) AS frekuensi_peminjaman,
        SUM(frp.jumlah_buku) AS total_judul_buku_unik_dipinjam
    FROM fact_rekap_pinjam frp
    JOIN dim_kategori_buku dkb ON frp.kategori_id = dkb.kategori_id
    GROUP BY dkb.nama_kategori
)
SELECT 
    nama_kategori,
    frekuensi_peminjaman,
    total_judul_buku_unik_dipinjam,
    RANK() OVER (ORDER BY frekuensi_peminjaman DESC) AS peringkat_popularitas
FROM RekapBuku;

-- tampilkan tabel
select * from mv_kategori_buku_populer;

-- 2. Bagaimana pola peminjaman buku dari semester ke semester?
-- Menampilkan tren total transaksi peminjaman dan denda berdasarkan waktu (semester),
-- otomatis menampilkan sub-total per tahun akademik agar memudahkan rekapitulasi data.
CREATE VIEW v_tren_peminjaman_semester AS
SELECT 
    COALESCE(CAST(dw.tahun_akademik AS TEXT), 'Total Semua Waktu') AS tahun_akademik,
    COALESCE(CAST(dw.semester AS TEXT), 'Sub-Total Tahun') AS semester,
    SUM(frp.total_peminjaman) AS total_transaksi_pinjam,
    SUM(frp.jumlah_denda) AS total_denda_rp
FROM fact_rekap_pinjam frp
JOIN dim_waktu dw ON frp.waktu_id = dw.waktu_id
GROUP BY ROLLUP (dw.tahun_akademik, dw.semester)
ORDER BY dw.tahun_akademik ASC, dw.semester DESC;

-- tampilkan tabel
select * from v_tren_peminjaman_semester;

-- ANALISIS KORELASI AKADEMIK DAN PERPUSTAKAAN

-- 1. Apakah mahasiswa yang rajin meminjam buku memiliki IPK lebih tinggi?
-- Query ini mengelompokkan mahasiswa menjadi 3 tier (Rajin, Jarang, Tidak Pernah) pada setiap semester,
-- lalu melihat rata-rata IP-nya. Dilengkapi dengan grand total sebagai standar rata-rata populasi.
CREATE MATERIALIZED VIEW mv_korelasi_rajin_pinjam_ip AS
WITH aktivitas_mahasiswa AS (
    SELECT 
        fri.waktu_id,
        fri.mahasiswa_id,
        fri.ip_semester,
        COALESCE(SUM(frp.total_peminjaman), 0) AS total_pinjam_semester
    FROM fact_rekap_ip fri
    LEFT JOIN fact_rekap_pinjam frp 
        ON fri.mahasiswa_id = frp.mahasiswa_id 
        AND fri.waktu_id = frp.waktu_id
    GROUP BY fri.waktu_id, fri.mahasiswa_id, fri.ip_semester
),
klasifikasi_tier AS (
    SELECT 
        CASE 
            WHEN total_pinjam_semester = 0 THEN '1 - Tidak Pernah Pinjam'
            WHEN total_pinjam_semester BETWEEN 1 AND 5 THEN '2 - Jarang (1-5 Buku/Semester)'
            ELSE '3 - Rajin (>5 Buku/Semester)'
        END AS klasifikasi_peminjam,
        mahasiswa_id,
        ip_semester
    FROM aktivitas_mahasiswa
)
SELECT 
    COALESCE(klasifikasi_peminjam, 'Grand Total Populasi') AS klasifikasi_peminjam,
    COUNT(mahasiswa_id) AS total_sampel_semester,
    ROUND(AVG(ip_semester), 2) AS rata_rata_ip_semester
FROM klasifikasi_tier
GROUP BY GROUPING SETS ((klasifikasi_peminjam), ())
ORDER BY klasifikasi_peminjam ASC;

-- tampilkan tabel
select * from mv_korelasi_rajin_pinjam_ip;

SELECT
    CASE
        WHEN ip_semester >= 3.51 THEN 'Cumlaude (3.51 - 4.00)'
        WHEN ip_semester >= 3.01 THEN 'Sangat Memuaskan (3.01 - 3.50)'
        WHEN ip_semester >= 2.51 THEN 'Memuaskan (2.51 - 3.00)'
        WHEN ip_semester >= 2.00 THEN 'Cukup (2.00 - 2.50)'
        ELSE                          'Kurang (< 2.00)'
    END AS kategori_ip,
    COUNT(*) AS jumlah_mahasiswa,
    ROUND(count(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS persentase
FROM fact_rekap_ip
GROUP BY kategori_ip
ORDER BY MIN(ip_semester) DESC;

-- 2. Apakah mahasiswa yang sering kena denda cenderung memiliki nilai lebih rendah?
-- Membandingkan kedisiplinan pengembalian perpustakaan (kena denda vs tidak) terhadap
-- capaian nilai IP semester mahasiswa secara komparatif dengan angka rata-rata umum (Grand Total).
CREATE MATERIALIZED VIEW mv_korelasi_denda_ip AS
WITH rekap_denda AS (
    SELECT 
        fri.waktu_id,
        fri.mahasiswa_id,
        fri.ip_semester,
        COALESCE(SUM(frp.jumlah_denda), 0) AS denda_semester
    FROM fact_rekap_ip fri
    LEFT JOIN fact_rekap_pinjam frp 
        ON fri.mahasiswa_id = frp.mahasiswa_id 
        AND fri.waktu_id = frp.waktu_id
    GROUP BY fri.waktu_id, fri.mahasiswa_id, fri.ip_semester
),
status_denda AS (
    SELECT 
        CASE 
            WHEN denda_semester = 0 THEN 'Disiplin (Tanpa Denda)'
            ELSE 'Pernah Terlambat (Kena Denda)'
        END AS status_kedisiplinan_perpus,
        mahasiswa_id,
        ip_semester
    FROM rekap_denda
)
SELECT 
    COALESCE(status_kedisiplinan_perpus, 'Rata-rata Keseluruhan Mahasiswa') AS status_kedisiplinan_perpus,
    COUNT(mahasiswa_id) AS total_sampel,
    ROUND(AVG(ip_semester), 2) AS rata_rata_ip_semester
FROM status_denda
GROUP BY GROUPING SETS ((status_kedisiplinan_perpus), ())
ORDER BY status_kedisiplinan_perpus;

-- tampilkan tabel
select * from mv_korelasi_denda_ip;

-- 3. Kategori buku apa yang paling banyak dipinjam oleh mahasiswa berprestasi?
-- Query ini menampilkan dan memeringkatkan (ranking) kategori buku yang paling banyak dipinjam 
-- oleh mahasiswa berprestasi (dengan asumsi mahasiswa berprestasi memiliki IP semester minimal 3.50).
CREATE MATERIALIZED VIEW mv_buku_favorit_mahasiswa_berprestasi AS
WITH FavoritBerprestasi AS (
    SELECT 
        dkb.nama_kategori,
        SUM(frp.total_peminjaman) AS total_peminjaman
    FROM fact_rekap_pinjam frp
    JOIN fact_rekap_ip fri 
        ON frp.mahasiswa_id = fri.mahasiswa_id 
        AND frp.waktu_id = fri.waktu_id
    JOIN dim_kategori_buku dkb 
        ON frp.kategori_id = dkb.kategori_id
    WHERE fri.ip_semester >= 3.50 
    GROUP BY dkb.nama_kategori
)
SELECT 
    nama_kategori,
    total_peminjaman,
    DENSE_RANK() OVER (ORDER BY total_peminjaman DESC) AS peringkat_buku_berprestasi
FROM FavoritBerprestasi;

-- tampilkan tabel
select * from mv_buku_favorit_mahasiswa_berprestasi;

-- ANALISIS TAMBAHAN:
-- Analisis Demografi: Perbandingan Performa Akademik & Literasi Berdasarkan Jenis Kelamin
-- Analisis ini menyatukan dua fact table (fact_rekap_ip dan fact_rekap_pinjam) dengan dim_mahasiswa 
-- untuk melihat apakah ada pola perbedaan kedisiplinan dan nilai akademik antara laki-laki dan perempuan,
-- menggunakan GROUPING SETS untuk menghasilkan baris komparasi akhir (Total Keseluruhan).
CREATE MATERIALIZED VIEW mv_analisis_gender_akademik_perpus AS
WITH rekap_akademik AS (
    SELECT mahasiswa_id, AVG(ip_semester) as avg_ip
    FROM fact_rekap_ip
    GROUP BY mahasiswa_id
),
rekap_perpus AS (
    SELECT mahasiswa_id, SUM(total_peminjaman) as total_pinjam, SUM(jumlah_denda) as total_denda
    FROM fact_rekap_pinjam
    GROUP BY mahasiswa_id
)
SELECT 
    COALESCE(dm.jenis_kelamin, 'Semua Demografi (Total)') AS jenis_kelamin,
    COUNT(dm.mahasiswa_id) AS total_mahasiswa,
    ROUND(AVG(ra.avg_ip), 2) AS rata_rata_ipk,
    COALESCE(SUM(rp.total_pinjam), 0) AS total_buku_dipinjam,
    COALESCE(SUM(rp.total_denda), 0) AS total_akumulasi_denda_rp
FROM dim_mahasiswa dm
LEFT JOIN rekap_akademik ra ON dm.mahasiswa_id = ra.mahasiswa_id
LEFT JOIN rekap_perpus rp ON dm.mahasiswa_id = rp.mahasiswa_id
GROUP BY GROUPING SETS (
    (dm.jenis_kelamin), 
    ()
);

-- tampilkan tabel
select * from mv_analisis_gender_akademik_perpus;