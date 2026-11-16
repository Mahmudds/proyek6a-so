#!/bin/bash

SRC_DIR="/srv/proyek6a/shared"
BACKUP_DIR="/srv/proyek6a/backup"
RESTORE_DIR="/srv/proyek6a/restore_uji"
LOG_FILE="/srv/proyek6a/logs/operasional.log"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
LATEST="$BACKUP_DIR/latest_backup.tar.gz"

mkdir -p "$BACKUP_DIR" "$RESTORE_DIR" "$(dirname "$LOG_FILE")"

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ANGGOTA-5] $1" | tee -a "$LOG_FILE"
}

if [ "$#" -ne 1 ]; then
    echo "Gunakan: $0 {backup|test_pos|test_neg|reset}"
    exit 2
fi

case "$1" in
    backup)
        if [ ! -d "$SRC_DIR" ]; then
            log_msg "GAGAL: Direktori sumber tidak ditemukan."
            exit 1
        fi

        ARCHIVE="$BACKUP_DIR/backup_shared_${TIMESTAMP}.tar.gz"

        if ! tar -czf "$ARCHIVE" -C "$SRC_DIR" .; then
            log_msg "GAGAL: Proses backup."
            exit 1
        fi

        (cd "$BACKUP_DIR" && sha256sum "$(basename "$ARCHIVE")" > "$(basename "$ARCHIVE").sha256")
        cp "$ARCHIVE" "$LATEST"
        (cd "$BACKUP_DIR" && sha256sum latest_backup.tar.gz > latest_backup.tar.gz.sha256)

        log_msg "Backup berhasil: $ARCHIVE"
        log_msg "Checksum SHA-256 berhasil dibuat."
        ;;

    test_pos)
        if [ ! -f "$LATEST" ] || [ ! -f "$LATEST.sha256" ]; then
            log_msg "GAGAL: File backup atau checksum tidak ditemukan."
            exit 1
        fi

        if ! (cd "$BACKUP_DIR" && sha256sum -c latest_backup.tar.gz.sha256); then
            log_msg "GAGAL: Verifikasi checksum backup."
            exit 1
        fi

        find "$RESTORE_DIR" -mindepth 1 -delete

        if ! tar -xzf "$LATEST" -C "$RESTORE_DIR"; then
            log_msg "GAGAL: Proses restore."
            exit 1
        fi

        if diff -qr "$SRC_DIR" "$RESTORE_DIR"; then
            log_msg "Pengujian positif berhasil: hasil restore sesuai sumber."
        else
            log_msg "GAGAL: Hasil restore berbeda dari sumber."
            exit 1
        fi
        ;;

    test_neg)
        if [ ! -f "$LATEST" ]; then
            log_msg "GAGAL: File backup tidak ditemukan."
            exit 1
        fi

        cp "$LATEST" "$BACKUP_DIR/corrupt_backup.tar.gz"
        (cd "$BACKUP_DIR" && sha256sum corrupt_backup.tar.gz > corrupt_backup.tar.gz.sha256)
        echo "DATA_RUSAK" >> "$BACKUP_DIR/corrupt_backup.tar.gz"

        if (cd "$BACKUP_DIR" && sha256sum -c corrupt_backup.tar.gz.sha256); then
            log_msg "GAGAL: Kerusakan arsip tidak terdeteksi."
            exit 1
        else
            log_msg "Pengujian negatif berhasil: checksum berbeda, restore ditolak."
            exit 14
        fi
        ;;

    reset)
        rm -f "$BACKUP_DIR/corrupt_backup.tar.gz" "$BACKUP_DIR/corrupt_backup.tar.gz.sha256"
        find "$RESTORE_DIR" -mindepth 1 -delete
        log_msg "Reset berhasil: file pengujian dibersihkan."
        ;;

    *)
        echo "Pilihan tidak valid."
        exit 2
        ;;
esac

exit 0
