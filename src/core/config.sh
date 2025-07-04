#!/bin/bash

##
# Sistema de Configuración Externa - Moodle Backup CLI
# Versión: 1.0.0
#
# Proporciona un sistema de configuración modular que permite
# cargar configuración desde múltiples fuentes con orden de precedencia
##

# Guard para evitar carga múltiple
[[ "${MOODLE_BACKUP_CONFIG_LOADED:-}" == "true" ]] && return 0
export MOODLE_BACKUP_CONFIG_LOADED="true"

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

# ===================== CONFIGURACIÓN DEL SISTEMA =====================

# Archivos de configuración en orden de precedencia (menor a mayor)
# Puede ser modificado para tests
if [[ -z "${CONFIG_FILES:-}" ]]; then
    CONFIG_FILES=(
        "/etc/moodle-backup/config.conf"            # Sistema global
        "/etc/moodle-backup.conf"                   # Sistema alternativo
        "$HOME/.config/moodle-backup/config.conf"   # Usuario
        "$HOME/.moodle-backup.conf"                 # Usuario alternativo
        "$(pwd)/.moodle-backup.conf"                # Directorio actual
        "${CONFIG_FILE:-}"                          # Variable de entorno
    )
fi

# Variables de configuración con valores por defecto
if [[ "${MOODLE_CLI_TEST_MODE:-}" == "true" ]]; then
    # En modo test, permitir redeclaración de arrays globales
    declare -gA CONFIG_DEFAULTS 2>/dev/null || true
    declare -gA CONFIG_VALUES 2>/dev/null || true
else
    # En modo normal, usar declaración estándar
    declare -A CONFIG_DEFAULTS
    declare -A CONFIG_VALUES
fi

# Inicializar CONFIG_DEFAULTS
CONFIG_DEFAULTS=(
    # Configuración general
    ["LOG_LEVEL"]="INFO"
    ["LOG_TO_FILE"]="true"
    ["LOG_TO_STDOUT"]="true"
    ["VERBOSE"]="false"
    ["DEBUG"]="false"
    
    # Directorios
    ["BACKUP_DIR"]="$HOME/backups"
    ["TMP_DIR"]="/tmp"
    ["LOG_DIR"]="${TEST_TEMP_DIR:-/var/log/moodle-backup}"
    
    # Base de datos
    ["DB_BACKUP_ENABLED"]="true"
    ["DB_COMPRESSION"]="true"
    ["DB_TIMEOUT"]="1800"
    
    # Archivos
    ["FILES_BACKUP_ENABLED"]="true"
    ["FILES_COMPRESSION"]="true"
    ["FILES_EXCLUDE_CACHE"]="true"
    
    # Compresión
    ["COMPRESSION_ALGORITHM"]="zstd"
    ["COMPRESSION_LEVEL"]="3"
    ["COMPRESSION_THREADS"]="auto"
    
    # Cloud storage
    ["CLOUD_ENABLED"]="false"
    ["CLOUD_PROVIDER"]=""
    ["CLOUD_RETENTION_DAYS"]="30"
    
    # Notificaciones
    ["NOTIFICATIONS_ENABLED"]="false"
    ["EMAIL_NOTIFICATIONS"]="false"
    ["EMAIL_ON_ERROR"]="true"
    
    # Seguridad
    ["ENCRYPT_BACKUPS"]="false"
    ["ENCRYPTION_KEY_FILE"]=""
    
    # Reintentos
    ["MAX_RETRIES"]="3"
    ["RETRY_DELAY"]="5"
    ["TIMEOUT"]="3600"
)

# Inicializar CONFIG_VALUES como array vacío
if [[ "${MOODLE_CLI_TEST_MODE:-}" != "true" ]]; then
    # Array para almacenar la configuración cargada
    declare -A CONFIG_VALUES=()
fi

# Archivo de configuración actualmente cargado
CONFIG_LOADED_FROM=""

# ===================== FUNCIONES PRIVADAS =====================

##
# Expande variables en un valor de configuración
# @param $1 string Valor a expandir
# @return string Valor expandido
##
_expand_config_value() {
    local value="$1"
    
    # 1. Expandir ~ para el directorio home (debe ser lo primero)
    if [[ "$value" =~ ^~/(.*)$ ]]; then
        value="${HOME}/${BASH_REMATCH[1]}"
    elif [[ "$value" == "~" ]]; then
        value="${HOME}"
    fi
    
    # 2. Expandir variables de entorno usando envsubst
    value=$(envsubst <<< "$value" 2>/dev/null || echo "$value")
    
    # 3. Expandir variables de configuración existentes (máximo 10 iteraciones para evitar loops)
    local expanded="$value"
    local iterations=0
    while [[ "$expanded" =~ \$\{([A-Z_]+)\} ]] && (( iterations < 10 )); do
        local var_name="${BASH_REMATCH[1]}"
        local var_value="${CONFIG_VALUES[$var_name]:-${CONFIG_DEFAULTS[$var_name]:-}}"
        expanded="${expanded/\$\{$var_name\}/$var_value}"
        ((iterations++))
    done
    
    echo "$expanded"
}

##
# Valida un valor de configuración
# @param $1 string Nombre de la variable
# @param $2 string Valor a validar
# @return int 0 si es válido, 1 si no
##
_validate_config_value() {
    local key="$1"
    local value="$2"
    
    case "$key" in
        *_ENABLED|VERBOSE|DEBUG|*_COMPRESSION|ENCRYPT_BACKUPS)
            # Valores booleanos
            [[ "$value" =~ ^(true|false|yes|no|1|0|on|off|enabled|disabled)$ ]]
            ;;
        LOG_LEVEL)
            # Niveles de logging válidos
            [[ "$value" =~ ^(ERROR|WARN|INFO|DEBUG|TRACE)$ ]]
            ;;
        COMPRESSION_LEVEL)
            # Nivel de compresión (0-9)
            [[ "$value" =~ ^[0-9]$ ]]
            ;;
        *_TIMEOUT|*_DELAY|RETENTION_DAYS|MAX_RETRIES)
            # Valores numéricos
            [[ "$value" =~ ^[0-9]+$ ]]
            ;;
        *_DIR)
            # Directorios - deben tener valor
            [[ -n "$value" ]]
            ;;
        *_FILE)
            # Archivos - pueden estar vacíos (opcional)
            true
            ;;
        ENCRYPTION_KEY_FILE)
            # Archivo de clave de encriptación - opcional
            true
            ;;
        *)
            # Por defecto, todo es válido
            true
            ;;
    esac
}

##
# Normaliza un valor booleano
# @param $1 string Valor a normalizar
# @return string "true" o "false"
##
_normalize_boolean() {
    local value="$1"
    case "${value,,}" in
        true|yes|1|on|enabled) echo "true" ;;
        *) echo "false" ;;
    esac
}

##
# Parsea un archivo de configuración
# @param $1 string Ruta del archivo
# @return int 0 si se carga exitosamente
##
_parse_config_file() {
    local config_file="$1"
    
    [[ -f "$config_file" ]] || return 1
    [[ -r "$config_file" ]] || {
        log_warn "No se puede leer el archivo de configuración: $config_file"
        return 1
    }
    
    log_debug "Parseando archivo de configuración: $config_file"
    
    local line_num=0
    while IFS= read -r line; do
        ((line_num++))
        
        # Saltar líneas vacías y comentarios
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Parsear variable=valor
        if [[ "$line" =~ ^[[:space:]]*([A-Z_][A-Z0-9_]*)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            # Remover comillas si las hay
            if [[ "$value" =~ ^[\"\'](.*)[\"\']*$ ]]; then
                value="${BASH_REMATCH[1]}"
            fi
            
            # Expandir variables
            value=$(_expand_config_value "$value")
            
            # Validar valor
            if _validate_config_value "$key" "$value"; then
                # Normalizar booleanos
                case "$key" in
                    *_ENABLED|VERBOSE|DEBUG|*_COMPRESSION|ENCRYPT_BACKUPS)
                        value=$(_normalize_boolean "$value")
                        ;;
                esac
                
                CONFIG_VALUES["$key"]="$value"
                log_debug "Configuración cargada: $key=$value"
            else
                log_warn "Valor inválido en $config_file:$line_num: $key=$value"
            fi
        else
            log_warn "Línea mal formateada en $config_file:$line_num: $line"
        fi
    done < "$config_file"
    
    CONFIG_LOADED_FROM="$config_file"
    return 0
}

# ===================== FUNCIONES PÚBLICAS =====================

##
# Carga la configuración desde múltiples fuentes
# @return int 0 si se carga exitosamente
##
config_load() {
    log_info "Cargando configuración del sistema"
    
    # Inicializar con valores por defecto
    for key in "${!CONFIG_DEFAULTS[@]}"; do
        CONFIG_VALUES["$key"]="${CONFIG_DEFAULTS[$key]}"
    done
    
    # Cargar desde archivos en orden de precedencia
    for config_file in "${CONFIG_FILES[@]}"; do
        [[ -n "$config_file" ]] || continue
        
        if _parse_config_file "$config_file"; then
            log_info "Configuración cargada desde: $config_file"
        fi
    done
    
    # Cargar desde variables de entorno (máxima precedencia)
    for key in "${!CONFIG_DEFAULTS[@]}"; do
        if [[ -n "${!key:-}" ]]; then
            local value="${!key}"
            if _validate_config_value "$key" "$value"; then
                CONFIG_VALUES["$key"]="$value"
                log_debug "Configuración desde ENV: $key=$value"
            fi
        fi
    done
    
    log_info "Configuración cargada exitosamente"
    return 0
}

##
# Obtiene un valor de configuración
# @param $1 string Nombre de la variable
# @param $2 string Valor por defecto (opcional)
# @return string Valor de configuración
##
config_get() {
    local key="$1"
    local default="${2:-}"
    
    if [[ -n "${CONFIG_VALUES[$key]:-}" ]]; then
        echo "${CONFIG_VALUES[$key]}"
    elif [[ -n "${CONFIG_DEFAULTS[$key]:-}" ]]; then
        echo "${CONFIG_DEFAULTS[$key]}"
    else
        echo "$default"
    fi
}

##
# Establece un valor de configuración
# @param $1 string Nombre de la variable
# @param $2 string Valor
# @return int 0 si es exitoso
##
config_set() {
    local key="$1"
    local value="$2"
    
    if _validate_config_value "$key" "$value"; then
        CONFIG_VALUES["$key"]="$value"
        return 0
    else
        log_error "Valor de configuración inválido: $key=$value"
        return 1
    fi
}

##
# Verifica si una clave de configuración existe
# @param $1 string Nombre de la variable
# @return int 0 si existe
##
config_has() {
    local key="$1"
    [[ -n "${CONFIG_VALUES[$key]:-${CONFIG_DEFAULTS[$key]:-}}" ]]
}

##
# Exporta la configuración como variables de entorno
# @param $1 string Prefijo opcional (default: MB_)
##
config_export() {
    local prefix="${1:-MB_}"
    
    for key in "${!CONFIG_VALUES[@]}"; do
        export "${prefix}${key}"="${CONFIG_VALUES[$key]}"
    done
}

##
# Muestra la configuración actual
##
config_show() {
    echo "Configuración actual:"
    echo "====================="
    
    if [[ -n "$CONFIG_LOADED_FROM" ]]; then
        echo "Cargada desde: $CONFIG_LOADED_FROM"
        echo
    fi
    
    # Mostrar configuración ordenada
    for key in $(printf '%s\n' "${!CONFIG_VALUES[@]}" | sort); do
        local value="${CONFIG_VALUES[$key]}"
        
        # Ocultar valores sensibles
        case "$key" in
            *PASSWORD*|*SECRET*|*TOKEN*|*KEY*)
                value="[OCULTO]"
                ;;
        esac
        
        printf "%-25s = %s\n" "$key" "$value"
    done
}

##
# Valida toda la configuración actual
# @return int 0 si toda la configuración es válida
##
config_validate() {
    local errors=0
    
    log_info "Validando configuración"
    
    for key in "${!CONFIG_VALUES[@]}"; do
        local value="${CONFIG_VALUES[$key]}"
        
        if ! _validate_config_value "$key" "$value"; then
            log_error "Configuración inválida: $key=$value"
            ((errors++))
        fi
    done
    
    # Validaciones adicionales
    local backup_dir
    backup_dir=$(config_get "BACKUP_DIR")
    if [[ ! -d "$backup_dir" ]] && ! mkdir -p "$backup_dir" 2>/dev/null; then
        log_error "No se puede crear el directorio de backup: $backup_dir"
        ((errors++))
    fi
    
    if (( errors > 0 )); then
        log_error "Se encontraron $errors errores en la configuración"
        return 1
    fi
    
    log_info "Configuración validada exitosamente"
    return 0
}

##
# Guarda la configuración actual en un archivo
# @param $1 string Ruta del archivo de destino
# @return int 0 si es exitoso
##
config_save() {
    local output_file="$1"
    
    [[ -n "$output_file" ]] || {
        log_error "config_save: se requiere un archivo de destino"
        return 1
    }
    
    local output_dir
    output_dir=$(dirname "$output_file")
    mkdir -p "$output_dir" || {
        log_error "No se puede crear el directorio: $output_dir"
        return 1
    }
    
    log_info "Guardando configuración en: $output_file"
    
    {
        echo "# Moodle Backup CLI Configuration"
        echo "# Generado automáticamente el $(date)"
        echo "# Archivo: $output_file"
        echo
        
        for key in $(printf '%s\n' "${!CONFIG_VALUES[@]}" | sort); do
            local value="${CONFIG_VALUES[$key]}"
            echo "$key=\"$value\""
        done
    } > "$output_file"
    
    log_info "Configuración guardada exitosamente"
    return 0
}

##
# Reinicia la configuración a valores por defecto
##
config_reset() {
    log_info "Reiniciando configuración a valores por defecto"
    
    CONFIG_VALUES=()
    CONFIG_LOADED_FROM=""
    
    for key in "${!CONFIG_DEFAULTS[@]}"; do
        CONFIG_VALUES["$key"]="${CONFIG_DEFAULTS[$key]}"
    done
}

##
# Muestra información de debug sobre la configuración
##
config_debug() {
    echo "Debug de configuración:"
    echo "======================="
    echo "Archivos buscados:"
    
    for config_file in "${CONFIG_FILES[@]}"; do
        [[ -n "$config_file" ]] || continue
        
        if [[ -f "$config_file" ]]; then
            if [[ -r "$config_file" ]]; then
                echo "  ✓ $config_file (encontrado y legible)"
            else
                echo "  ⚠ $config_file (encontrado pero no legible)"
            fi
        else
            echo "  ✗ $config_file (no encontrado)"
        fi
    done
    
    echo
    echo "Variables de entorno relevantes:"
    for key in "${!CONFIG_DEFAULTS[@]}"; do
        if [[ -n "${!key:-}" ]]; then
            echo "  $key=${!key}"
        fi
    done
    
    echo
    config_show
}
