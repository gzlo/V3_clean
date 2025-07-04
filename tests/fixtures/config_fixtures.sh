#!/bin/bash
##
# Fixtures reutilizables para tests de configuración
# tests/fixtures/config_fixtures.sh
##

# Configuración básica válida
get_basic_config_fixture() {
    cat <<EOF
# Configuración básica de prueba
LOG_LEVEL=INFO
BACKUP_DIR=/tmp/backups
CLOUD_ENABLED=false
COMPRESSION_ALGORITHM=zstd
COMPRESSION_LEVEL=3
DB_BACKUP_ENABLED=true
FILES_BACKUP_ENABLED=true
EOF
}

# Configuración con variables
get_variable_config_fixture() {
    cat <<EOF
# Configuración con expansión de variables
BASE_DIR=\${TEST_BASE}
BACKUP_DIR=\${BASE_DIR}/backups
LOG_DIR=\${BASE_DIR}/logs
TMP_DIR=\${BACKUP_DIR}/tmp
EOF
}

# Configuración con booleanos diversos
get_boolean_config_fixture() {
    cat <<EOF
# Configuración con diferentes formatos de booleanos
FEATURE_TRUE=true
FEATURE_YES=yes
FEATURE_ONE=1
FEATURE_ON=on
FEATURE_FALSE=false
FEATURE_NO=no
FEATURE_ZERO=0
FEATURE_OFF=off
DEBUG=yes
VERBOSE=1
EOF
}

# Configuración mal formada
get_malformed_config_fixture() {
    cat <<EOF
# Configuración con líneas mal formadas
LOG_LEVEL=INFO
invalid line without equals
=value_without_key
BACKUP_DIR=/valid/path
invalid=
VALID_KEY=valid_value
# Línea vacía sigue

# Otra línea válida
COMPRESSION_LEVEL=5
EOF
}

# Configuración para prioridad de variables de entorno
get_env_priority_config_fixture() {
    cat <<EOF
# Configuración para test de prioridad
LOG_LEVEL=INFO
BACKUP_DIR=/from/file
CLOUD_ENABLED=false
EOF
}

# Configuración compleja para validación
get_validation_config_fixture() {
    cat <<EOF
# Configuración para tests de validación
LOG_LEVEL=DEBUG
BACKUP_DIR=/nonexistent/read-only/path
COMPRESSION_ALGORITHM=unsupported
COMPRESSION_LEVEL=999
EOF
}
