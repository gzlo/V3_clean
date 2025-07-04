#!/bin/bash

##
# Utilidades Generales para Moodle Backup CLI
# Versión: 1.0.0
#
# Funciones de utilidad reutilizables para validación, conversión,
# manejo de strings, fechas y otras operaciones comunes.
##

# Guard para evitar carga múltiple
[[ "${MOODLE_BACKUP_UTILS_LOADED:-}" == "true" ]] && return 0
export MOODLE_BACKUP_UTILS_LOADED="true"

# Dependencias
source "$(dirname "${BASH_SOURCE[0]}")/constants.sh"

# ===================== FUNCIONES DE VALIDACIÓN =====================

##
# Valida si una cadena es un email válido
#
# Arguments:
#   $1 - Email a validar
# Returns:
#   0 - Email válido
#   1 - Email inválido
##
is_valid_email() {
    local email="$1"
    [[ "$email" =~ $REGEX_EMAIL ]]
}

##
# Valida si una cadena es una IP v4 válida
#
# Arguments:
#   $1 - IP a validar
# Returns:
#   0 - IP válida
#   1 - IP inválida
##
is_valid_ipv4() {
    local ip="$1"
    if [[ "$ip" =~ $REGEX_IPV4 ]]; then
        # Validar que cada octeto esté en rango 0-255
        local IFS='.'
        local -a octets=($ip)
        local octet
        for octet in "${octets[@]}"; do
            [[ "$octet" -ge 0 && "$octet" -le 255 ]] || return 1
        done
        return 0
    fi
    return 1
}

##
# Valida si una cadena es un dominio válido
#
# Arguments:
#   $1 - Dominio a validar
# Returns:
#   0 - Dominio válido
#   1 - Dominio inválido
##
is_valid_domain() {
    local domain="$1"
    [[ "$domain" =~ $REGEX_DOMAIN ]] && [[ ${#domain} -le 253 ]]
}

##
# Valida si una cadena es una URL válida
#
# Arguments:
#   $1 - URL a validar
# Returns:
#   0 - URL válida
#   1 - URL inválida
##
is_valid_url() {
    local url="$1"
    [[ "$url" =~ $REGEX_URL ]]
}

##
# Valida si un número está en un rango específico
#
# Arguments:
#   $1 - Número a validar
#   $2 - Valor mínimo
#   $3 - Valor máximo
# Returns:
#   0 - Número en rango
#   1 - Número fuera de rango
##
is_number_in_range() {
    local number="$1"
    local min="$2"
    local max="$3"
    
    # Verificar que sea un número
    [[ "$number" =~ ^-?[0-9]+([.][0-9]+)?$ ]] || return 1
    
    # Verificar rango usando aritmética de punto flotante
    if [[ "$BC_AVAILABLE" == "true" ]]; then
        (( $(echo "$number >= $min && $number <= $max" | bc -l 2>/dev/null || echo 0) ))
    else
        # Fallback para números enteros sin bc
        local int_number int_min int_max
        int_number=$(echo "$number" | cut -d. -f1)
        int_min=$(echo "$min" | cut -d. -f1)
        int_max=$(echo "$max" | cut -d. -f1)
        (( int_number >= int_min && int_number <= int_max ))
    fi
}

##
# Valida si un path existe y es accesible
#
# Arguments:
#   $1 - Path a validar
#   $2 - Tipo: 'file', 'dir', 'any' (default: any)
# Returns:
#   0 - Path válido
#   1 - Path inválido
##
is_valid_path() {
    local path="$1"
    local type="${2:-any}"
    
    [[ -n "$path" ]] || return 1
    
    case "$type" in
        "file")
            [[ -f "$path" ]]
            ;;
        "dir")
            [[ -d "$path" ]]
            ;;
        "any")
            [[ -e "$path" ]]
            ;;
        *)
            return 1
            ;;
    esac
}

# ===================== FUNCIONES DE CONVERSIÓN =====================

##
# Convierte bytes a formato legible (KB, MB, GB, etc.)
#
# Arguments:
#   $1 - Número de bytes
# Outputs:
#   Tamaño formateado
##
format_bytes() {
    local bytes="$1"
    local units=("B" "KB" "MB" "GB" "TB" "PB")
    local unit=0
    
    # Validar entrada
    [[ "$bytes" =~ ^[0-9]+$ ]] || {
        echo "0 B"
        return 1
    }
    
    # Convertir usando bc si está disponible, sino usar aritmética entera
    local size=$bytes
    
    if [[ "$BC_AVAILABLE" == "true" ]]; then
        while (( $(echo "$size >= 1024" | bc -l 2>/dev/null || echo 0) )) && [[ $unit -lt $((${#units[@]} - 1)) ]]; do
            size=$(echo "scale=1; $size / 1024" | bc -l 2>/dev/null || echo "$size")
            ((unit++))
        done
    else
        # Fallback sin bc para números enteros
        while (( size >= 1024 )) && [[ $unit -lt $((${#units[@]} - 1)) ]]; do
            size=$((size / 1024))
            ((unit++))
        done
    fi
    
    # Formatear resultado
    if [[ $unit -eq 0 ]]; then
        echo "${size%.*} ${units[$unit]}"
    else
        printf "%.1f %s\n" "$size" "${units[$unit]}"
    fi
}

##
# Convierte segundos a formato legible (1h 30m 45s)
#
# Arguments:
#   $1 - Número de segundos
# Outputs:
#   Tiempo formateado
##
format_duration() {
    local seconds="$1"
    local days hours minutes
    
    # Validar entrada
    [[ "$seconds" =~ ^[0-9]+$ ]] || {
        echo "0s"
        return 1
    }
    
    days=$((seconds / 86400))
    hours=$(((seconds % 86400) / 3600))
    minutes=$(((seconds % 3600) / 60))
    seconds=$((seconds % 60))
    
    local result=""
    [[ $days -gt 0 ]] && result+="${days}d "
    [[ $hours -gt 0 ]] && result+="${hours}h "
    [[ $minutes -gt 0 ]] && result+="${minutes}m "
    [[ $seconds -gt 0 || -z "$result" ]] && result+="${seconds}s"
    
    echo "${result% }"
}

##
# Convierte string a minúsculas
##
to_lowercase() {
    echo "$*" | tr '[:upper:]' '[:lower:]'
}

##
# Convierte string a mayúsculas
##
to_uppercase() {
    echo "$*" | tr '[:lower:]' '[:upper:]'
}

##
# Convierte string a formato título (Primera Letra Mayúscula)
##
to_titlecase() {
    echo "$*" | sed 's/\b\(.\)/\u\1/g'
}

# ===================== FUNCIONES DE MANIPULACIÓN DE STRINGS =====================

##
# Elimina espacios en blanco del inicio y final
##
trim() {
    local string="$*"
    # Eliminar espacios del inicio
    string="${string#"${string%%[![:space:]]*}"}"
    # Eliminar espacios del final
    string="${string%"${string##*[![:space:]]}"}"
    echo "$string"
}

##
# Escapa caracteres especiales para uso en regex
##
escape_regex() {
    echo "$*" | sed 's/[[\.*^$()+?{|]/\\&/g'
}

##
# Escapa caracteres especiales para uso en paths
##
escape_path() {
    echo "$*" | sed 's/[[:space:]]/\\ /g'
}

##
# Extrae el nombre de archivo de un path
##
basename_safe() {
    local path="$1"
    echo "${path##*/}"
}

##
# Extrae el directorio de un path
##
dirname_safe() {
    local path="$1"
    echo "${path%/*}"
}

##
# Genera un string aleatorio
#
# Arguments:
#   $1 - Longitud (default: 8)
#   $2 - Caracteres permitidos (default: alfanumérico)
##
generate_random_string() {
    local length="${1:-8}"
    local chars="${2:-abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789}"
    
    local result=""
    local i
    for ((i = 0; i < length; i++)); do
        result+="${chars:$((RANDOM % ${#chars})):1}"
    done
    
    echo "$result"
}

##
# Reemplaza múltiples espacios con uno solo
##
normalize_spaces() {
    echo "$*" | tr -s '[:space:]' ' '
}

##
# Trunca string a longitud máxima
#
# Arguments:
#   $1 - String a truncar
#   $2 - Longitud máxima
#   $3 - Sufijo para truncamiento (default: ...)
##
truncate_string() {
    local string="$1"
    local max_length="$2"
    local suffix="${3:-...}"
    
    if [[ ${#string} -le $max_length ]]; then
        echo "$string"
    else
        local truncated_length=$((max_length - ${#suffix}))
        echo "${string:0:$truncated_length}$suffix"
    fi
}

# ===================== FUNCIONES DE FECHA Y TIEMPO =====================

##
# Obtiene timestamp actual en formato ISO 8601
##
get_iso_timestamp() {
    date '+%Y-%m-%dT%H:%M:%S%z'
}

##
# Obtiene timestamp actual para nombres de archivo
##
get_file_timestamp() {
    date '+%Y%m%d_%H%M%S'
}

##
# Obtiene fecha actual en formato YYYY-MM-DD
##
get_date() {
    date '+%Y-%m-%d'
}

##
# Obtiene hora actual en formato HH:MM:SS
##
get_time() {
    date '+%H:%M:%S'
}

##
# Calcula diferencia entre dos timestamps
#
# Arguments:
#   $1 - Timestamp inicial (epoch)
#   $2 - Timestamp final (epoch, default: ahora)
# Outputs:
#   Diferencia en segundos
##
calculate_time_diff() {
    local start_time="$1"
    local end_time="${2:-$(date +%s)}"
    
    echo $((end_time - start_time))
}

##
# Convierte timestamp epoch a formato legible
##
epoch_to_date() {
    local epoch="$1"
    date -d "@$epoch" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r "$epoch" '+%Y-%m-%d %H:%M:%S'
}

# ===================== FUNCIONES DE ARRAY Y LISTAS =====================

##
# Verifica si un elemento está en un array
#
# Arguments:
#   $1 - Elemento a buscar
#   $@ - Array elementos
# Returns:
#   0 - Elemento encontrado
#   1 - Elemento no encontrado
##
array_contains() {
    local element="$1"
    shift
    
    local item
    for item in "$@"; do
        [[ "$item" == "$element" ]] && return 0
    done
    
    return 1
}

##
# Une elementos de array con un separador
#
# Arguments:
#   $1 - Separador
#   $@ - Elementos a unir
##
array_join() {
    local separator="$1"
    shift
    
    local result="$1"
    shift
    
    local item
    for item in "$@"; do
        result+="$separator$item"
    done
    
    echo "$result"
}

##
# Elimina duplicados de una lista
##
array_unique() {
    printf '%s\n' "$@" | sort -u
}

##
# Filtra array por patrón
#
# Arguments:
#   $1 - Patrón (regex)
#   $@ - Elementos a filtrar
##
array_filter() {
    local pattern="$1"
    shift
    
    local item
    for item in "$@"; do
        [[ "$item" =~ $pattern ]] && echo "$item"
    done
}

# ===================== FUNCIONES DE COMANDOS Y PROCESOS =====================

##
# Verifica si un comando existe
##
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

##
# Ejecuta comando con timeout
#
# Arguments:
#   $1 - Timeout en segundos
#   $@ - Comando a ejecutar
##
run_with_timeout() {
    local timeout="$1"
    shift
    
    if command_exists timeout; then
        timeout "$timeout" "$@"
    else
        # Fallback para sistemas sin timeout
        "$@" &
        local pid=$!
        local count=0
        
        while [[ $count -lt $timeout ]]; do
            if ! kill -0 "$pid" 2>/dev/null; then
                wait "$pid"
                return $?
            fi
            sleep 1
            ((count++))
        done
        
        kill -TERM "$pid" 2>/dev/null
        sleep 2
        kill -KILL "$pid" 2>/dev/null
        return 124  # Timeout exit code
    fi
}

##
# Ejecuta comando con reintentos
#
# Arguments:
#   $1 - Número máximo de reintentos
#   $2 - Delay entre reintentos (segundos)
#   $@ - Comando a ejecutar
##
run_with_retry() {
    local max_attempts="$1"
    local delay="$2"
    shift 2
    
    local attempt=1
    local exit_code
    
    while [[ $attempt -le $max_attempts ]]; do
        if "$@"; then
            return 0
        fi
        
        exit_code=$?
        
        if [[ $attempt -eq $max_attempts ]]; then
            return $exit_code
        fi
        
        sleep "$delay"
        ((attempt++))
    done
}

##
# Verifica si un proceso está ejecutándose
##
is_process_running() {
    local pid="$1"
    kill -0 "$pid" 2>/dev/null
}

##
# Obtiene el uso de CPU de un proceso
##
get_process_cpu() {
    local pid="$1"
    ps -p "$pid" -o %cpu= 2>/dev/null | trim
}

##
# Obtiene el uso de memoria de un proceso
##
get_process_memory() {
    local pid="$1"
    ps -p "$pid" -o %mem= 2>/dev/null | trim
}

# ===================== FUNCIONES DE CONFIGURACIÓN =====================

##
# Lee valor de configuración desde archivo INI
#
# Arguments:
#   $1 - Archivo de configuración
#   $2 - Sección
#   $3 - Clave
##
read_ini_value() {
    local file="$1"
    local section="$2"
    local key="$3"
    
    [[ -f "$file" ]] || return 1
    
    awk -F '=' -v section="[$section]" -v key="$key" '
        $0 == section { in_section = 1; next }
        /^\[/ { in_section = 0; next }
        in_section && $1 == key { 
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
            gsub(/^["'"'"']|["'"'"']$/, "", $2)
            print $2
            exit
        }
    ' "$file"
}

##
# Escribe valor de configuración a archivo INI
#
# Arguments:
#   $1 - Archivo de configuración
#   $2 - Sección
#   $3 - Clave
#   $4 - Valor
##
write_ini_value() {
    local file="$1"
    local section="$2"
    local key="$3"
    local value="$4"
    
    # Crear archivo si no existe
    [[ -f "$file" ]] || touch "$file"
    
    # Usar script temporal para modificación
    local temp_file
    temp_file=$(mktemp)
    
    awk -F '=' -v section="[$section]" -v key="$key" -v value="$value" '
        BEGIN { found_section = 0; found_key = 0 }
        $0 == section { 
            print
            in_section = 1
            found_section = 1
            next 
        }
        /^\[/ && in_section { 
            if (!found_key) {
                print key "=" value
                found_key = 1
            }
            in_section = 0
        }
        in_section && $1 == key {
            print key "=" value
            found_key = 1
            next
        }
        { print }
        END {
            if (!found_section) {
                print "\n" section
                print key "=" value
            } else if (!found_key) {
                print key "=" value
            }
        }
    ' "$file" > "$temp_file"
    
    mv "$temp_file" "$file"
}

# ===================== FUNCIONES DE LOG Y DEBUG =====================

##
# Imprime mensaje de debug si está habilitado
##
debug_print() {
    [[ "${MOODLE_BACKUP_DEBUG:-0}" == "1" ]] && echo "[DEBUG] $*" >&2
}

##
# Imprime trace de función si está habilitado
##
trace_function() {
    [[ "${MOODLE_BACKUP_TRACE:-0}" == "1" ]] && echo "[TRACE] Entering function: ${FUNCNAME[1]}" >&2
}

##
# Crea backup de archivo antes de modificarlo
##
backup_file() {
    local file="$1"
    local backup_suffix="${2:-.backup.$(date +%s)}"
    
    [[ -f "$file" ]] && cp "$file" "${file}${backup_suffix}"
}

# ===================== INICIALIZACIÓN =====================

# Verificar dependencias críticas
for cmd in date tr sed awk; do
    if ! command_exists "$cmd"; then
        echo "ERROR: Comando requerido no encontrado: $cmd" >&2
        exit "$EXIT_DEPENDENCY_ERROR"
    fi
done

# Verificar dependencias opcionales
if ! command_exists "bc"; then
    readonly BC_AVAILABLE=false
else
    readonly BC_AVAILABLE=true
fi
