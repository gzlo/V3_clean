#!/usr/bin/env bash

##
# Test Helper Principal para Moodle CLI
# Configuración común para todos los tests
##

# Configurar variables de entorno base
export MOODLE_CLI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export BATS_TEST_TIMEOUT=30

# Configurar logging para tests
export BACKUP_LOG_LEVEL="ERROR"
export BACKUP_LOG_SUPPRESS="true"

# Colores para output de tests (compatibles con Windows)
if [[ "${OS:-}" == "Windows_NT" ]]; then
    export NO_COLOR=1
fi

# Función para preparar entorno de test aislado
setup_test_environment() {
    export TEST_TMPDIR="${BATS_TEST_TMPDIR:-/tmp}/moodle_cli_test_$$"
    mkdir -p "${TEST_TMPDIR}"
    export BACKUP_LOG_DIR="${TEST_TMPDIR}/logs"
    mkdir -p "${BACKUP_LOG_DIR}"
}

# Función para limpiar entorno de test
cleanup_test_environment() {
    if [[ -n "${TEST_TMPDIR:-}" && -d "${TEST_TMPDIR}" ]]; then
        rm -rf "${TEST_TMPDIR}"
    fi
}

# Función para crear mocks básicos
setup_basic_mocks() {
    export MOCK_DIR="${MOODLE_CLI_ROOT}/tests/mocks"
    mkdir -p "${MOCK_DIR}"
    export PATH="${MOCK_DIR}:${PATH}"
}

# Función para verificar dependencias de test
check_test_dependencies() {
    local missing_deps=()
    
    # Verificar que existen los módulos core
    for module in logging config validation; do
        if [[ ! -f "${MOODLE_CLI_ROOT}/src/core/${module}.sh" ]]; then
            missing_deps+=("src/core/${module}.sh")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo "ERROR: Dependencias faltantes: ${missing_deps[*]}" >&2
        return 1
    fi
}

# Auto-ejecutar verificaciones básicas
check_test_dependencies || exit 1
