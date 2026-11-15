#!/usr/bin/env bash

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/output"
REPORT_FILE="$OUTPUT_DIR/laporan.txt"
LOG_FILE="/srv/proyek6a/logs/operasional.log"
DOCKER_IMAGE="alpine:3.19"
SERVICES=("smbd" "ssh")

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ANGGOTA-6] $1" | tee -a "$LOG_FILE"
}

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 {generate_report|uji_beban|test_pos|test_neg|reset}"
    exit 2
fi

mkdir -p "$OUTPUT_DIR"

case "$1" in
    generate_report)
        {
            echo "=================================================================="
            echo " LAPORAN OPERASIONAL LAYANAN & BACKUP - PROYEK 6A SISTEM OPERASI"
            echo " Waktu Pembuatan : $(date '+%Y-%m-%d %H:%M:%S')"
            echo "=================================================================="
            echo ""
            echo "[1] STATUS PROSES LAYANAN UTAMA"
            for svc in "${SERVICES[@]}"; do
                STATUS=$(systemctl is-active "$svc" 2>/dev/null || echo "inactive")
                PID=$(systemctl show --property MainPID --value "$svc" 2>/dev/null || echo "0")
                echo " - Layanan : $svc | Status : $STATUS | MainPID : $PID"
            done
            echo ""
            echo "[2] RINGKASAN PENGGUNAAN SUMBER DAYA (CPU & MEMORI HOST)"
            free -m | awk 'NR==1{print "   " $0} NR==2{printf "   Memori (MB) -> Total: %s | Digunakan: %s | Bebas: %s\n", $2, $3, $4}'
            ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -n 6 | sed 's/^/   /'
            echo ""
            echo "[3] DAFTAR ARSIP BACKUP & CHECKSUM TERBARU"
            ls -lh /srv/proyek6a/backup 2>/dev/null | sed 's/^/   /'
            echo ""
            echo "[4] 15 LOG OPERASIONAL & AUDIT AKSES TERAKHIR"
            tail -n 15 "$LOG_FILE" 2>/dev/null | sed 's/^/   /'
            echo "=================================================================="
        } > "$REPORT_FILE"

        log_msg "LAPORAN DIBUAT: Berkas $REPORT_FILE berhasil diperbarui."
        exit 0
        ;;

    uji_beban)
        log_msg "PENGAMATAN 2 BEBAN AMAN: Membandingkan Beban Ringan (1MB) vs Beban Menengah (25MB)"
        TMP_LOAD="/tmp/uji_beban_6a"
        mkdir -p "$TMP_LOAD"

        for sz in 1 25; do
            echo "--- Pengujian Beban ${sz}MB ---"
            dd if=/dev/zero of="$TMP_LOAD/data_${sz}MB.bin" bs=1M count="$sz" status=none
            /usr/bin/time -f "Beban ${sz}MB -> Waktu: %E | CPU: %P | Max RAM: %M KB" \
                tar -czf "$TMP_LOAD/arsip_${sz}MB.tar.gz" "$TMP_LOAD/data_${sz}MB.bin"
        done
        rm -rf "$TMP_LOAD"
        log_msg "PENGAMATAN BEBAN SELESAI: Metrik 2 beban aman berhasil dicatat."
        exit 0
        ;;

    test_pos)
        if [[ ! -f "$REPORT_FILE" ]]; then
            "$0" generate_report
        fi
        log_msg "UJI POSITIF DOCKER: Container $DOCKER_IMAGE membaca /data/laporan.txt (read-only mount)"
        if sudo docker run --rm --mount type=bind,src="$OUTPUT_DIR",dst=/data,readonly "$DOCKER_IMAGE" cat /data/laporan.txt; then
            log_msg "HASIL POSITIF LULUS: Container berhasil membaca laporan host dengan exit status 0."
            exit 0
        else
            log_msg "HASIL POSITIF GAGAL: Container gagal membaca laporan!"
            exit 1
        fi
        ;;

    test_neg)
        if [[ ! -f "$REPORT_FILE" ]]; then
            "$0" generate_report
        fi
        HASH_AWAL=$(sha256sum "$REPORT_FILE" | awk '{print $1}')
        log_msg "UJI NEGATIF DOCKER: Percobaan menulis ke /data/laporan.txt pada mount read-only"
        echo "Checksum sebelum uji negatif : $HASH_AWAL"

        if sudo docker run --rm --mount type=bind,src="$OUTPUT_DIR",dst=/data,readonly "$DOCKER_IMAGE" sh -c 'echo "uji perubahan" >> /data/laporan.txt' 2>/dev/null; then
            log_msg "HASIL NEGATIF GAGAL: Container seharusnya ditolak menulis ke mount read-only!"
            exit 1
        else
            DOCKER_EXIT=$?
            HASH_AKHIR=$(sha256sum "$REPORT_FILE" | awk '{print $1}')
            echo "Checksum sesudah uji negatif : $HASH_AKHIR"
            if [[ "$HASH_AWAL" == "$HASH_AKHIR" ]]; then
                log_msg "HASIL NEGATIF LULUS: Penulisan ditolak (exit status $DOCKER_EXIT) & checksum berkas host tetap identik."
                exit "$DOCKER_EXIT"
            else
                log_msg "HASIL NEGATIF GAGAL: Checksum berkas berubah!"
                exit 1
            fi
        fi
        ;;

    reset)
        "$0" generate_report
        log_msg "RESET: Laporan output/laporan.txt disegarkan kembali."
        exit 0
        ;;

    *)
        echo "Usage: $0 {generate_report|uji_beban|test_pos|test_neg|reset}"
        exit 2
        ;;
esac
