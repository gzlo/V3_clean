#!/bin/bash
##
# Mocks para comandos del sistema usados en validation.sh
# tests/mocks/system_commands.sh
##

##
# Mock para comando command_exists
# Permite simular la existencia/ausencia de comandos
##
mock_command_exists() {
    local cmd="$1"
    
    # Lista de comandos que simulamos como disponibles
    case "$cmd" in
        bash|date|tar|gzip|find|sed|awk|grep|cut|sort|tr|head|tail|wc|chmod|chown|mkdir|rm|cp|mv|ln)
            return 0  # Comandos básicos siempre disponibles
            ;;
        curl|wget)
            return 0  # Comandos de red simulados como disponibles
            ;;
        mysql|mysqldump|pg_dump)
            # En modo test, simular que NO están disponibles para evitar ejecución real
            return 1
            ;;
        mail|sendmail)
            # Comandos de correo simulados como NO disponibles en test
            return 1
            ;;
        zstd|xz|bzip2)
            # Algunos comandos de compresión disponibles
            return 0
            ;;
        rsync|rclone|gpg|openssl|pv|parallel)
            # Comandos opcionales simulados como NO disponibles
            return 1
            ;;
        *)
            return 1  # Por defecto, comando no disponible
            ;;
    esac
}

##
# Mock para _get_command_version
# Simula versiones de comandos sin ejecutarlos realmente
##
mock_get_command_version() {
    local cmd="$1"
    
    case "$cmd" in
        bash)
            echo "5.1.8"
            ;;
        curl)
            echo "7.68.0"
            ;;
        wget)
            echo "1.20.3"
            ;;
        zstd)
            echo "1.4.5"
            ;;
        tar)
            echo "1.30"
            ;;
        gzip)
            echo "1.10"
            ;;
        *)
            echo ""  # No version available
            ;;
    esac
}

##
# Mock para validate_disk_space
# Simula verificación de espacio en disco sin acceso real al filesystem
##
mock_validate_disk_space() {
    local path="$1"
    local required_gb="$2"
    
    # Simular que directorios de test tienen espacio suficiente
    if [[ "$path" =~ /tmp ]] || [[ "$path" =~ $TEST_TEMP_DIR ]]; then
        if [[ "$required_gb" -lt 100 ]]; then
            return 0  # Espacio suficiente
        else
            return 1  # No hay espacio para requerimientos muy grandes
        fi
    fi
    
    # Directorios inexistentes fallan
    return 1
}

##
# Mock para validate_network_connectivity
# Simula verificación de conectividad sin hacer requests reales
##
mock_validate_network_connectivity() {
    local host="$1"
    local port="$2"
    
    # En modo test, simular que conexiones a hosts conocidos funcionan
    case "$host" in
        localhost|127.0.0.1|google.com|github.com)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

##
# Activar mocks sobrescribiendo funciones originales
##
activate_validation_mocks() {
    # Solo activar en modo test
    if [[ "${MOODLE_CLI_TEST_MODE:-}" == "true" ]]; then
        # Sobrescribir command_exists si no está ya definida como mock
        if ! declare -f command_exists | grep -q "mock_command_exists"; then
            eval "$(declare -f mock_command_exists)"
            alias command_exists='mock_command_exists'
        fi
        
        # Sobrescribir _get_command_version
        if ! declare -f _get_command_version | grep -q "mock_get_command_version"; then
            eval "$(declare -f mock_get_command_version)"
            _get_command_version() { mock_get_command_version "$@"; }
        fi
        
        # Crear función de bypass para comandos problemáticos
        mysql() { echo "mock mysql output"; }
        mysqldump() { echo "mock mysqldump output"; }
        mail() { echo "mock mail output"; }
        sendmail() { echo "mock sendmail output"; }
        
        export -f mysql mysqldump mail sendmail
        
        echo "[MOCK] Validation mocks activated" >&2
    fi
}

##
# Desactivar mocks
##
deactivate_validation_mocks() {
    unalias command_exists 2>/dev/null || true
    unset -f mysql mysqldump mail sendmail 2>/dev/null || true
    echo "[MOCK] Validation mocks deactivated" >&2
}
