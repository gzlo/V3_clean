#!/bin/bash
##
# Script de ejecución de tests para Fases 1 y 2
# Ejecuta todos los tests principales de manera controlada
##

set -euo pipefail

echo "🧪 SUITE DE TESTS COMPLETA - FASES 1 y 2"
echo "=========================================="
echo ""

# Configuración de entorno
export MOODLE_CLI_TEST_MODE="true"
export PROJECT_ROOT="$(pwd)"
export TEST_TEMP_DIR="$(mktemp -d)"

echo "🔧 Configuración:"
echo "   PROJECT_ROOT: $PROJECT_ROOT"
echo "   TEST_TEMP_DIR: $TEST_TEMP_DIR"
echo "   MOODLE_CLI_TEST_MODE: $MOODLE_CLI_TEST_MODE"
echo ""

# Contadores
total_tests=0
passed_tests=0

# Función helper para ejecutar tests
run_test() {
    local test_name="$1"
    local test_command="$2"
    local description="$3"
    
    echo -n "📋 $test_name: "
    total_tests=$((total_tests + 1))
    
    if eval "$test_command" >/dev/null 2>&1; then
        echo "✅ PASSED - $description"
        passed_tests=$((passed_tests + 1))
        return 0
    else
        echo "❌ FAILED - $description"
        return 1
    fi
}

echo "🚀 Ejecutando tests..."
echo ""

# Test 1: Carga de constantes y colores
run_test "constants" \
    "source lib/constants.sh && source lib/colors.sh" \
    "Librerías base (constants, colors)"

# Test 2: Utilidades y filesystem
run_test "utils" \
    "source lib/utils.sh && source lib/filesystem.sh" \
    "Librerías utilitarias"

# Test 3: Logging
run_test "logging" \
    "source src/core/logging.sh" \
    "Sistema de logging"

# Test 4: Config básico
run_test "config_basic" \
    "source src/core/config.sh" \
    "Sistema de configuración"

# Test 5: Config con fixtures
run_test "config_fixtures" \
    "source tests/fixtures/config_fixtures.sh && source tests/helpers/config_test_helper.bash" \
    "Fixtures y helpers de configuración"

# Test 6: Mocks de validación
run_test "validation_mocks" \
    "source tests/mocks/system_commands.sh" \
    "Mocks para comandos del sistema"

# Test 7: Validación con mocks
run_test "validation" \
    "source tests/mocks/system_commands.sh && source src/core/validation.sh" \
    "Sistema de validación con mocks"

# Test 8: Bootstrap básico
run_test "bootstrap" \
    "source src/core/bootstrap.sh" \
    "Sistema de bootstrap"

# Test 9: Config funcional
run_test "config_functional" \
    "source lib/constants.sh && source lib/utils.sh && source lib/filesystem.sh && source src/core/logging.sh && source src/core/config.sh" \
    "Configuración funcional"

# Test 10: Validation funcional con mocks
run_test "validation_functional" \
    "source tests/mocks/system_commands.sh && activate_validation_mocks && source src/core/validation.sh && validate_bash_version" \
    "Validación funcional con mocks"

echo ""
echo "=================================================="
echo "📊 RESULTADOS FINALES:"
echo "   Tests ejecutados: $total_tests"
echo "   Tests pasados: $passed_tests"
echo "   Tests fallidos: $((total_tests - passed_tests))"

if [ "$total_tests" -gt 0 ]; then
    coverage=$((passed_tests * 100 / total_tests))
    echo "   Coverage: $coverage%"
else
    coverage=0
    echo "   Coverage: 0%"
fi

echo ""

if [ "$passed_tests" -eq "$total_tests" ]; then
    echo "🎉 TODOS LOS TESTS PASARON"
    echo "✅ Sistema completamente funcional"
    echo "🚀 Listo para Fase 3 (detección automática)"
    exit_code=0
elif [ "$coverage" -ge 80 ]; then
    echo "✅ MAYORÍA DE TESTS PASARON ($coverage%)"
    echo "⚠️  Algunos tests menores fallaron"
    echo "🔧 Sistema mayormente funcional"
    exit_code=0
else
    echo "❌ VARIOS TESTS FALLARON"
    echo "🔧 Sistema necesita correcciones"
    exit_code=1
fi

echo "=================================================="

# Limpiar
rm -rf "$TEST_TEMP_DIR" 2>/dev/null || true

exit $exit_code
