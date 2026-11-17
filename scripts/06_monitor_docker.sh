#!/usr/bin/env bash
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/output"
REPORT_FILE="$OUTPUT_DIR/laporan.txt"
LOG_FILE="/srv/proyek6a/logs/operasional.log"
DOCKER_IMAGE="alpine:3.19"
SERVICES=("smbd" "ssh")

log_msg() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ANGGOTA-6] $1" | tee -a "$LOG_FILE"; }

if [[ $# -lt 1 ]]; then exit 2; fi
mkdir -p "$OUTPUT_DIR"

case "$1" in
    generate_report)
        {
            echo "=================================================================="
            echo " LAPORAN OPERASIONAL LAYANAN & BACKUP - PROYEK 6A SISTEM OPERASI"
            echo " Waktu Pembuatan : $(date '+%Y-%m-%d %H:%M:%S')"
            echo "=================================================================="
            echo "[1] STATUS PROSES LAYANAN UTAMA"
            for svc in "${SERVICES[@]}"; do
                STATUS=$(systemctl is-active "$svc" 2>/dev/null || echo "inactive")
                PID=$(systemctl show --property MainPID --value "$svc" 2>/dev/null || echo "0")
                echo " - Layanan : $svc | Status : $STATUS | MainPID : $PID"
            done
            echo "[2] RINGKASAN PENGGUNAAN SUMBER DAYA (CPU & MEMORI HOST)"
            free -m | awk 'NR==1{print "   " $0} NR==2{printf "   Memori (MB) -> Total: %s | Digunakan: %s | Bebas: %s\n", $2, $3, $4}'
            ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -n 6 | sed 's/^/   /'
            echo "[3] DAFTAR ARSIP BACKUP & CHECKSUM TERBARU"
            ls -lh /srv/proyek6a/backup 2>/dev/null | sed 's/^/   /'
            echo "[4] 15 LOG OPERASIONAL & AUDIT AKSES TERAKHIR"
            tail -n 15 "$LOG_FILE" 2>/dev/null | sed 's/^/   /'
            echo "=================================================================="
        } > "$REPORT_FILE"
        log_msg "LAPORAN DIBUAT: Berkas $REPORT_FILE berhasil diperbarui."
        exit 0
        ;;
    uji_beban)
        TMP_LOAD="/tmp/uji_beban_6a"
        mkdir -p "$TMP_LOAD"
        for sz in 1 25; do
            dd if=/dev/zero of="$TMP_LOAD/data_${sz}MB.bin" bs=1M count="$sz" status=none
            /usr/bin/time -f "Beban ${sz}MB -> Waktu: %E | CPU: %P | Max RAM: %M KB" tar -czf "$TMP_LOAD/arsip_${sz}MB.tar.gz" "$TMP_LOAD/data_${sz}MB.bin"
        done
        rm -rf "$TMP_LOAD"
        exit 0
        ;;
    test_pos)
        if [[ ! -f "$REPORT_FILE" ]]; then "$0" generate_report; fi
        if sudo docker run --rm --mount type=bind,src="$OUTPUT_DIR",dst=/data,readonly "$DOCKER_IMAGE" cat /data/laporan.txt; then
            log_msg "HASIL POSITIF LULUS: Container berhasil membaca laporan host."
            exit 0
        else exit 1; fi
        ;;
    test_neg)
        if [[ ! -f "$REPORT_FILE" ]]; then "$0" generate_report; fi
        if sudo docker run --rm --mount type=bind,src="$OUTPUT_DIR",dst=/data,readonly "$DOCKER_IMAGE" sh -c 'echo "uji perubahan" >> /data/laporan.txt' 2>/dev/null; then
            exit 1
        else
            log_msg "HASIL NEGATIF LULUS: Penulisan ditolak."
            exit 0
        fi
        ;;
    *) exit 2 ;;
esac
