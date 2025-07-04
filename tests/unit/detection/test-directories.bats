#!/usr/bin/env bats

##
# Test Suite: Detector de Directorios
# 
# Validaciones para src/detection/directories.sh
# Incluye tests de detección de paths, validación de permisos y auto-discovery
##

# Setup del entorno de testing
setup() {
    load "../../helpers/test_helper"
    load "../../helpers/bats-support/load"
    load "../../helpers/bats-assert/load"
    
    # Cargar fixtures de detección
    load "../../fixtures/detection_fixtures.sh"
    
    # Variables del entorno de test
    export TEST_BASE_DIR="${BATS_TEST_TMPDIR}"
    export MOCK_FILESYSTEM_ROOT="${TEST_BASE_DIR}/mock_filesystem"
    export BACKUP_LOG_DIR="${TEST_BASE_DIR}/logs"
    
    # Crear estructura de directorios de prueba
    create_mock_filesystem_structure
    
    # Cargar el módulo bajo test
    source "${MOODLE_CLI_ROOT}/src/detection/directories.sh"
    
    # Mock de comandos del sistema
    export PATH="${MOODLE_CLI_ROOT}/tests/mocks:${PATH}"
}

teardown() {
    # Limpiar archivos temporales
    if [[ -n "${TEST_BASE_DIR:-}" && -d "${TEST_BASE_DIR}" ]]; then
        rm -rf "${TEST_BASE_DIR}"
    fi
}

# ===================== HELPER PARA CREAR ESTRUCTURA MOCK =====================

create_mock_filesystem_structure() {
    mkdir -p "${BACKUP_LOG_DIR}"
    mkdir -p "${MOCK_FILESYSTEM_ROOT}"
    
    # Estructura típica de cPanel
    mkdir -p "${MOCK_FILESYSTEM_ROOT}/home/user1/public_html/moodle"
    mkdir -p "${MOCK_FILESYSTEM_ROOT}/home/user1/public_html/subdomain.domain.com"
    mkdir -p "${MOCK_FILESYSTEM_ROOT}/home/user1/moodledata"
    
    # Estructura típica de Plesk
    mkdir -p "${MOCK_FILESYSTEM_ROOT}/var/www/vhosts/domain.com/httpdocs/moodle"
    mkdir -p "${MOCK_FILESYSTEM_ROOT}/var/www/vhosts/domain.com/moodledata"
    
    # Estructura típica de VestaCP
    mkdir -p "${MOCK_FILESYSTEM_ROOT}/home/user2/web/domain.com/public_html"
    mkdir -p "${MOCK_FILESYSTEM_ROOT}/home/user2/web/domain.com/private"
    
    # Directorios estándar de sistema
    mkdir -p "${MOCK_FILESYSTEM_ROOT}/var/www/html"
    mkdir -p "${MOCK_FILESYSTEM_ROOT}/usr/share/nginx/html"
    mkdir -p "${MOCK_FILESYSTEM_ROOT}/opt/moodle"
    
    # Crear archivos de configuración de Moodle para identificación
    cat > "${MOCK_FILESYSTEM_ROOT}/home/user1/public_html/moodle/config.php" << 'EOF'
<?php
$CFG = new stdClass();
$CFG->wwwroot = 'https://domain.com/moodle';
$CFG->dataroot = '/home/user1/moodledata';
EOF
    
    cat > "${MOCK_FILESYSTEM_ROOT}/var/www/vhosts/domain.com/httpdocs/moodle/config.php" << 'EOF'
<?php
$CFG = new stdClass();
$CFG->wwwroot = 'https://plesk.domain.com/moodle';
$CFG->dataroot = '/var/www/vhosts/domain.com/moodledata';
EOF
}

# ===================== TESTS DE DETECCIÓN DE PANELES =====================

@test "detect_panel_type: debe detectar cPanel" {
    # Mock de estructura cPanel
    mkdir -p "${MOCK_FILESYSTEM_ROOT}/usr/local/cpanel"
    mkdir -p "${MOCK_FILESYSTEM_ROOT}/var/cpanel"
    
    # Mock del comando de detección
    cat > "${MOODLE_CLI_ROOT}/tests/mocks/ls" << 'EOF'
#!/bin/bash
if [[ "$*" =~ "/usr/local/cpanel" ]]; then
    echo "cpanel found"
    exit 0
fi
exit 1
EOF
    chmod +x "${MOODLE_CLI_ROOT}/tests/mocks/ls"
    
    run detect_panel_type
    
    assert_success
    assert_output --partial "cPanel detectado"
}

@test "detect_panel_type: debe detectar Plesk" {
    # Mock de estructura Plesk
    mkdir -p "${MOCK_FILESYSTEM_ROOT}/usr/local/psa"
    mkdir -p "${MOCK_FILESYSTEM_ROOT}/opt/psa"
    
    # Mock del comando
    cat > "${MOODLE_CLI_ROOT}/tests/mocks/which" << 'EOF'
#!/bin/bash
if [[ "$1" == "plesk" ]]; then
    echo "/usr/local/psa/bin/plesk"
    exit 0
fi
exit 1
EOF
    chmod +x "${MOODLE_CLI_ROOT}/tests/mocks/which"
    
    run detect_panel_type
    
    assert_success
    assert_output --partial "Plesk detectado"
}

@test "detect_panel_type: debe detectar VestaCP/HestiaCP" {
    # Mock de estructura VestaCP
    mkdir -p "${MOCK_FILESYSTEM_ROOT}/usr/local/vesta"
    
    cat > "${MOODLE_CLI_ROOT}/tests/mocks/systemctl" << 'EOF'
#!/bin/bash
if [[ "$*" =~ "vesta" ]]; then
    echo "vesta.service - loaded"
    exit 0
fi
exit 1
EOF
    chmod +x "${MOODLE_CLI_ROOT}/tests/mocks/systemctl"
    
    run detect_panel_type
    
    assert_success
    assert_output --partial "VestaCP detectado"
}

@test "detect_panel_type: debe retornar 'manual' si no detecta panel" {
    # No crear estructura de ningún panel
    
    run detect_panel_type
    
    assert_success
    assert_output --partial "Configuración manual detectada"
}

# ===================== TESTS DE DETECCIÓN DE WWW_DIR =====================

@test "detect_www_directory: debe detectar directorio web en cPanel" {
    export PANEL_TYPE="cpanel"
    export MOODLE_DOMAIN="domain.com"
    
    # El config.php ya existe en la estructura mock
    run detect_www_directory
    
    assert_success
    assert_output --partial "${MOCK_FILESYSTEM_ROOT}/home/user1/public_html/moodle"
}

@test "detect_www_directory: debe detectar directorio web en Plesk" {
    export PANEL_TYPE="plesk"
    export MOODLE_DOMAIN="domain.com"
    
    run detect_www_directory
    
    assert_success
    assert_output --partial "${MOCK_FILESYSTEM_ROOT}/var/www/vhosts/domain.com/httpdocs/moodle"
}

@test "detect_www_directory: debe encontrar múltiples instalaciones" {
    export PANEL_TYPE="cpanel"
    
    # Crear segunda instalación
    mkdir -p "${MOCK_FILESYSTEM_ROOT}/home/user1/public_html/moodle2"
    cat > "${MOCK_FILESYSTEM_ROOT}/home/user1/public_html/moodle2/config.php" << 'EOF'
<?php
$CFG = new stdClass();
$CFG->wwwroot = 'https://domain.com/moodle2';
EOF
    
    run detect_www_directory
    
    assert_success
    assert_output --partial "Múltiples instalaciones encontradas"
    assert_output --partial "moodle"
    assert_output --partial "moodle2"
}

@test "detect_www_directory: debe fallar si no encuentra instalaciones" {
    export PANEL_TYPE="cpanel"
    
    # Remover todas las configuraciones de Moodle
    rm -f "${MOCK_FILESYSTEM_ROOT}"/*/config.php
    find "${MOCK_FILESYSTEM_ROOT}" -name "config.php" -delete
    
    run detect_www_directory
    
    assert_failure
    assert_output --partial "No se encontraron instalaciones"
}

# ===================== TESTS DE DETECCIÓN DE MOODLEDATA_DIR =====================

@test "detect_moodledata_directory: debe extraer dataroot de config.php" {
    export WWW_DIR="${MOCK_FILESYSTEM_ROOT}/home/user1/public_html/moodle"
    
    run detect_moodledata_directory
    
    assert_success
    assert_output --partial "/home/user1/moodledata"
}

@test "detect_moodledata_directory: debe validar que el directorio existe" {
    export WWW_DIR="${MOCK_FILESYSTEM_ROOT}/home/user1/public_html/moodle"
    
    # El directorio ya existe en la estructura mock
    run detect_moodledata_directory
    
    assert_success
    assert_output --partial "Directorio de datos válido"
}

@test "detect_moodledata_directory: debe fallar si dataroot no existe" {
    export WWW_DIR="${MOCK_FILESYSTEM_ROOT}/home/user1/public_html/moodle"
    
    # Remover el directorio de datos
    rm -rf "${MOCK_FILESYSTEM_ROOT}/home/user1/moodledata"
    
    run detect_moodledata_directory
    
    assert_failure
    assert_output --partial "Directorio de datos no existe"
}

@test "detect_moodledata_directory: debe sugerir ubicaciones alternativas" {
    export WWW_DIR="${MOCK_FILESYSTEM_ROOT}/home/user1/public_html/moodle"
    
    # Modificar config.php para que apunte a directorio inexistente
    cat > "${MOCK_FILESYSTEM_ROOT}/home/user1/public_html/moodle/config.php" << 'EOF'
<?php
$CFG = new stdClass();
$CFG->dataroot = '/nonexistent/moodledata';
EOF
    
    run detect_moodledata_directory
    
    assert_failure
    assert_output --partial "Ubicaciones sugeridas"
    assert_output --partial "/home/user1/moodledata"
}

# ===================== TESTS DE VALIDACIÓN DE PERMISOS =====================

@test "validate_directory_permissions: debe validar permisos de lectura" {
    export TEST_DIR="${MOCK_FILESYSTEM_ROOT}/home/user1/public_html/moodle"
    
    run validate_directory_permissions "${TEST_DIR}" "read"
    
    assert_success
    assert_output --partial "Permisos de lectura: OK"
}

@test "validate_directory_permissions: debe validar permisos de escritura" {
    export TEST_DIR="${MOCK_FILESYSTEM_ROOT}/home/user1/moodledata"
    
    run validate_directory_permissions "${TEST_DIR}" "write"
    
    assert_success
    assert_output --partial "Permisos de escritura: OK"
}

@test "validate_directory_permissions: debe fallar con directorio no accesible" {
    export TEST_DIR="/root/restricted"
    
    run validate_directory_permissions "${TEST_DIR}" "read"
    
    assert_failure
    assert_output --partial "Sin permisos de acceso"
}

# ===================== TESTS DE DETECCIÓN DE ESPACIO DISPONIBLE =====================

@test "check_available_space: debe reportar espacio disponible" {
    # Mock del comando df
    cat > "${MOODLE_CLI_ROOT}/tests/mocks/df" << 'EOF'
#!/bin/bash
if [[ "$*" =~ "-h" ]]; then
    echo "Filesystem      Size  Used Avail Use% Mounted on"
    echo "/dev/sda1        20G  8.0G   11G  43% /"
    exit 0
fi
exit 1
EOF
    chmod +x "${MOODLE_CLI_ROOT}/tests/mocks/df"
    
    run check_available_space "${MOCK_FILESYSTEM_ROOT}"
    
    assert_success
    assert_output --partial "11G disponibles"
}

@test "check_available_space: debe advertir sobre poco espacio" {
    # Mock que simula poco espacio disponible
    cat > "${MOODLE_CLI_ROOT}/tests/mocks/df" << 'EOF'
#!/bin/bash
echo "Filesystem      Size  Used Avail Use% Mounted on"
echo "/dev/sda1        20G   19G  500M  98% /"
exit 0
EOF
    chmod +x "${MOODLE_CLI_ROOT}/tests/mocks/df"
    
    run check_available_space "${MOCK_FILESYSTEM_ROOT}"
    
    assert_success
    assert_output --partial "ADVERTENCIA"
    assert_output --partial "poco espacio"
}

# ===================== TESTS DE ESTIMACIÓN DE TAMAÑOS =====================

@test "estimate_directory_size: debe calcular tamaño de directorio" {
    # Mock del comando du
    cat > "${MOODLE_CLI_ROOT}/tests/mocks/du" << 'EOF'
#!/bin/bash
if [[ "$*" =~ "-sh" ]]; then
    echo "2.5G	/path/to/directory"
    exit 0
fi
exit 1
EOF
    chmod +x "${MOODLE_CLI_ROOT}/tests/mocks/du"
    
    run estimate_directory_size "${MOCK_FILESYSTEM_ROOT}/home/user1/public_html/moodle"
    
    assert_success
    assert_output --partial "2.5G"
}

@test "estimate_directory_size: debe manejar directorios grandes" {
    # Mock que simula directorio muy grande
    cat > "${MOODLE_CLI_ROOT}/tests/mocks/du" << 'EOF'
#!/bin/bash
echo "50G	/large/directory"
exit 0
EOF
    chmod +x "${MOODLE_CLI_ROOT}/tests/mocks/du"
    
    run estimate_directory_size "${MOCK_FILESYSTEM_ROOT}"
    
    assert_success
    assert_output --partial "50G"
    assert_output --partial "directorio grande"
}

# ===================== TESTS DE BÚSQUEDA INTELIGENTE =====================

@test "smart_directory_search: debe buscar por patrones de archivo" {
    export SEARCH_PATTERN="config.php"
    
    run smart_directory_search "${MOCK_FILESYSTEM_ROOT}" "${SEARCH_PATTERN}"
    
    assert_success
    assert_output --partial "config.php"
    assert_output --partial "/home/user1/public_html/moodle"
}

@test "smart_directory_search: debe encontrar archivos específicos de Moodle" {
    # Crear archivos característicos de Moodle
    touch "${MOCK_FILESYSTEM_ROOT}/home/user1/public_html/moodle/version.php"
    touch "${MOCK_FILESYSTEM_ROOT}/home/user1/public_html/moodle/lib/moodlelib.php"
    
    export SEARCH_PATTERN="version.php"
    
    run smart_directory_search "${MOCK_FILESYSTEM_ROOT}" "${SEARCH_PATTERN}"
    
    assert_success
    assert_output --partial "version.php"
}

@test "smart_directory_search: debe limitar resultados excesivos" {
    # Crear muchos archivos config.php
    for i in {1..20}; do
        mkdir -p "${MOCK_FILESYSTEM_ROOT}/fake${i}"
        touch "${MOCK_FILESYSTEM_ROOT}/fake${i}/config.php"
    done
    
    export SEARCH_PATTERN="config.php"
    export MAX_SEARCH_RESULTS="10"
    
    run smart_directory_search "${MOCK_FILESYSTEM_ROOT}" "${SEARCH_PATTERN}"
    
    assert_success
    assert_output --partial "resultados limitados"
}

# ===================== TESTS DE DETECCIÓN AUTOMÁTICA COMPLETA =====================

@test "detect_directories_auto: debe ejecutar detección completa" {
    export PANEL_TYPE="cpanel"
    export MOODLE_DOMAIN="domain.com"
    
    run detect_directories_auto
    
    assert_success
    assert_output --partial "Detección de directorios completada"
    assert_output --partial "WWW_DIR="
    assert_output --partial "MOODLEDATA_DIR="
}

@test "detect_directories_auto: debe manejar detección fallida gracefully" {
    export PANEL_TYPE="unknown_panel"
    
    # Remover todas las instalaciones
    find "${MOCK_FILESYSTEM_ROOT}" -name "config.php" -delete
    
    run detect_directories_auto
    
    assert_failure
    assert_output --partial "No se pudieron detectar directorios"
    assert_output --partial "configuración manual"
}

# ===================== TESTS DE FUNCIONES AUXILIARES =====================

@test "get_directory_owner: debe identificar propietario de directorio" {
    # Mock del comando stat
    cat > "${MOODLE_CLI_ROOT}/tests/mocks/stat" << 'EOF'
#!/bin/bash
if [[ "$*" =~ "--format=%U" ]]; then
    echo "user1"
    exit 0
fi
exit 1
EOF
    chmod +x "${MOODLE_CLI_ROOT}/tests/mocks/stat"
    
    run get_directory_owner "${MOCK_FILESYSTEM_ROOT}/home/user1"
    
    assert_success
    assert_output --partial "user1"
}

@test "normalize_path: debe normalizar rutas correctamente" {
    run normalize_path "/home/user1//public_html/../public_html/moodle/"
    
    assert_success
    assert_output --partial "/home/user1/public_html/moodle"
}

@test "is_moodle_directory: debe validar directorio de Moodle" {
    # El directorio mock ya tiene config.php
    run is_moodle_directory "${MOCK_FILESYSTEM_ROOT}/home/user1/public_html/moodle"
    
    assert_success
    assert_output --partial "directorio Moodle válido"
}

@test "is_moodle_directory: debe fallar con directorio no-Moodle" {
    run is_moodle_directory "${MOCK_FILESYSTEM_ROOT}/home/user1"
    
    assert_failure
    assert_output --partial "no es un directorio Moodle"
}

# ===================== TESTS DE EDGE CASES =====================

@test "debe manejar rutas con espacios y caracteres especiales" {
    export SPECIAL_DIR="${MOCK_FILESYSTEM_ROOT}/home/user with spaces/moodle site"
    mkdir -p "${SPECIAL_DIR}"
    cat > "${SPECIAL_DIR}/config.php" << 'EOF'
<?php
$CFG = new stdClass();
$CFG->wwwroot = 'https://domain.com/moodle';
EOF
    
    run is_moodle_directory "${SPECIAL_DIR}"
    
    assert_success
    assert_output --partial "directorio Moodle válido"
}

@test "debe manejar symlinks correctamente" {
    export LINK_TARGET="${MOCK_FILESYSTEM_ROOT}/home/user1/public_html/moodle"
    export SYMLINK_PATH="${MOCK_FILESYSTEM_ROOT}/var/www/moodle_link"
    
    # Crear symlink si es posible (puede fallar en algunos sistemas)
    if ln -s "${LINK_TARGET}" "${SYMLINK_PATH}" 2>/dev/null; then
        run is_moodle_directory "${SYMLINK_PATH}"
        assert_success
    else
        skip "Sistema no soporta symlinks"
    fi
}

@test "debe manejar directorios con permisos restringidos" {
    export RESTRICTED_DIR="${MOCK_FILESYSTEM_ROOT}/restricted"
    mkdir -p "${RESTRICTED_DIR}"
    
    # Simular permisos restringidos (puede no funcionar en todos los sistemas)
    if chmod 000 "${RESTRICTED_DIR}" 2>/dev/null; then
        run validate_directory_permissions "${RESTRICTED_DIR}" "read"
        assert_failure
        chmod 755 "${RESTRICTED_DIR}" # Restaurar permisos para cleanup
    else
        skip "No se pueden modificar permisos en este sistema"
    fi
}
