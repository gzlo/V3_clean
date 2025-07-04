#!/bin/bash
##
# Helper especializado para tests de configuración
# tests/helpers/config_test_helper.bash
##

# Cargar fixtures
source "${BATS_TEST_DIRNAME:-}/../fixtures/config_fixtures.sh" 2>/dev/null || \
source "$(dirname "${BASH_SOURCE[0]}")/../fixtures/config_fixtures.sh" 2>/dev/null || \
source "tests/fixtures/config_fixtures.sh"

##
# Crear archivo de configuración temporal con fixture
# @param $1 string Nombre del fixture (basic, variable, boolean, etc.)
# @param $2 string Nombre del archivo (opcional)
# @return string Ruta del archivo creado
##
create_config_fixture() {
    local fixture_name="$1"
    local filename="${2:-test.conf}"
    local config_file="$TEST_CONFIG_DIR/$filename"
    
    case "$fixture_name" in
        basic)
            get_basic_config_fixture > "$config_file"
            ;;
        variable)
            get_variable_config_fixture > "$config_file"
            ;;
        boolean)
            get_boolean_config_fixture > "$config_file"
            ;;
        malformed)
            get_malformed_config_fixture > "$config_file"
            ;;
        env_priority)
            get_env_priority_config_fixture > "$config_file"
            ;;
        validation)
            get_validation_config_fixture > "$config_file"
            ;;
        *)
            echo "Fixture desconocido: $fixture_name" >&2
            return 1
            ;;
    esac
    
    echo "$config_file"
}

##
# Setup especializado para tests de configuración
##
config_test_setup() {
    # Crear directorio temporal para tests
    TEST_CONFIG_DIR="$TEST_TEMP_DIR/config"
    mkdir -p "$TEST_CONFIG_DIR"
    
    # Limpiar variables de entorno que puedan interferir
    unset LOG_LEVEL BACKUP_DIR CLOUD_ENABLED
    unset LOG_TO_FILE LOG_TO_STDOUT VERBOSE DEBUG
    unset CONFIG_FILE CONFIG_LOADED_FROM
    unset MOODLE_BACKUP_CONFIG_LOADED
    
    # Cargar el módulo de configuración
    source "$PROJECT_ROOT/src/core/config.sh"
}

##
# Teardown especializado para tests de configuración
##
config_test_teardown() {
    # Limpiar configuración
    config_reset 2>/dev/null || true
    unset CONFIG_VALUES CONFIG_LOADED_FROM CONFIG_FILES
    unset LOG_LEVEL BACKUP_DIR CLOUD_ENABLED
    unset LOG_TO_FILE LOG_TO_STDOUT VERBOSE DEBUG
    unset CONFIG_FILE
    unset TEST_BASE
}

##
# Verificar que una configuración cargó correctamente
# @param $1 string Clave de configuración
# @param $2 string Valor esperado
##
assert_config_value() {
    local key="$1"
    local expected="$2"
    local actual
    
    actual=$(config_get "$key")
    [ "$actual" = "$expected" ] || {
        echo "Expected config['$key'] = '$expected', got '$actual'" >&2
        return 1
    }
}

##
# Verificar que múltiples configuraciones cargaron correctamente
# @param $@ array Pares clave=valor
##
assert_config_values() {
    local pair key value
    
    for pair in "$@"; do
        key="${pair%=*}"
        value="${pair#*=}"
        assert_config_value "$key" "$value"
    done
}
