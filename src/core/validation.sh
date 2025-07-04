#!/bin/bash

##
# Sistema de Validación de Entorno - Moodle Backup CLI
# Versión: 1.0.0
#
# Proporciona validación exhaustiva de entorno, dependencias,
# permisos y configuración antes de ejecutar operaciones de backup
##

# Guard para evitar carga múltiple
[[ "${MOODLE_BACKUP_VALIDATION_LOADED:-}" == "true" ]] && return 0
export MOODLE_BACKUP_VALIDATION_LOADED="true"

# Cargar dependencias con verificación
if [[ "${MOODLE_BACKUP_CONSTANTS_LOADED:-}" != "true" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/../../lib/constants.sh"
fi

if [[ "${MOODLE_BACKUP_UTILS_LOADED:-}" != "true" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/../../lib/utils.sh"
fi

if [[ "${MOODLE_BACKUP_FILESYSTEM_LOADED:-}" != "true" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/../../lib/filesystem.sh"
fi

if [[ "${MOODLE_BACKUP_LOGGING_LOADED:-}" != "true" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"
fi

# ===================== CONFIGURACIÓN DE VALIDACIÓN =====================

# Comandos requeridos del sistema
readonly REQUIRED_COMMANDS=(
    "bash"
    "date"
    "tar"
    "gzip"
    "find"
    "sed"
    "awk"
    "grep"
    "cut"
    "sort"
    "tr"
    "head"
    "tail"
    "wc"
    "chmod"
    "chown"
    "mkdir"
    "rm"
    "cp"
    "mv"
    "ln"
)

# Comandos opcionales pero recomendados
readonly OPTIONAL_COMMANDS=(
    "zstd"          # Compresión avanzada
    "xz"            # Compresión alternativa
    "bzip2"         # Compresión alternativa
    "mysql"         # Cliente MySQL
    "mysqldump"     # Backup MySQL
    "pg_dump"       # Backup PostgreSQL
    "rsync"         # Sincronización de archivos
    "rclone"        # Cloud storage
    "gpg"           # Encriptación
    "openssl"       # Encriptación/SSL
    "curl"          # HTTP requests
    "wget"          # HTTP requests
    "mail"          # Notificaciones email
    "sendmail"      # Notificaciones email
    "pv"            # Progress viewer
    "parallel"      # Procesamiento paralelo
)

# Versiones mínimas requeridas
if [[ "${MOODLE_CLI_TEST_MODE:-}" == "true" ]]; then
    # En modo test, permitir redeclaración de arrays globales
    declare -gA MIN_VERSIONS 2>/dev/null || true
    declare -gA REQUIRED_PERMISSIONS 2>/dev/null || true
    declare -gA VALIDATION_RESULTS 2>/dev/null || true
else
    # En modo normal, usar declaración estándar
    declare -A MIN_VERSIONS
    declare -A REQUIRED_PERMISSIONS
    declare -A VALIDATION_RESULTS
fi

# Inicializar MIN_VERSIONS
MIN_VERSIONS=(
    ["bash"]="4.0"
    ["mysql"]="5.5"
    ["mysqldump"]="5.5"
    ["pg_dump"]="9.0"
    ["zstd"]="1.3"
    ["rclone"]="1.50"
)

# Inicializar REQUIRED_PERMISSIONS
REQUIRED_PERMISSIONS=(
    ["read"]="r"
    ["write"]="w" 
    ["execute"]="x"
)

# Contadores de validación (inicializados)
declare -gi VALIDATION_ERRORS=0
declare -gi VALIDATION_WARNINGS=0

# VALIDATION_RESULTS ya se declara arriba según el modo

##
# Inicializa las variables de validación
##
_init_validation() {
    VALIDATION_ERRORS=0
    VALIDATION_WARNINGS=0
    
    # Reinicializar el array según el modo
    if [[ "${MOODLE_CLI_TEST_MODE:-}" == "true" ]]; then
        declare -gA VALIDATION_RESULTS 2>/dev/null || true
        VALIDATION_RESULTS=()
    else
        VALIDATION_RESULTS=()
    fi
}

# Inicializar al cargar el módulo
_init_validation

# ===================== FUNCIONES PRIVADAS =====================

##
# Obtiene la versión de un comando
# @param $1 string Comando
# @return string Versión o vacío si no se puede determinar
##
_get_command_version() {
    local cmd="$1"
    local version=""
    local timeout_cmd="timeout 5s"
    
    # En Windows/Git Bash, timeout puede no estar disponible
    if ! command -v timeout >/dev/null 2>&1; then
        timeout_cmd=""
    fi
    
    case "$cmd" in
        bash)
            version=$(${timeout_cmd} bash --version </dev/null 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+' | head -n1)
            ;;
        mysql|mysqldump)
            # Evitar colgarse en entorno de test sin configuración MySQL
            if [[ "${MOODLE_CLI_TEST_MODE:-}" == "true" ]]; then
                version=$(${timeout_cmd} $cmd --version </dev/null 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || echo "")
            else
                version=$(${timeout_cmd} $cmd --version </dev/null 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
            fi
            ;;
        pg_dump)
            version=$(${timeout_cmd} $cmd --version </dev/null 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -n1)
            ;;
        zstd)
            version=$(${timeout_cmd} $cmd --version </dev/null 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
            ;;
        rclone)
            version=$(${timeout_cmd} $cmd version </dev/null 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
            ;;
        mail|sendmail)
            # Comandos de correo pueden ser problemáticos, skip en modo test
            if [[ "${MOODLE_CLI_TEST_MODE:-}" == "true" ]]; then
                version=""
            else
                for flag in "--version" "-V" "-v"; do
                    if version=$(${timeout_cmd} $cmd $flag </dev/null 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1); then
                        break
                    fi
                done
            fi
            ;;
        *)
            # Intentar obtener versión con métodos comunes y timeout
            for flag in "--version" "-V" "-v" "version"; do
                if version=$(${timeout_cmd} $cmd $flag </dev/null 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1); then
                    break
                fi
            done
            ;;
    esac
    
    echo "$version"
}

##
# Compara versiones semánticas
# @param $1 string Versión actual
# @param $2 string Versión mínima requerida
# @return int 0 si actual >= mínima
##
_compare_versions() {
    local current="$1"
    local required="$2"
    
    [[ -z "$current" || -z "$required" ]] && return 1
    
    # Si BC está disponible, usar comparación decimal
    if [[ "${BC_AVAILABLE:-false}" == "true" ]]; then
        (( $(echo "$current >= $required" | bc -l 2>/dev/null || echo 0) ))
    else
        # Fallback: comparación simple por strings
        [[ "$current" == "$required" ]] || [[ "$current" > "$required" ]]
    fi
}

##
# Registra un error de validación
# @param $1 string Categoría
# @param $2 string Mensaje
##
_validation_error() {
    local category="$1"
    local message="$2"
    
    ((VALIDATION_ERRORS++))
    VALIDATION_RESULTS["ERROR_${VALIDATION_ERRORS}"]="[$category] $message"
    log_error "Validación: $message"
}

##
# Registra una advertencia de validación
# @param $1 string Categoría
# @param $2 string Mensaje
##
_validation_warning() {
    local category="$1"
    local message="$2"
    
    ((VALIDATION_WARNINGS++))
    VALIDATION_RESULTS["WARNING_${VALIDATION_WARNINGS}"]="[$category] $message"
    log_warn "Validación: $message"
}

##
# Registra un éxito de validación
# @param $1 string Categoría
# @param $2 string Mensaje
##
_validation_success() {
    local category="$1"
    local message="$2"
    
    VALIDATION_RESULTS["SUCCESS_${category}"]="$message"
    log_debug "Validación OK: $message"
}

# ===================== FUNCIONES DE VALIDACIÓN =====================

##
# Valida la versión de Bash
# @return int 0 si es válida
##
validate_bash_version() {
    log_debug "Validando versión de Bash"
    
    local bash_version
    bash_version=$(bash --version | head -n1 | grep -oE '[0-9]+\.[0-9]+' | head -n1)
    
    if [[ -z "$bash_version" ]]; then
        _validation_error "BASH" "No se puede determinar la versión de Bash"
        return 1
    fi
    
    local min_version="${MIN_VERSIONS[bash]}"
    if _compare_versions "$bash_version" "$min_version"; then
        _validation_success "BASH" "Versión de Bash: $bash_version (>= $min_version)"
        return 0
    else
        _validation_error "BASH" "Versión de Bash $bash_version < $min_version (requerida)"
        return 1
    fi
}

##
# Valida comandos requeridos del sistema
# @return int 0 si todos están disponibles
##
validate_required_commands() {
    log_debug "Validando comandos requeridos"
    
    local missing_commands=()
    local errors=0
    
    for cmd in "${REQUIRED_COMMANDS[@]}"; do
        if command_exists "$cmd"; then
            _validation_success "COMMAND" "Comando requerido '$cmd' disponible"
        else
            missing_commands+=("$cmd")
            _validation_error "COMMAND" "Comando requerido '$cmd' no encontrado"
            ((errors++))
        fi
    done
    
    if (( errors > 0 )); then
        _validation_error "COMMANDS" "Faltan ${#missing_commands[@]} comandos requeridos: ${missing_commands[*]}"
        return 1
    fi
    
    _validation_success "COMMANDS" "Todos los comandos requeridos están disponibles"
    return 0
}

##
# Valida comandos opcionales
##
validate_optional_commands() {
    log_debug "Validando comandos opcionales"
    
    local available=()
    local missing=()
    local skipped=()
    
    for cmd in "${OPTIONAL_COMMANDS[@]}"; do
        # En modo test, saltarse comandos problemáticos en Windows/Git Bash
        if [[ "${MOODLE_CLI_TEST_MODE:-}" == "true" ]]; then
            case "$cmd" in
                mysql|mysqldump|pg_dump|mail|sendmail)
                    log_debug "Saltando validación de '$cmd' en modo test"
                    skipped+=("$cmd")
                    continue
                    ;;
            esac
        fi
        
        if command_exists "$cmd"; then
            local version
            # Usar timeout en la obtención de versión para evitar bloqueos
            if version=$(_get_command_version "$cmd" 2>/dev/null); then
                if [[ -n "${MIN_VERSIONS[$cmd]:-}" ]]; then
                    local min_version="${MIN_VERSIONS[$cmd]}"
                    if [[ -n "$version" ]] && _compare_versions "$version" "$min_version"; then
                        available+=("$cmd ($version)")
                        _validation_success "OPTIONAL" "Comando '$cmd' versión $version disponible"
                    elif [[ -n "$version" ]]; then
                        _validation_warning "OPTIONAL" "Comando '$cmd' versión $version < $min_version (recomendada)"
                        available+=("$cmd ($version)")
                    else
                        available+=("$cmd")
                        _validation_success "OPTIONAL" "Comando '$cmd' disponible"
                    fi
                else
                    if [[ -n "$version" ]]; then
                        available+=("$cmd ($version)")
                    else
                        available+=("$cmd")
                    fi
                    _validation_success "OPTIONAL" "Comando '$cmd' disponible"
                fi
            else
                # Comando existe pero no pudimos obtener versión
                available+=("$cmd")
                _validation_success "OPTIONAL" "Comando '$cmd' disponible (versión no determinada)"
            fi
        else
            missing+=("$cmd")
            log_debug "Comando opcional '$cmd' no disponible"
        fi
    done
    
    local total_checked=$((${#OPTIONAL_COMMANDS[@]} - ${#skipped[@]}))
    log_info "Comandos opcionales disponibles: ${#available[@]}/${total_checked}"
    
    if (( ${#missing[@]} > 0 )); then
        log_info "Comandos opcionales faltantes: ${missing[*]}"
    fi
    
    if (( ${#skipped[@]} > 0 )); then
        log_debug "Comandos opcionales omitidos: ${skipped[*]}"
    fi
}

##
# Valida permisos de directorio
# @param $1 string Ruta del directorio
# @param $2 string Permisos requeridos (rwx)
# @return int 0 si los permisos son correctos
##
validate_directory_permissions() {
    local dir_path="$1"
    local required_perms="$2"
    
    [[ -n "$dir_path" ]] || {
        _validation_error "PERMISSIONS" "validate_directory_permissions: ruta vacía"
        return 1
    }
    
    # Crear directorio si no existe
    if [[ ! -d "$dir_path" ]]; then
        if mkdir -p "$dir_path" 2>/dev/null; then
            _validation_success "DIRECTORY" "Directorio '$dir_path' creado"
        else
            _validation_error "DIRECTORY" "No se puede crear directorio '$dir_path'"
            return 1
        fi
    fi
    
    # Validar permisos
    local errors=0
    
    if [[ "$required_perms" =~ r ]] && [[ ! -r "$dir_path" ]]; then
        _validation_error "PERMISSIONS" "Sin permisos de lectura en '$dir_path'"
        ((errors++))
    fi
    
    if [[ "$required_perms" =~ w ]] && [[ ! -w "$dir_path" ]]; then
        _validation_error "PERMISSIONS" "Sin permisos de escritura en '$dir_path'"
        ((errors++))
    fi
    
    if [[ "$required_perms" =~ x ]] && [[ ! -x "$dir_path" ]]; then
        _validation_error "PERMISSIONS" "Sin permisos de ejecución en '$dir_path'"
        ((errors++))
    fi
    
    if (( errors == 0 )); then
        _validation_success "PERMISSIONS" "Permisos '$required_perms' correctos en '$dir_path'"
        return 0
    else
        return 1
    fi
}

##
# Valida espacio en disco disponible
# @param $1 string Directorio a verificar
# @param $2 int Espacio mínimo requerido en MB
# @return int 0 si hay suficiente espacio
##
validate_disk_space() {
    local dir_path="$1"
    local required_mb="$2"
    
    [[ -n "$dir_path" && -n "$required_mb" ]] || {
        _validation_error "DISK_SPACE" "validate_disk_space: parámetros inválidos"
        return 1
    }
    
    [[ -d "$dir_path" ]] || {
        _validation_error "DISK_SPACE" "Directorio '$dir_path' no existe"
        return 1
    }
    
    # Obtener espacio disponible en KB
    local available_kb
    available_kb=$(df "$dir_path" | awk 'NR==2 {print $4}' 2>/dev/null)
    
    [[ -n "$available_kb" && "$available_kb" =~ ^[0-9]+$ ]] || {
        _validation_error "DISK_SPACE" "No se puede determinar espacio disponible en '$dir_path'"
        return 1
    }
    
    # Convertir a MB
    local available_mb=$((available_kb / 1024))
    local required_mb_int=$((required_mb))
    
    if (( available_mb >= required_mb_int )); then
        _validation_success "DISK_SPACE" "Espacio disponible: ${available_mb}MB >= ${required_mb_int}MB en '$dir_path'"
        return 0
    else
        _validation_error "DISK_SPACE" "Espacio insuficiente: ${available_mb}MB < ${required_mb_int}MB en '$dir_path'"
        return 1
    fi
}

##
# Valida conectividad de red (opcional)
# @param $1 string Host a probar
# @param $2 int Puerto (opcional, default 80)
# @return int 0 si hay conectividad
##
validate_network_connectivity() {
    local host="${1:-google.com}"
    local port="${2:-80}"
    
    # Solo validar si hay comandos de red disponibles
    if ! command_exists "curl" && ! command_exists "wget" && ! command_exists "nc"; then
        log_debug "Sin comandos de red disponibles, saltando validación de conectividad"
        return 0
    fi
    
    log_debug "Validando conectividad de red a $host:$port"
    
    # Probar con curl primero
    if command_exists "curl"; then
        if curl -s --connect-timeout 5 "$host:$port" >/dev/null 2>&1; then
            _validation_success "NETWORK" "Conectividad OK usando curl a $host:$port"
            return 0
        fi
    fi
    
    # Probar con wget
    if command_exists "wget"; then
        if wget -q --timeout=5 --tries=1 --spider "http://$host" >/dev/null 2>&1; then
            _validation_success "NETWORK" "Conectividad OK usando wget a $host"
            return 0
        fi
    fi
    
    # Probar con netcat si está disponible
    if command_exists "nc"; then
        if echo "" | nc -w 5 "$host" "$port" >/dev/null 2>&1; then
            _validation_success "NETWORK" "Conectividad OK usando nc a $host:$port"
            return 0
        fi
    fi
    
    _validation_warning "NETWORK" "No se puede validar conectividad a $host:$port"
    return 1
}

# ===================== FUNCIONES PÚBLICAS =====================

##
# Ejecuta validación completa del entorno
# @return int 0 si toda la validación pasa
##
validate_environment() {
    log_info "Iniciando validación del entorno"
    
    # Reiniciar contadores
    _init_validation
    
    # Validaciones críticas
    validate_bash_version
    validate_required_commands
    
    # Validaciones opcionales
    validate_optional_commands
    validate_network_connectivity
    
    # Reporte final
    log_info "Validación del entorno completada: $VALIDATION_ERRORS errores, $VALIDATION_WARNINGS advertencias"
    
    return $VALIDATION_ERRORS
}

##
# Valida configuración de backup específica
# @param $1 string Directorio de backup
# @param $2 string Directorio temporal
# @param $3 int Espacio mínimo requerido en MB (opcional)
# @return int 0 si la validación pasa
##
validate_backup_environment() {
    local backup_dir="$1"
    local temp_dir="$2"
    local min_space_mb="${3:-1024}"  # 1GB por defecto
    
    log_info "Validando entorno de backup"
    
    local errors=0
    
    # Validar directorio de backup
    if [[ -n "$backup_dir" ]]; then
        validate_directory_permissions "$backup_dir" "rwx" || ((errors++))
        validate_disk_space "$backup_dir" "$min_space_mb" || ((errors++))
    else
        _validation_error "CONFIG" "Directorio de backup no especificado"
        ((errors++))
    fi
    
    # Validar directorio temporal
    if [[ -n "$temp_dir" ]]; then
        validate_directory_permissions "$temp_dir" "rwx" || ((errors++))
        validate_disk_space "$temp_dir" "$((min_space_mb / 2))" || ((errors++))
    else
        _validation_error "CONFIG" "Directorio temporal no especificado"
        ((errors++))
    fi
    
    # Validar comandos específicos de backup
    local backup_commands=("tar" "gzip")
    for cmd in "${backup_commands[@]}"; do
        if ! command_exists "$cmd"; then
            _validation_error "BACKUP" "Comando de backup '$cmd' no disponible"
            ((errors++))
        fi
    done
    
    return $errors
}

##
# Valida configuración de base de datos
# @param $1 string Tipo de BD (mysql, postgresql)
# @param $2 string Host
# @param $3 string Puerto
# @param $4 string Usuario
# @param $5 string Base de datos
# @return int 0 si la validación pasa
##
validate_database_config() {
    local db_type="$1"
    local db_host="${2:-localhost}"
    local db_port="$3"
    local db_user="$4"
    local db_name="$5"
    
    log_info "Validando configuración de base de datos $db_type"
    
    local errors=0
    
    case "$db_type" in
        mysql)
            # Validar cliente MySQL
            if ! command_exists "mysql"; then
                _validation_error "DATABASE" "Cliente MySQL no disponible"
                ((errors++))
            fi
            
            if ! command_exists "mysqldump"; then
                _validation_error "DATABASE" "mysqldump no disponible"
                ((errors++))
            fi
            
            # Validar puerto por defecto
            [[ -z "$db_port" ]] && db_port="3306"
            ;;
            
        postgresql)
            if ! command_exists "pg_dump"; then
                _validation_error "DATABASE" "pg_dump no disponible"
                ((errors++))
            fi
            
            [[ -z "$db_port" ]] && db_port="5432"
            ;;
            
        *)
            _validation_error "DATABASE" "Tipo de base de datos no soportado: $db_type"
            ((errors++))
            return $errors
            ;;
    esac
    
    # Validar configuración básica
    [[ -z "$db_user" ]] && {
        _validation_error "DATABASE" "Usuario de base de datos no especificado"
        ((errors++))
    }
    
    [[ -z "$db_name" ]] && {
        _validation_error "DATABASE" "Nombre de base de datos no especificado"
        ((errors++))
    }
    
    # Validar puerto
    if [[ -n "$db_port" ]] && ! [[ "$db_port" =~ ^[0-9]+$ ]]; then
        _validation_error "DATABASE" "Puerto de base de datos inválido: $db_port"
        ((errors++))
    fi
    
    return $errors
}

##
# Muestra reporte de validación
##
validation_report() {
    echo "=== REPORTE DE VALIDACIÓN ==="
    echo
    
    if (( VALIDATION_ERRORS == 0 && VALIDATION_WARNINGS == 0 )); then
        echo "✅ Todas las validaciones pasaron exitosamente"
        return 0
    fi
    
    if (( VALIDATION_ERRORS > 0 )); then
        echo "❌ ERRORES ($VALIDATION_ERRORS):"
        for key in "${!VALIDATION_RESULTS[@]}"; do
            if [[ "$key" =~ ^ERROR_ ]]; then
                echo "  • ${VALIDATION_RESULTS[$key]}"
            fi
        done
        echo
    fi
    
    if (( VALIDATION_WARNINGS > 0 )); then
        echo "⚠️  ADVERTENCIAS ($VALIDATION_WARNINGS):"
        for key in "${!VALIDATION_RESULTS[@]}"; do
            if [[ "$key" =~ ^WARNING_ ]]; then
                echo "  • ${VALIDATION_RESULTS[$key]}"
            fi
        done
        echo
    fi
    
    # Mostrar éxitos si estamos en modo debug
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo "✅ VALIDACIONES EXITOSAS:"
        for key in "${!VALIDATION_RESULTS[@]}"; do
            if [[ "$key" =~ ^SUCCESS_ ]]; then
                echo "  • ${VALIDATION_RESULTS[$key]}"
            fi
        done
        echo
    fi
    
    return $VALIDATION_ERRORS
}

##
# Diagnóstico del sistema para troubleshooting
##
system_diagnostic() {
    echo "=== DIAGNÓSTICO DEL SISTEMA ==="
    echo
    
    echo "Sistema operativo:"
    uname -a 2>/dev/null || echo "  No disponible"
    echo
    
    echo "Información de distribución:"
    if [[ -f /etc/os-release ]]; then
        grep -E "^(NAME|VERSION)" /etc/os-release
    elif [[ -f /etc/redhat-release ]]; then
        cat /etc/redhat-release
    elif [[ -f /etc/debian_version ]]; then
        echo "Debian $(cat /etc/debian_version)"
    else
        echo "  Distribución no identificada"
    fi
    echo
    
    echo "Versión de Bash:"
    bash --version | head -n1
    echo
    
    echo "Espacio en disco:"
    df -h 2>/dev/null || echo "  No disponible"
    echo
    
    echo "Memoria del sistema:"
    if command_exists "free"; then
        free -h
    else
        echo "  Comando 'free' no disponible"
    fi
    echo
    
    echo "Carga del sistema:"
    if [[ -f /proc/loadavg ]]; then
        echo "  $(cat /proc/loadavg)"
    else
        echo "  No disponible"
    fi
    echo
    
    echo "Comandos disponibles:"
    for cmd in "${REQUIRED_COMMANDS[@]}" "${OPTIONAL_COMMANDS[@]}"; do
        if command_exists "$cmd"; then
            local version
            version=$(_get_command_version "$cmd")
            if [[ -n "$version" ]]; then
                printf "  ✓ %-15s %s\n" "$cmd" "$version"
            else
                printf "  ✓ %-15s %s\n" "$cmd" "(disponible)"
            fi
        else
            printf "  ✗ %-15s %s\n" "$cmd" "(no disponible)"
        fi
    done
}
