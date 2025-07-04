#!/usr/bin/env bash

##
# Fixtures para Tests de Detección
# 
# Proporciona datos de prueba consistentes para todos los tests de detección
##

# ===================== FIXTURES DE CONFIGURACIÓN MOODLE =====================

##
# Genera un config.php de Moodle válido
# @param $1 - Directorio donde crear el archivo
# @param $2 - Tipo de BD (mysqli, pgsql, etc.)
##
create_moodle_config_fixture() {
    local target_dir="$1"
    local db_type="${2:-mysqli}"
    
    mkdir -p "$target_dir"
    
    cat > "$target_dir/config.php" << EOF
<?php  // Moodle configuration file
unset(\$CFG);
global \$CFG;
\$CFG = new stdClass();

\$CFG->dbtype    = '$db_type';
\$CFG->dblibrary = 'native';
\$CFG->dbhost    = 'localhost';
\$CFG->dbname    = 'moodle_test';
\$CFG->dbuser    = 'moodle_user';
\$CFG->dbpass    = 'moodle_pass';
\$CFG->prefix    = 'mdl_';
\$CFG->dboptions = array(
    'dbpersist' => 0,
    'dbsocket' => '',
    'dbport' => '',
    'dbhandlesoptions' => false,
    'dbcollation' => 'utf8mb4_unicode_ci',
);

\$CFG->wwwroot   = 'http://localhost/moodle';
\$CFG->dataroot  = '/var/moodledata';
\$CFG->admin     = 'admin';

\$CFG->directorypermissions = 02777;

require_once(__DIR__ . '/lib/setup.php');
EOF
}

##
# Genera un config.php incompleto para tests negativos
##
create_incomplete_moodle_config_fixture() {
    local target_dir="$1"
    
    mkdir -p "$target_dir"
    
    cat > "$target_dir/config.php" << 'EOF'
<?php
$CFG = new stdClass();
$CFG->dbtype = 'mysqli';
// Configuración incompleta - falta dbhost, dbname, etc.
EOF
}

##
# Genera un version.php de Moodle
# @param $1 - Directorio donde crear el archivo
# @param $2 - Año de versión (2022, 2023, 2024)
##
create_moodle_version_fixture() {
    local target_dir="$1"
    local version_year="${2:-2023}"
    
    mkdir -p "$target_dir"
    
    local version_number
    case "$version_year" in
        2019) version_number="2019051700" ;;
        2020) version_number="2020061500" ;;
        2021) version_number="2021051700" ;;
        2022) version_number="2022041900" ;;
        2023) version_number="2023042400" ;;
        2024) version_number="2024042200" ;;
        *) version_number="2023042400" ;;
    esac
    
    cat > "$target_dir/version.php" << EOF
<?php
defined('MOODLE_INTERNAL') || die();

\$version  = $version_number;        // YYYYMMDDXX
\$release  = '4.2.0';
\$branch   = '402';
\$maturity = MATURITY_STABLE;
EOF
}

# ===================== FIXTURES DE ESTRUCTURA MOODLE =====================

##
# Crea una estructura completa de Moodle para testing
# @param $1 - Directorio base
# @param $2 - Tipo de BD (opcional)
# @param $3 - Año de versión (opcional)
##
create_complete_moodle_fixture() {
    local moodle_dir="$1"
    local db_type="${2:-mysqli}"
    local version_year="${3:-2023}"
    
    # Crear directorios principales
    mkdir -p "$moodle_dir"/{lib,course,admin,user,mod,blocks,theme,filter,enrol,auth,grade,backup,question,repository,portfolio,webservice,calendar,message,tag,blog,notes,plagiarism,cohort,badges,analytics,search,privacy,customfield,completion,competency,rating,comment,mnet,cache,tempdir,lang}
    
    # Crear archivos de firma principales
    touch "$moodle_dir/index.php"
    touch "$moodle_dir/config-dist.php"
    touch "$moodle_dir/install.php"
    touch "$moodle_dir/lib/moodlelib.php"
    touch "$moodle_dir/lib/weblib.php"
    touch "$moodle_dir/lib/dmllib.php"
    touch "$moodle_dir/course/lib.php"
    touch "$moodle_dir/admin/index.php"
    touch "$moodle_dir/admin/cli/install.php"
    
    # Crear archivos de configuración
    create_moodle_config_fixture "$moodle_dir" "$db_type"
    create_moodle_version_fixture "$moodle_dir" "$version_year"
    
    # Crear .htaccess
    cat > "$moodle_dir/.htaccess" << 'EOF'
# Apache configuration for Moodle
RewriteEngine On
EOF
    
    # Crear algunos archivos PHP adicionales
    echo "<?php // Core functions" > "$moodle_dir/lib/corelib.php"
    echo "<?php // Course functions" > "$moodle_dir/course/format.php"
}

##
# Crea estructura de moodledata para testing
# @param $1 - Directorio de moodledata
##
create_moodledata_fixture() {
    local data_dir="$1"
    
    # Crear directorios típicos de moodledata
    mkdir -p "$data_dir"/{cache,filedir,lang,localcache,muc,sessions,temp,trashdir,lock}
    
    # Crear algunos subdirectorios específicos
    mkdir -p "$data_dir/filedir/00/01"
    mkdir -p "$data_dir/cache/cachestore_file/default_application"
    mkdir -p "$data_dir/sessions/sess_"
    
    # Crear archivos típicos
    touch "$data_dir/.htaccess"
    echo "deny from all" > "$data_dir/.htaccess"
    
    cat > "$data_dir/environment.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8" ?>
<MOODLE_ENVIRONMENT>
    <ENVIRONMENT>
        <NAME>test_environment</NAME>
    </ENVIRONMENT>
</MOODLE_ENVIRONMENT>
EOF
    
    # Crear algunos archivos de log simulados
    echo "$(date): Test log entry" > "$data_dir/upgrade.log"
    mkdir -p "$data_dir/phpunit"
    touch "$data_dir/phpunit/phpunit.xml"
}

# ===================== FIXTURES DE PANELES DE CONTROL =====================

##
# Crea fixture de cPanel
# @param $1 - Directorio base del sistema simulado
##
create_cpanel_fixture() {
    local system_dir="$1"
    
    # Crear estructura de cPanel
    mkdir -p "$system_dir/usr/local/cpanel"/{bin,whostmgr,logs,etc}
    
    # Archivo de versión
    echo "11.92.0.5" > "$system_dir/usr/local/cpanel/version"
    
    # Binarios simulados
    touch "$system_dir/usr/local/cpanel/bin/cpanel"
    touch "$system_dir/usr/local/cpanel/bin/whostmgr"
    chmod +x "$system_dir/usr/local/cpanel/bin"/*
    
    # Configuración
    cat > "$system_dir/usr/local/cpanel/etc/cpanel.config" << 'EOF'
cpanel_version=11.92.0.5
theme=jupiter
EOF
}

##
# Crea fixture de Plesk
##
create_plesk_fixture() {
    local system_dir="$1"
    
    # Crear estructura de Plesk
    mkdir -p "$system_dir/usr/local/psa"/{bin,admin,var,etc}
    
    # Archivo de versión
    echo "Plesk 18.0.35" > "$system_dir/usr/local/psa/version"
    
    # Binarios simulados
    touch "$system_dir/usr/local/psa/bin/plesk"
    chmod +x "$system_dir/usr/local/psa/bin/plesk"
    
    # Admin interface
    mkdir -p "$system_dir/usr/local/psa/admin/plib"
    touch "$system_dir/usr/local/psa/admin/plib/config.php"
}

##
# Crea fixture de DirectAdmin
##
create_directadmin_fixture() {
    local system_dir="$1"
    
    # Crear estructura de DirectAdmin
    mkdir -p "$system_dir/usr/local/directadmin"/{conf,data,plugins}
    
    # Archivo de configuración
    cat > "$system_dir/usr/local/directadmin/conf/directadmin.conf" << 'EOF'
version=1.60.8
admin_user=admin
ethernet_dev=eth0
EOF
    
    # Binario
    touch "$system_dir/usr/local/directadmin/directadmin"
    chmod +x "$system_dir/usr/local/directadmin/directadmin"
}

##
# Crea fixture de VestaCP
##
create_vestacp_fixture() {
    local system_dir="$1"
    
    # Crear estructura de VestaCP
    mkdir -p "$system_dir/usr/local/vesta"/{bin,conf,data,web}
    
    # Archivo de configuración
    cat > "$system_dir/usr/local/vesta/conf/vesta.conf" << 'EOF'
VESTA='1.0'
VERSION='0.9.8-26'
EOF
    
    # Binarios
    touch "$system_dir/usr/local/vesta/bin/v-list-sys-info"
    chmod +x "$system_dir/usr/local/vesta/bin/v-list-sys-info"
}

##
# Crea fixture de HestiaCP
##
create_hestiacp_fixture() {
    local system_dir="$1"
    
    # Crear estructura de HestiaCP
    mkdir -p "$system_dir/usr/local/hestia"/{bin,conf,data,web}
    
    # Archivo de configuración
    cat > "$system_dir/usr/local/hestia/conf/hestia.conf" << 'EOF'
HESTIA='1.0'
VERSION='1.6.0'
EOF
    
    # Binarios
    touch "$system_dir/usr/local/hestia/bin/v-list-sys-info"
    chmod +x "$system_dir/usr/local/hestia/bin/v-list-sys-info"
}

# ===================== FIXTURES DE ENTORNOS WEB =====================

##
# Crea estructura de hosting típica con múltiples sitios
# @param $1 - Directorio base
##
create_hosting_environment_fixture() {
    local base_dir="$1"
    
    # Estructura típica de cPanel
    mkdir -p "$base_dir/home/user1/public_html"
    mkdir -p "$base_dir/home/user2/public_html"
    mkdir -p "$base_dir/home/user1/moodledata"
    mkdir -p "$base_dir/home/user2/moodledata"
    
    # Estructura típica de Plesk
    mkdir -p "$base_dir/var/www/vhosts/site1.com/httpdocs"
    mkdir -p "$base_dir/var/www/vhosts/site2.com/httpdocs"
    mkdir -p "$base_dir/var/www/vhosts/site1.com/moodledata"
    
    # Crear algunas instalaciones Moodle
    create_complete_moodle_fixture "$base_dir/home/user1/public_html/moodle"
    create_complete_moodle_fixture "$base_dir/var/www/vhosts/site1.com/httpdocs/lms"
    
    # Crear algunos moodledata
    create_moodledata_fixture "$base_dir/home/user1/moodledata"
    create_moodledata_fixture "$base_dir/var/www/vhosts/site1.com/moodledata"
    
    # Crear algunas instalaciones no-Moodle para ruido
    mkdir -p "$base_dir/home/user2/public_html/wordpress"
    echo "<?php // WordPress" > "$base_dir/home/user2/public_html/wordpress/wp-config.php"
}

# ===================== FIXTURES DE BASE DE DATOS =====================

##
# Crea fixture de configuración MySQL
##
create_mysql_config_fixture() {
    local target_dir="$1"
    
    create_moodle_config_fixture "$target_dir" "mysqli"
}

##
# Crea fixture de configuración PostgreSQL
##
create_postgresql_config_fixture() {
    local target_dir="$1"
    
    cat > "$target_dir/config.php" << 'EOF'
<?php
$CFG = new stdClass();
$CFG->dbtype    = 'pgsql';
$CFG->dbhost    = 'localhost';
$CFG->dbname    = 'moodle_test';
$CFG->dbuser    = 'postgres';
$CFG->dbpass    = 'postgres_pass';
$CFG->dbport    = '5432';
$CFG->prefix    = 'mdl_';
$CFG->wwwroot   = 'http://localhost/moodle';
$CFG->dataroot  = '/var/moodledata';
EOF
}

# ===================== FUNCIONES DE LIMPIEZA =====================

##
# Limpia todos los fixtures creados
# @param $1 - Directorio base de fixtures
##
cleanup_fixtures() {
    local fixture_dir="$1"
    
    if [[ -d "$fixture_dir" ]]; then
        rm -rf "$fixture_dir"
    fi
}

##
# Verifica que un fixture de Moodle es válido
# @param $1 - Directorio del fixture
##
verify_moodle_fixture() {
    local moodle_dir="$1"
    
    # Verificar archivos críticos
    [[ -f "$moodle_dir/config.php" ]] || return 1
    [[ -f "$moodle_dir/version.php" ]] || return 1
    [[ -f "$moodle_dir/lib/moodlelib.php" ]] || return 1
    [[ -d "$moodle_dir/course" ]] || return 1
    [[ -d "$moodle_dir/admin" ]] || return 1
    
    return 0
}

# ===================== VARIABLES DE CONFIGURACIÓN =====================

# Configuración por defecto para fixtures
FIXTURE_DB_TYPE_DEFAULT="mysqli"
FIXTURE_VERSION_YEAR_DEFAULT="2023"
FIXTURE_WWWROOT_DEFAULT="http://localhost/moodle"
FIXTURE_DATAROOT_DEFAULT="/var/moodledata"

# Exportar funciones para uso en tests
export -f create_moodle_config_fixture
export -f create_incomplete_moodle_config_fixture
export -f create_moodle_version_fixture
export -f create_complete_moodle_fixture
export -f create_moodledata_fixture
export -f create_cpanel_fixture
export -f create_plesk_fixture
export -f create_directadmin_fixture
export -f create_vestacp_fixture
export -f create_hestiacp_fixture
export -f create_hosting_environment_fixture
export -f create_mysql_config_fixture
export -f create_postgresql_config_fixture
export -f cleanup_fixtures
export -f verify_moodle_fixture
