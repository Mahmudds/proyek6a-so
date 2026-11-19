---
ANGGOTA 2 — MOH CANDRA AHNAF FADHILA (2510512030)
---

# Portofolio Individu Proyek Akhir Sistem Operasi

## 1. Identitas
- Nama: Moh Candra Ahnaf Fadhila
- NIM: 2510512030
- Kelompok: Kelompok 6A
- Pilihan Proyek: 6A — Server Berkas Bersama dengan Backup dan Audit Akses
- Peran: Anggota 2 (Konfigurasi Samba dan Pengujian Akses Klien)

## 2. Asal Proyek
- Tautan Repository Utama Kelompok: https://github.com/fadhila277/proyek6a-so
- Tautan Repository Pribadi (Host Utama): https://github.com/fadhila277/proyek6a-so
- Daftar Anggota Kelompok:
  1. Muhammad Irsyad Athala Pasya (2510512024) — User, Group, dan Permission
  2. Moh Candra Ahnaf Fadhila (2510512030) — Samba dan Klien
  3. Sastia Rahmadani Azzahra (2510512018) — Hak Pembaca (Read-Only)
  4. Muhammad Mahmud Mahfuz (2510512004) — Administrasi SSH
  5. Ruth Keysha Putri Lase (2510512012) — Backup dan Restore
  6. Salvito Maryanto (2510512034) — Monitoring, Log, Laporan, dan Docker

## 3. Kontribusi Pribadi
Sebagai Anggota 2, kontribusi teknis dan analisis yang saya kerjakan meliputi:
- Menyusun konfigurasi file sharing Samba [proyek6a_share] pada berkas config/smb.conf.snippet yang mengarah ke /srv/proyek6a/shared dengan pembatasan akses berbasis grup (valid users = @operator @pembaca, read only = yes, write list = @operator).
- Mengembangkan dan menguji skrip otomasi scripts/02_samba_client.sh dengan parameter --setup, --test-pos, --test-neg, dan --reset.
- Melakukan pengujian integrasi akses klien menggunakan smbclient serta mendokumentasikan bukti uji pada evidence/02_samba_client.log dan evidence/bukti_anggota2.txt.

## 4. Bukti Kontribusi
- Skrip Utama: scripts/02_samba_client.sh
- Konfigurasi: config/smb.conf.snippet
- Log dan Bukti Uji: evidence/02_samba_client.log dan evidence/bukti_anggota2.txt
- Riwayat Commit: https://github.com/fadhila277/proyek6a-so/commits/main

## 5. Skenario Pengujian Individu
- Tujuan: Memastikan layanan Samba (smbd) hanya mengizinkan akun yang terdaftar dan tergabung dalam grup berwenang (operator/pembaca), serta menolak akun di luar grup (user_luar).
- Prasyarat / Kondisi Awal:
  Direktori /srv/proyek6a/shared dan akun Linux (user_op, user_ro, user_luar) telah disiapkan oleh Anggota 1. Konfigurasi [proyek6a_share] terpasang di /etc/samba/smb.conf, akun user_op dan user_ro aktif di database smbpasswd, serta layanan smbd berstatus active.
- Langkah Uji Positif (--test-pos):
  Menjalankan ./scripts/02_samba_client.sh --test-pos yang mengeksekusi smbclient //127.0.0.1/proyek6a_share -U user_op%Proyek6A_2026 -c "ls".
  Hasil Aktual: Koneksi diterima, daftar berkas (dokumen_unit_1.txt hingga dokumen_unit_3.txt) tampil, dan skrip menghasilkan exit status 0.
- Langkah Uji Negatif (--test-neg):
  Menjalankan ./scripts/02_samba_client.sh --test-neg yang mengeksekusi smbclient //127.0.0.1/proyek6a_share -U user_luar%Proyek6A_2026 -c "ls".
  Hasil Aktual: Koneksi ditolak dengan pesan tree connect failed: NT_STATUS_ACCESS_DENIED dan skrip menghasilkan exit status 13.
- Verifikasi dan Pemulihan (--reset):
  Memeriksa catatan waktu dan hasil uji pada evidence/02_samba_client.log, lalu menjalankan sudo ./scripts/02_samba_client.sh --reset untuk me-restart layanan smbd kembali ke kondisi normal.

## 6. Analisis Konsep Sistem Operasi
- Autentikasi: Samba mengelola database kredensial terpisah dari /etc/shadow Linux melalui smbpasswd/pdbedit. Klien wajib melewati tahap verifikasi identitas SMB sebelum sesi akses diberikan.
- Otorisasi dan Proteksi Berkas: Parameter valid users dan write list pada Samba bekerja berlapis di atas permission dan ACL sistem berkas Linux (chmod 2770 SetGID). Meskipun protokol jaringan mengizinkan akses, kernel Linux tetap menegakkan hak akses terketat pada tingkat sistem berkas.
- Proses Layanan dan I/O: Daemon smbd berjalan sebagai proses layanan latar belakang (background service) yang dikelola systemd, mendengarkan port TCP 445, dan melayani permintaan baca/tulis I/O berkas dari klien secara terisolasi.

## 7. Kendala dan Penyelesaian
- Kendala: Akun Linux baru (user_op dan user_ro) awalnya gagal melakukan autentikasi Samba karena belum terdaftar di database password Samba, serta perintah smbclient yang gagal menghasilkan kode keluar umum (1) sehingga sulit dibedakan dari kesalahan eksekusi skrip.
- Penyelesaian: Menambahkan otomasi pendaftaran akun non-interaktif (echo "$SMB_PASS"; echo "$SMB_PASS") | smbpasswd -s -a "$u" pada blok --setup, serta menetapkan exit status 13 (EACCES / Permission denied) secara eksplisit ketika penolakan akses pada uji negatif berhasil terdeteksi.

## 8. Refleksi
- Hal yang Sudah Dikuasai: Konfigurasi file sharing Samba berbasis grup, sinkronisasi akun Samba dengan pengguna Linux, pengujian akses otomatis menggunakan smbclient, serta pengelolaan exit status dan pencatatan log pada skrip Bash.
- Hal yang Masih Perlu Dipelajari: Penerapan enkripsi lalu lintas jaringan SMB3 secara menyeluruh serta integrasi autentikasi terpusat menggunakan LDAP/Active Directory untuk skala infrastruktur yang lebih besar.
