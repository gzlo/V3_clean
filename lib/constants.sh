#!/bin/bash

##
# Constantes Globales del Sistema Moodle Backup CLI
# Versión: 1.0.0
# 
# Este archivo contiene todas las constantes globales utilizadas
# a través del sistema modular de Moodle Backup CLI.
##

# Guard para evitar carga múltiple
[[ "${MOODLE_BACKUP_CONSTANTS_LOADED:-}" == "true" ]] && return 0
export MOODLE_BACKUP_CONSTANTS_LOADED="true"

# ===================== INFORMACIÓN DEL SISTEMA =====================

# Información de versión
readonly MOODLE_BACKUP_VERSION="3.5.0"
readonly MOODLE_BACKUP_NAME="Moodle Backup CLI"
readonly MOODLE_BACKUP_AUTHOR="GZLOnline"

# Aliases para compatibilidad
readonly PROJECT_NAME="$MOODLE_BACKUP_NAME"
readonly VERSION="$MOODLE_BACKUP_VERSION"

readonly MOODLE_BACKUP_REPO="https://github.com/gzlo/moodle-backup-cli"

# Identificadores de compatibilidad
readonly MOODLE_BACKUP_MIN_BASH_VERSION="4.0"
readonly MOODLE_BACKUP_SUPPORTED_OS=("linux" "darwin")

# ===================== CONFIGURACIÓN DE PATHS =====================

# Directorios base del sistema
readonly MOODLE_BACKUP_ROOT_DIR="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")"
readonly MOODLE_BACKUP_SRC_DIR="$MOODLE_BACKUP_ROOT_DIR/src"
readonly MOODLE_BACKUP_LIB_DIR="$MOODLE_BACKUP_ROOT_DIR/lib"
readonly MOODLE_BACKUP_CONFIG_DIR="$MOODLE_BACKUP_ROOT_DIR/config"
readonly MOODLE_BACKUP_SCRIPTS_DIR="$MOODLE_BACKUP_ROOT_DIR/scripts"

# Directorios de runtime
readonly MOODLE_BACKUP_DEFAULT_TMP_DIR="/tmp"
readonly MOODLE_BACKUP_DEFAULT_LOG_DIR="/var/log/moodle-backup"
readonly MOODLE_BACKUP_DEFAULT_CONFIG_SYSTEM="/etc/moodle-backup"
readonly MOODLE_BACKUP_DEFAULT_CONFIG_USER="$HOME/.config/moodle-backup"

# ===================== CONFIGURACIÓN DE LOGGING =====================

# Niveles de logging
readonly LOG_LEVEL_ERROR=1
readonly LOG_LEVEL_WARN=2  
readonly LOG_LEVEL_INFO=3
readonly LOG_LEVEL_DEBUG=4
readonly LOG_LEVEL_TRACE=5

# Nombres de niveles
readonly LOG_LEVEL_NAMES=(
    [1]="ERROR"
    [2]="WARN"
    [3]="INFO" 
    [4]="DEBUG"
    [5]="TRACE"
)

# Configuración de archivos de log
readonly DEFAULT_LOG_FILE="moodle-backup.log"
readonly DEFAULT_ERROR_LOG_FILE="moodle-backup-error.log"
readonly MAX_LOG_SIZE_MB=50
readonly MAX_LOG_FILES=5

# ===================== TIMEOUTS Y LÍMITES =====================

# Timeouts de operación (en segundos)
readonly DEFAULT_OPERATION_TIMEOUT=3600      # 1 hora
readonly DEFAULT_DATABASE_TIMEOUT=1800       # 30 minutos
readonly DEFAULT_UPLOAD_TIMEOUT=7200         # 2 horas
readonly DEFAULT_COMPRESSION_TIMEOUT=3600    # 1 hora
readonly DEFAULT_NETWORK_TIMEOUT=300         # 5 minutos

# Límites de reintentos
readonly DEFAULT_MAX_RETRIES=3
readonly DEFAULT_RETRY_DELAY=5
readonly DEFAULT_EXPONENTIAL_BACKOFF=2

# Límites de tamaño de archivo
readonly MAX_SINGLE_FILE_SIZE_GB=10
readonly MAX_TOTAL_BACKUP_SIZE_GB=50

# ===================== CONFIGURACIÓN DE COMPRESIÓN =====================

# Algoritmos de compresión soportados
readonly COMPRESSION_ALGORITHMS=("gzip" "zstd" "xz" "bzip2")
readonly DEFAULT_COMPRESSION_ALGORITHM="zstd"
readonly DEFAULT_COMPRESSION_LEVEL=3

# Extensiones de archivo
readonly COMPRESSION_EXTENSIONS=(
    ["gzip"]=".gz"
    ["zstd"]=".zst" 
    ["xz"]=".xz"
    ["bzip2"]=".bz2"
)

# ===================== CONFIGURACIÓN DE PANELES =====================

# Tipos de paneles soportados
readonly SUPPORTED_PANELS=("cpanel" "plesk" "directadmin" "vestacp" "hestia" "ispconfig" "cyberpanel" "manual" "docker")

# Paths típicos por panel
readonly CPANEL_PATHS=("/home" "/home2" "/home3")
readonly PLESK_PATHS=("/var/www/vhosts")
readonly DIRECTADMIN_PATHS=("/home" "/usr/local/directadmin/data/users")
readonly VESTACP_PATHS=("/home")
readonly ISPCONFIG_PATHS=("/var/www" "/var/www/clients")

# ===================== CONFIGURACIÓN DE BASE DE DATOS =====================

# Motores de BD soportados
readonly SUPPORTED_DB_ENGINES=("mysql" "mariadb" "postgresql")
readonly DEFAULT_DB_PORT_MYSQL=3306
readonly DEFAULT_DB_PORT_POSTGRESQL=5432

# Configuración de dumps
readonly DEFAULT_MYSQL_DUMP_OPTIONS="--single-transaction --routines --triggers --lock-tables=false"
readonly DEFAULT_POSTGRESQL_DUMP_OPTIONS="--no-owner --no-privileges --clean"

# ===================== CONFIGURACIÓN DE CLOUD =====================

# Proveedores cloud soportados
readonly SUPPORTED_CLOUD_PROVIDERS=("gdrive" "s3" "dropbox" "onedrive")
readonly DEFAULT_CLOUD_PROVIDER="gdrive"

# Configuración de Google Drive
readonly GDRIVE_MAX_FILE_SIZE_GB=5
readonly GDRIVE_MAX_PARALLEL_UPLOADS=3
readonly GDRIVE_CHUNK_SIZE_MB=256

# ===================== CONFIGURACIÓN DE MOODLE =====================

# Versiones de Moodle soportadas
readonly MIN_MOODLE_VERSION="3.5"
readonly SUPPORTED_MOODLE_VERSIONS=("3.5" "3.6" "3.7" "3.8" "3.9" "3.10" "3.11" "4.0" "4.1" "4.2" "4.3" "4.4")

# Archivos críticos de Moodle
readonly MOODLE_CONFIG_FILE="config.php"
readonly MOODLE_VERSION_FILE="version.php"
readonly MOODLE_INSTALL_FILE="install.php"

# Directorios críticos de Moodle (relativos a WWW_DIR)
readonly MOODLE_CRITICAL_DIRS=("admin" "auth" "blocks" "course" "enrol" "lib" "login" "mod" "theme")

# ===================== PATRONES DE EXCLUSIÓN =====================

# Patrones para exclusión de backup de archivos
readonly DEFAULT_EXCLUDE_PATTERNS=(
    "*.tmp"
    "*.log"
    "*.cache"
    "*/.git/*"
    "*/node_modules/*"
    "*/cache/*"
    "*/temp/*"
    "*/sessions/*"
    "*/.sass-cache/*"
    "*/localcache/*"
    "*/backup_*"
)

# Extensiones temporales a excluir
readonly TEMP_FILE_EXTENSIONS=("tmp" "temp" "cache" "lock" "pid" "swp" "swo" "orig" "rej")

# ===================== CÓDIGOS DE SALIDA =====================

# Códigos de exit estándar
readonly EXIT_SUCCESS=0
readonly EXIT_GENERAL_ERROR=1
readonly EXIT_MISUSE=2
readonly EXIT_CANNOT_EXECUTE=126
readonly EXIT_COMMAND_NOT_FOUND=127
readonly EXIT_INVALID_EXIT_ARGUMENT=128
readonly EXIT_FATAL_ERROR_SIGNAL=130

# Códigos específicos del sistema
readonly EXIT_CONFIG_ERROR=10
readonly EXIT_DEPENDENCY_ERROR=11
readonly EXIT_VALIDATION_ERROR=12
readonly EXIT_PERMISSION_ERROR=13
readonly EXIT_NETWORK_ERROR=14
readonly EXIT_DISK_SPACE_ERROR=15
readonly EXIT_DATABASE_ERROR=16
readonly EXIT_COMPRESSION_ERROR=17
readonly EXIT_UPLOAD_ERROR=18
readonly EXIT_MOODLE_ERROR=19

# ===================== EXPRESIONES REGULARES =====================

# Patrones de validación comunes
readonly REGEX_EMAIL="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
readonly REGEX_IPV4="^([0-9]{1,3}\.){3}[0-9]{1,3}$"
readonly REGEX_DOMAIN="^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$"
readonly REGEX_URL="^https?://[^\s/$.?#].[^\s]*$"

# Patrones específicos de Moodle
readonly REGEX_MOODLE_DB_PREFIX="^[a-zA-Z][a-zA-Z0-9_]*$"
readonly REGEX_MOODLE_VERSION="^[0-9]+\.[0-9]+(\.[0-9]+)?(\+|\-[a-zA-Z0-9]+)?$"

# ===================== CONFIGURACIÓN DE UI =====================

# Caracteres para progreso y UI
readonly PROGRESS_CHARS=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
readonly PROGRESS_BAR_CHAR="█"
readonly PROGRESS_BAR_EMPTY_CHAR="░"
readonly PROGRESS_BAR_WIDTH=40

# Símbolos de estado
readonly SYMBOL_SUCCESS="✓"
readonly SYMBOL_ERROR="✗"
readonly SYMBOL_WARNING="⚠"
readonly SYMBOL_INFO="ℹ"
readonly SYMBOL_QUESTION="?"
readonly SYMBOL_ARROW="➤"

# ===================== CONFIGURACIÓN DE NOTIFICACIONES =====================

# Tipos de notificación
readonly NOTIFICATION_TYPES=("email" "webhook" "slack" "telegram")
readonly DEFAULT_NOTIFICATION_TYPE="email"

# Templates de mensaje
readonly EMAIL_SUBJECT_SUCCESS="[Moodle Backup] Backup completado exitosamente"
readonly EMAIL_SUBJECT_ERROR="[Moodle Backup] Error en proceso de backup"
readonly EMAIL_SUBJECT_WARNING="[Moodle Backup] Advertencias en proceso de backup"

# ===================== CONFIGURACIÓN DE DESARROLLO =====================

# Variables de debug
readonly DEBUG_VARS=("MOODLE_BACKUP_DEBUG" "MOODLE_BACKUP_TRACE" "MOODLE_BACKUP_VERBOSE")

# Colores para debug (si no están cargados desde colors.sh)
readonly DEBUG_COLOR_RESET="\033[0m"
readonly DEBUG_COLOR_RED="\033[31m"
readonly DEBUG_COLOR_GREEN="\033[32m"
readonly DEBUG_COLOR_YELLOW="\033[33m"
readonly DEBUG_COLOR_BLUE="\033[34m"
readonly DEBUG_COLOR_PURPLE="\033[35m"
readonly DEBUG_COLOR_CYAN="\033[36m"

# ===================== FUNCIONES DE UTILIDAD PARA CONSTANTES =====================

##
# Verifica si un valor está en un array de constantes
#
# Arguments:
#   $1 - Valor a buscar
#   $2 - Nombre del array (sin $)
# Returns:
#   0 - Si el valor está en el array
#   1 - Si el valor no está en el array
##
is_value_in_const_array() {
    local value="$1"
    local array_name="$2"
    local -n array_ref="$array_name"
    
    local item
    for item in "${array_ref[@]}"; do
        [[ "$item" == "$value" ]] && return 0
    done
    
    return 1
}

##
# Obtiene el valor de una constante asociativa
#
# Arguments:
#   $1 - Clave
#   $2 - Nombre del array asociativo (sin $)
# Returns:
#   0 - Si la clave existe
#   1 - Si la clave no existe
# Outputs:
#   Valor asociado a la clave
##
get_const_assoc_value() {
    local key="$1"
    local array_name="$2"
    local -n array_ref="$array_name"
    
    if [[ -n "${array_ref[$key]:-}" ]]; then
        echo "${array_ref[$key]}"
        return 0
    fi
    
    return 1
}

##
# Valida que la versión de Bash sea compatible
#
# Returns:
#   0 - Si la versión es compatible
#   1 - Si la versión no es compatible
##
validate_bash_version() {
    local current_version="${BASH_VERSION%%.*}"
    local min_version="${MOODLE_BACKUP_MIN_BASH_VERSION%%.*}"
    
    [[ "$current_version" -ge "$min_version" ]]
}

# ===================== INICIALIZACIÓN =====================

# Validar entorno básico al cargar constantes
if ! validate_bash_version; then
    echo "ERROR: Bash $MOODLE_BACKUP_MIN_BASH_VERSION+ requerido. Versión actual: $BASH_VERSION" >&2
    exit $EXIT_DEPENDENCY_ERROR
fi

# Exportar variables críticas para subprocesos
export MOODLE_BACKUP_VERSION
export MOODLE_BACKUP_ROOT_DIR
export MOODLE_BACKUP_SRC_DIR
export MOODLE_BACKUP_LIB_DIR
