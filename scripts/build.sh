#!/bin/bash

##
# Build System para Moodle Backup CLI
# Versión: 1.0.0
#
# Genera single-file distribuible desde código fuente modular
# Resuelve dependencias automáticamente y optimiza el código
##

set -euo pipefail

# Configuración del build
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly SRC_DIR="$PROJECT_ROOT/src"
readonly LIB_DIR="$PROJECT_ROOT/lib"
readonly CONFIG_DIR="$PROJECT_ROOT/config"
readonly DIST_DIR="$PROJECT_ROOT/dist"
readonly BUILD_TEMP_DIR="/tmp/moodle-backup-build-$$"

# Información de versión
readonly VERSION=$(grep -o '"version": "[^"]*"' "$PROJECT_ROOT/package.json" | cut -d'"' -f4)
readonly BUILD_DATE=$(date '+%Y-%m-%d %H:%M:%S')
readonly BUILD_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

# Colores para output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# ===================== FUNCIONES DE UTILIDAD =====================

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

##
# Limpieza al salir
##
cleanup() {
    [[ -d "$BUILD_TEMP_DIR" ]] && rm -rf "$BUILD_TEMP_DIR"
}
trap cleanup EXIT

##
# Muestra ayuda del script
##
show_help() {
    cat <<EOF
Build System para Moodle Backup CLI v$VERSION

USO:
    $0 [OPCIONES]

OPCIONES:
    -h, --help              Muestra esta ayuda
    -v, --verbose           Output verbose
    -o, --output FILE       Archivo de salida (default: moodle-backup-v$VERSION.sh)
    -m, --minify           Minifica el código (elimina comentarios y espacios extra)
    -c, --check            Solo verifica dependencies sin build
    --no-header            No incluir header de información
    --include-tests        Incluir funciones de testing en el build

EJEMPLOS:
    $0                                    # Build estándar
    $0 -v -m                             # Build verbose con minificación
    $0 -o custom-backup.sh               # Build con nombre personalizado
    $0 -c                                # Solo verificar dependencias

EOF
}

# ===================== ANÁLISIS DE DEPENDENCIAS =====================

##
# Analiza las dependencias entre módulos
##
analyze_dependencies() {
    local file="$1"
    
    # Buscar líneas 'source' en el archivo
    grep -E '^[[:space:]]*source[[:space:]]' "$file" 2>/dev/null | \
    sed -E 's/.*source[[:space:]]+['"'"'"]?([^'"'"'"[:space:]]+)['"'"'"]?.*/\1/' | \
    while read -r dep; do
        # Resolver path relativo
        local resolved_dep
        if [[ "$dep" =~ ^\$\(dirname.*\) ]]; then
            # Extraer path relativo del comando dirname
            resolved_dep=$(echo "$dep" | sed -E 's/.*dirname[^)]*\)[\/]*(.*)/\1/')
            resolved_dep="$(dirname "$file")/$resolved_dep"
        else
            resolved_dep="$dep"
        fi
        
        # Normalizar path
        echo "$(readlink -f "$resolved_dep" 2>/dev/null || echo "$resolved_dep")"
    done | sort -u
}

##
# Construye grafo de dependencias completo
##
build_dependency_graph() {
    declare -A dependencies
    declare -A visited
    local -a all_files
    
    # Encontrar todos los archivos fuente
    mapfile -t all_files < <(find "$SRC_DIR" "$LIB_DIR" -name "*.sh" -type f)
    
    # Analizar dependencias para cada archivo
    local file
    for file in "${all_files[@]}"; do
        local deps
        mapfile -t deps < <(analyze_dependencies "$file")
        dependencies["$file"]=$(printf '%s\n' "${deps[@]}")
    done
    
    # Retornar como JSON para fácil procesamiento
    echo "{"
    local first=true
    for file in "${!dependencies[@]}"; do
        [[ "$first" == "true" ]] && first=false || echo ","
        echo -n "  \"$file\": ["
        local dep_first=true
        while IFS= read -r dep; do
            [[ -n "$dep" ]] || continue
            [[ "$dep_first" == "true" ]] && dep_first=false || echo -n ", "
            echo -n "\"$dep\""
        done <<< "${dependencies[$file]}"
        echo -n "]"
    done
    echo ""
    echo "}"
}

##
# Ordena archivos según dependencias (topological sort)
##
topological_sort() {
    local dependency_graph="$1"
    
    # Usar Python para hacer topological sort si está disponible
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "
import json
import sys
from collections import defaultdict, deque

# Leer grafo de dependencias
graph = json.loads('$dependency_graph')

# Construir grafo inverso (dependents)
in_degree = defaultdict(int)
dependents = defaultdict(list)

all_files = set(graph.keys())
for file, deps in graph.items():
    for dep in deps:
        if dep in all_files:
            dependents[dep].append(file)
            in_degree[file] += 1

# Topological sort usando Kahn's algorithm
queue = deque([f for f in all_files if in_degree[f] == 0])
result = []

while queue:
    current = queue.popleft()
    result.append(current)
    
    for dependent in dependents[current]:
        in_degree[dependent] -= 1
        if in_degree[dependent] == 0:
            queue.append(dependent)

# Verificar ciclos
if len(result) != len(all_files):
    print('ERROR: Dependencias circulares detectadas', file=sys.stderr)
    sys.exit(1)

# Imprimir orden
for file in result:
    print(file)
"
    else
        # Fallback: orden alfabético simple
        find "$LIB_DIR" -name "*.sh" -type f | sort
        find "$SRC_DIR" -name "*.sh" -type f | sort
    fi
}

# ===================== PROCESAMIENTO DE ARCHIVOS =====================

##
# Extrae funciones públicas de un archivo
##
extract_functions() {
    local file="$1"
    local minify="$2"
    
    # Leer archivo y procesar
    local in_function=false
    local function_content=""
    local brace_count=0
    
    while IFS= read -r line; do
        # Detectar inicio de función
        if [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\(\)[[:space:]]*\{ ]]; then
            in_function=true
            function_content="$line"
            brace_count=1
        elif [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\(\)[[:space:]]*$ ]]; then
            in_function=true
            function_content="$line"
            brace_count=0
        elif [[ "$in_function" == "true" ]]; then
            function_content+=$'\n'"$line"
            
            # Contar llaves para determinar fin de función
            local line_braces
            line_braces=$(echo "$line" | tr -cd '{}' | wc -c)
            local open_braces
            open_braces=$(echo "$line" | tr -cd '{' | wc -c)
            local close_braces
            close_braces=$(echo "$line" | tr -cd '}' | wc -c)
            
            brace_count=$((brace_count + open_braces - close_braces))
            
            if [[ $brace_count -eq 0 ]] && [[ "$line" =~ } ]]; then
                # Fin de función
                if [[ "$minify" == "true" ]]; then
                    echo "$function_content" | minify_bash_code
                else
                    echo "$function_content"
                fi
                echo ""
                in_function=false
                function_content=""
            fi
        elif [[ "$minify" != "true" ]] || [[ ! "$line" =~ ^[[:space:]]*# ]] && [[ -n "$(echo "$line" | tr -d '[:space:]')" ]]; then
            # Línea fuera de función (solo incluir si no es comentario en modo minify)
            if [[ "$minify" == "true" ]]; then
                echo "$line" | minify_bash_code
            else
                echo "$line"
            fi
        fi
    done < "$file"
}

##
# Minifica código bash
##
minify_bash_code() {
    # Eliminar comentarios (excepto shebang y comentarios especiales)
    sed -E '/^#!/!s/#.*$//' | \
    # Eliminar líneas vacías
    sed '/^[[:space:]]*$/d' | \
    # Eliminar espacios extra al inicio
    sed 's/^[[:space:]]*//'
}

##
# Genera header del archivo build
##
generate_header() {
    local include_header="$1"
    
    [[ "$include_header" == "true" ]] || return 0
    
    cat <<EOF
#!/bin/bash

# ===================== MOODLE BACKUP CLI - SINGLE FILE DISTRIBUTION =====================
# Version: $VERSION
# Build Date: $BUILD_DATE
# Build Commit: $BUILD_COMMIT
# Generated automatically from modular source code
# 
# Original repository: https://github.com/gzlo/moodle-backup-cli
# Documentation: https://github.com/gzlo/moodle-backup-cli/wiki
# 
# This file contains the complete Moodle Backup CLI system in a single executable.
# =====================================================================================

EOF
}

##
# Genera metadata del build
##
generate_build_metadata() {
    cat <<EOF

# ===================== BUILD METADATA =====================
readonly MOODLE_BACKUP_BUILD_VERSION="$VERSION"
readonly MOODLE_BACKUP_BUILD_DATE="$BUILD_DATE"
readonly MOODLE_BACKUP_BUILD_COMMIT="$BUILD_COMMIT"
readonly MOODLE_BACKUP_IS_SINGLE_FILE=true

EOF
}

# ===================== FUNCIÓN PRINCIPAL DE BUILD =====================

##
# Construye el archivo single-file
##
build_single_file() {
    local output_file="$1"
    local minify="$2"
    local include_header="$3"
    local include_tests="$4"
    local verbose="$5"
    
    log_info "Iniciando build de single-file..."
    
    # Crear directorio temporal
    mkdir -p "$BUILD_TEMP_DIR"
    
    # Generar grafo de dependencias
    [[ "$verbose" == "true" ]] && log_info "Analizando dependencias..."
    local dependency_graph
    dependency_graph=$(build_dependency_graph)
    
    # Ordenar archivos según dependencias
    [[ "$verbose" == "true" ]] && log_info "Ordenando archivos según dependencias..."
    local ordered_files
    mapfile -t ordered_files < <(topological_sort "$dependency_graph")
    
    # Crear archivo temporal de build
    local temp_output="$BUILD_TEMP_DIR/moodle-backup-build.sh"
    
    # Generar header
    generate_header "$include_header" > "$temp_output"
    
    # Agregar metadata del build
    generate_build_metadata >> "$temp_output"
    
    # Procesar cada archivo en orden
    local file
    for file in "${ordered_files[@]}"; do
        [[ "$verbose" == "true" ]] && log_info "Procesando: $(basename "$file")"
        
        # Filtrar archivos de test si no están incluidos
        if [[ "$include_tests" != "true" ]] && [[ "$file" =~ test ]]; then
            continue
        fi
        
        # Agregar separador
        cat <<EOF >> "$temp_output"

# ===================== $(basename "$file" .sh | tr '[:lower:]' '[:upper:]') =====================
# Source: $file

EOF
        
        # Filtrar guards de carga múltiple y source statements
        extract_functions "$file" "$minify" | \
        grep -v 'MOODLE_BACKUP.*_LOADED' | \
        grep -v '^[[:space:]]*source[[:space:]]' | \
        grep -v 'export.*_LOADED=' >> "$temp_output"
    done
    
    # Agregar punto de entrada principal
    cat <<'EOF' >> "$temp_output"

# ===================== ENTRY POINT =====================
# Punto de entrada principal del sistema

# Si el script se ejecuta directamente (no se hace source)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Cargar configuración global
    main "$@"
fi
EOF
    
    # Mover archivo final a destino
    mv "$temp_output" "$output_file"
    chmod +x "$output_file"
    
    log_success "Build completado: $output_file"
    
    # Mostrar estadísticas
    local file_size
    file_size=$(wc -c < "$output_file")
    local line_count
    line_count=$(wc -l < "$output_file")
    
    log_info "Estadísticas del build:"
    echo "  - Tamaño: $(format_bytes "$file_size" 2>/dev/null || echo "$file_size bytes")"
    echo "  - Líneas: $line_count"
    echo "  - Archivos procesados: ${#ordered_files[@]}"
}

##
# Verifica dependencias del sistema de build
##
verify_build_dependencies() {
    local errors=0
    
    log_info "Verificando dependencias del build..."
    
    # Comandos requeridos
    local required_commands=("grep" "sed" "awk" "find" "sort" "wc")
    local cmd
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "Comando requerido no encontrado: $cmd"
            ((errors++))
        fi
    done
    
    # Directorios requeridos
    local required_dirs=("$SRC_DIR" "$LIB_DIR")
    local dir
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            log_error "Directorio requerido no encontrado: $dir"
            ((errors++))
        fi
    done
    
    # Archivos críticos
    local critical_files=("$PROJECT_ROOT/package.json")
    local file
    for file in "${critical_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "Archivo crítico no encontrado: $file"
            ((errors++))
        fi
    done
    
    if [[ $errors -eq 0 ]]; then
        log_success "Todas las dependencias están disponibles"
        return 0
    else
        log_error "Se encontraron $errors errores en las dependencias"
        return 1
    fi
}

# ===================== PROCESAMIENTO DE ARGUMENTOS =====================

# Valores por defecto
VERBOSE=false
OUTPUT_FILE="$DIST_DIR/moodle-backup-v$VERSION.sh"
MINIFY=false
CHECK_ONLY=false
INCLUDE_HEADER=true
INCLUDE_TESTS=false

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
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -m|--minify)
            MINIFY=true
            shift
            ;;
        -c|--check)
            CHECK_ONLY=true
            shift
            ;;
        --no-header)
            INCLUDE_HEADER=false
            shift
            ;;
        --include-tests)
            INCLUDE_TESTS=true
            shift
            ;;
        *)
            log_error "Opción desconocida: $1"
            show_help
            exit 1
            ;;
    esac
done

# ===================== EJECUCIÓN PRINCIPAL =====================

main() {
    log_info "Moodle Backup CLI Build System v$VERSION"
    
    # Verificar dependencias
    if ! verify_build_dependencies; then
        exit 1
    fi
    
    # Si solo verificación, salir aquí
    if [[ "$CHECK_ONLY" == "true" ]]; then
        log_success "Verificación de dependencias completada"
        exit 0
    fi
    
    # Crear directorio de distribución
    mkdir -p "$DIST_DIR"
    
    # Construir archivo single-file
    build_single_file "$OUTPUT_FILE" "$MINIFY" "$INCLUDE_HEADER" "$INCLUDE_TESTS" "$VERBOSE"
    
    # Generar checksum
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$OUTPUT_FILE" > "${OUTPUT_FILE}.sha256"
        log_success "Checksum SHA256 generado: ${OUTPUT_FILE}.sha256"
    fi
    
    log_success "Build process completado exitosamente!"
}

# Ejecutar función principal
main "$@"
