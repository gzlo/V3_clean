#!/bin/bash

##
# Utilidades de Sistema de Archivos para Moodle Backup CLI
# Versión: 1.0.0
#
# Funciones especializadas para operaciones de archivos, directorios,
# permisos, espacio en disco y operaciones de filesystem.
##

# Guard para evitar carga múltiple
[[ "${MOODLE_BACKUP_FILESYSTEM_LOADED:-}" == "true" ]] && return 0
export MOODLE_BACKUP_FILESYSTEM_LOADED="true"

# Dependencias
source "$(dirname "${BASH_SOURCE[0]}")/constants.sh"
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

# ===================== FUNCIONES DE INFORMACIÓN DE SISTEMA =====================

##
# Obtiene información de espacio en disco para un path
#
# Arguments:
#   $1 - Path a verificar
# Outputs:
#   JSON con información de espacio (total, usado, disponible en bytes)
##
get_disk_space_info() {
    local path="$1"
    
    # Validar que el path existe
    [[ -e "$path" ]] || {
        echo '{"error": "Path no encontrado"}'
        return 1
    }
    
    # Usar df para obtener información
    local df_output
    if df_output=$(df -B1 "$path" 2>/dev/null | tail -n 1); then
        local total used available
        read -r _ total used available _ <<< "$df_output"
        
        # Calcular porcentaje usado
        local percentage=0
        [[ $total -gt 0 ]] && percentage=$(( (used * 100) / total ))
        
        cat <<EOF
{
    "total": $total,
    "used": $used,
    "available": $available,
    "percentage_used": $percentage,
    "path": "$path"
}
EOF
    else
        echo '{"error": "No se pudo obtener información de disco"}'
        return 1
    fi
}

##
# Verifica si hay suficiente espacio libre para una operación
#
# Arguments:
#   $1 - Path donde se necesita espacio
#   $2 - Espacio requerido en bytes
# Returns:
#   0 - Hay suficiente espacio
#   1 - No hay suficiente espacio
##
has_sufficient_disk_space() {
    local path="$1"
    local required_bytes="$2"
    
    local disk_info
    disk_info=$(get_disk_space_info "$path")
    
    # Extraer espacio disponible del JSON
    local available
    available=$(echo "$disk_info" | grep -o '"available": [0-9]*' | cut -d' ' -f2)
    
    [[ -n "$available" ]] && [[ $available -ge $required_bytes ]]
}

##
# Calcula el tamaño total de un directorio
#
# Arguments:
#   $1 - Directorio a medir
#   $2 - Profundidad máxima (opcional, default: sin límite)
# Outputs:
#   Tamaño en bytes
##
get_directory_size() {
    local directory="$1"
    local max_depth="${2:-}"
    
    [[ -d "$directory" ]] || {
        echo 0
        return 1
    }
    
    local du_cmd="du -sb"
    [[ -n "$max_depth" ]] && du_cmd="du -sb --max-depth=$max_depth"
    
    $du_cmd "$directory" 2>/dev/null | cut -f1 | head -n1
}

##
# Estima el tamaño que tendrá un directorio comprimido
#
# Arguments:
#   $1 - Directorio a estimar
#   $2 - Algoritmo de compresión (gzip, zstd, xz)
# Outputs:
#   Tamaño estimado en bytes
##
estimate_compressed_size() {
    local directory="$1"
    local algorithm="${2:-gzip}"
    
    local original_size
    original_size=$(get_directory_size "$directory")
    
    # Ratios de compresión estimados basados en contenido típico de Moodle
    local compression_ratio
    case "$algorithm" in
        "gzip")
            compression_ratio="0.3"  # ~70% compresión
            ;;
        "zstd")
            compression_ratio="0.25" # ~75% compresión
            ;;
        "xz")
            compression_ratio="0.2"  # ~80% compresión
            ;;
        "bzip2")
            compression_ratio="0.35" # ~65% compresión
            ;;
        *)
            compression_ratio="0.5"  # Estimación conservadora
            ;;
    esac
    
    # Calcular tamaño estimado
    echo "scale=0; $original_size * $compression_ratio / 1" | bc -l 2>/dev/null || echo "$original_size"
}

# ===================== FUNCIONES DE PERMISOS Y PROPIETARIOS =====================

##
# Verifica si el usuario actual tiene permisos específicos sobre un archivo/directorio
#
# Arguments:
#   $1 - Path del archivo/directorio
#   $2 - Permisos a verificar (r, w, x, rw, rx, wx, rwx)
# Returns:
#   0 - Tiene los permisos requeridos
#   1 - No tiene los permisos requeridos
##
has_permission() {
    local path="$1"
    local required_perms="$2"
    
    [[ -e "$path" ]] || return 1
    
    local has_read=false has_write=false has_execute=false
    
    [[ -r "$path" ]] && has_read=true
    [[ -w "$path" ]] && has_write=true
    [[ -x "$path" ]] && has_execute=true
    
    case "$required_perms" in
        "r")   $has_read ;;
        "w")   $has_write ;;
        "x")   $has_execute ;;
        "rw")  $has_read && $has_write ;;
        "rx")  $has_read && $has_execute ;;
        "wx")  $has_write && $has_execute ;;
        "rwx") $has_read && $has_write && $has_execute ;;
        *)     return 1 ;;
    esac
}

##
# Obtiene el propietario de un archivo/directorio
#
# Arguments:
#   $1 - Path del archivo/directorio
# Outputs:
#   Nombre del propietario
##
get_file_owner() {
    local path="$1"
    
    if [[ -e "$path" ]]; then
        if command_exists stat; then
            stat -c '%U' "$path" 2>/dev/null || ls -ld "$path" | awk '{print $3}'
        else
            ls -ld "$path" | awk '{print $3}'
        fi
    fi
}

##
# Obtiene el grupo de un archivo/directorio
#
# Arguments:
#   $1 - Path del archivo/directorio
# Outputs:
#   Nombre del grupo
##
get_file_group() {
    local path="$1"
    
    if [[ -e "$path" ]]; then
        if command_exists stat; then
            stat -c '%G' "$path" 2>/dev/null || ls -ld "$path" | awk '{print $4}'
        else
            ls -ld "$path" | awk '{print $4}'
        fi
    fi
}

##
# Obtiene los permisos octal de un archivo/directorio
#
# Arguments:
#   $1 - Path del archivo/directorio
# Outputs:
#   Permisos en formato octal (ej: 755)
##
get_file_permissions() {
    local path="$1"
    
    if [[ -e "$path" ]]; then
        if command_exists stat; then
            stat -c '%a' "$path" 2>/dev/null
        else
            # Fallback usando ls y conversión manual
            local perms
            perms=$(ls -ld "$path" | cut -c2-10)
            echo "$perms" | sed 's/...\(...\)\(...\)\(...\)/\1 \2 \3/' | while read -r user group other; do
                local u=0 g=0 o=0
                [[ "$user" =~ r ]] && u=$((u + 4))
                [[ "$user" =~ w ]] && u=$((u + 2))
                [[ "$user" =~ x ]] && u=$((u + 1))
                [[ "$group" =~ r ]] && g=$((g + 4))
                [[ "$group" =~ w ]] && g=$((g + 2))
                [[ "$group" =~ x ]] && g=$((g + 1))
                [[ "$other" =~ r ]] && o=$((o + 4))
                [[ "$other" =~ w ]] && o=$((o + 2))
                [[ "$other" =~ x ]] && o=$((o + 1))
                echo "$u$g$o"
            done
        fi
    fi
}

##
# Cambia permisos de forma segura con backup
#
# Arguments:
#   $1 - Path del archivo/directorio
#   $2 - Nuevos permisos (formato octal)
#   $3 - Crear backup de permisos (true/false, default: true)
# Returns:
#   0 - Permisos cambiados exitosamente
#   1 - Error al cambiar permisos
##
change_permissions_safe() {
    local path="$1"
    local new_perms="$2"
    local create_backup="${3:-true}"
    
    [[ -e "$path" ]] || return 1
    
    # Crear backup de permisos actuales si se solicita
    if [[ "$create_backup" == "true" ]]; then
        local current_perms
        current_perms=$(get_file_permissions "$path")
        echo "$current_perms" > "${path}.perms.backup.$(date +%s)" 2>/dev/null || true
    fi
    
    chmod "$new_perms" "$path"
}

# ===================== FUNCIONES DE OPERACIONES DE ARCHIVOS =====================

##
# Copia archivos/directorios con preservación de atributos
#
# Arguments:
#   $1 - Origen
#   $2 - Destino
#   $3 - Preservar permisos (true/false, default: true)
#   $4 - Preservar timestamps (true/false, default: true)
# Returns:
#   0 - Copia exitosa
#   1 - Error en la copia
##
copy_with_attributes() {
    local source="$1"
    local destination="$2"
    local preserve_perms="${3:-true}"
    local preserve_times="${4:-true}"
    
    [[ -e "$source" ]] || return 1
    
    local cp_options="-r"
    
    if [[ "$preserve_perms" == "true" ]] && [[ "$preserve_times" == "true" ]]; then
        cp_options+="p"
    elif [[ "$preserve_perms" == "true" ]]; then
        cp_options+=" --preserve=mode,ownership"
    elif [[ "$preserve_times" == "true" ]]; then
        cp_options+=" --preserve=timestamps"
    fi
    
    cp $cp_options "$source" "$destination"
}

##
# Mueve archivo/directorio con verificación de integridad
#
# Arguments:
#   $1 - Origen
#   $2 - Destino
#   $3 - Verificar integridad (true/false, default: true)
# Returns:
#   0 - Movimiento exitoso
#   1 - Error en el movimiento
##
move_with_verification() {
    local source="$1"
    local destination="$2"
    local verify_integrity="${3:-true}"
    
    [[ -e "$source" ]] || return 1
    
    # Si la verificación está habilitada y es un archivo
    if [[ "$verify_integrity" == "true" ]] && [[ -f "$source" ]]; then
        # Calcular checksum antes del movimiento
        local source_checksum
        if command_exists md5sum; then
            source_checksum=$(md5sum "$source" | cut -d' ' -f1)
        elif command_exists shasum; then
            source_checksum=$(shasum -a 256 "$source" | cut -d' ' -f1)
        else
            # Sin verificación si no hay herramientas disponibles
            verify_integrity=false
        fi
    fi
    
    # Realizar el movimiento
    if mv "$source" "$destination"; then
        # Verificar integridad después del movimiento si está habilitada
        if [[ "$verify_integrity" == "true" ]] && [[ -f "$destination" ]] && [[ -n "${source_checksum:-}" ]]; then
            local dest_checksum
            if command_exists md5sum; then
                dest_checksum=$(md5sum "$destination" | cut -d' ' -f1)
            elif command_exists shasum; then
                dest_checksum=$(shasum -a 256 "$destination" | cut -d' ' -f1)
            fi
            
            if [[ "$source_checksum" != "$dest_checksum" ]]; then
                echo "ERROR: Verificación de integridad falló durante el movimiento" >&2
                return 1
            fi
        fi
        return 0
    else
        return 1
    fi
}

##
# Elimina archivos/directorios de forma segura
#
# Arguments:
#   $1 - Path a eliminar
#   $2 - Confirmar eliminación (true/false, default: false)
#   $3 - Crear backup antes de eliminar (true/false, default: false)
# Returns:
#   0 - Eliminación exitosa
#   1 - Error en la eliminación o cancelada por usuario
##
remove_safe() {
    local path="$1"
    local confirm="${2:-false}"
    local create_backup="${3:-false}"
    
    [[ -e "$path" ]] || return 1
    
    # Solicitar confirmación si está habilitada
    if [[ "$confirm" == "true" ]]; then
        echo -n "¿Está seguro de eliminar '$path'? [y/N]: "
        local response
        read -r response
        [[ "$response" =~ ^[Yy]$ ]] || return 1
    fi
    
    # Crear backup si se solicita
    if [[ "$create_backup" == "true" ]]; then
        local backup_name="${path}.deleted.$(date +%s)"
        copy_with_attributes "$path" "$backup_name" || {
            echo "WARNING: No se pudo crear backup de '$path'" >&2
        }
    fi
    
    rm -rf "$path"
}

# ===================== FUNCIONES DE BÚSQUEDA DE ARCHIVOS =====================

##
# Busca archivos por patrón con filtros avanzados
#
# Arguments:
#   $1 - Directorio base de búsqueda
#   $2 - Patrón de nombre (puede usar wildcards)
#   $3 - Tipo (f=archivo, d=directorio, l=enlace, default: f)
#   $4 - Tamaño mínimo en bytes (opcional)
#   $5 - Tamaño máximo en bytes (opcional)
#   $6 - Edad máxima en días (opcional)
# Outputs:
#   Lista de archivos encontrados
##
find_files_advanced() {
    local base_dir="$1"
    local pattern="$2"
    local type="${3:-f}"
    local min_size="$4"
    local max_size="$5"
    local max_age="$6"
    
    [[ -d "$base_dir" ]] || return 1
    
    local find_cmd="find \"$base_dir\" -type $type -name \"$pattern\""
    
    # Agregar filtros de tamaño
    [[ -n "$min_size" ]] && find_cmd+=" -size +${min_size}c"
    [[ -n "$max_size" ]] && find_cmd+=" -size -${max_size}c"
    
    # Agregar filtro de edad
    [[ -n "$max_age" ]] && find_cmd+=" -mtime -$max_age"
    
    eval "$find_cmd" 2>/dev/null
}

##
# Busca archivos duplicados por contenido
#
# Arguments:
#   $1 - Directorio a analizar
#   $2 - Tamaño mínimo para considerar (bytes, default: 1024)
# Outputs:
#   Grupos de archivos duplicados
##
find_duplicate_files() {
    local directory="$1"
    local min_size="${2:-1024}"
    
    [[ -d "$directory" ]] || return 1
    
    # Verificar si existe herramienta de checksum
    local checksum_cmd
    if command_exists md5sum; then
        checksum_cmd="md5sum"
    elif command_exists shasum; then
        checksum_cmd="shasum -a 256"
    else
        echo "ERROR: No se encontró herramienta de checksum" >&2
        return 1
    fi
    
    # Buscar archivos por tamaño primero (optimización)
    find "$directory" -type f -size +${min_size}c -exec ls -l {} \; 2>/dev/null | \
    awk '{print $5 " " $9}' | \
    sort | \
    uniq -d -w 10 | \
    while read -r size file; do
        # Para archivos del mismo tamaño, calcular checksum
        find "$directory" -type f -size ${size}c -exec $checksum_cmd {} \; 2>/dev/null
    done | \
    sort | \
    uniq -d -w 32 | \
    awk '{print $2}'
}

##
# Busca archivos grandes en un directorio
#
# Arguments:
#   $1 - Directorio a analizar
#   $2 - Número de archivos más grandes a mostrar (default: 10)
#   $3 - Tamaño mínimo en MB (default: 10)
# Outputs:
#   Lista de archivos más grandes con su tamaño
##
find_large_files() {
    local directory="$1"
    local count="${2:-10}"
    local min_size_mb="${3:-10}"
    
    [[ -d "$directory" ]] || return 1
    
    local min_size_bytes=$((min_size_mb * 1024 * 1024))
    
    find "$directory" -type f -size +${min_size_bytes}c -exec ls -la {} \; 2>/dev/null | \
    awk '{print $5 " " $9}' | \
    sort -rn | \
    head -n "$count" | \
    while read -r size file; do
        local formatted_size
        formatted_size=$(format_bytes "$size")
        echo "$formatted_size $file"
    done
}

# ===================== FUNCIONES DE ARCHIVOS TEMPORALES =====================

##
# Crea directorio temporal seguro
#
# Arguments:
#   $1 - Prefijo del directorio (opcional)
#   $2 - Directorio padre (opcional, default: /tmp)
# Outputs:
#   Path del directorio temporal creado
##
create_temp_dir() {
    local prefix="${1:-moodle_backup_tmp}"
    local parent_dir="${2:-/tmp}"
    
    local temp_dir
    if command_exists mktemp; then
        temp_dir=$(mktemp -d "$parent_dir/${prefix}.XXXXXX")
    else
        # Fallback manual
        temp_dir="$parent_dir/${prefix}.$$.$RANDOM"
        mkdir -p "$temp_dir"
    fi
    
    # Establecer permisos seguros
    chmod 700 "$temp_dir"
    
    echo "$temp_dir"
}

##
# Crea archivo temporal seguro
#
# Arguments:
#   $1 - Prefijo del archivo (opcional)
#   $2 - Directorio padre (opcional, default: /tmp)
# Outputs:
#   Path del archivo temporal creado
##
create_temp_file() {
    local prefix="${1:-moodle_backup_tmp}"
    local parent_dir="${2:-/tmp}"
    
    local temp_file
    if command_exists mktemp; then
        temp_file=$(mktemp "$parent_dir/${prefix}.XXXXXX")
    else
        # Fallback manual
        temp_file="$parent_dir/${prefix}.$$.$RANDOM"
        touch "$temp_file"
    fi
    
    # Establecer permisos seguros
    chmod 600 "$temp_file"
    
    echo "$temp_file"
}

##
# Limpia archivos temporales antiguos
#
# Arguments:
#   $1 - Directorio temporal (default: /tmp)
#   $2 - Patrón de archivos a limpiar (default: moodle_backup_*)
#   $3 - Edad máxima en días (default: 7)
##
cleanup_temp_files() {
    local temp_dir="${1:-/tmp}"
    local pattern="${2:-moodle_backup_*}"
    local max_age="${3:-7}"
    
    [[ -d "$temp_dir" ]] || return 1
    
    find "$temp_dir" -name "$pattern" -type f -mtime +$max_age -delete 2>/dev/null || true
    find "$temp_dir" -name "$pattern" -type d -empty -mtime +$max_age -delete 2>/dev/null || true
}

# ===================== FUNCIONES DE MONTAJE Y FILESYSTEMS =====================

##
# Detecta el tipo de filesystem de un path
#
# Arguments:
#   $1 - Path a analizar
# Outputs:
#   Tipo de filesystem (ext4, xfs, btrfs, etc.)
##
detect_filesystem_type() {
    local path="$1"
    
    [[ -e "$path" ]] || return 1
    
    if command_exists stat; then
        stat -f -c %T "$path" 2>/dev/null
    elif command_exists df; then
        df -T "$path" 2>/dev/null | tail -n 1 | awk '{print $2}'
    else
        echo "unknown"
    fi
}

##
# Verifica si un path está en un montaje específico
#
# Arguments:
#   $1 - Path a verificar
#   $2 - Punto de montaje esperado
# Returns:
#   0 - Path está en el montaje especificado
#   1 - Path no está en el montaje especificado
##
is_path_in_mount() {
    local path="$1"
    local expected_mount="$2"
    
    local actual_mount
    actual_mount=$(df "$path" 2>/dev/null | tail -n 1 | awk '{print $6}')
    
    [[ "$actual_mount" == "$expected_mount" ]]
}

# ===================== INICIALIZACIÓN =====================

# Verificar comandos críticos para funciones de filesystem
for cmd in df ls chmod cp mv rm find; do
    if ! command_exists "$cmd"; then
        echo "ERROR: Comando requerido no encontrado: $cmd" >&2
        exit "$EXIT_DEPENDENCY_ERROR"
    fi
done
