#!/bin/bash

##
# Sistema de Colores y UI para Moodle Backup CLI
# Versión: 1.0.0
#
# Proporciona funciones para output colorizado y elementos de UI
# compatibles con diferentes terminales y entornos.
##

# Guard para evitar carga múltiple
[[ "${MOODLE_BACKUP_COLORS_LOADED:-}" == "true" ]] && return 0
export MOODLE_BACKUP_COLORS_LOADED="true"

# Dependencias
source "$(dirname "${BASH_SOURCE[0]}")/constants.sh"

# ===================== DETECCIÓN DE CAPACIDADES DE TERMINAL =====================

##
# Detecta si el terminal soporta colores
#
# Returns:
#   0 - Si el terminal soporta colores
#   1 - Si el terminal no soporta colores
##
terminal_supports_colors() {
    # Variables que indican soporte de color
    [[ -t 1 ]] && {
        # Verificar variables de entorno
        [[ -n "${TERM:-}" ]] && [[ "$TERM" != "dumb" ]] && {
            # Verificar capacidades específicas
            [[ "$TERM" =~ color ]] || 
            [[ -n "${COLORTERM:-}" ]] ||
            [[ "${TERM_PROGRAM:-}" == "iTerm.app" ]] ||
            [[ "${TERM_PROGRAM:-}" == "Apple_Terminal" ]] ||
            command -v tput >/dev/null 2>&1 && [[ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]]
        }
    }
}

##
# Detecta si el terminal soporta caracteres Unicode
#
# Returns:
#   0 - Si el terminal soporta Unicode
#   1 - Si el terminal no soporta Unicode
##
terminal_supports_unicode() {
    [[ "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" =~ UTF-?8$ ]] ||
    [[ "${TERM_PROGRAM:-}" == "iTerm.app" ]] ||
    [[ "${TERM_PROGRAM:-}" == "Apple_Terminal" ]]
}

# ===================== CONFIGURACIÓN DE COLORES =====================

# Determinar si usar colores
if terminal_supports_colors && [[ "${NO_COLOR:-}" != "1" ]] && [[ "${MOODLE_BACKUP_NO_COLOR:-}" != "1" ]]; then
    readonly COLOR_ENABLED=true
else
    readonly COLOR_ENABLED=false
fi

# Determinar si usar Unicode
if terminal_supports_unicode && [[ "${MOODLE_BACKUP_NO_UNICODE:-}" != "1" ]]; then
    readonly UNICODE_ENABLED=true
else
    readonly UNICODE_ENABLED=false
fi

# ===================== CÓDIGOS DE COLOR ANSI =====================

if [[ "$COLOR_ENABLED" == "true" ]]; then
    # Colores básicos
    readonly COLOR_RESET="\033[0m"
    readonly COLOR_BOLD="\033[1m"
    readonly COLOR_DIM="\033[2m"
    readonly COLOR_UNDERLINE="\033[4m"
    readonly COLOR_BLINK="\033[5m"
    readonly COLOR_REVERSE="\033[7m"
    readonly COLOR_STRIKETHROUGH="\033[9m"
    
    # Colores de texto
    readonly COLOR_BLACK="\033[30m"
    readonly COLOR_RED="\033[31m"
    readonly COLOR_GREEN="\033[32m"
    readonly COLOR_YELLOW="\033[33m"
    readonly COLOR_BLUE="\033[34m"
    readonly COLOR_PURPLE="\033[35m"
    readonly COLOR_CYAN="\033[36m"
    readonly COLOR_WHITE="\033[37m"
    
    # Colores brillantes
    readonly COLOR_BRIGHT_BLACK="\033[90m"
    readonly COLOR_BRIGHT_RED="\033[91m"
    readonly COLOR_BRIGHT_GREEN="\033[92m"
    readonly COLOR_BRIGHT_YELLOW="\033[93m"
    readonly COLOR_BRIGHT_BLUE="\033[94m"
    readonly COLOR_BRIGHT_PURPLE="\033[95m"
    readonly COLOR_BRIGHT_CYAN="\033[96m"
    readonly COLOR_BRIGHT_WHITE="\033[97m"
    
    # Colores de fondo
    readonly COLOR_BG_BLACK="\033[40m"
    readonly COLOR_BG_RED="\033[41m"
    readonly COLOR_BG_GREEN="\033[42m"
    readonly COLOR_BG_YELLOW="\033[43m"
    readonly COLOR_BG_BLUE="\033[44m"
    readonly COLOR_BG_PURPLE="\033[45m"
    readonly COLOR_BG_CYAN="\033[46m"
    readonly COLOR_BG_WHITE="\033[47m"
    
    # Esquema de colores temático para la aplicación
    readonly APP_COLOR_SUCCESS="$COLOR_GREEN"
    readonly APP_COLOR_ERROR="$COLOR_RED"
    readonly APP_COLOR_WARNING="$COLOR_YELLOW"
    readonly APP_COLOR_INFO="$COLOR_BLUE"
    readonly APP_COLOR_DEBUG="$COLOR_CYAN"
    readonly APP_COLOR_TRACE="$COLOR_PURPLE"
    readonly APP_COLOR_ACCENT="$COLOR_BRIGHT_BLUE"
    readonly APP_COLOR_MUTED="$COLOR_DIM"
    readonly APP_COLOR_HIGHLIGHT="$COLOR_BOLD"
else
    # Sin colores - todas las variables vacías
    readonly COLOR_RESET=""
    readonly COLOR_BOLD=""
    readonly COLOR_DIM=""
    readonly COLOR_UNDERLINE=""
    readonly COLOR_BLINK=""
    readonly COLOR_REVERSE=""
    readonly COLOR_STRIKETHROUGH=""
    
    readonly COLOR_BLACK=""
    readonly COLOR_RED=""
    readonly COLOR_GREEN=""
    readonly COLOR_YELLOW=""
    readonly COLOR_BLUE=""
    readonly COLOR_PURPLE=""
    readonly COLOR_CYAN=""
    readonly COLOR_WHITE=""
    
    readonly COLOR_BRIGHT_BLACK=""
    readonly COLOR_BRIGHT_RED=""
    readonly COLOR_BRIGHT_GREEN=""
    readonly COLOR_BRIGHT_YELLOW=""
    readonly COLOR_BRIGHT_BLUE=""
    readonly COLOR_BRIGHT_PURPLE=""
    readonly COLOR_BRIGHT_CYAN=""
    readonly COLOR_BRIGHT_WHITE=""
    
    readonly COLOR_BG_BLACK=""
    readonly COLOR_BG_RED=""
    readonly COLOR_BG_GREEN=""
    readonly COLOR_BG_YELLOW=""
    readonly COLOR_BG_BLUE=""
    readonly COLOR_BG_PURPLE=""
    readonly COLOR_BG_CYAN=""
    readonly COLOR_BG_WHITE=""
    
    readonly APP_COLOR_SUCCESS=""
    readonly APP_COLOR_ERROR=""
    readonly APP_COLOR_WARNING=""
    readonly APP_COLOR_INFO=""
    readonly APP_COLOR_DEBUG=""
    readonly APP_COLOR_TRACE=""
    readonly APP_COLOR_ACCENT=""
    readonly APP_COLOR_MUTED=""
    readonly APP_COLOR_HIGHLIGHT=""
fi

# ===================== SÍMBOLOS Y CARACTERES ESPECIALES =====================

if [[ "$UNICODE_ENABLED" == "true" ]]; then
    # Símbolos Unicode (solo definir si no existen)
    if [[ -z "${SYMBOL_SUCCESS:-}" ]]; then readonly SYMBOL_SUCCESS="✓"; fi
    if [[ -z "${SYMBOL_ERROR:-}" ]]; then readonly SYMBOL_ERROR="✗"; fi
    if [[ -z "${SYMBOL_WARNING:-}" ]]; then readonly SYMBOL_WARNING="⚠"; fi
    if [[ -z "${SYMBOL_INFO:-}" ]]; then readonly SYMBOL_INFO="ℹ"; fi
    if [[ -z "${SYMBOL_QUESTION:-}" ]]; then readonly SYMBOL_QUESTION="?"; fi
    if [[ -z "${SYMBOL_ARROW:-}" ]]; then readonly SYMBOL_ARROW="➤"; fi
    if [[ -z "${SYMBOL_BULLET:-}" ]]; then readonly SYMBOL_BULLET="•"; fi
    if [[ -z "${SYMBOL_CHECKBOX_CHECKED:-}" ]]; then readonly SYMBOL_CHECKBOX_CHECKED="☑"; fi
    if [[ -z "${SYMBOL_CHECKBOX_UNCHECKED:-}" ]]; then readonly SYMBOL_CHECKBOX_UNCHECKED="☐"; fi
    if [[ -z "${SYMBOL_CIRCLE:-}" ]]; then readonly SYMBOL_CIRCLE="●"; fi
    if [[ -z "${SYMBOL_SQUARE:-}" ]]; then readonly SYMBOL_SQUARE="■"; fi
    if [[ -z "${SYMBOL_DIAMOND:-}" ]]; then readonly SYMBOL_DIAMOND="♦"; fi
    if [[ -z "${SYMBOL_STAR:-}" ]]; then readonly SYMBOL_STAR="★"; fi
    if [[ -z "${SYMBOL_HEART:-}" ]]; then readonly SYMBOL_HEART="♥"; fi
    if [[ -z "${SYMBOL_CLOCK:-}" ]]; then readonly SYMBOL_CLOCK="⏰"; fi
    if [[ -z "${SYMBOL_GEAR:-}" ]]; then readonly SYMBOL_GEAR="⚙"; fi
    if [[ -z "${SYMBOL_ROCKET:-}" ]]; then readonly SYMBOL_ROCKET="🚀"; fi
    if [[ -z "${SYMBOL_BACKUP:-}" ]]; then readonly SYMBOL_BACKUP="💾"; fi
    if [[ -z "${SYMBOL_CLOUD:-}" ]]; then readonly SYMBOL_CLOUD="☁"; fi
    if [[ -z "${SYMBOL_DATABASE:-}" ]]; then readonly SYMBOL_DATABASE="🗄"; fi
    if [[ -z "${SYMBOL_FOLDER:-}" ]]; then readonly SYMBOL_FOLDER="📁"; fi
    if [[ -z "${SYMBOL_FILE:-}" ]]; then readonly SYMBOL_FILE="📄"; fi
    if [[ -z "${SYMBOL_LOCK:-}" ]]; then readonly SYMBOL_LOCK="🔒"; fi
    if [[ -z "${SYMBOL_KEY:-}" ]]; then readonly SYMBOL_KEY="🔑"; fi
    if [[ -z "${SYMBOL_SHIELD:-}" ]]; then readonly SYMBOL_SHIELD="🛡"; fi
    if [[ -z "${SYMBOL_PROGRESS_FULL:-}" ]]; then readonly SYMBOL_PROGRESS_FULL="█"; fi
    if [[ -z "${SYMBOL_PROGRESS_EMPTY:-}" ]]; then readonly SYMBOL_PROGRESS_EMPTY="░"; fi
    if [[ -z "${SYMBOL_PROGRESS_PARTIAL:-}" ]]; then readonly SYMBOL_PROGRESS_PARTIAL="▓"; fi
    
    # Spinner frames para animaciones
    readonly SPINNER_FRAMES=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    readonly SPINNER_DOTS=("⠄" "⠆" "⠇" "⠋" "⠙" "⠸" "⠰" "⠠" "⠰" "⠸" "⠙" "⠋" "⠇" "⠆")
    readonly SPINNER_LINE=("─" "\\" "|" "/")
    
    # Líneas para cajas y separadores
    readonly LINE_HORIZONTAL="─"
    readonly LINE_VERTICAL="│"
    readonly LINE_TOP_LEFT="┌"
    readonly LINE_TOP_RIGHT="┐"
    readonly LINE_BOTTOM_LEFT="└"
    readonly LINE_BOTTOM_RIGHT="┘"
    readonly LINE_CROSS="┼"
    readonly LINE_T_TOP="┬"
    readonly LINE_T_BOTTOM="┴"
    readonly LINE_T_LEFT="├"
    readonly LINE_T_RIGHT="┤"
else
    # Símbolos ASCII fallback
    readonly SYMBOL_SUCCESS="[OK]"
    readonly SYMBOL_ERROR="[ERROR]"
    readonly SYMBOL_WARNING="[WARN]"
    readonly SYMBOL_INFO="[INFO]"
    readonly SYMBOL_QUESTION="[?]"
    readonly SYMBOL_ARROW=">"
    readonly SYMBOL_BULLET="*"
    readonly SYMBOL_CHECKBOX_CHECKED="[x]"
    readonly SYMBOL_CHECKBOX_UNCHECKED="[ ]"
    readonly SYMBOL_CIRCLE="o"
    readonly SYMBOL_SQUARE="#"
    readonly SYMBOL_DIAMOND="<>"
    readonly SYMBOL_STAR="*"
    readonly SYMBOL_HEART="<3"
    readonly SYMBOL_CLOCK="[time]"
    readonly SYMBOL_GEAR="[cfg]"
    readonly SYMBOL_ROCKET="[run]"
    readonly SYMBOL_BACKUP="[bak]"
    readonly SYMBOL_CLOUD="[cloud]"
    readonly SYMBOL_DATABASE="[db]"
    readonly SYMBOL_FOLDER="[dir]"
    readonly SYMBOL_FILE="[file]"
    readonly SYMBOL_LOCK="[lock]"
    readonly SYMBOL_KEY="[key]"
    readonly SYMBOL_SHIELD="[sec]"
    readonly SYMBOL_PROGRESS_FULL="#"
    readonly SYMBOL_PROGRESS_EMPTY="-"
    readonly SYMBOL_PROGRESS_PARTIAL="="
    
    readonly SPINNER_FRAMES=("|" "/" "-" "\\")
    readonly SPINNER_DOTS=("." "o" "O" "o")
    readonly SPINNER_LINE=("-" "\\" "|" "/")
    
    readonly LINE_HORIZONTAL="-"
    readonly LINE_VERTICAL="|"
    readonly LINE_TOP_LEFT="+"
    readonly LINE_TOP_RIGHT="+"
    readonly LINE_BOTTOM_LEFT="+"
    readonly LINE_BOTTOM_RIGHT="+"
    readonly LINE_CROSS="+"
    readonly LINE_T_TOP="+"
    readonly LINE_T_BOTTOM="+"
    readonly LINE_T_LEFT="+"
    readonly LINE_T_RIGHT="+"
fi

# ===================== FUNCIONES DE COLORIZACIÓN =====================

##
# Aplica color a un texto
#
# Arguments:
#   $1 - Código de color
#   $2 - Texto a colorizar
# Outputs:
#   Texto colorizado
##
colorize() {
    local color="$1"
    local text="$2"
    
    if [[ "$COLOR_ENABLED" == "true" ]]; then
        echo -e "${color}${text}${COLOR_RESET}"
    else
        echo "$text"
    fi
}

##
# Texto en color rojo (errores)
##
red() { colorize "$COLOR_RED" "$*"; }

##
# Texto en color verde (éxito)
##
green() { colorize "$COLOR_GREEN" "$*"; }

##
# Texto en color amarillo (advertencias)
##
yellow() { colorize "$COLOR_YELLOW" "$*"; }

##
# Texto en color azul (información)
##
blue() { colorize "$COLOR_BLUE" "$*"; }

##
# Texto en color cyan (debug)
##
cyan() { colorize "$COLOR_CYAN" "$*"; }

##
# Texto en color púrpura (trace)
##
purple() { colorize "$COLOR_PURPLE" "$*"; }

##
# Texto en negrita
##
bold() { colorize "$COLOR_BOLD" "$*"; }

##
# Texto dimmed
##
dim() { colorize "$COLOR_DIM" "$*"; }

##
# Texto subrayado
##
underline() { colorize "$COLOR_UNDERLINE" "$*"; }

# ===================== FUNCIONES DE UI ESPECÍFICAS =====================

##
# Imprime mensaje de éxito
##
print_success() {
    colorize "$APP_COLOR_SUCCESS" "$SYMBOL_SUCCESS $*"
}

##
# Imprime mensaje de error
##
print_error() {
    colorize "$APP_COLOR_ERROR" "$SYMBOL_ERROR $*"
}

##
# Imprime mensaje de advertencia
##
print_warning() {
    colorize "$APP_COLOR_WARNING" "$SYMBOL_WARNING $*"
}

##
# Imprime mensaje informativo
##
print_info() {
    colorize "$APP_COLOR_INFO" "$SYMBOL_INFO $*"
}

##
# Imprime cabecera destacada
##
print_header() {
    local text="$*"
    local length=${#text}
    local line
    
    # Crear línea de separación
    printf -v line '%*s' $((length + 4)) ''
    line=${line// /$LINE_HORIZONTAL}
    
    echo
    colorize "$APP_COLOR_ACCENT" "$line"
    colorize "$APP_COLOR_ACCENT$COLOR_BOLD" "  $text  "
    colorize "$APP_COLOR_ACCENT" "$line"
    echo
}

##
# Imprime paso de proceso
##
print_step() {
    colorize "$APP_COLOR_ACCENT" "$SYMBOL_ARROW $*"
}

##
# Imprime elemento de lista
##
print_bullet() {
    colorize "$APP_COLOR_INFO" "$SYMBOL_BULLET $*"
}

# ===================== FUNCIONES DE PROGRESO =====================

##
# Muestra barra de progreso
#
# Arguments:
#   $1 - Progreso actual (0-100)
#   $2 - Texto descriptivo (opcional)
##
print_progress_bar() {
    local progress="$1"
    local text="${2:-}"
    local width="${PROGRESS_BAR_WIDTH:-40}"
    
    # Validar entrada
    [[ "$progress" =~ ^[0-9]+$ ]] || progress=0
    [[ "$progress" -gt 100 ]] && progress=100
    
    # Calcular caracteres llenos
    local filled=$(( progress * width / 100 ))
    local empty=$(( width - filled ))
    
    # Construir barra
    local bar=""
    printf -v bar '%*s' "$filled" ''
    bar=${bar// /$SYMBOL_PROGRESS_FULL}
    
    local empty_bar=""
    printf -v empty_bar '%*s' "$empty" ''
    empty_bar=${empty_bar// /$SYMBOL_PROGRESS_EMPTY}
    
    # Mostrar con colores
    local colored_bar
    if [[ "$progress" -eq 100 ]]; then
        colored_bar=$(colorize "$APP_COLOR_SUCCESS" "$bar$empty_bar")
    elif [[ "$progress" -ge 70 ]]; then
        colored_bar=$(colorize "$APP_COLOR_SUCCESS" "$bar")$(colorize "$APP_COLOR_MUTED" "$empty_bar")
    elif [[ "$progress" -ge 30 ]]; then
        colored_bar=$(colorize "$APP_COLOR_WARNING" "$bar")$(colorize "$APP_COLOR_MUTED" "$empty_bar")
    else
        colored_bar=$(colorize "$APP_COLOR_ERROR" "$bar")$(colorize "$APP_COLOR_MUTED" "$empty_bar")
    fi
    
    printf "\r[%s] %3d%%" "$colored_bar" "$progress"
    [[ -n "$text" ]] && printf " %s" "$text"
    
    # Nueva línea solo si está completo
    [[ "$progress" -eq 100 ]] && echo
}

##
# Spinner animado para operaciones largas
#
# Arguments:
#   $1 - PID del proceso a monitorear
#   $2 - Mensaje a mostrar
##
show_spinner() {
    local pid="$1"
    local message="${2:-Procesando...}"
    local frame=0
    
    # Ocultar cursor
    printf "\033[?25l"
    
    while kill -0 "$pid" 2>/dev/null; do
        local spinner_char="${SPINNER_FRAMES[$((frame % ${#SPINNER_FRAMES[@]}))]}"
        printf "\r%s %s" "$(colorize "$APP_COLOR_ACCENT" "$spinner_char")" "$message"
        frame=$((frame + 1))
        sleep 0.1
    done
    
    # Mostrar cursor y limpiar línea
    printf "\033[?25h\r\033[K"
}

# ===================== FUNCIONES DE LAYOUT =====================

##
# Imprime línea separadora
##
print_separator() {
    local char="${1:-$LINE_HORIZONTAL}"
    local width="${2:-80}"
    
    local line
    printf -v line '%*s' "$width" ''
    line=${line// /$char}
    
    colorize "$APP_COLOR_MUTED" "$line"
}

##
# Imprime caja con texto
##
print_box() {
    local text="$*"
    local width=$(( ${#text} + 4 ))
    
    # Línea superior
    local top_line="$LINE_TOP_LEFT"
    printf -v top_line '%s%*s%s' "$LINE_TOP_LEFT" $((width - 2)) '' "$LINE_TOP_RIGHT"
    top_line=${top_line// /$LINE_HORIZONTAL}
    
    # Línea inferior  
    local bottom_line="$LINE_BOTTOM_LEFT"
    printf -v bottom_line '%s%*s%s' "$LINE_BOTTOM_LEFT" $((width - 2)) '' "$LINE_BOTTOM_RIGHT"
    bottom_line=${bottom_line// /$LINE_HORIZONTAL}
    
    echo
    colorize "$APP_COLOR_ACCENT" "$top_line"
    colorize "$APP_COLOR_ACCENT" "$LINE_VERTICAL $text $LINE_VERTICAL"
    colorize "$APP_COLOR_ACCENT" "$bottom_line"
    echo
}

##
# Imprime texto centrado
##
print_centered() {
    local text="$*"
    local width="${TERMINAL_WIDTH:-80}"
    local padding=$(( (width - ${#text}) / 2 ))
    
    printf '%*s%s\n' "$padding" '' "$text"
}

# ===================== FUNCIONES DE UTILIDAD =====================

##
# Detecta ancho del terminal
##
get_terminal_width() {
    if command -v tput >/dev/null 2>&1; then
        tput cols 2>/dev/null || echo 80
    elif [[ -n "${COLUMNS:-}" ]]; then
        echo "$COLUMNS"
    else
        echo 80
    fi
}

##
# Limpia la pantalla si es compatible
##
clear_screen() {
    if [[ -t 1 ]] && command -v clear >/dev/null 2>&1; then
        clear
    else
        printf '\033[2J\033[H'
    fi
}

##
# Mueve cursor a posición específica
##
move_cursor() {
    local row="$1"
    local col="$2"
    printf '\033[%d;%dH' "$row" "$col"
}

##
# Limpia la línea actual
##
clear_line() {
    printf '\r\033[K'
}

# ===================== INICIALIZACIÓN =====================

# Detectar ancho del terminal
readonly TERMINAL_WIDTH=$(get_terminal_width)

# ===================== ALIAS DE COMPATIBILIDAD =====================
# Para retrocompatibilidad con logging.sh y otros módulos

# Alias de colores básicos
readonly RED="$COLOR_RED"
readonly GREEN="$COLOR_GREEN"
readonly YELLOW="$COLOR_YELLOW"
readonly BLUE="$COLOR_BLUE"
readonly CYAN="$COLOR_CYAN"
readonly MAGENTA="$COLOR_PURPLE"
readonly WHITE="$COLOR_WHITE"
readonly NC="$COLOR_RESET"

# Exportar variables críticas para subprocesos
export COLOR_ENABLED
export UNICODE_ENABLED
export TERMINAL_WIDTH
