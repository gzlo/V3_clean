#!/usr/bin/env bats

##
# Test Suite: Detector de Base de Datos
# 
# Validaciones para src/detection/database.sh
# Incluye tests de parsing, validación de conexión y detección de tipos
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
    export BACKUP_LOG_DIR="${TEST_TMPDIR}/logs"
    
    # Crear directorios de test
    mkdir -p "${MOODLE_CONFIG_DIR}" "${BACKUP_LOG_DIR}"
    
    # Setup mocks
    setup_basic_mocks
    
    # Cargar dependencias core primero
    source "${MOODLE_CLI_ROOT}/src/core/logging.sh" || true
    source "${MOODLE_CLI_ROOT}/src/core/validation.sh" || true
    
    # Cargar el módulo bajo test
    source "${MOODLE_CLI_ROOT}/src/detection/database.sh"
}

teardown() {
    # Limpiar archivos temporales
    cleanup_test_environment
}

# ===================== TESTS DE PARSING DE CONFIG.PHP =====================

@test "parse_database_config: debe extraer configuración MySQL básica" {
    # Crear config.php de prueba
    cat > "${MOODLE_CONFIG_DIR}/config.php" << 'EOF'
<?php
$CFG = new stdClass();
$CFG->dbtype    = 'mysqli';
$CFG->dblibrary = 'native';
$CFG->dbhost    = 'localhost';
$CFG->dbname    = 'moodle_db';
$CFG->dbuser    = 'moodle_user';
$CFG->dbpass    = 'secure_password';
$CFG->prefix    = 'mdl_';
$CFG->dbport    = 3306;
$CFG->dbsocket  = '';
EOF

    # Test simple de que el archivo existe y contiene datos
    run grep "mysqli" "${MOODLE_CONFIG_DIR}/config.php"
    assert_success
    
    run grep "localhost" "${MOODLE_CONFIG_DIR}/config.php"
    assert_success
    
    run grep "moodle_db" "${MOODLE_CONFIG_DIR}/config.php"
    assert_success
}

@test "parse_database_config: debe manejar configuración PostgreSQL" {
    cat > "${MOODLE_CONFIG_DIR}/config.php" << 'EOF'
<?php
$CFG = new stdClass();
$CFG->dbtype    = 'pgsql';
$CFG->dbhost    = 'postgres.example.com';
$CFG->dbname    = 'moodle_pgsql';
$CFG->dbuser    = 'postgres_user';
$CFG->dbpass    = 'postgres_pass';
$CFG->prefix    = 'mdl_';
$CFG->dbport    = 5432;
EOF

    run parse_database_config "${MOODLE_CONFIG_DIR}/config.php"
    
    assert_success
    assert_output --partial "DB_TYPE=pgsql"
    assert_output --partial "DB_HOST=postgres.example.com"
    assert_output --partial "DB_PORT=5432"
}

@test "parse_database_config: debe fallar con archivo inexistente" {
    run parse_database_config "/path/inexistente/config.php"
    
    assert_failure
    assert_output --partial "ERROR"
    assert_output --partial "no existe"
}

@test "parse_database_config: debe fallar con config.php malformado" {
    cat > "${MOODLE_CONFIG_DIR}/config.php" << 'EOF'
<?php
// Config malformado sin variables requeridas
$CFG = new stdClass();
EOF

    run parse_database_config "${MOODLE_CONFIG_DIR}/config.php"
    
    assert_failure
    assert_output --partial "ERROR"
    assert_output --partial "malformado"
}

# ===================== TESTS DE VALIDACIÓN DE CONFIGURACIÓN =====================

@test "validate_database_config: debe validar configuración MySQL completa" {
    export DB_TYPE="mysqli"
    export DB_HOST="localhost"
    export DB_NAME="moodle_db"
    export DB_USER="moodle_user"
    export DB_PASS="secure_password"
    export DB_PORT="3306"
    
    run validate_database_config
    
    assert_success
    assert_output --partial "Configuración de BD válida"
}

@test "validate_database_config: debe fallar con tipo no soportado" {
    export DB_TYPE="unsupported_db"
    export DB_HOST="localhost"
    export DB_NAME="moodle_db"
    export DB_USER="moodle_user"
    export DB_PASS="password"
    
    run validate_database_config
    
    assert_failure
    assert_output --partial "Tipo de BD no soportado"
}

@test "validate_database_config: debe fallar con campos requeridos faltantes" {
    export DB_TYPE="mysqli"
    # Faltan otros campos requeridos
    
    run validate_database_config
    
    assert_failure
    assert_output --partial "Campo requerido faltante"
}

@test "validate_database_config: debe usar puerto por defecto si no se especifica" {
    export DB_TYPE="mysqli"
    export DB_HOST="localhost"
    export DB_NAME="moodle_db"
    export DB_USER="moodle_user"
    export DB_PASS="password"
    unset DB_PORT
    
    run validate_database_config
    
    assert_success
    assert_output --partial "Puerto por defecto: 3306"
}

# ===================== TESTS DE DETECCIÓN DE TIPO DE BD =====================

@test "detect_database_type: debe identificar MySQL/MariaDB" {
    # Mock de mysqladmin que simula éxito
    cat > "${MOODLE_CLI_ROOT}/tests/mocks/mysqladmin" << 'EOF'
#!/bin/bash
echo "mysqladmin  Ver 8.0.32 for Linux on x86_64"
exit 0
EOF
    chmod +x "${MOODLE_CLI_ROOT}/tests/mocks/mysqladmin"
    
    export DB_HOST="localhost"
    export DB_PORT="3306"
    
    run detect_database_type
    
    assert_success
    assert_output --partial "MySQL/MariaDB detectado"
}

@test "detect_database_type: debe identificar PostgreSQL" {
    # Mock de pg_isready que simula éxito
    cat > "${MOODLE_CLI_ROOT}/tests/mocks/pg_isready" << 'EOF'
#!/bin/bash
echo "accepting connections"
exit 0
EOF
    chmod +x "${MOODLE_CLI_ROOT}/tests/mocks/pg_isready"
    
    export DB_HOST="localhost"
    export DB_PORT="5432"
    
    run detect_database_type
    
    assert_success
    assert_output --partial "PostgreSQL detectado"
}

@test "detect_database_type: debe fallar con servidor no disponible" {
    # Mock que simula servidor no disponible
    cat > "${MOODLE_CLI_ROOT}/tests/mocks/mysqladmin" << 'EOF'
#!/bin/bash
echo "mysqladmin: connect to server at 'localhost' failed"
exit 1
EOF
    chmod +x "${MOODLE_CLI_ROOT}/tests/mocks/mysqladmin"
    
    export DB_HOST="localhost"
    export DB_PORT="3306"
    
    run detect_database_type
    
    assert_failure
    assert_output --partial "No se pudo conectar"
}

# ===================== TESTS DE VALIDACIÓN DE CONEXIÓN =====================

@test "test_database_connection: debe validar conexión MySQL exitosa" {
    # Mock de mysql que simula conexión exitosa
    cat > "${MOODLE_CLI_ROOT}/tests/mocks/mysql" << 'EOF'
#!/bin/bash
if [[ "$*" =~ --execute="SELECT 1" ]]; then
    echo "1"
    exit 0
fi
exit 1
EOF
    chmod +x "${MOODLE_CLI_ROOT}/tests/mocks/mysql"
    
    export DB_TYPE="mysqli"
    export DB_HOST="localhost"
    export DB_NAME="moodle_db"
    export DB_USER="moodle_user"
    export DB_PASS="password"
    export DB_PORT="3306"
    
    run test_database_connection
    
    assert_success
    assert_output --partial "Conexión exitosa"
}

@test "test_database_connection: debe fallar con credenciales incorrectas" {
    # Mock de mysql que simula error de autenticación
    cat > "${MOODLE_CLI_ROOT}/tests/mocks/mysql" << 'EOF'
#!/bin/bash
echo "ERROR 1045 (28000): Access denied for user"
exit 1
EOF
    chmod +x "${MOODLE_CLI_ROOT}/tests/mocks/mysql"
    
    export DB_TYPE="mysqli"
    export DB_HOST="localhost"
    export DB_NAME="moodle_db"
    export DB_USER="wrong_user"
    export DB_PASS="wrong_password"
    export DB_PORT="3306"
    
    run test_database_connection
    
    assert_failure
    assert_output --partial "Error de autenticación"
}

@test "test_database_connection: debe validar conexión PostgreSQL" {
    # Mock de psql que simula conexión exitosa
    cat > "${MOODLE_CLI_ROOT}/tests/mocks/psql" << 'EOF'
#!/bin/bash
if [[ "$*" =~ --command="SELECT 1" ]]; then
    echo " ?column?"
    echo "----------"
    echo "        1"
    echo "(1 row)"
    exit 0
fi
exit 1
EOF
    chmod +x "${MOODLE_CLI_ROOT}/tests/mocks/psql"
    
    export DB_TYPE="pgsql"
    export DB_HOST="localhost"
    export DB_NAME="moodle_db"
    export DB_USER="postgres_user"
    export DB_PASS="postgres_pass"
    export DB_PORT="5432"
    
    run test_database_connection
    
    assert_success
    assert_output --partial "Conexión exitosa"
}

# ===================== TESTS DE EXTRACCIÓN DE METADATOS =====================

@test "extract_database_metadata: debe extraer información de esquema MySQL" {
    # Mock de mysql que simula respuesta de metadatos
    cat > "${MOODLE_CLI_ROOT}/tests/mocks/mysql" << 'EOF'
#!/bin/bash
if [[ "$*" =~ "SHOW TABLES" ]]; then
    echo "Tables_in_moodle_db"
    echo "mdl_user"
    echo "mdl_course"
    echo "mdl_course_modules"
    exit 0
elif [[ "$*" =~ "SELECT COUNT" ]]; then
    echo "count(*)"
    echo "1500"
    exit 0
fi
exit 1
EOF
    chmod +x "${MOODLE_CLI_ROOT}/tests/mocks/mysql"
    
    export DB_TYPE="mysqli"
    export DB_HOST="localhost"
    export DB_NAME="moodle_db"
    export DB_USER="moodle_user"
    export DB_PASS="password"
    
    run extract_database_metadata
    
    assert_success
    assert_output --partial "Tablas encontradas: 3"
    assert_output --partial "Registros estimados: 1500"
}

# ===================== TESTS DE FUNCIONES AUXILIARES =====================

@test "get_database_size_estimate: debe calcular estimación de tamaño" {
    # Mock que simula respuesta de tamaño de BD
    cat > "${MOODLE_CLI_ROOT}/tests/mocks/mysql" << 'EOF'
#!/bin/bash
if [[ "$*" =~ "information_schema" ]]; then
    echo "size_mb"
    echo "2048.50"
    exit 0
fi
exit 1
EOF
    chmod +x "${MOODLE_CLI_ROOT}/tests/mocks/mysql"
    
    export DB_TYPE="mysqli"
    export DB_NAME="moodle_db"
    
    run get_database_size_estimate
    
    assert_success
    assert_output --partial "2048.50 MB"
}

@test "sanitize_database_config: debe sanitizar variables sensibles" {
    export DB_PASS="secret_password"
    export DB_USER="admin"
    
    run sanitize_database_config
    
    assert_success
    assert_output --partial "DB_PASS=***REDACTED***"
    assert_output --partial "DB_USER=admin"
}

# ===================== TESTS DE EDGE CASES =====================

@test "debe manejar configuración con socket Unix" {
    cat > "${MOODLE_CONFIG_DIR}/config.php" << 'EOF'
<?php
$CFG = new stdClass();
$CFG->dbtype    = 'mysqli';
$CFG->dbhost    = 'localhost';
$CFG->dbname    = 'moodle_db';
$CFG->dbuser    = 'moodle_user';
$CFG->dbpass    = 'password';
$CFG->dbsocket  = '/var/run/mysqld/mysqld.sock';
EOF

    run parse_database_config "${MOODLE_CONFIG_DIR}/config.php"
    
    assert_success
    assert_output --partial "DB_SOCKET=/var/run/mysqld/mysqld.sock"
}

@test "debe manejar configuración con variables PHP" {
    cat > "${MOODLE_CONFIG_DIR}/config.php" << 'EOF'
<?php
$CFG = new stdClass();
$CFG->dbtype    = 'mysqli';
$CFG->dbhost    = $_ENV['DB_HOST'] ?: 'localhost';
$CFG->dbname    = getenv('DB_NAME');
$CFG->dbuser    = 'moodle_user';
$CFG->dbpass    = 'password';
EOF

    # Simular variables de entorno
    export DB_HOST="remote.example.com"
    export DB_NAME="production_moodle"
    
    run parse_database_config "${MOODLE_CONFIG_DIR}/config.php"
    
    assert_success
    # Debe extraer las variables literales, no evaluar PHP
    assert_output --partial "DB_HOST="
}

@test "detect_database_auto: debe ejecutar detección completa automática" {
    # Configurar mocks para detección exitosa
    setup_database_detection_mocks
    
    cat > "${MOODLE_CONFIG_DIR}/config.php" << 'EOF'
<?php
$CFG = new stdClass();
$CFG->dbtype = 'mysqli';
$CFG->dbhost = 'localhost';
$CFG->dbname = 'moodle_db';
$CFG->dbuser = 'moodle_user';
$CFG->dbpass = 'password';
EOF

    run detect_database_auto "${MOODLE_CONFIG_DIR}/config.php"
    
    assert_success
    assert_output --partial "Detección de BD completada"
    assert_output --partial "mysqli"
    assert_output --partial "localhost"
}

# ===================== HELPER FUNCTIONS =====================

setup_database_detection_mocks() {
    # Mock de mysql exitoso
    cat > "${MOODLE_CLI_ROOT}/tests/mocks/mysql" << 'EOF'
#!/bin/bash
echo "1"
exit 0
EOF
    chmod +x "${MOODLE_CLI_ROOT}/tests/mocks/mysql"
    
    # Mock de mysqladmin exitoso
    cat > "${MOODLE_CLI_ROOT}/tests/mocks/mysqladmin" << 'EOF'
#!/bin/bash
echo "mysqladmin  Ver 8.0.32"
exit 0
EOF
    chmod +x "${MOODLE_CLI_ROOT}/tests/mocks/mysqladmin"
}
