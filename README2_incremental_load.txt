README2 --- Incremental Load
Kelanjutan dari README1 --- Initial Load
(Panduan Simulasi Penambahan Data Baru)

Dokumentasi ini merupakan kelanjutan langsung dari README1 --- Initial Load. Langkah-langkah di bawah ini digunakan untuk mensimulasikan masuknya data operasional baru (data incremental) pada database akademik dan perpustakaan, serta bagaimana Data Warehouse memperbarui datanya.

===============================================================================================

1. Simulasi Pemasukan Data Operasional Baru
A. Copy files dump ke dalam container:
docker cp "incremental_akademik1.dump" db_akademik:/tmp/dump1.dump
docker cp "incremental_akademik2.dump" db_akademik:/tmp/dump2.dump
docker cp "incremental_perpus1.dump" db_perpus:/tmp/dump1.dump
docker cp "incremental_perpus2.dump" db_perpus:/tmp/dump2.dump
docker cp "incremental_perpus3.dump" db_perpus:/tmp/dump3.dump

B. Import data akademik:
docker exec -it db_akademik pg_restore -U user -d db_akademik /tmp/dump1.dump
docker exec -it db_akademik pg_restore -U user -d db_akademik /tmp/dump2.dump

C. Import data perpustakaan:
docker exec -it db_perpus pg_restore -U user -d db_perpus /tmp/dump1.dump
docker exec -it db_perpus pg_restore -U user -d db_perpus /tmp/dump2.dump
docker exec -it db_perpus pg_restore -U user -d db_perpus /tmp/dump3.dump

===============================================================================================

2. Sinkronisasi Data Warehouse (Proses ETL Incremental)
Untuk memproses data baru yang telah masuk ke dalam Data Warehouse, dapat dipilih salah satu dari dua metode di bawah ini:

-----------------------------------------------------------------------------------------------

OPSI A: Eksekusi Otomatis (Menggunakan pg_cron)
Secara bawaan, sistem telah dikonfigurasi untuk melakukan refreshment load otomatis menggunakan scheduler pg_cron.

Memeriksa riwayat eksekusi otomatis (cron job):
docker exec -it db_dw psql -U user -d DWakadperpus -P pager=off -c "SELECT * FROM cron.job_run_details ORDER BY start_time DESC;"

Memeriksa daftar jadwal (schedule) cron yang aktif:
docker exec -it db_dw psql -U user -d DWakadperpus -P pager=off -c "SELECT * FROM cron.job;"

Catatan: Docker Compose telah mengatur timezone PostgreSQL dan pg_cron ke Asia/Jakarta (WIB). Untuk validasi, jalankan:
docker exec -it db_dw psql -U user -d DWakadperpus -c "SHOW timezone; SHOW cron.timezone; SELECT now();"

-----------------------------------------------------------------------------------------------

OPSI B: Eksekusi Manual (Tanpa Menunggu Jadwal Cron)
Jika ingin melakukan pembaruan data secara instan untuk kebutuhan demo, jalankan Stored Procedure berikut ini secara berurutan pada database db_dw:
docker exec -it db_dw psql -U user -d DWakadperpus -c "CALL sp_load_shared_dimensions();"
docker exec -it db_dw psql -U user -d DWakadperpus -c "CALL sp_load_perpus_dw();"
docker exec -it db_dw psql -U user -d DWakadperpus -c "CALL sp_build_cross_domain_facts();"
docker exec -it db_dw psql -U user -d DWakadperpus -c "CALL sp_load_akademik_dw();"
docker exec -it db_dw psql -U user -d DWakadperpus -c "CALL sp_refresh_semua_dashboard_dw();"

===============================================================================================

3. Monitoring ETL dan Eksplorasi Hasil Analisis

A. Copy script monitoring dan analisis ke container db_dw:
docker cp "monitoring_etl.sql" db_dw:/tmp/monitoring_etl.sql
docker cp "hasil_analisis.sql" db_dw:/tmp/hasil_analisis.sql

B. Memeriksa Log Proses ETL
docker exec -it db_dw psql -U user -d DWakadperpus -P pager=off -f /tmp/monitoring_etl.sql

C. Menampilkan Hasil Analisis
docker exec -it db_dw psql -U user -d DWakadperpus -P pager=off -f /tmp/hasil_analisis.sql

===============================================================================================

Validasi Jumlah Data Akhir
Guna memastikan seluruh data baru telah terserap sempurna tanpa ada data loss, pastikan jumlah baris data sesuai dengan hasil di bawah ini.

-----------------------------------------------------------------------------
Jalankan pada db_akademik:
-----------------------------------------------------------------------------

SELECT 'detail_nilai' AS tabel, COUNT(*) AS total FROM detail_nilai
UNION ALL
SELECT 'hasil_studi' AS tabel, COUNT(*) AS total FROM hasil_studi
UNION ALL
SELECT 'mahasiswa' AS tabel, COUNT(*) AS total FROM mahasiswa
UNION ALL
SELECT 'mata_kuliah' AS tabel, COUNT(*) AS total FROM mata_kuliah
UNION ALL
SELECT 'program_studi' AS tabel, COUNT(*) AS total FROM program_studi;

-----------------------------------------------------------------------------
Jalankan pada db_perpus:
-----------------------------------------------------------------------------

SELECT 'anggota' AS tabel, COUNT(*) AS total FROM anggota
UNION ALL
SELECT 'buku' AS tabel, COUNT(*) AS total FROM buku
UNION ALL
SELECT 'denda' AS tabel, COUNT(*) AS total FROM denda
UNION ALL
SELECT 'detail_peminjaman' AS tabel, COUNT(*) AS total FROM detail_peminjaman
UNION ALL
SELECT 'eksemplar_buku' AS tabel, COUNT(*) AS total FROM eksemplar_buku
UNION ALL
SELECT 'kategori_buku' AS tabel, COUNT(*) AS total FROM kategori_buku
UNION ALL
SELECT 'kunjungan' AS tabel, COUNT(*) AS total FROM kunjungan
UNION ALL
SELECT 'peminjaman' AS tabel, COUNT(*) AS total FROM peminjaman;

-----------------------------------------------------------------------------
Jalankan pada Data Warehouse:
-----------------------------------------------------------------------------

SELECT 'dim_kategori_buku' AS tabel, COUNT(*) AS total FROM dim_kategori_buku
UNION ALL
SELECT 'dim_mahasiswa' AS tabel, COUNT(*) AS total FROM dim_mahasiswa
UNION ALL
SELECT 'dim_mata_kuliah' AS tabel, COUNT(*) AS total FROM dim_mata_kuliah
UNION ALL
SELECT 'dim_program_studi' AS tabel, COUNT(*) AS total FROM dim_program_studi
UNION ALL
SELECT 'dim_waktu' AS tabel, COUNT(*) AS total FROM dim_waktu
UNION ALL
SELECT 'fact_detail_nilai' AS tabel, COUNT(*) AS total FROM fact_detail_nilai
UNION ALL
SELECT 'fact_rekap_ip' AS tabel, COUNT(*) AS total FROM fact_rekap_ip
UNION ALL
SELECT 'fact_rekap_pinjam' AS tabel, COUNT(*) AS total FROM fact_rekap_pinjam
ORDER BY tabel ASC;

-----------------------------------------------------------------------------
Output yang diharapkan:
-----------------------------------------------------------------------------
Data Akademik:				| Data Perpustakaan:
detail_nilai 	= 473,373	 	| anggota 		= 12,000
hasil_studi 	= 67,218	 	| buku 			= 600
mahasiswa 	= 12,000	 	| denda 		= 38,140
mata_kuliah 	= 200		 	| detail_peminjaman 	= 362,362
program_studi 	= 10		 	| eksemplar_buku 	= 2,386
----------------------------------------| kategori_buku 	= 12
Data Warehouse:			 	| kunjungan 		= 1,657,190
dim_kategori_buku 	= 12	 	| peminjaman 		= 181,080
dim_mahasiswa 		= 12,000 	|
dim_mata_kuliah 	= 200	 	|
dim_program_studi 	= 10	 	|
dim_waktu 		= 10	 	|
fact_detail_nilai 	= 402,668	|
fact_rekap_ip 		= 57,194	|
fact_rekap_pinjam 	= 204,142	|
-----------------------------------------------------------------------------

