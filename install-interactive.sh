#!/bin/bash
# ===================== INSTALADOR INTERACTIVO MOODLE BACKUP V3 =====================
# Instalador automático desde GitHub con configuración asistida paso a paso
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
CONFIG_DIR="/etc/moodle-backup/configs"
SCRIPT_NAME="moodle-backup"
DETECTED_PANEL=""
GLOBAL_INSTALL=false
SETUP_CRON=true
SETUP_RCLONE=true
MULTI_CLIENT=false

# Variables del sistema detectado
DETECTED_CPU_CORES=""
DETECTED_RAM=""
DETECTED_DISK_SPACE=""
RECOMMENDED_COMPRESSION=""
RECOMMENDED_THREADS=""

# Funciones de logging con estilo
print_header() {
    echo -e "${BLUE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                    MOODLE BACKUP V3 - INSTALADOR INTERACTIVO               ║"
    echo "║                          Sistema Universal Multi-Panel                      ║"
    echo "║                                by GZLOnline                                 ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
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
                                                      
          INSTALADOR INTERACTIVO V3
                by GZLOnline
EOF
    echo -e "${NC}"
}

log_info() { echo -e "${BLUE}ℹ️  $*${NC}"; }
log_success() { echo -e "${GREEN}✅ $*${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $*${NC}"; }
log_error() { echo -e "${RED}❌ $*${NC}"; }
log_step() { echo -e "${PURPLE}🔧 $*${NC}"; }
log_question() { echo -e "${CYAN}$*${NC}"; }

# Función para pausar y continuar
wait_continue() {
    echo -e "${CYAN}Presiona Enter para continuar...${NC}"
    read -r
}

# Función para detectar capacidades del servidor
detect_server_capabilities() {
    log_step "Detectando capacidades del servidor..."
    
    # Detectar CPU
    DETECTED_CPU_CORES=$(nproc 2>/dev/null || echo "2")
    
    # Detectar RAM (en GB)
    DETECTED_RAM=$(free -g | awk '/^Mem:/{print $2}' 2>/dev/null || echo "2")
    
    # Detectar espacio en disco (en GB)
    DETECTED_DISK_SPACE=$(df -BG / | awk 'NR==2{gsub(/G/, "", $4); print $4}' 2>/dev/null || echo "10")
    
    # Recomendar configuración basada en recursos
    if [[ $DETECTED_CPU_CORES -ge 8 ]] && [[ $DETECTED_RAM -ge 8 ]]; then
        RECOMMENDED_COMPRESSION=6
        RECOMMENDED_THREADS=4
        SERVER_TYPE="Alto rendimiento"
    elif [[ $DETECTED_CPU_CORES -ge 4 ]] && [[ $DETECTED_RAM -ge 4 ]]; then
        RECOMMENDED_COMPRESSION=3
        RECOMMENDED_THREADS=2
        SERVER_TYPE="Rendimiento medio"
    else
        RECOMMENDED_COMPRESSION=1
        RECOMMENDED_THREADS=1
        SERVER_TYPE="Recursos limitados"
    fi
    
    echo ""
    log_info "🖥️  Capacidades del servidor detectadas:"
    echo -e "   • CPUs: ${GREEN}$DETECTED_CPU_CORES${NC} núcleos"
    echo -e "   • RAM: ${GREEN}${DETECTED_RAM}GB${NC}"
    echo -e "   • Espacio libre: ${GREEN}${DETECTED_DISK_SPACE}GB${NC}"
    echo -e "   • Tipo de servidor: ${YELLOW}$SERVER_TYPE${NC}"
    echo ""
    log_success "Recomendaciones optimizadas:"
    echo -e "   • Nivel de compresión: ${GREEN}$RECOMMENDED_COMPRESSION${NC} (1=rápido, 22=máxima compresión)"
    echo -e "   • Threads concurrentes: ${GREEN}$RECOMMENDED_THREADS${NC}"
    echo ""
}

# Función para preguntar con valor por defecto
ask_with_default() {
    local prompt="$1"
    local default="$2"
    local variable_name="$3"
    local description="$4"
    local required="${5:-true}"  # Nuevo parámetro para indicar si es obligatorio
    
    echo ""
    echo -e "${BLUE}$description${NC}"
    echo -e "${CYAN}$prompt${NC}"
    
    if [[ -n "$default" ]]; then
        echo -e "${YELLOW}Valor por defecto: $default${NC}"
        read -r -p "Ingrese valor (Enter para usar por defecto): " value
        if [[ -z "$value" ]]; then
            value="$default"
        fi
    else
        read -r -p "Ingrese valor: " value
        if [[ "$required" == "true" ]]; then
            while [[ -z "$value" ]]; do
                log_warning "Este campo es obligatorio"
                read -r -p "Ingrese valor: " value
            done
        fi
    fi
    
    # Método robusto para asignar variables - usar tanto declare como eval
    declare -g "$variable_name"="$value" 2>/dev/null || true
    eval "$variable_name=\"$value\""
    
    # Verificar que la asignación funcionó
    if eval "test \"\${${variable_name}:-}\" = \"$value\""; then
        log_success "✓ $variable_name = $value"
    else
        log_error "❌ Error al asignar $variable_name"
        return 1
    fi
}

# Función para preguntar sí/no con valor por defecto
ask_yes_no() {
    local prompt="$1"
    local default="$2"
    local variable_name="$3"
    
    local options
    if [[ "$default" == "true" ]] || [[ "$default" == "y" ]]; then
        options="[Y/n]"
        default_char="y"
    else
        options="[y/N]"
        default_char="n"
    fi
    
    echo ""
    read -r -p "$prompt $options: " answer
    
    if [[ -z "$answer" ]]; then
        answer="$default_char"
    fi
    
    local result_value
    case ${answer,,} in
        y|yes|true)
            result_value="true"
            ;;
        *)
            result_value="false"
            ;;
    esac
    
    # Método robusto para asignar variables
    declare -g "$variable_name"="$result_value" 2>/dev/null || true
    eval "$variable_name=\"$result_value\""
    
    # Verificar que la asignación funcionó
    if eval "test \"\${${variable_name}:-}\" = \"$result_value\""; then
        log_success "✓ $variable_name = $result_value"
    else
        log_error "❌ Error al asignar $variable_name"
        return 1
    fi
}

# Función para validar email
validate_email() {
    local email="$1"
    if [[ $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Función para detectar automáticamente el tipo de panel
detect_control_panel() {
    # Detectar silenciosamente - sin mostrar logs
    
    # Verificar cPanel
    if [[ -d "/usr/local/cpanel" ]] || [[ -f "/usr/local/cpanel/cpanel" ]]; then
        echo "cpanel"
        return 0
    fi
    
    # Verificar Plesk
    if [[ -d "/opt/psa" ]] || [[ -f "/usr/local/psa/version" ]]; then
        echo "plesk"
        return 0
    fi
    
    # Verificar DirectAdmin
    if [[ -d "/usr/local/directadmin" ]] || [[ -f "/usr/local/directadmin/directadmin" ]]; then
        echo "directadmin"
        return 0
    fi
    
    # Verificar VestaCP
    if [[ -d "/usr/local/vesta" ]] || [[ -f "/usr/local/vesta/bin/v-list-users" ]]; then
        echo "vestacp"
        return 0
    fi
    
    # Verificar ISPConfig
    if [[ -d "/usr/local/ispconfig" ]] || [[ -f "/usr/local/ispconfig/server/server.sh" ]]; then
        echo "ispconfig"
        return 0
    fi
    
    # No se detectó ningún panel conocido
    echo "manual"
    return 1
}

# Función para obtener ejemplos de rutas según el panel
get_path_examples() {
    local panel_type="$1"
    
    case "$panel_type" in
        "cpanel")
            echo "/home/usuario/public_html"
            ;;
        "plesk")
            echo "/var/www/vhosts/dominio.com/httpdocs"
            ;;
        "directadmin")
            echo "/home/usuario/domains/dominio.com/public_html"
            ;;
        "vestacp")
            echo "/home/usuario/web/dominio.com/public_html"
            ;;
        "ispconfig")
            echo "/var/www/clients/client1/web1/web"
            ;;
        *)
            echo "/var/www/html o /home/usuario/public_html"
            ;;
    esac
}

# Función para leer config.php de Moodle y extraer configuración de BD
read_moodle_config() {
    local www_dir="$1"
    local config_file="$www_dir/config.php"
    
    if [[ ! -f "$config_file" ]]; then
        log_warning "No se encontró config.php en $www_dir"
        return 1
    fi
    
    log_step "Leyendo configuración de Moodle desde $config_file..."
    
    # Extraer configuraciones usando grep y sed
    local db_type=$(grep -E '^\$CFG->dbtype' "$config_file" | sed "s/.*['\"]\\([^'\"]*\\)['\"].*/\\1/" | head -1)
    local db_host=$(grep -E '^\$CFG->dbhost' "$config_file" | sed "s/.*['\"]\\([^'\"]*\\)['\"].*/\\1/" | head -1)
    local db_name=$(grep -E '^\$CFG->dbname' "$config_file" | sed "s/.*['\"]\\([^'\"]*\\)['\"].*/\\1/" | head -1)
    local db_user=$(grep -E '^\$CFG->dbuser' "$config_file" | sed "s/.*['\"]\\([^'\"]*\\)['\"].*/\\1/" | head -1)
    local db_pass=$(grep -E '^\$CFG->dbpass' "$config_file" | sed "s/.*['\"]\\([^'\"]*\\)['\"].*/\\1/" | head -1)
    local moodledata=$(grep -E '^\$CFG->dataroot' "$config_file" | sed "s/.*['\"]\\([^'\"]*\\)['\"].*/\\1/" | head -1)
    local wwwroot=$(grep -E '^\$CFG->wwwroot' "$config_file" | sed "s/.*['\"]\\([^'\"]*\\)['\"].*/\\1/" | head -1)
    
    # Mostrar configuración encontrada
    echo ""
    log_success "Configuración encontrada en Moodle:"
    echo -e "   ${CYAN}Tipo de BD:${NC} $db_type"
    echo -e "   ${CYAN}Host BD:${NC} $db_host"
    echo -e "   ${CYAN}Nombre BD:${NC} $db_name"
    echo -e "   ${CYAN}Usuario BD:${NC} $db_user"
    echo -e "   ${CYAN}Directorio datos:${NC} $moodledata"
    echo -e "   ${CYAN}URL del sitio:${NC} $wwwroot"
    
    # Preguntar si usar esta configuración
    echo ""
    read -r -p "¿Usar esta configuración detectada? [Y/n]: " use_detected
    
    if [[ -z "$use_detected" ]] || [[ "$use_detected" =~ ^[Yy] ]]; then
        # Exportar las variables para uso global
        export DETECTED_DB_HOST="$db_host"
        export DETECTED_DB_NAME="$db_name"
        export DETECTED_DB_USER="$db_user"
        export DETECTED_DB_PASS="$db_pass"
        export DETECTED_MOODLEDATA="$moodledata"
        export DETECTED_WWWROOT="$wwwroot"
        export DETECTED_DB_TYPE="$db_type"
        
        log_success "Configuración de Moodle cargada exitosamente"
        return 0
    else
        log_info "Se solicitará configuración manual"
        return 1
    fi
}

# Función para extraer dominio de la URL
extract_domain_from_url() {
    local url="$1"
    echo "$url" | sed 's|https\?://||' | sed 's|/.*||' | sed 's|:.*||'
}

# Función para configurar un cliente paso a paso
configure_client_interactive() {
    local client_number="$1"
    
    echo ""
    echo -e "${BLUE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                         CONFIGURACIÓN CLIENTE #$client_number                          ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Variables de configuración del cliente
    CLIENT_NAME=""
    CLIENT_DESCRIPTION=""
    PANEL_TYPE=""
    REQUIRE_CONFIG=""
    DOMAIN_NAME=""
    AUTO_DETECT_AGGRESSIVE=""
    PANEL_USER=""
    WWW_DIR=""
    MOODLEDATA_DIR=""
    TMP_DIR=""
    DB_HOST=""
    DB_NAME=""
    DB_USER=""
    DB_PASS=""
    GDRIVE_REMOTE=""
    MAX_BACKUPS_GDRIVE=""
    FORCE_THREADS=""
    FORCE_COMPRESSION_LEVEL=""
    OPTIMIZED_HOURS=""
    CUSTOM_UPLOAD_TIMEOUT=""
    MAINTENANCE_TITLE=""
    LOG_FILE=""
    EXTENDED_DIAGNOSTICS=""
    NOTIFICATION_EMAILS_EXTRA=""
    CRON_HOUR=""
    CRON_FREQUENCY=""
    
    # SECCIÓN 1: CONFIGURACIÓN UNIVERSAL MULTI-PANEL
    echo -e "${PURPLE}${BOLD}SECCIÓN 1: CONFIGURACIÓN UNIVERSAL MULTI-PANEL${NC}"
    echo ""
    
    # Auto-detectar panel primero
    log_step "Detectando tipo de panel de control..."
    local detected_panel=$(detect_control_panel)
    if [[ "$detected_panel" != "manual" ]]; then
        log_success "Panel detectado automáticamente: $detected_panel"
        echo ""
        read -r -p "¿Usar el panel detectado ($detected_panel)? [Y/n]: " use_detected_panel
        if [[ -z "$use_detected_panel" ]] || [[ "$use_detected_panel" =~ ^[Yy] ]]; then
            PANEL_TYPE="$detected_panel"
            log_success "✓ PANEL_TYPE = $PANEL_TYPE"
        else
            ask_with_default \
                "Tipo de panel de control del servidor:" \
                "$detected_panel" \
                "PANEL_TYPE" \
                "Valores válidos: auto, cpanel, plesk, directadmin, vestacp, ispconfig, manual"
        fi
    else
        ask_with_default \
            "Tipo de panel de control del servidor:" \
            "auto" \
            "PANEL_TYPE" \
            "Valores válidos: auto, cpanel, plesk, directadmin, vestacp, ispconfig, manual"
    fi
    
    ask_yes_no \
        "¿Requerir configuración manual (recomendado: false para auto-detección)?" \
        "false" \
        "REQUIRE_CONFIG"
    
    # El dominio solo es obligatorio para Plesk
    local domain_required="false"
    local domain_description="Opcional para la mayoría de paneles. Solo requerido para Plesk."
    if [[ "$PANEL_TYPE" == "plesk" ]]; then
        domain_required="true"
        domain_description="Requerido para Plesk. Nombre del dominio principal del sitio."
    fi
    
    ask_with_default \
        "Nombre del dominio (ejemplo: moodle.ejemplo.com):" \
        "" \
        "DOMAIN_NAME" \
        "$domain_description" \
        "$domain_required"
    
    ask_yes_no \
        "¿Activar búsqueda agresiva si no encuentra Moodle?" \
        "true" \
        "AUTO_DETECT_AGGRESSIVE"
    
    # SECCIÓN 2: IDENTIFICACIÓN DEL CLIENTE
    echo ""
    echo -e "${PURPLE}${BOLD}SECCIÓN 2: IDENTIFICACIÓN DEL CLIENTE${NC}"
    echo ""
    
    ask_with_default \
        "Nombre único del cliente (sin espacios, solo letras, números y guiones):" \
        "cliente$client_number" \
        "CLIENT_NAME" \
        "Se usará en nombres de archivos y carpetas. Ejemplo: empresa_com, cliente1"
    
    ask_with_default \
        "Descripción del cliente para logs y notificaciones:" \
        "Moodle Backup - $CLIENT_NAME" \
        "CLIENT_DESCRIPTION" \
        "Descripción amigable que aparecerá en emails y logs"
    
    # SECCIÓN 3: CONFIGURACIÓN DEL SERVIDOR
    echo ""
    echo -e "${PURPLE}${BOLD}SECCIÓN 3: CONFIGURACIÓN DEL SERVIDOR${NC}"
    echo ""
    
    # Obtener ejemplos de rutas según el panel
    local path_example=$(get_path_examples "$PANEL_TYPE")
    
    case "$PANEL_TYPE" in
        "cpanel")
            ask_with_default \
                "Usuario de cPanel:" \
                "" \
                "PANEL_USER" \
                "Nombre de usuario de la cuenta de cPanel" \
                "false"
            ;;
        "plesk")
            ask_with_default \
                "Usuario de Plesk:" \
                "" \
                "PANEL_USER" \
                "Usuario o dominio en Plesk (puede ser opcional en algunos casos)" \
                "false"
            ;;
        "directadmin")
            ask_with_default \
                "Usuario de DirectAdmin:" \
                "" \
                "PANEL_USER" \
                "Nombre de usuario de DirectAdmin" \
                "false"
            ;;
        *)
            ask_with_default \
                "Usuario del sistema:" \
                "" \
                "PANEL_USER" \
                "Usuario del sistema. Se detectará automáticamente si se deja vacío" \
                "false"
            ;;
    esac
    
    ask_with_default \
        "Directorio web de Moodle (ejemplo: $path_example):" \
        "" \
        "WWW_DIR" \
        "Ruta completa al directorio donde está instalado Moodle. Se intentará auto-detectar si se deja vacío" \
        "false"
    
    # Si se proporcionó WWW_DIR, intentar leer config.php
    local moodle_config_loaded="false"
    if [[ -n "$WWW_DIR" ]] && [[ -d "$WWW_DIR" ]]; then
        if read_moodle_config "$WWW_DIR"; then
            moodle_config_loaded="true"
            # Si se cargó la configuración de Moodle, usar valores detectados como predeterminados
            if [[ -n "$DETECTED_MOODLEDATA" ]]; then
                MOODLEDATA_DIR="$DETECTED_MOODLEDATA"
                log_success "✓ MOODLEDATA_DIR = $MOODLEDATA_DIR (desde config.php)"
            fi
            
            # Extraer dominio de la URL si no se especificó
            if [[ -z "$DOMAIN_NAME" ]] && [[ -n "$DETECTED_WWWROOT" ]]; then
                local extracted_domain=$(extract_domain_from_url "$DETECTED_WWWROOT")
                echo ""
                read -r -p "¿Usar dominio extraído de Moodle ($extracted_domain)? [Y/n]: " use_extracted_domain
                if [[ -z "$use_extracted_domain" ]] || [[ "$use_extracted_domain" =~ ^[Yy] ]]; then
                    DOMAIN_NAME="$extracted_domain"
                    log_success "✓ DOMAIN_NAME = $DOMAIN_NAME (extraído de Moodle)"
                fi
            fi
        fi
    fi
    
    # Solo preguntar por moodledata si no se cargó desde config.php
    if [[ "$moodle_config_loaded" != "true" ]]; then
        ask_with_default \
            "Directorio de datos de Moodle:" \
            "" \
            "MOODLEDATA_DIR" \
            "Ruta al directorio moodledata. Se detectará desde config.php si se deja vacío" \
            "false"
    fi
    
    ask_with_default \
        "Directorio temporal para backups:" \
        "/tmp/moodle_backup_$CLIENT_NAME" \
        "TMP_DIR" \
        "Debe tener suficiente espacio libre (al menos 2x el tamaño de Moodle + BD)"
    
    # SECCIÓN 4: CONFIGURACIÓN DE BASE DE DATOS
    echo ""
    echo -e "${PURPLE}${BOLD}SECCIÓN 4: CONFIGURACIÓN DE BASE DE DATOS${NC}"
    echo ""
    
    # Si se cargó la configuración de Moodle, usar valores detectados como predeterminados
    local default_db_host="localhost"
    local default_db_name=""
    local default_db_user=""
    
    if [[ "$moodle_config_loaded" == "true" ]]; then
        default_db_host="${DETECTED_DB_HOST:-localhost}"
        default_db_name="$DETECTED_DB_NAME"
        default_db_user="$DETECTED_DB_USER"
        
        log_info "Usando configuración detectada de Moodle como valores predeterminados"
    fi
    
    ask_with_default \
        "Host de la base de datos:" \
        "$default_db_host" \
        "DB_HOST" \
        "Normalmente 'localhost' para la mayoría de paneles"
    
    ask_with_default \
        "Nombre de la base de datos:" \
        "$default_db_name" \
        "DB_NAME" \
        "Nombre de la base de datos de Moodle. Se detectará desde config.php si se deja vacío" \
        "false"
    
    ask_with_default \
        "Usuario de la base de datos:" \
        "$default_db_user" \
        "DB_USER" \
        "Usuario para conectar a la base de datos. Se detectará desde config.php si se deja vacío" \
        "false"
    
    echo ""
    echo -e "${BLUE}¿Desea configurar la contraseña de la base de datos ahora?${NC}"
    echo -e "${BLUE}OPCIONES DE SEGURIDAD (ordenadas por seguridad):${NC}"
    echo "  1. Variable de entorno (MÁS SEGURO)"
    echo "  2. Archivo protegido /etc/mysql/backup.pwd (RECOMENDADO)"
    echo "  3. Ingresar ahora en texto plano (MENOS SEGURO)"
    echo "  4. Auto-detectar desde config.php (RECOMENDADO)"
    echo ""
    
    local default_option="4"
    if [[ "$moodle_config_loaded" == "true" ]] && [[ -n "$DETECTED_DB_PASS" ]]; then
        echo -e "${GREEN}Se detectó contraseña en config.php${NC}"
        default_option="4"
    fi
    
    read -r -p "Seleccione opción [1-4] ($default_option para auto-detección): " db_option
    
    if [[ -z "$db_option" ]]; then
        db_option="$default_option"
    fi
    
    case "$db_option" in
        "1")
            read -r -s -p "Ingrese la contraseña (se configurará como variable de entorno): " DB_PASS
            echo ""
            echo "export MYSQL_PASSWORD=\"$DB_PASS\"" >> ~/.bashrc
            log_success "✓ Contraseña configurada como variable de entorno"
            ;;
        "2")
            read -r -s -p "Ingrese la contraseña (se guardará en archivo protegido): " DB_PASS
            echo ""
            echo "$DB_PASS" | sudo tee /etc/mysql/backup.pwd > /dev/null
            sudo chmod 600 /etc/mysql/backup.pwd
            sudo chown root:root /etc/mysql/backup.pwd
            log_success "✓ Contraseña guardada en /etc/mysql/backup.pwd"
            ;;
        "3")
            read -r -s -p "Ingrese la contraseña (ADVERTENCIA: se guardará en texto plano): " DB_PASS
            echo ""
            log_warning "⚠️  La contraseña se guardará en texto plano en el archivo de configuración"
            ;;
        *)
            if [[ "$moodle_config_loaded" == "true" ]] && [[ -n "$DETECTED_DB_PASS" ]]; then
                DB_PASS="$DETECTED_DB_PASS"
                log_success "✓ Contraseña cargada desde config.php de Moodle"
            else
                DB_PASS=""
                log_success "✓ Se auto-detectará desde config.php durante la ejecución"
            fi
            ;;
    esac
    
    # SECCIÓN 5: CONFIGURACIÓN DE GOOGLE DRIVE
    echo ""
    echo -e "${PURPLE}${BOLD}SECCIÓN 5: CONFIGURACIÓN DE GOOGLE DRIVE${NC}"
    echo ""
    
    # Verificar si rclone está configurado
    if command -v rclone &> /dev/null; then
        echo "Remotos de rclone disponibles:"
        rclone listremotes || echo "No hay remotos configurados"
        echo ""
        
        ask_yes_no \
            "¿Desea configurar o reconfigurar rclone para Google Drive?" \
            "false" \
            "SETUP_RCLONE_NOW"
        
        if [[ "$SETUP_RCLONE_NOW" == "true" ]]; then
            log_step "Iniciando configuración de rclone..."
            rclone config
        fi
        
        ask_with_default \
            "Remote de rclone para Google Drive (formato: nombre_remote:carpeta_destino):" \
            "gdrive:moodle_backups_$CLIENT_NAME" \
            "GDRIVE_REMOTE" \
            "Ejemplo: gdrive:moodle_backups o drive:backups/moodle"
    else
        log_warning "rclone no está instalado. Se instalará durante el proceso."
        GDRIVE_REMOTE="gdrive:moodle_backups_$CLIENT_NAME"
        log_info "Se configurará por defecto: $GDRIVE_REMOTE"
    fi
    
    ask_with_default \
        "Número máximo de carpetas de backup a mantener en Google Drive:" \
        "3" \
        "MAX_BACKUPS_GDRIVE" \
        "Cantidad de backups históricos a conservar (recomendado: 3-7)"
    
    # SECCIÓN 6: CONFIGURACIÓN DE RENDIMIENTO
    echo ""
    echo -e "${PURPLE}${BOLD}SECCIÓN 6: CONFIGURACIÓN DE RENDIMIENTO${NC}"
    echo ""
    
    log_info "Configuración recomendada basada en su servidor ($SERVER_TYPE):"
    echo -e "   • Threads: ${GREEN}$RECOMMENDED_THREADS${NC}"
    echo -e "   • Compresión: ${GREEN}$RECOMMENDED_COMPRESSION${NC}"
    echo ""
    
    ask_with_default \
        "Número de threads a usar (0 = automático según horario):" \
        "$RECOMMENDED_THREADS" \
        "FORCE_THREADS" \
        "Más threads = más rápido pero consume más CPU"
    
    ask_with_default \
        "Nivel de compresión (1=rápido, 22=máxima compresión):" \
        "$RECOMMENDED_COMPRESSION" \
        "FORCE_COMPRESSION_LEVEL" \
        "Nivel $RECOMMENDED_COMPRESSION es óptimo para su servidor"
    
    ask_with_default \
        "Horario optimizado (formato HH-HH, 24h):" \
        "02-08" \
        "OPTIMIZED_HOURS" \
        "Durante estas horas se usarán más recursos. Recomendado: horario nocturno"
    
    ask_with_default \
        "Timeout personalizado para subidas (segundos, 0=automático):" \
        "0" \
        "CUSTOM_UPLOAD_TIMEOUT" \
        "Útil para conexiones lentas. 0 = detección automática"
    
    # SECCIÓN 7: CONFIGURACIÓN DE MANTENIMIENTO
    echo ""
    echo -e "${PURPLE}${BOLD}SECCIÓN 7: CONFIGURACIÓN DE MANTENIMIENTO${NC}"
    echo ""
    
    ask_with_default \
        "Título de la página de mantenimiento:" \
        "Mantenimiento - Moodle" \
        "MAINTENANCE_TITLE" \
        "Mensaje que verán los usuarios durante el backup"
    
    # SECCIÓN 8: CONFIGURACIÓN DE LOGGING
    echo ""
    echo -e "${PURPLE}${BOLD}SECCIÓN 8: CONFIGURACIÓN DE LOGGING${NC}"
    echo ""
    
    ask_with_default \
        "Archivo de log:" \
        "/var/log/moodle_backup_$CLIENT_NAME.log" \
        "LOG_FILE" \
        "Ubicación del archivo de log específico para este cliente"
    
    ask_yes_no \
        "¿Activar diagnósticos extendidos?" \
        "true" \
        "EXTENDED_DIAGNOSTICS"
    
    # SECCIÓN 9: CONFIGURACIÓN DE NOTIFICACIONES (OBLIGATORIO)
    echo ""
    echo -e "${PURPLE}${BOLD}SECCIÓN 9: CONFIGURACIÓN DE NOTIFICACIONES${NC}"
    echo ""
    
    log_warning "⚠️  OBLIGATORIO: Debe configurar al menos un email"
    
    while true; do
        read -r -p "Ingrese email(s) para notificaciones (separados por comas): " NOTIFICATION_EMAILS_EXTRA
        
        if [[ -z "$NOTIFICATION_EMAILS_EXTRA" ]]; then
            log_error "El email es obligatorio para recibir notificaciones de backup"
            continue
        fi
        
        # Validar emails
        valid_emails=true
        IFS=',' read -ra EMAILS <<< "$NOTIFICATION_EMAILS_EXTRA"
        for email in "${EMAILS[@]}"; do
            email=$(echo "$email" | xargs) # Trim spaces
            if ! validate_email "$email"; then
                log_error "Email inválido: $email"
                valid_emails=false
                break
            fi
        done
        
        if [[ "$valid_emails" == "true" ]]; then
            log_success "✓ Emails configurados: $NOTIFICATION_EMAILS_EXTRA"
            break
        fi
    done
    
    # SECCIÓN 10: CONFIGURACIÓN DE CRON
    echo ""
    echo -e "${PURPLE}${BOLD}SECCIÓN 10: CONFIGURACIÓN DE PROGRAMACIÓN (CRON)${NC}"
    echo ""
    
    log_info "Configuración de la programación automática del backup:"
    echo ""
    echo "Opciones de frecuencia:"
    echo "  1. Diario"
    echo "  2. Cada 2 días"
    echo "  3. Semanal (domingos)"
    echo "  4. Quincenal (1° y 15 de cada mes)"
    echo "  5. Mensual (día 1 de cada mes)"
    echo "  6. Personalizado"
    echo ""
    
    read -r -p "Seleccione frecuencia [1-6]: " freq_option
    
    case "$freq_option" in
        "1")
            CRON_FREQUENCY="daily"
            ;;
        "2")
            CRON_FREQUENCY="every_2_days"
            ;;
        "3")
            CRON_FREQUENCY="weekly"
            ;;
        "4")
            CRON_FREQUENCY="biweekly"
            ;;
        "5")
            CRON_FREQUENCY="monthly"
            ;;
        "6")
            read -r -p "Ingrese expresión cron personalizada (ejemplo: 0 2 * * 0): " CRON_FREQUENCY
            ;;
        *)
            CRON_FREQUENCY="daily"
            log_info "Usando frecuencia por defecto: diaria"
            ;;
    esac
    
    ask_with_default \
        "Hora de ejecución (0-23):" \
        "2" \
        "CRON_HOUR" \
        "Hora en formato 24h. Recomendado: horario nocturno (2-6 AM)"
    
    # MOSTRAR RESUMEN DE CONFIGURACIÓN
    echo ""
    echo -e "${GREEN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                           RESUMEN DE CONFIGURACIÓN                          ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo -e "${YELLOW}Cliente:${NC} $CLIENT_NAME"
    echo -e "${YELLOW}Descripción:${NC} $CLIENT_DESCRIPTION"
    echo -e "${YELLOW}Panel:${NC} $PANEL_TYPE"
    echo -e "${YELLOW}Usuario:${NC} $PANEL_USER"
    echo -e "${YELLOW}Dominio:${NC} $DOMAIN_NAME"
    echo -e "${YELLOW}Directorio web:${NC} ${WWW_DIR:-'Auto-detectar'}"
    echo -e "${YELLOW}Datos Moodle:${NC} ${MOODLEDATA_DIR:-'Auto-detectar'}"
    echo -e "${YELLOW}Base de datos:${NC} ${DB_NAME:-'Auto-detectar'}@$DB_HOST"
    echo -e "${YELLOW}Google Drive:${NC} $GDRIVE_REMOTE"
    echo -e "${YELLOW}Max backups:${NC} $MAX_BACKUPS_GDRIVE"
    echo -e "${YELLOW}Threads:${NC} $FORCE_THREADS"
    echo -e "${YELLOW}Compresión:${NC} $FORCE_COMPRESSION_LEVEL"
    echo -e "${YELLOW}Horario optimizado:${NC} $OPTIMIZED_HOURS"
    echo -e "${YELLOW}Emails:${NC} $NOTIFICATION_EMAILS_EXTRA"
    echo -e "${YELLOW}Frecuencia:${NC} $CRON_FREQUENCY"
    echo -e "${YELLOW}Hora:${NC} ${CRON_HOUR}:00"
    echo ""
    
    ask_yes_no \
        "¿Confirma esta configuración?" \
        "true" \
        "CONFIRM_CONFIG"
    
    if [[ "$CONFIRM_CONFIG" != "true" ]]; then
        log_warning "Configuración cancelada. Regresando al menú principal."
        return 1
    fi
    
    # GENERAR ARCHIVO DE CONFIGURACIÓN
    local config_file="$CONFIG_DIR/$CLIENT_NAME.conf"
    mkdir -p "$CONFIG_DIR"
    
    cat > "$config_file" << EOF
# ===================== CONFIGURACIÓN MOODLE BACKUP V3 =====================
# Cliente: $CLIENT_NAME
# Generado automáticamente el: $(date)
# =========================================================================

# ===================== CONFIGURACIÓN UNIVERSAL MULTI-PANEL =====================
PANEL_TYPE="$PANEL_TYPE"
REQUIRE_CONFIG=$REQUIRE_CONFIG
DOMAIN_NAME="$DOMAIN_NAME"
AUTO_DETECT_AGGRESSIVE="$AUTO_DETECT_AGGRESSIVE"

# ===================== IDENTIFICACIÓN DEL CLIENTE =====================
CLIENT_NAME="$CLIENT_NAME"
CLIENT_DESCRIPTION="$CLIENT_DESCRIPTION"

# ===================== CONFIGURACIÓN DEL SERVIDOR =====================
PANEL_USER="$PANEL_USER"
WWW_DIR="$WWW_DIR"
MOODLEDATA_DIR="$MOODLEDATA_DIR"
TMP_DIR="$TMP_DIR"

# ===================== CONFIGURACIÓN DE BASE DE DATOS =====================
DB_HOST=$DB_HOST
DB_NAME="$DB_NAME"
DB_USER="$DB_USER"
EOF

    # Solo agregar contraseña si se configuró en texto plano
    if [[ -n "$DB_PASS" ]] && [[ "$db_option" == "3" ]]; then
        echo "DB_PASS=\"$DB_PASS\"" >> "$config_file"
    fi

    cat >> "$config_file" << EOF

# ===================== CONFIGURACIÓN DE GOOGLE DRIVE =====================
GDRIVE_REMOTE=$GDRIVE_REMOTE
MAX_BACKUPS_GDRIVE=$MAX_BACKUPS_GDRIVE

# ===================== CONFIGURACIÓN DE RENDIMIENTO =====================
FORCE_THREADS=$FORCE_THREADS
FORCE_COMPRESSION_LEVEL=$FORCE_COMPRESSION_LEVEL
OPTIMIZED_HOURS="$OPTIMIZED_HOURS"
CUSTOM_UPLOAD_TIMEOUT=$CUSTOM_UPLOAD_TIMEOUT

# ===================== CONFIGURACIÓN DE MANTENIMIENTO =====================
MAINTENANCE_TITLE="$MAINTENANCE_TITLE"

# ===================== CONFIGURACIÓN DE LOGGING =====================
LOG_FILE="$LOG_FILE"
EXTENDED_DIAGNOSTICS=$EXTENDED_DIAGNOSTICS

# ===================== CONFIGURACIÓN DE NOTIFICACIONES =====================
NOTIFICATION_EMAILS_EXTRA="$NOTIFICATION_EMAILS_EXTRA"

# ===================== CONFIGURACIÓN INTERNA =====================
# Programación cron: $CRON_FREQUENCY a las $CRON_HOUR:00
CRON_FREQUENCY="$CRON_FREQUENCY"
CRON_HOUR="$CRON_HOUR"
EOF

    chmod 600 "$config_file"
    log_success "✅ Configuración guardada en: $config_file"
    
    # CONFIGURAR CRON - Solo si CLIENT_NAME no está vacío
    if [[ -n "$CLIENT_NAME" ]] && [[ -n "$CRON_FREQUENCY" ]] && [[ -n "$CRON_HOUR" ]]; then
        configure_cron_for_client "$CLIENT_NAME" "$CRON_FREQUENCY" "$CRON_HOUR"
    else
        log_warning "⚠️ No se configuró cron: CLIENT_NAME='$CLIENT_NAME', CRON_FREQUENCY='$CRON_FREQUENCY', CRON_HOUR='$CRON_HOUR'"
    fi
    
    echo ""
    ask_yes_no \
        "¿Desea agregar otra configuración de cliente?" \
        "false" \
        "ADD_ANOTHER_CLIENT"
    
    return 0
}

# Función para configurar cron para un cliente específico
configure_cron_for_client() {
    local client_name="$1"
    local frequency="$2"
    local hour="$3"
    
    # Validar parámetros
    if [[ -z "$client_name" ]]; then
        log_error "❌ Error: client_name está vacío"
        return 1
    fi
    
    if [[ -z "$frequency" ]]; then
        log_error "❌ Error: frequency está vacío"
        return 1
    fi
    
    if [[ -z "$hour" ]]; then
        log_error "❌ Error: hour está vacío"
        return 1
    fi
    
    log_step "Configurando cron para cliente: $client_name"
    
    # Generar la expresión cron según la frecuencia
    local cron_expression=""
    case "$frequency" in
        "daily")
            cron_expression="0 $hour * * *"
            ;;
        "every_2_days")
            cron_expression="0 $hour */2 * *"
            ;;
        "weekly")
            cron_expression="0 $hour * * 0"
            ;;
        "biweekly")
            cron_expression="0 $hour 1,15 * *"
            ;;
        "monthly")
            cron_expression="0 $hour 1 * *"
            ;;
        *)
            cron_expression="$frequency"
            ;;
    esac
    
    # Comando del cron
    local cron_command="CONFIG_FILE=$CONFIG_DIR/$client_name.conf $INSTALL_DIR/mb >/dev/null 2>&1"
    local cron_line="$cron_expression $cron_command # Moodle Backup - $client_name"
    
    # Agregar al crontab
    (crontab -l 2>/dev/null || echo "") | grep -v "# Moodle Backup - $client_name" | { cat; echo "$cron_line"; } | crontab -
    
    log_success "✅ Cron configurado para $client_name: $cron_expression"
    
    # Crear archivo de estado del cron
    local cron_status_file="$CONFIG_DIR/.cron_status"
    mkdir -p "$CONFIG_DIR"
    echo "$client_name:enabled:$cron_expression" >> "$cron_status_file"
}

# Función para deshabilitar cron de un cliente
disable_cron_for_client() {
    local client_name="$1"
    
    log_step "Deshabilitando cron para cliente: $client_name"
    
    # Remover del crontab
    (crontab -l 2>/dev/null || echo "") | grep -v "# Moodle Backup - $client_name" | crontab -
    
    # Actualizar archivo de estado
    local cron_status_file="$CONFIG_DIR/.cron_status"
    if [[ -f "$cron_status_file" ]]; then
        sed -i "/^$client_name:enabled:/c\\$client_name:disabled:" "$cron_status_file"
    fi
    
    log_success "✅ Cron deshabilitado para $client_name"
}

# Función para habilitar cron de un cliente
enable_cron_for_client() {
    local client_name="$1"
    
    log_step "Habilitando cron para cliente: $client_name"
    
    # Leer configuración del cliente
    local config_file="$CONFIG_DIR/$client_name.conf"
    if [[ ! -f "$config_file" ]]; then
        log_error "No se encontró configuración para cliente: $client_name"
        return 1
    fi
    
    # Extraer configuración de cron del archivo
    local cron_frequency=$(grep "^CRON_FREQUENCY=" "$config_file" | cut -d'"' -f2)
    local cron_hour=$(grep "^CRON_HOUR=" "$config_file" | cut -d'"' -f2)
    
    # Reconfigurar cron
    configure_cron_for_client "$client_name" "$cron_frequency" "$cron_hour"
    
    # Actualizar archivo de estado
    local cron_status_file="$CONFIG_DIR/.cron_status"
    if [[ -f "$cron_status_file" ]]; then
        sed -i "/^$client_name:disabled:/c\\$client_name:enabled:" "$cron_status_file"
    fi
}

# Función principal de instalación interactiva mejorada
main_interactive_install() {
    print_banner
    print_header
    
    echo ""
    log_info "🚀 Bienvenido al instalador interactivo de Moodle Backup V3"
    log_info "Este instalador le guiará paso a paso para configurar backups automáticos"
    echo ""
    
    # Detectar capacidades del servidor
    detect_server_capabilities
    wait_continue
    
    # Configurar directorios
    setup_directories
    
    # Instalar dependencias
    install_dependencies
    
    # Descargar scripts
    download_scripts
    
    # Configuración interactiva multi-cliente
    local client_number=1
    local continue_adding=true
    
    while [[ "$continue_adding" == "true" ]]; do
        if configure_client_interactive "$client_number"; then
            client_number=$((client_number + 1))
            continue_adding="$ADD_ANOTHER_CLIENT"
        else
            continue_adding="false"
        fi
    done
    
    # Configurar rclone si es necesario
    setup_rclone_if_needed
    
    # Mostrar resumen final
    show_final_summary
    
    log_success "🎉 ¡Instalación completada exitosamente!"
    echo ""
    log_info "Comandos disponibles:"
    echo "   mb                    - Ver menú de selección de clientes"
    echo "   mb list               - Listar configuraciones disponibles"
    echo "   mb on <cliente>       - Habilitar cron para un cliente"
    echo "   mb off <cliente>      - Deshabilitar cron para un cliente"
    echo "   mb status             - Ver estado de todos los clientes"
    echo ""
}

# Función para configurar directorios
setup_directories() {
    log_step "Configurando directorios del sistema..."
    
    # Determinar directorio de instalación
    if [[ $EUID -eq 0 ]]; then
        INSTALL_DIR="/usr/local/bin"
        GLOBAL_INSTALL=true
    else
        INSTALL_DIR="$HOME/bin"
        mkdir -p "$INSTALL_DIR"
        # Agregar al PATH si no está
        if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
            echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> ~/.bashrc
            export PATH="$INSTALL_DIR:$PATH"
        fi
    fi
    
    # Crear directorio de configuraciones
    mkdir -p "$CONFIG_DIR"
    chmod 755 "$CONFIG_DIR"
    
    log_success "✅ Directorios configurados"
    log_info "   • Instalación: $INSTALL_DIR"
    log_info "   • Configuraciones: $CONFIG_DIR"
}

# Función para instalar dependencias
install_dependencies() {
    log_step "Verificando e instalando dependencias..."
    
    local missing_deps=()
    
    # Verificar dependencias
    for dep in curl wget pv tar gzip; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    # Instalar dependencias faltantes
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_warning "Instalando dependencias: ${missing_deps[*]}"
        
        if command -v apt-get &> /dev/null; then
            sudo apt-get update
            sudo apt-get install -y "${missing_deps[@]}"
        elif command -v yum &> /dev/null; then
            sudo yum install -y "${missing_deps[@]}"
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y "${missing_deps[@]}"
        else
            log_error "No se pudo detectar el gestor de paquetes del sistema"
            log_warning "Por favor, instale manualmente: ${missing_deps[*]}"
        fi
    fi
    
    # Verificar rclone
    if ! command -v rclone &> /dev/null; then
        log_step "Instalando rclone..."
        curl https://rclone.org/install.sh | sudo bash
    fi
    
    log_success "✅ Dependencias verificadas e instaladas"
}

# Función para descargar scripts
download_scripts() {
    log_step "Descargando scripts desde GitHub..."
    
    # Lista de archivos a descargar
    local files=(
        "moodle_backup.sh"
        "mb"
    )
    
    for file in "${files[@]}"; do
        log_info "Descargando $file..."
        if curl -fsSL "$GITHUB_REPO/$file" -o "$INSTALL_DIR/$file"; then
            chmod +x "$INSTALL_DIR/$file"
            log_success "✅ $file descargado"
        else
            log_error "❌ Error descargando $file"
            exit 1
        fi
    done
    
    log_success "✅ Scripts descargados e instalados"
}

# Función para configurar rclone si es necesario
setup_rclone_if_needed() {
    if ! command -v rclone &> /dev/null; then
        log_error "rclone no está disponible"
        return 1
    fi
    
    # Verificar si hay remotos configurados
    if ! rclone listremotes | grep -q .; then
        log_warning "No se encontraron remotos de rclone configurados"
        ask_yes_no \
            "¿Desea configurar rclone para Google Drive ahora?" \
            "true" \
            "CONFIGURE_RCLONE_NOW"
        
        if [[ "$CONFIGURE_RCLONE_NOW" == "true" ]]; then
            log_step "Iniciando configuración de rclone..."
            rclone config
        fi
    fi
}

# Función para mostrar resumen final
show_final_summary() {
    echo ""
    echo -e "${GREEN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                              INSTALACIÓN COMPLETADA                         ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    log_info "📁 Archivos instalados en: $INSTALL_DIR"
    log_info "⚙️  Configuraciones en: $CONFIG_DIR"
    
    echo ""
    log_info "🔧 Clientes configurados:"
    if [[ -d "$CONFIG_DIR" ]]; then
        for config_file in "$CONFIG_DIR"/*.conf; do
            if [[ -f "$config_file" ]]; then
                local client_name=$(basename "$config_file" .conf)
                local client_desc=$(grep "^CLIENT_DESCRIPTION=" "$config_file" | cut -d'"' -f2)
                echo -e "   • ${GREEN}$client_name${NC}: $client_desc"
            fi
        done
    fi
    
    echo ""
    log_info "📅 Tareas cron programadas:"
    crontab -l | grep "Moodle Backup" || log_warning "No hay tareas cron configuradas"
}

# Función principal
main() {
    main_interactive_install
}

# Verificar requisitos mínimos
if [[ "${BASH_VERSION%%.*}" -lt 4 ]]; then
    log_error "Bash 4.0+ requerido. Versión actual: $BASH_VERSION"
    exit 1
fi

# Ejecutar instalador interactivo
main "$@"
