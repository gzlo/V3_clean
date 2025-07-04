#!/bin/bash

##
# Sistema de Logging Avanzado - Moodle Backup CLI
# Versión: 1.0.0
#
# Proporciona un sistema de logging robusto con múltiples niveles,
# rotación automática, y salida tanto a archivo como a stdout.
##

# Guard para evitar carga múltiple
[[ "${MOODLE_BACKUP_LOGGING_LOADED:-}" == "true" ]] && return 0
export MOODLE_BACKUP_LOGGING_LOADED="true"

# Cargar dependencias con verificación
if [[ "${MOODLE_BACKUP_CONSTANTS_LOADED:-}" != "true" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/../../lib/constants.sh"
fi

if [[ "${MOODLE_BACKUP_COLORS_LOADED:-}" != "true" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/../../lib/colors.sh"
fi

if [[ "${MOODLE_BACKUP_FILESYSTEM_LOADED:-}" != "true" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/../../lib/filesystem.sh"
fi

# ===================== CONFIGURACIÓN DE LOGGING =====================

# Niveles de logging (numéricos para comparación)
[[ -z "${LOG_LEVEL_ERROR:-}" ]] && readonly LOG_LEVEL_ERROR=1
[[ -z "${LOG_LEVEL_WARN:-}" ]] && readonly LOG_LEVEL_WARN=2
[[ -z "${LOG_LEVEL_INFO:-}" ]] && readonly LOG_LEVEL_INFO=3
[[ -z "${LOG_LEVEL_DEBUG:-}" ]] && readonly LOG_LEVEL_DEBUG=4

# Configuración por defecto
LOG_LEVEL_CURRENT=${LOG_LEVEL_CURRENT:-$LOG_LEVEL_INFO}
LOG_TO_FILE=${LOG_TO_FILE:-true}
LOG_TO_STDOUT=${LOG_TO_STDOUT:-true}
LOG_FILE="${LOG_FILE:-${TEST_TEMP_DIR:-${DEFAULT_LOG_DIR:-/tmp}}/moodle-backup.log}"
LOG_MAX_SIZE=${LOG_MAX_SIZE:-10485760}  # 10MB
LOG_MAX_FILES=${LOG_MAX_FILES:-5}
LOG_TIMESTAMP_FORMAT=${LOG_TIMESTAMP_FORMAT:-"%Y-%m-%d %H:%M:%S"}

# Patrones de formato
[[ -z "${LOG_FORMAT_STDOUT:-}" ]] && readonly LOG_FORMAT_STDOUT="[%s] %s: %s"
[[ -z "${LOG_FORMAT_FILE:-}" ]] && readonly LOG_FORMAT_FILE="[%s] [PID:%s] %s: %s"

# ===================== FUNCIONES PRIVADAS =====================

##
# Obtiene el timestamp actual formateado
##
_get_timestamp() {
    date +"$LOG_TIMESTAMP_FORMAT"
}

##
# Obtiene el PID del proceso actual
##
_get_pid() {
    echo $$
}

##
# Convierte nivel de string a número
# @param $1 string Nivel de logging (ERROR, WARN, INFO, DEBUG)
# @return int Nivel numérico
##
_level_to_number() {
    local level="$1"
    case "${level^^}" in
        ERROR) echo $LOG_LEVEL_ERROR ;;
        WARN)  echo $LOG_LEVEL_WARN ;;
        INFO)  echo $LOG_LEVEL_INFO ;;
        DEBUG) echo $LOG_LEVEL_DEBUG ;;
        *) echo $LOG_LEVEL_INFO ;;
    esac
}

##
# Verifica si un nivel debe ser loggeado
# @param $1 string Nivel del mensaje
# @return bool true si debe loggearse
##
_should_log() {
    local level="$1"
    local level_num
    level_num=$(_level_to_number "$level")
    [[ $level_num -le $LOG_LEVEL_CURRENT ]]
}

##
# Obtiene el color para un nivel de logging
# @param $1 string Nivel de logging
# @return string Código de color
##
_get_level_color() {
    local level="$1"
    case "${level^^}" in
        ERROR) echo "$RED" ;;
        WARN)  echo "$YELLOW" ;;
        INFO)  echo "$GREEN" ;;
        DEBUG) echo "$CYAN" ;;
        *) echo "$NC" ;;
    esac
}

##
# Crea el directorio de logs si no existe
##
_ensure_log_directory() {
    local log_dir
    log_dir=$(dirname "$LOG_FILE")
    
    if [[ ! -d "$log_dir" ]]; then
        if command -v create_directory_safe >/dev/null 2>&1; then
            create_directory_safe "$log_dir"
        else
            mkdir -p "$log_dir" 2>/dev/null || true
        fi
    fi
}

##
# Rota el archivo de log si excede el tamaño máximo
##
_rotate_log_if_needed() {
    [[ "$LOG_TO_FILE" != "true" ]] && return 0
    [[ ! -f "$LOG_FILE" ]] && return 0
    
    local file_size
    if command -v get_file_size >/dev/null 2>&1; then
        file_size=$(get_file_size "$LOG_FILE")
    else
        file_size=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
    fi
    
    if [[ $file_size -gt $LOG_MAX_SIZE ]]; then
        _rotate_logs
    fi
}

##
# Realiza la rotación de logs
##
_rotate_logs() {
    local base_file="$LOG_FILE"
    
    # Eliminar el archivo más antiguo si existe
    if [[ -f "${base_file}.${LOG_MAX_FILES}" ]]; then
        rm -f "${base_file}.${LOG_MAX_FILES}"
    fi
    
    # Rotar archivos existentes
    for ((i = LOG_MAX_FILES - 1; i >= 1; i--)); do
        if [[ -f "${base_file}.${i}" ]]; then
            mv "${base_file}.${i}" "${base_file}.$((i + 1))"
        fi
    done
    
    # Rotar el archivo actual
    if [[ -f "$base_file" ]]; then
        mv "$base_file" "${base_file}.1"
    fi
    
    # Crear nuevo archivo de log
    touch "$base_file"
}

##
# Escribe mensaje a archivo de log
# @param $1 string Nivel
# @param $2 string Mensaje
##
_write_to_file() {
    local level="$1"
    local message="$2"
    local timestamp
    local pid
    
    timestamp=$(_get_timestamp)
    pid=$(_get_pid)
    
    printf "$LOG_FORMAT_FILE\n" "$timestamp" "$pid" "$level" "$message" >> "$LOG_FILE" 2>/dev/null || true
}

##
# Escribe mensaje a stdout
# @param $1 string Nivel
# @param $2 string Mensaje
##
_write_to_stdout() {
    local level="$1"
    local message="$2"
    local timestamp
    local color
    local reset
    
    timestamp=$(_get_timestamp)
    color=$(_get_level_color "$level")
    reset="$NC"
    
    # Si NO_COLOR está configurado, no usar colores
    if [[ -n "${NO_COLOR:-}" ]]; then
        color=""
        reset=""
    fi
    
    printf "${color}${LOG_FORMAT_STDOUT}${reset}\n" "$timestamp" "$level" "$message"
}

# ===================== FUNCIONES PÚBLICAS =====================

##
# Configura el nivel de logging global
# @param $1 string Nivel (ERROR, WARN, INFO, DEBUG)
##
log_set_level() {
    local level="$1"
    
    if [[ -z "$level" ]]; then
        echo "Error: Nivel de logging requerido" >&2
        return 1
    fi
    
    LOG_LEVEL_CURRENT=$(_level_to_number "$level")
    export LOG_LEVEL_CURRENT
}

##
# Configura el archivo de log
# @param $1 string Path del archivo de log
##
log_set_file() {
    local file="$1"
    
    if [[ -z "$file" ]]; then
        echo "Error: Archivo de log requerido" >&2
        return 1
    fi
    
    LOG_FILE="$file"
    export LOG_FILE
    _ensure_log_directory
}

##
# Habilita o deshabilita logging a archivo
# @param $1 bool true/false
##
log_set_file_output() {
    local enabled="$1"
    LOG_TO_FILE="$enabled"
    export LOG_TO_FILE
    
    if [[ "$enabled" == "true" ]]; then
        _ensure_log_directory
    fi
}

##
# Habilita o deshabilita logging a stdout
# @param $1 bool true/false
##
log_set_stdout_output() {
    local enabled="$1"
    LOG_TO_STDOUT="$enabled"
    export LOG_TO_STDOUT
}

##
# Función principal de logging
# @param $1 string Nivel (ERROR, WARN, INFO, DEBUG)
# @param $2 string Mensaje
##
log() {
    local level="$1"
    local message="$2"
    
    # Validación de parámetros
    if [[ -z "$level" || -z "$message" ]]; then
        echo "Error: log() requiere nivel y mensaje" >&2
        return 1
    fi
    
    # Verificar si debe loggearse
    if ! _should_log "$level"; then
        return 0
    fi
    
    # Asegurar directorio de logs y rotar si es necesario
    if [[ "$LOG_TO_FILE" == "true" ]]; then
        _ensure_log_directory
        _rotate_log_if_needed
    fi
    
    # Escribir a archivo si está habilitado
    if [[ "$LOG_TO_FILE" == "true" ]]; then
        _write_to_file "$level" "$message"
    fi
    
    # Escribir a stdout si está habilitado
    if [[ "$LOG_TO_STDOUT" == "true" ]]; then
        _write_to_stdout "$level" "$message"
    fi
}

##
# Funciones de conveniencia para cada nivel
##
log_error() {
    log "ERROR" "$*"
}

log_warn() {
    log "WARN" "$*"
}

log_info() {
    log "INFO" "$*"
}

log_debug() {
    log "DEBUG" "$*"
}

##
# Obtiene información del estado del logging
##
log_status() {
    echo "=== Estado del Sistema de Logging ==="
    echo "Nivel actual: $LOG_LEVEL_CURRENT"
    echo "Log a archivo: $LOG_TO_FILE"
    echo "Log a stdout: $LOG_TO_STDOUT"
    echo "Archivo de log: $LOG_FILE"
    echo "Tamaño máximo: $LOG_MAX_SIZE bytes"
    echo "Archivos máximos: $LOG_MAX_FILES"
    
    if [[ "$LOG_TO_FILE" == "true" && -f "$LOG_FILE" ]]; then
        local size
        if command -v get_file_size >/dev/null 2>&1; then
            size=$(get_file_size "$LOG_FILE")
        else
            size=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo "desconocido")
        fi
        echo "Tamaño actual: $size bytes"
    fi
}

##
# Limpia logs antiguos manualmente
##
log_cleanup() {
    local days="${1:-30}"
    local log_dir
    log_dir=$(dirname "$LOG_FILE")
    
    if [[ -d "$log_dir" ]]; then
        find "$log_dir" -name "$(basename "$LOG_FILE")*" -type f -mtime +$days -delete 2>/dev/null || true
        log_info "Limpieza de logs completada (archivos > $days días)"
    fi
}

##
# Exporta las funciones principales para uso externo
##
export -f log log_error log_warn log_info log_debug
export -f log_set_level log_set_file log_set_file_output log_set_stdout_output
export -f log_status log_cleanup
