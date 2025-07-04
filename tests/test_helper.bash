#!/usr/bin/env bash

# Helper común para todos los tests
# Carga automáticamente las librerías de BATS

# Obtener el directorio base de tests
TEST_BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cargar helpers de BATS con rutas correctas
load "$TEST_BASE_DIR/helpers/bats-support/load.bash"
load "$TEST_BASE_DIR/helpers/bats-assert/load.bash"  
load "$TEST_BASE_DIR/helpers/bats-file/load.bash"

# Variables globales para tests
export BATS_TEST_SKIPPED=
export PROJECT_ROOT="$(cd "$TEST_BASE_DIR/.." && pwd)"
export TEST_TEMP_DIR="$BATS_TMPDIR/moodle-backup-test"

# Setup común para cada test
setup() {
    # Crear directorio temporal para el test
    mkdir -p "$TEST_TEMP_DIR"
    cd "$TEST_TEMP_DIR"
    
    # Copiar librerías necesarias
    mkdir -p lib
    cp -r "$PROJECT_ROOT/lib"/* lib/ 2>/dev/null || true
    
    # Copiar módulos src
    mkdir -p src
    cp -r "$PROJECT_ROOT/src"/* src/ 2>/dev/null || true
}

# Teardown común para cada test
teardown() {
    # Limpiar directorio temporal
    cd "$PROJECT_ROOT"
    rm -rf "$TEST_TEMP_DIR"
}

# Función helper para verificar que un comando existe
has_command() {
    command -v "$1" >/dev/null 2>&1
}

# Función helper para crear archivos de prueba
create_test_file() {
    local file="$1"
    local content="${2:-test content}"
    mkdir -p "$(dirname "$file")"
    echo "$content" > "$file"
}

# Función helper para mockear comandos
mock_command() {
    local cmd="$1"
    local output="${2:-}"
    local exit_code="${3:-0}"
    
    cat > "$TEST_TEMP_DIR/$cmd" << MOCK_EOF
#!/usr/bin/env bash
echo "$output"
exit $exit_code
MOCK_EOF
    chmod +x "$TEST_TEMP_DIR/$cmd"
    export PATH="$TEST_TEMP_DIR:$PATH"
}
