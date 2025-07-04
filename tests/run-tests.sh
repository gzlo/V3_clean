#!/bin/bash
# ================================================================
# EJECUTOR DE TESTS PARA MOODLE BACKUP CLI
# ================================================================

set -euo pipefail

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'
BOLD='\033[1m'

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

print_header() {
    echo -e "${BLUE}${BOLD}================================================================${NC}"
    echo -e "${BLUE}${BOLD}  MOODLE BACKUP CLI - SUITE DE TESTS COMPLETA${NC}"
    echo -e "${BLUE}${BOLD}  Ejecutando todos los tests disponibles${NC}"
    echo -e "${BLUE}${BOLD}================================================================${NC}"
    echo ""
}

run_test() {
    local test_name="$1"
    local test_script="$2"
    local description="$3"
    
    echo -e "${BLUE}🧪 Ejecutando: ${BOLD}$test_name${NC}"
    echo -e "${BLUE}📝 Descripción: $description${NC}"
    echo ""
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [[ -f "$test_script" ]]; then
        if bash "$test_script"; then
            echo ""
            echo -e "${GREEN}✅ TEST PASADO: $test_name${NC}"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            echo ""
            echo -e "${RED}❌ TEST FALLIDO: $test_name${NC}"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    else
        echo -e "${RED}❌ ARCHIVO NO ENCONTRADO: $test_script${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    
    echo -e "${BLUE}${BOLD}================================================================${NC}"
    echo ""
}

print_summary() {
    echo -e "${BLUE}${BOLD}================================================================${NC}"
    echo -e "${BLUE}${BOLD}  RESUMEN FINAL DE TODOS LOS TESTS${NC}"
    echo -e "${BLUE}${BOLD}================================================================${NC}"
    echo ""
    
    local success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    
    echo -e "Total de test suites ejecutadas: ${BOLD}$TOTAL_TESTS${NC}"
    echo -e "Test suites exitosas: ${GREEN}${BOLD}$PASSED_TESTS${NC}"
    echo -e "Test suites fallidas: ${RED}${BOLD}$FAILED_TESTS${NC}"
    echo -e "Tasa de éxito: ${BOLD}$success_rate%${NC}"
    echo ""
    
    if [[ $success_rate -ge 90 ]]; then
        echo -e "${GREEN}${BOLD}🎉 TODOS LOS TESTS PRINCIPALES PASARON EXITOSAMENTE${NC}"
        echo -e "${GREEN}${BOLD}✅ SISTEMA LISTO PARA PRODUCCIÓN${NC}"
        echo ""
        echo -e "${GREEN}Componentes validados:${NC}"
        echo -e "  ✓ Parsing robusto de config.php de Moodle"
        echo -e "  ✓ Auto-detección de configuraciones"
        echo -e "  ✓ Integración con todos los instaladores"
        echo -e "  ✓ Manejo de errores y casos edge"
        echo -e "  ✓ Performance y seguridad"
        echo -e "  ✓ Compatibilidad con múltiples paneles"
        echo ""
        echo -e "${GREEN}🚀 Ready to deploy!${NC}"
        return 0
    else
        echo -e "${RED}${BOLD}⚠️  ALGUNOS TESTS FALLARON${NC}"
        echo -e "${RED}${BOLD}❌ REQUIERE ATENCIÓN ANTES DE PRODUCCIÓN${NC}"
        echo ""
        echo -e "${YELLOW}Revisar logs de tests fallidos arriba${NC}"
        return 1
    fi
}

# Función principal
main() {
    print_header
    
    # Test 1: Parsing robusto de config.php (test principal)
    run_test \
        "test-robust-moodle-parsing" \
        "$SCRIPT_DIR/test-robust-moodle-parsing.sh" \
        "Test comprehensivo de parsing de config.php con cobertura >90%"
    
    # Test 2: Parsing simple y robusto
    run_test \
        "test-simple-moodle-parsing" \
        "$SCRIPT_DIR/test-simple-moodle-parsing.sh" \
        "Test simple y robusto de parsing de config.php"
    
    # Test 3: Test de instalación (si existe)
    if [[ -f "$SCRIPT_DIR/test-install.sh" ]]; then
        run_test \
            "test-install" \
            "$SCRIPT_DIR/test-install.sh" \
            "Test de proceso de instalación completo"
    fi
    
    # Test 4: Test de mejoras (si existe)
    if [[ -f "$SCRIPT_DIR/test-mejoras.sh" ]]; then
        run_test \
            "test-mejoras" \
            "$SCRIPT_DIR/test-mejoras.sh" \
            "Test de mejoras y funcionalidades adicionales"
    fi
    
    # Test 5: Test de UI (si existe)
    if [[ -f "$SCRIPT_DIR/test-ui-improvements.sh" ]]; then
        run_test \
            "test-ui-improvements" \
            "$SCRIPT_DIR/test-ui-improvements.sh" \
            "Test de mejoras de interfaz de usuario"
    fi
    
    # Mostrar resumen y determinar resultado
    print_summary
}

# Ejecutar tests
main "$@"
