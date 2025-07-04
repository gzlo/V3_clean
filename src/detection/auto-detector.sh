#!/usr/bin/env bash

##
# Moodle CLI Backup - Auto-Detector Principal
# 
# Orquestador principal de detección automática
# Coordina todos los detectores y proporciona un algoritmo de priorización
# 
# @version 1.0.0
# @author GZL Online
##

set -euo pipefail

# ===================== GUARDS Y VALIDACIONES =====================

if [[ "${MOODLE_AUTO_DETECTOR_LOADED:-}" == "true" ]]; then
    return 0
fi

readonly MOODLE_AUTO_DETECTOR_LOADED="true"

# Verificar dependencias core
if [[ "${MOODLE_BACKUP_LOGGING_LOADED:-}" != "true" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/../core/logging.sh"
fi

if [[ "${MOODLE_BACKUP_CONFIG_LOADED:-}" != "true" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/../core/config.sh"
fi

if [[ "${MOODLE_BACKUP_VALIDATION_LOADED:-}" != "true" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/../core/validation.sh"
fi

# ===================== CONFIGURACIÓN DE DETECCIÓN =====================

# Directorio de cache para resultados de detección
DETECTION_CACHE_DIR="${DETECTION_CACHE_DIR:-${TEST_TEMP_DIR:-/tmp}/moodle-detection-cache}"
DETECTION_CACHE_TTL="${DETECTION_CACHE_TTL:-3600}"  # 1 hora
DETECTION_MAX_DEPTH="${DETECTION_MAX_DEPTH:-3}"     # Profundidad máxima de búsqueda

# Prioridades de detección (menor número = mayor prioridad)
declare -A DETECTION_PRIORITIES=(
    ["panels"]=1
    ["directories"]=2
    ["moodle"]=3
    ["database"]=4
)

# Estado de detección
DETECTION_STARTED=false
declare -A DETECTION_RESULTS=()
declare -A DETECTION_CACHE=()
declare -a DETECTION_MODULES=()

# ===================== FUNCIONES DE CACHE =====================

##
# Inicializa el sistema de cache de detección
##
detection_cache_init() {
    if [[ "$MOODLE_CLI_TEST_MODE" == "true" ]]; then
        DETECTION_CACHE_DIR="$TEST_TEMP_DIR/detection-cache"
    fi
    
    mkdir -p "$DETECTION_CACHE_DIR"
    log_debug "Cache de detección inicializado en: $DETECTION_CACHE_DIR"
}

##
# Obtiene un valor del cache de detección
# @param $1 - Clave del cache
# @return 0 si existe y es válido, 1 si no existe o expiró
##
detection_cache_get() {
    local key="$1"
    local cache_file="$DETECTION_CACHE_DIR/${key}.cache"
    
    if [[ ! -f "$cache_file" ]]; then
        return 1
    fi
    
    # Verificar TTL
    local file_time
    file_time=$(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null || echo 0)
    local current_time
    current_time=$(date +%s)
    
    if (( current_time - file_time > DETECTION_CACHE_TTL )); then
        rm -f "$cache_file"
        return 1
    fi
    
    # Leer valor del cache
    cat "$cache_file"
    return 0
}

##
# Almacena un valor en el cache de detección
# @param $1 - Clave del cache
# @param $2 - Valor a almacenar
##
detection_cache_set() {
    local key="$1"
    local value="$2"
    local cache_file="$DETECTION_CACHE_DIR/${key}.cache"
    
    echo "$value" > "$cache_file"
    log_debug "Cache actualizado: $key"
}

##
# Limpia el cache de detección
##
detection_cache_clear() {
    if [[ -d "$DETECTION_CACHE_DIR" ]]; then
        rm -rf "$DETECTION_CACHE_DIR"/*
        log_info "Cache de detección limpiado"
    fi
}

# ===================== REGISTRO DE MÓDULOS =====================

##
# Registra un módulo de detección
# @param $1 - Nombre del módulo
# @param $2 - Path al archivo del módulo
##
detection_register_module() {
    local module_name="$1"
    local module_path="$2"
    
    if [[ ! -f "$module_path" ]]; then
        log_warning "Módulo de detección no encontrado: $module_path"
        return 1
    fi
    
    DETECTION_MODULES+=("$module_name:$module_path")
    log_debug "Módulo de detección registrado: $module_name"
}

##
# Carga todos los módulos de detección disponibles
##
detection_load_modules() {
    local detection_dir
    detection_dir="$(dirname "${BASH_SOURCE[0]}")"
    
    # Registrar módulos estándar
    local modules=(
        "panels:$detection_dir/panels.sh"
        "directories:$detection_dir/directories.sh"
        "moodle:$detection_dir/moodle.sh"
        "database:$detection_dir/database.sh"
    )
    
    for module in "${modules[@]}"; do
        local name="${module%%:*}"
        local path="${module##*:}"
        detection_register_module "$name" "$path"
    done
    
    log_info "Módulos de detección cargados: ${#DETECTION_MODULES[@]}"
}

# ===================== ALGORITMO DE DETECCIÓN =====================

##
# Ejecuta un módulo de detección específico
# @param $1 - Nombre del módulo
# @return 0 si la detección fue exitosa
##
detection_run_module() {
    local module_name="$1"
    local module_found=false
    
    # Buscar el módulo registrado
    for module in "${DETECTION_MODULES[@]}"; do
        local name="${module%%:*}"
        local path="${module##*:}"
        
        if [[ "$name" == "$module_name" ]]; then
            module_found=true
            
            # Verificar cache primero
            local cache_key="module_${module_name}"
            local cached_result
            if cached_result=$(detection_cache_get "$cache_key"); then
                log_debug "Usando resultado de cache para: $module_name"
                DETECTION_RESULTS["$module_name"]="$cached_result"
                return 0
            fi
            
            log_info "Ejecutando detección: $module_name"
            
            # Cargar y ejecutar el módulo
            if source "$path"; then
                # Llamar a la función principal del módulo
                local detection_function="detect_${module_name}"
                if declare -F "$detection_function" >/dev/null; then
                    local result
                    if result=$("$detection_function"); then
                        DETECTION_RESULTS["$module_name"]="$result"
                        detection_cache_set "$cache_key" "$result"
                        log_success "Detección completada: $module_name"
                        return 0
                    else
                        log_warning "Falló la detección: $module_name"
                        return 1
                    fi
                else
                    log_error "Función de detección no encontrada: $detection_function"
                    return 1
                fi
            else
                log_error "Error cargando módulo: $path"
                return 1
            fi
        fi
    done
    
    if [[ "$module_found" == "false" ]]; then
        log_error "Módulo de detección no registrado: $module_name"
        return 1
    fi
}

##
# Ejecuta todos los módulos de detección ordenados por prioridad
##
detection_run_all() {
    if [[ "$DETECTION_STARTED" == "true" ]]; then
        log_warning "Detección ya iniciada"
        return 0
    fi
    
    DETECTION_STARTED=true
    detection_cache_init
    detection_load_modules
    
    log_info "Iniciando detección automática..."
    
    # Ordenar módulos por prioridad
    local -a sorted_modules=()
    for module in "${DETECTION_MODULES[@]}"; do
        local name="${module%%:*}"
        local priority="${DETECTION_PRIORITIES[$name]:-999}"
        sorted_modules+=("$priority:$name")
    done
    
    # Ordenar por prioridad (sort numérico)
    local -a ordered_modules=()
    while IFS= read -r -d '' module; do
        ordered_modules+=("${module#*:}")
    done < <(printf '%s\0' "${sorted_modules[@]}" | sort -z -n)
    
    # Ejecutar módulos en orden de prioridad
    local success_count=0
    local total_modules=${#ordered_modules[@]}
    
    for module_name in "${ordered_modules[@]}"; do
        if detection_run_module "$module_name"; then
            ((success_count++))
        fi
    done
    
    log_info "Detección completada: $success_count/$total_modules módulos exitosos"
    
    # Generar reporte
    detection_generate_report
    
    return 0
}

# ===================== FUNCIONES DE REPORTE =====================

##
# Obtiene el resultado de un módulo de detección
# @param $1 - Nombre del módulo
##
detection_get_result() {
    local module_name="$1"
    echo "${DETECTION_RESULTS[$module_name]:-}"
}

##
# Verifica si un módulo tuvo detección exitosa
# @param $1 - Nombre del módulo
##
detection_has_result() {
    local module_name="$1"
    [[ -n "${DETECTION_RESULTS[$module_name]:-}" ]]
}

##
# Genera un reporte detallado de la detección
##
detection_generate_report() {
    local report_file="$DETECTION_CACHE_DIR/detection_report.txt"
    
    {
        echo "# Reporte de Detección Automática"
        echo "# Generado: $(date)"
        echo ""
        
        for module in "${!DETECTION_RESULTS[@]}"; do
            echo "## $module"
            echo "${DETECTION_RESULTS[$module]}"
            echo ""
        done
    } > "$report_file"
    
    log_info "Reporte generado: $report_file"
}

##
# Muestra un resumen de la detección en formato de tabla
##
detection_show_summary() {
    local -i panel_width=15
    local -i status_width=10
    local -i result_width=50
    
    echo ""
    echo "┌────────────────┬────────────┬──────────────────────────────────────────────────┐"
    printf "│ %-${panel_width}s │ %-${status_width}s │ %-${result_width}s │\n" "MÓDULO" "ESTADO" "RESULTADO"
    echo "├────────────────┼────────────┼──────────────────────────────────────────────────┤"
    
    for module_name in panels directories moodle database; do
        local status="❌ NO DETECTADO"
        local result="No disponible"
        
        if detection_has_result "$module_name"; then
            status="✅ DETECTADO"
            result=$(detection_get_result "$module_name" | head -1)
            # Truncar resultado si es muy largo
            if [[ ${#result} -gt $result_width ]]; then
                result="${result:0:$((result_width-3))}..."
            fi
        fi
        
        printf "│ %-${panel_width}s │ %-${status_width}s │ %-${result_width}s │\n" \
            "$module_name" "$status" "$result"
    done
    
    echo "└────────────────┴────────────┴──────────────────────────────────────────────────┘"
    echo ""
}

# ===================== FUNCIONES DE LIMPIEZA =====================

##
# Limpia el estado de detección
##
detection_cleanup() {
    DETECTION_STARTED=false
    DETECTION_RESULTS=()
    DETECTION_CACHE=()
    DETECTION_MODULES=()
    
    if [[ "$MOODLE_CLI_TEST_MODE" == "true" ]]; then
        detection_cache_clear
    fi
    
    log_debug "Estado de detección limpiado"
}

# ===================== FUNCIÓN PRINCIPAL =====================

##
# Función principal de detección automática
# @param $1 - Comando (opcional): 'run', 'summary', 'cleanup', 'cache-clear'
##
auto_detect() {
    local command="${1:-run}"
    
    case "$command" in
        "run")
            detection_run_all
            ;;
        "summary")
            detection_show_summary
            ;;
        "cleanup")
            detection_cleanup
            ;;
        "cache-clear")
            detection_cache_clear
            ;;
        "report")
            detection_generate_report
            ;;
        *)
            log_error "Comando no válido: $command"
            log_info "Comandos disponibles: run, summary, cleanup, cache-clear, report"
            return 1
            ;;
    esac
}

# ===================== MODO SCRIPT INDEPENDIENTE =====================

# Si se ejecuta directamente (no como source)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    auto_detect "${1:-run}"
fi
