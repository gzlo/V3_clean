#!/bin/bash

# ===================== INSTALADOR WEB MOODLE BACKUP V3 =====================
# Instalador web automático para Moodle Backup V3 - Script Universal Multi-Panel
# Autor: Sistema Moodle Backup - Versión: 3.0
# Fecha: 2025-06-29
#
# USO DIRECTO DESDE GITHUB:
#   curl -fsSL https://raw.githubusercontent.com/gzlo/moodle-backup/main/web-install.sh | bash
#   wget -qO- https://raw.githubusercontent.com/gzlo/moodle-backup/main/web-install.sh | bash
#
# USO CON PARÁMETROS:
#   curl -fsSL https://raw.githubusercontent.com/gzlo/moodle-backup/main/web-install.sh | bash -s -- --auto
#   curl -fsSL https://raw.githubusercontent.com/gzlo/moodle-backup/main/web-install.sh | bash -s -- --interactive
#
# CARACTERÍSTICAS:
# - Instalación completamente automática desde GitHub
# - Detección de sistema operativo y panel de control
# - Instalación de dependencias automática
# - Configuración de rclone para Google Drive
# - Configuración de cron asistida
# - Soporte multi-cliente
# - Verificación post-instalación
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
REPO_BASE_URL="https://raw.githubusercontent.com/gzlo/moodle-backup/main"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc"
USER_INSTALL_DIR="$HOME/bin"
USER_CONFIG_DIR="$HOME/.config/moodle-backup"
TEMP_DIR="/tmp/moodle-backup-install-$$"

# Variables de control
INTERACTIVE_MODE=true
AUTO_MODE=false
SKIP_DEPENDENCIES=false
SKIP_RCLONE_CONFIG=false
SKIP_CRON_CONFIG=false

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
                                                      
            INSTALADOR WEB UNIVERSAL V3
EOF
    echo -e "${NC}"
}

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
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

# Función para procesar argumentos de línea de comandos
process_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --auto)
                AUTO_MODE=true
                INTERACTIVE_MODE=false
                print_info "Modo automático activado"
                ;;
            --interactive)
                INTERACTIVE_MODE=true
                AUTO_MODE=false
                print_info "Modo interactivo activado"
                ;;
            --skip-deps)
                SKIP_DEPENDENCIES=true
                print_info "Omitiendo instalación de dependencias"
                ;;
            --skip-rclone)
                SKIP_RCLONE_CONFIG=true
                print_info "Omitiendo configuración de rclone"
                ;;
            --skip-cron)
                SKIP_CRON_CONFIG=true
                print_info "Omitiendo configuración de cron"
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                print_warning "Parámetro desconocido: $1"
                ;;
        esac
        shift
    done
}

# Función para mostrar uso
show_usage() {
    echo "Uso: $0 [OPCIONES]"
    echo ""
    echo "OPCIONES:"
    echo "  --auto          Instalación automática sin preguntas"
    echo "  --interactive   Instalación interactiva (por defecto)"
    echo "  --skip-deps     Omitir instalación de dependencias"
    echo "  --skip-rclone   Omitir configuración de rclone"
    echo "  --skip-cron     Omitir configuración de cron"
    echo "  --help, -h      Mostrar esta ayuda"
    echo ""
    echo "EJEMPLOS:"
    echo "  curl -fsSL https://raw.githubusercontent.com/gzlo/moodle-backup/main/web-install.sh | bash"
    echo "  curl -fsSL https://raw.githubusercontent.com/gzlo/moodle-backup/main/web-install.sh | bash -s -- --auto"
}

# Función para detectar el sistema operativo
detect_os() {
    print_step "Detectando sistema operativo..."
    
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

# Función para detectar panel de control
detect_control_panel() {
    print_step "Detectando panel de control..."
    
    DETECTED_PANEL="manual"
    
    if [[ -d "/usr/local/cpanel" ]] || command -v whmapi1 >/dev/null 2>&1; then
        DETECTED_PANEL="cpanel"
        print_success "cPanel detectado"
    elif [[ -d "/opt/psa" ]] || command -v plesk >/dev/null 2>&1; then
        DETECTED_PANEL="plesk"
        print_success "Plesk detectado"
    elif [[ -d "/usr/local/directadmin" ]]; then
        DETECTED_PANEL="directadmin"
        print_success "DirectAdmin detectado"
    elif [[ -d "/usr/local/vesta" ]] || [[ -d "/usr/local/hestia" ]]; then
        DETECTED_PANEL="vestacp"
        print_success "VestaCP/HestiaCP detectado"
    elif [[ -d "/usr/local/ispconfig" ]]; then
        DETECTED_PANEL="ispconfig"
        print_success "ISPConfig detectado"
    else
        print_info "Panel manual detectado (sin panel específico)"
    fi
}

# Función para verificar permisos de instalación
check_installation_permissions() {
    print_step "Verificando permisos de instalación..."
    
    if [[ $EUID -eq 0 ]]; then
        INSTALL_MODE="system"
        FINAL_INSTALL_DIR="$INSTALL_DIR"
        FINAL_CONFIG_DIR="$CONFIG_DIR"
        print_success "Instalación del sistema (como root)"
    else
        if [[ -w "$INSTALL_DIR" ]] && [[ -w "$CONFIG_DIR" ]]; then
            INSTALL_MODE="system"
            FINAL_INSTALL_DIR="$INSTALL_DIR"
            FINAL_CONFIG_DIR="$CONFIG_DIR"
            print_success "Instalación del sistema (con permisos de escritura)"
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
    if [[ "$SKIP_DEPENDENCIES" == true ]]; then
        print_info "Omitiendo instalación de dependencias (--skip-deps)"
        return 0
    fi
    
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
                "unzip"           # Para descomprimir archivos
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
                "unzip"           # Para descomprimir archivos
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
            
            if [[ "$AUTO_MODE" == false ]]; then
                echo -n "¿Continuar sin instalar dependencias? [y/N]: "
                read -r continue_without_deps
                if [[ ! "$continue_without_deps" =~ ^[Yy]$ ]]; then
                    print_error "Instalación cancelada por el usuario"
                    exit 1
                fi
            else
                print_warning "Modo automático: continuando sin dependencias"
            fi
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
        if curl -fsSL "$REPO_BASE_URL/$file" -o "$file"; then
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
    if [[ "$SKIP_RCLONE_CONFIG" == true ]]; then
        print_info "Omitiendo configuración de rclone (--skip-rclone)"
        return 0
    fi
    
    print_header "CONFIGURACIÓN DE RCLONE"
    
    if rclone listremotes | grep -q "gdrive:"; then
        print_success "rclone ya tiene configuración de Google Drive (gdrive:)"
        
        if [[ "$AUTO_MODE" == false ]]; then
            echo -n "¿Desea reconfigurar Google Drive? [y/N]: "
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                configure_rclone_gdrive
            fi
        else
            print_info "Modo automático: manteniendo configuración existente"
        fi
    else
        print_info "No se encontró configuración de Google Drive en rclone"
        
        if [[ "$AUTO_MODE" == false ]]; then
            echo -n "¿Desea configurar Google Drive ahora? [Y/n]: "
            read -r response
            if [[ "$response" =~ ^[Nn]$ ]]; then
                print_warning "Google Drive no configurado. Deberá configurarlo manualmente más tarde"
                print_info "Ejecute: rclone config"
            else
                configure_rclone_gdrive
            fi
        else
            print_warning "Modo automático: Google Drive no configurado"
            print_info "Configure manualmente con: rclone config"
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
    
    if [[ "$AUTO_MODE" == false ]]; then
        echo "Vamos a configurar su primera instalación de Moodle para backup."
        echo ""
        
        # Información del cliente
        echo -n "Nombre del cliente [default]: "
        read -r client_name
        client_name="${client_name:-default}"
        
        echo -n "Descripción del cliente [Moodle Backup]: "
        read -r client_description
        client_description="${client_description:-Moodle Backup}"
    else
        # Modo automático: usar valores por defecto
        client_name="default"
        client_description="Moodle Backup - $(hostname)"
        print_info "Modo automático: usando configuración por defecto"
    fi
    
    # Copiar configuración ejemplo y personalizar
    cp "$FINAL_CONFIG_DIR/moodle_backup.conf.example" "$config_file"
    
    # Personalizar configuración básica
    sed -i "s/CLIENT_NAME=.*/CLIENT_NAME=\"$client_name\"/" "$config_file"
    sed -i "s/CLIENT_DESCRIPTION=.*/CLIENT_DESCRIPTION=\"$client_description\"/" "$config_file"
    sed -i "s/PANEL_TYPE=.*/PANEL_TYPE=\"$DETECTED_PANEL\"/" "$config_file"
    sed -i "s/AUTO_DETECT_AGGRESSIVE=.*/AUTO_DETECT_AGGRESSIVE=\"true\"/" "$config_file"
    
    print_success "Configuración inicial creada: $config_file"
}

# Función para configurar cron
configure_cron() {
    if [[ "$SKIP_CRON_CONFIG" == true ]]; then
        print_info "Omitiendo configuración de cron (--skip-cron)"
        return 0
    fi
    
    print_header "CONFIGURACIÓN DE CRON"
    
    local cron_time="0 2 * * *"
    local cron_description="2:00 AM diariamente"
    
    if [[ "$AUTO_MODE" == false ]]; then
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
                cron_time="0 2 * * *"
                cron_description="2:00 AM diariamente"
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
    else
        print_info "Modo automático: configurando cron para las 2:00 AM diariamente"
    fi
    
    # Determinar comando del cron
    local cron_command="$FINAL_INSTALL_DIR/moodle_backup.sh"
    
    # Agregar entrada al cron
    local cron_entry="$cron_time $cron_command >/dev/null 2>&1"
    
    # Verificar si ya existe una entrada similar
    if crontab -l 2>/dev/null | grep -q "moodle_backup.sh"; then
        print_warning "Ya existe una tarea de moodle_backup en cron"
        
        if [[ "$AUTO_MODE" == false ]]; then
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
            print_info "Modo automático: manteniendo configuración existente"
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

# Función para mostrar resumen final
show_final_summary() {
    print_header "🎉 INSTALACIÓN COMPLETADA"
    
    echo -e "${GREEN}Moodle Backup V3 se ha instalado correctamente!${NC}"
    echo ""
    
    echo -e "${CYAN}📁 Archivos instalados:${NC}"
    echo "  • Script principal: $FINAL_INSTALL_DIR/moodle_backup.sh"
    echo "  • Wrapper 'mb': $FINAL_INSTALL_DIR/mb"
    echo "  • Configuración ejemplo: $FINAL_CONFIG_DIR/moodle_backup.conf.example"
    echo "  • Configuración activa: $FINAL_CONFIG_DIR/moodle_backup.conf"
    echo ""
    
    echo -e "${CYAN}⚡ Comandos disponibles:${NC}"
    echo "  • mb                    # Ejecutar backup con configuración por defecto"
    echo "  • mb --test             # Probar configuración"
    echo "  • mb --help             # Mostrar ayuda"
    echo "  • mb --version          # Mostrar versión"
    echo "  • mb --show-config      # Mostrar configuración actual"
    echo ""
    
    echo -e "${CYAN}📋 Próximos pasos recomendados:${NC}"
    echo "  1. Verificar configuración: mb --test"
    echo "  2. Ejecutar primer backup: mb"
    echo "  3. Revisar logs en: /var/log/moodle_backup*.log"
    echo "  4. Verificar tareas de cron: crontab -l"
    echo ""
    
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
    # Mostrar banner
    print_banner
    
    print_info "Instalador web universal para sistemas Linux"
    print_info "Soporta: CentOS/RHEL/Fedora/Rocky/Alma y Ubuntu/Debian"
    
    # Procesar argumentos
    process_arguments "$@"
    
    # Crear directorio temporal
    mkdir -p "$TEMP_DIR"
    trap "rm -rf '$TEMP_DIR'" EXIT
    
    # Pasos de instalación
    detect_os
    detect_control_panel
    check_installation_permissions
    install_dependencies
    download_files
    install_files
    configure_rclone
    configure_first_client
    configure_cron
    verify_installation
    show_final_summary
    
    print_success "🎯 Instalación completada exitosamente!"
    
    if [[ "$INSTALL_MODE" == "user" ]]; then
        print_warning "IMPORTANTE: Reinicie su terminal o ejecute 'source ~/.bashrc' para usar los comandos"
    fi
    
    print_info "Puede comenzar a usar el sistema con: mb --test"
}

# Ejecutar instalador
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
