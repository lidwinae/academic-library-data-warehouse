README1 --- Initial Load

1. Pastikan Docker Desktop / Engine sudah aktif.

2. Download semua file dalam folder drive ini ke dalam satu file folder / direktori yang sama. Setelah itu, jalankan terminal pada direktori ini.

3. Jalankan Docker Compose (untuk pertama kali setup saja):
docker compose up -d --build

Setelah setup awal selesai, untuk menjalankan ulang cukup:
docker compose up -d

4. Copy files ke container untuk proses yang lebih cepat:
docker cp "dump-db_akademik.dump" db_akademik:/tmp/dump.dump
docker cp "dump-db_perpus.dump" db_perpus:/tmp/dump.dump
docker cp "dump-db_dw.dump" db_dw:/tmp/dump.dump

5. Import data akademik:
docker exec -it db_akademik pg_restore -U user -d db_akademik /tmp/dump.dump

6. Import data perpustakaan:
docker exec -it db_perpus pg_restore -U user -d db_perpus /tmp/dump.dump

7. Import Struktur Data Warehouse:
docker exec -it db_dw pg_restore -U user -d DWakadperpus /tmp/dump.dump

8. EKSEKUSI PROSES ETL (Initial Load):
docker exec -it db_dw psql -U user -d DWakadperpus -c "CALL sp_initial_load_dw();"

9. Jika ingin reset total dan menjalankan ulang dari awal:
docker compose down -v
docker compose up -d --build

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
detail_nilai 	= 353,331		| anggota 		= 10,000
hasil_studi 	= 50,194		| buku 			= 500
mahasiswa 	= 10,000		| denda 		= 31,390
mata_kuliah 	= 200			| detail_peminjaman 	= 288,619
program_studi 	= 10			| eksemplar_buku 	= 1955
----------------------------------------| kategori_buku 	= 12
Data Warehouse:				| kunjungan 		= 1,327,646
dim_kategori_buku 	= 12		| peminjaman 		= 144,194
dim_mahasiswa 		= 10,000	|
dim_mata_kuliah 	= 200		|
dim_program_studi 	= 10		|
dim_waktu 		= 9		|
fact_detail_nilai 	= 353,331	|
fact_rekap_ip 		= 50,194	|
fact_rekap_pinjam 	= 162,989	|
-----------------------------------------------------------------------------

