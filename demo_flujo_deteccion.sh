#!/bin/bash

##
# Demostración del Flujo de Detección de Servidores Web y Moodle
# 
# Este script simula el flujo completo que ve el usuario en la terminal
# cuando se ejecuta la detección automática del CLI de backup Moodle.
#
# Uso: ./demo_flujo_deteccion.sh
##

set -euo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Función para simular logs con timestamp
log_with_timestamp() {
    local level="$1"
    local message="$2"
    local color="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${color}[${timestamp}] [${level}] ${message}${NC}"
}

# Funciones de logging simuladas
log_info() { log_with_timestamp "INFO" "$1" "$BLUE"; }
log_success() { log_with_timestamp "SUCCESS" "✓ $1" "$GREEN"; }
log_warning() { log_with_timestamp "WARNING" "⚠ $1" "$YELLOW"; }
log_debug() { log_with_timestamp "DEBUG" "$1" "$CYAN"; }

# Función para pausar y continuar
pause_demo() {
    echo ""
    echo -e "${PURPLE}[Presiona ENTER para continuar...]${NC}"
    read -r
    echo ""
}

# Función para mostrar header
show_header() {
    echo ""
    echo -e "${BOLD}${PURPLE}===============================================${NC}"
    echo -e "${BOLD}${PURPLE}  $1${NC}"
    echo -e "${BOLD}${PURPLE}===============================================${NC}"
    echo ""
}

# Función para simular detección con delay
simulate_detection() {
    local message="$1"
    log_info "$message"
    sleep 1
}

# Inicio de la demostración
clear
show_header "🚀 DEMOSTRACIÓN: Flujo de Detección Moodle CLI"

echo -e "${BOLD}Este demo muestra exactamente lo que ve el usuario en la terminal${NC}"
echo -e "${BOLD}cuando ejecuta el sistema de detección automática.${NC}"
pause_demo

# ==============================================
# FASE 1: INICIO DEL SISTEMA
# ==============================================
show_header "📋 FASE 1: Inicio del Sistema"

echo -e "${BOLD}$ ./moodle_backup.sh${NC}"
sleep 1

log_info "Moodle CLI Backup v3.0 - Sistema de Detección Automática"
log_info "Inicializando módulos de detección..."
log_debug "Cache de detección inicializado en: /tmp/moodle-detection-cache"
log_info "Módulos de detección cargados: 4"

pause_demo

# ==============================================
# FASE 2: DETECCIÓN DE PANELES/SERVIDORES WEB
# ==============================================
show_header "🌐 FASE 2: Detección de Paneles y Servidores Web"

log_info "Iniciando detección automática..."
log_info "Ejecutando detección: panels"
sleep 1

log_debug "Verificando paneles de control..."
log_debug "- Buscando cPanel: /usr/local/cpanel/bin/whmapi1"
log_debug "- Buscando Plesk: /opt/psa/bin/admin"
log_debug "- Buscando DirectAdmin: /usr/local/directadmin/custombuild"
sleep 1

log_debug "Verificando servidores web..."
log_debug "- Buscando Apache: /etc/httpd/, /etc/apache2/"
log_debug "- Buscando Nginx: /etc/nginx/"
log_debug "- Buscando OpenLiteSpeed: /usr/local/lsws/"
sleep 1

# Simular detección exitosa de Apache
log_success "Panel detectado: Apache 2.4.54"
log_debug "  → Archivos de configuración: /etc/apache2/"
log_debug "  → VirtualHosts encontrados: 3"
log_debug "  → Sitios web activos: 2"
log_success "Detección completada: panels"

pause_demo

# ==============================================
# FASE 3: DETECCIÓN DE INSTALACIONES MOODLE
# ==============================================
show_header "🎓 FASE 3: Búsqueda de Instalaciones Moodle"

log_info "Ejecutando detección: moodle"
log_info "Buscando instalaciones Moodle..."

echo ""
echo -e "${CYAN}Rutas de búsqueda configuradas:${NC}"
echo -e "${CYAN}  - /var/www${NC}"
echo -e "${CYAN}  - /var/www/html${NC}"
echo -e "${CYAN}  - /home/*/public_html${NC}"
echo -e "${CYAN}  - /home/*/www${NC}"
echo -e "${CYAN}  - /usr/local/apache/htdocs${NC}"
echo -e "${CYAN}  - /opt/bitnami/apache2/htdocs${NC}"
echo -e "${CYAN}  - /srv/www${NC}"
echo -e "${CYAN}  - /www${NC}"
echo ""

sleep 2

log_debug "Buscando en: /var/www (profundidad: 3)"
log_debug "Buscando en: /var/www/html (profundidad: 3)"
sleep 1
log_debug "Config encontrado: /var/www/html/moodle/config.php"
log_debug "Validando instalación Moodle: /var/www/html/moodle"
log_debug "Config válido: /var/www/html/moodle/config.php (5/6 patrones)"
log_debug "Instalación Moodle válida: /var/www/html/moodle"
log_success "Moodle encontrado: /var/www/html/moodle"

sleep 1

log_debug "Buscando en: /home/*/public_html (profundidad: 3)"
log_debug "Config encontrado: /home/cliente1/public_html/learning/config.php"
log_debug "Validando instalación Moodle: /home/cliente1/public_html/learning"
log_debug "Config válido: /home/cliente1/public_html/learning/config.php (6/6 patrones)"
log_debug "Instalación Moodle válida: /home/cliente1/public_html/learning"
log_success "Moodle encontrado: /home/cliente1/public_html/learning"

sleep 1

log_info "Búsqueda completada. Encontradas 2 instalaciones"
log_success "Detección completada: moodle"

pause_demo

# ==============================================
# FASE 4: ANÁLISIS DETALLADO
# ==============================================
show_header "🔍 FASE 4: Análisis Detallado de Instalaciones"

log_info "Analizando instalaciones encontradas..."

echo ""
echo -e "${BOLD}${GREEN}📊 RESUMEN DE DETECCIÓN:${NC}"
echo ""
echo -e "${GREEN}🌐 Sistema detectado:${NC}"
echo -e "  - Panel: Apache 2.4.54"
echo -e "  - Servidor Web: Apache (2 sitios web encontrados)"
echo -e "  - SO: Ubuntu 20.04 LTS"
echo ""

echo -e "${GREEN}🎓 Instalaciones Moodle encontradas:${NC}"
echo ""

# Simular análisis de cada instalación
log_debug "Extrayendo información de: /var/www/html/moodle"
echo -e "${CYAN}1) /var/www/html/moodle${NC}"
echo -e "   - Versión: 4.1.2"
echo -e "   - Base de datos: moodle_prod (MySQL)"
echo -e "   - Dataroot: /var/moodledata"
echo -e "   - WWW Root: https://ejemplo.com/moodle"
echo -e "   - Estado: Activo"
echo -e "   - Permisos: OK"
echo ""

log_debug "Extrayendo información de: /home/cliente1/public_html/learning"
echo -e "${CYAN}2) /home/cliente1/public_html/learning${NC}"
echo -e "   - Versión: 3.11.8"
echo -e "   - Base de datos: cliente1_moodle (MySQL)"
echo -e "   - Dataroot: /home/cliente1/moodledata"
echo -e "   - WWW Root: https://cliente1.ejemplo.com/learning"
echo -e "   - Estado: Activo"
echo -e "   - Permisos: OK"
echo ""

pause_demo

# ==============================================
# FASE 5: SELECCIÓN INTERACTIVA
# ==============================================
show_header "⚡ FASE 5: Selección Interactiva"

echo -e "${BOLD}El sistema presenta las opciones al usuario:${NC}"
echo ""

echo -e "${YELLOW}Instalaciones Moodle encontradas:${NC}"
echo ""
echo -e "${WHITE}1) /var/www/html/moodle (v4.1.2) - Base de datos: moodle_prod${NC}"
echo -e "${WHITE}2) /home/cliente1/public_html/learning (v3.11.8) - Base de datos: cliente1_moodle${NC}"
echo ""
echo -e "${YELLOW}Seleccione la instalación a respaldar [1-2]: ${NC}"

# Simular selección del usuario
echo -e "${BOLD}1${NC}"
echo ""

log_info "Instalación seleccionada: /var/www/html/moodle"
log_info "Panel detectado: Apache - optimizando configuración"
log_info "Configurando backup para Moodle v4.1.2"
log_info "Base de datos: moodle_prod (MySQL)"
log_info "Dataroot: /var/moodledata"

pause_demo

# ==============================================
# FASE 6: CONFIGURACIÓN FINAL
# ==============================================
show_header "🔧 FASE 6: Configuración y Inicio de Backup"

log_success "✓ Configuración completada - iniciando backup..."
log_info "Aplicando optimizaciones específicas para Apache"
log_info "Configurando rutas de logs: /var/log/apache2/"
log_info "Configurando permisos de usuario: www-data"
log_info "Verificando conectividad a base de datos..."
log_success "✓ Conexión a MySQL establecida"
log_info "Iniciando proceso de backup..."

echo ""
echo -e "${BOLD}${GREEN}🎉 ¡FLUJO DE DETECCIÓN COMPLETADO!${NC}"
echo ""

pause_demo

# ==============================================
# RESUMEN FINAL
# ==============================================
show_header "📚 RESUMEN: Puntos Clave del Flujo"

echo -e "${BOLD}${GREEN}✅ Lo que SÍ hace la detección de paneles/servidores web:${NC}"
echo "  1. Identifica el entorno (cPanel, Plesk, Apache, Nginx, etc.)"
echo "  2. Proporciona contexto para optimizaciones específicas"
echo "  3. Informa al usuario sobre el sistema detectado"
echo "  4. Permite configuraciones específicas por tipo de panel"
echo ""

echo -e "${BOLD}${RED}❌ Lo que NO hace la detección de paneles/servidores web:${NC}"
echo "  1. NO modifica las rutas de búsqueda de Moodle"
echo "  2. NO restringe la búsqueda a rutas específicas del panel"
echo "  3. NO es prerequisito para encontrar instalaciones Moodle"
echo ""

echo -e "${BOLD}${CYAN}🎯 La búsqueda de Moodle es independiente:${NC}"
echo "  - Siempre busca en rutas estándar predefinidas"
echo "  - Valida cada config.php encontrado"
echo "  - Funciona sin importar el panel detectado"
echo "  - Es robusta para cualquier configuración de servidor"
echo ""

echo -e "${BOLD}${PURPLE}🔗 Relación Panel ↔ Moodle:${NC}"
echo "  Panel detectado → Contexto e información para el usuario"
echo "  Búsqueda Moodle → Independiente, rutas fijas predefinidas"
echo "  Resultado final → Combinación de ambos para backup optimizado"
echo ""

echo -e "${BOLD}${BLUE}Este flujo garantiza que el sistema funcione en cualquier${NC}"
echo -e "${BOLD}${BLUE}configuración de servidor, con o sin panel de control.${NC}"

echo ""
echo -e "${BOLD}${GREEN}¡Demostración completada!${NC}"
