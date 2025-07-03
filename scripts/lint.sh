#!/bin/bash

##
# Sistema de Linting para Moodle Backup CLI
# Versión: 1.0.0
#
# Ejecuta shellcheck y otras herramientas de linting sobre el código fuente
##

set -euo pipefail

# Configuración
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly SRC_DIR="$PROJECT_ROOT/src"
readonly LIB_DIR="$PROJECT_ROOT/lib"
readonly SCRIPTS_DIR="$PROJECT_ROOT/scripts"
readonly BIN_DIR="$PROJECT_ROOT/bin"

# Colores para output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Contadores
declare -i TOTAL_FILES=0
declare -i ERRORS=0
declare -i WARNINGS=0

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
Sistema de Linting para Moodle Backup CLI

USO:
    $0 [OPCIONES] [ARCHIVOS...]

OPCIONES:
    -h, --help              Muestra esta ayuda
    -v, --verbose           Output detallado
    -f, --format FORMAT     Formato de output (tty, json, xml)
    -s, --severity LEVEL    Nivel mínimo de severidad (error, warning, info, style)
    -x, --exclude CODES     Códigos de shellcheck a excluir (separados por coma)
    --fix                   Aplicar fixes automáticos cuando sea posible
    --check-style          Verificar estilo de código adicional
    --summary              Mostrar solo resumen final

EJEMPLOS:
    $0                                    # Lint todos los archivos
    $0 -v --check-style                  # Lint detallado con verificación de estilo
    $0 -s error                          # Solo mostrar errores
    $0 -x SC2034,SC2086                  # Excluir códigos específicos
    $0 src/core/logging.sh               # Lint archivo específico

CÓDIGOS SHELLCHECK COMUNES:
    SC2034  - Variable appears unused
    SC2086  - Double quote to prevent globbing
    SC2155  - Declare and assign separately
    SC2164  - Use 'cd ... || exit' in case cd fails

EOF
}

# ===================== CONFIGURACIÓN DE SHELLCHECK =====================

##
# Configuración por defecto de shellcheck
##
get_shellcheck_config() {
    cat <<EOF
# Excluir algunos checks que no son aplicables a nuestro contexto
# SC1091: Not following sourced files (normal para módulos)
# SC2034: Variable appears unused (común en scripts de configuración)
exclude=SC1091

# Shell específico
shell=bash

# Directivas de seguimiento
source-path=$SRC_DIR:$LIB_DIR:$SCRIPTS_DIR

EOF
}

##
# Verifica si shellcheck está disponible
##
check_shellcheck_available() {
    if ! command -v shellcheck >/dev/null 2>&1; then
        log_error "shellcheck no está instalado"
        log_info "Para instalarlo:"
        log_info "  Ubuntu/Debian: apt-get install shellcheck"
        log_info "  RHEL/CentOS: yum install ShellCheck"
        log_info "  macOS: brew install shellcheck"
        log_info "  O descarga desde: https://github.com/koalaman/shellcheck/releases"
        return 1
    fi
    return 0
}

# ===================== FUNCIONES DE LINTING =====================

##
# Ejecuta shellcheck en un archivo
##
lint_file_shellcheck() {
    local file="$1"
    local format="${2:-tty}"
    local severity="${3:-style}"
    local exclude_codes="${4:-}"
    local verbose="${5:-false}"
    
    local shellcheck_args=()
    
    # Configurar formato
    shellcheck_args+=("--format=$format")
    
    # Configurar severidad
    shellcheck_args+=("--severity=$severity")
    
    # Configurar exclusiones
    if [[ -n "$exclude_codes" ]]; then
        shellcheck_args+=("--exclude=$exclude_codes")
    fi
    
    # Configurar shell específico
    shellcheck_args+=("--shell=bash")
    
    # Verificar sintaxis adicional
    shellcheck_args+=("--check-sourced")
    
    [[ "$verbose" == "true" ]] && log_info "Verificando: $file"
    
    # Ejecutar shellcheck
    local exit_code=0
    shellcheck "${shellcheck_args[@]}" "$file" || exit_code=$?
    
    # Contar errores y warnings basado en exit code
    case $exit_code in
        0)
            # Sin problemas
            ;;
        1)
            # Problemas encontrados
            if [[ "$severity" == "error" ]]; then
                ((ERRORS++))
            else
                ((WARNINGS++))
            fi
            ;;
        *)
            # Error de shellcheck
            log_error "Error ejecutando shellcheck en $file"
            ((ERRORS++))
            ;;
    esac
    
    return $exit_code
}

##
# Verifica estilo de código adicional
##
check_code_style() {
    local file="$1"
    local verbose="${2:-false}"
    
    [[ "$verbose" == "true" ]] && log_info "Verificando estilo: $file"
    
    local style_errors=0
    
    # Verificar longitud de líneas (max 120 caracteres)
    local long_lines
    long_lines=$(grep -n '.\{121,\}' "$file" 2>/dev/null || true)
    if [[ -n "$long_lines" ]]; then
        echo "Líneas demasiado largas (>120 chars) en $file:"
        echo "$long_lines" | head -5
        [[ $(echo "$long_lines" | wc -l) -gt 5 ]] && echo "... y $(( $(echo "$long_lines" | wc -l) - 5 )) más"
        ((style_errors++))
    fi
    
    # Verificar trailing whitespace
    local trailing_ws
    trailing_ws=$(grep -n '[[:space:]]$' "$file" 2>/dev/null || true)
    if [[ -n "$trailing_ws" ]]; then
        echo "Espacios en blanco al final de línea en $file:"
        echo "$trailing_ws" | head -3
        [[ $(echo "$trailing_ws" | wc -l) -gt 3 ]] && echo "... y $(( $(echo "$trailing_ws" | wc -l) - 3 )) más"
        ((style_errors++))
    fi
    
    # Verificar tabs vs spaces (preferir spaces)
    if grep -q $'\t' "$file" 2>/dev/null; then
        echo "Tabs encontrados en $file (preferir 4 espacios)"
        ((style_errors++))
    fi
    
    # Verificar funciones sin documentación
    local undocumented_functions
    undocumented_functions=$(awk '
        /^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\(\)[[:space:]]*\{?[[:space:]]*$/ {
            func_line = NR
            func_name = $1
            gsub(/[^a-zA-Z0-9_]/, "", func_name)
            
            # Buscar documentación en líneas anteriores
            documented = 0
            for (i = 1; i <= 10 && func_line - i > 0; i++) {
                if (lines[func_line - i] ~ /^[[:space:]]*##/) {
                    documented = 1
                    break
                }
                if (lines[func_line - i] !~ /^[[:space:]]*$/ && lines[func_line - i] !~ /^[[:space:]]*#/) {
                    break
                }
            }
            
            if (!documented && func_name !~ /^(main|cleanup|setup|teardown)$/) {
                print func_line ": " func_name
            }
        }
        { lines[NR] = $0 }
    ' "$file")
    
    if [[ -n "$undocumented_functions" ]]; then
        echo "Funciones sin documentación en $file:"
        echo "$undocumented_functions" | head -5
        ((style_errors++))
    fi
    
    if [[ $style_errors -gt 0 ]]; then
        ((WARNINGS += style_errors))
        return 1
    fi
    
    return 0
}

##
# Aplica fixes automáticos básicos
##
apply_auto_fixes() {
    local file="$1"
    local verbose="${2:-false}"
    
    [[ "$verbose" == "true" ]] && log_info "Aplicando fixes automáticos: $file"
    
    # Crear backup
    cp "$file" "${file}.backup.$(date +%s)"
    
    # Fix trailing whitespace
    sed -i 's/[[:space:]]*$//' "$file"
    
    # Fix múltiples líneas vacías consecutivas
    awk '/^[[:space:]]*$/ { if (++n <= 2) print; next } { n=0; print }' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
    
    # Fix espacios alrededor de =
    sed -i -E 's/[[:space:]]*=[[:space:]]*/=/g' "$file"
    
    log_info "Fixes aplicados a $file (backup creado)"
}

##
# Procesa un archivo individual
##
process_file() {
    local file="$1"
    local format="$2"
    local severity="$3"
    local exclude_codes="$4"
    local verbose="$5"
    local check_style="$6"
    local apply_fixes="$7"
    
    ((TOTAL_FILES++))
    
    # Verificar que el archivo existe y es un script bash
    if [[ ! -f "$file" ]]; then
        log_error "Archivo no encontrado: $file"
        ((ERRORS++))
        return 1
    fi
    
    # Verificar que es un script bash
    local first_line
    first_line=$(head -n1 "$file")
    if [[ ! "$first_line" =~ ^#!.*bash ]]; then
        [[ "$verbose" == "true" ]] && log_warning "Saltando archivo no-bash: $file"
        ((TOTAL_FILES--))
        return 0
    fi
    
    local file_errors=0
    
    # Aplicar fixes automáticos si está habilitado
    if [[ "$apply_fixes" == "true" ]]; then
        apply_auto_fixes "$file" "$verbose"
    fi
    
    # Ejecutar shellcheck
    if ! lint_file_shellcheck "$file" "$format" "$severity" "$exclude_codes" "$verbose"; then
        ((file_errors++))
    fi
    
    # Verificar estilo adicional si está habilitado
    if [[ "$check_style" == "true" ]]; then
        if ! check_code_style "$file" "$verbose"; then
            ((file_errors++))
        fi
    fi
    
    return $file_errors
}

##
# Encuentra todos los archivos bash en el proyecto
##
find_bash_files() {
    local dirs=("$SRC_DIR" "$LIB_DIR" "$SCRIPTS_DIR")
    
    # Agregar bin si existe
    [[ -d "$BIN_DIR" ]] && dirs+=("$BIN_DIR")
    
    # Buscar archivos .sh
    find "${dirs[@]}" -name "*.sh" -type f 2>/dev/null | sort
    
    # Buscar archivos sin extensión que sean scripts bash
    find "${dirs[@]}" -type f ! -name "*.sh" -exec grep -l '^#!/.*bash' {} \; 2>/dev/null | sort
}

##
# Genera resumen de resultados
##
generate_summary() {
    local format="$1"
    local show_summary_only="$2"
    
    if [[ "$format" == "json" ]]; then
        cat <<EOF
{
    "summary": {
        "total_files": $TOTAL_FILES,
        "errors": $ERRORS,
        "warnings": $WARNINGS,
        "status": "$([ $ERRORS -eq 0 ] && echo "success" || echo "failed")"
    }
}
EOF
    else
        echo ""
        echo "===================== RESUMEN DE LINTING ====================="
        echo "Archivos procesados: $TOTAL_FILES"
        echo "Errores encontrados: $ERRORS"
        echo "Advertencias encontradas: $WARNINGS"
        echo ""
        
        if [[ $ERRORS -eq 0 ]] && [[ $WARNINGS -eq 0 ]]; then
            log_success "¡Todos los archivos pasaron el linting sin problemas!"
        elif [[ $ERRORS -eq 0 ]]; then
            log_warning "Linting completado con $WARNINGS advertencias"
        else
            log_error "Linting falló con $ERRORS errores y $WARNINGS advertencias"
        fi
    fi
}

# ===================== PROCESAMIENTO DE ARGUMENTOS =====================

# Valores por defecto
VERBOSE=false
FORMAT="tty"
SEVERITY="style"
EXCLUDE_CODES=""
APPLY_FIXES=false
CHECK_STYLE=false
SHOW_SUMMARY_ONLY=false
FILES=()

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
        -f|--format)
            FORMAT="$2"
            shift 2
            ;;
        -s|--severity)
            SEVERITY="$2"
            shift 2
            ;;
        -x|--exclude)
            EXCLUDE_CODES="$2"
            shift 2
            ;;
        --fix)
            APPLY_FIXES=true
            shift
            ;;
        --check-style)
            CHECK_STYLE=true
            shift
            ;;
        --summary)
            SHOW_SUMMARY_ONLY=true
            shift
            ;;
        -*)
            log_error "Opción desconocida: $1"
            show_help
            exit 1
            ;;
        *)
            FILES+=("$1")
            shift
            ;;
    esac
done

# ===================== EJECUCIÓN PRINCIPAL =====================

main() {
    log_info "Sistema de Linting para Moodle Backup CLI"
    
    # Verificar que shellcheck está disponible
    if ! check_shellcheck_available; then
        exit 1
    fi
    
    # Determinar archivos a procesar
    local files_to_process=()
    
    if [[ ${#FILES[@]} -eq 0 ]]; then
        # No se especificaron archivos, procesar todos
        [[ "$VERBOSE" == "true" ]] && log_info "Buscando archivos bash en el proyecto..."
        mapfile -t files_to_process < <(find_bash_files)
    else
        # Usar archivos especificados
        files_to_process=("${FILES[@]}")
    fi
    
    if [[ ${#files_to_process[@]} -eq 0 ]]; then
        log_warning "No se encontraron archivos para procesar"
        exit 0
    fi
    
    [[ "$VERBOSE" == "true" ]] && log_info "Procesando ${#files_to_process[@]} archivos..."
    
    # Procesar cada archivo
    local file
    for file in "${files_to_process[@]}"; do
        if [[ "$SHOW_SUMMARY_ONLY" != "true" ]]; then
            process_file "$file" "$FORMAT" "$SEVERITY" "$EXCLUDE_CODES" "$VERBOSE" "$CHECK_STYLE" "$APPLY_FIXES"
        else
            process_file "$file" "json" "$SEVERITY" "$EXCLUDE_CODES" "false" "$CHECK_STYLE" "$APPLY_FIXES" >/dev/null 2>&1
        fi
    done
    
    # Generar resumen
    generate_summary "$FORMAT" "$SHOW_SUMMARY_ONLY"
    
    # Exit code basado en errores
    exit $ERRORS
}

# Ejecutar función principal
main "$@"
