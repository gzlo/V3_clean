#!/bin/bash

# ===================== INSTALADOR MOODLE BACKUP V3 =====================
# Instalador automático para Moodle Backup V3 - Script Universal Multi-Panel
# Autor: Sistema Moodle Backup - Versión: 3.0
# Fecha: 2025-06-29
#
# USO:
#   curl -fsSL https://raw.githubusercontent.com/gzlo/moodle-backup/main/install.sh | bash
#   wget -qO- https://raw.githubusercontent.com/gzlo/moodle-backup/main/install.sh | bash
#
# FUNCIONALIDADES:
# - Detección automática del sistema operativo (CentOS/RHEL/Fedora vs Ubuntu/Debian)
# - Instalación de dependencias usando yum/dnf o apt según corresponda
# - Detección y configuración de rclone para Google Drive
# - Configuración asistida de cron con horarios amigables
# - Instalación multi-cliente con configuraciones independientes
# - Verificación post-instalación y testing
# - NUEVO: Auto-detección de configuración desde config.php de Moodle
# ===============================================================================

set -euo pipefail

# Colores para output amigable
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Variables del instalador
REPO_URL="https://raw.githubusercontent.com/gzlo/moodle-backup/main"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc"
USER_INSTALL_DIR="$HOME/bin"
USER_CONFIG_DIR="$HOME/.config/moodle-backup"
TEMP_DIR="/tmp/moodle-backup-install-$$"

# Variables para configuración detectada desde Moodle
DETECTED_DB_HOST=""
DETECTED_DB_NAME=""
DETECTED_DB_USER=""
DETECTED_DB_PASS=""
DETECTED_DATAROOT=""
DETECTED_WWWROOT=""
DETECTED_CONFIG_FOUND=false

# Funciones de logging amigables
print_header() {
    echo ""
    echo -e "${PURPLE}===============================================${NC}"
    echo -e "${PURPLE}  $1${NC}"
    echo -e "${PURPLE}===============================================${NC}"
    echo ""
}

print_step() {
    echo -e "${BLUE}➤ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# ===================== FUNCIÓN PARA PARSEAR CONFIG.PHP DE MOODLE =====================
# Función para extraer configuración desde config.php de Moodle
parse_moodle_config() {
    local config_path="$1"
    local base_dir="$2"  # Directorio base para buscar config.php si no se proporciona path
    
    # Variables de salida (globales)
    DETECTED_DB_HOST=""
    DETECTED_DB_NAME=""
    DETECTED_DB_USER=""
    DETECTED_DB_PASS=""
    DETECTED_DATAROOT=""
    DETECTED_WWWROOT=""
    DETECTED_CONFIG_FOUND=false
    
    # Determinar ruta del config.php
    local config_file=""
    if [[ -n "$config_path" ]] && [[ -f "$config_path" ]]; then
        config_file="$config_path"
    elif [[ -n "$base_dir" ]] && [[ -f "$base_dir/config.php" ]]; then
        config_file="$base_dir/config.php"
    else
        print_warning "No se pudo encontrar config.php en las rutas especificadas"
        return 1
    fi
    
    # Verificar que es un config.php válido de Moodle
    if ! grep -q '\$CFG.*=' "$config_file" 2>/dev/null; then
        print_warning "El archivo $config_file no parece ser un config.php válido de Moodle"
        return 1
    fi
    
    print_step "Parseando configuración de Moodle desde: $config_file"
    
    # Extraer variables de configuración usando sed/grep robusto
    # $CFG->dbhost
    if DETECTED_DB_HOST=$(grep -E "^\s*\\\$CFG->dbhost\s*=" "$config_file" | head -1 | sed "s/.*=\s*['\"]//;s/['\"];.*//;s/['\"].*//"); then
        [[ -n "$DETECTED_DB_HOST" ]] && print_success "Host BD detectado: $DETECTED_DB_HOST"
    fi
    
    # $CFG->dbname
    if DETECTED_DB_NAME=$(grep -E "^\s*\\\$CFG->dbname\s*=" "$config_file" | head -1 | sed "s/.*=\s*['\"]//;s/['\"];.*//;s/['\"].*//"); then
        [[ -n "$DETECTED_DB_NAME" ]] && print_success "Nombre BD detectado: $DETECTED_DB_NAME"
    fi
    
    # $CFG->dbuser
    if DETECTED_DB_USER=$(grep -E "^\s*\\\$CFG->dbuser\s*=" "$config_file" | head -1 | sed "s/.*=\s*['\"]//;s/['\"];.*//;s/['\"].*//"); then
        [[ -n "$DETECTED_DB_USER" ]] && print_success "Usuario BD detectado: $DETECTED_DB_USER"
    fi
    
    # $CFG->dbpass (más sensible)
    if DETECTED_DB_PASS=$(grep -E "^\s*\\\$CFG->dbpass\s*=" "$config_file" | head -1 | sed "s/.*=\s*['\"]//;s/['\"];.*//;s/['\"].*//"); then
        [[ -n "$DETECTED_DB_PASS" ]] && print_success "Contraseña BD detectada: [****]"
    fi
    
    # $CFG->dataroot
    if DETECTED_DATAROOT=$(grep -E "^\s*\\\$CFG->dataroot\s*=" "$config_file" | head -1 | sed "s/.*=\s*['\"]//;s/['\"];.*//;s/['\"].*//"); then
        [[ -n "$DETECTED_DATAROOT" ]] && print_success "Directorio de datos detectado: $DETECTED_DATAROOT"
    fi
    
    # $CFG->wwwroot (opcional, para validación)
    if DETECTED_WWWROOT=$(grep -E "^\s*\\\$CFG->wwwroot\s*=" "$config_file" | head -1 | sed "s/.*=\s*['\"]//;s/['\"];.*//;s/['\"].*//"); then
        [[ -n "$DETECTED_WWWROOT" ]] && print_step "URL raíz detectada: $DETECTED_WWWROOT"
    fi
    
    # Validar que se encontraron los datos críticos
    if [[ -n "$DETECTED_DB_HOST" ]] && [[ -n "$DETECTED_DB_NAME" ]] && [[ -n "$DETECTED_DB_USER" ]]; then
        DETECTED_CONFIG_FOUND=true
        print_success "Configuración de Moodle detectada exitosamente"
        return 0
    else
        print_warning "Configuración de Moodle incompleta (faltan datos críticos)"
        return 1
    fi
}

# Función para buscar instalaciones de Moodle automáticamente
auto_discover_moodle_simple() {
    print_step "Buscando instalaciones de Moodle automáticamente..."
    
    # Directorios comunes donde buscar
    local search_dirs=(
        "/var/www/html"
        "/var/www"
        "/srv/www"
        "/opt/lampp/htdocs"
        "/usr/local/apache2/htdocs"
        "/home/*/public_html"
        "/home/*/www"
        "/home/*/htdocs"
        "/home/*/domains/*/public_html"
    )
    
    local found_configs=()
    local found_dirs=()
    
    # Buscar config.php en los directorios candidatos
    for dir_pattern in "${search_dirs[@]}"; do
        # Expandir wildcards si existen
        for dir in $dir_pattern; do
            if [[ -d "$dir" ]] && [[ -f "$dir/config.php" ]]; then
                # Verificar que es un config.php de Moodle
                if grep -q '\$CFG.*dbname\|\$CFG.*wwwroot' "$dir/config.php" 2>/dev/null; then
                    found_configs+=("$dir/config.php")
                    found_dirs+=("$dir")
                    print_step "Instalación Moodle encontrada: $dir"
                fi
            fi
        done
    done
    
    if [[ ${#found_configs[@]} -gt 0 ]]; then
        print_success "Se encontraron ${#found_configs[@]} instalaciones de Moodle"
        
        # Si hay una sola instalación, usarla automáticamente
        if [[ ${#found_configs[@]} -eq 1 ]]; then
            if parse_moodle_config "${found_configs[0]}" "${found_dirs[0]}"; then
                echo ""
                print_success "Configuración cargada automáticamente desde: ${found_dirs[0]}"
                echo "• Host BD: $DETECTED_DB_HOST"
                echo "• Nombre BD: $DETECTED_DB_NAME"
                echo "• Usuario BD: $DETECTED_DB_USER"
                echo "• Directorio datos: $DETECTED_DATAROOT"
                echo ""
                return 0
            fi
        else
            # Múltiples instalaciones - mostrar opciones
            echo ""
            echo "Seleccione la instalación de Moodle a usar:"
            for i in "${!found_dirs[@]}"; do
                echo "$((i + 1)). ${found_dirs[$i]}"
            done
            echo "0. Configurar manualmente"
            echo ""
            
            local selection=""
            while true; do
                echo -n "Seleccione opción [1-${#found_dirs[@]}] o 0 para manual: "
                read -r selection
                
                if [[ "$selection" =~ ^[0-9]+$ ]] && [[ $selection -ge 0 ]] && [[ $selection -le ${#found_dirs[@]} ]]; then
                    break
                else
                    print_warning "Selección inválida. Ingrese un número entre 0 y ${#found_dirs[@]}"
                fi
            done
            
            if [[ $selection -gt 0 ]]; then
                local selected_index=$((selection - 1))
                if parse_moodle_config "${found_configs[$selected_index]}" "${found_dirs[$selected_index]}"; then
                    print_success "Configuración cargada desde: ${found_dirs[$selected_index]}"
                    return 0
                fi
            fi
        fi
    else
        print_warning "No se encontraron instalaciones de Moodle automáticamente"
    fi
    
    return 1
}

# Banner de bienvenida
print_banner() {
    echo -e "${PURPLE}"
    cat << 'EOF'
    ███╗   ███╗ ██████╗  ██████╗ ██████╗ ██╗     ███████╗
    ████╗ ████║██╔═══██╗██╔═══██╗██╔══██╗██║     ██╔════╝
    ██╔████╔██║██║   ██║██║   ██║██║  ██║██║     █████╗  
    ██║╚██╔╝██║██║   ██║██║   ██║██║  ██║██║     ██╔══╝  
    ██║ ╚═╝ ██║╚██████╔╝╚██████╔╝██████╔╝███████╗███████╗
    ╚═╝     ╚═╝ ╚═════╝  ╚═════╝ ╚═════╝ ╚══════╝╚══════╝
                                                          
     ██████╗  █████╗  ██████╗██╗  ██╗██╗   ██╗██████╗ 
     ██╔══██╗██╔══██╗██╔════╝██║ ██╔╝██║   ██║██╔══██╗
     ██████╔╝███████║██║     █████╔╝ ██║   ██║██████╔╝
     ██╔══██╗██╔══██║██║     ██╔═██╗ ██║   ██║██╔═══╝ 
     ██████╔╝██║  ██║╚██████╗██║  ██╗╚██████╔╝██║     
     ╚═════╝ ╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝ ╚═════╝ ╚═╝     
                                                      
               INSTALADOR AUTOMÁTICO V3
                     by GZLOnline
EOF
    echo -e "${NC}"
}

# Función para detectar el sistema operativo
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_ID="$ID"
        OS_VERSION="$VERSION_ID"
        
        case "$OS_ID" in
            "centos"|"rhel"|"fedora"|"rocky"|"almalinux")
                PACKAGE_MANAGER="yum"
                [[ -x "$(command -v dnf)" ]] && PACKAGE_MANAGER="dnf"
                INSTALL_CMD="$PACKAGE_MANAGER install -y"
                UPDATE_CMD="$PACKAGE_MANAGER update -y"
                ;;
            "ubuntu"|"debian"|"linuxmint")
                PACKAGE_MANAGER="apt"
                INSTALL_CMD="apt-get install -y"
                UPDATE_CMD="apt-get update"
                ;;
            *)
                print_warning "Sistema operativo no reconocido: $OS_ID"
                print_info "Intentando detección genérica..."
                if command -v yum >/dev/null 2>&1; then
                    PACKAGE_MANAGER="yum"
                    INSTALL_CMD="yum install -y"
                    UPDATE_CMD="yum update -y"
                elif command -v dnf >/dev/null 2>&1; then
                    PACKAGE_MANAGER="dnf"
                    INSTALL_CMD="dnf install -y"
                    UPDATE_CMD="dnf update -y"
                elif command -v apt-get >/dev/null 2>&1; then
                    PACKAGE_MANAGER="apt"
                    INSTALL_CMD="apt-get install -y"
                    UPDATE_CMD="apt-get update"
                else
                    print_error "No se pudo detectar el gestor de paquetes"
                    exit 1
                fi
                ;;
        esac
    else
        print_error "No se pudo detectar el sistema operativo"
        exit 1
    fi
    
    print_success "Sistema detectado: $OS_ID $OS_VERSION ($PACKAGE_MANAGER)"
}

# Función para verificar permisos de instalación
check_installation_permissions() {
    if [[ $EUID -eq 0 ]]; then
        INSTALL_MODE="system"
        FINAL_INSTALL_DIR="$INSTALL_DIR"
        FINAL_CONFIG_DIR="$CONFIG_DIR"
        print_info "Instalación del sistema (como root)"
    else
        if [[ -w "$INSTALL_DIR" ]] && [[ -w "$CONFIG_DIR" ]]; then
            INSTALL_MODE="system"
            FINAL_INSTALL_DIR="$INSTALL_DIR"
            FINAL_CONFIG_DIR="$CONFIG_DIR"
            print_info "Instalación del sistema (con permisos de escritura)"
        else
            INSTALL_MODE="user"
            FINAL_INSTALL_DIR="$USER_INSTALL_DIR"
            FINAL_CONFIG_DIR="$USER_CONFIG_DIR"
            print_info "Instalación de usuario en: $FINAL_INSTALL_DIR"
            
            # Crear directorios de usuario si no existen
            mkdir -p "$FINAL_INSTALL_DIR" "$FINAL_CONFIG_DIR"
            
            # Agregar al PATH si no está
            if [[ ":$PATH:" != *":$FINAL_INSTALL_DIR:"* ]]; then
                echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
                export PATH="$FINAL_INSTALL_DIR:$PATH"
                print_info "Agregado $FINAL_INSTALL_DIR al PATH en ~/.bashrc"
            fi
        fi
    fi
}

# Función para instalar dependencias
install_dependencies() {
    print_step "Verificando e instalando dependencias..."
    
    local dependencies_system=()
    local dependencies_missing=()
    
    # Dependencias básicas del sistema
    case "$PACKAGE_MANAGER" in
        "yum"|"dnf")
            dependencies_system=(
                "mysql"           # Cliente MySQL
                "tar"             # Archivado
                "gzip"            # Compresión gzip
                "zstd"            # Compresión zstd
                "curl"            # Para descargas
                "wget"            # Para descargas alternativas
                "crontabs"        # Servicio cron
            )
            ;;
        "apt")
            dependencies_system=(
                "mysql-client"    # Cliente MySQL
                "tar"             # Archivado
                "gzip"            # Compresión gzip
                "zstd"            # Compresión zstd
                "curl"            # Para descargas
                "wget"            # Para descargas alternativas
                "cron"            # Servicio cron
            )
            
            # Actualizar cache de paquetes para apt
            if [[ $EUID -eq 0 ]] || sudo -n true 2>/dev/null; then
                print_step "Actualizando cache de paquetes..."
                [[ $EUID -eq 0 ]] && $UPDATE_CMD || sudo $UPDATE_CMD
            fi
            ;;
    esac
    
    # Verificar qué dependencias faltan
    for dep in "${dependencies_system[@]}"; do
        local package_name="$dep"
        local command_name="$dep"
        
        # Mapeo especial para algunos comandos
        case "$dep" in
            "mysql"|"mysql-client")
                command_name="mysql"
                ;;
            "crontabs"|"cron")
                command_name="crontab"
                ;;
        esac
        
        if ! command -v "$command_name" >/dev/null 2>&1; then
            dependencies_missing+=("$package_name")
        fi
    done
    
    # Instalar dependencias faltantes
    if [[ ${#dependencies_missing[@]} -gt 0 ]]; then
        print_step "Instalando dependencias faltantes: ${dependencies_missing[*]}"
        
        if [[ $EUID -eq 0 ]]; then
            $INSTALL_CMD "${dependencies_missing[@]}"
        elif sudo -n true 2>/dev/null; then
            sudo $INSTALL_CMD "${dependencies_missing[@]}"
        else
            print_error "Se necesitan permisos de administrador para instalar dependencias"
            print_info "Dependencias faltantes: ${dependencies_missing[*]}"
            print_info "Instale manualmente o ejecute como root/sudo"
            exit 1
        fi
        
        print_success "Dependencias instaladas correctamente"
    else
        print_success "Todas las dependencias del sistema están disponibles"
    fi
    
    # Verificar e instalar rclone
    install_rclone
}

# Función para instalar rclone
install_rclone() {
    if command -v rclone >/dev/null 2>&1; then
        local rclone_version=$(rclone version | head -n1 | awk '{print $2}')
        print_success "rclone ya está instalado (versión: $rclone_version)"
    else
        print_step "Instalando rclone..."
        
        if [[ $EUID -eq 0 ]] || sudo -n true 2>/dev/null; then
            # Instalación oficial de rclone
            curl https://rclone.org/install.sh | bash
            print_success "rclone instalado correctamente"
        else
            print_warning "No se pueden obtener permisos para instalar rclone globalmente"
            print_info "Instalando rclone en modo usuario..."
            
            # Instalación en directorio de usuario
            mkdir -p "$FINAL_INSTALL_DIR"
            cd "$TEMP_DIR"
            
            # Detectar arquitectura
            local arch=$(uname -m)
            case "$arch" in
                "x86_64") rclone_arch="amd64" ;;
                "i386"|"i686") rclone_arch="386" ;;
                "aarch64") rclone_arch="arm64" ;;
                "armv7l") rclone_arch="arm" ;;
                *) rclone_arch="amd64" ;;
            esac
            
            local rclone_url="https://downloads.rclone.org/rclone-current-linux-${rclone_arch}.zip"
            
            wget "$rclone_url" -O rclone.zip
            unzip -q rclone.zip
            mv rclone-*/rclone "$FINAL_INSTALL_DIR/"
            chmod +x "$FINAL_INSTALL_DIR/rclone"
            
            print_success "rclone instalado en modo usuario"
        fi
    fi
}

# Función para descargar archivos del repositorio
download_files() {
    print_step "Descargando archivos desde GitHub..."
    
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    local files_to_download=(
        "moodle_backup.sh"
        "moodle_backup.conf.example"
        "mb"
    )
    
    for file in "${files_to_download[@]}"; do
        print_step "Descargando $file..."
        if curl -fsSL "$REPO_URL/$file" -o "$file"; then
            print_success "✓ $file descargado"
        else
            print_error "Error descargando $file"
            exit 1
        fi
    done
}

# Función para instalar archivos
install_files() {
    print_step "Instalando archivos..."
    
    # Instalar script principal
    cp moodle_backup.sh "$FINAL_INSTALL_DIR/"
    chmod +x "$FINAL_INSTALL_DIR/moodle_backup.sh"
    print_success "✓ moodle_backup.sh instalado en $FINAL_INSTALL_DIR"
    
    # Instalar wrapper mb
    cp mb "$FINAL_INSTALL_DIR/"
    chmod +x "$FINAL_INSTALL_DIR/mb"
    print_success "✓ Wrapper 'mb' instalado en $FINAL_INSTALL_DIR"
    
    # Instalar archivo de configuración ejemplo
    cp moodle_backup.conf.example "$FINAL_CONFIG_DIR/"
    print_success "✓ Archivo de configuración ejemplo instalado en $FINAL_CONFIG_DIR"
    
    # Crear alias si no existe
    if [[ ! -f ~/.bash_aliases ]] || ! grep -q "alias mb=" ~/.bash_aliases 2>/dev/null; then
        echo "alias mb='$FINAL_INSTALL_DIR/mb'" >> ~/.bash_aliases
        print_info "Alias 'mb' agregado a ~/.bash_aliases"
    fi
}

# Función para configurar rclone si es necesario
configure_rclone() {
    print_header "CONFIGURACIÓN DE RCLONE"
    
    if rclone listremotes | grep -q "gdrive:"; then
        print_success "rclone ya tiene configuración de Google Drive (gdrive:)"
        
        echo -n "¿Desea reconfigurar Google Drive? [y/N]: "
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            configure_rclone_gdrive
        fi
    else
        print_info "No se encontró configuración de Google Drive en rclone"
        echo -n "¿Desea configurar Google Drive ahora? [Y/n]: "
        read -r response
        if [[ "$response" =~ ^[Nn]$ ]]; then
            print_warning "Google Drive no configurado. Deberá configurarlo manualmente más tarde"
            print_info "Ejecute: rclone config"
        else
            configure_rclone_gdrive
        fi
    fi
}

# Función para configurar Google Drive en rclone
configure_rclone_gdrive() {
    print_step "Iniciando configuración de Google Drive..."
    print_info "Se abrirá la configuración interactiva de rclone"
    print_info "Siga las instrucciones para configurar Google Drive como 'gdrive'"
    
    echo ""
    echo -e "${YELLOW}INSTRUCCIONES RÁPIDAS:${NC}"
    echo "1. Elegir 'n' para nueva configuración"
    echo "2. Nombre: gdrive"
    echo "3. Tipo: Google Drive (número correspondiente)"
    echo "4. Client ID y Secret: dejar vacío (presionar Enter)"
    echo "5. Scope: 1 (acceso completo)"
    echo "6. Configuración avanzada: n"
    echo "7. Usar navegador web: y"
    echo "8. Confirmar la configuración"
    echo ""
    
    echo -n "Presione Enter para continuar con la configuración..."
    read -r
    
    rclone config
    
    # Verificar que se configuró correctamente
    if rclone listremotes | grep -q "gdrive:"; then
        print_success "Google Drive configurado correctamente"
        
        # Test de conexión
        print_step "Probando conexión con Google Drive..."
        if rclone lsd gdrive: >/dev/null 2>&1; then
            print_success "✓ Conexión con Google Drive exitosa"
        else
            print_warning "⚠️ Posible problema de conexión con Google Drive"
        fi
    else
        print_error "No se pudo configurar Google Drive"
        print_info "Podrá configurarlo manualmente más tarde con: rclone config"
    fi
}

# Función para configurar el primer cliente
configure_first_client() {
    print_header "CONFIGURACIÓN DEL PRIMER CLIENTE"
    
    local config_file="$FINAL_CONFIG_DIR/moodle_backup.conf"
    
    echo "Vamos a configurar su primera instalación de Moodle para backup."
    echo ""
    
    # Información del cliente
    echo -n "Nombre del cliente [default]: "
    read -r client_name
    client_name="${client_name:-default}"
    
    echo -n "Descripción del cliente [Moodle Backup]: "
    read -r client_description
    client_description="${client_description:-Moodle Backup}"
    
    # Auto-detección de configuración
    print_step "Intentando auto-detectar configuración de Moodle..."
    
    # Ejecutar script en modo test para auto-detectar
    if "$FINAL_INSTALL_DIR/moodle_backup.sh" --auto-detect-test > /tmp/autodetect.log 2>&1; then
        print_success "Auto-detección exitosa"
        
        # Mostrar configuración detectada
        echo ""
        echo -e "${CYAN}Configuración detectada:${NC}"
        cat /tmp/autodetect.log | grep -E "(Detectado|Auto-detectado)" || true
        echo ""
        
        echo -n "¿Usar configuración auto-detectada? [Y/n]: "
        read -r use_autodetect
        
        if [[ ! "$use_autodetect" =~ ^[Nn]$ ]]; then
            # Copiar configuración ejemplo y activar auto-detección
            cp "$FINAL_CONFIG_DIR/moodle_backup.conf.example" "$config_file"
            
            # Personalizar configuración básica
            sed -i "s/CLIENT_NAME=.*/CLIENT_NAME=\"$client_name\"/" "$config_file"
            sed -i "s/CLIENT_DESCRIPTION=.*/CLIENT_DESCRIPTION=\"$client_description\"/" "$config_file"
            sed -i "s/PANEL_TYPE=.*/PANEL_TYPE=\"auto\"/" "$config_file"
            sed -i "s/AUTO_DETECT_AGRESSIVE=.*/AUTO_DETECT_AGRESSIVE=\"true\"/" "$config_file"
            
            print_success "Configuración inicial creada: $config_file"
        else
            manual_configuration_wizard "$config_file" "$client_name" "$client_description"
        fi
    else
        print_warning "Auto-detección falló, usando configuración manual"
        manual_configuration_wizard "$config_file" "$client_name" "$client_description"
    fi
    
    # Limpiar archivo temporal
    rm -f /tmp/autodetect.log
}

# Función para configuración manual asistida
manual_configuration_wizard() {
    local config_file="$1"
    local client_name="$2"
    local client_description="$3"
    
    print_step "Configuración asistida con autodetección de Moodle..."
    
    # NUEVA FUNCIONALIDAD: Autodetección de Moodle
    echo ""
    echo "🔍 DETECCIÓN AUTOMÁTICA DE INSTALACIONES DE MOODLE"
    echo ""
    echo "¿Desea buscar automáticamente instalaciones de Moodle? [Y/n]: "
    read -r auto_detect_choice
    auto_detect_choice="${auto_detect_choice:-Y}"
    
    local config_detected=false
    if [[ "$auto_detect_choice" =~ ^[Yy] ]]; then
        if auto_discover_moodle_simple; then
            config_detected=true
            print_success "Configuración detectada automáticamente"
        fi
    fi
    
    # Variables para configuración
    local panel_user=""
    local www_dir=""
    local moodledata_dir=""
    local db_name=""
    local db_user=""
    local db_host="localhost"
    
    # Si se detectó configuración, usar como valores por defecto
    if [[ "$config_detected" == "true" ]]; then
        # Intentar detectar directorio web desde la configuración
        for dir in "${found_dirs[@]:-}"; do
            if [[ -n "$dir" ]]; then
                www_dir="$dir"
                break
            fi
        done
        
        moodledata_dir="$DETECTED_DATAROOT"
        db_name="$DETECTED_DB_NAME"
        db_user="$DETECTED_DB_USER"
        db_host="${DETECTED_DB_HOST:-localhost}"
        
        echo ""
        print_success "Usando valores detectados como predeterminados"
        echo "Puede modificarlos si es necesario:"
        echo ""
    fi
    
    echo -n "Usuario del panel (dejar vacío si no aplica): "
    read -r panel_user
    
    # Configuración del directorio web
    if [[ -n "$www_dir" ]]; then
        echo "Directorio web de Moodle [$www_dir]: "
        read -r input_www_dir
        www_dir="${input_www_dir:-$www_dir}"
    else
        echo -n "Directorio web de Moodle (ej: /home/user/public_html): "
        read -r www_dir
    fi
    
    # Si se ingresó un directorio web manualmente, intentar leer config.php
    if [[ -n "$www_dir" ]] && [[ ! "$config_detected" == "true" ]] && [[ -f "$www_dir/config.php" ]]; then
        print_step "Detectando configuración desde directorio especificado..."
        if parse_moodle_config "$www_dir/config.php" "$www_dir"; then
            config_detected=true
            moodledata_dir="$DETECTED_DATAROOT"
            db_name="$DETECTED_DB_NAME"
            db_user="$DETECTED_DB_USER"
            db_host="${DETECTED_DB_HOST:-localhost}"
            print_success "Configuración actualizada desde config.php"
        fi
    fi
    
    # Configuración del directorio de datos
    if [[ -n "$moodledata_dir" ]]; then
        echo "Directorio moodledata [$moodledata_dir]: "
        read -r input_moodledata_dir
        moodledata_dir="${input_moodledata_dir:-$moodledata_dir}"
    else
        echo -n "Directorio moodledata (ej: /home/user/moodledata): "
        read -r moodledata_dir
    fi
    
    # Configuración de base de datos
    if [[ -n "$db_name" ]]; then
        echo "Nombre de la base de datos [$db_name]: "
        read -r input_db_name
        db_name="${input_db_name:-$db_name}"
    else
        echo -n "Nombre de la base de datos: "
        read -r db_name
    fi
    
    if [[ -n "$db_user" ]]; then
        echo "Usuario de la base de datos [$db_user]: "
        read -r input_db_user
        db_user="${input_db_user:-$db_user}"
    else
        echo -n "Usuario de la base de datos: "
        read -r db_user
    fi
    
    # Información sobre configuración de contraseña de BD
    echo ""
    echo "🔐 CONFIGURACIÓN DE CONTRASEÑA DE BASE DE DATOS"
    echo "⚠️  IMPORTANTE: Configuración de seguridad para la contraseña"
    echo ""
    echo "Opciones disponibles para mayor seguridad:"
    echo "1. Variable de entorno MYSQL_PASSWORD (más seguro)"
    echo "2. Archivo protegido /etc/mysql/backup.pwd (recomendado)"
    echo "3. Escribir en configuración (menos seguro)"
    echo ""
    echo "Si eliges opción 1 o 2, puedes dejar esto vacío y configurarlo después."
    echo "Consulta la documentación para configuración avanzada."
    echo ""
    
    local db_pass_choice=""
    echo "¿Cómo prefieres configurar la contraseña?"
    echo "1. Escribir ahora (texto plano en archivo config - menos seguro)"
    echo "2. Crear archivo protegido automáticamente (recomendado)"
    echo "3. Variable de entorno (configurar manualmente después)"
    if [[ "$config_detected" == "true" ]] && [[ -n "$DETECTED_DB_PASS" ]]; then
        echo "4. Usar contraseña detectada desde config.php (recomendado)"
        echo "5. Configurar más tarde (solo instrucciones)"
        echo -n "Selecciona opción (1-5) [4]: "
        read -r db_pass_choice
        db_pass_choice="${db_pass_choice:-4}"
    else
        echo "4. Configurar más tarde (solo instrucciones)"
        echo -n "Selecciona opción (1-4) [2]: "
        read -r db_pass_choice
        db_pass_choice="${db_pass_choice:-2}"
    fi
    
    local db_pass=""
    case "$db_pass_choice" in
        "1")
            echo ""
            echo -n "Contraseña de la base de datos: "
            read -rs db_pass
            echo ""
            echo "⚠️  La contraseña se guardará en texto plano en moodle_backup.conf"
            ;;
        "2")
            echo ""
            echo "✅ Configuración de archivo protegido seleccionada"
            
            if [[ $EUID -eq 0 ]] || sudo -n true 2>/dev/null; then
                echo -n "Contraseña de la base de datos: "
                read -rs temp_password
                echo ""
                
                # Crear directorio si no existe
                [[ $EUID -eq 0 ]] && mkdir -p /etc/mysql || sudo mkdir -p /etc/mysql
                
                # Escribir contraseña al archivo protegido
                if [[ $EUID -eq 0 ]]; then
                    echo "$temp_password" > /etc/mysql/backup.pwd
                    chmod 600 /etc/mysql/backup.pwd
                    chown root:root /etc/mysql/backup.pwd
                else
                    echo "$temp_password" | sudo tee /etc/mysql/backup.pwd > /dev/null
                    sudo chmod 600 /etc/mysql/backup.pwd
                    sudo chown root:root /etc/mysql/backup.pwd
                fi
                
                print_success "✅ Archivo protegido creado: /etc/mysql/backup.pwd"
                print_info "Permisos: 600 (solo root puede leer)"
                
                # Verificar que se creó correctamente
                if [[ -f /etc/mysql/backup.pwd ]]; then
                    local file_perms=$(stat -c "%a" /etc/mysql/backup.pwd 2>/dev/null || stat -f "%Mp%Lp" /etc/mysql/backup.pwd 2>/dev/null || echo "")
                    if [[ "$file_perms" == "600" ]]; then
                        print_success "✅ Permisos configurados correctamente"
                    else
                        print_warning "⚠️  Verificar permisos del archivo manualmente"
                    fi
                else
                    print_error "❌ Error creando el archivo protegido"
                    print_info "Deberá configurarlo manualmente después"
                fi
                
                unset temp_password  # Limpiar variable de memoria
                db_pass=""  # Dejar vacío en config para usar archivo
            else
                print_error "❌ Se necesitan permisos de administrador para crear archivo protegido"
                print_info "📋 EJECUTA MANUALMENTE DESPUÉS DE LA INSTALACIÓN:"
                echo "   sudo mkdir -p /etc/mysql"
                echo "   sudo echo 'tu_password_aquí' > /etc/mysql/backup.pwd"
                echo "   sudo chmod 600 /etc/mysql/backup.pwd"
                echo "   sudo chown root:root /etc/mysql/backup.pwd"
                db_pass=""
            fi
            ;;
        "3")
            echo ""
            echo "✅ Configuración con variable de entorno seleccionada"
            echo ""
            echo "📋 CONFIGURACIÓN REQUERIDA:"
            echo "   export MYSQL_PASSWORD='tu_password_aquí'"
            echo ""
            echo "💡 Para hacerlo permanente, agrega la línea a ~/.bashrc:"
            echo "   echo \"export MYSQL_PASSWORD='tu_password'\" >> ~/.bashrc"
            echo ""
            
            echo -n "¿Deseas configurar la variable ahora para esta sesión? [y/N]: "
            read -r set_env_now
            if [[ "$set_env_now" =~ ^[Yy]$ ]]; then
                echo -n "Contraseña de la base de datos: "
                read -rs temp_password
                echo ""
                export MYSQL_PASSWORD="$temp_password"
                print_success "✅ Variable MYSQL_PASSWORD configurada para esta sesión"
                print_warning "⚠️  Recuerda agregar la variable a ~/.bashrc para que persista"
                unset temp_password
            fi
            db_pass=""
            ;;
        "4")
            # Opción 4: Usar contraseña detectada (solo si está disponible)
            if [[ "$config_detected" == "true" ]] && [[ -n "$DETECTED_DB_PASS" ]]; then
                db_pass="$DETECTED_DB_PASS"
                print_success "✅ Usando contraseña detectada desde config.php"
                echo ""
                echo "⚠️  IMPORTANTE: La contraseña se guardará en texto plano en moodle_backup.conf"
                echo "   Para mayor seguridad, considere cambiar a archivo protegido después:"
                echo "   sudo echo '$DETECTED_DB_PASS' > /etc/mysql/backup.pwd"
                echo "   sudo chmod 600 /etc/mysql/backup.pwd"
                echo "   sudo chown root:root /etc/mysql/backup.pwd"
                echo "   # Luego remover DB_PASS del archivo .conf"
                echo ""
            else
                # Fallback a configuración postpone
                echo ""
                echo "✅ Configuración postpone seleccionada"
                echo "📋 OPCIONES DISPONIBLES PARA CONFIGURAR DESPUÉS:"
                echo ""
                echo "   Opción A - Archivo protegido (RECOMENDADO):"
                echo "   sudo mkdir -p /etc/mysql"
                echo "   sudo echo 'tu_password_aquí' > /etc/mysql/backup.pwd"
                echo "   sudo chmod 600 /etc/mysql/backup.pwd"
                echo "   sudo chown root:root /etc/mysql/backup.pwd"
                echo ""
                echo "   Opción B - Variable de entorno:"
                echo "   export MYSQL_PASSWORD='tu_password_aquí'"
                echo "   # Agregar a ~/.bashrc para persistir"
                echo ""
                echo "   Opción C - En archivo de configuración:"
                echo "   Editar archivos .conf y agregar: DB_PASS=tu_password"
                echo "   (Menos seguro - solo para desarrollo)"
                echo ""
                db_pass=""
            fi
            ;;
        "5")
            # Opción 5: Configuración postpone (solo cuando hay contraseña detectada)
            echo ""
            echo "✅ Configuración postpone seleccionada"
            echo "📋 OPCIONES DISPONIBLES PARA CONFIGURAR DESPUÉS:"
            echo ""
            echo "   Opción A - Archivo protegido (RECOMENDADO):"
            echo "   sudo mkdir -p /etc/mysql"
            echo "   sudo echo 'tu_password_aquí' > /etc/mysql/backup.pwd"
            echo "   sudo chmod 600 /etc/mysql/backup.pwd"
            echo "   sudo chown root:root /etc/mysql/backup.pwd"
            echo ""
            echo "   Opción B - Variable de entorno:"
            echo "   export MYSQL_PASSWORD='tu_password_aquí'"
            echo "   # Agregar a ~/.bashrc para persistir"
            echo ""
            echo "   Opción C - En archivo de configuración:"
            echo "   Editar archivos .conf y agregar: DB_PASS=tu_password"
            echo "   (Menos seguro - solo para desarrollo)"
            echo ""
            db_pass=""
            ;;
        *)
            # Fallback: usar contraseña detectada si está disponible, sino postpone
            if [[ "$config_detected" == "true" ]] && [[ -n "$DETECTED_DB_PASS" ]]; then
                db_pass="$DETECTED_DB_PASS"
                print_success "✅ Usando contraseña detectada desde config.php (opción por defecto)"
            else
                print_error "Opción inválida, usando configuración postpone"
                db_pass=""
            fi
            ;;
    esac
    
    # Solicitar email de notificación (OBLIGATORIO)
    echo ""
    echo "🔔 CONFIGURACIÓN DE NOTIFICACIONES"
    echo "⚠️  IMPORTANTE: Se requiere al menos un email para notificaciones"
    echo ""
    
    local notification_email=""
    while [[ -z "$notification_email" ]]; do
        echo -n "Email para notificaciones (OBLIGATORIO): "
        read -r notification_email
        
        # Validar formato básico de email
        if [[ ! "$notification_email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
            print_error "Email inválido. Por favor ingresa un email válido."
            notification_email=""
        fi
    done
    
    print_success "Email configurado: $notification_email"
    
    # Crear archivo de configuración
    cat > "$config_file" << EOF
# Configuración Moodle Backup V3 - Cliente: $client_name
# Generado automáticamente por el instalador
# Fecha: $(date)

# ===================== INFORMACIÓN DEL CLIENTE =====================
CLIENT_NAME="$client_name"
CLIENT_DESCRIPTION="$client_description"

# ===================== CONFIGURACIÓN DE PANEL =====================
PANEL_TYPE="manual"
PANEL_USER="$panel_user"

# ===================== DIRECTORIOS PRINCIPALES =====================
WWW_DIR="$www_dir"
MOODLEDATA_DIR="$moodledata_dir"
TMP_DIR="/tmp/moodle_backup"

# ===================== CONFIGURACIÓN DE BASE DE DATOS =====================
DB_NAME="$db_name"
DB_USER="$db_user"
DB_PASS="$db_pass"
DB_HOST="$db_host"

# ===================== CONFIGURACIÓN DE GOOGLE DRIVE =====================
GDRIVE_REMOTE="gdrive:moodle_backups"
MAX_BACKUPS_GDRIVE=2

# ===================== CONFIGURACIÓN DE LOGGING =====================
LOG_FILE="/var/log/moodle_backup_${client_name}.log"

# ===================== CONFIGURACIÓN ADICIONAL =====================
REQUIRE_CONFIG="false"
AUTO_DETECT_AGGRESSIVE="false"
EXTENDED_DIAGNOSTICS="false"
NOTIFICATION_EMAILS_EXTRA="$notification_email"
EOF

    print_success "Configuración manual creada: $config_file"
}

# Función para configurar cron
configure_cron() {
    print_header "CONFIGURACIÓN DE CRON"
    
    echo "¿Cómo desea configurar la tarea programada de backup?"
    echo ""
    echo "1. 2:00 AM diariamente (recomendado)"
    echo "2. Horario personalizado"
    echo "3. No configurar ahora"
    echo ""
    echo -n "Seleccione una opción [1]: "
    read -r cron_option
    cron_option="${cron_option:-1}"
    
    case "$cron_option" in
        "1")
            local cron_time="0 2 * * *"
            local cron_description="2:00 AM diariamente"
            ;;
        "2")
            echo ""
            echo "Configuración personalizada de cron:"
            echo "Formato: minuto hora día mes día_semana"
            echo "Ejemplo: 0 3 * * * = 3:00 AM diariamente"
            echo "Ejemplo: 30 1 * * 0 = 1:30 AM solo domingos"
            echo ""
            echo -n "Ingrese el horario cron: "
            read -r cron_time
            cron_description="horario personalizado"
            ;;
        "3")
            print_info "Configuración de cron omitida"
            print_info "Puede configurar manualmente más tarde con: crontab -e"
            return 0
            ;;
        *)
            print_error "Opción inválida"
            return 1
            ;;
    esac
    
    # Determinar comando del cron según modo de instalación
    if [[ "$INSTALL_MODE" == "system" ]]; then
        local cron_command="$FINAL_INSTALL_DIR/moodle_backup.sh"
        local cron_user="root"
    else
        local cron_command="$FINAL_INSTALL_DIR/moodle_backup.sh"
        local cron_user="$USER"
    fi
    
    # Agregar entrada al cron
    local cron_entry="$cron_time $cron_command >/dev/null 2>&1"
    
    # Verificar si ya existe una entrada similar
    if crontab -l 2>/dev/null | grep -q "moodle_backup.sh"; then
        print_warning "Ya existe una tarea de moodle_backup en cron"
        echo -n "¿Desea reemplazarla? [y/N]: "
        read -r replace_cron
        
        if [[ "$replace_cron" =~ ^[Yy]$ ]]; then
            # Remover entradas existentes y agregar nueva
            (crontab -l 2>/dev/null | grep -v "moodle_backup.sh"; echo "$cron_entry") | crontab -
            print_success "Tarea de cron reemplazada: $cron_description"
        else
            print_info "Tarea de cron no modificada"
        fi
    else
        # Agregar nueva entrada
        (crontab -l 2>/dev/null; echo "$cron_entry") | crontab -
        print_success "Tarea de cron agregada: $cron_description"
    fi
    
    # Mostrar crontab actual
    echo ""
    print_info "Tareas de cron actuales:"
    crontab -l 2>/dev/null | grep -E "(moodle|backup)" || echo "  (ninguna relacionada con backup)"
}

# Función para verificar la instalación
verify_installation() {
    print_header "VERIFICACIÓN DE INSTALACIÓN"
    
    local verification_errors=()
    
    # Verificar archivos instalados
    [[ ! -f "$FINAL_INSTALL_DIR/moodle_backup.sh" ]] && verification_errors+=("Script principal no encontrado")
    [[ ! -f "$FINAL_INSTALL_DIR/mb" ]] && verification_errors+=("Wrapper 'mb' no encontrado")
    [[ ! -f "$FINAL_CONFIG_DIR/moodle_backup.conf.example" ]] && verification_errors+=("Archivo de configuración ejemplo no encontrado")
    
    # Verificar permisos de ejecución
    [[ ! -x "$FINAL_INSTALL_DIR/moodle_backup.sh" ]] && verification_errors+=("Script principal no ejecutable")
    [[ ! -x "$FINAL_INSTALL_DIR/mb" ]] && verification_errors+=("Wrapper 'mb' no ejecutable")
    
    # Verificar comandos en PATH
    if ! command -v mb >/dev/null 2>&1; then
        verification_errors+=("Comando 'mb' no disponible en PATH")
    fi
    
    # Verificar dependencias críticas
    local critical_deps=("mysql" "tar" "gzip" "rclone")
    for dep in "${critical_deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            verification_errors+=("Dependencia crítica no encontrada: $dep")
        fi
    done
    
    # Mostrar resultados
    if [[ ${#verification_errors[@]} -eq 0 ]]; then
        print_success "✅ Verificación de instalación exitosa"
        
        # Test básico del script
        print_step "Ejecutando test básico..."
        if "$FINAL_INSTALL_DIR/moodle_backup.sh" --version >/dev/null 2>&1; then
            print_success "✅ Script principal funcional"
        else
            print_warning "⚠️ Posible problema con el script principal"
        fi
        
        # Test del wrapper
        if "$FINAL_INSTALL_DIR/mb" --version >/dev/null 2>&1; then
            print_success "✅ Wrapper 'mb' funcional"
        else
            print_warning "⚠️ Posible problema con el wrapper 'mb'"
        fi
        
    else
        print_error "❌ Errores en la verificación:"
        for error in "${verification_errors[@]}"; do
            echo -e "  ${RED}• $error${NC}"
        done
        return 1
    fi
}

# Función para configurar clientes adicionales
configure_additional_clients() {
    print_header "CONFIGURACIÓN MULTI-CLIENTE"
    
    echo "¿Desea configurar backups para clientes/instalaciones adicionales?"
    echo ""
    echo -n "¿Agregar más configuraciones? [y/N]: "
    read -r add_more
    
    if [[ "$add_more" =~ ^[Yy]$ ]]; then
        local client_count=2
        
        while true; do
            echo ""
            print_step "Configurando cliente #$client_count"
            
            echo -n "Nombre del cliente: "
            read -r client_name
            
            if [[ -z "$client_name" ]]; then
                print_warning "Nombre de cliente vacío, cancelando configuración adicional"
                break
            fi
            
            local client_config="$FINAL_CONFIG_DIR/moodle_backup_${client_name}.conf"
            
            if [[ -f "$client_config" ]]; then
                print_warning "Ya existe configuración para el cliente: $client_name"
                echo -n "¿Sobrescribir? [y/N]: "
                read -r overwrite
                if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
                    continue
                fi
            fi
            
            echo -n "Descripción del cliente [Moodle Backup - $client_name]: "
            read -r client_description
            client_description="${client_description:-Moodle Backup - $client_name}"
            
            # Configuración rápida o manual
            echo ""
            echo "1. Auto-detección (recomendado)"
            echo "2. Configuración manual"
            echo -n "Seleccione método [1]: "
            read -r config_method
            config_method="${config_method:-1}"
            
            case "$config_method" in
                "1")
                    # Copiar ejemplo y personalizar para auto-detección
                    cp "$FINAL_CONFIG_DIR/moodle_backup.conf.example" "$client_config"
                    sed -i "s/CLIENT_NAME=.*/CLIENT_NAME=\"$client_name\"/" "$client_config"
                    sed -i "s/CLIENT_DESCRIPTION=.*/CLIENT_DESCRIPTION=\"$client_description\"/" "$client_config"
                    sed -i "s/PANEL_TYPE=.*/PANEL_TYPE=\"auto\"/" "$client_config"
                    sed -i "s/AUTO_DETECT_AGRESSIVE=.*/AUTO_DETECT_AGRESSIVE=\"true\"/" "$client_config"
                    sed -i "s/LOG_FILE=.*/LOG_FILE=\"\/var\/log\/moodle_backup_${client_name}.log\"/" "$client_config"
                    
                    print_success "Configuración de auto-detección creada: $client_config"
                    ;;
                "2")
                    manual_configuration_wizard "$client_config" "$client_name" "$client_description"
                    ;;
            esac
            
            print_success "Cliente '$client_name' configurado"
            print_info "Usar con: mb --config $client_config"
            
            client_count=$((client_count + 1))
            
            echo ""
            echo -n "¿Configurar otro cliente? [y/N]: "
            read -r continue_adding
            if [[ ! "$continue_adding" =~ ^[Yy]$ ]]; then
                break
            fi
        done
    fi
}

# Función para mostrar resumen final
show_final_summary() {
    print_header "🎉 INSTALACIÓN COMPLETADA"
    
    echo -e "${GREEN}Moodle Backup V3 se ha instalado correctamente!${NC}"
    echo ""
    
    echo -e "${CYAN}📁 Archivos instalados:${NC}"
    echo "  • Script principal: $FINAL_INSTALL_DIR/moodle_backup.sh"
    echo "  • Wrapper 'mb': $FINAL_INSTALL_DIR/mb"
    echo "  • Configuración ejemplo: $FINAL_CONFIG_DIR/moodle_backup.conf.example"
    echo ""
    
    echo -e "${CYAN}🔧 Configuraciones creadas:${NC}"
    for config in "$FINAL_CONFIG_DIR"/moodle_backup*.conf; do
        if [[ -f "$config" ]]; then
            local client=$(basename "$config" .conf | sed 's/moodle_backup_//' | sed 's/moodle_backup/default/')
            echo "  • Cliente '$client': $config"
        fi
    done
    echo ""
    
    echo -e "${CYAN}⚡ Comandos disponibles:${NC}"
    echo "  • mb                    # Ejecutar backup con configuración por defecto"
    echo "  • mb --config archivo   # Ejecutar con configuración específica"
    echo "  • mb --test             # Probar configuración"
    echo "  • mb --help             # Mostrar ayuda"
    echo "  • mb --version          # Mostrar versión"
    echo ""
    
    echo -e "${CYAN}📋 Próximos pasos recomendados:${NC}"
    echo "  1. Verificar configuración: mb --test"
    echo "  2. Ejecutar primer backup: mb"
    echo "  3. Revisar logs en: /var/log/moodle_backup*.log"
    echo "  4. Verificar tareas de cron: crontab -l"
    echo ""
    
    # Verificar estado de configuración de contraseñas y mostrar información relevante
    local need_password_config=false
    local has_protected_file=false
    local has_env_var=false
    local configs_with_plain_pass=()
    
    # Verificar archivo protegido
    if [[ -f /etc/mysql/backup.pwd ]]; then
        has_protected_file=true
    fi
    
    # Verificar variable de entorno
    if [[ -n "${MYSQL_PASSWORD:-}" ]]; then
        has_env_var=true
    fi
    
    # Verificar configuraciones
    for config in "$FINAL_CONFIG_DIR"/moodle_backup*.conf; do
        if [[ -f "$config" ]]; then
            if grep -q "^DB_PASS=.\+$" "$config" 2>/dev/null; then
                configs_with_plain_pass+=("$(basename "$config")")
            elif ! grep -q "^DB_PASS=" "$config" 2>/dev/null; then
                need_password_config=true
            fi
        fi
    done
    
    # Mostrar estado de configuración de contraseñas
    echo -e "${CYAN}🔐 ESTADO DE CONFIGURACIÓN DE CONTRASEÑAS:${NC}"
    echo ""
    
    if [[ "$has_protected_file" == "true" ]]; then
        echo -e "${GREEN}✅ Archivo protegido configurado: /etc/mysql/backup.pwd${NC}"
        local file_perms=$(stat -c "%a" /etc/mysql/backup.pwd 2>/dev/null || echo "???")
        echo -e "   Permisos: $file_perms $([ "$file_perms" = "600" ] && echo "✅" || echo "⚠️")"
    fi
    
    if [[ "$has_env_var" == "true" ]]; then
        echo -e "${GREEN}✅ Variable de entorno MYSQL_PASSWORD configurada${NC}"
        echo -e "   (Solo para esta sesión - agregar a ~/.bashrc para persistir)"
    fi
    
    if [[ ${#configs_with_plain_pass[@]} -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  Configuraciones con contraseña en texto plano:${NC}"
        for config in "${configs_with_plain_pass[@]}"; do
            echo -e "   • $config"
        done
        echo -e "${YELLOW}   Considera migrar a método más seguro${NC}"
    fi
    
    if [[ "$need_password_config" == "true" ]]; then
        echo -e "${YELLOW}🔐 RECORDATORIO IMPORTANTE - CONFIGURACIÓN DE CONTRASEÑA BD:${NC}"
        echo ""
        echo -e "${RED}⚠️  Algunas configuraciones requieren contraseña de base de datos${NC}"
        echo ""
        echo -e "${CYAN}Opciones de configuración segura:${NC}"
        echo ""
        echo -e "${GREEN}Opción 1 - Archivo protegido (RECOMENDADO):${NC}"
        echo "  sudo echo 'tu_password_aquí' > /etc/mysql/backup.pwd"
        echo "  sudo chmod 600 /etc/mysql/backup.pwd"
        echo "  sudo chown root:root /etc/mysql/backup.pwd"
        echo ""
        echo -e "${GREEN}Opción 2 - Variable de entorno:${NC}"
        echo "  export MYSQL_PASSWORD='tu_password_aquí'"
        echo "  # Agregar a ~/.bashrc para persistir"
        echo ""
        echo -e "${GREEN}Opción 3 - En archivo de configuración:${NC}"
        echo "  Editar archivos .conf y agregar: DB_PASS=tu_password"
        echo "  (Menos seguro - solo para desarrollo)"
        echo ""
        echo -e "${CYAN}💡 Verificar después con: mb --test${NC}"
        echo ""
    fi
    
    if [[ "$INSTALL_MODE" == "user" ]]; then
        echo -e "${YELLOW}⚠️  Instalación de usuario:${NC}"
        echo "  • Reinicie su terminal o ejecute: source ~/.bashrc"
        echo "  • Los archivos están en: $FINAL_INSTALL_DIR"
        echo ""
    fi
    
    echo -e "${CYAN}🆘 Soporte:${NC}"
    echo "  • Documentación: https://github.com/gzlo/moodle-backup"
    echo "  • Issues: https://github.com/gzlo/moodle-backup/issues"
    echo "  • GitHub: https://github.com/gzlo/moodle-backup"
    echo ""
    
    print_success "¡Instalación completada exitosamente!"
}

# Función principal de instalación
main() {
    print_banner
    print_header "🚀 INSTALADOR MOODLE BACKUP V3"
    print_info "Instalador universal para sistemas Linux"
    print_info "Soporta: CentOS/RHEL/Fedora/Rocky/Alma y Ubuntu/Debian"
    
    # Crear directorio temporal
    mkdir -p "$TEMP_DIR"
    trap "rm -rf '$TEMP_DIR'" EXIT
    
    # Pasos de instalación
    detect_os
    check_installation_permissions
    install_dependencies
    download_files
    install_files
    configure_rclone
    configure_first_client
    configure_cron
    configure_additional_clients
    verify_installation
    show_final_summary
    
    print_success "🎯 Instalación completada exitosamente!"
    print_info "Puede comenzar a usar el sistema con: mb --test"
}

# Ejecutar instalador
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

echo ""
log_success "🎉 INSTALACIÓN COMPLETADA EXITOSAMENTE"
echo ""
echo -e "${BLUE}PRÓXIMOS PASOS:${NC}"
echo "1. Recargar configuración de shell:"
if [[ "$GLOBAL_INSTALL" == true ]]; then
    echo "   source /etc/bash.bashrc  (o reiniciar sesión)"
else
    echo "   source ~/.bashrc  (o reiniciar sesión)"
fi
echo ""
echo "2. Editar configuración según necesidades:"
echo "   nano $CONFIG_PATH"
echo ""
echo "3. Verificar configuración:"
echo "   $SCRIPT_NAME --show-config"
echo "   (o después de recargar: mb-config)"
echo ""
echo "4. Configurar Google Drive (si no está configurado):"
echo "   rclone config"
echo ""
echo "5. Ejecutar primer backup de prueba:"
echo "   $SCRIPT_NAME"
echo "   (o después de recargar: mb)"
echo ""
echo -e "${GREEN}COMANDOS DISPONIBLES (después de recargar shell):${NC}"
echo "  mb           - Ejecutar backup"
echo "  mb-config    - Ver configuración cargada"  
echo "  mb-test      - Probar conexión Google Drive"
echo "  mb-help      - Ver ayuda completa"
echo "  mb-diag      - Ejecutar diagnóstico del sistema"
echo ""
echo -e "${YELLOW}CONFIGURACIÓN DETECTADA:${NC}"
echo "  Panel: $DETECTED_PANEL"
echo "  Instalación: $(if [[ "$GLOBAL_INSTALL" == true ]]; then echo "Global (sistema)"; else echo "Local (usuario)"; fi)"
echo "  Script: $INSTALL_DIR/$SCRIPT_NAME"
echo "  Config: $CONFIG_PATH"
echo ""
echo -e "${BLUE}Para más información, consultar INSTALACION_Y_USO.md${NC}"
