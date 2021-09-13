#!/bin/bash

# set -x
set -o pipefail

if [ -f ".env" ]; then
    . ".env"
fi

# $1 - variable name
# $2 - variable default value
set_var() {
    if [ -z "${!1}" ]; then
        eval "$1"='$2'
    fi
}

# Cfg
set_var "DST_HOST" "some.host"
set_var "DST_PORT" "2222"
set_var "LOG_DIR" "log"
set_var "LOG_EXT" ".log"
set_var "CFG_DIR" "cfg"
set_var "BACKUP_DIR" "/backup_storage" # folder on the DST_HOST
set_var "BACKUP_DIR_TEMP" "_temp"
set_var "ARCHIVE_DATE_MASK" "+%Y-%m-%d_%H-%M-%S"
set_var "LOG_MSG_DATE_MASK" "+%Y-%m-%d %H:%M:%S.%Z"
set_var "UMASK" "0007"
set_var "DB_ARCH_NAME_EXT" ".gz"
set_var "SSH_TPL" "ssh -q -p DST_PORT -o StrictHostKeyChecking=no DST_USER@DST_HOST"
set_var "RSYNC_OPT" "--verbose --progress"
set_var "RSYNC_TPL" "nice -n 19 ionice -c 3 rsync RSYNC_OPT -aR -H --inplace --delete --compress --perms --chmod=u+rw,g+rw,o-rwx,Du+rwx,Dg+rwx,Do-rwx,D-t -e \"ssh -q -T -x -o Compression=no -p DST_PORT -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null\" EXCLUDE SRC DST_USER@DST_HOST:DST_DIR"
set_var "RSYNC_RETRIES" "5"
set_var "MYSQL_CMD" "mysql"
set_var "MYSQL_GET_ALL_DB_NAMES_TPL" "MYSQL_CMD --host=MYSQL_HOST --user=MYSQL_USER --password=MYSQL_PASS --skip-column-names -e \"show databases\""
set_var "MYSQL_DUMP_TMP_DIR" "/tmp"
set_var "MYSQL_DUMP_CMD" "mysqldump"
set_var "MYSQL_DUMP_TPL" "MYSQL_DUMP_CMD --host=MYSQL_HOST --user=MYSQL_USER --password=MYSQL_PASS --skip-lock-tables --quick --extended-insert --disable-keys --databases DB_NAME | gzip -c --best > DB_ARCH_NAME"
set_var "POST_CMD_TPL" "eval ./final.sh > LOG_FILE.final.txt 2>&1 ; { grep --color=never \" - Error: \| - Start: \| - Dir: \| - Dump DB: \| - Finish$\|rsync error\" LOG_FILE; } | { [ -n \"${REMOTE_CMD_LOCAL_DIR}\" ] && SSH_TPL /backup/send_backup_logs.sh \"Backup:\ $1\" || ./send_backup_logs.sh \"Backup: $1\"; }"
set_var "KEEP_LAST_BACKUPS" "5"
set_var "KEEP_FIRST_BY_UNIQ_STR_PART" "8" # Backups look 2017-01-01_15-02-02, 2017-02-01_15-02-03. First 8 symbols are markers to keep backup (For example "2017-01-" and "2017-02-")
# End Cfg

if [ -n "${TERM}" ] && [ "${TERM}" != "dumb" ]; then
    LOG_ECHO=1
else
    LOG_ECHO=0
fi

# $1 - message
# $2 - (0/1, default 1) print date/time
# $3 - (0/1, default 1) print end of line
log() {
    if [ "$2" == "0" ]; then
        msg=""
    else
        msg="$(date "+%Y-%m-%d %H:%M:%S,%3N %Z") - "
    fi

    msg="${msg}${1}"

    if [ "$3" == "0" ]; then
        echo_opt="-n"
    else
        echo_opt=
    fi

    if [ "${LOG_ECHO}" == "1" ]; then
        eval echo "${echo_opt}" '"${msg}"'
    fi

    eval echo "${echo_opt}" '"${msg}"' >> "${log_file}"
}

# $1 - message
print_stderr() {
    echo "$1" >&2
}

# $1 - rsync command
# $2 - log file
rsync_with_retries() {
    for i in $(seq 1 "${RSYNC_RETRIES}"); do
        log "Run rsync (attempt: ${i}/${RSYNC_RETRIES}): ${rsync_cmd}"

        eval "$1" >> "$2" 2>&1
        rsync_ec="$?"
        log "Rsync finished with exit code: ${rsync_ec}"

        if [ "${rsync_ec}" -eq 0 ]; then
            break
        fi
    done
}

if [ -n "$1" ]; then
    cfg="$1"
else
    print_stderr "Usage: $0 <config_file>"
    print_stderr "Config directory: ${CFG_DIR}"
    print_stderr "Exit 1"
    exit 1
fi

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
cd "${script_dir}" || exit 2

cfg_file="${CFG_DIR}/${cfg}"

if [ ! -f "${cfg_file}" ]; then
    print_stderr "Can't find the file: ${cfg_file}. Exit 3"
    exit 3
fi

# shellcheck source=cfg/example
. "${cfg_file}"
source_ec="$?"

if [ "${source_ec}" -ne 0 ]; then
    print_stderr "Failed to source the file: ${cfg_file}. Exit 4"
    exit 4
fi

umask "${UMASK}"
dt="$(date "${ARCHIVE_DATE_MASK}")"
log_dir="${LOG_DIR}/${cfg}/${dt}"
log_file="${log_dir}/${dt}${LOG_EXT}"

cmd="mkdir -p ${log_dir}"
${cmd}
log "Created log dir: ${log_dir}"

log "Start: ${cfg}"
log "Config: ${cfg_file}"

if [ ! -f "${cfg_file}" ]; then
    m="The configuration '${cfg_file}' doesn't exist. Exit 5"
    log "${m}"
    print_stderr "${m}"
    exit 5
fi

backup_root_dir="${BACKUP_DIR}/${cfg}"
backup_final_dir="${backup_root_dir}/${dt}"
log "New backup dir: ${backup_final_dir}"
backup_dir="${backup_final_dir}${BACKUP_DIR_TEMP}"
log "New backup temp dir: ${backup_dir}"

if [ -n "${SSH_TPL}" ]; then
    ssh_cmd="${SSH_TPL}"
    ssh_cmd="${ssh_cmd//DST_USER/${DST_USER}}"
    ssh_cmd="${ssh_cmd//DST_HOST/${DST_HOST}}"
    ssh_cmd="${ssh_cmd//DST_PORT/${DST_PORT}}"
    ssh_pre_cmd="${ssh_cmd} '"
    ssh_post_cmd="'"
else
    ssh_cmd=""
    ssh_pre_cmd=""
    ssh_post_cmd=""
fi

cmd="${ssh_pre_cmd}ls ${backup_root_dir} 2> /dev/null | grep -v '${BACKUP_DIR_TEMP}' || echo 'not_found'${ssh_post_cmd}"
log "Find latest backup, run: ${cmd}"
backups_list="$(eval "${cmd}")"
backups_list_ec="$?"

if [ "${backups_list_ec}" -ne 0 ]; then
    m="Failed to get latest backup (ssh failed?). Exit 6"
    log "${m}"
    print_stderr "${m}"
    exit 6
fi

if [ -z "${backups_list}" ] || [ "${backups_list}" == "not_found" ]; then
    log "Latest backup not found"
    cmd="${ssh_pre_cmd}umask ${UMASK} && mkdir -p ${backup_dir}${ssh_post_cmd}"
    log "Create destination directory, run: ${cmd}"
    eval "${cmd}"
    cmd_ec="$?"

    if [ "${cmd_ec}" -ne 0 ]; then
        m="Failed to create the directory. Exit 7"
        log "${m}"
        print_stderr "${m}"
        exit 7
    fi
else
    last_backup_dir="${backup_root_dir}/$(echo "${backups_list}" | sort | tail -n 1)"
    log "Found latest backup: ${last_backup_dir}"

    cmd="${ssh_pre_cmd}nice -n 19 ionice -c 3 cp -al --reflink=always ${last_backup_dir} ${backup_dir}${ssh_post_cmd}"
    log "Copy data from latest to new backup, run: ${cmd}"
    copy_out="$(eval "${cmd}" 2>&1)"
    copy_ec="$?"

    if [ "${copy_ec}" -ne 0 ]; then
        m="Error: Copy failed. Output: '${copy_out}'. Exit 8"
        log "${m}"
        print_stderr "${m}"
        exit 8
    fi

    log "Copy finished"
fi

for dirs_iterator in "${!DIRS[@]}"; do
    dir=${DIRS[${dirs_iterator}]}
    log "Dir: ${dir}"

    rsync_cmd="${RSYNC_TPL}"
    rsync_cmd="${rsync_cmd//RSYNC_OPT/${RSYNC_OPT}}"
    rsync_cmd="${rsync_cmd//SRC/${dir}}"
    rsync_cmd="${rsync_cmd//DST_USER/${DST_USER}}"
    rsync_cmd="${rsync_cmd//DST_HOST/${DST_HOST}}"
    rsync_cmd="${rsync_cmd//DST_PORT/${DST_PORT}}"
    rsync_cmd="${rsync_cmd//DST_DIR/${backup_dir}}"

    # Exclude list
    exclude_cmd=""
    dir_strlen=${#dir}

    for exclude_iterator in "${!EXCLUDE[@]}"; do
        excl="${EXCLUDE[${exclude_iterator}]}"

        if [ "${dir}" == "${excl:0:${dir_strlen}}" ]; then
            if [ -n "${exclude_cmd}" ]; then
                exclude_cmd="${exclude_cmd} --exclude ${excl}"
            else
                exclude_cmd="--exclude ${excl}"
            fi
        fi
    done

    if [ -n "${exclude_cmd}" ]; then
        rsync_cmd=${rsync_cmd//EXCLUDE/${exclude_cmd}}
    else
        rsync_cmd=${rsync_cmd//EXCLUDE /}
    fi
    # End

    rsync_log="${log_dir}/$(date "${ARCHIVE_DATE_MASK}")${dir//\//_}${LOG_EXT}"
    rsync_with_retries "${rsync_cmd}" "${rsync_log}"
    log "Completed dir: ${dir}"
done

# MySQL DBs dump
if [ -n "${MYSQL_HOST}" ]; then
    log "Start DB backup"

    mysql_cmd="${MYSQL_GET_ALL_DB_NAMES_TPL}"
    mysql_cmd="${mysql_cmd//MYSQL_CMD/${MYSQL_CMD}}"
    mysql_cmd="${mysql_cmd//MYSQL_HOST/${MYSQL_HOST}}"
    mysql_cmd="${mysql_cmd//MYSQL_USER/${MYSQL_USER}}"
    mysql_cmd="${mysql_cmd//MYSQL_PASS/${MYSQL_PASS}}"

    log "Get all databases name"
    dbs="$(eval "${mysql_cmd} 2>&1")"
    dbs_ec=$?

    if [ "${dbs_ec}" -ne 0 ]; then
        log "Error: 'Get all databases name' failed. Output: ${dbs}"
    else
        log "Output:
${dbs}"

        dbs=("${dbs}")

        for db in ${dbs[*]}; do
            log "Dump DB: ${db}"

            db_arch_name="${MYSQL_DUMP_TMP_DIR}/${db}${DB_ARCH_NAME_EXT}"

            if [ -f "${db_arch_name}" ]; then
                log "Remove the file: ${db_arch_name}"
                rm -f "${db_arch_name}"
            fi

            mysqldump_cmd="${MYSQL_DUMP_TPL}"
            mysqldump_cmd="${mysqldump_cmd//MYSQL_DUMP_CMD/${MYSQL_DUMP_CMD}}"
            mysqldump_cmd="${mysqldump_cmd//MYSQL_HOST/${MYSQL_HOST}}"
            mysqldump_cmd="${mysqldump_cmd//MYSQL_USER/${MYSQL_USER}}"
            mysqldump_cmd="${mysqldump_cmd//MYSQL_PASS/${MYSQL_PASS}}"
            mysqldump_cmd="${mysqldump_cmd//DB_NAME/${db}}"
            mysqldump_cmd="${mysqldump_cmd//DB_ARCH_NAME/${db_arch_name}}"

            mysqldump_out="$(eval "${mysqldump_cmd}" 2>&1)"
            mysqldump_ec="$?"

            if [ "${mysqldump_ec}" -eq 0 ] && [ -f "${db_arch_name}" ]; then
                rsync_cmd="${RSYNC_TPL}"
                rsync_cmd="${rsync_cmd//RSYNC_OPT/${RSYNC_OPT}}"
                rsync_cmd="${rsync_cmd//SRC/${db_arch_name}}"
                rsync_cmd="${rsync_cmd//DST_USER/${DST_USER}}"
                rsync_cmd="${rsync_cmd//DST_HOST/${DST_HOST}}"
                rsync_cmd="${rsync_cmd//DST_PORT/${DST_PORT}}"
                rsync_cmd="${rsync_cmd//DST_DIR/${backup_dir}}"
                rsync_cmd="${rsync_cmd//EXCLUDE /}"

                rsync_log="${log_dir}/$(date "${ARCHIVE_DATE_MASK}")_mysql_${db}${LOG_EXT}"
                rsync_with_retries "${rsync_cmd}" "${rsync_log}"
                rm -f "${db_arch_name}"
            else
                log "Error: Backup failed for the DB: '${db}'. Output: ${mysqldump_out}"
            fi

            log "Completed the DB dump: ${db}"
        done
    fi

    log "Finish DB backup"
fi
# End MySQL DBs dump

log "Finish"

if [ -n "${POST_CMD_TPL}" ]; then
    post_cmd="${POST_CMD_TPL}"
    post_cmd="${post_cmd//LOG_FILE/${log_file}}"
    post_cmd="${post_cmd//DST_DIR/${backup_dir}}"
    post_cmd="${post_cmd//SSH_TPL/${ssh_cmd}}"

#    log "Run POST_CMD: ${post_cmd}"
    log "Run POST_CMD"
    ${post_cmd}
fi

cmd="${ssh_pre_cmd}mv ${backup_dir} ${backup_final_dir}${ssh_post_cmd}"
log "Rename backup directory, run: ${cmd}"
eval "${cmd}"

# Remove old backups
if [ -n "${KEEP_LAST_BACKUPS}" ]; then
    log "All backups list:"
    if [ -n "${backups_list}" ]; then
        log "${backups_list}" 0
    else
        log "<empty>" 0
    fi

    candidates_to_remove="$(echo "${backups_list}" | head -n -"${KEEP_LAST_BACKUPS}")"
    log "List without last ${KEEP_LAST_BACKUPS} backups"
    if [ -n "${candidates_to_remove}" ]; then
        log "${candidates_to_remove}" 0
    else
        log "<empty>" 0
    fi

    keep=()
    delete=()
    first_by_uniq_str_part=

    while read -r candidate; do
        candidate_uniq_str_part="${candidate:0:${KEEP_FIRST_BY_UNIQ_STR_PART}}"

        if [ -z "${first_by_uniq_str_part}" ] || [ "${first_by_uniq_str_part}" != "${candidate_uniq_str_part}" ]; then
            keep+=("${candidate}")
            first_by_uniq_str_part="${candidate_uniq_str_part}"
        else
            delete+=("${candidate}")
        fi
    done <<< "${candidates_to_remove}"

    log "Keep backups list:"
    if [ -n "${keep[0]}" ]; then
        log "${keep[*]}" 0
    else
        log "<empty>" 0
    fi

    log "Delete backups list:"
    if [ -n "${delete[0]}" ]; then
        log "${delete[*]}" 0
        cmd="${ssh_pre_cmd}cur_dir=\$(pwd) ; cd ${backup_root_dir} && rm -rf ${delete[*]} *_temp ; cd \${cur_dir}${ssh_post_cmd}"
        log "Delete backups, run: ${cmd}"
        eval "${cmd}"
    else
        log "<empty>" 0
    fi
fi
# End Remove old backups

log "Done"
