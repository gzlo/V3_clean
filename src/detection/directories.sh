#!/usr/bin/env bash

##
# Moodle CLI Backup - Detector de Directorios
# 
# Sistema de detección automática de paths críticos de Moodle
# Detecta WWW_DIR, MOODLEDATA_DIR y directorios específicos por panel
# 
# @version 1.0.0
# @author GZL Online
##

set -euo pipefail

# ===================== GUARDS Y VALIDACIONES =====================

if [[ "${MOODLE_DIRECTORIES_DETECTOR_LOADED:-}" == "true" ]]; then
    return 0
fi

readonly MOODLE_DIRECTORIES_DETECTOR_LOADED="true"

# Verificar dependencias core
if [[ "${MOODLE_BACKUP_LOGGING_LOADED:-}" != "true" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/../core/logging.sh"
fi

if [[ "${MOODLE_BACKUP_VALIDATION_LOADED:-}" != "true" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/../core/validation.sh"
fi

# ===================== CONFIGURACIÓN DE DETECCIÓN =====================

# Directorios web comunes por panel de control
declare -A PANEL_WEB_DIRS=(
    # cPanel
    ["cpanel"]="/home/*/public_html"
    
    # Plesk
    ["plesk"]="/var/www/vhosts/*/httpdocs"
    
    # DirectAdmin
    ["directadmin"]="/home/*/public_html"
    
    # VestaCP/HestiaCP
    ["vestacp"]="/home/*/web/*/public_html"
    ["hestiacp"]="/home/*/web/*/public_html"
    
    # ISPConfig
    ["ispconfig"]="/var/www/*/web"
    
    # CyberPanel
    ["cyberpanel"]="/home/*/public_html"
    
    # Docker/Manual
    ["docker"]="/var/www/html"
    ["manual"]="/var/www/html"
)

# Directorios de datos comunes
declare -A PANEL_DATA_DIRS=(
    ["cpanel"]="/home/*/moodledata"
    ["plesk"]="/var/www/vhosts/*/moodledata"
    ["directadmin"]="/home/*/moodledata"
    ["vestacp"]="/home/*/web/*/moodledata"
    ["hestiacp"]="/home/*/web/*/moodledata"
    ["ispconfig"]="/var/www/*/moodledata"
    ["cyberpanel"]="/home/*/moodledata"
    ["docker"]="/var/moodledata"
    ["manual"]="/var/moodledata"
)

# Directorios web estándar del sistema
STANDARD_WEB_DIRS=(
    "/var/www/html"
    "/var/www"
    "/usr/local/apache/htdocs"
    "/usr/local/apache2/htdocs"
    "/opt/bitnami/apache2/htdocs"
    "/srv/www"
    "/www"
    "/var/www/localhost/htdocs"  # Gentoo
    "/usr/share/nginx/html"      # Nginx
)

# Directorios de datos estándar
STANDARD_DATA_DIRS=(
    "/var/moodledata"
    "/opt/moodledata"
    "/srv/moodledata"
    "/home/moodledata"
    "/usr/local/moodledata"
)

# Configuración de búsqueda
DIRECTORIES_MAX_DEPTH="${DIRECTORIES_MAX_DEPTH:-4}"
DIRECTORIES_SEARCH_TIMEOUT="${DIRECTORIES_SEARCH_TIMEOUT:-30}"

# Estado de detección
DIRECTORIES_DETECTION_STARTED=false
declare -A DETECTED_DIRECTORIES=()
declare -A DIRECTORY_ANALYSIS=()

# ===================== FUNCIONES DE DETECCIÓN POR PANEL =====================

##
# Detecta directorios para un panel específico
# @param $1 - Nombre del panel
##
detect_panel_directories() {
    local panel_name="$1"
    local web_pattern="${PANEL_WEB_DIRS[$panel_name]:-}"
    local data_pattern="${PANEL_DATA_DIRS[$panel_name]:-}"
    
    local found_dirs=""
    
    # Buscar directorios web
    if [[ -n "$web_pattern" ]]; then
        log_debug "Buscando directorios web para $panel_name: $web_pattern"
        
        # Expandir wildcards
        for web_dir in $web_pattern; do
            if [[ -d "$web_dir" ]]; then
                # Verificar si contiene instalación Moodle
                if [[ -f "$web_dir/config.php" ]] && [[ -f "$web_dir/version.php" ]]; then
                    found_dirs+="web:$web_dir|"
                    log_debug "Directorio web Moodle encontrado: $web_dir"
                fi
            fi
        done
    fi
    
    # Buscar directorios de datos
    if [[ -n "$data_pattern" ]]; then
        log_debug "Buscando directorios de datos para $panel_name: $data_pattern"
        
        for data_dir in $data_pattern; do
            if [[ -d "$data_dir" ]]; then
                # Verificar características típicas de moodledata
                if is_moodledata_directory "$data_dir"; then
                    found_dirs+="data:$data_dir|"
                    log_debug "Directorio de datos Moodle encontrado: $data_dir"
                fi
            fi
        done
    fi
    
    if [[ -n "$found_dirs" ]]; then
        echo "${found_dirs%|}"  # Remover último |
        return 0
    fi
    
    return 1
}

##
# Verifica si un directorio parece ser moodledata
# @param $1 - Ruta del directorio
##
is_moodledata_directory() {
    local dir="$1"
    
    if [[ ! -d "$dir" ]]; then
        return 1
    fi
    
    # Verificar subdirectorios típicos de moodledata
    local moodle_subdirs=("cache" "filedir" "sessions" "temp" "trashdir")
    local found_subdirs=0
    
    for subdir in "${moodle_subdirs[@]}"; do
        if [[ -d "$dir/$subdir" ]]; then
            ((found_subdirs++))
        fi
    done
    
    # Debe tener al menos 2 subdirectorios típicos
    if [[ $found_subdirs -ge 2 ]]; then
        return 0
    fi
    
    # Verificar archivos de configuración específicos
    if [[ -f "$dir/environment.xml" ]] || [[ -f "$dir/.htaccess" ]]; then
        return 0
    fi
    
    return 1
}

# ===================== DETECCIÓN DESDE CONFIG.PHP =====================

##
# Extrae directorios desde config.php de Moodle
# @param $1 - Ruta al directorio de Moodle o archivo config.php
##
extract_directories_from_config() {
    local moodle_path="$1"
    local config_file=""
    
    if [[ -f "$moodle_path" ]]; then
        config_file="$moodle_path"
    elif [[ -d "$moodle_path" ]]; then
        config_file="$moodle_path/config.php"
    else
        log_error "Ruta no válida: $moodle_path"
        return 1
    fi
    
    if [[ ! -f "$config_file" ]]; then
        log_error "Archivo config.php no encontrado: $config_file"
        return 1
    fi
    
    # Extraer WWW root y data root
    local wwwroot dataroot dirroot
    
    wwwroot=$(grep -E '^\s*\$CFG->wwwroot\s*=' "$config_file" 2>/dev/null | sed -E "s/.*=\s*['\"]([^'\"]+)['\"].*/\1/" | head -1)
    dataroot=$(grep -E '^\s*\$CFG->dataroot\s*=' "$config_file" 2>/dev/null | sed -E "s/.*=\s*['\"]([^'\"]+)['\"].*/\1/" | head -1)
    dirroot=$(grep -E '^\s*\$CFG->dirroot\s*=' "$config_file" 2>/dev/null | sed -E "s/.*=\s*['\"]([^'\"]+)['\"].*/\1/" | head -1)
    
    # Si dirroot no está definido, usar el directorio del config.php
    if [[ -z "$dirroot" ]]; then
        dirroot=$(dirname "$config_file")
    fi
    
    local config_dirs=""
    [[ -n "$wwwroot" ]] && config_dirs+="wwwroot:$wwwroot|"
    [[ -n "$dataroot" ]] && config_dirs+="dataroot:$dataroot|"
    [[ -n "$dirroot" ]] && config_dirs+="dirroot:$dirroot|"
    
    if [[ -n "$config_dirs" ]]; then
        echo "${config_dirs%|}"
        return 0
    fi
    
    return 1
}

# ===================== BÚSQUEDA AUTOMÁTICA =====================

##
# Busca directorios web estándar que contengan Moodle
##
search_standard_web_directories() {
    local found_dirs=""
    
    log_debug "Buscando en directorios web estándar..."
    
    for web_dir in "${STANDARD_WEB_DIRS[@]}"; do
        if [[ -d "$web_dir" ]]; then
            # Buscar config.php en el directorio y subdirectorios
            local config_files
            config_files=$(find "$web_dir" -maxdepth "$DIRECTORIES_MAX_DEPTH" -name "config.php" -type f 2>/dev/null || true)
            
            while IFS= read -r config_file; do
                if [[ -n "$config_file" ]]; then
                    local moodle_dir
                    moodle_dir=$(dirname "$config_file")
                    
                    # Verificar que es una instalación Moodle válida
                    if [[ -f "$moodle_dir/version.php" ]] && [[ -f "$moodle_dir/lib/moodlelib.php" ]]; then
                        found_dirs+="web:$moodle_dir|"
                        log_debug "Directorio web Moodle encontrado: $moodle_dir"
                    fi
                fi
            done <<< "$config_files"
        fi
    done
    
    if [[ -n "$found_dirs" ]]; then
        echo "${found_dirs%|}"
        return 0
    fi
    
    return 1
}

##
# Busca directorios de datos estándar
##
search_standard_data_directories() {
    local found_dirs=""
    
    log_debug "Buscando directorios de datos estándar..."
    
    for data_dir in "${STANDARD_DATA_DIRS[@]}"; do
        if is_moodledata_directory "$data_dir"; then
            found_dirs+="data:$data_dir|"
            log_debug "Directorio de datos encontrado: $data_dir"
        fi
    done
    
    # Buscar en ubicaciones comunes con nombres variables
    local search_patterns=(
        "/var/www/*/moodledata"
        "/home/*/moodledata"
        "/opt/*/moodledata"
    )
    
    for pattern in "${search_patterns[@]}"; do
        for data_dir in $pattern; do
            if is_moodledata_directory "$data_dir"; then
                found_dirs+="data:$data_dir|"
                log_debug "Directorio de datos encontrado: $data_dir"
            fi
        done
    done
    
    if [[ -n "$found_dirs" ]]; then
        echo "${found_dirs%|}"
        return 0
    fi
    
    return 1
}

# ===================== ANÁLISIS DE DIRECTORIOS =====================

##
# Analiza las propiedades de un directorio
# @param $1 - Ruta del directorio
# @param $2 - Tipo de directorio (web|data)
##
analyze_directory() {
    local dir_path="$1"
    local dir_type="$2"
    
    if [[ ! -d "$dir_path" ]]; then
        echo "status:not_found"
        return 1
    fi
    
    local analysis=""
    
    # Verificar permisos
    local permissions="ok"
    if [[ ! -r "$dir_path" ]]; then
        permissions="no_read"
    elif [[ ! -w "$dir_path" ]]; then
        permissions="no_write"
    elif [[ ! -x "$dir_path" ]]; then
        permissions="no_execute"
    fi
    
    analysis+="permissions:$permissions|"
    
    # Calcular tamaño del directorio
    local size="unknown"
    if command -v du >/dev/null 2>&1; then
        size=$(du -sh "$dir_path" 2>/dev/null | cut -f1 || echo "unknown")
    fi
    analysis+="size:$size|"
    
    # Verificar propietario
    local owner="unknown"
    if command -v stat >/dev/null 2>&1; then
        owner=$(stat -c %U "$dir_path" 2>/dev/null || stat -f %Su "$dir_path" 2>/dev/null || echo "unknown")
    fi
    analysis+="owner:$owner|"
    
    # Verificar espacio libre
    local free_space="unknown"
    if command -v df >/dev/null 2>&1; then
        free_space=$(df -h "$dir_path" 2>/dev/null | tail -1 | awk '{print $4}' || echo "unknown")
    fi
    analysis+="free_space:$free_space|"
    
    # Análisis específico por tipo
    case "$dir_type" in
        "web")
            # Verificar archivos PHP
            local php_files
            php_files=$(find "$dir_path" -name "*.php" -type f 2>/dev/null | wc -l)
            analysis+="php_files:$php_files|"
            
            # Verificar si hay .htaccess
            if [[ -f "$dir_path/.htaccess" ]]; then
                analysis+="htaccess:present|"
            else
                analysis+="htaccess:missing|"
            fi
            ;;
        "data")
            # Contar subdirectorios
            local subdirs
            subdirs=$(find "$dir_path" -maxdepth 1 -type d 2>/dev/null | wc -l)
            subdirs=$((subdirs - 1))  # Excluir el directorio padre
            analysis+="subdirs:$subdirs|"
            
            # Verificar archivos de log
            local log_files
            log_files=$(find "$dir_path" -name "*.log" -type f 2>/dev/null | wc -l)
            analysis+="log_files:$log_files|"
            ;;
    esac
    
    echo "${analysis%|}"
    return 0
}

##
# Valida la configuración de directorios
# @param $1 - Lista de directorios detectados
##
validate_directories_configuration() {
    local directories="$1"
    local validation_result="valid"
    local issues=""
    
    # Verificar que hay al menos un directorio web y uno de datos
    local has_web=false
    local has_data=false
    
    IFS='|' read -ra DIR_ARRAY <<< "$directories"
    for dir_entry in "${DIR_ARRAY[@]}"; do
        if [[ "$dir_entry" == web:* ]]; then
            has_web=true
        elif [[ "$dir_entry" == data:* ]]; then
            has_data=true
        fi
    done
    
    if [[ "$has_web" == "false" ]]; then
        validation_result="warning"
        issues+="no_web_dir|"
    fi
    
    if [[ "$has_data" == "false" ]]; then
        validation_result="warning"
        issues+="no_data_dir|"
    fi
    
    # Verificar permisos de cada directorio
    for dir_entry in "${DIR_ARRAY[@]}"; do
        local dir_type="${dir_entry%%:*}"
        local dir_path="${dir_entry##*:}"
        
        local analysis
        analysis=$(analyze_directory "$dir_path" "$dir_type")
        
        if echo "$analysis" | grep -q "permissions:no_"; then
            validation_result="error"
            issues+="permission_error:$dir_path|"
        fi
    done
    
    echo "status:$validation_result|issues:${issues%|}"
    return 0
}

# ===================== FUNCIÓN PRINCIPAL =====================

##
# Función principal para detectar directorios
# @param $1 - Panel detectado (opcional)
# @param $2 - Ruta de Moodle para extraer config (opcional)
##
detect_directories() {
    local detected_panel="${1:-}"
    local moodle_path="${2:-}"
    
    if [[ "$DIRECTORIES_DETECTION_STARTED" == "true" ]]; then
        log_debug "Detección de directorios ya ejecutada"
        # Retornar resultado existente
        for dir_id in "${!DETECTED_DIRECTORIES[@]}"; do
            echo "${DETECTED_DIRECTORIES[$dir_id]}"
        done
        return 0
    fi
    
    DIRECTORIES_DETECTION_STARTED=true
    
    log_info "Iniciando detección de directorios..."
    
    local all_directories=""
    
    # 1. Intentar extraer desde config.php si se proporciona
    if [[ -n "$moodle_path" ]]; then
        log_debug "Extrayendo directorios desde config.php..."
        local config_dirs
        if config_dirs=$(extract_directories_from_config "$moodle_path"); then
            all_directories+="$config_dirs|"
        fi
    fi
    
    # 2. Detectar por panel específico si se proporciona
    if [[ -n "$detected_panel" ]] && [[ "$detected_panel" != "manual" ]]; then
        log_debug "Detectando directorios para panel: $detected_panel"
        local panel_dirs
        if panel_dirs=$(detect_panel_directories "$detected_panel"); then
            all_directories+="$panel_dirs|"
        fi
    fi
    
    # 3. Búsqueda en directorios estándar
    log_debug "Buscando en directorios estándar..."
    local standard_web_dirs
    if standard_web_dirs=$(search_standard_web_directories); then
        all_directories+="$standard_web_dirs|"
    fi
    
    local standard_data_dirs
    if standard_data_dirs=$(search_standard_data_directories); then
        all_directories+="$standard_data_dirs|"
    fi
    
    # Limpiar duplicados y formatear resultado
    if [[ -n "$all_directories" ]]; then
        all_directories="${all_directories%|}"  # Remover último |
        
        # Remover duplicados
        local unique_dirs=""
        IFS='|' read -ra DIR_ARRAY <<< "$all_directories"
        for dir_entry in "${DIR_ARRAY[@]}"; do
            if [[ "$unique_dirs" != *"$dir_entry"* ]]; then
                unique_dirs+="$dir_entry|"
            fi
        done
        unique_dirs="${unique_dirs%|}"
        
        # Analizar cada directorio
        IFS='|' read -ra UNIQUE_DIR_ARRAY <<< "$unique_dirs"
        for dir_entry in "${UNIQUE_DIR_ARRAY[@]}"; do
            local dir_type="${dir_entry%%:*}"
            local dir_path="${dir_entry##*:}"
            local analysis
            analysis=$(analyze_directory "$dir_path" "$dir_type")
            DIRECTORY_ANALYSIS["$dir_entry"]="$analysis"
        done
        
        # Validar configuración
        local validation
        validation=$(validate_directories_configuration "$unique_dirs")
        
        # Almacenar resultado
        DETECTED_DIRECTORIES["main"]="$unique_dirs"
        DETECTED_DIRECTORIES["validation"]="$validation"
        
        log_success "Detección de directorios completada"
        echo "$unique_dirs"
        return 0
    else
        log_warning "No se detectaron directorios válidos"
        return 1
    fi
}

##
# Obtiene análisis detallado de un directorio
# @param $1 - Entrada de directorio (tipo:ruta)
##
get_directory_analysis() {
    local dir_entry="$1"
    echo "${DIRECTORY_ANALYSIS[$dir_entry]:-}"
}

##
# Obtiene solo directorios de un tipo específico
# @param $1 - Tipo de directorio (web|data|wwwroot|dataroot|dirroot)
##
get_directories_by_type() {
    local dir_type="$1"
    local result=""
    
    for dir_id in "${!DETECTED_DIRECTORIES[@]}"; do
        if [[ "$dir_id" == "main" ]]; then
            local directories="${DETECTED_DIRECTORIES[$dir_id]}"
            IFS='|' read -ra DIR_ARRAY <<< "$directories"
            for dir_entry in "${DIR_ARRAY[@]}"; do
                if [[ "$dir_entry" == $dir_type:* ]]; then
                    local dir_path="${dir_entry##*:}"
                    result+="$dir_path "
                fi
            done
        fi
    done
    
    echo "${result% }"  # Remover último espacio
}

# ===================== LIMPIEZA =====================

##
# Limpia el estado de detección de directorios
##
directories_cleanup() {
    DIRECTORIES_DETECTION_STARTED=false
    DETECTED_DIRECTORIES=()
    DIRECTORY_ANALYSIS=()
    
    log_debug "Estado de detección de directorios limpiado"
}

# ===================== MODO SCRIPT INDEPENDIENTE =====================

# Si se ejecuta directamente (no como source)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    detect_directories "${1:-}" "${2:-}"
fi
