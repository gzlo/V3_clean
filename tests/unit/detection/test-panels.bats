#!/usr/bin/env bats

##
# Tests para el Detector de Paneles de Control
# 
# Pruebas unitarias para detección automática de paneles
##

# Setup y teardown
setup() {
    # Cargar helpers de testing
    load '../../helpers/test_helper'
    load '../../helpers/config_test_helper.bash'
    
    # Configurar entorno de test
    export MOODLE_CLI_TEST_MODE="true"
    export TEST_TEMP_DIR="$(mktemp -d)"
    
    # Crear estructura de directorios simulados
    mkdir -p "$TEST_TEMP_DIR/mock_system"
    
    # Cargar módulo bajo test
    source "$PROJECT_ROOT/src/detection/panels.sh"
}

teardown() {
    # Limpiar estado
    panels_cleanup
    
    # Limpiar archivos temporales
    [[ -d "$TEST_TEMP_DIR" ]] && rm -rf "$TEST_TEMP_DIR"
}

# ===================== TESTS DE INICIALIZACIÓN =====================

@test "detector de paneles se carga correctamente" {
    run echo "$MOODLE_PANELS_DETECTOR_LOADED"
    assert_output "true"
}

@test "variables de configuración están definidas" {
    # Verificar que las rutas de paneles están definidas
    assert [[ -n "${PANEL_PATHS[cpanel]:-}" ]]
    assert [[ -n "${PANEL_PATHS[plesk]:-}" ]]
    assert [[ -n "${PANEL_PATHS[directadmin]:-}" ]]
    
    # Verificar que las rutas de servidores web están definidas
    assert [[ -n "${WEBSERVER_PATHS[apache_config]:-}" ]]
    assert [[ -n "${WEBSERVER_PATHS[nginx_config]:-}" ]]
    assert [[ -n "${WEBSERVER_PATHS[openlitespeed_config]:-}" ]]
}

# ===================== TESTS DE DETECCIÓN CPANEL =====================

@test "detect_cpanel detecta instalación por archivo de versión" {
    # Crear archivo de versión simulado
    local cpanel_version_file="$TEST_TEMP_DIR/mock_system/cpanel_version"
    mkdir -p "$(dirname "$cpanel_version_file")"
    echo "11.92.0.5" > "$cpanel_version_file"
    
    # Sobrescribir ruta para test
    PANEL_PATHS[cpanel]="$cpanel_version_file"
    
    run detect_cpanel
    assert_success
    
    # Verificar que se detectó
    assert [[ -n "${DETECTED_PANELS[cpanel]:-}" ]]
    assert [[ "${DETECTED_PANELS[cpanel]}" == *"cPanel 11.92.0.5"* ]]
}

@test "detect_cpanel detecta por directorio de binarios" {
    # Crear directorio de binarios simulado
    local cpanel_bin_dir="$TEST_TEMP_DIR/mock_system/cpanel_bin"
    mkdir -p "$cpanel_bin_dir"
    
    # Sobrescribir rutas para test
    PANEL_PATHS[cpanel]="/nonexistent"  # No hay archivo de versión
    PANEL_PATHS[cpanel_bin]="$cpanel_bin_dir"
    
    # Crear función mock para pgrep
    pgrep() {
        if [[ "$*" == *"cpanel"* ]]; then
            echo "1234"
            return 0
        fi
        return 1
    }
    export -f pgrep
    
    run detect_cpanel
    assert_success
    
    assert [[ "${DETECTED_PANELS[cpanel]}" == *"cPanel (detectado por proceso)"* ]]
}

@test "detect_cpanel no detecta cuando no hay evidencia" {
    # Limpiar detecciones previas
    unset DETECTED_PANELS[cpanel]
    
    # Sobrescribir rutas a ubicaciones inexistentes
    PANEL_PATHS[cpanel]="/nonexistent/version"
    PANEL_PATHS[cpanel_bin]="/nonexistent/bin"
    
    # Mock pgrep para no encontrar procesos
    pgrep() { return 1; }
    export -f pgrep
    
    # Mock netstat para no encontrar puertos
    netstat() { echo ""; }
    export -f netstat
    
    run detect_cpanel
    assert_failure
}

# ===================== TESTS DE DETECCIÓN PLESK =====================

@test "detect_plesk detecta instalación por archivo de versión" {
    # Crear archivo de versión simulado
    local plesk_version_file="$TEST_TEMP_DIR/mock_system/plesk_version"
    mkdir -p "$(dirname "$plesk_version_file")"
    echo "Plesk 18.0.35" > "$plesk_version_file"
    
    PANEL_PATHS[plesk]="$plesk_version_file"
    
    run detect_plesk
    assert_success
    
    assert [[ "${DETECTED_PANELS[plesk]}" == *"Plesk 18.0.35"* ]]
}

@test "detect_plesk detecta por comando plesk" {
    # Sobrescribir ruta a archivo inexistente
    PANEL_PATHS[plesk]="/nonexistent"
    
    # Crear comando plesk simulado
    plesk() {
        if [[ "$1" == "version" ]]; then
            echo "Product version: Plesk Obsidian 18.0.35"
            return 0
        fi
        return 1
    }
    export -f plesk
    
    # Mock command para indicar que plesk existe
    command() {
        if [[ "$1" == "-v" && "$2" == "plesk" ]]; then
            return 0
        fi
        return 1
    }
    export -f command
    
    run detect_plesk
    assert_success
    
    assert [[ "${DETECTED_PANELS[plesk]}" == *"Plesk"* ]]
}

# ===================== TESTS DE DETECCIÓN DIRECTADMIN =====================

@test "detect_directadmin detecta por archivo de configuración" {
    local da_config_file="$TEST_TEMP_DIR/mock_system/directadmin.conf"
    mkdir -p "$(dirname "$da_config_file")"
    echo "version=1.60.8" > "$da_config_file"
    echo "admin_user=admin" >> "$da_config_file"
    
    PANEL_PATHS[directadmin]="$da_config_file"
    
    run detect_directadmin
    assert_success
    
    assert [[ "${DETECTED_PANELS[directadmin]}" == *"DirectAdmin 1.60.8"* ]]
}

@test "detect_directadmin detecta por binario" {
    # Crear binario simulado
    local da_binary="$TEST_TEMP_DIR/mock_system/directadmin"
    mkdir -p "$(dirname "$da_binary")"
    touch "$da_binary"
    chmod +x "$da_binary"
    
    PANEL_PATHS[directadmin]="/nonexistent"  # No config
    PANEL_PATHS[directadmin_bin]="$da_binary"
    
    run detect_directadmin
    assert_success
    
    assert [[ "${DETECTED_PANELS[directadmin]}" == *"DirectAdmin (binario encontrado)"* ]]
}

# ===================== TESTS DE DETECCIÓN VESTACP =====================

@test "detect_vestacp detecta por archivo de configuración" {
    local vesta_config="$TEST_TEMP_DIR/mock_system/vesta.conf"
    mkdir -p "$(dirname "$vesta_config")"
    echo "VESTA='1.0'" > "$vesta_config"
    
    PANEL_PATHS[vestacp]="$vesta_config"
    
    run detect_vestacp
    assert_success
    
    assert [[ "${DETECTED_PANELS[vestacp]}" == *"VestaCP"* ]]
}

@test "detect_vestacp detecta por comando" {
    PANEL_PATHS[vestacp]="/nonexistent"
    
    # Mock comando vesta
    v-list-sys-info() {
        echo "VestaCP System Information"
        return 0
    }
    export -f v-list-sys-info
    
    command() {
        if [[ "$1" == "-v" && "$2" == "v-list-sys-info" ]]; then
            return 0
        fi
        return 1
    }
    export -f command
    
    run detect_vestacp
    assert_success
    
    assert [[ "${DETECTED_PANELS[vestacp]}" == *"VestaCP (comando encontrado)"* ]]
}

# ===================== TESTS DE DETECCIÓN HESTIACP =====================

@test "detect_hestiacp detecta por archivo de configuración" {
    local hestia_config="$TEST_TEMP_DIR/mock_system/hestia.conf"
    mkdir -p "$(dirname "$hestia_config")"
    echo "HESTIA='1.0'" > "$hestia_config"
    
    PANEL_PATHS[hestiacp]="$hestia_config"
    
    run detect_hestiacp
    assert_success
    
    assert [[ "${DETECTED_PANELS[hestiacp]}" == *"HestiaCP"* ]]
}

# ===================== TESTS DE DETECCIÓN DOCKER =====================

@test "detect_docker detecta contenedor por .dockerenv" {
    # Crear archivo .dockerenv simulado
    touch "$TEST_TEMP_DIR/.dockerenv"
    
    # Cambiar directorio de trabajo temporalmente
    local original_pwd="$PWD"
    cd "$TEST_TEMP_DIR"
    
    run detect_docker
    cd "$original_pwd"
    
    assert_success
    assert [[ "${DETECTED_PANELS[docker]}" == *"Docker Container"* ]]
}

@test "detect_docker detecta por cgroup" {
    # Crear archivo cgroup simulado
    local cgroup_file="$TEST_TEMP_DIR/mock_cgroup"
    echo "1:name=systemd:/docker/abc123" > "$cgroup_file"
    
    # Mock /proc/1/cgroup
    grep() {
        if [[ "$*" == *"/proc/1/cgroup"* ]]; then
            cat "$cgroup_file"
            return 0
        fi
        return 1
    }
    export -f grep
    
    run detect_docker
    assert_success
    
    assert [[ "${DETECTED_PANELS[docker]}" == *"Docker Container"* ]]
}

@test "detect_docker detecta Docker daemon" {
    # Mock comando docker
    docker() {
        if [[ "$1" == "info" ]]; then
            echo "Server Version: 20.10.8"
            return 0
        fi
        return 1
    }
    export -f docker
    
    command() {
        if [[ "$1" == "-v" && "$2" == "docker" ]]; then
            return 0
        fi
        return 1
    }
    export -f command
    
    run detect_docker
    assert_success
    
    assert [[ "${DETECTED_PANELS[docker]}" == *"Docker Host"* ]]
}

# ===================== TESTS DE FUNCIÓN PRINCIPAL =====================

@test "detect_panels ejecuta todas las detecciones" {
    # Mock todas las funciones de detección para retornar éxito
    detect_cpanel() { 
        DETECTED_PANELS[cpanel]="cPanel mock"
        return 0
    }
    detect_plesk() { return 1; }  # No detectado
    detect_directadmin() { return 1; }
    detect_vestacp() { return 1; }
    detect_hestiacp() { return 1; }
    detect_ispconfig() { return 1; }
    detect_cyberpanel() { return 1; }
    detect_docker() { return 1; }
    
    export -f detect_cpanel detect_plesk detect_directadmin
    export -f detect_vestacp detect_hestiacp detect_ispconfig
    export -f detect_cyberpanel detect_docker
    
    run detect_panels
    assert_success
    
    # Debe retornar el panel detectado
    assert_output --partial "cpanel"
}

@test "detect_panels retorna manual cuando no hay paneles" {
    # Mock todas las funciones para fallar
    for func in detect_cpanel detect_plesk detect_directadmin detect_vestacp detect_hestiacp detect_ispconfig detect_cyberpanel detect_docker; do
        eval "$func() { return 1; }"
        export -f $func
    done
    
    run detect_panels
    assert_success
    assert_output "manual"
}

@test "detect_panels no se ejecuta múltiples veces" {
    # Primera ejecución
    export PANEL_DETECTION_STARTED=false
    
    # Mock función que cuenta ejecuciones
    local execution_count=0
    detect_cpanel() { 
        ((execution_count++))
        return 1
    }
    export -f detect_cpanel
    export execution_count
    
    # Primera llamada
    run detect_panels
    assert_success
    
    # Segunda llamada no debe ejecutar las funciones de nuevo
    run detect_panels
    assert_success
    
    # execution_count debería ser 1, no 2
    assert [ "$execution_count" -eq 1 ]
}

# ===================== TESTS DE FUNCIONES AUXILIARES =====================

@test "get_panel_info retorna información del panel" {
    DETECTED_PANELS[test_panel]="Test Panel Info"
    
    run get_panel_info "test_panel"
    assert_success
    assert_output "Test Panel Info"
}

@test "get_panel_info falla para panel inexistente" {
    run get_panel_info "nonexistent_panel"
    assert_failure
}

@test "get_primary_panel retorna el primer panel por prioridad" {
    # Simular múltiples paneles detectados
    DETECTED_PANELS[plesk]="Plesk detected"
    DETECTED_PANELS[cpanel]="cPanel detected"
    DETECTED_PANELS[docker]="Docker detected"
    
    run get_primary_panel
    assert_success
    # cPanel tiene prioridad sobre Plesk
    assert_output "cpanel"
}

@test "get_primary_panel retorna manual cuando no hay paneles" {
    # Limpiar paneles detectados
    unset DETECTED_PANELS
    declare -A DETECTED_PANELS=()
    
    run get_primary_panel
    assert_success
    assert_output "manual"
}

@test "check_panel_conflicts detecta múltiples paneles" {
    DETECTED_PANELS[cpanel]="cPanel"
    DETECTED_PANELS[plesk]="Plesk"
    
    run check_panel_conflicts
    assert_failure  # Debe retornar error por conflicto
}

@test "check_panel_conflicts pasa con un solo panel" {
    DETECTED_PANELS[cpanel]="cPanel only"
    
    run check_panel_conflicts
    assert_success
}

# ===================== TESTS DE EDGE CASES =====================

@test "detección funciona con permisos limitados" {
    # Simular falta de permisos para archivos
    local restricted_file="$TEST_TEMP_DIR/restricted"
    touch "$restricted_file"
    chmod 000 "$restricted_file"
    
    PANEL_PATHS[cpanel]="$restricted_file"
    
    # No debe fallar completamente, solo no detectar
    run detect_cpanel
    assert_failure
}

@test "detección maneja comandos inexistentes" {
    # Mock command para indicar que comandos no existen
    command() { return 1; }
    export -f command
    
    run detect_plesk
    assert_failure
}

@test "panels_cleanup resetea estado correctamente" {
    # Configurar estado inicial
    PANEL_DETECTION_STARTED=true
    DETECTED_PANELS[test]="test_value"
    
    run panels_cleanup
    assert_success
    
    # Verificar limpieza
    assert [ "$PANEL_DETECTION_STARTED" = "false" ]
    assert [ ${#DETECTED_PANELS[@]} -eq 0 ]
}

# ===================== TESTS DE TIMEOUT Y ROBUSTEZ =====================

@test "detección maneja timeouts en comandos externos" {
    # Mock netstat que demora mucho
    netstat() {
        sleep 2  # Simular comando lento
        echo ":2082"
    }
    export -f netstat
    
    # Mock timeout command
    timeout() {
        local time_limit="$1"
        shift
        # Si el tiempo es muy corto, fallar
        if [[ "$time_limit" == "1" ]]; then
            return 124  # Timeout exit code
        fi
        "$@"
    }
    export -f timeout
    
    # La detección debe manejar el timeout graciosamente
    run detect_cpanel
    # No debe fallar completamente
    assert [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "detección funciona sin herramientas de red" {
    # Mock para indicar que netstat no existe
    command() {
        if [[ "$1" == "-v" && "$2" == "netstat" ]]; then
            return 1
        fi
        return 0
    }
    export -f command
    
    run detect_cpanel
    # Debe poder ejecutarse sin netstat
    assert [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

# ===================== TESTS DE DETECCIÓN APACHE MANUAL =====================

@test "detect_apache_manual detecta Apache por archivo de configuración" {
    # Crear archivo de configuración de Apache
    mkdir -p "$TEST_TEMP_DIR/etc/apache2"
    echo "ServerRoot /etc/apache2" > "$TEST_TEMP_DIR/etc/apache2/apache2.conf"
    
    # Mock para simular el archivo existe
    WEBSERVER_PATHS["apache_config"]="$TEST_TEMP_DIR/etc/apache2/apache2.conf"
    
    run detect_apache_manual
    assert_success
    assert [[ -n "${DETECTED_PANELS[apache_manual]:-}" ]]
}

@test "detect_apache_manual detecta Apache por comando apache2" {
    # Mock del comando apache2
    apache2() {
        echo "Server version: Apache/2.4.41 (Ubuntu)"
        echo "Server built:   2021-01-01T00:00:00"
    }
    export -f apache2
    
    # Mock command para indicar que apache2 existe
    command() {
        if [[ "$1" == "-v" && "$2" == "apache2" ]]; then
            return 0
        fi
        return 1
    }
    export -f command
    
    run detect_apache_manual
    assert_success
    assert [[ "${DETECTED_PANELS[apache_manual]}" =~ "Apache/2.4.41" ]]
}

@test "detect_apache_manual detecta Apache por comando httpd" {
    # Mock del comando httpd
    httpd() {
        echo "Server version: Apache/2.4.6 (CentOS)"
        echo "Server built:   2021-01-01T00:00:00"
    }
    export -f httpd
    
    # Mock command para apache2 no existe pero httpd sí
    command() {
        if [[ "$1" == "-v" && "$2" == "apache2" ]]; then
            return 1
        elif [[ "$1" == "-v" && "$2" == "httpd" ]]; then
            return 0
        fi
        return 1
    }
    export -f command
    
    run detect_apache_manual
    assert_success
    assert [[ "${DETECTED_PANELS[apache_manual]}" =~ "Apache/2.4.6" ]]
}

@test "detect_apache_manual detecta Apache por proceso" {
    # Mock pgrep para simular proceso Apache
    pgrep() {
        if [[ "$1" == "-f" && "$2" =~ apache2 ]]; then
            echo "1234"
            return 0
        fi
        return 1
    }
    export -f pgrep
    
    run detect_apache_manual
    assert_success
    assert [[ "${DETECTED_PANELS[apache_manual]}" =~ "detectado por proceso" ]]
}

# ===================== TESTS DE DETECCIÓN NGINX MANUAL =====================

@test "detect_nginx_manual detecta Nginx por archivo de configuración" {
    # Crear archivo de configuración de Nginx
    mkdir -p "$TEST_TEMP_DIR/etc/nginx"
    cat > "$TEST_TEMP_DIR/etc/nginx/nginx.conf" << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
EOF
    
    # Mock para simular el archivo existe
    WEBSERVER_PATHS["nginx_config"]="$TEST_TEMP_DIR/etc/nginx/nginx.conf"
    
    run detect_nginx_manual
    assert_success
    assert [[ -n "${DETECTED_PANELS[nginx_manual]:-}" ]]
}

@test "detect_nginx_manual detecta Nginx por comando" {
    # Mock del comando nginx
    nginx() {
        if [[ "$1" == "-v" ]]; then
            echo "nginx version: nginx/1.18.0" >&2
            return 0
        fi
        return 1
    }
    export -f nginx
    
    # Mock command para indicar que nginx existe
    command() {
        if [[ "$1" == "-v" && "$2" == "nginx" ]]; then
            return 0
        fi
        return 1
    }
    export -f command
    
    run detect_nginx_manual
    assert_success
    assert [[ "${DETECTED_PANELS[nginx_manual]}" =~ "nginx/1.18.0" ]]
}

@test "detect_nginx_manual detecta Nginx por proceso" {
    # Mock pgrep para simular proceso Nginx
    pgrep() {
        if [[ "$1" == "-f" && "$2" =~ nginx ]]; then
            echo "1234"
            return 0
        fi
        return 1
    }
    export -f pgrep
    
    run detect_nginx_manual
    assert_success
    assert [[ "${DETECTED_PANELS[nginx_manual]}" =~ "detectado por proceso" ]]
}

@test "detect_nginx_manual cuenta sitios en sites-available" {
    # Crear estructura de sitios
    mkdir -p "$TEST_TEMP_DIR/etc/nginx/sites-available"
    touch "$TEST_TEMP_DIR/etc/nginx/sites-available/default.conf"
    touch "$TEST_TEMP_DIR/etc/nginx/sites-available/example.com.conf"
    
    # Mock para simular los directorios existen
    WEBSERVER_PATHS["nginx_config"]="$TEST_TEMP_DIR/etc/nginx/nginx.conf"
    WEBSERVER_PATHS["nginx_sites"]="$TEST_TEMP_DIR/etc/nginx/sites-available"
    
    # Crear archivo de configuración
    echo "user nginx;" > "$TEST_TEMP_DIR/etc/nginx/nginx.conf"
    
    run detect_nginx_manual
    assert_success
    assert [[ "${DETECTED_PANELS[nginx_manual]}" =~ "sites-available:2" ]]
}

# ===================== TESTS DE DETECCIÓN OPENLITESPEED MANUAL =====================

@test "detect_openlitespeed_manual detecta OLS por archivo de configuración" {
    # Crear archivo de configuración de OpenLiteSpeed
    mkdir -p "$TEST_TEMP_DIR/usr/local/lsws/conf"
    cat > "$TEST_TEMP_DIR/usr/local/lsws/conf/httpd_config.conf" << 'EOF'
serverName OpenLiteSpeed
user nobody
group nogroup
priority 0
EOF
    
    # Mock para simular el archivo existe
    WEBSERVER_PATHS["openlitespeed_config"]="$TEST_TEMP_DIR/usr/local/lsws/conf/httpd_config.conf"
    
    run detect_openlitespeed_manual
    assert_success
    assert [[ -n "${DETECTED_PANELS[openlitespeed_manual]:-}" ]]
}

@test "detect_openlitespeed_manual detecta OLS por comando lshttpd" {
    # Mock del comando lshttpd
    lshttpd() {
        if [[ "$1" == "-v" ]]; then
            echo "LiteSpeed Technologies OpenLiteSpeed Web Server/1.7.16"
            return 0
        fi
        return 1
    }
    export -f lshttpd
    
    # Mock command para indicar que lshttpd existe
    command() {
        if [[ "$1" == "-v" && "$2" == "lshttpd" ]]; then
            return 0
        fi
        return 1
    }
    export -f command
    
    run detect_openlitespeed_manual
    assert_success
    assert [[ "${DETECTED_PANELS[openlitespeed_manual]}" =~ "LiteSpeed" ]]
}

@test "detect_openlitespeed_manual detecta OLS por proceso (sin CyberPanel)" {
    # Asegurar que no hay CyberPanel detectado
    unset DETECTED_PANELS[cyberpanel]
    
    # Mock pgrep para simular proceso OpenLiteSpeed
    pgrep() {
        if [[ "$1" == "-f" && "$2" =~ openlitespeed ]]; then
            echo "1234"
            return 0
        fi
        return 1
    }
    export -f pgrep
    
    run detect_openlitespeed_manual
    assert_success
    assert [[ "${DETECTED_PANELS[openlitespeed_manual]}" =~ "detectado por proceso" ]]
}

@test "detect_openlitespeed_manual cuenta virtual hosts" {
    # Crear estructura de virtual hosts
    mkdir -p "$TEST_TEMP_DIR/usr/local/lsws/conf/vhosts/example1"
    mkdir -p "$TEST_TEMP_DIR/usr/local/lsws/conf/vhosts/example2"
    
    # Mock para simular los directorios existen
    WEBSERVER_PATHS["openlitespeed_config"]="$TEST_TEMP_DIR/usr/local/lsws/conf/httpd_config.conf"
    WEBSERVER_PATHS["openlitespeed_vhosts"]="$TEST_TEMP_DIR/usr/local/lsws/conf/vhosts"
    
    # Crear archivo de configuración
    echo "serverName OpenLiteSpeed" > "$TEST_TEMP_DIR/usr/local/lsws/conf/httpd_config.conf"
    
    run detect_openlitespeed_manual
    assert_success
    assert [[ "${DETECTED_PANELS[openlitespeed_manual]}" =~ "vhosts:2" ]]
}

# ===================== TESTS DE INTEGRACIÓN SERVIDORES WEB =====================

@test "detect_panels incluye detección de servidores web manuales" {
    # Mock para simular Apache detectado
    apache2() {
        echo "Server version: Apache/2.4.41"
    }
    export -f apache2
    
    command() {
        if [[ "$1" == "-v" && "$2" == "apache2" ]]; then
            return 0
        fi
        return 1
    }
    export -f command
    
    run detect_panels
    assert_success
    assert [[ "${output}" =~ "apache_manual" ]]
}

@test "prioridad correcta en get_primary_panel con servidores web" {
    # Simular detección de múltiples servidores
    DETECTED_PANELS["apache_manual"]="Apache Manual"
    DETECTED_PANELS["nginx_manual"]="Nginx Manual"
    DETECTED_PANELS["cpanel"]="cPanel"
    
    run get_primary_panel
    assert_success
    # cPanel debe tener prioridad sobre servidores manuales
    assert_output "cpanel"
}

@test "get_primary_panel retorna nginx_manual con prioridad sobre apache" {
    # Simular solo servidores web manuales
    DETECTED_PANELS["apache_manual"]="Apache Manual"
    DETECTED_PANELS["nginx_manual"]="Nginx Manual"
    
    run get_primary_panel
    assert_success
    # Nginx debe tener prioridad sobre Apache
    assert_output "nginx_manual"
}

@test "detección de puertos no interfiere con paneles existentes" {
    # Simular que ya hay un panel detectado
    DETECTED_PANELS["cpanel"]="cPanel"
    
    # Mock netstat que reporta puerto 80
    netstat() {
        echo ":80 LISTEN"
    }
    export -f netstat
    
    command() {
        if [[ "$1" == "-v" && "$2" == "netstat" ]]; then
            return 0
        fi
        return 1
    }
    export -f command
    
    # Apache no debe detectarse por puertos si ya hay un panel
    run detect_apache_manual
    assert_failure
}
