\echo '========================================================================'
\echo '1. Tingkat Ketidaklulusan Mata Kuliah'
\echo '========================================================================'
SELECT * FROM mv_tingkat_ketidaklulusan LIMIT 10;

\echo '========================================================================'
\echo '2. Tren Performa Akademik per Semester'
\echo '========================================================================'
SELECT * FROM v_tren_performa_akademik;

\echo '========================================================================'
\echo '3. Perbandingan Performa Berdasarkan Kelas'
\echo '========================================================================'
SELECT * FROM mv_perbandingan_kelas_reguler_inter;

\echo '========================================================================'
\echo '4. Cohort Performa Berdasarkan Angkatan'
\echo '========================================================================'
SELECT * FROM mv_analisis_cohort_angkatan;

\echo '========================================================================'
\echo '5. Mata Kuliah Kritis per Angkatan'
\echo '========================================================================'
SELECT * FROM mv_evaluasi_matkul_angkatan_kritis LIMIT 10;

\echo '========================================================================'
\echo '6. Kategori Buku Paling Populer'
\echo '========================================================================'
SELECT * FROM mv_kategori_buku_populer;

\echo '========================================================================'
\echo '7. Tren Peminjaman dan Denda per Semester'
\echo '========================================================================'
SELECT * FROM v_tren_peminjaman_semester;

\echo '========================================================================'
\echo '8. Hubungan Intensitas Peminjaman dengan IP Semester'
\echo '========================================================================'
SELECT * FROM mv_korelasi_rajin_pinjam_ip;

\echo '========================================================================'
\echo '9. Query Diagnostik Distribusi IP'
\echo '========================================================================'
SELECT
    CASE
        WHEN ip_semester >= 3.51 THEN 'Cumlaude (3.51 - 4.00)'
        WHEN ip_semester >= 3.01 THEN 'Sangat Memuaskan (3.01 - 3.50)'
        WHEN ip_semester >= 2.51 THEN 'Memuaskan (2.51 - 3.00)'
        WHEN ip_semester >= 2.00 THEN 'Cukup (2.00 - 2.50)'
        ELSE                          'Kurang (< 2.00)'
    END AS kategori_ip,
    COUNT(*) AS jumlah_mahasiswa,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS persentase
FROM fact_rekap_ip
GROUP BY kategori_ip
ORDER BY MIN(ip_semester) DESC;

\echo '========================================================================'
\echo '10. Hubungan Denda dengan IP Semester'
\echo '========================================================================'
SELECT * FROM mv_korelasi_denda_ip;

\echo '========================================================================'
\echo '11. Buku Favorit Mahasiswa Berprestasi'
\echo '========================================================================'
SELECT * FROM mv_buku_favorit_mahasiswa_berprestasi;

\echo '========================================================================'
\echo '12. Perbandingan Akademik dan Aktivitas Perpustakaan Berdasarkan Gender'
\echo '========================================================================'
SELECT * FROM mv_analisis_gender_akademik_perpus;