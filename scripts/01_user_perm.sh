#!/bin/bash
set -u

BASE_DIR="/srv/proyek6a"
SHARED_DIR="${BASE_DIR}/shared"
BACKUP_DIR="${BASE_DIR}/backup"
LOG_DIR="${BASE_DIR}/logs"

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EVIDENCE_DIR="${REPO_DIR}/evidence"
LOG_FILE="${EVIDENCE_DIR}/01_user_perm.log"

GROUP_LIST="operator pembaca"
USER_LIST="admin_os user_op user_ro user_luar"
DEFAULT_PASS="Proyek6A_2026"

mkdir -p "${EVIDENCE_DIR}" 2>/dev/null

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$1] $2" | tee -a "${LOG_FILE}"
}

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_msg "ERROR" "Operasi ini memerlukan hak akses root atau sudo."
        exit 1
    fi
}

setup_environment() {
    check_root
    log_msg "INFO" "Memulai setup fondasi User, Group, dan Permission 6A"

    if ! command -v setfacl >/dev/null 2>&1; then
        apt-get update -y && apt-get install -y acl
    fi

    for d in "${BASE_DIR}" "${SHARED_DIR}" "${BACKUP_DIR}" "${LOG_DIR}" "${REPO_DIR}/output"; do
        if [ ! -d "${d}" ]; then
            mkdir -p "${d}"
            log_msg "INFO" "Direktori dibuat: ${d}"
        else
            log_msg "INFO" "Direktori sudah ada: ${d}"
        fi
    done

    for grp in ${GROUP_LIST}; do
        if ! getent group "${grp}" >/dev/null; then
            groupadd "${grp}"
            log_msg "INFO" "Grup dibuat: ${grp}"
        else
            log_msg "INFO" "Grup sudah ada: ${grp}"
        fi
    done

    for usr in ${USER_LIST}; do
        if ! id -u "${usr}" >/dev/null 2>&1; then
            useradd -m -s /bin/bash "${usr}"
            echo "${usr}:${DEFAULT_PASS}" | chpasswd
            log_msg "INFO" "Akun dibuat: ${usr}"
        else
            log_msg "INFO" "Akun sudah ada: ${usr}"
        fi
    done

    usermod -aG sudo,operator admin_os
    usermod -aG operator user_op
    usermod -aG pembaca user_ro
    log_msg "INFO" "Pemetaan grup selesai diatur."

    chown -R admin_os:operator "${BASE_DIR}"
    chmod 755 "${BASE_DIR}"
    chmod 2770 "${SHARED_DIR}"
    chmod 2770 "${BACKUP_DIR}"
    chmod 775 "${LOG_DIR}"

    setfacl -b "${SHARED_DIR}"
    setfacl -m u:admin_os:rwx,g:operator:rwx,g:pembaca:rx,o::--- "${SHARED_DIR}"
    setfacl -d -m u:admin_os:rwx,g:operator:rwx,g:pembaca:rx,o::--- "${SHARED_DIR}"
    log_msg "INFO" "Permission SetGID 2770 dan ACL diterapkan pada ${SHARED_DIR}"

    for i in 1 2 3; do
        f="${SHARED_DIR}/dokumen_unit_${i}.txt"
        echo "DOKUMEN RESMI UNIT KERJA 6A - DOK-0${i}" > "${f}"
        chown admin_os:operator "${f}"
        chmod 660 "${f}"
        setfacl -m g:operator:rw-,g:pembaca:r--,o::--- "${f}"
        log_msg "INFO" "Berkas dummy dibuat: ${f}"
    done

    log_msg "SUCCESS" "Setup fondasi Anggota 1 selesai."
    exit 0
}

test_positive() {
    log_msg "INFO" "Uji Positif: Operator menulis berkas"
    target="${SHARED_DIR}/laporan_operator.txt"
    if sudo -u user_op bash -c "echo 'Laporan operator' > '${target}'" 2>>"${LOG_FILE}"; then
        log_msg "SUCCESS" "POSITIF LULUS: user_op berhasil menulis ke ${target}"
        ls -l "${target}" | tee -a "${LOG_FILE}"
        exit 0
    else
        rc=$?
        log_msg "ERROR" "POSITIF GAGAL: Exit status ${rc}"
        exit "${rc}"
    fi
}

test_negative() {
    log_msg "INFO" "Uji Negatif: Pengguna luar grup ditolak"
    target="${SHARED_DIR}/ilegal_user_luar.txt"
    if sudo -u user_luar bash -c "echo 'Akses ilegal' > '${target}'" 2>>"${LOG_FILE}"; then
        log_msg "ERROR" "NEGATIF GAGAL: user_luar berhasil menulis berkas"
        exit 0
    else
        rc=$?
        log_msg "SUCCESS" "NEGATIF LULUS: Akses user_luar ditolak dengan Exit Status ${rc}"
        exit "${rc}"
    fi
}

show_status() {
    log_msg "INFO" "Menampilkan bukti konfigurasi User, Group, dan ACL"
    for usr in ${USER_LIST}; do
        id "${usr}" 2>&1 | tee -a "${LOG_FILE}"
    done
    ls -ld "${BASE_DIR}" "${SHARED_DIR}" "${BACKUP_DIR}" | tee -a "${LOG_FILE}"
    getfacl -p "${SHARED_DIR}" | tee -a "${LOG_FILE}"
    ls -la "${SHARED_DIR}" | tee -a "${LOG_FILE}"
    exit 0
}

reset_environment() {
    check_root
    rm -f "${SHARED_DIR}/laporan_operator.txt" "${SHARED_DIR}/ilegal_user_luar.txt"
    log_msg "SUCCESS" "Kondisi direktori shared berhasil direset."
    exit 0
}

if [ $# -ne 1 ]; then
    echo "Penggunaan: $0 {--setup|--test-pos|--test-neg|--status|--reset}"
    exit 2
fi

case "$1" in
    --setup)    setup_environment ;;
    --test-pos) test_positive ;;
    --test-neg) test_negative ;;
    --status)   show_status ;;
    --reset)    reset_environment ;;
    *)          echo "Opsi tidak valid: $1"; exit 2 ;;
esac
