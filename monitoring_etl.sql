SELECT 
    log_id,
    nama_proses,
    waktu_mulai,
    waktu_selesai,
    durasi_detik || ' detik' AS total_durasi,
    status,
    pesan_error
FROM log_proses_etl 
ORDER BY waktu_mulai DESC;