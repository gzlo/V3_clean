#!/usr/bin/env bash

# Setup script para instalar herramientas de testing
# Este script instala BATS y sus helpers para el entorno de desarrollo

set -euo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar si estamos en Windows (Git Bash)
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    log_info "Detectado entorno Windows - configurando para Git Bash"
    INSTALL_PREFIX="$HOME/.local"
    export PATH="$INSTALL_PREFIX/bin:$PATH"
else
    INSTALL_PREFIX="/usr/local"
fi

# Crear directorio de instalación si no existe
mkdir -p "$INSTALL_PREFIX/bin"

# Función para instalar BATS Core
install_bats_core() {
    log_info "Instalando BATS Core..."
    
    local temp_dir
    temp_dir=$(mktemp -d)
    
    cd "$temp_dir"
    git clone https://github.com/bats-core/bats-core.git
    cd bats-core
    
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
        # En Windows, instalación manual
        cp bin/bats "$INSTALL_PREFIX/bin/"
        chmod +x "$INSTALL_PREFIX/bin/bats"
        mkdir -p "$INSTALL_PREFIX/lib/bats-core"
        cp -r lib/* "$INSTALL_PREFIX/lib/bats-core/"
    else
        sudo ./install.sh "$INSTALL_PREFIX"
    fi
    
    cd /
    rm -rf "$temp_dir"
    
    log_info "BATS Core instalado correctamente"
}

# Función para instalar helpers de BATS
install_bats_helpers() {
    log_info "Instalando BATS helpers..."
    
    # Obtener el directorio del proyecto (parent del directorio scripts)
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local project_dir="$(cd "$script_dir/.." && pwd)"
    
    cd "$project_dir" || {
        log_error "No se puede cambiar al directorio del proyecto: $project_dir"
        return 1
    }
    
    local helpers_dir="tests/helpers"
    
    # Crear directorio de helpers si no existe
    if [[ ! -d "$helpers_dir" ]]; then
        mkdir -p "$helpers_dir" || {
            log_error "No se puede crear el directorio $helpers_dir"
            return 1
        }
    fi
    
    # bats-support
    if [ ! -d "$helpers_dir/bats-support" ]; then
        log_info "Clonando bats-support..."
        git clone https://github.com/bats-core/bats-support.git "$helpers_dir/bats-support"
    fi
    
    # bats-assert
    if [ ! -d "$helpers_dir/bats-assert" ]; then
        log_info "Clonando bats-assert..."
        git clone https://github.com/bats-core/bats-assert.git "$helpers_dir/bats-assert"
    fi
    
    # bats-file
    if [ ! -d "$helpers_dir/bats-file" ]; then
        log_info "Clonando bats-file..."
        git clone https://github.com/bats-core/bats-file.git "$helpers_dir/bats-file"
    fi
    
    log_info "BATS helpers instalados correctamente"
}

# Función para verificar instalación
verify_installation() {
    log_info "Verificando instalación..."
    
    if command -v bats >/dev/null 2>&1; then
        local version
        version=$(bats --version)
        log_info "BATS instalado: $version"
    else
        log_error "BATS no encontrado en PATH"
        return 1
    fi
    
    # Verificar helpers
    local helpers_dir="tests/helpers"
    for helper in bats-support bats-assert bats-file; do
        if [ -d "$helpers_dir/$helper" ]; then
            log_info "Helper $helper: ✓"
        else
            log_warn "Helper $helper: ✗"
        fi
    done
}

# Función para crear configuración de test
create_test_config() {
    log_info "Creando configuración de test..."
    
    # Obtener el directorio del proyecto
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local project_dir="$(cd "$script_dir/.." && pwd)"
    
    cd "$project_dir" || {
        log_error "No se puede cambiar al directorio del proyecto: $project_dir"
        return 1
    }
    
    # Crear directorio tests si no existe
    mkdir -p tests
    
    cat > tests/test_helper.bash << 'HELPER_EOF'
#!/usr/bin/env bash

# Helper común para todos los tests
# Carga automáticamente las librerías de BATS

# Cargar helpers de BATS
load "helpers/bats-support/load"
load "helpers/bats-assert/load"
load "helpers/bats-file/load"

# Variables globales para tests
export BATS_TEST_SKIPPED=
export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
export TEST_TEMP_DIR="$BATS_TMPDIR/moodle-backup-test"

# Setup común para cada test
setup() {
    # Crear directorio temporal para el test
    mkdir -p "$TEST_TEMP_DIR"
    cd "$TEST_TEMP_DIR"
    
    # Copiar librerías necesarias
    mkdir -p lib
    cp -r "$PROJECT_ROOT/lib"/* lib/ 2>/dev/null || true
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
HELPER_EOF

    log_info "Configuración de test creada en tests/test_helper.bash"
}

# Función principal
main() {
    log_info "Iniciando setup de herramientas de testing..."
    
    # Verificar si Git está disponible
    if ! command -v git >/dev/null 2>&1; then
        log_error "Git no está instalado. Es necesario para clonar los repositorios."
        exit 1
    fi
    
    # Instalar componentes
    install_bats_core
    install_bats_helpers
    create_test_config
    
    # Verificar instalación
    if verify_installation; then
        log_info "Setup de testing completado exitosamente"
        log_info "Ahora puedes ejecutar: ./tests/run-all-tests.sh"
    else
        log_error "Falló la verificación de instalación"
        exit 1
    fi
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
