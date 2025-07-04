#!/usr/bin/env bats

##
# Tests para el Detector de Instalaciones Moodle
# 
# Pruebas unitarias para detección automática de Moodle
##

# Setup y teardown
setup() {
    # Cargar helpers de testing
    load '../../helpers/test_helper'
    load '../../helpers/config_test_helper.bash'
    
    # Configurar entorno de test
    export MOODLE_CLI_TEST_MODE="true"
    export TEST_TEMP_DIR="$(mktemp -d)"
    
    # Crear estructura de directorios simulados
    mkdir -p "$TEST_TEMP_DIR/mock_moodle"
    
    # Cargar módulo bajo test
    source "$PROJECT_ROOT/src/detection/moodle.sh"
}

teardown() {
    # Limpiar estado
    moodle_cleanup
    
    # Limpiar archivos temporales
    [[ -d "$TEST_TEMP_DIR" ]] && rm -rf "$TEST_TEMP_DIR"
}

# ===================== TESTS DE INICIALIZACIÓN =====================

@test "detector de moodle se carga correctamente" {
    run echo "$MOODLE_DETECTOR_LOADED"
    assert_output "true"
}

@test "configuración de búsqueda está definida" {
    assert [ ${#MOODLE_SEARCH_PATHS[@]} -gt 0 ]
    assert [ ${#MOODLE_SIGNATURE_FILES[@]} -gt 0 ]
    assert [ ${#MOODLE_CONFIG_PATTERNS[@]} -gt 0 ]
}

# ===================== TESTS DE VALIDACIÓN CONFIG.PHP =====================

@test "validate_moodle_config acepta config válido" {
    # Crear config.php válido
    local config_file="$TEST_TEMP_DIR/valid_config.php"
    cat > "$config_file" << 'EOF'
<?php
$CFG = new stdClass();
$CFG->dbtype    = 'mysqli';
$CFG->dbhost    = 'localhost';
$CFG->dbname    = 'moodle';
$CFG->dbuser    = 'moodleuser';
$CFG->dbpass    = 'password';
$CFG->wwwroot   = 'http://localhost/moodle';
$CFG->dataroot  = '/var/moodledata';
EOF

    run validate_moodle_config "$config_file"
    assert_success
}

@test "validate_moodle_config rechaza config incompleto" {
    # Crear config.php incompleto
    local config_file="$TEST_TEMP_DIR/incomplete_config.php"
    cat > "$config_file" << 'EOF'
<?php
$CFG = new stdClass();
$CFG->dbtype = 'mysqli';
// Falta configuración crítica
EOF

    run validate_moodle_config "$config_file"
    assert_failure
}

@test "validate_moodle_config falla para archivo inexistente" {
    run validate_moodle_config "/nonexistent/config.php"
    assert_failure
}

# ===================== TESTS DE VALIDACIÓN INSTALACIÓN =====================

@test "validate_moodle_installation acepta instalación válida" {
    # Crear estructura de Moodle válida
    local moodle_dir="$TEST_TEMP_DIR/valid_moodle"
    mkdir -p "$moodle_dir"
    
    # Crear archivos de firma requeridos
    touch "$moodle_dir/version.php"
    mkdir -p "$moodle_dir/lib"
    touch "$moodle_dir/lib/moodlelib.php"
    mkdir -p "$moodle_dir/course"
    touch "$moodle_dir/course/lib.php"
    mkdir -p "$moodle_dir/admin"
    touch "$moodle_dir/admin/index.php"
    
    # Crear config.php válido
    cat > "$moodle_dir/config.php" << 'EOF'
<?php
$CFG = new stdClass();
$CFG->dbtype = 'mysqli';
$CFG->dbhost = 'localhost';
$CFG->dbname = 'moodle';
$CFG->dbuser = 'user';
$CFG->wwwroot = 'http://localhost';
$CFG->dataroot = '/var/data';
EOF

    run validate_moodle_installation "$moodle_dir"
    assert_success
}

@test "validate_moodle_installation rechaza directorio sin archivos de firma" {
    local moodle_dir="$TEST_TEMP_DIR/invalid_moodle"
    mkdir -p "$moodle_dir"
    
    # Solo crear config.php pero sin archivos de firma
    cat > "$moodle_dir/config.php" << 'EOF'
<?php
$CFG = new stdClass();
$CFG->dbtype = 'mysqli';
$CFG->dbhost = 'localhost';
$CFG->dbname = 'moodle';
$CFG->dbuser = 'user';
EOF

    run validate_moodle_installation "$moodle_dir"
    assert_failure
}

@test "validate_moodle_installation falla para directorio inexistente" {
    run validate_moodle_installation "/nonexistent/directory"
    assert_failure
}

# ===================== TESTS DE EXTRACCIÓN DE VERSIÓN =====================

@test "extract_moodle_version extrae versión correctamente" {
    local moodle_dir="$TEST_TEMP_DIR/moodle_with_version"
    mkdir -p "$moodle_dir"
    
    # Crear version.php con versión de 2023 (Moodle 4.2-4.3)
    cat > "$moodle_dir/version.php" << 'EOF'
<?php
defined('MOODLE_INTERNAL') || die();
$version  = 2023042400;
$release  = '4.2.0';
$branch   = '402';
EOF

    run extract_moodle_version "$moodle_dir"
    assert_success
    assert_output "4.2-4.3"
}

@test "extract_moodle_version maneja versión desconocida" {
    local moodle_dir="$TEST_TEMP_DIR/moodle_unknown_version"
    mkdir -p "$moodle_dir"
    
    # Crear version.php con formato inválido
    cat > "$moodle_dir/version.php" << 'EOF'
<?php
// Sin variable $version válida
$invalid = "not a version";
EOF

    run extract_moodle_version "$moodle_dir"
    assert_success
    assert_output "desconocida"
}

@test "extract_moodle_version maneja archivo faltante" {
    local moodle_dir="$TEST_TEMP_DIR/moodle_no_version"
    mkdir -p "$moodle_dir"
    
    run extract_moodle_version "$moodle_dir"
    assert_success
    assert_output "desconocida"
}

# ===================== TESTS DE EXTRACCIÓN DE CONFIG DB =====================

@test "extract_moodle_database_config extrae configuración completa" {
    local moodle_dir="$TEST_TEMP_DIR/moodle_db_config"
    mkdir -p "$moodle_dir"
    
    cat > "$moodle_dir/config.php" << 'EOF'
<?php
$CFG = new stdClass();
$CFG->dbtype = 'mysqli';
$CFG->dbhost = 'localhost';
$CFG->dbname = 'moodledb';
$CFG->dbuser = 'moodleuser';
$CFG->dbpass = 'secret123';
$CFG->dbport = '3306';
EOF

    run extract_moodle_database_config "$moodle_dir"
    assert_success
    assert_output --partial "tipo:mysqli"
    assert_output --partial "host:localhost"
    assert_output --partial "db:moodledb"
    assert_output --partial "usuario:moodleuser"
    assert_output --partial "puerto:3306"
}

@test "extract_moodle_database_config maneja config faltante" {
    local moodle_dir="$TEST_TEMP_DIR/moodle_no_config"
    mkdir -p "$moodle_dir"
    
    run extract_moodle_database_config "$moodle_dir"
    assert_success
    assert_output "no_config"
}

# ===================== TESTS DE EXTRACCIÓN DE DIRECTORIOS =====================

@test "extract_moodle_directories extrae rutas correctamente" {
    local moodle_dir="$TEST_TEMP_DIR/moodle_dirs"
    mkdir -p "$moodle_dir"
    
    cat > "$moodle_dir/config.php" << 'EOF'
<?php
$CFG = new stdClass();
$CFG->wwwroot = 'http://example.com/moodle';
$CFG->dataroot = '/var/moodledata';
EOF

    run extract_moodle_directories "$moodle_dir"
    assert_success
    assert_output --partial "wwwroot:http://example.com/moodle"
    assert_output --partial "dataroot:/var/moodledata"
}

# ===================== TESTS DE ANÁLISIS COMPLETO =====================

@test "analyze_moodle_installation genera análisis completo" {
    # Crear instalación Moodle completa
    local moodle_dir="$TEST_TEMP_DIR/complete_moodle"
    mkdir -p "$moodle_dir"
    
    # Version.php
    cat > "$moodle_dir/version.php" << 'EOF'
<?php
$version = 2023042400;
EOF

    # Config.php
    cat > "$moodle_dir/config.php" << 'EOF'
<?php
$CFG = new stdClass();
$CFG->dbtype = 'mysqli';
$CFG->dbhost = 'localhost';
$CFG->dbname = 'moodle';
$CFG->dbuser = 'user';
$CFG->wwwroot = 'http://localhost';
$CFG->dataroot = '/var/data';
EOF

    run analyze_moodle_installation "$moodle_dir"
    assert_success
    assert_output --partial "path:$moodle_dir"
    assert_output --partial "version:"
    assert_output --partial "database:"
    assert_output --partial "directories:"
    assert_output --partial "permissions:"
    assert_output --partial "activity:"
}

# ===================== TESTS DE BÚSQUEDA =====================

@test "search_moodle_in_directory encuentra instalaciones válidas" {
    # Crear estructura de búsqueda
    local search_dir="$TEST_TEMP_DIR/web_root"
    local moodle_dir="$search_dir/moodle"
    mkdir -p "$moodle_dir"
    
    # Crear instalación Moodle válida
    touch "$moodle_dir/version.php"
    mkdir -p "$moodle_dir/lib"
    touch "$moodle_dir/lib/moodlelib.php"
    mkdir -p "$moodle_dir/course"
    touch "$moodle_dir/course/lib.php"
    
    cat > "$moodle_dir/config.php" << 'EOF'
<?php
$CFG = new stdClass();
$CFG->dbtype = 'mysqli';
$CFG->dbhost = 'localhost';
$CFG->dbname = 'moodle';
$CFG->dbuser = 'user';
$CFG->wwwroot = 'http://localhost';
$CFG->dataroot = '/var/data';
EOF

    # Mock find para evitar problemas de timeout
    find() {
        local search_path="$1"
        shift
        echo "$moodle_dir/config.php"
    }
    export -f find
    
    run search_moodle_in_directory "$search_dir"
    assert_success
    
    # Verificar que se añadió a DETECTED_MOODLES
    assert [ ${#DETECTED_MOODLES[@]} -gt 0 ]
}

@test "search_moodle_in_directory ignora instalaciones inválidas" {
    local search_dir="$TEST_TEMP_DIR/web_root"
    local fake_moodle="$search_dir/fake_moodle"
    mkdir -p "$fake_moodle"
    
    # Crear solo config.php sin archivos de firma
    cat > "$fake_moodle/config.php" << 'EOF'
<?php
$CFG = new stdClass();
$CFG->dbtype = 'mysqli';
EOF

    # Mock find
    find() {
        echo "$fake_moodle/config.php"
    }
    export -f find
    
    run search_moodle_in_directory "$search_dir"
    assert_success
    
    # No debe haber detectado nada
    assert [ ${#DETECTED_MOODLES[@]} -eq 0 ]
}

@test "search_all_moodle_installations busca en múltiples rutas" {
    # Crear múltiples instalaciones
    local moodle1="$TEST_TEMP_DIR/web1/moodle"
    local moodle2="$TEST_TEMP_DIR/web2/moodle"
    
    for moodle_dir in "$moodle1" "$moodle2"; do
        mkdir -p "$moodle_dir"
        touch "$moodle_dir/version.php"
        mkdir -p "$moodle_dir/lib"
        touch "$moodle_dir/lib/moodlelib.php"
        mkdir -p "$moodle_dir/course"
        touch "$moodle_dir/course/lib.php"
        
        cat > "$moodle_dir/config.php" << 'EOF'
<?php
$CFG = new stdClass();
$CFG->dbtype = 'mysqli';
$CFG->dbhost = 'localhost';
$CFG->dbname = 'moodle';
$CFG->dbuser = 'user';
$CFG->wwwroot = 'http://localhost';
$CFG->dataroot = '/var/data';
EOF
    done
    
    # Sobrescribir rutas de búsqueda
    MOODLE_SEARCH_PATHS=("$TEST_TEMP_DIR/web1" "$TEST_TEMP_DIR/web2")
    
    # Mock find para retornar ambas instalaciones
    find() {
        case "$1" in
            *web1*) echo "$moodle1/config.php" ;;
            *web2*) echo "$moodle2/config.php" ;;
        esac
    }
    export -f find
    
    run search_all_moodle_installations
    assert_success
    
    # Debe haber encontrado 2 instalaciones
    assert [ ${#DETECTED_MOODLES[@]} -eq 2 ]
}

# ===================== TESTS DE FUNCIÓN PRINCIPAL =====================

@test "detect_moodle search retorna instalaciones encontradas" {
    # Configurar instalación simulada
    DETECTED_MOODLES=("/var/www/moodle" "/home/user/moodle")
    MOODLE_DETECTION_STARTED=true
    
    run detect_moodle "search"
    assert_success
    assert_line "/var/www/moodle"
    assert_line "/home/user/moodle"
}

@test "detect_moodle count retorna número de instalaciones" {
    DETECTED_MOODLES=("/var/www/moodle" "/home/user/moodle")
    MOODLE_DETECTION_STARTED=true
    
    run detect_moodle "count"
    assert_success
    assert_output "2"
}

@test "detect_moodle analyze analiza instalación específica" {
    local moodle_dir="$TEST_TEMP_DIR/analyze_moodle"
    mkdir -p "$moodle_dir"
    
    cat > "$moodle_dir/version.php" << 'EOF'
<?php
$version = 2023042400;
EOF

    cat > "$moodle_dir/config.php" << 'EOF'
<?php
$CFG = new stdClass();
$CFG->dbtype = 'mysqli';
$CFG->dbhost = 'localhost';
$CFG->dbname = 'moodle';
$CFG->dbuser = 'user';
EOF

    run detect_moodle "analyze" "$moodle_dir"
    assert_success
    assert_output --partial "path:$moodle_dir"
}

@test "detect_moodle analyze falla sin parámetro" {
    run detect_moodle "analyze"
    assert_failure
    assert_output --partial "Se requiere una ruta para analizar"
}

@test "detect_moodle falla con comando inválido" {
    run detect_moodle "invalid_command"
    assert_failure
    assert_output --partial "Comando no válido"
}

# ===================== TESTS DE FUNCIONES AUXILIARES =====================

@test "get_primary_moodle retorna primera instalación" {
    DETECTED_MOODLES=("/var/www/moodle" "/home/user/moodle")
    
    run get_primary_moodle
    assert_success
    assert_output "/var/www/moodle"
}

@test "get_primary_moodle falla sin instalaciones" {
    DETECTED_MOODLES=()
    
    run get_primary_moodle
    assert_failure
}

@test "has_multiple_moodles detecta múltiples instalaciones" {
    DETECTED_MOODLES=("/var/www/moodle" "/home/user/moodle")
    
    run has_multiple_moodles
    assert_success
}

@test "has_multiple_moodles falla con una sola instalación" {
    DETECTED_MOODLES=("/var/www/moodle")
    
    run has_multiple_moodles
    assert_failure
}

# ===================== TESTS DE SELECCIÓN INTERACTIVA =====================

@test "select_moodle_installation retorna única instalación automáticamente" {
    DETECTED_MOODLES=("/var/www/moodle")
    
    run select_moodle_installation
    assert_success
    assert_output "/var/www/moodle"
}

@test "select_moodle_installation falla sin instalaciones" {
    DETECTED_MOODLES=()
    
    run select_moodle_installation
    assert_failure
}

@test "show_moodle_installations muestra tabla formateada" {
    DETECTED_MOODLES=("/var/www/moodle" "/home/user/moodle")
    
    # Mock extract_moodle_version
    extract_moodle_version() {
        case "$1" in
            */moodle) echo "4.2" ;;
            */user/moodle) echo "4.1" ;;
        esac
    }
    export -f extract_moodle_version
    
    run show_moodle_installations
    assert_success
    assert_output --partial "RUTA DE INSTALACIÓN"
    assert_output --partial "VERSIÓN"
    assert_output --partial "/var/www/moodle"
    assert_output --partial "/home/user/moodle"
}

@test "show_moodle_installations falla sin instalaciones" {
    DETECTED_MOODLES=()
    
    run show_moodle_installations
    assert_failure
    assert_output "No se encontraron instalaciones Moodle"
}

# ===================== TESTS DE EDGE CASES =====================

@test "detección maneja permisos de archivos limitados" {
    local moodle_dir="$TEST_TEMP_DIR/restricted_moodle"
    mkdir -p "$moodle_dir"
    
    # Crear config.php sin permisos de lectura
    echo "test" > "$moodle_dir/config.php"
    chmod 000 "$moodle_dir/config.php"
    
    run validate_moodle_config "$moodle_dir/config.php"
    assert_failure
}

@test "búsqueda maneja directorios inexistentes" {
    run search_moodle_in_directory "/absolutely/nonexistent/directory"
    assert_failure
}

@test "extracción maneja archivos PHP corruptos" {
    local moodle_dir="$TEST_TEMP_DIR/corrupt_moodle"
    mkdir -p "$moodle_dir"
    
    # Crear archivo con sintaxis PHP inválida
    echo "<?php this is not valid PHP syntax" > "$moodle_dir/config.php"
    
    run extract_moodle_database_config "$moodle_dir"
    assert_success
    # Debe manejar graciosamente y retornar valores por defecto
}

@test "moodle_cleanup resetea estado correctamente" {
    # Configurar estado
    MOODLE_DETECTION_STARTED=true
    DETECTED_MOODLES=("/test/path")
    MOODLE_DETAILS[test]="test_value"
    
    run moodle_cleanup
    assert_success
    
    # Verificar limpieza
    assert [ "$MOODLE_DETECTION_STARTED" = "false" ]
    assert [ ${#DETECTED_MOODLES[@]} -eq 0 ]
    assert [ ${#MOODLE_DETAILS[@]} -eq 0 ]
}

# ===================== TESTS DE TIMEOUT Y PERFORMANCE =====================

@test "búsqueda maneja timeout en find" {
    # Mock timeout command
    timeout() {
        if [[ "$1" == "1" ]]; then
            return 124  # Timeout exit code
        fi
        shift
        "$@"
    }
    export -f timeout
    
    # Configurar timeout muy corto
    export MOODLE_SEARCH_TIMEOUT=1
    
    run search_moodle_in_directory "$TEST_TEMP_DIR"
    # No debe fallar completamente por timeout
    assert [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "detección funciona sin comando timeout" {
    # Mock command para indicar que timeout no existe
    command() {
        if [[ "$1" == "-v" && "$2" == "timeout" ]]; then
            return 1
        fi
        return 0
    }
    export -f command
    
    run search_moodle_in_directory "$TEST_TEMP_DIR"
    # Debe funcionar sin timeout
    assert_success
}
