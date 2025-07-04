#!/bin/bash

##
# Sistema de Manejo de Procesos y Señales - Moodle Backup CLI
# Versión: 1.0.0
#
# Proporciona gestión avanzada de procesos, lockfiles, señales
# y limpieza automática para prevenir ejecuciones concurrentes
##

# Guard para evitar carga múltiple
[[ "${MOODLE_BACKUP_PROCESS_LOADED:-}" == "true" ]] && return 0
export MOODLE_BACKUP_PROCESS_LOADED="true"

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

# ===================== CONFIGURACIÓN DE PROCESOS =====================

# Archivos de control
PROCESS_LOCK_DIR="${PROCESS_LOCK_DIR:-${TEST_TEMP_DIR:-/tmp}/moodle-backup-locks}"
PROCESS_PID_FILE="${PROCESS_PID_FILE:-$PROCESS_LOCK_DIR/moodle-backup.pid}"
PROCESS_LOCK_FILE="${PROCESS_LOCK_FILE:-$PROCESS_LOCK_DIR/moodle-backup.lock}"
PROCESS_STATUS_FILE="${PROCESS_STATUS_FILE:-$PROCESS_LOCK_DIR/moodle-backup.status}"

# Configuración de timeouts
PROCESS_LOCK_TIMEOUT="${PROCESS_LOCK_TIMEOUT:-300}"  # 5 minutos
PROCESS_STALE_TIMEOUT="${PROCESS_STALE_TIMEOUT:-3600}"  # 1 hora
PROCESS_CLEANUP_INTERVAL="${PROCESS_CLEANUP_INTERVAL:-60}"  # 1 minuto

# Estado del proceso
PROCESS_STARTED=false
PROCESS_CLEANUP_REGISTERED=false
PROCESS_SIGNALS_TRAPPED=false

# Funciones de cleanup registradas
declare -a CLEANUP_FUNCTIONS=()

# PIDs de procesos hijos
declare -a CHILD_PIDS=()

# ===================== FUNCIONES PRIVADAS =====================

##
# Crea el directorio de locks si no existe
##
_ensure_lock_directory() {
    [[ -d "$PROCESS_LOCK_DIR" ]] || mkdir -p "$PROCESS_LOCK_DIR" 2>/dev/null || {
        log_error "No se puede crear directorio de locks: $PROCESS_LOCK_DIR"
        return 1
    }
}

##
# Obtiene información del proceso desde PID file
# @param $1 string Archivo PID
# @return string "pid:user:command" o vacío si no es válido
##
_get_process_info() {
    local pid_file="$1"
    
    [[ -f "$pid_file" ]] || return 1
    
    local pid
    pid=$(cat "$pid_file" 2>/dev/null)
    [[ "$pid" =~ ^[0-9]+$ ]] || return 1
    
    # Verificar si el proceso existe
    if ! kill -0 "$pid" 2>/dev/null; then
        return 1
    fi
    
    # Obtener información del proceso
    local user command
    if [[ -f "/proc/$pid/comm" ]]; then
        command=$(cat "/proc/$pid/comm" 2>/dev/null || echo "unknown")
        user=$(stat -c %U "/proc/$pid" 2>/dev/null || echo "unknown")
    else
        # macOS/BSD fallback
        command=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")
        user=$(ps -p "$pid" -o user= 2>/dev/null || echo "unknown")
    fi
    
    echo "$pid:$user:$command"
}

##
# Verifica si un lockfile está obsoleto
# @param $1 string Archivo de lock
# @return int 0 si está obsoleto
##
_is_stale_lock() {
    local lock_file="$1"
    
    [[ -f "$lock_file" ]] || return 1
    
    local lock_age
    lock_age=$(stat -c %Y "$lock_file" 2>/dev/null || stat -f %m "$lock_file" 2>/dev/null)
    [[ -n "$lock_age" ]] || return 1
    
    local current_time
    current_time=$(date +%s)
    local age_seconds=$((current_time - lock_age))
    
    (( age_seconds > PROCESS_STALE_TIMEOUT ))
}

##
# Mata procesos hijos recursivamente
# @param $1 int PID del proceso padre
##
_kill_child_processes() {
    local parent_pid="$1"
    
    [[ "$parent_pid" =~ ^[0-9]+$ ]] || return 1
    
    # Obtener PIDs de procesos hijos
    local child_pids
    if command_exists "pgrep"; then
        child_pids=$(pgrep -P "$parent_pid" 2>/dev/null || true)
    elif [[ -d "/proc" ]]; then
        child_pids=$(ps --no-headers -o pid --ppid="$parent_pid" 2>/dev/null || true)
    else
        # macOS/BSD fallback
        child_pids=$(ps -o pid= --ppid="$parent_pid" 2>/dev/null || true)
    fi
    
    # Matar procesos hijos recursivamente
    for child_pid in $child_pids; do
        [[ "$child_pid" =~ ^[0-9]+$ ]] || continue
        log_debug "Matando proceso hijo: $child_pid"
        _kill_child_processes "$child_pid"
        kill -TERM "$child_pid" 2>/dev/null || true
    done
    
    # Esperar un poco antes de force kill
    sleep 1
    
    # Force kill si aún están vivos
    for child_pid in $child_pids; do
        [[ "$child_pid" =~ ^[0-9]+$ ]] || continue
        if kill -0 "$child_pid" 2>/dev/null; then
            log_debug "Force killing proceso hijo: $child_pid"
            kill -KILL "$child_pid" 2>/dev/null || true
        fi
    done
}

##
# Handler de señales de interrupción
##
_signal_handler() {
    local signal="$1"
    
    log_warn "Señal $signal recibida, iniciando limpieza..."
    
    # Marcar que estamos en proceso de limpieza
    process_set_status "INTERRUPTED" "$signal"
    
    # Ejecutar limpieza
    process_cleanup
    
    # Exit con código apropiado
    case "$signal" in
        INT|TERM) exit $EXIT_INTERRUPTED ;;
        *) exit $EXIT_ERROR ;;
    esac
}

# ===================== FUNCIONES PÚBLICAS =====================

##
# Inicializa el sistema de gestión de procesos
# @param $1 string Nombre del proceso (opcional)
# @return int 0 si es exitoso
##
process_init() {
    local process_name="${1:-moodle-backup}"
    
    log_debug "Inicializando gestión de procesos para '$process_name'"
    
    # Actualizar rutas con nombre del proceso
    PROCESS_PID_FILE="$PROCESS_LOCK_DIR/${process_name}.pid"
    PROCESS_LOCK_FILE="$PROCESS_LOCK_DIR/${process_name}.lock"
    PROCESS_STATUS_FILE="$PROCESS_LOCK_DIR/${process_name}.status"
    
    # Crear directorio de locks
    _ensure_lock_directory || return 1
    
    # Registrar traps de señales si no están registrados
    if [[ "$PROCESS_SIGNALS_TRAPPED" != "true" ]]; then
        trap '_signal_handler INT' INT
        trap '_signal_handler TERM' TERM
        trap '_signal_handler HUP' HUP 2>/dev/null || true
        trap '_signal_handler QUIT' QUIT 2>/dev/null || true
        PROCESS_SIGNALS_TRAPPED=true
        log_debug "Traps de señales registrados"
    fi
    
    # Registrar cleanup automático
    if [[ "$PROCESS_CLEANUP_REGISTERED" != "true" ]]; then
        trap 'process_cleanup' EXIT
        PROCESS_CLEANUP_REGISTERED=true
        log_debug "Cleanup automático registrado"
    fi
    
    PROCESS_STARTED=true
    return 0
}

##
# Adquiere un lock exclusivo
# @param $1 int Timeout en segundos (opcional)
# @return int 0 si el lock se adquiere exitosamente
##
process_acquire_lock() {
    local timeout="${1:-$PROCESS_LOCK_TIMEOUT}"
    local current_pid=$$
    
    _ensure_lock_directory || return 1
    
    log_debug "Intentando adquirir lock: $PROCESS_LOCK_FILE"
    
    local attempts=0
    local max_attempts=$((timeout / 5))
    [[ $max_attempts -lt 1 ]] && max_attempts=1
    
    while (( attempts < max_attempts )); do
        # Verificar si ya tenemos el lock
        if [[ -f "$PROCESS_LOCK_FILE" ]]; then
            local existing_pid
            existing_pid=$(cat "$PROCESS_LOCK_FILE" 2>/dev/null)
            
            if [[ "$existing_pid" == "$current_pid" ]]; then
                log_debug "Ya tenemos el lock"
                return 0
            fi
            
            # Verificar si el proceso existente está vivo
            local process_info
            if process_info=$(_get_process_info "$PROCESS_PID_FILE"); then
                local existing_pid_check user command
                IFS=':' read -r existing_pid_check user command <<< "$process_info"
                
                if [[ "$existing_pid_check" == "$existing_pid" ]]; then
                    log_warn "Proceso $existing_pid ($user:$command) ya está ejecutándose"
                    ((attempts++))
                    sleep 5
                    continue
                fi
            fi
            
            # Lock obsoleto, limpiarlo
            if _is_stale_lock "$PROCESS_LOCK_FILE"; then
                log_warn "Removiendo lock obsoleto"
                process_release_lock
            else
                log_warn "Lock activo, esperando... (intento $((attempts + 1))/$max_attempts)"
                ((attempts++))
                sleep 5
                continue
            fi
        fi
        
        # Intentar adquirir el lock atómicamente
        if (
            set -C  # noclobber
            echo "$current_pid" > "$PROCESS_LOCK_FILE" 2>/dev/null
        ); then
            # Escribir PID file
            echo "$current_pid" > "$PROCESS_PID_FILE"
            
            # Establecer estado inicial
            process_set_status "RUNNING" "Lock adquirido"
            
            log_info "Lock adquirido exitosamente (PID: $current_pid)"
            return 0
        fi
        
        ((attempts++))
        sleep 5
    done
    
    log_error "No se pudo adquirir el lock después de $timeout segundos"
    return 1
}

##
# Libera el lock actual
##
process_release_lock() {
    local current_pid=$$
    
    # Verificar que tengamos el lock
    if [[ -f "$PROCESS_LOCK_FILE" ]]; then
        local lock_pid
        lock_pid=$(cat "$PROCESS_LOCK_FILE" 2>/dev/null)
        
        if [[ "$lock_pid" != "$current_pid" ]]; then
            log_warn "Intentando liberar lock que no nos pertenece (PID: $lock_pid)"
        fi
    fi
    
    # Remover archivos de control
    rm -f "$PROCESS_LOCK_FILE" "$PROCESS_PID_FILE" "$PROCESS_STATUS_FILE" 2>/dev/null
    
    log_debug "Lock liberado"
}

##
# Establece el estado del proceso
# @param $1 string Estado (RUNNING, COMPLETED, ERROR, INTERRUPTED)
# @param $2 string Mensaje adicional (opcional)
##
process_set_status() {
    local status="$1"
    local message="${2:-}"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    local status_line="$timestamp|$$|$status|$message"
    echo "$status_line" >> "$PROCESS_STATUS_FILE" 2>/dev/null || true
    
    log_debug "Estado del proceso: $status - $message"
}

##
# Obtiene el estado actual del proceso
# @return string Última línea de estado
##
process_get_status() {
    [[ -f "$PROCESS_STATUS_FILE" ]] || {
        echo "UNKNOWN||No status file"
        return 1
    }
    
    tail -n1 "$PROCESS_STATUS_FILE" 2>/dev/null || echo "ERROR||Cannot read status file"
}

##
# Registra una función de cleanup para ejecutar al salir
# @param $1 string Nombre de la función
##
process_register_cleanup() {
    local cleanup_function="$1"
    
    [[ -n "$cleanup_function" ]] || {
        log_error "process_register_cleanup: función vacía"
        return 1
    }
    
    # Verificar que la función existe
    if ! declare -f "$cleanup_function" >/dev/null; then
        log_error "Función de cleanup no existe: $cleanup_function"
        return 1
    fi
    
    CLEANUP_FUNCTIONS+=("$cleanup_function")
    log_debug "Función de cleanup registrada: $cleanup_function"
}

##
# Registra un PID de proceso hijo para seguimiento
# @param $1 int PID del proceso hijo
##
process_register_child() {
    local child_pid="$1"
    
    [[ "$child_pid" =~ ^[0-9]+$ ]] || {
        log_error "PID inválido: $child_pid"
        return 1
    }
    
    CHILD_PIDS+=("$child_pid")
    log_debug "Proceso hijo registrado: $child_pid"
}

##
# Espera a que todos los procesos hijos terminen
# @param $1 int Timeout en segundos (opcional)
# @return int 0 si todos terminaron exitosamente
##
process_wait_children() {
    local timeout="${1:-30}"
    local start_time
    start_time=$(date +%s)
    
    [[ ${#CHILD_PIDS[@]} -eq 0 ]] && {
        log_debug "No hay procesos hijos que esperar"
        return 0
    }
    
    log_info "Esperando a ${#CHILD_PIDS[@]} procesos hijos..."
    
    local remaining_pids=("${CHILD_PIDS[@]}")
    
    while [[ ${#remaining_pids[@]} -gt 0 ]]; do
        local current_time
        current_time=$(date +%s)
        
        if (( current_time - start_time > timeout )); then
            log_warn "Timeout esperando procesos hijos, forzando terminación"
            
            for pid in "${remaining_pids[@]}"; do
                log_warn "Matando proceso hijo: $pid"
                kill -TERM "$pid" 2>/dev/null || true
            done
            
            sleep 2
            
            for pid in "${remaining_pids[@]}"; do
                if kill -0 "$pid" 2>/dev/null; then
                    log_warn "Force killing proceso hijo: $pid"
                    kill -KILL "$pid" 2>/dev/null || true
                fi
            done
            
            return 1
        fi
        
        # Revisar cuáles procesos aún están vivos
        local new_remaining=()
        for pid in "${remaining_pids[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                new_remaining+=("$pid")
            else
                log_debug "Proceso hijo $pid terminó"
            fi
        done
        
        remaining_pids=("${new_remaining[@]}")
        
        [[ ${#remaining_pids[@]} -gt 0 ]] && sleep 1
    done
    
    log_info "Todos los procesos hijos terminaron exitosamente"
    CHILD_PIDS=()
    return 0
}

##
# Ejecuta limpieza completa del proceso
##
process_cleanup() {
    [[ "$PROCESS_STARTED" != "true" ]] && return 0
    
    log_debug "Ejecutando limpieza del proceso"
    
    # Establecer estado de limpieza
    process_set_status "CLEANING" "Ejecutando limpieza"
    
    # Ejecutar funciones de cleanup registradas
    for cleanup_func in "${CLEANUP_FUNCTIONS[@]}"; do
        log_debug "Ejecutando cleanup: $cleanup_func"
        if declare -f "$cleanup_func" >/dev/null; then
            "$cleanup_func" 2>/dev/null || log_warn "Error en cleanup: $cleanup_func"
        fi
    done
    
    # Matar procesos hijos
    if [[ ${#CHILD_PIDS[@]} -gt 0 ]]; then
        log_info "Terminando ${#CHILD_PIDS[@]} procesos hijos"
        for pid in "${CHILD_PIDS[@]}"; do
            [[ "$pid" =~ ^[0-9]+$ ]] || continue
            _kill_child_processes "$pid"
        done
        CHILD_PIDS=()
    fi
    
    # Liberar lock
    process_release_lock
    
    # Marcar limpieza completada
    PROCESS_STARTED=false
    log_debug "Limpieza del proceso completada"
}

##
# Muestra información de procesos activos
##
process_status_report() {
    echo "=== ESTADO DE PROCESOS MOODLE BACKUP ==="
    echo
    
    if [[ ! -d "$PROCESS_LOCK_DIR" ]]; then
        echo "No hay directorio de locks: $PROCESS_LOCK_DIR"
        return 0
    fi
    
    local lock_files
    lock_files=$(find "$PROCESS_LOCK_DIR" -name "*.lock" 2>/dev/null || true)
    
    if [[ -z "$lock_files" ]]; then
        echo "No hay procesos activos"
        return 0
    fi
    
    echo "Procesos activos:"
    echo
    
    while IFS= read -r lock_file; do
        [[ -f "$lock_file" ]] || continue
        
        local process_name
        process_name=$(basename "$lock_file" .lock)
        
        local pid_file="$PROCESS_LOCK_DIR/${process_name}.pid"
        local status_file="$PROCESS_LOCK_DIR/${process_name}.status"
        
        echo "Proceso: $process_name"
        
        if [[ -f "$pid_file" ]]; then
            local process_info
            if process_info=$(_get_process_info "$pid_file"); then
                local pid user command
                IFS=':' read -r pid user command <<< "$process_info"
                echo "  PID: $pid"
                echo "  Usuario: $user"
                echo "  Comando: $command"
                
                # Tiempo de ejecución
                local start_time
                start_time=$(stat -c %Y "$pid_file" 2>/dev/null || stat -f %m "$pid_file" 2>/dev/null)
                if [[ -n "$start_time" ]]; then
                    local current_time
                    current_time=$(date +%s)
                    local runtime=$((current_time - start_time))
                    echo "  Tiempo ejecución: $(format_duration $runtime)"
                fi
            else
                echo "  Estado: STALE (proceso no existe)"
            fi
        fi
        
        if [[ -f "$status_file" ]]; then
            local last_status
            last_status=$(tail -n1 "$status_file" 2>/dev/null)
            if [[ -n "$last_status" ]]; then
                local timestamp status message
                IFS='|' read -r timestamp pid status message <<< "$last_status"
                echo "  Último estado: $status ($timestamp)"
                [[ -n "$message" ]] && echo "  Mensaje: $message"
            fi
        fi
        
        echo
    done <<< "$lock_files"
}

##
# Limpia locks obsoletos y procesos zombi
##
process_cleanup_stale() {
    log_info "Limpiando locks obsoletos"
    
    [[ -d "$PROCESS_LOCK_DIR" ]] || return 0
    
    local cleaned=0
    
    # Buscar archivos de lock
    while IFS= read -r lock_file; do
        [[ -f "$lock_file" ]] || continue
        
        local process_name
        process_name=$(basename "$lock_file" .lock)
        local pid_file="$PROCESS_LOCK_DIR/${process_name}.pid"
        
        # Verificar si el proceso está vivo
        if ! _get_process_info "$pid_file" >/dev/null 2>&1; then
            log_info "Removiendo lock obsoleto: $process_name"
            rm -f "$lock_file" "$pid_file" "$PROCESS_LOCK_DIR/${process_name}.status" 2>/dev/null
            ((cleaned++))
        elif _is_stale_lock "$lock_file"; then
            log_warn "Removiendo lock muy antiguo: $process_name"
            rm -f "$lock_file" "$pid_file" "$PROCESS_LOCK_DIR/${process_name}.status" 2>/dev/null
            ((cleaned++))
        fi
        
    done < <(find "$PROCESS_LOCK_DIR" -name "*.lock" 2>/dev/null || true)
    
    if (( cleaned > 0 )); then
        log_info "Limpiados $cleaned locks obsoletos"
    else
        log_debug "No se encontraron locks obsoletos"
    fi
    
    return 0
}
