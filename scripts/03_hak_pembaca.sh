#!/usr/bin/env bash
# File: scripts/03_hak_pembaca.sh
# Penanggung Jawab: Anggota 3 - Verifikasi Hak Pembaca (Read-Only) dan Audit Akses

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
TARGET_FILE="/srv/proyek6a/shared/dokumen_unit_1.txt"
LOG_FILE="$REPO_DIR/evidence/anggota3_audit.log"
READER_USER="user_ro"

mkdir -p "$REPO_DIR/evidence"

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ANGGOTA-3] $1" | tee -a "$LOG_FILE"
}

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 {test_pos|test_neg|reset}"
    exit 2
fi

if ! sudo test -f "$TARGET_FILE"; then
    echo "ERROR: Berkas $TARGET_FILE tidak ditemukan. Jalankan setup Anggota 1 terlebih dahulu!"
    exit 1
fi

case "$1" in
    test_pos)
        log_msg "UJI POSITIF: $READER_USER membaca berkas $TARGET_FILE"
        if OUTPUT=$(sudo -u "$READER_USER" cat "$TARGET_FILE" 2>/dev/null); then
            echo "Isi Berkas Terbaca: $OUTPUT"
            log_msg "HASIL POSITIF LULUS: $READER_USER berhasil membaca berkas (exit 0)."
            exit 0
        else
            log_msg "HASIL POSITIF GAGAL: $READER_USER ditolak saat membaca berkas!"
            exit 1
        fi
        ;;

    test_neg)
        log_msg "UJI NEGATIF: $READER_USER mencoba memodifikasi dan menghapus $TARGET_FILE"
        FAIL_COUNT=0

        for act in "modify" "delete"; do
            if [[ "$act" == "modify" ]]; then
                if sudo -u "$READER_USER" bash -c "echo 'ubahteks' >> '$TARGET_FILE'" 2>/dev/null; then
                    log_msg "PELANGGARAN: $READER_USER berhasil mengubah berkas!"
                    ((FAIL_COUNT++))
                else
                    log_msg "AUDIT AKSES: Percobaan modifikasi oleh $READER_USER ditolak (Permission denied)."
                fi
            elif [[ "$act" == "delete" ]]; then
                if sudo -u "$READER_USER" rm -f "$TARGET_FILE" 2>/dev/null; then
                    log_msg "PELANGGARAN: $READER_USER berhasil menghapus berkas!"
                    ((FAIL_COUNT++))
                else
                    log_msg "AUDIT AKSES: Percobaan penghapusan oleh $READER_USER ditolak (Permission denied)."
                fi
            fi
        done

        if [[ $FAIL_COUNT -eq 0 ]]; then
            log_msg "HASIL NEGATIF LULUS: Seluruh percobaan tulis/hapus oleh $READER_USER berhasil ditolak."
            exit 13
        else
            log_msg "HASIL NEGATIF GAGAL: Terdapat aksi tulis/hapus yang lolos!"
            exit 1
        fi
        ;;

    reset)
        log_msg "RESET: Verifikasi keutuhan berkas $TARGET_FILE selesai."
        sudo ls -l "$TARGET_FILE"
        exit 0
        ;;

    *)
        echo "Usage: $0 {test_pos|test_neg|reset}"
        exit 2
        ;;
esac
