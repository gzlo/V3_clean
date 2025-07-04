#!/bin/bash

##
# Propuesta de solución arquitectural para config.sh compatible con BATS
# 
# PROBLEMA: Los arrays asociativos no se comparten entre setup() y tests en BATS
# SOLUCIÓN: Usar un enfoque híbrido con funciones de inicialización y reset limpias
##

# En lugar de arrays globales, usar funciones que inicialicen los arrays localmente
# pero de manera consistente y testeable

##
# Inicializa el sistema de configuración
# Esta función debe ser llamada al inicio de cada test o al cargar el módulo
##
config_init() {
    # Solo inicializar si no está ya inicializado
    [[ "${MOODLE_CONFIG_INITIALIZED:-}" == "true" ]] && return 0
    
    # Declarar arrays en el contexto actual
    declare -gA CONFIG_VALUES=()
    declare -gA CONFIG_DEFAULTS=(
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
        
        # Database
        ["DB_BACKUP_ENABLED"]="true"
        ["DB_COMPRESSION"]="true"
        ["DB_TIMEOUT"]="1800"
        
        # ... resto de configuración ...
    )
    
    # Inicializar CONFIG_VALUES con defaults
    for key in "${!CONFIG_DEFAULTS[@]}"; do
        CONFIG_VALUES["$key"]="${CONFIG_DEFAULTS[$key]}"
    done
    
    export MOODLE_CONFIG_INITIALIZED="true"
    return 0
}

##
# Reset del sistema de configuración para tests
##
config_test_reset() {
    unset CONFIG_VALUES CONFIG_DEFAULTS
    unset MOODLE_CONFIG_INITIALIZED
    unset CONFIG_LOADED_FROM
}

# El resto de las funciones (config_get, config_set, etc.) permanecen igual
# pero todas verifican que config_init() haya sido llamado

config_get() {
    config_init  # Auto-inicializar si es necesario
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

config_set() {
    config_init  # Auto-inicializar si es necesario
    local key="$1"
    local value="$2"
    
    # ... resto de la lógica de validación ...
    CONFIG_VALUES["$key"]="$value"
    return 0
}

# Y así con todas las demás funciones...
