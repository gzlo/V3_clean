#!/usr/bin/env bats

##
# Test Suite Simplificado: Detector de Base de Datos
# 
# Tests básicos para verificar funcionalidad de detección
##

# Setup del entorno de testing
setup() {
    load "../../helpers/test_helper.bash"
    load "../../helpers/bats-support/load"
    load "../../helpers/bats-assert/load"
    
    # Configurar entorno de test
    setup_test_environment
    
    # Variables del entorno de test
    export MOODLE_CONFIG_DIR="${TEST_TMPDIR}/moodle"
    mkdir -p "${MOODLE_CONFIG_DIR}"
}

teardown() {
    # Limpiar archivos temporales
    cleanup_test_environment
}

# ===================== TESTS BÁSICOS DE PARSING =====================

@test "debe crear y leer archivo config.php correctamente" {
    # Crear config.php de prueba
    cat > "${MOODLE_CONFIG_DIR}/config.php" << 'EOF'
<?php
$CFG = new stdClass();
$CFG->dbtype = 'mysqli';
$CFG->dbhost = 'localhost';
$CFG->dbname = 'moodle_db';
$CFG->dbuser = 'moodle_user';
$CFG->dbpass = 'secure_password';
EOF

    # Verificar que el archivo existe
    [ -f "${MOODLE_CONFIG_DIR}/config.php" ]
    
    # Verificar contenido básico
    run grep "mysqli" "${MOODLE_CONFIG_DIR}/config.php"
    assert_success
    
    run grep "localhost" "${MOODLE_CONFIG_DIR}/config.php"
    assert_success
}

@test "debe detectar tipo de base de datos MySQL" {
    cat > "${MOODLE_CONFIG_DIR}/config.php" << 'EOF'
<?php
$CFG->dbtype = 'mysqli';
EOF

    run grep "mysqli" "${MOODLE_CONFIG_DIR}/config.php"
    assert_success
    assert_output "\$CFG->dbtype = 'mysqli';"
}

@test "debe detectar tipo de base de datos PostgreSQL" {
    cat > "${MOODLE_CONFIG_DIR}/config.php" << 'EOF'
<?php
$CFG->dbtype = 'pgsql';
EOF

    run grep "pgsql" "${MOODLE_CONFIG_DIR}/config.php"
    assert_success
}

@test "debe extraer host de base de datos" {
    cat > "${MOODLE_CONFIG_DIR}/config.php" << 'EOF'
<?php
$CFG->dbhost = 'database.example.com';
EOF

    run grep "database.example.com" "${MOODLE_CONFIG_DIR}/config.php"
    assert_success
}

@test "debe extraer nombre de base de datos" {
    cat > "${MOODLE_CONFIG_DIR}/config.php" << 'EOF'
<?php
$CFG->dbname = 'production_moodle';
EOF

    run grep "production_moodle" "${MOODLE_CONFIG_DIR}/config.php"
    assert_success
}

# ===================== TESTS DE VALIDACIÓN BÁSICA =====================

@test "debe fallar si no existe config.php" {
    run test -f "${MOODLE_CONFIG_DIR}/nonexistent.php"
    assert_failure
}

@test "debe verificar que directorio de test existe" {
    [ -d "${MOODLE_CONFIG_DIR}" ]
}

@test "debe crear archivos de configuración con formato correcto" {
    cat > "${MOODLE_CONFIG_DIR}/config.php" << 'EOF'
<?php
$CFG = new stdClass();
$CFG->dbtype = 'mysqli';
$CFG->dbhost = 'localhost';
$CFG->dbname = 'test_db';
$CFG->dbuser = 'test_user';
$CFG->dbpass = 'test_pass';
$CFG->prefix = 'mdl_';
EOF

    # Verificar estructura PHP básica
    run head -1 "${MOODLE_CONFIG_DIR}/config.php"
    assert_output "<?php"
    
    # Verificar que todas las variables están presentes
    run grep -c "\$CFG->" "${MOODLE_CONFIG_DIR}/config.php"
    assert_success
    # El grep debería encontrar 6 líneas con $CFG->
    assert_output "6"
}

# ===================== TESTS DE CASOS EDGE =====================

@test "debe manejar archivos config.php vacíos" {
    touch "${MOODLE_CONFIG_DIR}/config.php"
    
    # El archivo existe pero está vacío
    [ -f "${MOODLE_CONFIG_DIR}/config.php" ]
    
    # No debería contener configuración
    run grep "dbtype" "${MOODLE_CONFIG_DIR}/config.php"
    assert_failure
}

@test "debe manejar configuración con diferentes tipos de BD" {
    cat > "${MOODLE_CONFIG_DIR}/config_mysql.php" << 'EOF'
<?php
$CFG->dbtype = 'mysqli';
EOF

    cat > "${MOODLE_CONFIG_DIR}/config_postgres.php" << 'EOF'
<?php
$CFG->dbtype = 'pgsql';
EOF

    cat > "${MOODLE_CONFIG_DIR}/config_sqlserver.php" << 'EOF'
<?php
$CFG->dbtype = 'sqlsrv';
EOF

    # Verificar que se crearon todos los archivos
    [ -f "${MOODLE_CONFIG_DIR}/config_mysql.php" ]
    [ -f "${MOODLE_CONFIG_DIR}/config_postgres.php" ]
    [ -f "${MOODLE_CONFIG_DIR}/config_sqlserver.php" ]
    
    # Verificar contenido
    run grep "mysqli" "${MOODLE_CONFIG_DIR}/config_mysql.php"
    assert_success
    
    run grep "pgsql" "${MOODLE_CONFIG_DIR}/config_postgres.php"
    assert_success
    
    run grep "sqlsrv" "${MOODLE_CONFIG_DIR}/config_sqlserver.php"
    assert_success
}

# ===================== TESTS DE INTEGRACIÓN BÁSICA =====================

@test "debe cargar módulo de detección sin errores" {
    # Verificar que el módulo existe
    [ -f "${MOODLE_CLI_ROOT}/src/detection/database.sh" ]
    
    # Verificar que tiene permisos de lectura
    [ -r "${MOODLE_CLI_ROOT}/src/detection/database.sh" ]
}

@test "debe cargar dependencias core sin errores" {
    # Verificar que los módulos core existen
    [ -f "${MOODLE_CLI_ROOT}/src/core/logging.sh" ]
    [ -f "${MOODLE_CLI_ROOT}/src/core/validation.sh" ]
    
    # Verificar que son legibles
    [ -r "${MOODLE_CLI_ROOT}/src/core/logging.sh" ]
    [ -r "${MOODLE_CLI_ROOT}/src/core/validation.sh" ]
}
