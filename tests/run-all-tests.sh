#!/bin/bash

##
# Test Runner Principal para Moodle Backup CLI
# Versión: 1.0.0
#
# Ejecuta toda la suite de tests (unitarios, integración, performance)
# y genera reportes de coverage
##

set -euo pipefail

# Configuración
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly TESTS_DIR="$PROJECT_ROOT/tests"
readonly COVERAGE_DIR="$TESTS_DIR/coverage"
readonly RESULTS_DIR="$TESTS_DIR/results"

# Colores
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Contadores globales
declare -i TOTAL_TESTS=0
declare -i PASSED_TESTS=0
declare -i FAILED_TESTS=0
declare -i SKIPPED_TESTS=0

# ===================== FUNCIONES DE UTILIDAD =====================

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

##
# Muestra ayuda del script
##
show_help() {
    cat <<EOF
Test Runner para Moodle Backup CLI

USO:
    $0 [OPCIONES] [PATTERNS...]

OPCIONES:
    -h, --help              Muestra esta ayuda
    -v, --verbose           Output detallado
    -t, --type TYPE         Tipo de tests (unit, integration, performance, all)
    -p, --pattern PATTERN   Patrón de archivos de test (ej: *logging*)
    -c, --coverage          Generar reporte de coverage
    -f, --format FORMAT     Formato de output (tap, junit, json)
    -o, --output DIR        Directorio de resultados
    -j, --jobs N            Número de jobs paralelos
    --timeout SECONDS       Timeout por test (default: 300)
    --setup                 Solo ejecutar setup inicial
    --cleanup               Solo ejecutar cleanup
    --bail                  Parar en el primer error

TIPOS DE TEST:
    unit                    Tests unitarios (por módulo)
    integration             Tests de integración (end-to-end)
    performance             Tests de performance y stress
    all                     Todos los tipos (default)

EJEMPLOS:
    $0                                    # Ejecutar todos los tests
    $0 -t unit -c                        # Solo tests unitarios con coverage
    $0 -p "*logging*" -v                 # Tests de logging con output verbose
    $0 -t integration --timeout 600      # Tests de integración con timeout extendido
    $0 --format junit -o /tmp/results    # Output en formato JUnit

EOF
}

# ===================== CONFIGURACIÓN Y SETUP =====================

##
# Verifica dependencias del sistema de testing
##
check_dependencies() {
    local missing_deps=()
    
    # BATS (Bash Automated Testing System)
    if ! command -v bats >/dev/null 2>&1; then
        missing_deps+=("bats")
    fi
    
    # bc para cálculos (opcional)
    if ! command -v bc >/dev/null 2>&1; then
        log_warning "bc no está disponible - algunas métricas pueden ser limitadas"
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Dependencias faltantes: ${missing_deps[*]}"
        log_info "Para instalar BATS:"
        log_info "  Ubuntu/Debian: apt-get install bats"
        log_info "  macOS: brew install bats-core"
        log_info "  Manual: https://github.com/bats-core/bats-core"
        return 1
    fi
    
    return 0
}

##
# Configura el entorno de testing
##
setup_test_environment() {
    local verbose="$1"
    
    [[ "$verbose" == "true" ]] && log_info "Configurando entorno de testing..."
    
    # Crear directorios necesarios
    mkdir -p "$COVERAGE_DIR" "$RESULTS_DIR"
    
    # Configurar variables de entorno para tests
    export MOODLE_BACKUP_TEST_MODE=1
    export MOODLE_BACKUP_LOG_LEVEL=1  # Solo errores durante tests
    export MOODLE_BACKUP_NO_COLOR=1   # Sin colores en tests
    
    # Configurar paths temporales para tests
    export MOODLE_BACKUP_TEST_TMP_DIR="$TESTS_DIR/tmp"
    mkdir -p "$MOODLE_BACKUP_TEST_TMP_DIR"
    
    # Cargar librerías para tests
    if [[ -f "$TESTS_DIR/test_helper.bash" ]]; then
        # shellcheck source=/dev/null
        source "$TESTS_DIR/test_helper.bash"
    fi
    
    [[ "$verbose" == "true" ]] && log_success "Entorno de testing configurado"
}

##
# Limpia el entorno de testing
##
cleanup_test_environment() {
    local verbose="$1"
    
    [[ "$verbose" == "true" ]] && log_info "Limpiando entorno de testing..."
    
    # Limpiar archivos temporales de tests
    if [[ -d "$MOODLE_BACKUP_TEST_TMP_DIR" ]]; then
        rm -rf "$MOODLE_BACKUP_TEST_TMP_DIR"
    fi
    
    # Limpiar lockfiles de testing
    find /tmp -name "moodle_backup_test_*" -type f -delete 2>/dev/null || true
    
    # Limpiar procesos huérfanos de testing
    pkill -f "moodle.*backup.*test" 2>/dev/null || true
    
    [[ "$verbose" == "true" ]] && log_success "Entorno de testing limpio"
}

# ===================== EJECUCIÓN DE TESTS =====================

##
# Encuentra archivos de test por tipo y patrón
##
find_test_files() {
    local test_type="$1"
    local pattern="$2"
    
    case "$test_type" in
        "unit")
            find "$TESTS_DIR/unit" -name "$pattern.bats" -type f 2>/dev/null | sort
            ;;
        "integration")
            find "$TESTS_DIR/integration" -name "$pattern.bats" -type f 2>/dev/null | sort
            ;;
        "performance")
            find "$TESTS_DIR/performance" -name "$pattern.bats" -type f 2>/dev/null | sort
            ;;
        "all")
            find "$TESTS_DIR" -name "$pattern.bats" -type f ! -path "*/coverage/*" ! -path "*/results/*" 2>/dev/null | sort
            ;;
        *)
            log_error "Tipo de test desconocido: $test_type"
            return 1
            ;;
    esac
}

##
# Ejecuta un archivo de test individual
##
run_test_file() {
    local test_file="$1"
    local format="$2"
    local timeout="$3"
    local verbose="$4"
    local bail="$5"
    
    local test_name
    test_name=$(basename "$test_file" .bats)
    
    [[ "$verbose" == "true" ]] && log_info "Ejecutando: $test_name"
    
    # Configurar comando BATS
    local bats_cmd="bats"
    local bats_args=()
    
    # Configurar formato
    case "$format" in
        "tap")
            bats_args+=("--formatter" "tap")
            ;;
        "junit")
            bats_args+=("--formatter" "junit")
            ;;
        "json")
            bats_args+=("--formatter" "json")
            ;;
        *)
            # Formato por defecto (pretty)
            bats_args+=("--formatter" "pretty")
            ;;
    esac
    
    # Configurar timeout
    local timeout_cmd=""
    if command -v timeout >/dev/null 2>&1; then
        timeout_cmd="timeout $timeout"
    fi
    
    # Ejecutar test con captura de output y exit code
    local output_file="$RESULTS_DIR/${test_name}.out"
    local exit_code=0
    
    if [[ -n "$timeout_cmd" ]]; then
        $timeout_cmd $bats_cmd "${bats_args[@]}" "$test_file" > "$output_file" 2>&1 || exit_code=$?
    else
        $bats_cmd "${bats_args[@]}" "$test_file" > "$output_file" 2>&1 || exit_code=$?
    fi
    
    # Procesar resultados
    local test_count passed_count failed_count skipped_count
    
    if [[ "$format" == "tap" ]] || [[ "$format" == "" ]]; then
        # Parsear formato TAP
        test_count=$(grep -c "^[0-9]" "$output_file" 2>/dev/null || echo "0")
        passed_count=$(grep -c "^ok " "$output_file" 2>/dev/null || echo "0")
        failed_count=$(grep -c "^not ok " "$output_file" 2>/dev/null || echo "0")
        skipped_count=$(grep -c "# skip" "$output_file" 2>/dev/null || echo "0")
    else
        # Para otros formatos, usar exit code
        if [[ $exit_code -eq 0 ]]; then
            test_count=1
            passed_count=1
            failed_count=0
            skipped_count=0
        else
            test_count=1
            passed_count=0
            failed_count=1
            skipped_count=0
        fi
    fi
    
    # Actualizar contadores globales
    ((TOTAL_TESTS += test_count))
    ((PASSED_TESTS += passed_count))
    ((FAILED_TESTS += failed_count))
    ((SKIPPED_TESTS += skipped_count))
    
    # Mostrar resultados del archivo
    if [[ $failed_count -eq 0 ]]; then
        log_success "$test_name: $passed_count/$test_count tests passed"
    else
        log_error "$test_name: $failed_count/$test_count tests failed"
        
        # Mostrar errores si es verbose o hay fallos
        if [[ "$verbose" == "true" ]] || [[ $failed_count -gt 0 ]]; then
            echo "--- Output de $test_name ---"
            cat "$output_file"
            echo "--- Fin output ---"
        fi
        
        # Bail si está habilitado
        if [[ "$bail" == "true" ]]; then
            log_error "Deteniendo ejecución por --bail (primer error)"
            return $exit_code
        fi
    fi
    
    return $exit_code
}

##
# Ejecuta suite de tests en paralelo
##
run_test_suite_parallel() {
    local test_files=("$@")
    local jobs="$1"; shift
    local format="$1"; shift  
    local timeout="$1"; shift
    local verbose="$1"; shift
    local bail="$1"; shift
    test_files=("$@")
    
    local pids=()
    local active_jobs=0
    local job_index=0
    
    for test_file in "${test_files[@]}"; do
        # Esperar si hemos alcanzado el límite de jobs
        while [[ $active_jobs -ge $jobs ]]; do
            for i in "${!pids[@]}"; do
                if ! kill -0 "${pids[$i]}" 2>/dev/null; then
                    wait "${pids[$i]}"
                    unset "pids[$i]"
                    ((active_jobs--))
                fi
            done
            sleep 0.1
        done
        
        # Ejecutar test en background
        run_test_file "$test_file" "$format" "$timeout" "$verbose" "$bail" &
        pids[$job_index]=$!
        ((active_jobs++))
        ((job_index++))
        
        # Si bail está habilitado, no ejecutar en paralelo
        if [[ "$bail" == "true" ]]; then
            wait "${pids[$((job_index-1))]}"
            local exit_code=$?
            if [[ $exit_code -ne 0 ]]; then
                # Matar todos los jobs en background
                for pid in "${pids[@]}"; do
                    kill "$pid" 2>/dev/null || true
                done
                return $exit_code
            fi
            active_jobs=0
            pids=()
        fi
    done
    
    # Esperar a que terminen todos los jobs
    for pid in "${pids[@]}"; do
        wait "$pid"
    done
}

# ===================== COVERAGE Y MÉTRICAS =====================

##
# Función auxiliar para verificar si un archivo debe incluirse en coverage
##
should_include_in_coverage() {
    local file="$1"
    local basename
    basename=$(basename "$file")
    
    # Patrones de exclusión
    local exclude_patterns=("*test*" "*mock*" "*fixture*" "*.md" "*.txt" "*.json" "*.yml" "*.yaml")
    
    for pattern in "${exclude_patterns[@]}"; do
        if [[ "$basename" == $pattern ]]; then
            return 1
        fi
    done
    
    # Patrones de inclusión
    if [[ "$basename" =~ \.(sh|bash)$ ]]; then
        return 0
    fi
    
    return 1
}

##
# Función para ejecutar análisis de cobertura
##
run_coverage() {
    print_section "📊 Ejecutando análisis de cobertura"
    
    local coverage_dir="$TEST_DIR/coverage"
    mkdir -p "$coverage_dir"
    
    # Cargar configuración de coverage si existe
    if [[ -f "$coverage_dir/coverage.conf" ]]; then
        source "$coverage_dir/coverage.conf"
    fi
    
    local total_files=0
    local covered_files=0
    local total_functions=0
    local tested_functions=0
    
    # Análisis detallado de archivos y funciones
    {
        echo "# Coverage Report - $(date)"
        echo "# Generated by Moodle CLI Backup Test Suite"
        echo ""
        echo "## Summary"
    } > "$coverage_dir/coverage.txt"
    
    # Analizar archivos en lib/ y src/
    for dir in lib src; do
        if [[ -d "$dir" ]]; then
            echo "Analizando directorio: $dir"
            
            while IFS= read -r -d '' file; do
                if should_include_in_coverage "$file"; then
                    ((total_files++))
                    
                    # Contar funciones en el archivo
                    local file_functions
                    file_functions=$(grep -c "^[[:space:]]*function\|^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*(" "$file" 2>/dev/null || echo 0)
                    total_functions=$((total_functions + file_functions))
                    
                    # Verificar si tiene tests correspondientes
                    local base_name
                    base_name=$(basename "${file%.*}")
                    local has_unit_test=0
                    local has_integration_test=0
                    
                    if [[ -f "$TEST_DIR/unit/test_${base_name}.bats" ]]; then
                        has_unit_test=1
                        ((covered_files++))
                        
                        # Contar tests de funciones
                        local function_tests
                        function_tests=$(grep -c "@test.*${base_name}" "$TEST_DIR/unit/test_${base_name}.bats" 2>/dev/null || echo 0)
                        tested_functions=$((tested_functions + function_tests))
                    fi
                    
                    if [[ -f "$TEST_DIR/integration/test_${base_name}.bats" ]]; then
                        has_integration_test=1
                        if [[ $has_unit_test -eq 0 ]]; then
                            ((covered_files++))
                        fi
                    fi
                    
                    # Reportar archivo individual
                    {
                        echo "### $file"
                        echo "- Functions: $file_functions"
                        echo "- Unit tests: $has_unit_test"
                        echo "- Integration tests: $has_integration_test"
                        echo ""
                    } >> "$coverage_dir/coverage.txt"
                fi
            done < <(find "$dir" -type f -print0 2>/dev/null)
        fi
    done
    
    # Calcular métricas finales
    local file_coverage_percent=0
    local function_coverage_percent=0
    
    if [[ $total_files -gt 0 ]]; then
        file_coverage_percent=$((covered_files * 100 / total_files))
    fi
    
    if [[ $total_functions -gt 0 ]]; then
        function_coverage_percent=$((tested_functions * 100 / total_functions))
    fi
    
    # Escribir resumen
    {
        echo "## Coverage Metrics"
        echo "- Total files: $total_files"
        echo "- Files with tests: $covered_files"
        echo "- File coverage: ${file_coverage_percent}%"
        echo "- Total functions: $total_functions"
        echo "- Functions with tests: $tested_functions"
        echo "- Function coverage: ${function_coverage_percent}%"
        echo ""
        echo "## Overall Score: ${file_coverage_percent}%"
    } >> "$coverage_dir/coverage.txt"
    
    # Mostrar resultados
    local overall_coverage=$file_coverage_percent
    local threshold=${COVERAGE_THRESHOLD:-90}
    
    if [[ $overall_coverage -ge $threshold ]]; then
        print_success "Cobertura: ${overall_coverage}% (Excelente ✨)"
    elif [[ $overall_coverage -ge 70 ]]; then
        print_warning "Cobertura: ${overall_coverage}% (Buena 👍)"
    else
        print_error "Cobertura: ${overall_coverage}% (Necesita mejora 🔨)"
    fi
    
    echo -e "${GREEN}Archivos: $covered_files/$total_files | Funciones: $tested_functions/$total_functions${NC}"
    echo "Reporte detallado: $coverage_dir/coverage.txt"
    
    return $overall_coverage
}

##
# Genera reporte de coverage avanzado
##
generate_coverage_report() {
    local verbose="${1:-false}"
    
    print_section "📊 Generando reporte de cobertura"
    
    if [[ "$verbose" == "true" ]]; then
        run_coverage
    else
        run_coverage >/dev/null
        echo "Reporte de cobertura generado en tests/coverage/"
    fi
}

# ===================== FUNCIÓN PRINCIPAL =====================

# ===================== PROCESAMIENTO DE ARGUMENTOS =====================

# Valores por defecto
VERBOSE=false
TEST_TYPE="all"
PATTERN="*"
GENERATE_COVERAGE=false
FORMAT="pretty"
OUTPUT_DIR="$RESULTS_DIR"
JOBS=1
TIMEOUT=300
SETUP_ONLY=false
CLEANUP_ONLY=false
BAIL=false

# Procesar argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -t|--type)
            TEST_TYPE="$2"
            shift 2
            ;;
        -p|--pattern)
            PATTERN="$2"
            shift 2
            ;;
        -c|--coverage)
            GENERATE_COVERAGE=true
            shift
            ;;
        -f|--format)
            FORMAT="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            RESULTS_DIR="$OUTPUT_DIR"
            COVERAGE_DIR="$OUTPUT_DIR/coverage"
            shift 2
            ;;
        -j|--jobs)
            JOBS="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --setup)
            SETUP_ONLY=true
            shift
            ;;
        --cleanup)
            CLEANUP_ONLY=true
            shift
            ;;
        --bail)
            BAIL=true
            shift
            ;;
        *)
            PATTERN="*$1*"
            shift
            ;;
    esac
done

# ===================== EJECUCIÓN PRINCIPAL =====================

main() {
    local start_time
    start_time=$(date +%s)
    
    log_info "Test Runner para Moodle Backup CLI"
    
    # Solo cleanup si se solicita
    if [[ "$CLEANUP_ONLY" == "true" ]]; then
        cleanup_test_environment "$VERBOSE"
        exit 0
    fi
    
    # Verificar dependencias
    if ! check_dependencies; then
        exit 1
    fi
    
    # Setup del entorno
    setup_test_environment "$VERBOSE"
    
    # Solo setup si se solicita
    if [[ "$SETUP_ONLY" == "true" ]]; then
        log_success "Setup de entorno completado"
        exit 0
    fi
    
    # Configurar cleanup automático
    trap 'cleanup_test_environment "$VERBOSE"' EXIT
    
    # Encontrar archivos de test
    local test_files=()
    mapfile -t test_files < <(find_test_files "$TEST_TYPE" "$PATTERN")
    
    if [[ ${#test_files[@]} -eq 0 ]]; then
        log_warning "No se encontraron archivos de test para el patrón: $PATTERN"
        exit 0
    fi
    
    [[ "$VERBOSE" == "true" ]] && log_info "Encontrados ${#test_files[@]} archivos de test"
    
    # Crear directorio de output
    mkdir -p "$OUTPUT_DIR"
    
    # Ejecutar tests
    if [[ $JOBS -eq 1 ]]; then
        # Ejecución secuencial
        for test_file in "${test_files[@]}"; do
            run_test_file "$test_file" "$FORMAT" "$TIMEOUT" "$VERBOSE" "$BAIL" || {
                [[ "$BAIL" == "true" ]] && break
            }
        done
    else
        # Ejecución paralela
        run_test_suite_parallel "$JOBS" "$FORMAT" "$TIMEOUT" "$VERBOSE" "$BAIL" "${test_files[@]}"
    fi
    
    local end_time
    end_time=$(date +%s)
    
    # Generar coverage si se solicita
    if [[ "$GENERATE_COVERAGE" == "true" ]]; then
        generate_coverage_report "$VERBOSE"
    fi
    
    # Generar resumen
    generate_test_summary "$FORMAT" "$start_time" "$end_time"
}

# Ejecutar función principal
main "$@"
