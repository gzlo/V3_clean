#!/usr/bin/env bash

##
# Moodle CLI Backup - Detector de Instalaciones Moodle
# 
# Sistema de auto-detección inteligente de instalaciones Moodle
# Busca y valida múltiples instancias, detecta versiones y configuraciones
# 
# @version 1.0.0
# @author GZL Online
##

set -euo pipefail

# ===================== GUARDS Y VALIDACIONES =====================

if [[ "${MOODLE_DETECTOR_LOADED:-}" == "true" ]]; then
    return 0
fi

readonly MOODLE_DETECTOR_LOADED="true"

# Verificar dependencias core
if [[ "${MOODLE_BACKUP_LOGGING_LOADED:-}" != "true" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/../core/logging.sh"
fi

if [[ "${MOODLE_BACKUP_VALIDATION_LOADED:-}" != "true" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/../core/validation.sh"
fi

# ===================== CONFIGURACIÓN DE DETECCIÓN =====================

# Directorios comunes donde buscar Moodle
MOODLE_SEARCH_PATHS=(
    "/var/www"
    "/var/www/html"
    "/home/*/public_html"
    "/home/*/www"
    "/usr/local/apache/htdocs"
    "/opt/bitnami/apache2/htdocs"
    "/srv/www"
    "/www"
    "${PWD}"  # Directorio actual
)

# Archivos que identifican una instalación Moodle
MOODLE_SIGNATURE_FILES=(
    "config.php"
    "version.php"
    "lib/moodlelib.php"
    "course/lib.php"
    "admin/index.php"
)

# Patrones para identificar config.php válido
MOODLE_CONFIG_PATTERNS=(
    'CFG->dbtype\s*='
    'CFG->dbhost\s*='
    'CFG->dbname\s*='
    'CFG->dbuser\s*='
    'CFG->wwwroot\s*='
    'CFG->dataroot\s*='
)

# Configuración de búsqueda
MOODLE_MAX_SEARCH_DEPTH="${MOODLE_MAX_SEARCH_DEPTH:-3}"
MOODLE_SEARCH_TIMEOUT="${MOODLE_SEARCH_TIMEOUT:-30}"

# Estado de detección
MOODLE_DETECTION_STARTED=false
declare -a DETECTED_MOODLES=()
declare -A MOODLE_DETAILS=()

# ===================== FUNCIONES DE VALIDACIÓN =====================

##
# Verifica si un archivo es un config.php válido de Moodle
# @param $1 - Ruta al archivo config.php
# @return 0 si es válido
##
validate_moodle_config() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        return 1
    fi
    
    # Verificar que contiene los patrones básicos de Moodle
    local required_patterns=0
    local found_patterns=0
    
    for pattern in "${MOODLE_CONFIG_PATTERNS[@]}"; do
        ((required_patterns++))
        if grep -qE "$pattern" "$config_file" 2>/dev/null; then
            ((found_patterns++))
        fi
    done
    
    # Debe tener al menos 4 de 6 patrones
    if [[ $found_patterns -ge 4 ]]; then
        log_debug "Config válido: $config_file ($found_patterns/$required_patterns patrones)"
        return 0
    fi
    
    log_debug "Config inválido: $config_file ($found_patterns/$required_patterns patrones)"
    return 1
}

##
# Verifica si un directorio contiene una instalación Moodle válida
# @param $1 - Ruta al directorio
# @return 0 si es una instalación válida
##
validate_moodle_installation() {
    local moodle_dir="$1"
    
    if [[ ! -d "$moodle_dir" ]]; then
        return 1
    fi
    
    # Verificar archivos de firma
    local required_files=0
    local found_files=0
    
    for file in "${MOODLE_SIGNATURE_FILES[@]}"; do
        ((required_files++))
        if [[ -f "$moodle_dir/$file" ]]; then
            ((found_files++))
        fi
    done
    
    # Debe tener al menos 3 de 5 archivos de firma
    if [[ $found_files -ge 3 ]]; then
        # Verificar que config.php es válido
        if validate_moodle_config "$moodle_dir/config.php"; then
            log_debug "Instalación Moodle válida: $moodle_dir"
            return 0
        fi
    fi
    
    log_debug "Instalación Moodle inválida: $moodle_dir ($found_files/$required_files archivos)"
    return 1
}

# ===================== EXTRACCIÓN DE INFORMACIÓN =====================

##
# Extrae la versión de Moodle desde version.php
# @param $1 - Directorio de Moodle
##
extract_moodle_version() {
    local moodle_dir="$1"
    local version_file="$moodle_dir/version.php"
    
    if [[ ! -f "$version_file" ]]; then
        echo "desconocida"
        return
    fi
    
    # Extraer versión
    local version
    version=$(grep -E '^\$version\s*=' "$version_file" 2>/dev/null | head -1 | sed -E 's/.*=\s*([0-9]+).*/\1/' | tr -d ';')
    
    if [[ -n "$version" && "$version" =~ ^[0-9]+$ ]]; then
        # Convertir timestamp de versión a formato legible
        case "${version:0:4}" in
            "2019"*) echo "3.7" ;;
            "2020"*) echo "3.8-3.9" ;;
            "2021"*) echo "3.10-3.11" ;;
            "2022"*) echo "4.0-4.1" ;;
            "2023"*) echo "4.2-4.3" ;;
            "2024"*) echo "4.4+" ;;
            *) echo "$version" ;;
        esac
    else
        echo "desconocida"
    fi
}

##
# Extrae la configuración de base de datos desde config.php
# @param $1 - Directorio de Moodle
##
extract_moodle_database_config() {
    local moodle_dir="$1"
    local config_file="$moodle_dir/config.php"
    
    if [[ ! -f "$config_file" ]]; then
        echo "no_config"
        return
    fi
    
    # Extraer configuración de BD
    local dbtype dbhost dbname dbuser dbpass dbport
    
    dbtype=$(grep -E 'CFG->dbtype\s*=' "$config_file" 2>/dev/null | sed -E "s/.*=\s*['\"]([^'\"]+)['\"].*/\1/" | head -1)
    dbhost=$(grep -E 'CFG->dbhost\s*=' "$config_file" 2>/dev/null | sed -E "s/.*=\s*['\"]([^'\"]+)['\"].*/\1/" | head -1)
    dbname=$(grep -E 'CFG->dbname\s*=' "$config_file" 2>/dev/null | sed -E "s/.*=\s*['\"]([^'\"]+)['\"].*/\1/" | head -1)
    dbuser=$(grep -E 'CFG->dbuser\s*=' "$config_file" 2>/dev/null | sed -E "s/.*=\s*['\"]([^'\"]+)['\"].*/\1/" | head -1)
    dbport=$(grep -E 'CFG->dbport\s*=' "$config_file" 2>/dev/null | sed -E "s/.*=\s*['\"]?([^'\"]+)['\"]?.*/\1/" | head -1)
    
    # Formatear resultado
    local db_info=""
    [[ -n "$dbtype" ]] && db_info+="tipo:$dbtype"
    [[ -n "$dbhost" ]] && db_info+="|host:$dbhost"
    [[ -n "$dbname" ]] && db_info+="|db:$dbname"
    [[ -n "$dbuser" ]] && db_info+="|usuario:$dbuser"
    [[ -n "$dbport" ]] && db_info+="|puerto:$dbport"
    
    echo "${db_info:-no_config}"
}

##
# Extrae la configuración de directorios desde config.php
# @param $1 - Directorio de Moodle
##
extract_moodle_directories() {
    local moodle_dir="$1"
    local config_file="$moodle_dir/config.php"
    
    if [[ ! -f "$config_file" ]]; then
        echo "no_config"
        return
    fi
    
    # Extraer directorios
    local wwwroot dataroot
    
    wwwroot=$(grep -E 'CFG->wwwroot\s*=' "$config_file" 2>/dev/null | sed -E "s/.*=\s*['\"]([^'\"]+)['\"].*/\1/" | head -1)
    dataroot=$(grep -E 'CFG->dataroot\s*=' "$config_file" 2>/dev/null | sed -E "s/.*=\s*['\"]([^'\"]+)['\"].*/\1/" | head -1)
    
    # Formatear resultado
    local dir_info=""
    [[ -n "$wwwroot" ]] && dir_info+="wwwroot:$wwwroot"
    [[ -n "$dataroot" ]] && dir_info+="|dataroot:$dataroot"
    
    echo "${dir_info:-no_config}"
}

##
# Genera información completa de una instalación Moodle
# @param $1 - Directorio de Moodle
##
analyze_moodle_installation() {
    local moodle_dir="$1"
    
    # Extraer información básica
    local version
    version=$(extract_moodle_version "$moodle_dir")
    
    local database_config
    database_config=$(extract_moodle_database_config "$moodle_dir")
    
    local directories_config
    directories_config=$(extract_moodle_directories "$moodle_dir")
    
    # Verificar permisos de archivos
    local permissions="ok"
    if [[ ! -r "$moodle_dir/config.php" ]]; then
        permissions="sin_lectura"
    elif [[ ! -w "$moodle_dir" ]]; then
        permissions="sin_escritura"
    fi
    
    # Detectar si está activo (verificar archivos recientes)
    local last_activity="inactivo"
    if find "$moodle_dir" -name "*.log" -o -name "sessions" -type d 2>/dev/null | head -1 | xargs ls -la 2>/dev/null | grep -q "$(date +%Y-%m-%d)"; then
        last_activity="activo"
    fi
    
    # Formatear resultado completo
    local analysis=""
    analysis+="path:$moodle_dir"
    analysis+="|version:$version"
    analysis+="|database:$database_config"
    analysis+="|directories:$directories_config"
    analysis+="|permissions:$permissions"
    analysis+="|activity:$last_activity"
    
    echo "$analysis"
}

# ===================== BÚSQUEDA DE INSTALACIONES =====================

##
# Busca instalaciones Moodle en un directorio específico
# @param $1 - Directorio base para buscar
# @param $2 - Profundidad máxima (opcional)
##
search_moodle_in_directory() {
    local search_dir="$1"
    local max_depth="${2:-$MOODLE_MAX_SEARCH_DEPTH}"
    
    if [[ ! -d "$search_dir" ]]; then
        return 1
    fi
    
    log_debug "Buscando Moodle en: $search_dir (profundidad: $max_depth)"
    
    # Usar find con timeout para evitar colgarse
    local find_cmd="find '$search_dir' -maxdepth $max_depth -name 'config.php' -type f"
    
    # Ejecutar con timeout
    local config_files
    if command -v timeout >/dev/null 2>&1; then
        config_files=$(timeout "$MOODLE_SEARCH_TIMEOUT" bash -c "$find_cmd" 2>/dev/null || true)
    else
        config_files=$(eval "$find_cmd" 2>/dev/null || true)
    fi
    
    # Verificar cada config.php encontrado
    while IFS= read -r config_file; do
        if [[ -n "$config_file" ]]; then
            local moodle_dir
            moodle_dir=$(dirname "$config_file")
            
            if validate_moodle_installation "$moodle_dir"; then
                DETECTED_MOODLES+=("$moodle_dir")
                log_debug "Moodle encontrado: $moodle_dir"
            fi
        fi
    done <<< "$config_files"
}

##
# Busca en todos los directorios de búsqueda configurados
##
search_all_moodle_installations() {
    log_info "Iniciando búsqueda de instalaciones Moodle..."
    
    for search_path in "${MOODLE_SEARCH_PATHS[@]}"; do
        # Expandir wildcards para directorios de usuarios
        if [[ "$search_path" == *"*"* ]]; then
            for expanded_path in $search_path; do
                if [[ -d "$expanded_path" ]]; then
                    search_moodle_in_directory "$expanded_path"
                fi
            done
        else
            search_moodle_in_directory "$search_path"
        fi
    done
    
    log_info "Búsqueda completada. Encontradas ${#DETECTED_MOODLES[@]} instalaciones"
}

# ===================== SELECCIÓN INTERACTIVA =====================

##
# Muestra las instalaciones encontradas en formato tabla
##
show_moodle_installations() {
    if [[ ${#DETECTED_MOODLES[@]} -eq 0 ]]; then
        echo "No se encontraron instalaciones Moodle"
        return 1
    fi
    
    echo ""
    echo "┌────┬─────────────────────────────────────────────────────────────────────────┬─────────────┐"
    printf "│ %-2s │ %-71s │ %-11s │\n" "#" "RUTA DE INSTALACIÓN" "VERSIÓN"
    echo "├────┼─────────────────────────────────────────────────────────────────────────┼─────────────┤"
    
    local index=1
    for moodle_dir in "${DETECTED_MOODLES[@]}"; do
        local version
        version=$(extract_moodle_version "$moodle_dir")
        
        # Truncar ruta si es muy larga
        local display_path="$moodle_dir"
        if [[ ${#display_path} -gt 71 ]]; then
            display_path="...${display_path: -68}"
        fi
        
        printf "│ %-2d │ %-71s │ %-11s │\n" "$index" "$display_path" "$version"
        ((index++))
    done
    
    echo "└────┴─────────────────────────────────────────────────────────────────────────┴─────────────┘"
    echo ""
}

##
# Selección interactiva de instalación Moodle
# @return Ruta de la instalación seleccionada
##
select_moodle_installation() {
    local num_installations=${#DETECTED_MOODLES[@]}
    
    if [[ $num_installations -eq 0 ]]; then
        log_error "No se encontraron instalaciones Moodle"
        return 1
    fi
    
    if [[ $num_installations -eq 1 ]]; then
        log_info "Una sola instalación encontrada: ${DETECTED_MOODLES[0]}"
        echo "${DETECTED_MOODLES[0]}"
        return 0
    fi
    
    # Múltiples instalaciones - mostrar menú
    show_moodle_installations
    
    while true; do
        echo -n "Seleccione el número de instalación (1-$num_installations): "
        read -r selection
        
        if [[ "$selection" =~ ^[0-9]+$ ]] && [[ $selection -ge 1 ]] && [[ $selection -le $num_installations ]]; then
            local selected_index=$((selection - 1))
            echo "${DETECTED_MOODLES[$selected_index]}"
            return 0
        else
            echo "Selección inválida. Por favor ingrese un número entre 1 y $num_installations."
        fi
    done
}

# ===================== FUNCIÓN PRINCIPAL =====================

##
# Función principal para detectar instalaciones Moodle
# @param $1 - Comando: 'search', 'list', 'select', 'analyze'
# @param $2 - Parámetro adicional (ruta para analyze)
##
detect_moodle() {
    local command="${1:-search}"
    local parameter="${2:-}"
    
    if [[ "$MOODLE_DETECTION_STARTED" == "false" ]]; then
        MOODLE_DETECTION_STARTED=true
        search_all_moodle_installations
    fi
    
    case "$command" in
        "search")
            # Ya ejecutado arriba
            if [[ ${#DETECTED_MOODLES[@]} -gt 0 ]]; then
                printf '%s\n' "${DETECTED_MOODLES[@]}"
                return 0
            else
                return 1
            fi
            ;;
        "list")
            show_moodle_installations
            ;;
        "select")
            select_moodle_installation
            ;;
        "analyze")
            if [[ -n "$parameter" ]]; then
                analyze_moodle_installation "$parameter"
            else
                log_error "Se requiere una ruta para analizar"
                return 1
            fi
            ;;
        "count")
            echo "${#DETECTED_MOODLES[@]}"
            ;;
        *)
            log_error "Comando no válido: $command"
            log_info "Comandos disponibles: search, list, select, analyze, count"
            return 1
            ;;
    esac
}

##
# Obtiene la primera instalación Moodle encontrada
##
get_primary_moodle() {
    if [[ ${#DETECTED_MOODLES[@]} -gt 0 ]]; then
        echo "${DETECTED_MOODLES[0]}"
        return 0
    fi
    
    return 1
}

##
# Verifica si hay múltiples instalaciones
##
has_multiple_moodles() {
    [[ ${#DETECTED_MOODLES[@]} -gt 1 ]]
}

# ===================== LIMPIEZA =====================

##
# Limpia el estado de detección de Moodle
##
moodle_cleanup() {
    MOODLE_DETECTION_STARTED=false
    DETECTED_MOODLES=()
    MOODLE_DETAILS=()
    
    log_debug "Estado de detección de Moodle limpiado"
}

# ===================== MODO SCRIPT INDEPENDIENTE =====================

# Si se ejecuta directamente (no como source)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    detect_moodle "${1:-search}" "${2:-}"
fi
