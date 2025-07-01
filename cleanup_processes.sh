#!/bin/bash

# ===================== UTILIDAD DE LIMPIEZA DE PROCESOS COLGADOS =====================
# Script para limpiar procesos y lockfiles huérfanos del backup de Moodle
# Autor: Sistema Moodle Backup V3.1
# Fecha: 2025-07-01
# ===============================================================================

set -euo pipefail

# Cargar configuración del backup principal si está disponible
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/moodle_backup.conf"

if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    echo "ADVERTENCIA: No se encontró archivo de configuración, usando valores por defecto"
    CLIENT_NAME="moodle"
fi

# Configuración
SCRIPT_NAME="moodle_backup.sh"
LOCKFILE_BASE="/tmp/moodle_backup_${CLIENT_NAME}"
MAX_PROCESS_AGE=7200  # 2 horas en segundos
LOG_FILE="/tmp/moodle_backup_cleanup.log"

# Función de logging
log() {
    local level="$1"
    shift
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="[$timestamp] [$level] $*"
    
    echo "$message" | tee -a "$LOG_FILE"
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }

# Función principal de limpieza
cleanup_backup_processes() {
    log_info "=== INICIANDO LIMPIEZA DE PROCESOS COLGADOS ==="
    
    local found_issues=false
    
    # 1. Verificar y limpiar lockfiles huérfanos
    local process_lockfile="${LOCKFILE_BASE}.pid"
    
    if [[ -f "$process_lockfile" ]]; then
        local stored_pid
        stored_pid=$(cat "$process_lockfile" 2>/dev/null || echo "")
        
        if [[ -n "$stored_pid" ]] && [[ "$stored_pid" =~ ^[0-9]+$ ]]; then
            if kill -0 "$stored_pid" 2>/dev/null; then
                local process_cmd
                process_cmd=$(ps -p "$stored_pid" -o args= 2>/dev/null || echo "")
                
                if [[ "$process_cmd" == *"$SCRIPT_NAME"* ]]; then
                    # Verificar antigüedad
                    local process_start
                    process_start=$(ps -p "$stored_pid" -o lstart= 2>/dev/null || echo "")
                    
                    if [[ -n "$process_start" ]]; then
                        local process_epoch
                        process_epoch=$(date -d "$process_start" +%s 2>/dev/null || echo "0")
                        local current_epoch
                        current_epoch=$(date +%s)
                        local process_age=$((current_epoch - process_epoch))
                        
                        if [[ $process_age -gt $MAX_PROCESS_AGE ]]; then
                            log_warn "Eliminando proceso antiguo PID $stored_pid (edad: ${process_age}s)"
                            kill -TERM "$stored_pid" 2>/dev/null || true
                            sleep 5
                            if kill -0 "$stored_pid" 2>/dev/null; then
                                log_warn "Proceso resistente, forzando eliminación"
                                kill -KILL "$stored_pid" 2>/dev/null || true
                            fi
                            found_issues=true
                        else
                            log_info "Proceso válido encontrado (PID: $stored_pid, edad: ${process_age}s)"
                            return 1
                        fi
                    fi
                else
                    log_warn "PID $stored_pid no corresponde a backup, limpiando lockfile"
                    found_issues=true
                fi
            else
                log_info "Eliminando lockfile huérfano (PID $stored_pid no existe)"
                found_issues=true
            fi
        else
            log_warn "Lockfile corrupto, eliminando"
            found_issues=true
        fi
        
        if [[ "$found_issues" == "true" ]]; then
            rm -f "$process_lockfile" 2>/dev/null || true
            log_info "Lockfile eliminado: $process_lockfile"
        fi
    fi
    
    # 2. Buscar procesos huérfanos por comando
    local running_processes
    running_processes=$(pgrep -f "$SCRIPT_NAME" 2>/dev/null || true)
    
    if [[ -n "$running_processes" ]]; then
        log_info "Verificando procesos encontrados: $running_processes"
        
        for pid in $running_processes; do
            if kill -0 "$pid" 2>/dev/null; then
                local process_args
                process_args=$(ps -p "$pid" -o args= 2>/dev/null || echo "")
                
                # Excluir editores y visualizadores
                if [[ "$process_args" == *"$SCRIPT_NAME"* ]] && 
                   [[ "$process_args" != *"vi "* ]] && 
                   [[ "$process_args" != *"nano "* ]] && 
                   [[ "$process_args" != *"cat "* ]] && 
                   [[ "$process_args" != *"less "* ]] && 
                   [[ "$process_args" != *"cleanup_processes.sh"* ]]; then
                    
                    # Verificar antigüedad
                    local process_start
                    process_start=$(ps -p "$pid" -o lstart= 2>/dev/null || echo "")
                    
                    if [[ -n "$process_start" ]]; then
                        local process_epoch
                        process_epoch=$(date -d "$process_start" +%s 2>/dev/null || echo "0")
                        local current_epoch
                        current_epoch=$(date +%s)
                        local process_age=$((current_epoch - process_epoch))
                        
                        if [[ $process_age -gt $MAX_PROCESS_AGE ]]; then
                            log_warn "Eliminando proceso de backup antiguo (PID: $pid, edad: ${process_age}s)"
                            kill -TERM "$pid" 2>/dev/null || true
                            sleep 3
                            if kill -0 "$pid" 2>/dev/null; then
                                kill -KILL "$pid" 2>/dev/null || true
                            fi
                            found_issues=true
                        else
                            log_info "Proceso de backup válido ejecutándose (PID: $pid, edad: ${process_age}s)"
                        fi
                    fi
                fi
            fi
        done
    fi
    
    # 3. Limpiar otros archivos temporales relacionados
    local cleaned_files=0
    
    # Lockfiles antiguos
    for lockfile in /tmp/moodle_backup_${CLIENT_NAME}*.lock; do
        if [[ -f "$lockfile" ]]; then
            local file_age
            file_age=$(find "$lockfile" -mtime +1 2>/dev/null || echo "")
            if [[ -n "$file_age" ]]; then
                rm -f "$lockfile" 2>/dev/null || true
                ((cleaned_files++))
                log_info "Eliminado lockfile antiguo: $lockfile"
                found_issues=true
            fi
        fi
    done
    
    # Logs de sesión antiguos
    for session_log in /tmp/moodle_backup_session_${CLIENT_NAME}_*.log; do
        if [[ -f "$session_log" ]]; then
            local file_age
            file_age=$(find "$session_log" -mtime +1 2>/dev/null || echo "")
            if [[ -n "$file_age" ]]; then
                rm -f "$session_log" 2>/dev/null || true
                ((cleaned_files++))
                log_info "Eliminado log de sesión antiguo: $session_log"
                found_issues=true
            fi
        fi
    done
    
    # 4. Resumen
    if [[ "$found_issues" == "true" ]]; then
        log_info "✅ Limpieza completada - Se encontraron y corrigieron problemas"
        log_info "Archivos temporales limpiados: $cleaned_files"
    else
        log_info "✅ No se encontraron procesos colgados ni lockfiles huérfanos"
    fi
    
    log_info "=== FIN DE LIMPIEZA ==="
    return 0
}

# Función para mostrar ayuda
show_help() {
    cat << EOF
UTILIDAD DE LIMPIEZA - Moodle Backup V3.1

DESCRIPCIÓN:
    Limpia procesos colgados y lockfiles huérfanos del sistema de backup de Moodle.
    
USO:
    $0 [OPCIÓN]
    
OPCIONES:
    --help, -h      Mostrar esta ayuda
    --force, -f     Forzar eliminación de todos los procesos relacionados
    --status, -s    Mostrar estado actual sin hacer cambios
    --dry-run, -d   Mostrar lo que se haría sin ejecutar
    
EJEMPLOS:
    $0              # Limpieza normal (solo procesos >2h)
    $0 --status     # Ver estado actual
    $0 --force      # Eliminar todos los procesos relacionados
    
NOTAS:
    - Los procesos más nuevos de 2 horas se consideran válidos
    - Se excluyen editores de texto y visualizadores
    - Se crean logs en: $LOG_FILE
EOF
}

# Función para mostrar estado
show_status() {
    log_info "=== ESTADO ACTUAL DEL SISTEMA ==="
    
    # Procesos
    local running_processes
    running_processes=$(pgrep -f "$SCRIPT_NAME" 2>/dev/null || true)
    
    if [[ -n "$running_processes" ]]; then
        log_info "Procesos de backup encontrados:"
        for pid in $running_processes; do
            if kill -0 "$pid" 2>/dev/null; then
                local process_info
                process_info=$(ps -p "$pid" -o pid,ppid,lstart,etime,cmd 2>/dev/null || echo "PID $pid - información no disponible")
                log_info "  $process_info"
            fi
        done
    else
        log_info "No hay procesos de backup ejecutándose"
    fi
    
    # Lockfiles
    local lockfile_count=0
    for lockfile in /tmp/moodle_backup_${CLIENT_NAME}*; do
        if [[ -f "$lockfile" ]]; then
            log_info "Lockfile: $lockfile ($(ls -la "$lockfile" | awk '{print $6, $7, $8}'))"
            ((lockfile_count++))
        fi
    done
    
    if [[ $lockfile_count -eq 0 ]]; then
        log_info "No se encontraron lockfiles"
    fi
    
    log_info "=== FIN DE ESTADO ==="
}

# Función para forzar limpieza
force_cleanup() {
    log_warn "=== FORZANDO LIMPIEZA DE TODOS LOS PROCESOS ==="
    
    local running_processes
    running_processes=$(pgrep -f "$SCRIPT_NAME" 2>/dev/null || true)
    
    if [[ -n "$running_processes" ]]; then
        for pid in $running_processes; do
            if kill -0 "$pid" 2>/dev/null; then
                local process_args
                process_args=$(ps -p "$pid" -o args= 2>/dev/null || echo "")
                
                if [[ "$process_args" == *"$SCRIPT_NAME"* ]] && 
                   [[ "$process_args" != *"cleanup_processes.sh"* ]]; then
                    log_warn "Forzando eliminación de PID: $pid"
                    kill -TERM "$pid" 2>/dev/null || true
                    sleep 2
                    if kill -0 "$pid" 2>/dev/null; then
                        kill -KILL "$pid" 2>/dev/null || true
                    fi
                fi
            fi
        done
    fi
    
    # Limpiar todos los lockfiles
    rm -f /tmp/moodle_backup_${CLIENT_NAME}* 2>/dev/null || true
    
    log_warn "✅ Limpieza forzada completada"
}

# Procesamiento de argumentos
case "${1:-}" in
    --help|-h)
        show_help
        exit 0
        ;;
    --status|-s)
        show_status
        exit 0
        ;;
    --force|-f)
        force_cleanup
        exit 0
        ;;
    --dry-run|-d)
        log_info "MODO DRY-RUN: Mostrando acciones sin ejecutar"
        # Aquí podrías implementar una versión que solo muestre qué haría
        show_status
        exit 0
        ;;
    "")
        # Ejecución normal
        cleanup_backup_processes
        ;;
    *)
        echo "Opción no reconocida: $1"
        echo "Usa --help para ver las opciones disponibles"
        exit 1
        ;;
esac
