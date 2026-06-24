-- ======================================================================
-- SCHEDULING ETL DATA WAREHOUSE MENGGUNAKAN PG_CRON
-- Urutan eksekusi diatur menggunakan jeda waktu (time-based sequencing)
-- ======================================================================

-- (Opsional) Hapus job lama jika Anda sedang mereset/menimpa jadwal
-- SELECT cron.unschedule('job_etl_01_dim_shared');
-- SELECT cron.unschedule('job_etl_02_dim_perpus');
-- SELECT cron.unschedule('job_etl_03_fact_perpus');
-- SELECT cron.unschedule('job_etl_04_all_akademik');
-- SELECT cron.unschedule('job_etl_refresh_dw_harian');

-- ----------------------------------------------------------------------
-- TAHAP 1: EKSEKUSI PUKUL 01:00 PAGI (Setiap Hari)
-- Mengambil data dimensi fundamental (waktu & mahasiswa) terlebih dahulu 
-- agar tidak terjadi Foreign Key error di tabel fakta.
-- ----------------------------------------------------------------------
SELECT cron.schedule(
    'job_etl_01_dim_shared',
    '0 1 * * *',
    'CALL sp_load_shared_dimensions();'
);

-- ----------------------------------------------------------------------
-- TAHAP 2: EKSEKUSI PUKUL 01:10 PAGI (Setiap Hari)
-- Jeda 10 menit. Mengambil dimensi spesifik perpustakaan (kategori buku).
-- ----------------------------------------------------------------------
SELECT cron.schedule(
    'job_etl_02_dim_perpus',
    '10 1 * * *',
    'CALL sp_load_perpus_dw();'
);

-- ----------------------------------------------------------------------
-- TAHAP 3: EKSEKUSI PUKUL 01:20 PAGI (Setiap Hari)
-- Jeda 10 menit dari dimensi perpus. Menghitung ulang fakta peminjaman
-- dan denda harian yang bergantung pada dimensi yang sudah ter-load.
-- ----------------------------------------------------------------------
SELECT cron.schedule(
    'job_etl_03_fact_perpus',
    '20 1 * * *',
    'CALL sp_build_cross_domain_facts();'
);

-- ----------------------------------------------------------------------
-- TAHAP 4: EKSEKUSI PUKUL 01:30 PAGI (Setiap Hari)
-- Jeda 10 menit. Memuat data nilai & IP mahasiswa. 
-- Meskipun data akademik biasanya baru ada tiap akhir semester, menjadwalkan
-- ini secara harian adalah praktik yang aman. SP ini sudah memiliki 
-- guard clause (pengecekan semester), sehingga jika tidak ada semester baru, 
-- SP ini hanya akan memakan waktu nol koma sekian detik lalu berhenti.
-- Semisalnya jika ada kasus pihak kampus tiba-tiba memutuskan untuk menginput
-- nilai semester sisipan/pendek, cron ini akan langsung dieksekusi
-- keesokan harinya secara otomatis tanpa perlu campur tangan manual.
-- ----------------------------------------------------------------------
SELECT cron.schedule(
    'job_etl_04_all_akademik',
    '30 1 * * *',
    'CALL sp_load_akademik_dw();'
);

-- ----------------------------------------------------------------------
-- TAHAP 5: EKSEKUSI PUKUL 02:00 PAGI (Setiap Hari)
-- Puncak dari ETL. Diberi jeda 30 menit (pukul 2 pagi pas) untuk memastikan
-- seluruh proses Tahap 1 s/d 4 benar-benar sudah selesai (commit). 
-- View di-refresh agar dashboard di pagi hari menampilkan data terbaru.
-- Dashboard ini ditujukan untuk menampilkan tabel hasil analisis
-- ----------------------------------------------------------------------
SELECT cron.schedule(
    'job_etl_05_refresh_mv',
    '0 2 * * *',
    'CALL sp_refresh_semua_dashboard_dw();'
);