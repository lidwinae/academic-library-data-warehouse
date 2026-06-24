CREATE OR REPLACE PROCEDURE sp_initial_load_dw()
LANGUAGE plpgsql
AS $$
DECLARE
    v_log_id INTEGER;
    v_waktu_mulai TIMESTAMP;
    v_waktu_selesai TIMESTAMP;
    v_durasi INTEGER;
    v_row_count INTEGER;
BEGIN
    -- ==========================================
    -- 1. LOG AWAL
    -- ==========================================
    v_waktu_mulai := NOW();
    
    INSERT INTO log_proses_etl (nama_proses, waktu_mulai, status)
    VALUES ('Initial Load Data Warehouse', v_waktu_mulai, 'RUNNING')
    RETURNING log_id INTO v_log_id;
    
    RAISE NOTICE '=== INITIAL LOAD DATA WAREHOUSE ===';
    
    -- ==========================================
    -- 2. TRUNCATE TABEL (KOSONGKAN DULU)
    -- ==========================================
    
    RAISE NOTICE '1. Mengosongkan tabel yang ada...';
    
    TRUNCATE TABLE fact_rekap_pinjam CASCADE;
    TRUNCATE TABLE fact_rekap_ip CASCADE;
    TRUNCATE TABLE fact_detail_nilai CASCADE;
    TRUNCATE TABLE dim_kategori_buku CASCADE;
    TRUNCATE TABLE dim_mata_kuliah CASCADE;
    TRUNCATE TABLE dim_program_studi CASCADE;
    TRUNCATE TABLE dim_mahasiswa CASCADE;
    TRUNCATE TABLE dim_waktu CASCADE;
    
    RAISE NOTICE '   Semua tabel berhasil dikosongkan';
    
    -- ==========================================
    -- 3. LOAD DIMENSI
    -- ==========================================
    
    RAISE NOTICE '2. Memuat tabel dimensi...';
    
    -- 3.1 Load dim_waktu
    INSERT INTO dim_waktu (tahun_akademik, semester)
    SELECT DISTINCT 
        tahun_akademik, 
        semester
    FROM hasil_studi
    WHERE tahun_akademik IS NOT NULL 
      AND semester IS NOT NULL
    ORDER BY tahun_akademik, semester;
    GET DIAGNOSTICS v_row_count = ROW_COUNT;
    RAISE NOTICE '   dim_waktu: % baris', v_row_count;
    
    -- 3.2 Load dim_program_studi
    INSERT INTO dim_program_studi (program_studi_id, jenjang, nama_program_studi, kelas)
    SELECT 
        program_studi_id, 
        jenjang, 
        nama_program_studi, 
        kelas
    FROM program_studi;
    GET DIAGNOSTICS v_row_count = ROW_COUNT;
    RAISE NOTICE '   dim_program_studi: % baris', v_row_count;
    
    -- 3.3 Load dim_mahasiswa
    INSERT INTO dim_mahasiswa (nim, nama, jenis_kelamin, angkatan)
    SELECT 
        m.nim, 
        m.nama_lengkap AS nama,
        CASE 
            WHEN m.jenis_kelamin = 'L' THEN 'Laki-laki'
            WHEN m.jenis_kelamin = 'P' THEN 'Perempuan'
            ELSE m.jenis_kelamin
        END AS jenis_kelamin,
        m.angkatan
    FROM mahasiswa m;
    GET DIAGNOSTICS v_row_count = ROW_COUNT;
    RAISE NOTICE '   dim_mahasiswa: % baris', v_row_count;
    
    -- 3.4 Load dim_mata_kuliah
    INSERT INTO dim_mata_kuliah (kode_mata_kuliah, nama_mata_kuliah, bobot_sks, jenis_mata_kuliah)
    SELECT 
        mata_kuliah_id AS kode_mata_kuliah,
        nama_mata_kuliah,
        sks AS bobot_sks,
        'Wajib' AS jenis_mata_kuliah
    FROM mata_kuliah;
    GET DIAGNOSTICS v_row_count = ROW_COUNT;
    RAISE NOTICE '   dim_mata_kuliah: % baris', v_row_count;
    
    -- 3.5 Load dim_kategori_buku
    INSERT INTO dim_kategori_buku (kategori_id, nama_kategori, deskripsi)
    SELECT 
        kategori_id,
        nama_kategori,
        'Kategori: ' || nama_kategori AS deskripsi
    FROM kategori_buku;
    GET DIAGNOSTICS v_row_count = ROW_COUNT;
    RAISE NOTICE '   dim_kategori_buku: % baris', v_row_count;
    
    -- ==========================================
    -- 4. LOAD fact_detail_nilai
    -- ==========================================
    
    RAISE NOTICE '3. Memuat fact_detail_nilai...';
    
    INSERT INTO fact_detail_nilai (waktu_id, mahasiswa_id, mata_kuliah_id, nilai_angka, status_lulus, bobot_nilai)
    SELECT 
        w.waktu_id,
        m.mahasiswa_id,
        mk.mata_kuliah_id,
        dn.nilai_angka,
        CASE 
            WHEN dn.status_lulus = 'Lulus' THEN TRUE 
            ELSE FALSE 
        END AS status_lulus,
        dn.nilai_angka * mk.bobot_sks AS bobot_nilai
    FROM detail_nilai dn
    JOIN hasil_studi hs ON dn.khs_id = hs.khs_id
    JOIN dim_waktu w ON hs.tahun_akademik = w.tahun_akademik AND hs.semester = w.semester
    JOIN dim_mahasiswa m ON hs.nim = m.nim
    JOIN dim_mata_kuliah mk ON dn.mata_kuliah_id = mk.kode_mata_kuliah;
    
    GET DIAGNOSTICS v_row_count = ROW_COUNT;
    RAISE NOTICE '   fact_detail_nilai: % baris', v_row_count;
    
    -- ==========================================
    -- 5. LOAD fact_rekap_ip (agregasi dari fact_detail_nilai)
    -- ==========================================
    
    RAISE NOTICE '4. Memuat fact_rekap_ip...';
    
    INSERT INTO fact_rekap_ip (waktu_id, program_studi_id, mahasiswa_id, ip_semester, total_sks, jumlah_mata_kuliah)
    SELECT 
        fdn.waktu_id,
        m_source.program_studi_id,
        fdn.mahasiswa_id,
        ROUND(SUM(fdn.bobot_nilai)::NUMERIC / SUM(mk.bobot_sks)::NUMERIC, 2) AS ip_semester,
        SUM(mk.bobot_sks) AS total_sks,
        COUNT(*) AS jumlah_mata_kuliah
    FROM fact_detail_nilai fdn
    JOIN dim_mahasiswa dm ON fdn.mahasiswa_id = dm.mahasiswa_id
    JOIN mahasiswa m_source ON dm.nim = m_source.nim
    JOIN dim_mata_kuliah mk ON fdn.mata_kuliah_id = mk.mata_kuliah_id
    GROUP BY fdn.waktu_id, m_source.program_studi_id, fdn.mahasiswa_id;
    
    GET DIAGNOSTICS v_row_count = ROW_COUNT;
    RAISE NOTICE '   fact_rekap_ip: % baris', v_row_count;
    
	-- ==========================================
	-- 6. LOAD fact_rekap_pinjam
	-- ==========================================
	
	RAISE NOTICE '5. Memuat fact_rekap_pinjam...';
	
	INSERT INTO fact_rekap_pinjam (waktu_id, mahasiswa_id, kategori_id, total_peminjaman, jumlah_denda, jumlah_buku)
	SELECT 
	    w.waktu_id,
	    dm.mahasiswa_id,
	    b.kategori_id,
	    COUNT(DISTINCT p.peminjaman_id) AS total_peminjaman,
	    COALESCE(SUM(d.total_denda), 0) AS jumlah_denda,
	    COUNT(DISTINCT dp.buku_id) AS jumlah_buku
	FROM peminjaman p
	JOIN detail_peminjaman dp ON p.peminjaman_id = dp.peminjaman_id
	JOIN buku b ON dp.buku_id = b.buku_id
	JOIN anggota a ON p.anggota_id = a.anggota_id
	JOIN dim_mahasiswa dm ON a.nim = dm.nim
	JOIN dim_waktu w ON 
	    w.tahun_akademik = 
	        CASE 
	            WHEN EXTRACT(MONTH FROM p.tgl_pinjam) >= 7 THEN 
	                EXTRACT(YEAR FROM p.tgl_pinjam) || '/' || (EXTRACT(YEAR FROM p.tgl_pinjam) + 1)
	            ELSE 
	                (EXTRACT(YEAR FROM p.tgl_pinjam) - 1) || '/' || EXTRACT(YEAR FROM p.tgl_pinjam)
	        END
	    AND w.semester = 
	        CASE 
	            WHEN EXTRACT(MONTH FROM p.tgl_pinjam) BETWEEN 1 AND 6 THEN 'Genap'
	            ELSE 'Ganjil'
	        END
	LEFT JOIN denda d ON p.peminjaman_id = d.peminjaman_id
	GROUP BY w.waktu_id, dm.mahasiswa_id, b.kategori_id;
	
	GET DIAGNOSTICS v_row_count = ROW_COUNT;
	RAISE NOTICE '   fact_rekap_pinjam: % baris', v_row_count;
    
    -- ==========================================
    -- 7. UPDATE LOG (SUCCESS)
    -- ==========================================
    
    v_waktu_selesai := NOW();
    v_durasi := EXTRACT(EPOCH FROM (v_waktu_selesai - v_waktu_mulai));
    
    UPDATE log_proses_etl 
    SET waktu_selesai = v_waktu_selesai,
        durasi_detik = v_durasi,
        status = 'SUCCESS',
        pesan_error = 'Initial load berhasil. Total durasi: ' || v_durasi || ' detik'
    WHERE log_id = v_log_id;
    
    RAISE NOTICE '=== INITIAL LOAD SELESAI (% detik) ===', v_durasi;

EXCEPTION WHEN OTHERS THEN
    -- Handle error
    v_waktu_selesai := NOW();
    v_durasi := EXTRACT(EPOCH FROM (v_waktu_selesai - v_waktu_mulai));
    
    UPDATE log_proses_etl 
    SET waktu_selesai = v_waktu_selesai,
        durasi_detik = v_durasi,
        status = 'FAILED',
        pesan_error = SQLERRM
    WHERE log_id = v_log_id;
    
    RAISE EXCEPTION 'Initial Load Gagal: %', SQLERRM;
END;
$$;