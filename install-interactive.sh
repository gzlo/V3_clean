#!/bin/bash
# ===================== INSTALADOR INTERACTIVO MOODLE BACKUP V3 =====================
# Instalador automático desde GitHub con configuración asistida
# Autor: Sistema Moodle Backup
# Ejecutar con: bash <(curl -fsSL https://raw.githubusercontent.com/gzlo/moodle-backup/main/install-interactive.sh)
# =====================================================================================

set -euo pipefail

# Colores y estilos
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

# Variables globales
GITHUB_REPO="https://raw.githubusercontent.com/gzlo/moodle-backup/main"
INSTALL_DIR=""
CONFIG_DIR=""
SCRIPT_NAME="moodle-backup"
DETECTED_PANEL=""
GLOBAL_INSTALL=false
SETUP_CRON=true
SETUP_RCLONE=true
MULTI_CLIENT=false

# Funciones de logging con estilo
print_header() {
    echo -e "${BLUE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                    MOODLE BACKUP V3 - INSTALADOR INTERACTIVO               ║"
    echo "║                          Sistema Universal Multi-Panel                      ║"
    echo "║                              by Desarrollador                                   ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log_info() { echo -e "${BLUE}ℹ️  $*${NC}"; }
log_success() { echo -e "${GREEN}✅ $*${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $*${NC}"; }
log_error() { echo -e "${RED}❌ $*${NC}"; }
log_step() { echo -e "${PURPLE}🔧 $*${NC}"; }
log_question() { echo -e "${CYAN}❓ $*${NC}"; }

# Función para pausar y continuar
pause_continue() {
    echo ""
    echo -e "${CYAN}Presiona ENTER para continuar...${NC}"
    read -r
}

# Función para preguntar sí/no
ask_yes_no() {
    local question="$1"
    local default="${2:-n}"
    local response
    
    while true; do
        if [[ "$default" == "y" ]]; then
            echo -e "${CYAN}❓ $question [Y/n]: ${NC}\c"
        else
            echo -e "${CYAN}❓ $question [y/N]: ${NC}\c"
        fi
        
        read -r response
        response=${response:-$default}
        
        case "$response" in
            [Yy]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][Oo]) return 1 ;;
            *) echo -e "${RED}Por favor responde 'y' o 'n'${NC}" ;;
        esac
    done
}

# Función para input con valor por defecto
ask_input() {
    local question="$1"
    local default="$2"
    local response
    
    echo -e "${CYAN}❓ $question${NC}"
    if [[ -n "$default" ]]; then
        echo -e "${CYAN}   (Por defecto: $default): ${NC}\c"
    else
        echo -e "${CYAN}   : ${NC}\c"
    fi
    
    read -r response
    echo "${response:-$default}"
}

# Función para seleccionar de una lista
ask_select() {
    local question="$1"
    shift
    local options=("$@")
    local choice
    
    echo -e "${CYAN}❓ $question${NC}"
    for i in "${!options[@]}"; do
        echo -e "${CYAN}   $((i+1))) ${options[i]}${NC}"
    done
    
    while true; do
        echo -e "${CYAN}   Selecciona [1-${#options[@]}]: ${NC}\c"
        read -r choice
        
        if [[ "$choice" =~ ^[1-9][0-9]*$ ]] && [[ "$choice" -le "${#options[@]}" ]]; then
            echo "${options[$((choice-1))]}"
            return 0
        else
            echo -e "${RED}   Selección inválida. Elige entre 1 y ${#options[@]}${NC}"
        fi
    done
}

# Verificar privilegios y configurar directorios
setup_installation_paths() {
    log_step "Configurando rutas de instalación..."
    
    if [[ $EUID -eq 0 ]]; then
        log_success "Ejecutando como root - Instalación global disponible"
        INSTALL_DIR="/usr/local/bin"
        CONFIG_DIR="/etc"
        GLOBAL_INSTALL=true
    else
        log_warning "Ejecutando como usuario regular"
        INSTALL_DIR="$HOME/bin"
        CONFIG_DIR="$HOME"
        GLOBAL_INSTALL=false
        mkdir -p "$INSTALL_DIR"
        
        if ask_yes_no "¿Deseas intentar instalación global? (requiere sudo)" "n"; then
            if sudo -n true 2>/dev/null; then
                log_success "Permisos sudo verificados"
                INSTALL_DIR="/usr/local/bin"
                CONFIG_DIR="/etc"
                GLOBAL_INSTALL=true
            else
                log_warning "No se puede usar sudo, continuando con instalación local"
            fi
        fi
    fi
    
    log_info "Directorio de instalación: $INSTALL_DIR"
    log_info "Directorio de configuración: $CONFIG_DIR"
}

# Detectar distribución Linux
detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$ID"
    elif [[ -f /etc/redhat-release ]]; then
        echo "rhel"
    elif [[ -f /etc/debian_version ]]; then
        echo "debian"
    else
        echo "unknown"
    fi
}

# Instalar dependencias automáticamente
install_dependencies() {
    log_step "Verificando e instalando dependencias..."
    
    local distro=$(detect_distro)
    local missing_deps=()
    local install_cmd=""
    
    # Verificar dependencias
    for cmd in mysqldump tar zstd curl wget; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    # Configurar comando de instalación según distribución
    case "$distro" in
        "ubuntu"|"debian")
            install_cmd="apt update && apt install -y"
            # Mapear nombres de paquetes
            missing_deps=("${missing_deps[@]//mysqldump/mysql-client}")
            missing_deps=("${missing_deps[@]//zstd/zstd}")
            ;;
        "centos"|"rhel"|"fedora"|"amzn")
            if command -v dnf >/dev/null 2>&1; then
                install_cmd="dnf install -y"
            else
                install_cmd="yum install -y"
            fi
            # Mapear nombres de paquetes
            missing_deps=("${missing_deps[@]//mysqldump/mysql}")
            missing_deps=("${missing_deps[@]//zstd/zstd}")
            ;;
        *)
            log_warning "Distribución no reconocida, verificar dependencias manualmente"
            ;;
    esac
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_warning "Dependencias faltantes: ${missing_deps[*]}"
        
        if [[ -n "$install_cmd" ]]; then
            if ask_yes_no "¿Instalar dependencias automáticamente?" "y"; then
                log_info "Instalando dependencias..."
                if [[ "$GLOBAL_INSTALL" == true ]]; then
                    eval "$install_cmd ${missing_deps[*]}"
                else
                    eval "sudo $install_cmd ${missing_deps[*]}"
                fi
                log_success "Dependencias instaladas"
            else
                log_warning "Instalar manualmente: $install_cmd ${missing_deps[*]}"
            fi
        fi
    else
        log_success "Todas las dependencias están instaladas"
    fi
}

# Verificar/instalar rclone
setup_rclone() {
    log_step "Configurando rclone..."
    
    if ! command -v rclone >/dev/null 2>&1; then
        log_warning "rclone no está instalado"
        
        if ask_yes_no "¿Instalar rclone automáticamente?" "y"; then
            log_info "Descargando e instalando rclone..."
            curl https://rclone.org/install.sh | bash
            log_success "rclone instalado"
        else
            log_warning "Instalar rclone manualmente: https://rclone.org/downloads/"
            SETUP_RCLONE=false
            return
        fi
    fi
    
    # Verificar configuración de Google Drive
    if ! rclone listremotes | grep -q "gdrive:"; then
        log_warning "rclone no está configurado para Google Drive"
        
        if ask_yes_no "¿Configurar Google Drive ahora?" "y"; then
            log_info "Iniciando configuración de rclone..."
            echo ""
            echo -e "${YELLOW}INSTRUCCIONES PARA GOOGLE DRIVE:${NC}"
            echo -e "${YELLOW}1. Selecciona: Google Drive (opción ~15)${NC}"
            echo -e "${YELLOW}2. Nombre del remote: gdrive${NC}"
            echo -e "${YELLOW}3. Usa configuración automática cuando se pregunte${NC}"
            echo -e "${YELLOW}4. Autoriza en el navegador que se abrirá${NC}"
            echo ""
            pause_continue
            
            rclone config
            
            if rclone listremotes | grep -q "gdrive:"; then
                log_success "Google Drive configurado correctamente"
                # Probar conexión
                if rclone lsd gdrive: >/dev/null 2>&1; then
                    log_success "Conexión con Google Drive verificada"
                else
                    log_warning "Conexión con Google Drive falló, verificar configuración"
                fi
            else
                log_warning "Google Drive no configurado, se puede configurar después"
                SETUP_RCLONE=false
            fi
        else
            SETUP_RCLONE=false
        fi
    else
        log_success "rclone ya está configurado para Google Drive"
        
        # Verificar conexión
        if rclone lsd gdrive: >/dev/null 2>&1; then
            log_success "Conexión con Google Drive verificada"
        else
            log_warning "Problemas con la conexión a Google Drive"
            if ask_yes_no "¿Reconfigurar Google Drive?" "y"; then
                rclone config
            fi
        fi
    fi
}

# Detectar panel de control
detect_panel() {
    log_step "Detectando panel de control..."
    
    if [[ -d "/usr/local/cpanel" ]] || command -v whmapi1 >/dev/null 2>&1; then
        DETECTED_PANEL="cpanel"
        log_success "Detectado: cPanel/WHM"
    elif [[ -d "/opt/psa" ]] || command -v plesk >/dev/null 2>&1; then
        DETECTED_PANEL="plesk"
        log_success "Detectado: Plesk"
    elif [[ -d "/usr/local/directadmin" ]]; then
        DETECTED_PANEL="directadmin"
        log_success "Detectado: DirectAdmin"
    elif [[ -d "/usr/local/vesta" ]] || [[ -d "/usr/local/hestia" ]]; then
        DETECTED_PANEL="vestacp"
        log_success "Detectado: VestaCP/HestiaCP"
    elif [[ -d "/usr/local/ispconfig" ]]; then
        DETECTED_PANEL="ispconfig"
        log_success "Detectado: ISPConfig"
    else
        DETECTED_PANEL="manual"
        log_warning "No se detectó panel específico - Servidor manual"
    fi
    
    # Confirmar detección
    local panels=("cpanel" "plesk" "directadmin" "vestacp" "ispconfig" "manual")
    if ask_yes_no "¿Confirmar panel detectado: $DETECTED_PANEL?" "y"; then
        log_success "Panel confirmado: $DETECTED_PANEL"
    else
        log_question "Seleccionar panel manualmente:"
        DETECTED_PANEL=$(ask_select "Tipo de panel:" "${panels[@]}")
        log_success "Panel seleccionado: $DETECTED_PANEL"
    fi
}

# Descargar archivos desde GitHub
download_files() {
    log_step "Descargando archivos desde GitHub..."
    
    local files=(
        "moodle_backup.sh"
        "mb"
        "moodle_backup.conf.example"
    )
    
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    for file in "${files[@]}"; do
        log_info "Descargando: $file"
        if curl -fsSL "$GITHUB_REPO/$file" -o "$file"; then
            chmod +x "$file" 2>/dev/null || true
            log_success "✓ $file descargado"
        else
            log_error "Error descargando $file"
            exit 1
        fi
    done
    
    echo "$temp_dir"
}

# Configurar instalación básica
configure_basic_setup() {
    log_step "Configuración básica del cliente..."
    
    local client_name hostname_clean
    hostname_clean=$(hostname | tr '.' '_' | tr '-' '_')
    
    client_name=$(ask_input "Nombre del cliente (identificador único)" "cliente_$hostname_clean")
    local client_desc=$(ask_input "Descripción del cliente" "Backup Moodle - $client_name")
    
    # Configurar email de notificación (OBLIGATORIO)
    log_step "Configuración de notificaciones por email..."
    echo -e "${YELLOW}⚠️  IMPORTANTE: El email de notificación es OBLIGATORIO${NC}"
    echo -e "   Sin email configurado, el script no funcionará."
    echo
    
    local notification_email=""
    while [[ -z "$notification_email" ]]; do
        notification_email=$(ask_input "Email para notificaciones (OBLIGATORIO)" "")
        
        # Validar formato básico de email
        if [[ ! "$notification_email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
            log_error "Email inválido. Por favor ingresa un email válido."
            notification_email=""
        fi
    done
    
    log_success "Email configurado: $notification_email"
    
    # Preguntar sobre configuración multi-cliente
    if ask_yes_no "¿Este servidor tendrá múltiples clientes Moodle?" "n"; then
        MULTI_CLIENT=true
        log_info "Configuración multi-cliente habilitada"
        log_info "Podrás agregar más configuraciones después"
    fi
    
    # Crear configuración inicial
    local config_path="$CONFIG_DIR/moodle_backup.conf"
    
    cat > "$config_path" << EOF
# ===================== CONFIGURACIÓN MOODLE BACKUP V3 =====================
# Generado automáticamente por el instalador interactivo
# Fecha: $(date)
# Panel detectado: $DETECTED_PANEL
# =========================================================================

# ===================== CONFIGURACIÓN BÁSICA =====================
CLIENT_NAME=$client_name
CLIENT_DESCRIPTION="$client_desc"

# ===================== CONFIGURACIÓN DEL PANEL =====================
PANEL_TYPE=$DETECTED_PANEL
REQUIRE_CONFIG=false  # Permitir auto-detección como complemento

# ===================== CONFIGURACIÓN ESPECÍFICA =====================
# Las siguientes variables se auto-detectarán si están vacías
CPANEL_USER=""        # Se auto-detecta desde \$USER
WWW_DIR=""           # Se auto-detecta según el panel
MOODLEDATA_DIR=""    # Se auto-detecta desde config.php
DOMAIN_NAME=""       # Necesario para Plesk y DirectAdmin

# ===================== CONFIGURACIÓN DE BACKUP =====================
GDRIVE_REMOTE="gdrive:moodle_backups"
TMP_DIR="/tmp/moodle_backup"
MAX_BACKUPS_GDRIVE=2

# ===================== CONFIGURACIÓN AVANZADA =====================
AUTO_DETECT_AGGRESSIVE=true
FORCE_THREADS=0
FORCE_COMPRESSION_LEVEL=1
OPTIMIZED_HOURS="02-08"

# ===================== NOTIFICACIONES =====================
NOTIFICATION_EMAILS_EXTRA="$notification_email"  # Email de notificación configurado

# ===================== NOTAS =====================
# - Ejecutar: mb-config para ver configuración actual
# - Editar este archivo para personalizar configuración
# - Ver ejemplos en: moodle_backup.conf.example
EOF
    
    chmod 600 "$config_path"
    if [[ "$GLOBAL_INSTALL" == true ]]; then
        chown root:root "$config_path" 2>/dev/null || true
    fi
    
    log_success "Configuración básica creada: $config_path"
    
    # Mostrar configuración específica por panel
    case "$DETECTED_PANEL" in
        "plesk"|"directadmin"|"vestacp")
            local domain_name=$(ask_input "Nombre del dominio (opcional pero recomendado)" "")
            if [[ -n "$domain_name" ]]; then
                sed -i "s/DOMAIN_NAME=\"\"/DOMAIN_NAME=\"$domain_name\"/" "$config_path"
                log_success "Dominio configurado: $domain_name"
            fi
            ;;
    esac
}

# Configurar cron job
setup_cron_job() {
    if ! ask_yes_no "¿Configurar backup automático con cron?" "y"; then
        SETUP_CRON=false
        return
    fi
    
    log_step "Configurando tarea cron..."
    
    # Opciones de horario
    local schedule_options=(
        "2:00 AM diario (recomendado)"
        "3:00 AM diario"
        "1:00 AM diario"
        "Horario personalizado"
        "No configurar ahora"
    )
    
    local selected_schedule=$(ask_select "¿Cuándo ejecutar el backup?" "${schedule_options[@]}")
    
    local cron_time=""
    case "$selected_schedule" in
        "2:00 AM diario (recomendado)")
            cron_time="0 2 * * *"
            ;;
        "3:00 AM diario")
            cron_time="0 3 * * *"
            ;;
        "1:00 AM diario")
            cron_time="0 1 * * *"
            ;;
        "Horario personalizado")
            local hour=$(ask_input "Hora (0-23)" "2")
            local minute=$(ask_input "Minuto (0-59)" "0")
            cron_time="$minute $hour * * *"
            ;;
        "No configurar ahora")
            SETUP_CRON=false
            return
            ;;
    esac
    
    # Configurar cron
    local cron_command="$INSTALL_DIR/$SCRIPT_NAME 2>&1 | logger -t moodle-backup"
    local cron_entry="$cron_time $cron_command"
    
    if [[ "$GLOBAL_INSTALL" == true ]]; then
        # Agregar a crontab de root
        (crontab -l 2>/dev/null || true; echo "$cron_entry") | crontab -
        log_success "Cron job configurado para root: $selected_schedule"
    else
        # Agregar a crontab del usuario
        (crontab -l 2>/dev/null || true; echo "$cron_entry") | crontab -
        log_success "Cron job configurado para usuario: $selected_schedule"
    fi
    
    log_info "Comando cron: $cron_entry"
}

# Instalar archivos
install_files() {
    log_step "Instalando archivos..."
    
    local temp_dir="$1"
    
    # Instalar script principal
    cp "$temp_dir/moodle_backup.sh" "$INSTALL_DIR/$SCRIPT_NAME"
    chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
    log_success "Script principal instalado: $INSTALL_DIR/$SCRIPT_NAME"
    
    # Instalar wrapper
    cp "$temp_dir/mb" "$INSTALL_DIR/mb"
    chmod +x "$INSTALL_DIR/mb"
    log_success "Wrapper instalado: $INSTALL_DIR/mb"
    
    # Instalar configuración de ejemplo
    cp "$temp_dir/moodle_backup.conf.example" "$CONFIG_DIR/"
    log_success "Configuración de ejemplo instalada: $CONFIG_DIR/moodle_backup.conf.example"
    
    # Configurar aliases
    local bashrc_file="$HOME/.bashrc"
    if [[ "$GLOBAL_INSTALL" == true ]] && [[ -f "/etc/bash.bashrc" ]]; then
        bashrc_file="/etc/bash.bashrc"
    fi
    
    if ! grep -q "# Moodle Backup V3 - Aliases" "$bashrc_file" 2>/dev/null; then
        cat >> "$bashrc_file" << EOF

# Moodle Backup V3 - Aliases (Instalado: $(date))
alias mb='$INSTALL_DIR/mb'
alias mb-config='$INSTALL_DIR/mb config'
alias mb-test='$INSTALL_DIR/mb test'
alias mb-help='$INSTALL_DIR/mb help'
alias mb-diag='$INSTALL_DIR/mb diag'
alias mb-status='$INSTALL_DIR/mb status'
alias mb-logs='$INSTALL_DIR/mb logs'
alias mb-clean='$INSTALL_DIR/mb clean'
EOF
        log_success "Aliases configurados en: $bashrc_file"
    fi
    
    # Agregar al PATH si es instalación local
    if [[ "$GLOBAL_INSTALL" == false ]]; then
        if ! grep -q 'export PATH="$HOME/bin:$PATH"' "$HOME/.bashrc" 2>/dev/null; then
            echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
            log_success "Directorio ~/bin agregado al PATH"
        fi
    fi
    
    # Configurar permisos
    if [[ "$GLOBAL_INSTALL" == true ]]; then
        chown root:root "$INSTALL_DIR/$SCRIPT_NAME" "$INSTALL_DIR/mb" 2>/dev/null || true
    fi
}

# Prueba final de la instalación
test_installation() {
    log_step "Probando instalación..."
    
    # Probar comando principal
    if "$INSTALL_DIR/$SCRIPT_NAME" --help >/dev/null 2>&1; then
        log_success "Script principal funciona correctamente"
    else
        log_error "Error en el script principal"
        return 1
    fi
    
    # Probar wrapper
    if "$INSTALL_DIR/mb" version >/dev/null 2>&1; then
        log_success "Wrapper funciona correctamente"
    else
        log_error "Error en el wrapper"
        return 1
    fi
    
    # Probar configuración
    log_info "Probando configuración..."
    "$INSTALL_DIR/mb" config 2>&1 | head -10
    
    log_success "🎉 Instalación completada exitosamente"
}

# Mostrar resumen final
show_final_summary() {
    echo ""
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║                          INSTALACIÓN COMPLETADA                             ║${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${BLUE}📍 UBICACIONES DE ARCHIVOS:${NC}"
    echo -e "  Script principal: ${YELLOW}$INSTALL_DIR/$SCRIPT_NAME${NC}"
    echo -e "  Wrapper:         ${YELLOW}$INSTALL_DIR/mb${NC}"
    echo -e "  Configuración:   ${YELLOW}$CONFIG_DIR/moodle_backup.conf${NC}"
    echo ""
    
    echo -e "${BLUE}🚀 PRIMEROS PASOS:${NC}"
    echo -e "  1. Recargar configuración: ${CYAN}source ~/.bashrc${NC}"
    echo -e "  2. Ver configuración:      ${CYAN}mb-config${NC}"
    echo -e "  3. Probar Google Drive:    ${CYAN}mb-test${NC}"
    echo -e "  4. Ejecutar primer backup: ${CYAN}mb${NC}"
    echo ""
    
    echo -e "${BLUE}📋 COMANDOS DISPONIBLES:${NC}"
    echo -e "  ${CYAN}mb${NC}           - Ejecutar backup"
    echo -e "  ${CYAN}mb-config${NC}    - Ver configuración"
    echo -e "  ${CYAN}mb-test${NC}      - Probar Google Drive"
    echo -e "  ${CYAN}mb-help${NC}      - Ver ayuda completa"
    echo -e "  ${CYAN}mb-diag${NC}      - Diagnóstico del sistema"
    echo -e "  ${CYAN}mb-status${NC}    - Estado del último backup"
    echo -e "  ${CYAN}mb-logs${NC}      - Ver logs recientes"
    echo -e "  ${CYAN}mb-clean${NC}     - Limpiar archivos temporales"
    echo ""
    
    if [[ "$SETUP_CRON" == true ]]; then
        echo -e "${BLUE}⏰ BACKUP AUTOMÁTICO CONFIGURADO${NC}"
        echo -e "  Los backups se ejecutarán automáticamente según el horario configurado"
        echo ""
    fi
    
    if [[ "$MULTI_CLIENT" == true ]]; then
        echo -e "${BLUE}🔧 CONFIGURACIÓN MULTI-CLIENTE:${NC}"
        echo -e "  Para agregar más clientes:"
        echo -e "  ${CYAN}cp $CONFIG_DIR/moodle_backup.conf $CONFIG_DIR/moodle_backup_cliente2.conf${NC}"
        echo -e "  ${CYAN}nano $CONFIG_DIR/moodle_backup_cliente2.conf${NC}"
        echo ""
    fi
    
    echo -e "${BLUE}📞 SOPORTE:${NC}"
    echo -e "  GitHub: ${CYAN}https://github.com/gzlo/moodle-backup${NC}"
    echo -e "  Issues: ${CYAN}https://github.com/gzlo/moodle-backup/issues${NC}"
    echo ""
    
    if ask_yes_no "¿Deseas ejecutar una prueba completa ahora?" "y"; then
        echo ""
        log_step "Ejecutando prueba completa..."
        source ~/.bashrc 2>/dev/null || true
        export PATH="$INSTALL_DIR:$PATH"
        "$INSTALL_DIR/mb" config
    fi
    
    # Preguntar si necesita configuraciones adicionales
    if ask_yes_no "¿Necesitas configurar otro cliente/instalación Moodle?" "n"; then
        echo ""
        log_info "Para configurar clientes adicionales:"
        echo -e "  1. Copia la configuración: ${CYAN}cp $CONFIG_DIR/moodle_backup.conf $CONFIG_DIR/moodle_backup_cliente2.conf${NC}"
        echo -e "  2. Edita el nuevo archivo: ${CYAN}nano $CONFIG_DIR/moodle_backup_cliente2.conf${NC}"
        echo -e "  3. Cambia CLIENT_NAME y rutas específicas"
        echo -e "  4. Ejecuta con configuración específica: ${CYAN}CLIENT_NAME=cliente2 mb${NC}"
    fi
}

# Función principal
main() {
    print_header
    
    echo -e "${BLUE}Este instalador configurará Moodle Backup V3 en tu servidor.${NC}"
    echo -e "${BLUE}Se detectará automáticamente el tipo de panel y configuración.${NC}"
    echo ""
    
    if ! ask_yes_no "¿Continuar con la instalación?" "y"; then
        log_info "Instalación cancelada por el usuario"
        exit 0
    fi
    
    echo ""
    
    # Pasos de instalación
    setup_installation_paths
    detect_panel
    install_dependencies
    setup_rclone
    
    local temp_dir
    temp_dir=$(download_files)
    
    configure_basic_setup
    install_files "$temp_dir"
    setup_cron_job
    
    # Limpiar archivos temporales
    rm -rf "$temp_dir"
    
    test_installation
    show_final_summary
    
    echo -e "${GREEN}🎉 ¡Instalación completada exitosamente!${NC}"
    echo -e "${BLUE}Reinicia tu sesión o ejecuta: ${CYAN}source ~/.bashrc${NC}"
}

# Verificar requisitos mínimos
if [[ "${BASH_VERSION%%.*}" -lt 4 ]]; then
    log_error "Bash 4.0+ requerido. Versión actual: $BASH_VERSION"
    exit 1
fi

# Ejecutar instalador
main "$@"
