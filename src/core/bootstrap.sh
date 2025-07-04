#!/bin/bash
# ============================================================================
# Bootstrap Module - Sistema de Carga e Inicialización de Módulos
# ============================================================================
# 
# Este módulo maneja la carga ordenada y la inicialización de todos los
# módulos del sistema CLI de backup para Moodle.
#
# Funcionalidades principales:
# - Carga ordenada de dependencias
# - Inicialización de módulos core
# - Validación de prerrequisitos
# - Configuración del entorno
# - Manejo de errores de carga
#
# Autor: Sistema CLI Moodle Backup
# Versión: 2.0.0
# ============================================================================

# Guard para evitar carga múltiple
if [[ "${_BOOTSTRAP_LOADED:-}" == "true" ]]; then
    return 0
fi

# Solo marcar como readonly si no está en modo test
if [[ "${MOODLE_CLI_TEST_MODE:-}" != "true" ]]; then
    readonly _BOOTSTRAP_LOADED="true"
else
    _BOOTSTRAP_LOADED="true"
fi

# ============================================================================
# CONFIGURACIÓN Y CONSTANTES
# ============================================================================

# Rutas base del sistema
if [[ -z "${MOODLE_CLI_ROOT:-}" ]]; then
    # Detectar directorio raíz del proyecto
    if [[ -f "${BASH_SOURCE[0]}" ]]; then
        readonly MOODLE_CLI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    else
        readonly MOODLE_CLI_ROOT="$(pwd)"
    fi
fi

# Directorios principales
readonly BOOTSTRAP_LIB_DIR="${MOODLE_CLI_ROOT}/lib"
readonly BOOTSTRAP_SRC_DIR="${MOODLE_CLI_ROOT}/src"
readonly BOOTSTRAP_CONFIG_DIR="${MOODLE_CLI_ROOT}/config"

# Estados de carga de módulos
if [[ "${MOODLE_CLI_TEST_MODE:-}" == "true" ]]; then
    # En modo test, permitir redeclaración
    declare -gA BOOTSTRAP_MODULE_STATUS 2>/dev/null || true
    declare -gA BOOTSTRAP_MODULE_DEPENDENCIES 2>/dev/null || true
else
    # En modo normal, usar declaración estándar
    declare -A BOOTSTRAP_MODULE_STATUS
    declare -A BOOTSTRAP_MODULE_DEPENDENCIES
fi

# Lista ordenada de módulos core
readonly BOOTSTRAP_CORE_MODULES=(
    "constants"
    "colors" 
    "utils"
    "filesystem"
    "logging"
    "config"
    "validation"
    "process"
)

# ============================================================================
# FUNCIONES DE CARGA DE LIBRERÍAS BASE
# ============================================================================

#
# Carga una librería base desde lib/
# 
# Argumentos:
#   $1 - Nombre de la librería (sin extensión .sh)
#
# Retorna:
#   0 - Éxito
#   1 - Error de carga
#
bootstrap_load_library() {
    local lib_name="$1"
    local lib_path="${BOOTSTRAP_LIB_DIR}/${lib_name}.sh"
    
    if [[ -z "$lib_name" ]]; then
        echo "ERROR: Nombre de librería requerido" >&2
        return 1
    fi
    
    if [[ ! -f "$lib_path" ]]; then
        echo "ERROR: Librería no encontrada: $lib_path" >&2
        return 1
    fi
    
    # Verificar si ya está cargada
    if [[ "${BOOTSTRAP_MODULE_STATUS[$lib_name]:-}" == "loaded" ]]; then
        return 0
    fi
    
    # Cargar la librería
    if source "$lib_path"; then
        BOOTSTRAP_MODULE_STATUS["$lib_name"]="loaded"
        return 0
    else
        echo "ERROR: Fallo al cargar librería: $lib_name" >&2
        BOOTSTRAP_MODULE_STATUS["$lib_name"]="error"
        return 1
    fi
}

#
# Carga un módulo core desde src/core/
#
# Argumentos:
#   $1 - Nombre del módulo (sin extensión .sh)
#
# Retorna:
#   0 - Éxito
#   1 - Error de carga
#
bootstrap_load_core_module() {
    local module_name="$1"
    local module_path="${BOOTSTRAP_SRC_DIR}/core/${module_name}.sh"
    
    if [[ -z "$module_name" ]]; then
        echo "ERROR: Nombre de módulo requerido" >&2
        return 1
    fi
    
    if [[ ! -f "$module_path" ]]; then
        echo "ERROR: Módulo no encontrado: $module_path" >&2
        return 1
    fi
    
    # Verificar si ya está cargado
    if [[ "${BOOTSTRAP_MODULE_STATUS[$module_name]:-}" == "loaded" ]]; then
        return 0
    fi
    
    # Cargar el módulo
    if source "$module_path"; then
        BOOTSTRAP_MODULE_STATUS["$module_name"]="loaded"
        return 0
    else
        echo "ERROR: Fallo al cargar módulo: $module_name" >&2
        BOOTSTRAP_MODULE_STATUS["$module_name"]="error"
        return 1
    fi
}

# ============================================================================
# FUNCIONES DE INICIALIZACIÓN ORDENADA
# ============================================================================

#
# Inicializa las librerías base en orden correcto
#
# Retorna:
#   0 - Éxito
#   1 - Error en la inicialización
#
bootstrap_init_libraries() {
    local lib_order=("constants" "colors" "utils" "filesystem")
    
    for lib in "${lib_order[@]}"; do
        if ! bootstrap_load_library "$lib"; then
            echo "ERROR: Fallo crítico cargando librería base: $lib" >&2
            return 1
        fi
    done
    
    return 0
}

#
# Inicializa los módulos core en orden correcto
#
# Retorna:
#   0 - Éxito
#   1 - Error en la inicialización
#
bootstrap_init_core_modules() {
    local core_order=("logging" "config" "validation" "process")
    
    for module in "${core_order[@]}"; do
        if ! bootstrap_load_core_module "$module"; then
            echo "ERROR: Fallo crítico cargando módulo core: $module" >&2
            return 1
        fi
    done
    
    return 0
}

#
# Inicializa el sistema de logging una vez cargado
#
# Retorna:
#   0 - Éxito
#   1 - Error en la inicialización
#
bootstrap_init_logging_system() {
    # Verificar que el módulo de logging esté cargado
    if [[ "${BOOTSTRAP_MODULE_STATUS[logging]:-}" != "loaded" ]]; then
        echo "ERROR: Módulo de logging no cargado" >&2
        return 1
    fi
    
    # Inicializar logging con configuración básica
    if command -v log_init >/dev/null 2>&1; then
        log_init || return 1
    fi
    
    return 0
}

#
# Inicializa el sistema de configuración
#
# Retorna:
#   0 - Éxito
#   1 - Error en la inicialización
#
bootstrap_init_config_system() {
    # Verificar que el módulo de config esté cargado
    if [[ "${BOOTSTRAP_MODULE_STATUS[config]:-}" != "loaded" ]]; then
        echo "ERROR: Módulo de configuración no cargado" >&2
        return 1
    fi
    
    # Cargar configuración por defecto
    local default_config="${BOOTSTRAP_CONFIG_DIR}/defaults.conf"
    if [[ -f "$default_config" ]] && command -v config_load >/dev/null 2>&1; then
        config_load "$default_config" || return 1
    fi
    
    return 0
}

# ============================================================================
# FUNCIONES DE VALIDACIÓN DE PRERREQUISITOS
# ============================================================================

#
# Valida que el entorno sea adecuado para el bootstrap
#
# Retorna:
#   0 - Entorno válido
#   1 - Entorno inválido
#
bootstrap_validate_environment() {
    # Verificar que estamos en bash
    if [[ -z "${BASH_VERSION:-}" ]]; then
        echo "ERROR: Se requiere Bash para ejecutar este sistema" >&2
        return 1
    fi
    
    # Verificar versión mínima de bash (4.0+)
    if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
        echo "ERROR: Se requiere Bash 4.0 o superior" >&2
        return 1
    fi
    
    # Verificar estructura de directorios
    local required_dirs=("$BOOTSTRAP_LIB_DIR" "$BOOTSTRAP_SRC_DIR" "$BOOTSTRAP_CONFIG_DIR")
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            echo "ERROR: Directorio requerido no encontrado: $dir" >&2
            return 1
        fi
    done
    
    return 0
}

#
# Valida que todas las librerías base estén disponibles
#
# Retorna:
#   0 - Todas las librerías disponibles
#   1 - Librerías faltantes
#
bootstrap_validate_libraries() {
    local required_libs=("constants" "colors" "utils" "filesystem")
    local missing_libs=()
    
    for lib in "${required_libs[@]}"; do
        local lib_path="${BOOTSTRAP_LIB_DIR}/${lib}.sh"
        if [[ ! -f "$lib_path" ]]; then
            missing_libs+=("$lib")
        fi
    done
    
    if [[ ${#missing_libs[@]} -gt 0 ]]; then
        echo "ERROR: Librerías base faltantes: ${missing_libs[*]}" >&2
        return 1
    fi
    
    return 0
}

#
# Valida que todos los módulos core estén disponibles
#
# Retorna:
#   0 - Todos los módulos disponibles
#   1 - Módulos faltantes
#
bootstrap_validate_core_modules() {
    local required_modules=("logging" "config" "validation" "process")
    local missing_modules=()
    
    for module in "${required_modules[@]}"; do
        local module_path="${BOOTSTRAP_SRC_DIR}/core/${module}.sh"
        if [[ ! -f "$module_path" ]]; then
            missing_modules+=("$module")
        fi
    done
    
    if [[ ${#missing_modules[@]} -gt 0 ]]; then
        echo "ERROR: Módulos core faltantes: ${missing_modules[*]}" >&2
        return 1
    fi
    
    return 0
}

# ============================================================================
# FUNCIONES DE DIAGNÓSTICO Y DEBUG
# ============================================================================

#
# Muestra el estado actual de todos los módulos
#
bootstrap_show_status() {
    echo "=== Estado del Sistema Bootstrap ==="
    echo "Directorio raíz: $MOODLE_CLI_ROOT"
    echo "Directorio lib: $BOOTSTRAP_LIB_DIR"
    echo "Directorio src: $BOOTSTRAP_SRC_DIR"
    echo "Directorio config: $BOOTSTRAP_CONFIG_DIR"
    echo ""
    
    echo "Estado de módulos:"
    for module in "${BOOTSTRAP_CORE_MODULES[@]}"; do
        local status="${BOOTSTRAP_MODULE_STATUS[$module]:-not_loaded}"
        printf "  %-15s: %s\n" "$module" "$status"
    done
}

#
# Lista todos los archivos de módulos disponibles
#
bootstrap_list_available_modules() {
    echo "=== Módulos Disponibles ==="
    
    echo "Librerías base (lib/):"
    if [[ -d "$BOOTSTRAP_LIB_DIR" ]]; then
        find "$BOOTSTRAP_LIB_DIR" -name "*.sh" -type f | sort | while read -r file; do
            local basename=$(basename "$file" .sh)
            echo "  - $basename"
        done
    fi
    
    echo ""
    echo "Módulos core (src/core/):"
    if [[ -d "${BOOTSTRAP_SRC_DIR}/core" ]]; then
        find "${BOOTSTRAP_SRC_DIR}/core" -name "*.sh" -type f | sort | while read -r file; do
            local basename=$(basename "$file" .sh)
            echo "  - $basename"
        done
    fi
}

# ============================================================================
# FUNCIÓN PRINCIPAL DE BOOTSTRAP
# ============================================================================

#
# Ejecuta el proceso completo de bootstrap del sistema
#
# Argumentos:
#   $1 - Modo de operación (optional): "verbose", "quiet", "debug"
#
# Retorna:
#   0 - Bootstrap exitoso
#   1 - Error en el bootstrap
#
bootstrap_init() {
    local mode="${1:-normal}"
    local verbose=false
    
    if [[ "$mode" == "verbose" || "$mode" == "debug" ]]; then
        verbose=true
    fi
    
    # Fase 1: Validación del entorno
    if [[ "$verbose" == "true" ]]; then
        echo "Bootstrap: Validando entorno..."
    fi
    
    if ! bootstrap_validate_environment; then
        echo "ERROR: Validación del entorno falló" >&2
        return 1
    fi
    
    # Fase 2: Validación de archivos
    if [[ "$verbose" == "true" ]]; then
        echo "Bootstrap: Validando archivos de módulos..."
    fi
    
    if ! bootstrap_validate_libraries || ! bootstrap_validate_core_modules; then
        echo "ERROR: Validación de archivos falló" >&2
        return 1
    fi
    
    # Fase 3: Carga de librerías base
    if [[ "$verbose" == "true" ]]; then
        echo "Bootstrap: Cargando librerías base..."
    fi
    
    if ! bootstrap_init_libraries; then
        echo "ERROR: Carga de librerías base falló" >&2
        return 1
    fi
    
    # Fase 4: Carga de módulos core
    if [[ "$verbose" == "true" ]]; then
        echo "Bootstrap: Cargando módulos core..."
    fi
    
    if ! bootstrap_init_core_modules; then
        echo "ERROR: Carga de módulos core falló" >&2
        return 1
    fi
    
    # Fase 5: Inicialización de sistemas
    if [[ "$verbose" == "true" ]]; then
        echo "Bootstrap: Inicializando sistemas..."
    fi
    
    if ! bootstrap_init_logging_system; then
        echo "ERROR: Inicialización del sistema de logging falló" >&2
        return 1
    fi
    
    if ! bootstrap_init_config_system; then
        echo "ERROR: Inicialización del sistema de configuración falló" >&2
        return 1
    fi
    
    # Éxito
    if [[ "$verbose" == "true" ]]; then
        echo "Bootstrap: Inicialización completada exitosamente"
        if [[ "$mode" == "debug" ]]; then
            bootstrap_show_status
        fi
    fi
    
    return 0
}

#
# Función de limpieza para tests y re-inicialización
#
bootstrap_cleanup() {
    # Limpiar estado de módulos
    for module in "${!BOOTSTRAP_MODULE_STATUS[@]}"; do
        unset BOOTSTRAP_MODULE_STATUS["$module"]
    done
    
    # Limpiar dependencias
    for module in "${!BOOTSTRAP_MODULE_DEPENDENCIES[@]}"; do
        unset BOOTSTRAP_MODULE_DEPENDENCIES["$module"]
    done
}

# ============================================================================
# FUNCIONES DE UTILIDAD PARA MÓDULOS EXTERNOS
# ============================================================================

#
# Verifica si un módulo específico está cargado
#
# Argumentos:
#   $1 - Nombre del módulo
#
# Retorna:
#   0 - Módulo cargado
#   1 - Módulo no cargado
#
bootstrap_is_module_loaded() {
    local module_name="$1"
    
    if [[ -z "$module_name" ]]; then
        return 1
    fi
    
    [[ "${BOOTSTRAP_MODULE_STATUS[$module_name]:-}" == "loaded" ]]
}

#
# Obtiene la lista de módulos cargados
#
bootstrap_get_loaded_modules() {
    local loaded_modules=()
    
    for module in "${!BOOTSTRAP_MODULE_STATUS[@]}"; do
        if [[ "${BOOTSTRAP_MODULE_STATUS[$module]}" == "loaded" ]]; then
            loaded_modules+=("$module")
        fi
    done
    
    printf '%s\n' "${loaded_modules[@]}"
}

#
# Carga un módulo específico con sus dependencias
#
# Argumentos:
#   $1 - Nombre del módulo
#   $2 - Tipo (library|core) - opcional, se detecta automáticamente
#
# Retorna:
#   0 - Módulo cargado exitosamente
#   1 - Error al cargar el módulo
#
bootstrap_load_module() {
    local module_name="$1"
    local module_type="${2:-auto}"
    
    if [[ -z "$module_name" ]]; then
        echo "ERROR: Nombre de módulo requerido" >&2
        return 1
    fi
    
    # Si ya está cargado, no hacer nada
    if bootstrap_is_module_loaded "$module_name"; then
        return 0
    fi
    
    # Detectar tipo si es auto
    if [[ "$module_type" == "auto" ]]; then
        if [[ -f "${BOOTSTRAP_LIB_DIR}/${module_name}.sh" ]]; then
            module_type="library"
        elif [[ -f "${BOOTSTRAP_SRC_DIR}/core/${module_name}.sh" ]]; then
            module_type="core"
        else
            echo "ERROR: No se pudo detectar el tipo de módulo: $module_name" >&2
            return 1
        fi
    fi
    
    # Cargar según el tipo
    case "$module_type" in
        "library")
            bootstrap_load_library "$module_name"
            ;;
        "core")
            bootstrap_load_core_module "$module_name"
            ;;
        *)
            echo "ERROR: Tipo de módulo desconocido: $module_type" >&2
            return 1
            ;;
    esac
}

# ============================================================================
# EXPORTACIÓN DE FUNCIONES PÚBLICAS
# ============================================================================

# Las funciones principales que otros módulos pueden usar:
# - bootstrap_init
# - bootstrap_is_module_loaded
# - bootstrap_get_loaded_modules
# - bootstrap_load_module
# - bootstrap_show_status
# - bootstrap_list_available_modules
# - bootstrap_cleanup (solo para tests)
