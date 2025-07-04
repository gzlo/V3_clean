#!/usr/bin/env bats

##
# Tests para el Auto-Detector Principal
# 
# Pruebas unitarias del orquestador de detección automática
##

# Setup y teardown
setup() {
    # Cargar helpers de testing
    load '../../helpers/test_helper'
    load '../../helpers/config_test_helper.bash'
    
    # Configurar entorno de test
    export MOODLE_CLI_TEST_MODE="true"
    export TEST_TEMP_DIR="$(mktemp -d)"
    export DETECTION_CACHE_DIR="$TEST_TEMP_DIR/detection-cache"
    
    # Cargar módulo bajo test
    source "$PROJECT_ROOT/src/detection/auto-detector.sh"
}

teardown() {
    # Limpiar estado
    detection_cleanup
    
    # Limpiar archivos temporales
    [[ -d "$TEST_TEMP_DIR" ]] && rm -rf "$TEST_TEMP_DIR"
}

# ===================== TESTS DE INICIALIZACIÓN =====================

@test "auto-detector se carga correctamente" {
    run echo "$MOODLE_AUTO_DETECTOR_LOADED"
    assert_output "true"
}

@test "detection_cache_init crea directorio de cache" {
    run detection_cache_init
    assert_success
    assert [ -d "$DETECTION_CACHE_DIR" ]
}

@test "detection_cache_init en modo test usa TEST_TEMP_DIR" {
    export MOODLE_CLI_TEST_MODE="true"
    run detection_cache_init
    assert_success
    assert [[ "$DETECTION_CACHE_DIR" == *"$TEST_TEMP_DIR"* ]]
}

# ===================== TESTS DE CACHE =====================

@test "detection_cache_set almacena valor correctamente" {
    detection_cache_init
    
    run detection_cache_set "test_key" "test_value"
    assert_success
    
    assert [ -f "$DETECTION_CACHE_DIR/test_key.cache" ]
    run cat "$DETECTION_CACHE_DIR/test_key.cache"
    assert_output "test_value"
}

@test "detection_cache_get recupera valor almacenado" {
    detection_cache_init
    detection_cache_set "test_key" "test_value"
    
    run detection_cache_get "test_key"
    assert_success
    assert_output "test_value"
}

@test "detection_cache_get falla para clave inexistente" {
    detection_cache_init
    
    run detection_cache_get "nonexistent_key"
    assert_failure
}

@test "detection_cache_clear limpia todos los archivos de cache" {
    detection_cache_init
    detection_cache_set "key1" "value1"
    detection_cache_set "key2" "value2"
    
    run detection_cache_clear
    assert_success
    
    run find "$DETECTION_CACHE_DIR" -name "*.cache"
    assert_output ""
}

# ===================== TESTS DE REGISTRO DE MÓDULOS =====================

@test "detection_register_module registra módulo válido" {
    # Crear módulo de prueba
    local test_module="$TEST_TEMP_DIR/test_module.sh"
    echo "#!/bin/bash" > "$test_module"
    echo "detect_test() { echo 'test_result'; }" >> "$test_module"
    
    run detection_register_module "test" "$test_module"
    assert_success
    
    # Verificar que se registró
    assert [[ "${DETECTION_MODULES[*]}" == *"test:$test_module"* ]]
}

@test "detection_register_module falla para archivo inexistente" {
    run detection_register_module "test" "/nonexistent/module.sh"
    assert_failure
}

@test "detection_load_modules carga módulos estándar" {
    # Crear módulos simulados
    mkdir -p "$TEST_TEMP_DIR/detection"
    for module in panels directories moodle database; do
        local module_file="$TEST_TEMP_DIR/detection/${module}.sh"
        echo "#!/bin/bash" > "$module_file"
        echo "detect_${module}() { echo '${module}_result'; }" >> "$module_file"
    done
    
    # Sobrescribir la función para usar archivos de test
    detection_load_modules() {
        local detection_dir="$TEST_TEMP_DIR/detection"
        local modules=(
            "panels:$detection_dir/panels.sh"
            "directories:$detection_dir/directories.sh"
            "moodle:$detection_dir/moodle.sh"
            "database:$detection_dir/database.sh"
        )
        
        for module in "${modules[@]}"; do
            local name="${module%%:*}"
            local path="${module##*:}"
            detection_register_module "$name" "$path"
        done
    }
    
    run detection_load_modules
    assert_success
    
    # Verificar que se cargaron 4 módulos
    assert [ ${#DETECTION_MODULES[@]} -eq 4 ]
}

# ===================== TESTS DE EJECUCIÓN DE MÓDULOS =====================

@test "detection_run_module ejecuta módulo correctamente" {
    # Crear módulo de prueba
    local test_module="$TEST_TEMP_DIR/test_module.sh"
    echo "#!/bin/bash" > "$test_module"
    echo "detect_test() { echo 'module_executed'; return 0; }" >> "$test_module"
    
    detection_cache_init
    detection_register_module "test" "$test_module"
    
    run detection_run_module "test"
    assert_success
    
    # Verificar que el resultado se almacenó
    assert [[ "${DETECTION_RESULTS[test]}" == "module_executed" ]]
}

@test "detection_run_module usa cache cuando está disponible" {
    # Configurar cache
    detection_cache_init
    detection_cache_set "module_test" "cached_result"
    
    # Crear módulo que no debería ejecutarse
    local test_module="$TEST_TEMP_DIR/test_module.sh"
    echo "#!/bin/bash" > "$test_module"
    echo "detect_test() { echo 'fresh_result'; return 0; }" >> "$test_module"
    
    detection_register_module "test" "$test_module"
    
    run detection_run_module "test"
    assert_success
    
    # Debe usar el resultado del cache
    assert [[ "${DETECTION_RESULTS[test]}" == "cached_result" ]]
}

@test "detection_run_module falla para módulo no registrado" {
    run detection_run_module "nonexistent"
    assert_failure
}

# ===================== TESTS DE ALGORITMO DE DETECCIÓN =====================

@test "detection_run_all ejecuta todos los módulos registrados" {
    # Crear módulos simulados
    mkdir -p "$TEST_TEMP_DIR/detection"
    
    for module in panels directories; do
        local module_file="$TEST_TEMP_DIR/detection/${module}.sh"
        echo "#!/bin/bash" > "$module_file"
        echo "detect_${module}() { echo '${module}_detected'; return 0; }" >> "$module_file"
        chmod +x "$module_file"
    done
    
    # Sobrescribir detection_load_modules para usar archivos de test
    detection_load_modules() {
        detection_register_module "panels" "$TEST_TEMP_DIR/detection/panels.sh"
        detection_register_module "directories" "$TEST_TEMP_DIR/detection/directories.sh"
    }
    
    run detection_run_all
    assert_success
    
    # Verificar que se ejecutaron ambos módulos
    assert [[ "${DETECTION_RESULTS[panels]}" == "panels_detected" ]]
    assert [[ "${DETECTION_RESULTS[directories]}" == "directories_detected" ]]
}

@test "detection_run_all respeta prioridades de módulos" {
    # Los módulos deben ejecutarse en orden de prioridad
    # panels (1) -> directories (2) -> moodle (3) -> database (4)
    
    mkdir -p "$TEST_TEMP_DIR/detection"
    
    # Crear archivo de log para verificar orden
    local execution_log="$TEST_TEMP_DIR/execution_order.log"
    
    for module in panels directories moodle database; do
        local module_file="$TEST_TEMP_DIR/detection/${module}.sh"
        echo "#!/bin/bash" > "$module_file"
        echo "detect_${module}() {" >> "$module_file"
        echo "  echo '${module}' >> '$execution_log'" >> "$module_file"
        echo "  echo '${module}_detected'" >> "$module_file"
        echo "  return 0" >> "$module_file"
        echo "}" >> "$module_file"
        chmod +x "$module_file"
    done
    
    # Sobrescribir detection_load_modules
    detection_load_modules() {
        for module in panels directories moodle database; do
            detection_register_module "$module" "$TEST_TEMP_DIR/detection/${module}.sh"
        done
    }
    
    run detection_run_all
    assert_success
    
    # Verificar orden de ejecución
    run cat "$execution_log"
    local lines=("${lines[@]}")
    assert [ "${lines[0]}" = "panels" ]
    assert [ "${lines[1]}" = "directories" ]
    assert [ "${lines[2]}" = "moodle" ]
    assert [ "${lines[3]}" = "database" ]
}

@test "detection_run_all no se ejecuta múltiples veces" {
    # Primera ejecución
    export DETECTION_STARTED=false
    run detection_run_all
    assert_success
    
    # Segunda ejecución debe detectar que ya se ejecutó
    run detection_run_all
    assert_success
    assert_output --partial "Detección ya iniciada"
}

# ===================== TESTS DE FUNCIONES DE REPORTE =====================

@test "detection_get_result retorna resultado de módulo" {
    DETECTION_RESULTS["test_module"]="test_result"
    
    run detection_get_result "test_module"
    assert_output "test_result"
}

@test "detection_get_result retorna vacío para módulo inexistente" {
    run detection_get_result "nonexistent_module"
    assert_output ""
}

@test "detection_has_result verifica existencia de resultado" {
    DETECTION_RESULTS["existing_module"]="some_result"
    
    run detection_has_result "existing_module"
    assert_success
    
    run detection_has_result "nonexistent_module"
    assert_failure
}

@test "detection_generate_report crea archivo de reporte" {
    detection_cache_init
    DETECTION_RESULTS["panels"]="cpanel_detected"
    DETECTION_RESULTS["moodle"]="moodle_found"
    
    run detection_generate_report
    assert_success
    
    local report_file="$DETECTION_CACHE_DIR/detection_report.txt"
    assert [ -f "$report_file" ]
    
    run grep -q "panels" "$report_file"
    assert_success
    
    run grep -q "cpanel_detected" "$report_file"
    assert_success
}

# ===================== TESTS DE LIMPIEZA =====================

@test "detection_cleanup resetea estado correctamente" {
    # Configurar estado inicial
    DETECTION_STARTED=true
    DETECTION_RESULTS["test"]="result"
    DETECTION_MODULES+=("test:path")
    
    run detection_cleanup
    assert_success
    
    # Verificar que se limpió todo
    assert [ "$DETECTION_STARTED" = "false" ]
    assert [ ${#DETECTION_RESULTS[@]} -eq 0 ]
    assert [ ${#DETECTION_MODULES[@]} -eq 0 ]
}

@test "detection_cleanup limpia cache en modo test" {
    export MOODLE_CLI_TEST_MODE="true"
    detection_cache_init
    detection_cache_set "test" "value"
    
    run detection_cleanup
    assert_success
    
    # En modo test, debe limpiar el cache
    run detection_cache_get "test"
    assert_failure
}

# ===================== TESTS DE COMANDO AUTO_DETECT =====================

@test "auto_detect run ejecuta detección completa" {
    # Simular módulos mínimos
    mkdir -p "$TEST_TEMP_DIR/detection"
    echo "#!/bin/bash" > "$TEST_TEMP_DIR/detection/panels.sh"
    echo "detect_panels() { echo 'manual'; return 0; }" >> "$TEST_TEMP_DIR/detection/panels.sh"
    
    # Sobrescribir detection_load_modules
    detection_load_modules() {
        detection_register_module "panels" "$TEST_TEMP_DIR/detection/panels.sh"
    }
    
    run auto_detect "run"
    assert_success
}

@test "auto_detect summary muestra resumen" {
    # Configurar algunos resultados
    DETECTION_RESULTS["panels"]="cpanel"
    DETECTION_RESULTS["moodle"]="found"
    
    run auto_detect "summary"
    assert_success
    assert_output --partial "MÓDULO"
    assert_output --partial "ESTADO"
}

@test "auto_detect cleanup limpia estado" {
    DETECTION_STARTED=true
    DETECTION_RESULTS["test"]="value"
    
    run auto_detect "cleanup"
    assert_success
    
    assert [ "$DETECTION_STARTED" = "false" ]
}

@test "auto_detect cache-clear limpia cache" {
    detection_cache_init
    detection_cache_set "test" "value"
    
    run auto_detect "cache-clear"
    assert_success
    
    run detection_cache_get "test"
    assert_failure
}

@test "auto_detect comando inválido retorna error" {
    run auto_detect "invalid_command"
    assert_failure
    assert_output --partial "Comando no válido"
}

# ===================== TESTS DE TIMEOUT Y EDGE CASES =====================

@test "detection funciona con cache TTL expirado" {
    detection_cache_init
    
    # Crear archivo de cache con timestamp antiguo
    local cache_file="$DETECTION_CACHE_DIR/test_key.cache"
    echo "old_value" > "$cache_file"
    
    # Modificar timestamp para simular expiración (usar touch si está disponible)
    if command -v touch >/dev/null 2>&1; then
        touch -t 202001010000 "$cache_file" 2>/dev/null || true
    fi
    
    # El cache debería considerarse expirado
    run detection_cache_get "test_key"
    assert_failure
}

@test "detection maneja módulos con función faltante" {
    # Crear módulo sin función detect_
    local test_module="$TEST_TEMP_DIR/incomplete_module.sh"
    echo "#!/bin/bash" > "$test_module"
    echo "# Módulo sin función detect_" >> "$test_module"
    
    detection_register_module "incomplete" "$test_module"
    
    run detection_run_module "incomplete"
    assert_failure
    assert_output --partial "Función de detección no encontrada"
}

@test "detection maneja errores de carga de módulo" {
    # Crear módulo con error de sintaxis
    local bad_module="$TEST_TEMP_DIR/bad_module.sh"
    echo "#!/bin/bash" > "$bad_module"
    echo "this is not valid bash syntax &*@" >> "$bad_module"
    
    detection_register_module "bad" "$bad_module"
    
    run detection_run_module "bad"
    assert_failure
    assert_output --partial "Error cargando módulo"
}
