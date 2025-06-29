#!/bin/bash

# ===================== MOODLE BACKUP V3 - ARCHIVOS INDEPENDIENTES =====================
# Versión 3.0 con compresión y subida por archivos separados
# Base: V1 (snapshots + hard links) + V2 (robustez) + NUEVO: archivos independientes
# Autor: Sistema Moodle Backup - Versión: 3.0 Archivos Independientes
# Fecha: 2025-06-29
#
# CAMBIOS PRINCIPALES V3:
# - Compresión separada: database.sql.gz + moodle_core.tar.zst + moodledata.tar.zst
# - Subida secuencial con reintentos granulares por archivo
# - Estructura de carpetas por fecha: /backups/moodle_backup_YYYY-MM-DD/
# - Retención por carpetas completas en Google Drive
# - Logging granular y recuperación inteligente ante fallos parciales
# - Verificación de integridad individual por archivo
# ===============================================================================

set -euo pipefail

# Configuración específica para cron
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin"
export HOME="/root"

# ===================== FUNCIONES DE LOGGING BÁSICAS (PARA CONFIGURACIÓN) =====================
# Versiones simples que no dependen de variables de configuración
basic_log() {
    local level="$1"
    shift
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="[$timestamp] [$level] $*"
    
    # Solo a stdout durante la carga de configuración
    echo "$message"
}

basic_log_info() { basic_log "INFO" "$@"; }
basic_log_warn() { basic_log "WARN" "$@"; }
basic_log_error() { basic_log "ERROR" "$@"; }

# ===================== SISTEMA DE CONFIGURACIÓN EXTERNA (V3 NUEVO) =====================

# Función para cargar configuración externa
load_configuration() {
    local config_loaded=false
    
    # Orden de precedencia para archivos de configuración
    local config_files=(
        "./moodle_backup.conf"          # Configuración local (mayor prioridad)
        "/etc/moodle_backup.conf"       # Configuración global
        "$(dirname "$0")/moodle_backup.conf"  # Junto al script
    )
    
    basic_log_info "Cargando configuración externa..."
    
    # Intentar cargar configuración desde archivos
    for config_file in "${config_files[@]}"; do
        if [[ -f "$config_file" ]] && [[ -r "$config_file" ]]; then
            basic_log_info "Cargando configuración desde: $config_file"
            
            # Cargar solo variables válidas (seguridad)
            while IFS='=' read -r key value; do
                # Ignorar comentarios y líneas vacías
                [[ "$key" =~ ^[[:space:]]*# ]] && continue
                [[ -z "$key" ]] && continue
                
                # Validar formato de variable
                if [[ "$key" =~ ^[A-Z_][A-Z0-9_]*$ ]]; then
                    # Remover comillas si existen
                    value=$(echo "$value" | sed 's/^["\047]//' | sed 's/["\047]$//')
                    
                    # Solo sobrescribir si la variable no está ya definida por entorno
                    if [[ -z "${!key:-}" ]]; then
                        declare -g "$key"="$value"
                        basic_log_info "Configuración cargada: $key=${!key}"
                    else
                        basic_log_info "Variable ya definida por entorno: $key"
                    fi
                fi
            done < <(grep -E '^[A-Z_][A-Z0-9_]*=' "$config_file" 2>/dev/null)
            
            config_loaded=true
            break
        fi
    done
    
    if [[ "$config_loaded" == "false" ]]; then
        basic_log_info "No se encontró archivo de configuración, usando valores por defecto"
    fi
    
    return 0
}

# Función para detectar el tipo de panel de control
detect_panel_type() {
    if [[ "$PANEL_TYPE" != "auto" ]]; then
        basic_log_info "Tipo de panel forzado: $PANEL_TYPE"
        return 0
    fi
    
    basic_log_info "Detectando tipo de panel de control..."
    
    # Detectar cPanel
    if [[ -d "/usr/local/cpanel" ]] || [[ -f "/etc/cpanel.config" ]] || command -v whmapi1 >/dev/null 2>&1; then
        PANEL_TYPE="cpanel"
        basic_log_info "Detectado: cPanel"
        return 0
    fi
    
    # Detectar Plesk
    if [[ -d "/opt/psa" ]] || [[ -f "/etc/psa/.psa.shadow" ]] || command -v plesk >/dev/null 2>&1; then
        PANEL_TYPE="plesk"
        basic_log_info "Detectado: Plesk"
        return 0
    fi
    
    # Detectar DirectAdmin
    if [[ -d "/usr/local/directadmin" ]] || [[ -f "/etc/directadmin.conf" ]]; then
        PANEL_TYPE="directadmin"
        basic_log_info "Detectado: DirectAdmin"
        return 0
    fi
    
    # Detectar VestaCP/HestiaCP
    if [[ -d "/usr/local/vesta" ]] || [[ -d "/usr/local/hestia" ]] || command -v v-list-users >/dev/null 2>&1; then
        PANEL_TYPE="vestacp"
        basic_log_info "Detectado: VestaCP/HestiaCP"
        return 0
    fi
    
    # Detectar ISPConfig
    if [[ -d "/usr/local/ispconfig" ]] || [[ -f "/etc/ispconfig.conf" ]]; then
        PANEL_TYPE="ispconfig"
        basic_log_info "Detectado: ISPConfig"
        return 0
    fi
    
    # Si no se detecta ningún panel
    PANEL_TYPE="manual"
    basic_log_info "No se detectó panel específico - Modo manual/instalación directa"
    return 0
}

# Función para auto-detectar configuración de Moodle UNIVERSAL
auto_detect_moodle_config() {
    basic_log_info "Iniciando auto-detección universal de configuración Moodle..."
    
    # Verificar si se requiere configuración obligatoria
    if [[ "$REQUIRE_CONFIG" == "true" ]]; then
        basic_log_error "REQUIRE_CONFIG=true: Se requiere archivo de configuración obligatorio"
        basic_log_error "No se realizará auto-detección. Crear moodle_backup.conf"
        return 1
    fi
    
    # Detectar tipo de panel primero
    detect_panel_type
    
    # Auto-detectar usuario según el panel
    auto_detect_user
    
    # Auto-detectar directorios según el panel
    auto_detect_directories
    
    # Auto-detectar configuración de BD desde config.php
    auto_detect_database_config
    
    basic_log_info "Auto-detección universal completada"
    return 0
}

# Función para auto-detectar usuario según el panel
auto_detect_user() {
    if [[ -n "${CPANEL_USER:-}" ]]; then
        basic_log_info "Usuario ya definido: $CPANEL_USER"
        return 0
    fi
    
    case "$PANEL_TYPE" in
        "cpanel")
            if [[ -n "${USER:-}" ]] && [[ "$USER" != "root" ]]; then
                CPANEL_USER="$USER"
                basic_log_info "Auto-detectado usuario cPanel: $CPANEL_USER"
            fi
            ;;
        "plesk")
            # En Plesk, el usuario puede no ser relevante, usar dominio
            if [[ -n "${USER:-}" ]] && [[ "$USER" != "root" ]]; then
                CPANEL_USER="$USER"
                basic_log_info "Auto-detectado usuario Plesk: $CPANEL_USER"
            fi
            ;;
        "directadmin"|"vestacp"|"ispconfig")
            if [[ -n "${USER:-}" ]] && [[ "$USER" != "root" ]]; then
                CPANEL_USER="$USER"
                basic_log_info "Auto-detectado usuario ${PANEL_TYPE}: $CPANEL_USER"
            fi
            ;;
        "manual")
            basic_log_warn "Instalación manual detectada - Usuario puede no ser relevante"
            if [[ -n "${USER:-}" ]] && [[ "$USER" != "root" ]]; then
                CPANEL_USER="$USER"
                basic_log_info "Usando usuario del sistema: $CPANEL_USER"
            fi
            ;;
    esac
}

# Función para auto-detectar directorios según el panel de control
auto_detect_directories() {
    basic_log_info "Auto-detectando directorios para panel: $PANEL_TYPE"
    
    case "$PANEL_TYPE" in
        "cpanel")
            auto_detect_directories_cpanel
            ;;
        "plesk")
            auto_detect_directories_plesk
            ;;
        "directadmin")
            auto_detect_directories_directadmin
            ;;
        "vestacp")
            auto_detect_directories_vestacp
            ;;
        "ispconfig")
            auto_detect_directories_ispconfig
            ;;
        "manual")
            auto_detect_directories_manual
            ;;
        *)
            basic_log_warn "Panel desconocido '$PANEL_TYPE', usando detección manual"
            auto_detect_directories_manual
            ;;
    esac
}

# Función específica para cPanel
auto_detect_directories_cpanel() {
    local user="${CPANEL_USER:-$USER}"
    
    if [[ -z "$user" ]] || [[ "$user" == "root" ]]; then
        basic_log_warn "No se pudo determinar usuario cPanel válido"
        return 1
    fi
    
    basic_log_info "Auto-detectando directorios cPanel para usuario: $user"
    
    # Auto-detectar directorio web
    if [[ -z "${WWW_DIR:-}" ]]; then
        local possible_www_dirs=(
            "/home/${user}/public_html"
            "/home/${user}/public_html/moodle"
            "/home/${user}/public_html/academia"
            "/home/${user}/public_html/lms"
            "/home/${user}/www"
        )
        
        for dir in "${possible_www_dirs[@]}"; do
            if [[ -f "$dir/config.php" ]] && grep -q "CFG->wwwroot\|moodle\|Moodle" "$dir/config.php" 2>/dev/null; then
                WWW_DIR="$dir"
                basic_log_info "Auto-detectado directorio web cPanel: $WWW_DIR"
                break
            fi
        done
    fi
    
    # Auto-detectar moodledata
    if [[ -z "${MOODLEDATA_DIR:-}" ]]; then
        # Intentar extraer desde config.php primero
        if [[ -f "${WWW_DIR}/config.php" ]]; then
            auto_detect_moodledata_from_config
        fi
        
        # Si no se encontró, intentar ubicaciones típicas de cPanel
        if [[ -z "${MOODLEDATA_DIR:-}" ]]; then
            local possible_data_dirs=(
                "/home/${user}/moodledata"
                "/home/${user}/moodle_data"
                "/home/${user}/data"
                "/home/${user}/private_html/moodledata"
            )
            
            for dir in "${possible_data_dirs[@]}"; do
                if [[ -d "$dir" ]] && [[ -f "$dir/.htaccess" || -d "$dir/filedir" ]]; then
                    MOODLEDATA_DIR="$dir"
                    basic_log_info "Auto-detectado moodledata cPanel: $MOODLEDATA_DIR"
                    break
                fi
            done
        fi
    fi
}

# Función específica para Plesk
auto_detect_directories_plesk() {
    local domain="${DOMAIN_NAME:-}"
    local user="${CPANEL_USER:-$USER}"
    
    basic_log_info "Auto-detectando directorios Plesk"
    
    # Auto-detectar directorio web
    if [[ -z "${WWW_DIR:-}" ]]; then
        local possible_www_dirs=()
        
        # Si tenemos dominio, usar estructura típica de Plesk
        if [[ -n "$domain" ]]; then
            possible_www_dirs+=(
                "/var/www/vhosts/${domain}/httpdocs"
                "/var/www/vhosts/${domain}/httpdocs/moodle"
                "/var/www/vhosts/${domain}/subdomains/moodle/httpdocs"
            )
        fi
        
        # Patrones adicionales
        if [[ -n "$user" ]]; then
            possible_www_dirs+=(
                "/var/www/vhosts/*/httpdocs"
                "/opt/psa/var/www/vhosts/*/httpdocs"
            )
        fi
        
        # Búsqueda manual si no encontramos con patrones
        for pattern in "${possible_www_dirs[@]}"; do
            for dir in $pattern; do
                if [[ -f "$dir/config.php" ]] && grep -q "CFG->wwwroot\|moodle\|Moodle" "$dir/config.php" 2>/dev/null; then
                    WWW_DIR="$dir"
                    basic_log_info "Auto-detectado directorio web Plesk: $WWW_DIR"
                    break 2
                fi
            done
        done
    fi
    
    # Auto-detectar moodledata
    if [[ -z "${MOODLEDATA_DIR:-}" ]]; then
        # Intentar extraer desde config.php primero
        if [[ -f "${WWW_DIR}/config.php" ]]; then
            auto_detect_moodledata_from_config
        fi
        
        # Si no se encontró, intentar ubicaciones típicas de Plesk
        if [[ -z "${MOODLEDATA_DIR:-}" ]] && [[ -n "$domain" ]]; then
            local possible_data_dirs=(
                "/var/www/vhosts/${domain}/moodledata"
                "/var/www/vhosts/${domain}/private/moodledata"
                "/var/www/vhosts/${domain}/httpdocs/moodledata"
            )
            
            for dir in "${possible_data_dirs[@]}"; do
                if [[ -d "$dir" ]] && [[ -f "$dir/.htaccess" || -d "$dir/filedir" ]]; then
                    MOODLEDATA_DIR="$dir"
                    basic_log_info "Auto-detectado moodledata Plesk: $MOODLEDATA_DIR"
                    break
                fi
            done
        fi
    fi
}

# Función específica para DirectAdmin
auto_detect_directories_directadmin() {
    local user="${CPANEL_USER:-$USER}"
    local domain="${DOMAIN_NAME:-}"
    
    if [[ -z "$user" ]] || [[ "$user" == "root" ]]; then
        basic_log_warn "No se pudo determinar usuario DirectAdmin válido"
        return 1
    fi
    
    basic_log_info "Auto-detectando directorios DirectAdmin para usuario: $user"
    
    # Auto-detectar directorio web
    if [[ -z "${WWW_DIR:-}" ]]; then
        local possible_www_dirs=()
        
        # Si tenemos dominio
        if [[ -n "$domain" ]]; then
            possible_www_dirs+=(
                "/home/${user}/domains/${domain}/public_html"
                "/home/${user}/domains/${domain}/public_html/moodle"
            )
        fi
        
        # Patrones generales
        possible_www_dirs+=(
            "/home/${user}/domains/*/public_html"
            "/home/${user}/public_html"
        )
        
        for pattern in "${possible_www_dirs[@]}"; do
            for dir in $pattern; do
                if [[ -f "$dir/config.php" ]] && grep -q "CFG->wwwroot\|moodle\|Moodle" "$dir/config.php" 2>/dev/null; then
                    WWW_DIR="$dir"
                    basic_log_info "Auto-detectado directorio web DirectAdmin: $WWW_DIR"
                    break 2
                fi
            done
        done
    fi
    
    # Auto-detectar moodledata
    if [[ -z "${MOODLEDATA_DIR:-}" ]]; then
        # Intentar extraer desde config.php primero
        if [[ -f "${WWW_DIR}/config.php" ]]; then
            auto_detect_moodledata_from_config
        fi
        
        # Si no se encontró, intentar ubicaciones típicas de DirectAdmin
        if [[ -z "${MOODLEDATA_DIR:-}" ]]; then
            local possible_data_dirs=(
                "/home/${user}/moodledata"
                "/home/${user}/private_html/moodledata"
                "/home/${user}/domains/*/moodledata"
            )
            
            for pattern in "${possible_data_dirs[@]}"; do
                for dir in $pattern; do
                    if [[ -d "$dir" ]] && [[ -f "$dir/.htaccess" || -d "$dir/filedir" ]]; then
                        MOODLEDATA_DIR="$dir"
                        basic_log_info "Auto-detectado moodledata DirectAdmin: $MOODLEDATA_DIR"
                        break 2
                    fi
                done
            done
        fi
    fi
}

# Función específica para VestaCP/HestiaCP
auto_detect_directories_vestacp() {
    local user="${CPANEL_USER:-$USER}"
    local domain="${DOMAIN_NAME:-}"
    
    if [[ -z "$user" ]] || [[ "$user" == "root" ]]; then
        basic_log_warn "No se pudo determinar usuario VestaCP válido"
        return 1
    fi
    
    basic_log_info "Auto-detectando directorios VestaCP/HestiaCP para usuario: $user"
    
    # Auto-detectar directorio web
    if [[ -z "${WWW_DIR:-}" ]]; then
        local possible_www_dirs=()
        
        # Si tenemos dominio
        if [[ -n "$domain" ]]; then
            possible_www_dirs+=(
                "/home/${user}/web/${domain}/public_html"
                "/home/${user}/web/${domain}/public_html/moodle"
            )
        fi
        
        # Patrones generales VestaCP
        possible_www_dirs+=(
            "/home/${user}/web/*/public_html"
            "/home/${user}/public_html"
        )
        
        for pattern in "${possible_www_dirs[@]}"; do
            for dir in $pattern; do
                if [[ -f "$dir/config.php" ]] && grep -q "CFG->wwwroot\|moodle\|Moodle" "$dir/config.php" 2>/dev/null; then
                    WWW_DIR="$dir"
                    basic_log_info "Auto-detectado directorio web VestaCP: $WWW_DIR"
                    break 2
                fi
            done
        done
    fi
    
    # Auto-detectar moodledata
    if [[ -z "${MOODLEDATA_DIR:-}" ]]; then
        # Intentar extraer desde config.php primero
        if [[ -f "${WWW_DIR}/config.php" ]]; then
            auto_detect_moodledata_from_config
        fi
        
        # Si no se encontró, intentar ubicaciones típicas de VestaCP
        if [[ -z "${MOODLEDATA_DIR:-}" ]]; then
            local possible_data_dirs=(
                "/home/${user}/moodledata"
                "/home/${user}/web/*/moodledata"
                "/home/${user}/private/moodledata"
            )
            
            for pattern in "${possible_data_dirs[@]}"; do
                for dir in $pattern; do
                    if [[ -d "$dir" ]] && [[ -f "$dir/.htaccess" || -d "$dir/filedir" ]]; then
                        MOODLEDATA_DIR="$dir"
                        basic_log_info "Auto-detectado moodledata VestaCP: $MOODLEDATA_DIR"
                        break 2
                    fi
                done
            done
        fi
    fi
}

# Función específica para ISPConfig
auto_detect_directories_ispconfig() {
    local user="${CPANEL_USER:-$USER}"
    local domain="${DOMAIN_NAME:-}"
    
    basic_log_info "Auto-detectando directorios ISPConfig"
    
    # Auto-detectar directorio web
    if [[ -z "${WWW_DIR:-}" ]]; then
        local possible_www_dirs=()
        
        # Si tenemos dominio
        if [[ -n "$domain" ]]; then
            possible_www_dirs+=(
                "/var/www/${domain}/web"
                "/var/www/clients/*/web*/web"
            )
        fi
        
        # Patrones generales ISPConfig
        possible_www_dirs+=(
            "/var/www/*/web"
            "/srv/www/*/web"
        )
        
        for pattern in "${possible_www_dirs[@]}"; do
            for dir in $pattern; do
                if [[ -f "$dir/config.php" ]] && grep -q "CFG->wwwroot\|moodle\|Moodle" "$dir/config.php" 2>/dev/null; then
                    WWW_DIR="$dir"
                    basic_log_info "Auto-detectado directorio web ISPConfig: $WWW_DIR"
                    break 2
                fi
            done
        done
    fi
    
    # Auto-detectar moodledata
    if [[ -z "${MOODLEDATA_DIR:-}" ]]; then
        # Intentar extraer desde config.php primero
        if [[ -f "${WWW_DIR}/config.php" ]]; then
            auto_detect_moodledata_from_config
        fi
        
        # Si no se encontró, intentar ubicaciones típicas de ISPConfig
        if [[ -z "${MOODLEDATA_DIR:-}" ]]; then
            local www_parent=$(dirname "${WWW_DIR}")
            local possible_data_dirs=(
                "${www_parent}/moodledata"
                "${www_parent}/private/moodledata"
                "/var/moodledata"
            )
            
            for dir in "${possible_data_dirs[@]}"; do
                if [[ -d "$dir" ]] && [[ -f "$dir/.htaccess" || -d "$dir/filedir" ]]; then
                    MOODLEDATA_DIR="$dir"
                    basic_log_info "Auto-detectado moodledata ISPConfig: $MOODLEDATA_DIR"
                    break
                fi
            done
        fi
    fi
}

# Función para instalaciones manuales (búsqueda agresiva)
auto_detect_directories_manual() {
    basic_log_info "Auto-detectando directorios para instalación manual"
    
    # Auto-detectar directorio web con búsqueda agresiva
    if [[ -z "${WWW_DIR:-}" ]]; then
        if [[ "$AUTO_DETECT_AGGRESSIVE" == "true" ]]; then
            basic_log_info "Realizando búsqueda agresiva de Moodle..."
            
            local common_web_paths=(
                "/var/www/html"
                "/var/www"
                "/opt/moodle"
                "/usr/share/moodle"
                "/srv/www"
                "/home/*/public_html"
                "/var/www/html/moodle"
                "/var/www/moodle"
                "/opt/lampp/htdocs"
                "/Applications/XAMPP/htdocs"
            )
            
            for pattern in "${common_web_paths[@]}"; do
                for dir in $pattern; do
                    if [[ -f "$dir/config.php" ]] && grep -q "CFG->wwwroot\|moodle\|Moodle" "$dir/config.php" 2>/dev/null; then
                        WWW_DIR="$dir"
                        basic_log_info "Auto-detectado directorio web manual: $WWW_DIR"
                        break 2
                    fi
                done
            done
            
            # Si aún no encontramos, búsqueda más agresiva
            if [[ -z "${WWW_DIR:-}" ]]; then
                basic_log_info "Búsqueda agresiva: escaneando sistema..."
                local found_config
                found_config=$(find /var /opt /usr/share /home -name "config.php" -type f 2>/dev/null | head -20)
                
                for config_file in $found_config; do
                    if grep -q "CFG->wwwroot\|moodle\|Moodle" "$config_file" 2>/dev/null; then
                        WWW_DIR=$(dirname "$config_file")
                        basic_log_info "Auto-detectado directorio web (búsqueda agresiva): $WWW_DIR"
                        break
                    fi
                done
            fi
        else
            basic_log_warn "AUTO_DETECT_AGGRESSIVE=false, omitiendo búsqueda agresiva"
        fi
    fi
    
    # Auto-detectar moodledata
    if [[ -z "${MOODLEDATA_DIR:-}" ]]; then
        # Intentar extraer desde config.php primero
        if [[ -f "${WWW_DIR}/config.php" ]]; then
            auto_detect_moodledata_from_config
        fi
        
        # Si no se encontró y está habilitada la búsqueda agresiva
        if [[ -z "${MOODLEDATA_DIR:-}" ]] && [[ "$AUTO_DETECT_AGGRESSIVE" == "true" ]]; then
            basic_log_info "Búsqueda agresiva de moodledata..."
            
            local common_data_paths=(
                "/var/moodledata"
                "/opt/moodledata"
                "/usr/share/moodledata"
                "/srv/moodledata"
                "$(dirname "${WWW_DIR}")/moodledata"
                "/tmp/moodledata"
            )
            
            for dir in "${common_data_paths[@]}"; do
                if [[ -d "$dir" ]] && [[ -f "$dir/.htaccess" || -d "$dir/filedir" ]]; then
                    MOODLEDATA_DIR="$dir"
                    basic_log_info "Auto-detectado moodledata manual: $MOODLEDATA_DIR"
                    break
                fi
            done
        fi
    fi
}

# Función auxiliar para extraer moodledata desde config.php
auto_detect_moodledata_from_config() {
    if [[ ! -f "${WWW_DIR}/config.php" ]]; then
        return 1
    fi
    
    local moodledata_path
    if moodledata_path=$(grep -E "^\s*\\\$CFG->dataroot\s*=" "${WWW_DIR}/config.php" | sed "s/.*=\s*['\"]//;s/['\"];.*//"); then
        # Expandir variables si existen
        moodledata_path=$(eval echo "$moodledata_path" 2>/dev/null || echo "$moodledata_path")
        
        if [[ -d "$moodledata_path" ]]; then
            MOODLEDATA_DIR="$moodledata_path"
            basic_log_info "Auto-detectado moodledata desde config.php: $MOODLEDATA_DIR"
            return 0
        fi
    fi
    
    return 1
}

# Función para auto-detectar configuración de base de datos
auto_detect_database_config() {
    if [[ ! -f "${WWW_DIR}/config.php" ]]; then
        basic_log_warn "No se encontró config.php en: ${WWW_DIR}"
        return 1
    fi
    
    basic_log_info "Auto-detectando configuración de base de datos desde config.php"
    
    # Solo auto-detectar si no están definidas
    if [[ -z "${DB_NAME:-}" ]]; then
        if DB_NAME=$(grep -E "^\s*\\\$CFG->dbname\s*=" "${WWW_DIR}/config.php" | sed "s/.*=\s*['\"]//;s/['\"];.*//"); then
            basic_log_info "Auto-detectado nombre BD: $DB_NAME"
        fi
    fi
    
    if [[ -z "${DB_USER:-}" ]]; then
        if DB_USER=$(grep -E "^\s*\\\$CFG->dbuser\s*=" "${WWW_DIR}/config.php" | sed "s/.*=\s*['\"]//;s/['\"];.*//"); then
            basic_log_info "Auto-detectado usuario BD: $DB_USER"
        fi
    fi
    
    # Opcional: detectar host y puerto si no están definidos
    if [[ -z "${DB_HOST:-}" ]]; then
        if DB_HOST=$(grep -E "^\s*\\\$CFG->dbhost\s*=" "${WWW_DIR}/config.php" | sed "s/.*=\s*['\"]//;s/['\"];.*//"); then
            basic_log_info "Auto-detectado host BD: $DB_HOST"
        fi
    fi
    
    return 0
}

# Función para procesar configuración de emails
process_email_configuration() {
    # Inicializar array vacío para emails de notificación
    NOTIFICATION_EMAILS=()
    
    # Agregar emails desde configuración
    if [[ -n "${NOTIFICATION_EMAILS_EXTRA:-}" ]]; then
        basic_log_info "Agregando emails desde configuración"
        
        # Convertir string separado por comas a array
        IFS=',' read -ra extra_emails <<< "$NOTIFICATION_EMAILS_EXTRA"
        
        for email in "${extra_emails[@]}"; do
            # Limpiar espacios y validar formato básico
            email=$(echo "$email" | xargs)
            if [[ "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
                NOTIFICATION_EMAILS+=("$email")
                basic_log_info "Email agregado: $email"
            else
                basic_log_warn "Email inválido ignorado: $email"
            fi
        done
    fi
    
    # Validar que hay al menos un email configurado
    if [[ ${#NOTIFICATION_EMAILS[@]} -eq 0 ]]; then
        basic_log_error "ERROR: No hay emails de notificación configurados."
        basic_log_error "Debe configurar al menos un email en NOTIFICATION_EMAILS_EXTRA"
        basic_log_error "Ejemplo: NOTIFICATION_EMAILS_EXTRA=\"tu-email@ejemplo.com\""
        return 1
    fi
    
    basic_log_info "Configuración de emails: ${#NOTIFICATION_EMAILS[@]} destinatarios"
}

# Función para validar configuración cargada
validate_configuration() {
    local show_only="${1:-false}"
    basic_log_info "Validando configuración cargada..."
    
    local validation_errors=()
    
    # Validar directorios críticos
    [[ -z "${WWW_DIR:-}" ]] && validation_errors+=("WWW_DIR no definido")
    [[ -z "${MOODLEDATA_DIR:-}" ]] && validation_errors+=("MOODLEDATA_DIR no definido")
    [[ -z "${TMP_DIR:-}" ]] && validation_errors+=("TMP_DIR no definido")
    
    # Validar configuración de BD
    [[ -z "${DB_NAME:-}" ]] && validation_errors+=("DB_NAME no definido")
    [[ -z "${DB_USER:-}" ]] && validation_errors+=("DB_USER no definido")
    
    # Validar configuración de Google Drive
    [[ -z "${GDRIVE_REMOTE:-}" ]] && validation_errors+=("GDRIVE_REMOTE no definido")
    
    # Validar que hay emails de notificación configurados
    if [[ ${#NOTIFICATION_EMAILS[@]} -eq 0 ]]; then
        validation_errors+=("No hay emails de notificación configurados. Configure NOTIFICATION_EMAILS_EXTRA")
    fi
    
    if [[ ${#validation_errors[@]} -gt 0 ]]; then
        basic_log_warn "Advertencias de configuración:"
        for error in "${validation_errors[@]}"; do
            basic_log_warn "  - $error"
        done
        
        # Si solo se muestra configuración, no fallar por variables faltantes
        if [[ "$show_only" == "true" ]]; then
            basic_log_info "Modo solo visualización: continuando con configuración parcial"
        else
            basic_log_error "Configuración incompleta para ejecución"
            return 1
        fi
    fi
    
    # Validar que directorios existan (solo si están definidos)
    local dir_errors=()
    [[ -n "${WWW_DIR:-}" ]] && [[ ! -d "$WWW_DIR" ]] && dir_errors+=("Directorio web no existe: $WWW_DIR")
    [[ -n "${MOODLEDATA_DIR:-}" ]] && [[ ! -d "$MOODLEDATA_DIR" ]] && dir_errors+=("Directorio moodledata no existe: $MOODLEDATA_DIR")
    
    if [[ ${#dir_errors[@]} -gt 0 ]]; then
        basic_log_warn "Advertencias de directorios:"
        for error in "${dir_errors[@]}"; do
            basic_log_warn "  - $error"
        done
        
        # Si solo se muestra configuración, no fallar por directorios faltantes
        if [[ "$show_only" != "true" ]]; then
            basic_log_error "Directorios no válidos para ejecución"
            return 1
        fi
    fi
    
    if [[ ${#validation_errors[@]} -eq 0 ]] && [[ ${#dir_errors[@]} -eq 0 ]]; then
        basic_log_info "✅ Configuración validada correctamente"
    elif [[ "$show_only" == "true" ]]; then
        basic_log_info "⚠️ Configuración parcial mostrada (algunas variables por defecto)"
    fi
    
    return 0
}

# ===================== CONFIGURACIÓN POR DEFECTO (FALLBACK) =====================
set_default_configuration() {
    # Valores por defecto si no se cargan desde configuración externa
    CLIENT_NAME="${CLIENT_NAME:-default}"
    CLIENT_DESCRIPTION="${CLIENT_DESCRIPTION:-Moodle Backup}"
    CPANEL_USER="${CPANEL_USER:-}"
    WWW_DIR="${WWW_DIR:-}"
    MOODLEDATA_DIR="${MOODLEDATA_DIR:-}"
    DB_NAME="${DB_NAME:-}"
    DB_USER="${DB_USER:-}"
    DB_PASS="${DB_PASS:-${MYSQL_PASSWORD:-$(cat /etc/mysql/backup.pwd 2>/dev/null || echo '')}}"
    TMP_DIR="${TMP_DIR:-/tmp/moodle_backup}"
    GDRIVE_REMOTE="${GDRIVE_REMOTE:-gdrive:moodle_backups}"
    LOG_FILE="${LOG_FILE:-/var/log/moodle_backup.log}"
    MAX_BACKUPS_GDRIVE="${MAX_BACKUPS_GDRIVE:-2}"
    FORCE_THREADS="${FORCE_THREADS:-0}"
    FORCE_COMPRESSION_LEVEL="${FORCE_COMPRESSION_LEVEL:-1}"
    OPTIMIZED_HOURS="${OPTIMIZED_HOURS:-02-08}"
    CUSTOM_UPLOAD_TIMEOUT="${CUSTOM_UPLOAD_TIMEOUT:-0}"
    MAINTENANCE_TITLE="${MAINTENANCE_TITLE:-Mantenimiento - Moodle}"
    EXTENDED_DIAGNOSTICS="${EXTENDED_DIAGNOSTICS:-false}"
    NOTIFICATION_EMAILS_EXTRA="${NOTIFICATION_EMAILS_EXTRA:-}"
    
    # NUEVAS VARIABLES PARA GESTIÓN UNIVERSAL
    PANEL_TYPE="${PANEL_TYPE:-auto}"  # auto, cpanel, plesk, directadmin, vestacp, manual, none
    REQUIRE_CONFIG="${REQUIRE_CONFIG:-true}"  # true para requerir configuración obligatoria (más seguro por defecto)
    DOMAIN_NAME="${DOMAIN_NAME:-}"  # Necesario para algunos paneles (Plesk, etc.)
    AUTO_DETECT_AGGRESSIVE="${AUTO_DETECT_AGGRESSIVE:-true}"  # Búsqueda agresiva en todo el sistema
    DB_HOST="${DB_HOST:-localhost}"  # Host de base de datos por defecto
}

# ===================== PROCESAMIENTO TEMPRANO DE ARGUMENTOS =====================
# Procesar argumentos que no requieren configuración primero
case "${1:-}" in
    --help|-h)
        # La función show_help está definida más adelante, pero podemos mostrar ayuda básica
        cat << 'EOF'
=== MOODLE BACKUP V3 - SCRIPT UNIVERSAL MULTI-PANEL ===

DESCRIPCIÓN:
    Script robusto de backup para Moodle compatible con múltiples paneles de control.
    Soporta auto-detección de configuración y manejo de múltiples clientes.

PANELES SOPORTADOS:
    - cPanel
    - Plesk  
    - DirectAdmin
    - VestaCP/HestiaCP
    - ISPConfig
    - Instalaciones manuales

USO:
    ./moodle_backup.sh [OPCIONES]

OPCIONES PRINCIPALES:
    --help, -h              Mostrar esta ayuda
    --show-config           Mostrar configuración cargada (sin ejecutar backup)
    --test-rclone          Probar conectividad con Google Drive
    --diagnose             Ejecutar diagnóstico completo del sistema

CONFIGURACIÓN:
    El script busca archivos de configuración en este orden:
    1. ./moodle_backup.conf (local)
    2. /etc/moodle_backup.conf (global)
    3. [directorio_script]/moodle_backup.conf (junto al script)

    Ver 'moodle_backup.conf.example' para ejemplos de configuración.

VARIABLES CLAVE:
    PANEL_TYPE          Tipo de panel (auto, cpanel, plesk, directadmin, vestacp, manual)
    REQUIRE_CONFIG      true/false - Requiere configuración obligatoria
    CLIENT_NAME         Identificador único del cliente
    WWW_DIR            Directorio web de Moodle
    MOODLEDATA_DIR     Directorio de datos de Moodle

EJEMPLOS:
    # Ver configuración actual
    ./moodle_backup.sh --show-config
    
    # Ejecutar backup con auto-detección
    REQUIRE_CONFIG=false ./moodle_backup.sh
    
    # Forzar tipo de panel específico
    PANEL_TYPE=plesk ./moodle_backup.sh --show-config

Para más información detallada, ejecutar con configuración cargada.
EOF
        exit 0
        ;;
esac

# ===================== VARIABLES PRINCIPALES (CONFIGURABLES) =====================

# Cargar configuración en el orden correcto
set_default_configuration
load_configuration
auto_detect_moodle_config
process_email_configuration

# Nota: La validación estricta se realiza solo durante la ejecución normal,
# no durante la visualización de configuración
SERVER_NAME="$(hostname)"
BACKUP_SESSION_ID="backup_$(date +%s)"

# ===================== CONFIGURACIÓN DE RETENCIÓN =====================
MAX_BACKUPS_GDRIVE=2

# ===================== CONFIGURACIÓN DE RENDIMIENTO (DINÁMICA Y CONFIGURABLE) =====================
CORES=$(nproc)

# Usar configuración forzada de threads si está definida
if [[ "${FORCE_THREADS:-0}" -gt 0 ]]; then
    ZSTD_THREADS="$FORCE_THREADS"
    PERFORMANCE_MODE="manual"
    log_info "Usando configuración manual de threads: $ZSTD_THREADS"
else
    # Detectar horario para optimización automática usando configuración
    CURRENT_HOUR=$(date +%H)
    # Forzar interpretación decimal removiendo ceros a la izquierda
    CURRENT_HOUR=$((10#$CURRENT_HOUR))
    IFS='-' read -r start_hour end_hour <<< "$OPTIMIZED_HOURS"
    start_hour=$((10#$start_hour))
    end_hour=$((10#$end_hour))
    
    if [[ $CURRENT_HOUR -ge $start_hour && $CURRENT_HOUR -lt $end_hour ]]; then
        # Horario optimizado: más recursos disponibles
        ZSTD_THREADS=$(( CORES * 85 / 100 ))
        [[ $ZSTD_THREADS -gt 12 ]] && ZSTD_THREADS=12
        PERFORMANCE_MODE="optimizado"
    else
        # Horario normal: configuración conservadora
        ZSTD_THREADS=$(( CORES * 75 / 100 ))
        [[ $ZSTD_THREADS -gt 8 ]] && ZSTD_THREADS=8
        PERFORMANCE_MODE="conservador"
    fi
    [[ $ZSTD_THREADS -lt 2 ]] && ZSTD_THREADS=2
fi

# Usar nivel de compresión configurado
ZSTD_LEVEL="${FORCE_COMPRESSION_LEVEL:-1}"

# Configuración conservadora de buffers
TAR_BUFFER_SIZE="16M"
MYSQL_BUFFER_SIZE="512M"

# ===================== VARIABLES DINÁMICAS - ARCHIVOS INDEPENDIENTES =====================
FECHA=$(date +%F_%H-%M)
BACKUP_DATE=$(date +%F)

# Archivos independientes para subida secuencial (usando configuración)
DB_DUMP="${TMP_DIR}/database_${CLIENT_NAME}_${FECHA}.sql.gz"
CORE_ARCHIVE="${TMP_DIR}/moodle_core_${CLIENT_NAME}_${FECHA}.tar.zst"
DATA_ARCHIVE="${TMP_DIR}/moodledata_${CLIENT_NAME}_${FECHA}.tar.zst"

# Carpeta de backup en Google Drive (usando configuración de cliente)
GDRIVE_BACKUP_FOLDER="${GDRIVE_REMOTE}/moodle_backup_${CLIENT_NAME}_${BACKUP_DATE}"

# Archivos para compatibilidad (por si se requiere archivo único)
NOMBRE_ARCHIVO="moodle_backup_${CLIENT_NAME}_${FECHA}.tar.zst"
DESTINO="${TMP_DIR}/${NOMBRE_ARCHIVO}"

# ===================== VARIABLES DE SESIÓN (USANDO CONFIGURACIÓN) =====================
SESSION_START_TIME=""
SESSION_LOG="/tmp/moodle_backup_session_${CLIENT_NAME}_${BACKUP_SESSION_ID}.log"
SNAPSHOT_DIR=""
ERROR_NOTIFIED=false
LOG_LOCK="/tmp/moodle_backup_${CLIENT_NAME}_log.lock"

# ===================== ROTACIÓN DE LOGS =====================
rotate_logs() {
    local current_month=$(date +%Y-%m)
    local log_dir="/var/log"
    local base_name="moodle_backup"
    
    # Comprimir logs del mes anterior si existen
    local last_month=$(date -d "last month" +%Y-%m)
    if [[ -f "${log_dir}/${base_name}_${last_month}.log" ]]; then
        gzip "${log_dir}/${base_name}_${last_month}.log" 2>/dev/null || true
    fi
    
    # Eliminar logs comprimidos >6 meses
    find "$log_dir" -name "${base_name}_*.log.gz" -mtime +180 -delete 2>/dev/null || true
    
    # Rotar log actual si es necesario
    if [[ -f "$LOG_FILE" ]]; then
        local log_size=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
        if [[ $log_size -gt 104857600 ]]; then  # >100MB
            mv "$LOG_FILE" "${log_dir}/${base_name}_${current_month}.log"
            touch "$LOG_FILE"
        fi
    fi
}

# ===================== SISTEMA DE LOGGING AVANZADO (DE V2) =====================
log() {
    local level="$1"
    shift
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="[$timestamp] [$level] $*"
    
    # Usar lock para evitar duplicados (método V2 mejorado)
    {
        if command -v flock >/dev/null 2>&1; then
            flock -x 200
        fi
        echo "$message" >> "${LOG_FILE}"
        [[ -n "${SESSION_LOG:-}" ]] && echo "$message" >> "${SESSION_LOG}"
    } 200>"$LOG_LOCK" 2>/dev/null
    
    # Log al sistema (syslog) como V2
    if command -v logger >/dev/null 2>&1; then
        logger -t "moodle-backup" -p local0.info "$level: $*" 2>/dev/null || true
    fi
    
    # Solo a stdout si no es cron
    if [[ "${TERM:-}" != "" ]] && [[ "${BASH_SUBSHELL}" -eq 0 ]]; then
        echo "$message"
    fi
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }

# ===================== VERIFICACIÓN DE CUOTA GOOGLE DRIVE (DE V2) =====================
check_drive_quota() {
    log_info "Verificando cuota disponible en Google Drive"
    
    # Función auxiliar para convertir bytes a GB
    convert_to_gb() {
        local size="$1"
        local unit="${2:-}"
        
        case "$unit" in
            "TiB"|"TB"|"T")
                echo $(( $(echo "$size" | cut -d. -f1) * 1024 ))
                ;;
            "GiB"|"GB"|"G")
                echo $(echo "$size" | cut -d. -f1)
                ;;
            "MiB"|"MB"|"M")
                echo 1  # Menos de 1GB
                ;;
            "KiB"|"KB"|"K")
                echo 1  # Menos de 1GB
                ;;
            *)
                # Asumir bytes si no hay unidad
                echo $(( size / 1024 / 1024 / 1024 ))
                ;;
        esac
    }
    
    local free_gb=0
    
    # Intentar usar JSON primero (más robusto)
    if command -v jq >/dev/null 2>&1; then
        local quota_json
        if quota_json=$(timeout 30 rclone about "$GDRIVE_REMOTE" --json 2>/dev/null); then
            log_info "Usando análisis JSON para cuota (método robusto)"
            
            local free_bytes
            if free_bytes=$(echo "$quota_json" | jq -r '.free // empty' 2>/dev/null) && [[ -n "$free_bytes" ]]; then
                free_gb=$(( free_bytes / 1024 / 1024 / 1024 ))
            else
                log_warn "No se pudo extraer espacio libre de JSON, usando fallback"
                free_gb=1000  # Valor conservador para continuar
            fi
        else
            log_warn "Falló obtener cuota con JSON, usando método texto"
            free_gb=1000
        fi
    else
        # Fallback a parsing de texto
        log_info "Usando análisis de texto para cuota (fallback)"
        
        local quota_output
        if quota_output=$(timeout 30 rclone about "$GDRIVE_REMOTE" 2>/dev/null); then
            local free_space_line=$(echo "$quota_output" | grep -E "Free:|Available:" | head -1)
            
            if [[ -n "$free_space_line" ]]; then
                local free_value=$(echo "$free_space_line" | grep -oE '[0-9]+\.?[0-9]*' | head -1)
                local free_unit=$(echo "$free_space_line" | grep -oE '[KMGT]i?B?' | head -1)
                
                if [[ -n "$free_value" ]]; then
                    free_gb=$(convert_to_gb "$free_value" "$free_unit")
                else
                    free_gb=1000
                fi
            else
                free_gb=1000
            fi
        else
            log_error "No se pudo obtener información de cuota de Google Drive"
            return 1
        fi
    fi
    
    # Obtener tamaño del archivo a subir
    local file_size_gb=0
    if [[ -f "$DESTINO" ]]; then
        file_size_gb=$(du -h "$DESTINO" | awk '{print $1}' | sed 's/G.*//' | cut -d. -f1)
        [[ -z "$file_size_gb" ]] && file_size_gb=0
    fi
    
    log_info "Espacio libre estimado en Drive: ${free_gb}GB"
    log_info "Tamaño archivo a subir: ${file_size_gb}GB"
    
    # Verificar si hay suficiente espacio (con margen conservador)
    if [[ $free_gb -lt $((file_size_gb + 50)) ]] && [[ $free_gb -lt 100 ]]; then
        log_error "Espacio posiblemente insuficiente en Google Drive"
        log_error "Disponible: ~${free_gb}GB, Necesario: ~${file_size_gb}GB + margen"
        log_warn "Continuando con precaución..."
    fi
    
    # Verificar límite diario estimado por horario
    local current_hour=$(date +%H)
    current_hour=$((10#$current_hour))  # Forzar interpretación decimal
    if [[ $current_hour -gt 20 ]] && [[ $file_size_gb -gt 400 ]]; then
        log_warn "ADVERTENCIA: Subida de archivo grande después de las 20h"
        log_warn "Mayor probabilidad de fallar por límites diarios de Google Drive"
    fi
    
    log_info "Verificación de cuota completada - Procediendo con la subida"
    return 0
}

# ===================== OPTIMIZACIÓN DE PRIORIDADES MODERADA =====================
optimize_system_priority() {
    log_info "Configurando prioridades del sistema (modo conservador)"
    
    # Verificar si somos root o tenemos permisos
    local can_renice=false
    local can_ionice=false
    
    if [[ $EUID -eq 0 ]] || sudo -n true 2>/dev/null; then
        can_renice=true
        can_ionice=true
    fi
    
    # Configurar prioridad del proceso
    if [[ "$can_renice" == true ]]; then
        # Prioridad moderada para no interferir con otros servicios del servidor
        if [[ $EUID -eq 0 ]]; then
            renice -n -5 $$ 2>/dev/null || true
            log_info "✅ Prioridad CPU configurada (nice -5)"
        else
            sudo renice -n -5 $$ 2>/dev/null || true
            log_info "✅ Prioridad CPU configurada con sudo (nice -5)"
        fi
    else
        # Intentar sin privilegios elevados
        renice -n 5 $$ 2>/dev/null || true
        log_info "⚠️ Prioridad CPU normal (sin privilegios para nice negativo)"
    fi
    
    # Configurar prioridad de E/O si está disponible
    if command -v ionice >/dev/null 2>&1 && [[ "$can_ionice" == true ]]; then
        if [[ $EUID -eq 0 ]]; then
            ionice -c 2 -n 2 -p $$ 2>/dev/null || true
            log_info "✅ Prioridad I/O configurada (clase 2, nivel 2)"
        else
            sudo ionice -c 2 -n 4 -p $$ 2>/dev/null || true
            log_info "✅ Prioridad I/O configurada con sudo (clase 2, nivel 4)"
        fi
    else
        log_info "⚠️ ionice no disponible o sin permisos - continuando sin optimización I/O"
    fi
    
    # Configurar límites de recursos
    if command -v ulimit >/dev/null 2>&1; then
        # Aumentar límites conservadoramente para evitar interferir con cPanel
        ulimit -n 8192 2>/dev/null || true  # file descriptors
        ulimit -u 4096 2>/dev/null || true  # procesos de usuario
        log_info "✅ Límites de recursos configurados"
    fi
    
    log_info "Configuración de rendimiento: ${ZSTD_THREADS} threads (75% de ${CORES} cores, máx 8)"
    log_info "Entorno: WHM/cPanel - configuración conservadora aplicada"
}

# ===================== VERIFICACIÓN DE DEPENDENCIAS HÍBRIDA =====================
check_hybrid_dependencies() {
    log_info "Verificando dependencias del sistema (híbrido V1+V2)"
    
    # Verificar comandos esenciales
    local missing_deps=()
    local optional_deps=()
    
    for cmd in mysqldump tar zstd rclone; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    # Verificar herramientas opcionales para mejor rendimiento
    for cmd in pigz pv; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            optional_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Dependencias faltantes: ${missing_deps[*]}"
        log_error "Instalar con: yum install -y ${missing_deps[*]}"
        return 1
    fi
    
    if [[ ${#optional_deps[@]} -gt 0 ]]; then
        log_warn "Dependencias opcionales recomendadas: ${optional_deps[*]}"
        log_warn "pigz: compresión paralela de BD (más rápido que gzip)"
        log_warn "pv: monitor de progreso con estadísticas"
    fi
    
    # Verificar directorios
    for dir in "$WWW_DIR" "$MOODLEDATA_DIR"; do
        if [[ ! -d "$dir" ]]; then
            log_error "Directorio no encontrado: $dir"
            return 1
        fi
    done
    
    # Crear directorio temporal si no existe
    if ! mkdir -p "$TMP_DIR"; then
        log_error "No se pudo crear directorio temporal: $TMP_DIR"
        return 1
    fi
    
    log_info "✅ Todas las dependencias verificadas correctamente"
    return 0
}

# ===================== VERIFICACIÓN RCLONE Y CREDENCIALES (DE V2) =====================
test_rclone_connection() {
    if ! command -v rclone >/dev/null 2>&1; then
        return 1
    fi
    
    # Verificar que el remote está configurado
    if ! rclone listremotes | grep -q "^gdrive:$"; then
        return 1
    fi
    
    # Probar conexión básica
    log_info "Probando conexión básica con Google Drive..."
    if timeout 60 rclone lsd "$GDRIVE_REMOTE" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# ===================== FUNCIÓN DE DIAGNÓSTICO COMPLETA (DE V2) =====================
diagnose_issues() {
    log_info "=== DIAGNÓSTICO DEL SISTEMA ==="
    
    # Verificar espacio en disco
    local available_space=$(df -h "$TMP_DIR" | awk 'NR==2 {print $4}')
    log_info "Espacio disponible en $TMP_DIR: $available_space"
    
    # Verificar rclone
    if ! test_rclone_connection; then
        return 1
    fi
    
    # Verificar archivos de backup existentes
    log_info "Verificando archivos locales antiguos..."
    find "$TMP_DIR" -name "moodle_backup_*.tar.zst" -mtime +1 -ls 2>/dev/null | head -5
    
    # Verificar configuración de rendimiento
    log_info "Configuración actual de threads: $ZSTD_THREADS de $CORES cores disponibles"
    
    log_info "=== FIN DIAGNÓSTICO ==="
    return 0
}

# ===================== MODO DE MANTENIMIENTO (DE V1) =====================
enable_maintenance_mode() {
    log_info "Activando modo mantenimiento para: $CLIENT_DESCRIPTION"
    
    # Crear archivo HTML personalizado usando configuración
    cat > "${WWW_DIR}/climaintenance.html" << EOF
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${MAINTENANCE_TITLE}</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            margin: 0;
            padding: 0;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            color: white;
        }
        .container {
            text-align: center;
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            border-radius: 20px;
            padding: 3rem;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
            max-width: 500px;
        }
        .logo {
            font-size: 3rem;
            margin-bottom: 1rem;
        }
        .title {
            font-size: 2rem;
            margin-bottom: 1rem;
            font-weight: 300;
        }
        .message {
            font-size: 1.1rem;
            line-height: 1.6;
            margin-bottom: 2rem;
            opacity: 0.9;
        }
        .spinner {
            border: 3px solid rgba(255, 255, 255, 0.3);
            border-radius: 50%;
            border-top: 3px solid white;
            width: 30px;
            height: 30px;
            animation: spin 1s linear infinite;
            margin: 0 auto;
        }
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        .client-info {
            margin-top: 2rem;
            font-size: 0.9rem;
            opacity: 0.7;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">🔧</div>
        <h1 class="title">Mantenimiento Programado</h1>
        <p class="message">
            Estamos realizando mejoras en nuestros sistemas para brindarte una mejor experiencia.
            <br><br>
            El sitio estará disponible nuevamente en unos minutos.
        </p>
        <div class="spinner"></div>
        <div class="client-info">
            ${CLIENT_DESCRIPTION}
        </div>
    </div>
</body>
</html>
EOF
    
    # Activar modo mantenimiento de Moodle
    [[ -f "${WWW_DIR}/admin/cli/maintenance.php" ]] && \
        php "${WWW_DIR}/admin/cli/maintenance.php" --enable 2>/dev/null || true
}

disable_maintenance_mode() {
    log_info "Desactivando modo mantenimiento"
    
    # Eliminar archivo HTML
    rm -f "${WWW_DIR}/climaintenance.html"
    
    # Desactivar modo mantenimiento de Moodle
    [[ -f "${WWW_DIR}/admin/cli/maintenance.php" ]] && \
        php "${WWW_DIR}/admin/cli/maintenance.php" --disable 2>/dev/null || true
}

# ===================== BACKUP DE BASE DE DATOS CONSERVADOR =====================
backup_database() {
    log_info "Iniciando backup de base de datos: $DB_NAME"
    
    # Verificar conexión a MySQL
    if ! mysql -u"$DB_USER" -p"$DB_PASS" -e "USE $DB_NAME; SELECT 1;" >/dev/null 2>&1; then
        log_error "No se pudo conectar a la base de datos MySQL"
        log_error "Usuario: $DB_USER, Base: $DB_NAME"
        return 1
    fi
    
    log_info "Exportando base de datos a: $DB_DUMP"
    
    # Usar pigz si está disponible, sino gzip
    local compressor="gzip -1"
    if command -v pigz >/dev/null 2>&1; then
        compressor="pigz -p $ZSTD_THREADS -1"
        log_info "Usando pigz con $ZSTD_THREADS threads para compresión de BD"
    else
        log_info "Usando gzip estándar para compresión de BD"
    fi
    
    # Realizar dump con configuración conservadora
    if mysqldump \
        --user="$DB_USER" \
        --password="$DB_PASS" \
        --single-transaction \
        --routines \
        --triggers \
        --events \
        --lock-tables=false \
        --add-drop-table \
        --extended-insert \
        --quick \
        --order-by-primary \
        --default-character-set=utf8mb4 \
        --max_allowed_packet="$MYSQL_BUFFER_SIZE" \
        --net_buffer_length=1M \
        "$DB_NAME" | $compressor > "$DB_DUMP"; then
        
        local db_size=$(du -h "$DB_DUMP" | cut -f1)
        log_info "✅ Backup de BD completado - Tamaño: $db_size"
        return 0
    else
        log_error "❌ Error en el backup de la base de datos"
        return 1
    fi
}

# ===================== FUNCIÓN DE SNAPSHOT OPTIMIZADA (DE V1) =====================
create_optimized_snapshot() {
    local snapshot_base="${TMP_DIR}/snapshot_${FECHA}"
    local temp_log="/tmp/snapshot_creation_$$.log"
    
    log_info "Iniciando creación de snapshot con hard links (método V1 optimizado)"
    
    # Eliminar cualquier snapshot anterior de forma segura
    if [[ -d "$snapshot_base" ]]; then
        rm -rf "$snapshot_base" >/dev/null 2>&1
    fi
    
    # Crear estructura de directorios
    if ! mkdir -p "${snapshot_base}/www" "${snapshot_base}/moodledata" >/dev/null 2>&1; then
        log_error "No se pudo crear estructura de snapshot"
        return 1
    fi
    
    log_info "Creando hard links para archivos web..."
    
    # Crear hard links para archivos web preservando estructura
    local web_files_count=0
    while IFS= read -r -d '' file; do
        local relative_path="${file#$WWW_DIR/}"
        local target_dir="${snapshot_base}/www/$(dirname "$relative_path")"
        
        # Crear directorio si no existe
        mkdir -p "$target_dir" 2>/dev/null
        
        # Crear hard link preservando nombre y estructura
        if ln "$file" "${snapshot_base}/www/${relative_path}" 2>/dev/null; then
            ((web_files_count++))
        fi
    done < <(find "${WWW_DIR}" -type f -print0 2>/dev/null)
    
    log_info "Creando hard links para moodledata (excluyendo directorios problemáticos)..."
    
    # Crear hard links para moodledata preservando estructura
    local moodle_files_count=0
    while IFS= read -r -d '' file; do
        local relative_path="${file#$MOODLEDATA_DIR/}"
        local target_dir="${snapshot_base}/moodledata/$(dirname "$relative_path")"
        
        # Crear directorio si no existe
        mkdir -p "$target_dir" 2>/dev/null
        
        # Crear hard link preservando nombre y estructura
        if ln "$file" "${snapshot_base}/moodledata/${relative_path}" 2>/dev/null; then
            ((moodle_files_count++))
        fi
    done < <(find "${MOODLEDATA_DIR}" -type f \
        ! -path "*/cache/*" \
        ! -path "*/sessions/*" \
        ! -path "*/temp/*" \
        ! -path "*/localcache/*" \
        ! -path "*/lock/*" \
        ! -path "*/trashdir/*" \
        -print0 2>/dev/null)
    
    # Verificaciones finales
    if [[ ! -d "${snapshot_base}" ]] || [[ ! -d "${snapshot_base}/www" ]] || [[ ! -d "${snapshot_base}/moodledata" ]]; then
        log_error "Error en la estructura del snapshot"
        return 1
    fi
    
    # Verificar que hay archivos
    local total_files=$(find "${snapshot_base}" -type f 2>/dev/null | wc -l)
    if [[ $total_files -eq 0 ]]; then
        log_error "No se crearon archivos en el snapshot"
        return 1
    fi
    
    log_info "Snapshot creado exitosamente"
    log_info "Archivos web enlazados: $web_files_count"
    log_info "Archivos moodledata enlazados: $moodle_files_count"
    log_info "Total archivos: $total_files"
    log_info "Espacio utilizado: $(du -sh "${snapshot_base}" 2>/dev/null | cut -f1)"
    
    # Retornar solo la ruta del snapshot
    echo "${snapshot_base}"
    return 0
}

# ===================== COMPRESIÓN POR ARCHIVOS INDEPENDIENTES (V3 NUEVO) =====================
compress_independent_files() {
    log_info "Iniciando proceso de compresión por archivos independientes"
    
    # Crear snapshot
    local snapshot_path
    if snapshot_path=$(create_optimized_snapshot); then
        if [[ ! -d "$snapshot_path" ]]; then
            log_error "Error crítico: Ruta de snapshot inválida: '$snapshot_path'"
            return 1
        fi
    else
        log_error "Error crítico: No se pudo crear snapshot"
        return 1
    fi
    
    # Asignar a variable global para limpieza
    SNAPSHOT_DIR="$snapshot_path"
    
    log_info "Snapshot creado en: $SNAPSHOT_DIR"
    log_info "Iniciando compresión de archivos independientes (threads: $ZSTD_THREADS, nivel: $ZSTD_LEVEL)"
    
    # Verificaciones antes de comprimir
    if [[ ! -d "$SNAPSHOT_DIR/www" ]] || [[ ! -d "$SNAPSHOT_DIR/moodledata" ]]; then
        log_error "Error: Estructura de snapshot incompleta"
        return 1
    fi
    
    local compression_start=$(date +%s)
    local failed_compressions=()
    
    # 1. Comprimir moodle_core (archivos web)
    log_info "Comprimiendo moodle_core.tar.zst..."
    if nice -n 5 ionice -c2 -n4 tar \
        --warning=no-file-changed \
        --warning=no-file-removed \
        --ignore-failed-read \
        -I "zstd -$ZSTD_LEVEL --threads=$ZSTD_THREADS" \
        -cf "$CORE_ARCHIVE" \
        -C "$SNAPSHOT_DIR" \
        www 2>/dev/null; then
        
        local core_size=$(du -h "$CORE_ARCHIVE" | cut -f1)
        log_info "✅ moodle_core.tar.zst completado - Tamaño: $core_size"
    else
        log_error "❌ Error comprimiendo moodle_core"
        failed_compressions+=("moodle_core")
    fi
    
    # 2. Comprimir moodledata
    log_info "Comprimiendo moodledata.tar.zst..."
    if nice -n 5 ionice -c2 -n4 tar \
        --warning=no-file-changed \
        --warning=no-file-removed \
        --ignore-failed-read \
        -I "zstd -$ZSTD_LEVEL --threads=$ZSTD_THREADS" \
        -cf "$DATA_ARCHIVE" \
        -C "$SNAPSHOT_DIR" \
        moodledata 2>/dev/null; then
        
        local data_size=$(du -h "$DATA_ARCHIVE" | cut -f1)
        log_info "✅ moodledata.tar.zst completado - Tamaño: $data_size"
    else
        log_error "❌ Error comprimiendo moodledata"
        failed_compressions+=("moodledata")
    fi
    
    local compression_end=$(date +%s)
    local compression_time=$((compression_end - compression_start))
    
    # Verificar resultados
    if [[ ${#failed_compressions[@]} -eq 0 ]]; then
        log_info "✅ Compresión de archivos independientes completada exitosamente"
        log_info "Base de datos: $(du -h "$DB_DUMP" | cut -f1)"
        log_info "Moodle Core: $(du -h "$CORE_ARCHIVE" | cut -f1)"
        log_info "Moodle Data: $(du -h "$DATA_ARCHIVE" | cut -f1)"
        log_info "Tiempo total: ${compression_time}s"
        return 0
    else
        log_error "❌ Error en compresión de archivos: ${failed_compressions[*]}"
        return 1
    fi
}

# ===================== COMPATIBILIDAD: FUNCIÓN ORIGINAL (FALLBACK) =====================
compress_files() {
    log_warn "Usando método de compresión fallback (archivo único)"
    return compress_independent_files
}

# ===================== SUBIDA A GOOGLE DRIVE ROBUSTA (DE V2) =====================
upload_to_gdrive() {
    # Verificar cuota ANTES de intentar subir
    if ! check_drive_quota; then
        log_warn "Verificación de cuota mostró posibles problemas - Continuando con precaución"
    fi
    
    log_info "Iniciando subida a Google Drive (configuración conservadora)"
    
    # Crear archivo temporal para capturar salida de rclone
    local rclone_output="/tmp/rclone_output_$$.log"
    
    # Configuración conservadora para archivos grandes
    local upload_success=false
    local max_attempts=3
    local attempt=1
    
    # Calcular timeout dinámico basado en tamaño del archivo
    local file_size_gb=0
    if [[ -f "$DESTINO" ]]; then
        file_size_gb=$(du -h "$DESTINO" | awk '{print $1}' | sed 's/G.*//' | cut -d. -f1)
        [[ -z "$file_size_gb" ]] && file_size_gb=100
    fi
    
    # Timeout dinámico: 25 minutos por GB (más conservador), mínimo 2 horas, máximo 10 horas
    local timeout_seconds=$(( file_size_gb * 1500 ))
    [[ $timeout_seconds -lt 7200 ]] && timeout_seconds=7200    # Mínimo 2 horas
    [[ $timeout_seconds -gt 36000 ]] && timeout_seconds=36000  # Máximo 10 horas
    
    log_info "Timeout calculado: $((timeout_seconds / 3600)) horas para archivo de ${file_size_gb}GB"
    
    while [[ $attempt -le $max_attempts ]] && [[ "$upload_success" == "false" ]]; do
        log_info "Intento de subida $attempt/$max_attempts"
        
        # Ejecutar rclone con configuración conservadora
        log_info "Iniciando transferencia con rclone (configuración conservadora)..."
        
        # Configuración más conservadora que V2
        if rclone copy "$DESTINO" "$GDRIVE_REMOTE" \
            --drive-chunk-size=512M \
            --drive-upload-cutoff=512M \
            --bwlimit=0 \
            --checkers=4 \
            --transfers=2 \
            --retries=5 \
            --retries-sleep=30s \
            --timeout="${timeout_seconds}s" \
            --stats=300s \
            --stats-one-line \
            --buffer-size=128M \
            --tpslimit=8 \
            --drive-acknowledge-abuse=true \
            --drive-stop-on-upload-limit=true \
            --log-level=INFO \
            --progress > "$rclone_output" 2>&1; then
            
            upload_success=true
            log_info "✅ Subida completada exitosamente"
            break
        else
            log_error "Error en intento $attempt"
            
            # Analizar tipo de error (código de V2)
            if [[ -f "$rclone_output" ]]; then
                if grep -q "storageQuotaExceeded\|quotaExceeded\|quota.*exceeded" "$rclone_output"; then
                    log_error "Error de cuota detectado en Google Drive"
                    rm -f "$rclone_output"
                    return 2  # Código específico para cuota excedida
                elif grep -q "timeout\|connection\|network\|temporary failure" "$rclone_output"; then
                    log_warn "Error temporal de red, reintentando..."
                    sleep 60
                fi
            fi
        fi
        
        attempt=$((attempt + 1))
    done
    
    # Limpiar archivos temporales
    rm -f "$rclone_output"
    
    if [[ "$upload_success" == "true" ]]; then
        log_info "✅ Subida a Google Drive completada exitosamente"
        return 0
    else
        log_error "❌ Falló la subida después de $max_attempts intentos"
        return 1
    fi
}

# ===================== SUBIDA SECUENCIAL DE ARCHIVOS INDEPENDIENTES (V3 NUEVO) =====================

# Función para subir un archivo individual con reintentos
upload_single_file() {
    local file_path="$1"
    local remote_folder="$2"
    local file_description="$3"
    local max_attempts=3
    local attempt=1
    
    if [[ ! -f "$file_path" ]]; then
        log_error "Archivo no encontrado: $file_path"
        return 1
    fi
    
    local file_name=$(basename "$file_path")
    local file_size=$(du -h "$file_path" | cut -f1)
    
    # Calcular timeout dinámico basado en tamaño
    local file_size_mb=$(stat -c%s "$file_path" 2>/dev/null)
    file_size_mb=$((file_size_mb / 1024 / 1024))
    local timeout_seconds=$((file_size_mb * 2 + 600))  # 2s por MB + 10min base
    [[ $timeout_seconds -lt 1800 ]] && timeout_seconds=1800    # Mínimo 30min
    [[ $timeout_seconds -gt 21600 ]] && timeout_seconds=21600  # Máximo 6h
    
    log_info "Subiendo $file_description: $file_name ($file_size)"
    log_info "Timeout: $((timeout_seconds / 60)) minutos"
    
    while [[ $attempt -le $max_attempts ]]; do
        log_info "Intento $attempt/$max_attempts para $file_name"
        
        local rclone_output="/tmp/rclone_${file_name}_$$.log"
        local upload_start=$(date +%s)
        
        # Subir archivo con configuración conservadora
        if rclone copy "$file_path" "$remote_folder" \
            --drive-chunk-size=256M \
            --drive-upload-cutoff=256M \
            --bwlimit=0 \
            --checkers=2 \
            --transfers=1 \
            --retries=3 \
            --retries-sleep=30s \
            --timeout="${timeout_seconds}s" \
            --stats=120s \
            --stats-one-line \
            --buffer-size=64M \
            --tpslimit=6 \
            --drive-acknowledge-abuse=true \
            --drive-stop-on-upload-limit=true \
            --log-level=INFO \
            --progress > "$rclone_output" 2>&1; then
            
            local upload_end=$(date +%s)
            local upload_time=$((upload_end - upload_start))
            
            log_info "✅ $file_description subido exitosamente"
            log_info "Tiempo: $((upload_time / 60))m $((upload_time % 60))s"
            
            rm -f "$rclone_output"
            return 0
        else
            log_error "❌ Error en intento $attempt para $file_name"
            
            # Analizar tipo de error
            if [[ -f "$rclone_output" ]]; then
                if grep -q "storageQuotaExceeded\|quotaExceeded\|quota.*exceeded" "$rclone_output"; then
                    log_error "Error de cuota en Google Drive para $file_name"
                    rm -f "$rclone_output"
                    return 2
                elif grep -q "timeout\|connection\|network\|temporary failure" "$rclone_output"; then
                    log_warn "Error temporal de red para $file_name, esperando..."
                    sleep $((attempt * 30))
                fi
            fi
            
            rm -f "$rclone_output"
        fi
        
        attempt=$((attempt + 1))
    done
    
    log_error "❌ Falló subida de $file_description después de $max_attempts intentos"
    return 1
}

# Función para crear carpeta en Google Drive
create_gdrive_folder() {
    local folder_path="$1"
    
    log_info "Creando carpeta en Google Drive: $folder_path"
    
    # Verificar si la carpeta ya existe
    if rclone lsd "$(dirname "$folder_path")" 2>/dev/null | grep -q "$(basename "$folder_path")"; then
        log_info "Carpeta ya existe, continuando..."
        return 0
    fi
    
    # Crear carpeta
    if rclone mkdir "$folder_path" 2>/dev/null; then
        log_info "✅ Carpeta creada exitosamente"
        return 0
    else
        log_error "❌ Error creando carpeta en Google Drive"
        return 1
    fi
}

# Función para verificar que la carpeta esté completa
verify_complete_folder() {
    local folder_path="$1"
    local expected_files=3
    
    log_info "Verificando carpeta completa en Google Drive..."
    
    # Contar archivos en la carpeta
    local file_count
    if file_count=$(rclone ls "$folder_path" 2>/dev/null | wc -l); then
        if [[ $file_count -eq $expected_files ]]; then
            log_info "✅ Carpeta completa verificada ($file_count/$expected_files archivos)"
            return 0
        else
            log_warn "⚠️ Carpeta incompleta ($file_count/$expected_files archivos)"
            return 1
        fi
    else
        log_error "❌ Error verificando carpeta en Google Drive"
        return 1
    fi
}

# Función principal para subida secuencial
upload_independent_files() {
    # Verificar cuota ANTES de intentar subir
    if ! check_drive_quota; then
        log_warn "Verificación de cuota mostró posibles problemas - Continuando con precaución"
    fi
    
    log_info "=== INICIANDO SUBIDA SECUENCIAL DE ARCHIVOS INDEPENDIENTES ==="
    
    # Crear carpeta de backup en Google Drive
    if ! create_gdrive_folder "$GDRIVE_BACKUP_FOLDER"; then
        log_error "No se pudo crear carpeta de backup"
        return 1
    fi
    
    # Array de archivos a subir: [archivo, descripción]
    local files_to_upload=(
        "$DB_DUMP:Base de datos (database.sql.gz)"
        "$CORE_ARCHIVE:Archivos web (moodle_core.tar.zst)"
        "$DATA_ARCHIVE:Datos de usuario (moodledata.tar.zst)"
    )
    
    local failed_uploads=()
    local upload_session_start=$(date +%s)
    
    # Subir cada archivo secuencialmente
    for file_entry in "${files_to_upload[@]}"; do
        local file_path="${file_entry%%:*}"
        local file_description="${file_entry##*:}"
        
        if upload_single_file "$file_path" "$GDRIVE_BACKUP_FOLDER" "$file_description"; then
            log_info "✅ Subida exitosa: $file_description"
        else
            local exit_code=$?
            if [[ $exit_code -eq 2 ]]; then
                log_error "❌ Error de cuota para: $file_description"
                return 2  # Código específico para cuota excedida
            else
                log_error "❌ Error de subida para: $file_description"
                failed_uploads+=("$file_description")
            fi
        fi
    done
    
    local upload_session_end=$(date +%s)
    local total_time=$((upload_session_end - upload_session_start))
    
    # Verificar resultados
    if [[ ${#failed_uploads[@]} -eq 0 ]]; then
        log_info "✅ SUBIDA SECUENCIAL COMPLETADA EXITOSAMENTE"
        log_info "Tiempo total: $((total_time / 60))m $((total_time % 60))s"
        
        # Verificar que la carpeta esté completa
        if verify_complete_folder "$GDRIVE_BACKUP_FOLDER"; then
            log_info "✅ Backup completo verificado en Google Drive"
            return 0
        else
            log_warn "⚠️ Verificación de carpeta mostró archivos faltantes"
            return 1
        fi
    else
        log_error "❌ SUBIDA SECUENCIAL FALLÓ"
        log_error "Archivos fallidos: ${failed_uploads[*]}"
        return 1
    fi
}

# ===================== COMPATIBILIDAD: FUNCIÓN ORIGINAL (FALLBACK) =====================
upload_to_gdrive() {
    log_warn "Usando método de subida independiente (nuevo flujo V3)"
    return upload_independent_files
}

# ===================== LIMPIEZA DE CARPETAS ANTIGUAS EN GOOGLE DRIVE (V3 NUEVO) =====================
cleanup_old_backup_folders() {
    log_info "Limpiando carpetas de backup antiguas en Google Drive (manteniendo $MAX_BACKUPS_GDRIVE)"
    
    # Obtener lista de carpetas de backup ordenadas por fecha
    local backup_folders
    if ! backup_folders=$(rclone lsd "$GDRIVE_REMOTE" 2>/dev/null | grep "moodle_backup_" | awk '{print $5}' | sort); then
        log_warn "No se pudo obtener lista de carpetas de backup existentes"
        return 0
    fi
    
    # Verificar si hay carpetas
    if [[ -z "$backup_folders" ]]; then
        log_info "No hay carpetas de backup existentes en Google Drive"
        return 0
    fi
    
    local folder_count=$(echo "$backup_folders" | wc -l)
    
    if [[ $folder_count -le $MAX_BACKUPS_GDRIVE ]]; then
        log_info "Número de carpetas ($folder_count) dentro del límite ($MAX_BACKUPS_GDRIVE)"
        return 0
    fi
    
    # Calcular cuántas eliminar
    local to_delete=$((folder_count - MAX_BACKUPS_GDRIVE))
    
    log_info "Eliminando $to_delete carpeta(s) de backup antigua(s)..."
    
    # Eliminar las más antiguas (solo carpetas completas)
    echo "$backup_folders" | head -n $to_delete | while read -r backup_folder; do
        if [[ -n "$backup_folder" ]]; then
            local full_folder_path="${GDRIVE_REMOTE}/${backup_folder}"
            
            # Verificar que la carpeta esté completa antes de eliminar
            local file_count
            if file_count=$(rclone ls "$full_folder_path" 2>/dev/null | wc -l); then
                if [[ $file_count -eq 3 ]]; then
                    log_info "Eliminando carpeta completa: $backup_folder"
                    if rclone purge "$full_folder_path" 2>/dev/null; then
                        log_info "✅ Carpeta eliminada: $backup_folder"
                    else
                        log_warn "❌ No se pudo eliminar carpeta: $backup_folder"
                    fi
                else
                    log_warn "⚠️ Carpeta incompleta no eliminada: $backup_folder ($file_count/3 archivos)"
                fi
            else
                log_warn "❌ Error verificando carpeta: $backup_folder"
            fi
        fi
    done
    
    log_info "✅ Limpieza de carpetas antiguas completada"
}

# ===================== COMPATIBILIDAD: FUNCIÓN ORIGINAL =====================
cleanup_old_backups() {
    log_info "Usando limpieza de carpetas (nuevo flujo V3)"
    return cleanup_old_backup_folders
}

# ===================== LIMPIEZA HÍBRIDA =====================
cleanup_hybrid() {
    log_info "Iniciando limpieza híbrida del sistema"
    
    # Desactivar modo mantenimiento siempre
    disable_maintenance_mode
    
    # Limpiar snapshot si existe
    if [[ -n "$SNAPSHOT_DIR" ]] && [[ -d "$SNAPSHOT_DIR" ]]; then
        log_info "Eliminando snapshot: $SNAPSHOT_DIR"
        rm -rf "$SNAPSHOT_DIR" 2>/dev/null || log_warn "No se pudo eliminar snapshot completamente"
        SNAPSHOT_DIR=""
    fi
    
    # Limpieza híbrida: eliminar archivos específicos pero mantener estructura
    log_info "Limpieza híbrida: eliminando archivos de backup actuales"
    
    # Eliminar archivos del backup actual (tanto archivos independientes como archivo único)
    rm -f "${DB_DUMP}" "${CORE_ARCHIVE}" "${DATA_ARCHIVE}" "${DESTINO}" 2>/dev/null || true
    
    # Limpiar archivos antiguos (más de 1 día como especificaste)
    log_info "Limpiando archivos antiguos (>1 día) pero manteniendo estructura"
    find "$TMP_DIR" -name "moodle_backup_*.tar.zst" -mtime +1 -delete 2>/dev/null || true
    find "$TMP_DIR" -name "database_*.sql.gz" -mtime +1 -delete 2>/dev/null || true
    find "$TMP_DIR" -name "moodle_core_*.tar.zst" -mtime +1 -delete 2>/dev/null || true
    find "$TMP_DIR" -name "moodledata_*.tar.zst" -mtime +1 -delete 2>/dev/null || true
    find "$TMP_DIR" -name "db_dump_*.sql.gz" -mtime +1 -delete 2>/dev/null || true
    find "$TMP_DIR" -name "snapshot_*" -type d -mtime +1 -exec rm -rf {} + 2>/dev/null || true
    
    # Limpiar logs de sesión antiguos
    find /tmp -name "moodle_backup_session_*.log" -mtime +1 -delete 2>/dev/null || true
    find /tmp -name "snapshot_creation_*.log" -mtime +1 -delete 2>/dev/null || true
    
    # Limpiar lock de logging
    rm -f "$LOG_LOCK" 2>/dev/null || true
    
    log_info "✅ Limpieza híbrida completada - Estructura preservada, archivos antiguos eliminados"
}

# ===================== SISTEMA DE NOTIFICACIONES HÍBRIDO =====================
send_notification() {
    local status="$1"
    
    # Evitar notificaciones duplicadas
    if [[ "$ERROR_NOTIFIED" == "true" ]] && [[ "$status" == "FAILURE" ]]; then
        return 0
    fi
    
    if [[ "$status" == "FAILURE" ]] || [[ "$status" == "QUOTA_EXCEEDED" ]]; then
        ERROR_NOTIFIED=true
    fi
    
    local subject=""
    local body=""
    local session_duration=""
    
    # Calcular duración si hay tiempo de inicio
    if [[ -n "$SESSION_START_TIME" ]]; then
        local end_time=$(date +%s)
        local duration=$((end_time - SESSION_START_TIME))
        session_duration="Duración: $((duration / 60))m $((duration % 60))s"
    fi
    
    # Usar formato formal de V1 pero con mejores estados de V2
    case "$status" in
        "SUCCESS")
            subject="${CLIENT_NAME} moodle_backup_${BACKUP_DATE} - EXITOSO"
            body="El backup de Moodle se completó exitosamente.

RESUMEN:
- Servidor: $SERVER_NAME
- Fecha: $(date '+%Y-%m-%d %H:%M:%S')
- $session_duration
- Carpeta: moodle_backup_${BACKUP_DATE}
- Retención: $MAX_BACKUPS_GDRIVE carpetas en Google Drive
- Método: Archivos independientes con subida secuencial (V3)
- Configuración: $ZSTD_THREADS threads (conservador)

ARCHIVOS GENERADOS:
- Base de datos: $(du -h "$DB_DUMP" 2>/dev/null | cut -f1 || echo "N/A")
- Moodle Core: $(du -h "$CORE_ARCHIVE" 2>/dev/null | cut -f1 || echo "N/A") 
- Moodle Data: $(du -h "$DATA_ARCHIVE" 2>/dev/null | cut -f1 || echo "N/A")

ESTADO: Completado exitosamente
ALMACENAMIENTO: Carpeta $GDRIVE_BACKUP_FOLDER
LIMPIEZA: Híbrida - archivos locales eliminados, estructura preservada"
            ;;
        "FAILURE")
            subject="${CLIENT_NAME} moodle_backup_${BACKUP_DATE} - FALLIDO"
            body="El backup de Moodle falló durante la ejecución.

ALERTA:
- Servidor: $SERVER_NAME
- Fecha: $(date '+%Y-%m-%d %H:%M:%S')
- $session_duration
- Estado: ERROR - Revisar logs inmediatamente

INFORMACIÓN DEL SISTEMA:
- Espacio disponible: $(df -h "$TMP_DIR" 2>/dev/null | awk 'NR==2 {print $4}' || echo "N/A")
- Snapshot utilizado: ${SNAPSHOT_DIR:-"No creado"}
- Configuración: $ZSTD_THREADS threads (conservador)
- Flujo: Archivos independientes con subida secuencial

ACCIÓN REQUERIDA:
- Verificar espacio en disco
- Comprobar conectividad a Google Drive
- Revisar logs detallados para identificar archivo fallido
- Sistema con limpieza híbrida aplicada"
            ;;
        "QUOTA_EXCEEDED")
            subject="${CLIENT_NAME} moodle_backup_${BACKUP_DATE} - CUOTA EXCEDIDA"
            body="El backup de Moodle falló por cuota de Google Drive excedida.

PROBLEMA DE CUOTA:
- Servidor: $SERVER_NAME
- Fecha: $(date '+%Y-%m-%d %H:%M:%S')
- $session_duration
- Estado: CUOTA EXCEDIDA durante subida secuencial

VENTAJAS DEL NUEVO FLUJO:
- Archivos subidos parcialmente pueden recuperarse
- No necesita resubir archivos ya exitosos
- Mejor granularidad para identificar problemas

CAUSAS POSIBLES:
- Límite diario de 750GB alcanzado
- Múltiples transferencias el mismo día
- Archivos de backup superan límite disponible

SOLUCIONES RECOMENDADAS:
1. Reprogramar backup para horario 2-6 AM
2. Verificar otros backups programados el mismo día
3. Considerar usar múltiples cuentas Google Drive
4. Evaluar backup incremental vs completo

PRÓXIMOS PASOS:
- El backup se reintentará automáticamente mañana
- Verificar manualmente espacio en Google Drive"
            ;;
        "INTERRUPTED")
            subject="${CLIENT_NAME} moodle_backup_${BACKUP_DATE} - INTERRUMPIDO"
            body="El backup de Moodle fue interrumpido por una señal externa.

ALERTA:
- Servidor: $SERVER_NAME
- Fecha: $(date '+%Y-%m-%d %H:%M:%S')
- $session_duration
- Estado: INTERRUMPIDO
- Limpieza híbrida aplicada

SISTEMA LISTO: Para próxima ejecución"
            ;;
    esac
    
    # Agregar logs relevantes al email
    if [[ -f "$SESSION_LOG" ]]; then
        body="$body

LOGS RECIENTES:
$(tail -30 "$SESSION_LOG" 2>/dev/null || echo "No se pudieron obtener los logs")"
    fi
    
    # Enviar notificación por email
    if [[ ${#NOTIFICATION_EMAILS[@]} -gt 0 ]]; then
        for email in "${NOTIFICATION_EMAILS[@]}"; do
            if [[ -n "$email" ]] && [[ "$email" != \#* ]]; then
                echo "$body" | mail -s "$subject" "$email" 2>/dev/null || {
                    log_warn "No se pudo enviar email a: $email"
                }
            fi
        done
        log_info "Notificación enviada: $subject"
    else
        log_warn "No hay emails configurados para notificaciones"
    fi
}

# ===================== VERIFICACIÓN DE INTEGRIDAD RÁPIDA =====================
verify_archive_integrity() {
    log_info "Verificando integridad del archivo comprimido (verificación rápida)"
    
    if [[ ! -f "$DESTINO" ]]; then
        log_error "Archivo de backup no encontrado: $DESTINO"
        return 1
    fi
    
    # Verificación rápida: tamaño mínimo esperado
    local file_size=$(stat -c%s "$DESTINO" 2>/dev/null || echo 0)
    local min_size=$((50 * 1024 * 1024))  # 50MB mínimo
    
    if [[ $file_size -lt $min_size ]]; then
        log_error "Archivo de backup sospechosamente pequeño: $(du -h "$DESTINO" | cut -f1)"
        return 1
    fi
    
    # Verificación básica de header zstd
    if ! zstd -t "$DESTINO" >/dev/null 2>&1; then
        log_error "Archivo de backup corrupto: falló verificación zstd"
        return 1
    fi
    
    local final_size=$(du -h "$DESTINO" | cut -f1)
    log_info "✅ Verificación de integridad exitosa - Tamaño: $final_size"
    return 0
}

# ===================== FUNCIONES DE AYUDA Y CONFIGURACIÓN =====================
show_configuration() {
    cat << EOF
CONFIGURACIÓN ACTUAL DEL BACKUP MOODLE V3
=========================================

CLIENTE:
  Nombre: $CLIENT_NAME
  Descripción: $CLIENT_DESCRIPTION

SERVIDOR:
  Usuario cPanel: $CPANEL_USER
  Directorio web: $WWW_DIR
  Directorio moodledata: $MOODLEDATA_DIR
  Directorio temporal: $TMP_DIR

BASE DE DATOS:
  Nombre: $DB_NAME
  Usuario: $DB_USER
  Contraseña: [configurada desde archivo/variable]

GOOGLE DRIVE:
  Remote: $GDRIVE_REMOTE
  Carpeta backup: moodle_backup_${CLIENT_NAME}_YYYY-MM-DD
  Retención: $MAX_BACKUPS_GDRIVE carpetas

RENDIMIENTO:
  Cores disponibles: $CORES
  Threads configurados: $ZSTD_THREADS
  Modo: $PERFORMANCE_MODE
  Horario optimizado: $OPTIMIZED_HOURS
  Nivel compresión: $ZSTD_LEVEL

NOTIFICACIONES:
  Total emails: ${#NOTIFICATION_EMAILS[@]}
  Destinatarios: ${NOTIFICATION_EMAILS[*]}

LOGGING:
  Archivo log: $LOG_FILE
  Log sesión: $SESSION_LOG

ARCHIVOS GENERADOS:
  Base datos: database_${CLIENT_NAME}_YYYY-MM-DD_HH-MM.sql.gz
  Web core: moodle_core_${CLIENT_NAME}_YYYY-MM-DD_HH-MM.tar.zst
  User data: moodledata_${CLIENT_NAME}_YYYY-MM-DD_HH-MM.tar.zst

DIAGNÓSTICO EXTENDIDO: ${EXTENDED_DIAGNOSTICS:-false}
EOF
}

show_help() {
    cat << 'EOF'
SCRIPT DE BACKUP MOODLE V3 - ARCHIVOS INDEPENDIENTES CON CONFIGURACIÓN EXTERNA
==============================================================================

DESCRIPCIÓN:
  Versión 3.0 con archivos independientes, subida secuencial y configuración externa
  - Configuración mediante archivos externos y variables de entorno
  - Auto-detección de instalaciones Moodle estándar
  - Compresión por archivos separados (BD, Core, Data)
  - Subida secuencial con reintentos granulares
  - Soporte multi-cliente y multi-entorno
  - Snapshots con hard links (eficiente en espacio)
  - Retención por carpetas completas en Google Drive

CONFIGURACIÓN:
  El script carga configuración en este orden de prioridad:
  1. Variables de entorno
  2. ./moodle_backup.conf (configuración local)
  3. /etc/moodle_backup.conf (configuración global)
  4. Auto-detección desde config.php de Moodle
  5. Valores por defecto

FLUJO DE EJECUCIÓN:
  1. Carga de configuración externa → 2. Validaciones críticas
  3. Modo mantenimiento ON → 4. Backup BD → 5. Snapshot archivos
  6. Modo mantenimiento OFF → 7. Compresión independiente
  8. Verificación individual → 9. Subida secuencial
  10. Limpieza de carpetas antiguas → 11. Notificación final

VENTAJAS NUEVA VERSIÓN:
  - Configuración externa sin modificar código
  - Auto-detección de instalaciones Moodle
  - Soporte multi-cliente desde un solo script
  - Emails dinámicos (por defecto + configuración)
  - Reintentos granulares por archivo
  - Logging detallado por cliente
  - Recuperación inteligente ante fallos

OPCIONES:
  --config         Mostrar configuración actual cargada
  --test-rclone    Verificar conectividad con Google Drive
  --diagnose       Ejecutar diagnóstico completo del sistema  
  --help           Mostrar esta ayuda

EJEMPLO DE USO:
  ./moodle_backup.sh                # Ejecutar backup completo
  ./moodle_backup.sh --config       # Mostrar configuración
  ./moodle_backup.sh --diagnose     # Solo diagnóstico
  ./moodle_backup.sh --test-rclone  # Solo test de conexión

CONFIGURACIÓN INICIAL:
  1. Copiar moodle_backup.conf.example a moodle_backup.conf
  2. Editar variables según tu entorno
  3. Ejecutar ./moodle_backup.sh --config para validar
  4. Configurar en cron

CONFIGURACIÓN CRON RECOMENDADA:
  0 2 * * * /ruta/al/moodle_backup.sh >/dev/null 2>&1

ARCHIVOS DE CONFIGURACIÓN:
  - moodle_backup.conf.example: Plantilla de configuración
  - moodle_backup.conf: Configuración específica (crear desde example)
  - /etc/moodle_backup.conf: Configuración global del servidor
EOF
}

# ===================== FUNCIÓN PRINCIPAL =====================
main() {
    # Validar configuración antes de comenzar el backup
    if ! validate_configuration; then
        echo "ERROR: Configuración inválida. Script abortado." >&2
        exit 1
    fi
    
    SESSION_START_TIME=$(date +%s)
    
    # Rotar logs al inicio
    rotate_logs
    
    # Inicializar log de sesión
    {
        echo "=== INICIO SESIÓN BACKUP MOODLE V3 HÍBRIDO ==="
        echo "Fecha: $(date)"
        echo "Sesión ID: $BACKUP_SESSION_ID"
        echo "Modo rendimiento: $PERFORMANCE_MODE"
        echo "Configuración: $ZSTD_THREADS threads"
        echo "=============================================="
    } > "$SESSION_LOG"
    
    log_info "=== INICIANDO BACKUP MOODLE V3 HÍBRIDO ==="
    log_info "Sesión ID: $BACKUP_SESSION_ID"
    log_info "Modo: $PERFORMANCE_MODE ($ZSTD_THREADS threads de $CORES disponibles)"
    
    # Función de manejo de errores con reintentos
    handle_backup_error() {
        local error_msg="$1"
        local step="$2"
        log_error "Error en $step: $error_msg"
        
        # Desactivar modo mantenimiento siempre que haya error
        disable_maintenance_mode
        
        send_notification "FAILURE"
        cleanup_hybrid
        exit 1
    }
    
    # Función de reintento para pasos críticos
    retry_step() {
        local step_name="$1"
        local step_function="$2"
        local max_retries=1
        local attempt=1
        
        while [[ $attempt -le $((max_retries + 1)) ]]; do
            if [[ $attempt -gt 1 ]]; then
                log_info "Reintentando $step_name (intento $attempt/$((max_retries + 1)))"
                sleep 5
            fi
            
            if $step_function; then
                return 0
            else
                if [[ $attempt -le $max_retries ]]; then
                    log_warn "Falló $step_name en intento $attempt, reintentando..."
                    # Limpiar estado parcial si es necesario
                    case "$step_name" in
                        "snapshot")
                            if [[ -n "$SNAPSHOT_DIR" ]] && [[ -d "$SNAPSHOT_DIR" ]]; then
                                rm -rf "$SNAPSHOT_DIR" 2>/dev/null || true
                                SNAPSHOT_DIR=""
                            fi
                            ;;
                        "compresión")
                            rm -f "$DESTINO" 2>/dev/null || true
                            ;;
                    esac
                else
                    handle_backup_error "Falló después de $max_retries reintentos" "$step_name"
                fi
            fi
            ((attempt++))
        done
    }
    
    # ============= FLUJO PRINCIPAL SEGÚN ESPECIFICACIONES =============
    
    # 1. VALIDACIONES CRÍTICAS
    log_info "Paso 1: Validaciones críticas"
    validate_environment || handle_backup_error "Validación de entorno falló" "validaciones"
    optimize_system_priority || handle_backup_error "Optimización de prioridades falló" "configuracion"
    check_hybrid_dependencies || handle_backup_error "Verificación de dependencias falló" "dependencias"
    diagnose_issues || handle_backup_error "Diagnóstico inicial falló" "diagnostico"
    
    # 2. MODO MANTENIMIENTO ON
    log_info "Paso 2: Activando modo mantenimiento"
    if ! enable_maintenance_mode; then
        handle_backup_error "No se pudo activar modo mantenimiento" "mantenimiento"
    fi
    
    # 3. BACKUP BASE DE DATOS
    log_info "Paso 3: Backup de base de datos"
    retry_step "backup_bd" backup_database
    
    # 4. SNAPSHOT ARCHIVOS  
    log_info "Paso 4: Creación de snapshot de archivos"
    snapshot_function() {
        if SNAPSHOT_DIR=$(create_optimized_snapshot); then
            return 0
        else
            return 1
        fi
    }
    retry_step "snapshot" snapshot_function
    
    # 5. MODO MANTENIMIENTO OFF (después del snapshot como especificaste)
    log_info "Paso 5: Desactivando modo mantenimiento"
    disable_maintenance_mode
    
    # 6. COMPRESIÓN POR ARCHIVOS INDEPENDIENTES + VERIFICACIÓN
    log_info "Paso 6: Compresión por archivos independientes"
    compression_function() {
        return compress_independent_files
    }
    retry_step "compresión" compression_function
    
    # 7. VERIFICACIÓN DE INTEGRIDAD INDIVIDUAL
    log_info "Paso 7: Verificación de integridad de archivos"
    verification_function() {
        local verification_errors=()
        
        # Verificar cada archivo individualmente
        log_info "Verificando database.sql.gz..."
        if [[ ! -f "$DB_DUMP" ]] || [[ $(stat -c%s "$DB_DUMP" 2>/dev/null || echo 0) -lt 1024 ]]; then
            verification_errors+=("Base de datos muy pequeña o inexistente")
        fi
        
        log_info "Verificando moodle_core.tar.zst..."
        if [[ ! -f "$CORE_ARCHIVE" ]] || ! zstd -t "$CORE_ARCHIVE" >/dev/null 2>&1; then
            verification_errors+=("Archivo core corrupto o inexistente")
        fi
        
        log_info "Verificando moodledata.tar.zst..."
        if [[ ! -f "$DATA_ARCHIVE" ]] || ! zstd -t "$DATA_ARCHIVE" >/dev/null 2>&1; then
            verification_errors+=("Archivo data corrupto o inexistente")
        fi
        
        # Reportar resultados
        if [[ ${#verification_errors[@]} -eq 0 ]]; then
            log_info "✅ Verificación de integridad exitosa para todos los archivos"
            log_info "DB: $(du -h "$DB_DUMP" | cut -f1)"
            log_info "Core: $(du -h "$CORE_ARCHIVE" | cut -f1)"
            log_info "Data: $(du -h "$DATA_ARCHIVE" | cut -f1)"
            return 0
        else
            log_error "❌ Errores de verificación: ${verification_errors[*]}"
            return 1
        fi
    }
    retry_step "verificación" verification_function
    
    # 8. SUBIDA SECUENCIAL A GOOGLE DRIVE
    log_info "Paso 8: Subida secuencial a Google Drive"
    local upload_result=0
    upload_independent_files || upload_result=$?
    
    case $upload_result in
        0)
            log_info "✅ Subida secuencial completada exitosamente"
            ;;
        2)
            log_error "❌ Error de cuota en Google Drive durante subida secuencial"
            send_notification "QUOTA_EXCEEDED"
            cleanup_hybrid
            exit 2
            ;;
        *)
            handle_backup_error "Error en subida secuencial después de reintentos" "subida"
            ;;
    esac
    
    # 9. LIMPIEZA DE CARPETAS ANTIGUAS
    log_info "Paso 9: Limpieza de carpetas antiguas en Google Drive"
    cleanup_old_backup_folders || log_warn "Error en limpieza de carpetas antiguas"
    
    # 10. NOTIFICACIÓN FINAL
    log_info "Paso 10: Notificación de éxito"
    send_notification "SUCCESS"
    
    # Limpieza final híbrida
    cleanup_hybrid
    
    local end_time=$(date +%s)
    local total_duration=$((end_time - SESSION_START_TIME))
    
    log_info "=== BACKUP COMPLETADO EXITOSAMENTE (V3 ARCHIVOS INDEPENDIENTES) ==="
    log_info "Duración total: $((total_duration / 60))m $((total_duration % 60))s"
    log_info "Carpeta en GDrive: moodle_backup_${BACKUP_DATE}"
    log_info "Configuración: V3 Híbrido $PERFORMANCE_MODE ($ZSTD_THREADS threads)"
    log_info "Archivos: database.sql.gz + moodle_core.tar.zst + moodledata.tar.zst"
    
    # Guardar resumen final en log de sesión
    {
        echo ""
        echo "=== RESUMEN FINAL V3 ==="
        echo "Estado: ÉXITO"
        echo "Duración: $((total_duration / 60))m $((total_duration % 60))s"
        echo "Carpeta: moodle_backup_${BACKUP_DATE}"
        echo "Archivos independientes: 3"
        echo "DB: $(du -h "$DB_DUMP" 2>/dev/null | cut -f1 || echo "N/A")"
        echo "Core: $(du -h "$CORE_ARCHIVE" 2>/dev/null | cut -f1 || echo "N/A")"
        echo "Data: $(du -h "$DATA_ARCHIVE" 2>/dev/null | cut -f1 || echo "N/A")"
        echo "Threads utilizados: $ZSTD_THREADS"
        echo "Modo: $PERFORMANCE_MODE"
        echo "====================="
    } >> "$SESSION_LOG"
}

# ===================== PROCESAMIENTO DE ARGUMENTOS =====================
# ===================== PROCESAMIENTO DE ARGUMENTOS =====================
case "${1:-}" in
    --help|-h)
        show_help
        exit 0
        ;;
    --show-config|--config)
        echo "=== CONFIGURACIÓN CARGADA ==="
        show_configuration
        echo ""
        echo "=== VALIDACIÓN ==="
        if validate_configuration "true"; then
            echo "✅ Configuración mostrada correctamente"
            exit 0
        else
            echo "❌ Error mostrando configuración"
            exit 1
        fi
        ;;
    --test-rclone)
        log_info "=== PRUEBA DE CONECTIVIDAD RCLONE ==="
        if test_rclone_connection; then
            log_info "✅ Conexión con Google Drive exitosa"
            log_info "Configuración rclone operativa"
            exit 0
        else
            log_error "❌ Falló la conexión con Google Drive"
            log_error "Verificar: rclone config"
            exit 1
        fi
        ;;
    --diagnose)
        log_info "=== MODO DIAGNÓSTICO V3 HÍBRIDO ==="
        validate_environment
        check_hybrid_dependencies
        diagnose_issues
        log_info "✅ Diagnóstico completado"
        exit 0
        ;;
    "")
        # Ejecución normal
        main
        ;;
    *)
        echo "Opción no reconocida: $1"
        echo "Usa --help para ver las opciones disponibles"
        exit 1
        ;;
esac
