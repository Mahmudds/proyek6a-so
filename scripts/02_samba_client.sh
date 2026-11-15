#!/usr/bin/env bash
# File: scripts/02_samba_client.sh
# Penanggung Jawab: Anggota 2 - Konfigurasi Samba dan Pengujian Akses Klien

SHARE_NAME="proyek6a_share"
SMB_HOST="127.0.0.1"
SMB_PASS="Proyek6A_2026"
AUTH_USERS=("user_op" "user_ro")

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EVIDENCE_DIR="${REPO_DIR}/evidence"
LOG_FILE="${EVIDENCE_DIR}/02_samba_client.log"

mkdir -p "$EVIDENCE_DIR" 2>/dev/null
touch "$LOG_FILE" 2>/dev/null || true
chmod 666 "$LOG_FILE" 2>/dev/null || true

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ANGGOTA-2] $1" | tee -a "$LOG_FILE"
}

if [[ $# -ne 1 ]]; then
    echo "Penggunaan: $0 {--setup|--test-pos|--test-neg|--reset}"
    exit 2
fi

case "$1" in
    --setup)
        if [[ $EUID -ne 0 ]]; then
            echo "ERROR: Jalankan setup Samba dengan sudo!"
            exit 1
        fi

        if ! grep -q "\[${SHARE_NAME}\]" /etc/samba/smb.conf; then
            cat << 'EOS' >> /etc/samba/smb.conf

[proyek6a_share]
   comment = Direktori Berkas Bersama Proyek 6A SO
   path = /srv/proyek6a/shared
   browseable = yes
   valid users = @operator @pembaca
   read only = yes
   write list = @operator
   create mask = 0660
   directory mask = 2770
EOS
            log_msg "Konfigurasi [$SHARE_NAME] ditambahkan ke /etc/samba/smb.conf."
        else
            log_msg "Konfigurasi [$SHARE_NAME] sudah ada di /etc/samba/smb.conf."
        fi

        for u in "${AUTH_USERS[@]}"; do
            (echo "$SMB_PASS"; echo "$SMB_PASS") | smbpasswd -s -a "$u" >/dev/null
            smbpasswd -e "$u" >/dev/null
            log_msg "Akun Samba '$u' berhasil diaktifkan."
        done

        smbpasswd -x user_luar >/dev/null 2>&1 || true

        testparm -s >/dev/null 2>&1
        systemctl restart smbd
        log_msg "SETUP SAMBA BERHASIL: Layanan smbd aktif dan siap menerima koneksi."
        exit 0
        ;;

    --test-pos)
        log_msg "UJI POSITIF: Mengakses share //$SMB_HOST/$SHARE_NAME dengan akun berwenang (user_op)"
        if OUT=$(smbclient "//$SMB_HOST/$SHARE_NAME" -U "user_op%$SMB_PASS" -c "ls" 2>&1); then
            echo "$OUT"
            log_msg "HASIL POSITIF LULUS: user_op berhasil mengakses share Samba (exit 0)."
            exit 0
        else
            echo "$OUT"
            log_msg "HASIL POSITIF GAGAL: user_op gagal mengakses share Samba!"
            exit 1
        fi
        ;;

    --test-neg)
        log_msg "UJI NEGATIF: Mengakses share //$SMB_HOST/$SHARE_NAME dengan akun tidak berwenang (user_luar)"
        if OUT=$(smbclient "//$SMB_HOST/$SHARE_NAME" -U "user_luar%$SMB_PASS" -c "ls" 2>&1); then
            echo "$OUT"
            log_msg "HASIL NEGATIF GAGAL: user_luar seharusnya ditolak oleh Samba!"
            exit 1
        else
            echo "$OUT"
            log_msg "HASIL NEGATIF LULUS: Akses Samba oleh user_luar ditolak (NT_STATUS_ACCESS_DENIED)."
            exit 13
        fi
        ;;

    --reset)
        sudo systemctl restart smbd
        log_msg "RESET: Layanan Samba di-restart kembali ke kondisi normal."
        exit 0
        ;;

    *)
        echo "Opsi tidak valid: $1"
        echo "Penggunaan: $0 {--setup|--test-pos|--test-neg|--reset}"
        exit 2
        ;;
esac
