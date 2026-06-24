-- program_studi
CREATE TABLE program_studi (
    program_studi_id INTEGER PRIMARY KEY,
    jenjang VARCHAR(5),
    nama_program_studi VARCHAR(100),
    kelas VARCHAR(20)
);

-- mata_kuliah
CREATE TABLE mata_kuliah (
    mata_kuliah_id VARCHAR(10) PRIMARY KEY,
    nama_mata_kuliah VARCHAR(150),
    sks SMALLINT
);

-- mahasiswa
CREATE TABLE mahasiswa (
    nim VARCHAR(20) PRIMARY KEY,
    program_studi_id INTEGER REFERENCES program_studi(program_studi_id),
    nama_lengkap VARCHAR(100),
    jenis_kelamin CHAR(1),
    angkatan SMALLINT,
    total_sks SMALLINT
);

-- hasil_studi
CREATE TABLE hasil_studi (
    khs_id VARCHAR(20) PRIMARY KEY,
    nim VARCHAR(20) REFERENCES mahasiswa(nim),
    tahun_akademik VARCHAR(10),
    semester VARCHAR(10),
    sks_ditempuh SMALLINT
);

-- detail_nilai
CREATE TABLE detail_nilai (
    detail_id BIGINT PRIMARY KEY,
    khs_id VARCHAR(20) REFERENCES hasil_studi(khs_id),
    mata_kuliah_id VARCHAR(10) REFERENCES mata_kuliah(mata_kuliah_id),
    nilai_angka NUMERIC(4,2),
    nilai_huruf VARCHAR(5),
    status_lulus VARCHAR(15)
);