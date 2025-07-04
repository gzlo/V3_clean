#!/usr/bin/env bash

##
# Moodle CLI Backup - Detector de Paneles de Control
# 
# Sistema de detección automática de paneles de control web
# Soporta: cPanel, Plesk, DirectAdmin, VestaCP, HestiaCP, ISPConfig, Docker, Manual
# 
# @version 1.0.0
# @author GZL Online
##

set -euo pipefail

# ===================== GUARDS Y VALIDACIONES =====================

if [[ "${MOODLE_PANELS_DETECTOR_LOADED:-}" == "true" ]]; then
    return 0
fi

readonly MOODLE_PANELS_DETECTOR_LOADED="true"

# Verificar dependencias core
if [[ "${MOODLE_BACKUP_LOGGING_LOADED:-}" != "true" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/../core/logging.sh"
fi

# ===================== CONFIGURACIÓN DE DETECCIÓN =====================

# Rutas comunes para detección de paneles
declare -A PANEL_PATHS=(
    # cPanel
    ["cpanel"]="/usr/local/cpanel/version"
    ["cpanel_bin"]="/usr/local/cpanel/bin"
    ["cpanel_whm"]="/usr/local/cpanel/whostmgr"
    
    # Plesk
    ["plesk"]="/usr/local/psa/version"
    ["plesk_bin"]="/usr/local/psa/bin"
    ["plesk_admin"]="/usr/local/psa/admin"
    
    # DirectAdmin
    ["directadmin"]="/usr/local/directadmin/conf/directadmin.conf"
    ["directadmin_bin"]="/usr/local/directadmin/directadmin"
    
    # VestaCP
    ["vestacp"]="/usr/local/vesta/conf/vesta.conf"
    ["vestacp_bin"]="/usr/local/vesta/bin"
    
    # HestiaCP (fork de VestaCP)
    ["hestiacp"]="/usr/local/hestia/conf/hestia.conf"
    ["hestiacp_bin"]="/usr/local/hestia/bin"
    
    # ISPConfig
    ["ispconfig"]="/usr/local/ispconfig/interface/lib/config.inc.php"
    ["ispconfig_server"]="/usr/local/ispconfig/server/lib/config.inc.php"
    
    # CyberPanel
    ["cyberpanel"]="/usr/local/CyberCP/CyberCP/settings.py"
    ["cyberpanel_bin"]="/usr/local/lsws/bin/openlitespeed"
    
    # Webmin
    ["webmin"]="/etc/webmin/config"
    ["webmin_usermin"]="/etc/usermin/config"
)

# Rutas comunes para servidores web manuales
declare -A WEBSERVER_PATHS=(
    # Apache HTTP Server
    ["apache_config"]="/etc/apache2/apache2.conf"
    ["apache_config_centos"]="/etc/httpd/conf/httpd.conf"
    ["apache_config_freebsd"]="/usr/local/etc/apache24/httpd.conf"
    ["apache_sites"]="/etc/apache2/sites-available"
    ["apache_sites_centos"]="/etc/httpd/conf.d"
    ["apache_bin"]="/usr/sbin/apache2"
    ["apache_bin_centos"]="/usr/sbin/httpd"
    
    # Nginx
    ["nginx_config"]="/etc/nginx/nginx.conf"
    ["nginx_sites"]="/etc/nginx/sites-available"
    ["nginx_conf_d"]="/etc/nginx/conf.d"
    ["nginx_bin"]="/usr/sbin/nginx"
    ["nginx_bin_alt"]="/usr/bin/nginx"
    
    # OpenLiteSpeed
    ["openlitespeed_config"]="/usr/local/lsws/conf/httpd_config.conf"
    ["openlitespeed_admin"]="/usr/local/lsws/admin/conf/admin_config.conf"
    ["openlitespeed_bin"]="/usr/local/lsws/bin/openlitespeed"
    ["openlitespeed_vhosts"]="/usr/local/lsws/conf/vhosts"
)

# Procesos comunes de paneles
declare -A PANEL_PROCESSES=(
    ["cpanel"]="cpanel\|whostmgr"
    ["plesk"]="sw-engine\|panel"
    ["directadmin"]="directadmin"
    ["vestacp"]="vesta-nginx\|vesta-php"
    ["hestiacp"]="hestia-nginx\|hestia-php"
    ["ispconfig"]="ispconfig"
    ["cyberpanel"]="litespeed\|openlitespeed"
    ["webmin"]="webmin\|usermin"
)

# Procesos comunes de servidores web
declare -A WEBSERVER_PROCESSES=(
    ["apache"]="apache2\|httpd"
    ["nginx"]="nginx"
    ["openlitespeed"]="openlitespeed\|lshttpd"
)

# Puertos comunes de paneles
declare -A PANEL_PORTS=(
    ["cpanel"]="2082,2083,2086,2087"
    ["plesk"]="8443,8880"
    ["directadmin"]="2222"
    ["vestacp"]="8083"
    ["hestiacp"]="8083"
    ["ispconfig"]="8080"
    ["cyberpanel"]="8090"
    ["webmin"]="10000"
)

# Puertos comunes de servidores web
declare -A WEBSERVER_PORTS=(
    ["apache"]="80,443"
    ["nginx"]="80,443"
    ["openlitespeed"]="80,443,7080,8088"
)

# Variables de entorno comunes
declare -A PANEL_ENV_VARS=(
    ["cpanel"]="CPANEL_VERSION"
    ["plesk"]="PLESK_VERSION"
    ["directadmin"]="DA_PATH"
    ["vestacp"]="VESTA"
    ["hestiacp"]="HESTIA"
)

# Estado de detección
PANEL_DETECTION_STARTED=false
declare -A DETECTED_PANELS=()

# ===================== FUNCIONES DE DETECCIÓN ESPECÍFICAS =====================

##
# Detecta cPanel
# @return 0 si se detecta cPanel
##
detect_cpanel() {
    local cpanel_info=""
    
    # Verificar archivos de versión
    if [[ -f "${PANEL_PATHS[cpanel]}" ]]; then
        local version
        version=$(cat "${PANEL_PATHS[cpanel]}" 2>/dev/null | head -1)
        cpanel_info="cPanel $version"
        
        # Verificar binarios
        if [[ -d "${PANEL_PATHS[cpanel_bin]}" ]]; then
            cpanel_info+="|binarios:${PANEL_PATHS[cpanel_bin]}"
        fi
        
        # Verificar WHM
        if [[ -d "${PANEL_PATHS[cpanel_whm]}" ]]; then
            cpanel_info+="|whm:activo"
        fi
        
        return 0
    fi
    
    # Verificar procesos
    if pgrep -f "${PANEL_PROCESSES[cpanel]}" >/dev/null 2>&1; then
        cpanel_info="cPanel (detectado por proceso)"
        return 0
    fi
    
    # Verificar puertos
    if command -v netstat >/dev/null 2>&1; then
        if netstat -tuln 2>/dev/null | grep -E ":2082|:2083|:2086|:2087" >/dev/null; then
            cpanel_info="cPanel (detectado por puertos)"
            return 0
        fi
    fi
    
    if [[ -n "$cpanel_info" ]]; then
        DETECTED_PANELS["cpanel"]="$cpanel_info"
        return 0
    fi
    
    return 1
}

##
# Detecta Plesk
# @return 0 si se detecta Plesk
##
detect_plesk() {
    local plesk_info=""
    
    # Verificar archivo de versión
    if [[ -f "${PANEL_PATHS[plesk]}" ]]; then
        local version
        version=$(cat "${PANEL_PATHS[plesk]}" 2>/dev/null | head -1)
        plesk_info="Plesk $version"
        
        # Verificar binarios
        if [[ -d "${PANEL_PATHS[plesk_bin]}" ]]; then
            plesk_info+="|binarios:${PANEL_PATHS[plesk_bin]}"
        fi
        
        return 0
    fi
    
    # Verificar comando plesk
    if command -v plesk >/dev/null 2>&1; then
        local version
        version=$(plesk version 2>/dev/null | head -1)
        plesk_info="Plesk $version"
        return 0
    fi
    
    # Verificar procesos
    if pgrep -f "${PANEL_PROCESSES[plesk]}" >/dev/null 2>&1; then
        plesk_info="Plesk (detectado por proceso)"
        return 0
    fi
    
    # Verificar puertos
    if command -v netstat >/dev/null 2>&1; then
        if netstat -tuln 2>/dev/null | grep -E ":8443|:8880" >/dev/null; then
            plesk_info="Plesk (detectado por puertos)"
            return 0
        fi
    fi
    
    if [[ -n "$plesk_info" ]]; then
        DETECTED_PANELS["plesk"]="$plesk_info"
        return 0
    fi
    
    return 1
}

##
# Detecta DirectAdmin
# @return 0 si se detecta DirectAdmin
##
detect_directadmin() {
    local da_info=""
    
    # Verificar archivo de configuración
    if [[ -f "${PANEL_PATHS[directadmin]}" ]]; then
        da_info="DirectAdmin"
        
        # Extraer versión del config
        if grep -q "version=" "${PANEL_PATHS[directadmin]}" 2>/dev/null; then
            local version
            version=$(grep "version=" "${PANEL_PATHS[directadmin]}" | cut -d'=' -f2)
            da_info="DirectAdmin $version"
        fi
        
        return 0
    fi
    
    # Verificar binario
    if [[ -f "${PANEL_PATHS[directadmin_bin]}" ]]; then
        da_info="DirectAdmin (binario encontrado)"
        return 0
    fi
    
    # Verificar proceso
    if pgrep -f "${PANEL_PROCESSES[directadmin]}" >/dev/null 2>&1; then
        da_info="DirectAdmin (detectado por proceso)"
        return 0
    fi
    
    # Verificar puerto
    if command -v netstat >/dev/null 2>&1; then
        if netstat -tuln 2>/dev/null | grep ":2222" >/dev/null; then
            da_info="DirectAdmin (detectado por puerto)"
            return 0
        fi
    fi
    
    if [[ -n "$da_info" ]]; then
        DETECTED_PANELS["directadmin"]="$da_info"
        return 0
    fi
    
    return 1
}

##
# Detecta VestaCP
# @return 0 si se detecta VestaCP
##
detect_vestacp() {
    local vesta_info=""
    
    # Verificar archivo de configuración
    if [[ -f "${PANEL_PATHS[vestacp]}" ]]; then
        vesta_info="VestaCP"
        
        # Verificar binarios
        if [[ -d "${PANEL_PATHS[vestacp_bin]}" ]]; then
            vesta_info+="|binarios:${PANEL_PATHS[vestacp_bin]}"
        fi
        
        return 0
    fi
    
    # Verificar comando vesta
    if command -v v-list-sys-info >/dev/null 2>&1; then
        vesta_info="VestaCP (comando encontrado)"
        return 0
    fi
    
    # Verificar procesos
    if pgrep -f "${PANEL_PROCESSES[vestacp]}" >/dev/null 2>&1; then
        vesta_info="VestaCP (detectado por proceso)"
        return 0
    fi
    
    if [[ -n "$vesta_info" ]]; then
        DETECTED_PANELS["vestacp"]="$vesta_info"
        return 0
    fi
    
    return 1
}

##
# Detecta HestiaCP
# @return 0 si se detecta HestiaCP
##
detect_hestiacp() {
    local hestia_info=""
    
    # Verificar archivo de configuración
    if [[ -f "${PANEL_PATHS[hestiacp]}" ]]; then
        hestia_info="HestiaCP"
        
        # Verificar binarios
        if [[ -d "${PANEL_PATHS[hestiacp_bin]}" ]]; then
            hestia_info+="|binarios:${PANEL_PATHS[hestiacp_bin]}"
        fi
        
        return 0
    fi
    
    # Verificar comando hestia
    if command -v v-list-sys-info >/dev/null 2>&1 && [[ -d "/usr/local/hestia" ]]; then
        hestia_info="HestiaCP (comando encontrado)"
        return 0
    fi
    
    # Verificar procesos
    if pgrep -f "${PANEL_PROCESSES[hestiacp]}" >/dev/null 2>&1; then
        hestia_info="HestiaCP (detectado por proceso)"
        return 0
    fi
    
    if [[ -n "$hestia_info" ]]; then
        DETECTED_PANELS["hestiacp"]="$hestia_info"
        return 0
    fi
    
    return 1
}

##
# Detecta ISPConfig
# @return 0 si se detecta ISPConfig
##
detect_ispconfig() {
    local ispconfig_info=""
    
    # Verificar archivos de configuración
    if [[ -f "${PANEL_PATHS[ispconfig]}" ]] || [[ -f "${PANEL_PATHS[ispconfig_server]}" ]]; then
        ispconfig_info="ISPConfig"
        return 0
    fi
    
    # Verificar procesos
    if pgrep -f "${PANEL_PROCESSES[ispconfig]}" >/dev/null 2>&1; then
        ispconfig_info="ISPConfig (detectado por proceso)"
        return 0
    fi
    
    # Verificar puerto
    if command -v netstat >/dev/null 2>&1; then
        if netstat -tuln 2>/dev/null | grep ":8080" >/dev/null; then
            ispconfig_info="ISPConfig (detectado por puerto)"
            return 0
        fi
    fi
    
    if [[ -n "$ispconfig_info" ]]; then
        DETECTED_PANELS["ispconfig"]="$ispconfig_info"
        return 0
    fi
    
    return 1
}

##
# Detecta CyberPanel
# @return 0 si se detecta CyberPanel
##
detect_cyberpanel() {
    local cyber_info=""
    
    # Verificar archivo de configuración
    if [[ -f "${PANEL_PATHS[cyberpanel]}" ]]; then
        cyber_info="CyberPanel"
        return 0
    fi
    
    # Verificar OpenLiteSpeed (usado por CyberPanel)
    if [[ -f "${PANEL_PATHS[cyberpanel_bin]}" ]]; then
        cyber_info="CyberPanel (OpenLiteSpeed encontrado)"
        return 0
    fi
    
    # Verificar procesos
    if pgrep -f "${PANEL_PROCESSES[cyberpanel]}" >/dev/null 2>&1; then
        cyber_info="CyberPanel (detectado por proceso)"
        return 0
    fi
    
    if [[ -n "$cyber_info" ]]; then
        DETECTED_PANELS["cyberpanel"]="$cyber_info"
        return 0
    fi
    
    return 1
}

##
# Detecta Docker
# @return 0 si se detecta Docker
##
detect_docker() {
    local docker_info=""
    
    # Verificar si estamos en contenedor
    if [[ -f "/.dockerenv" ]] || grep -q "docker\|lxc" /proc/1/cgroup 2>/dev/null; then
        docker_info="Docker Container"
        
        # Verificar tipo de imagen si es posible
        if [[ -n "${DOCKER_IMAGE:-}" ]]; then
            docker_info+="|imagen:$DOCKER_IMAGE"
        fi
        
        DETECTED_PANELS["docker"]="$docker_info"
        return 0
    fi
    
    # Verificar Docker daemon
    if command -v docker >/dev/null 2>&1; then
        if docker info >/dev/null 2>&1; then
            docker_info="Docker Host"
            DETECTED_PANELS["docker"]="$docker_info"
            return 0
        fi
    fi
    
    return 1
}

##
# Detecta Apache HTTP Server (instalación manual)
# @return 0 si se detecta Apache
##
detect_apache_manual() {
    local apache_info=""
    local config_file=""
    local binary=""
    
    # Buscar archivos de configuración principales
    local config_paths=(
        "${WEBSERVER_PATHS[apache_config]}"
        "${WEBSERVER_PATHS[apache_config_centos]}"
        "${WEBSERVER_PATHS[apache_config_freebsd]}"
    )
    
    for config in "${config_paths[@]}"; do
        if [[ -f "$config" ]]; then
            config_file="$config"
            break
        fi
    done
    
    # Buscar binarios
    local binary_paths=(
        "${WEBSERVER_PATHS[apache_bin]}"
        "${WEBSERVER_PATHS[apache_bin_centos]}"
    )
    
    for bin in "${binary_paths[@]}"; do
        if [[ -f "$bin" ]]; then
            binary="$bin"
            break
        fi
    done
    
    # Verificar comando apache/httpd
    if command -v apache2 >/dev/null 2>&1; then
        local version
        version=$(apache2 -v 2>/dev/null | head -1 | grep -o "Apache/[0-9.]*")
        apache_info="Apache Manual ($version)"
        binary="$(command -v apache2)"
    elif command -v httpd >/dev/null 2>&1; then
        local version
        version=$(httpd -v 2>/dev/null | head -1 | grep -o "Apache/[0-9.]*")
        apache_info="Apache Manual ($version)"
        binary="$(command -v httpd)"
    fi
    
    # Si encontramos configuración o binario
    if [[ -n "$config_file" ]] || [[ -n "$binary" ]]; then
        if [[ -z "$apache_info" ]]; then
            apache_info="Apache Manual"
        fi
        
        if [[ -n "$config_file" ]]; then
            apache_info+="|config:$config_file"
        fi
        
        if [[ -n "$binary" ]]; then
            apache_info+="|binary:$binary"
        fi
        
        # Verificar directorio de sitios
        local sites_dir=""
        if [[ -d "${WEBSERVER_PATHS[apache_sites]}" ]]; then
            sites_dir="${WEBSERVER_PATHS[apache_sites]}"
        elif [[ -d "${WEBSERVER_PATHS[apache_sites_centos]}" ]]; then
            sites_dir="${WEBSERVER_PATHS[apache_sites_centos]}"
        fi
        
        if [[ -n "$sites_dir" ]]; then
            local site_count
            site_count=$(find "$sites_dir" -name "*.conf" -o -name "*.vhost" 2>/dev/null | wc -l)
            apache_info+="|sites:$site_count"
        fi
        
        DETECTED_PANELS["apache_manual"]="$apache_info"
        return 0
    fi
    
    # Verificar procesos
    if pgrep -f "${WEBSERVER_PROCESSES[apache]}" >/dev/null 2>&1; then
        apache_info="Apache Manual (detectado por proceso)"
        DETECTED_PANELS["apache_manual"]="$apache_info"
        return 0
    fi
    
    # Verificar puertos típicos (solo si no hay otros paneles)
    if [[ ${#DETECTED_PANELS[@]} -eq 0 ]] && command -v netstat >/dev/null 2>&1; then
        if netstat -tuln 2>/dev/null | grep -E ":80.*LISTEN|:443.*LISTEN" >/dev/null; then
            apache_info="Apache Manual (detectado por puertos)"
            DETECTED_PANELS["apache_manual"]="$apache_info"
            return 0
        fi
    fi
    
    return 1
}

##
# Detecta Nginx (instalación manual)
# @return 0 si se detecta Nginx
##
detect_nginx_manual() {
    local nginx_info=""
    local config_file=""
    local binary=""
    
    # Buscar archivo de configuración principal
    if [[ -f "${WEBSERVER_PATHS[nginx_config]}" ]]; then
        config_file="${WEBSERVER_PATHS[nginx_config]}"
    fi
    
    # Buscar binarios
    local binary_paths=(
        "${WEBSERVER_PATHS[nginx_bin]}"
        "${WEBSERVER_PATHS[nginx_bin_alt]}"
    )
    
    for bin in "${binary_paths[@]}"; do
        if [[ -f "$bin" ]]; then
            binary="$bin"
            break
        fi
    done
    
    # Verificar comando nginx
    if command -v nginx >/dev/null 2>&1; then
        local version
        version=$(nginx -v 2>&1 | grep -o "nginx/[0-9.]*")
        nginx_info="Nginx Manual ($version)"
        binary="$(command -v nginx)"
    fi
    
    # Si encontramos configuración o binario
    if [[ -n "$config_file" ]] || [[ -n "$binary" ]]; then
        if [[ -z "$nginx_info" ]]; then
            nginx_info="Nginx Manual"
        fi
        
        if [[ -n "$config_file" ]]; then
            nginx_info+="|config:$config_file"
        fi
        
        if [[ -n "$binary" ]]; then
            nginx_info+="|binary:$binary"
        fi
        
        # Verificar directorios de sitios
        local sites_count=0
        if [[ -d "${WEBSERVER_PATHS[nginx_sites]}" ]]; then
            sites_count=$(find "${WEBSERVER_PATHS[nginx_sites]}" -name "*.conf" 2>/dev/null | wc -l)
            nginx_info+="|sites-available:$sites_count"
        fi
        
        if [[ -d "${WEBSERVER_PATHS[nginx_conf_d]}" ]]; then
            local conf_d_count
            conf_d_count=$(find "${WEBSERVER_PATHS[nginx_conf_d]}" -name "*.conf" 2>/dev/null | wc -l)
            nginx_info+="|conf.d:$conf_d_count"
        fi
        
        DETECTED_PANELS["nginx_manual"]="$nginx_info"
        return 0
    fi
    
    # Verificar procesos
    if pgrep -f "${WEBSERVER_PROCESSES[nginx]}" >/dev/null 2>&1; then
        nginx_info="Nginx Manual (detectado por proceso)"
        DETECTED_PANELS["nginx_manual"]="$nginx_info"
        return 0
    fi
    
    # Verificar puertos típicos (solo si no hay otros paneles)
    if [[ ${#DETECTED_PANELS[@]} -eq 0 ]] && command -v netstat >/dev/null 2>&1; then
        if netstat -tuln 2>/dev/null | grep -E ":80.*LISTEN|:443.*LISTEN" >/dev/null; then
            nginx_info="Nginx Manual (detectado por puertos)"
            DETECTED_PANELS["nginx_manual"]="$nginx_info"
            return 0
        fi
    fi
    
    return 1
}

##
# Detecta OpenLiteSpeed (instalación manual)
# @return 0 si se detecta OpenLiteSpeed
##
detect_openlitespeed_manual() {
    local ols_info=""
    local config_file=""
    local admin_config=""
    local binary=""
    
    # Buscar archivos de configuración
    if [[ -f "${WEBSERVER_PATHS[openlitespeed_config]}" ]]; then
        config_file="${WEBSERVER_PATHS[openlitespeed_config]}"
    fi
    
    if [[ -f "${WEBSERVER_PATHS[openlitespeed_admin]}" ]]; then
        admin_config="${WEBSERVER_PATHS[openlitespeed_admin]}"
    fi
    
    # Buscar binario
    if [[ -f "${WEBSERVER_PATHS[openlitespeed_bin]}" ]]; then
        binary="${WEBSERVER_PATHS[openlitespeed_bin]}"
    fi
    
    # Verificar comando openlitespeed
    if command -v openlitespeed >/dev/null 2>&1; then
        ols_info="OpenLiteSpeed Manual"
        binary="$(command -v openlitespeed)"
    elif command -v lshttpd >/dev/null 2>&1; then
        local version
        version=$(lshttpd -v 2>/dev/null | grep -o "LiteSpeed.*" | head -1)
        ols_info="OpenLiteSpeed Manual ($version)"
        binary="$(command -v lshttpd)"
    fi
    
    # Si encontramos configuración o binario
    if [[ -n "$config_file" ]] || [[ -n "$admin_config" ]] || [[ -n "$binary" ]]; then
        if [[ -z "$ols_info" ]]; then
            ols_info="OpenLiteSpeed Manual"
        fi
        
        if [[ -n "$config_file" ]]; then
            ols_info+="|config:$config_file"
        fi
        
        if [[ -n "$admin_config" ]]; then
            ols_info+="|admin:$admin_config"
        fi
        
        if [[ -n "$binary" ]]; then
            ols_info+="|binary:$binary"
        fi
        
        # Verificar virtual hosts
        if [[ -d "${WEBSERVER_PATHS[openlitespeed_vhosts]}" ]]; then
            local vhost_count
            vhost_count=$(find "${WEBSERVER_PATHS[openlitespeed_vhosts]}" -type d 2>/dev/null | wc -l)
            if [[ $vhost_count -gt 1 ]]; then  # Excluir el directorio padre
                ols_info+="|vhosts:$((vhost_count-1))"
            fi
        fi
        
        DETECTED_PANELS["openlitespeed_manual"]="$ols_info"
        return 0
    fi
    
    # Verificar procesos (pero no si ya se detectó como CyberPanel)
    if [[ -z "${DETECTED_PANELS[cyberpanel]:-}" ]] && pgrep -f "${WEBSERVER_PROCESSES[openlitespeed]}" >/dev/null 2>&1; then
        ols_info="OpenLiteSpeed Manual (detectado por proceso)"
        DETECTED_PANELS["openlitespeed_manual"]="$ols_info"
        return 0
    fi
    
    # Verificar puertos administrativos específicos de OLS (solo si no hay otros paneles)
    if [[ ${#DETECTED_PANELS[@]} -eq 0 ]] && command -v netstat >/dev/null 2>&1; then
        if netstat -tuln 2>/dev/null | grep -E ":7080.*LISTEN|:8088.*LISTEN" >/dev/null; then
            ols_info="OpenLiteSpeed Manual (detectado por puertos admin)"
            DETECTED_PANELS["openlitespeed_manual"]="$ols_info"
            return 0
        fi
    fi
    
    return 1
}
# ===================== FUNCIÓN PRINCIPAL DE DETECCIÓN =====================

##
# Función principal para detectar paneles de control
# @return 0 si se detecta al menos un panel
##
detect_panels() {
    if [[ "$PANEL_DETECTION_STARTED" == "true" ]]; then
        log_debug "Detección de paneles ya ejecutada"
        return 0
    fi
    
    PANEL_DETECTION_STARTED=true
    
    log_info "Iniciando detección de paneles de control..."
    
    local panel_functions=(
        "detect_cpanel"
        "detect_plesk"
        "detect_directadmin"
        "detect_vestacp"
        "detect_hestiacp"
        "detect_ispconfig"
        "detect_cyberpanel"
        "detect_docker"
        "detect_apache_manual"
        "detect_nginx_manual"
        "detect_openlitespeed_manual"
    )
    
    local detected_count=0
    
    for func in "${panel_functions[@]}"; do
        log_debug "Ejecutando: $func"
        if "$func"; then
            ((detected_count++))
            log_debug "✓ Panel detectado por: $func"
        fi
    done
    
    if [[ $detected_count -gt 0 ]]; then
        log_success "Detectados $detected_count panel(es) de control"
        
        # Mostrar resultados
        for panel in "${!DETECTED_PANELS[@]}"; do
            log_info "Panel detectado: $panel - ${DETECTED_PANELS[$panel]}"
        done
        
        # Retornar lista de paneles detectados
        printf '%s\n' "${!DETECTED_PANELS[@]}"
        return 0
    else
        log_warning "No se detectaron paneles de control (instalación manual)"
        echo "manual"
        return 0  # No es error, solo instalación manual
    fi
}

##
# Obtiene información detallada de un panel específico
# @param $1 - Nombre del panel
##
get_panel_info() {
    local panel_name="$1"
    
    if [[ -n "${DETECTED_PANELS[$panel_name]:-}" ]]; then
        echo "${DETECTED_PANELS[$panel_name]}"
        return 0
    fi
    
    return 1
}

##
# Obtiene el primer panel detectado (por prioridad)
##
get_primary_panel() {
    local priority_order=("cpanel" "plesk" "directadmin" "hestiacp" "vestacp" "ispconfig" "cyberpanel" "nginx_manual" "apache_manual" "openlitespeed_manual" "docker")
    
    for panel in "${priority_order[@]}"; do
        if [[ -n "${DETECTED_PANELS[$panel]:-}" ]]; then
            echo "$panel"
            return 0
        fi
    done
    
    echo "manual"
    return 0
}

##
# Verifica si hay conflictos entre paneles
##
check_panel_conflicts() {
    if [[ ${#DETECTED_PANELS[@]} -gt 1 ]]; then
        log_warning "Múltiples paneles detectados: ${!DETECTED_PANELS[*]}"
        log_warning "Esto puede indicar una migración incompleta o conflicto"
        return 1
    fi
    
    return 0
}

# ===================== LIMPIEZA =====================

##
# Limpia el estado de detección de paneles
##
panels_cleanup() {
    PANEL_DETECTION_STARTED=false
    DETECTED_PANELS=()
    
    log_debug "Estado de detección de paneles limpiado"
}

# ===================== MODO SCRIPT INDEPENDIENTE =====================

# Si se ejecuta directamente (no como source)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    detect_panels
fi
