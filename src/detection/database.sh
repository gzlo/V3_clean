#!/usr/bin/env bash

##
# Moodle CLI Backup - Detector de Base de Datos
# 
# Sistema de detección y validación de configuración de base de datos
# Extrae credenciales, valida conexiones y detecta tipos de BD
# 
# @version 1.0.0
# @author GZL Online
##

set -euo pipefail

# ===================== GUARDS Y VALIDACIONES =====================

if [[ "${MOODLE_DATABASE_DETECTOR_LOADED:-}" == "true" ]]; then
    return 0
fi

readonly MOODLE_DATABASE_DETECTOR_LOADED="true"

# Verificar dependencias core
if [[ "${MOODLE_BACKUP_LOGGING_LOADED:-}" != "true" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/../core/logging.sh"
fi

if [[ "${MOODLE_BACKUP_VALIDATION_LOADED:-}" != "true" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/../core/validation.sh"
fi

# ===================== CONFIGURACIÓN DE DETECCIÓN =====================

# Tipos de base de datos soportados
DB_SUPPORTED_TYPES=(
    "mysqli"
    "mariadb"
    "pgsql"
    "sqlsrv"
    "oci"
)

# Puertos por defecto para cada tipo de BD
declare -A DB_DEFAULT_PORTS=(
    ["mysqli"]="3306"
    ["mariadb"]="3306"
    ["pgsql"]="5432"
    ["sqlsrv"]="1433"
    ["oci"]="1521"
)

# Comandos de cliente para cada tipo de BD
declare -A DB_CLIENT_COMMANDS=(
    ["mysqli"]="mysql"
    ["mariadb"]="mysql"
    ["pgsql"]="psql"
    ["sqlsrv"]="sqlcmd"
    ["oci"]="sqlplus"
)

# Comandos de dump para cada tipo de BD
declare -A DB_DUMP_COMMANDS=(
    ["mysqli"]="mysqldump"
    ["mariadb"]="mysqldump"
    ["pgsql"]="pg_dump"
    ["sqlsrv"]="sqlcmd"
    ["oci"]="expdp"
)

# Configuración de timeout
DB_CONNECTION_TIMEOUT="${DB_CONNECTION_TIMEOUT:-10}"
DB_QUERY_TIMEOUT="${DB_QUERY_TIMEOUT:-5}"

# Estado de detección
DATABASE_DETECTION_STARTED=false
declare -A DETECTED_DATABASES=()
declare -A DATABASE_CONFIGS=()

# ===================== FUNCIONES DE PARSING =====================

##
# Extrae configuración de base de datos desde config.php
# @param $1 - Ruta al archivo config.php
##
parse_database_config() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "Archivo config.php no encontrado: $config_file"
        return 1
    fi
    
    if [[ ! -r "$config_file" ]]; then
        log_error "Sin permisos de lectura para: $config_file"
        return 1
    fi
    
    # Variables para almacenar la configuración
    local dbtype dbhost dbname dbuser dbpass dbport dbprefix dbsocket dbcollation
    
    # Extraer cada variable de configuración
    dbtype=$(grep -E '^\s*\$CFG->dbtype\s*=' "$config_file" 2>/dev/null | sed -E "s/.*=\s*['\"]([^'\"]+)['\"].*/\1/" | head -1)
    dbhost=$(grep -E '^\s*\$CFG->dbhost\s*=' "$config_file" 2>/dev/null | sed -E "s/.*=\s*['\"]([^'\"]+)['\"].*/\1/" | head -1)
    dbname=$(grep -E '^\s*\$CFG->dbname\s*=' "$config_file" 2>/dev/null | sed -E "s/.*=\s*['\"]([^'\"]+)['\"].*/\1/" | head -1)
    dbuser=$(grep -E '^\s*\$CFG->dbuser\s*=' "$config_file" 2>/dev/null | sed -E "s/.*=\s*['\"]([^'\"]+)['\"].*/\1/" | head -1)
    dbpass=$(grep -E '^\s*\$CFG->dbpass\s*=' "$config_file" 2>/dev/null | sed -E "s/.*=\s*['\"]([^'\"]*)['\"].*/\1/" | head -1)
    dbport=$(grep -E '^\s*\$CFG->dbport\s*=' "$config_file" 2>/dev/null | sed -E "s/.*=\s*['\"]?([^'\"]+)['\"]?.*/\1/" | head -1)
    dbprefix=$(grep -E '^\s*\$CFG->prefix\s*=' "$config_file" 2>/dev/null | sed -E "s/.*=\s*['\"]([^'\"]*)['\"].*/\1/" | head -1)
    dbsocket=$(grep -E '^\s*\$CFG->dbsocket\s*=' "$config_file" 2>/dev/null | sed -E "s/.*=\s*['\"]([^'\"]*)['\"].*/\1/" | head -1)
    dbcollation=$(grep -E '^\s*\$CFG->dbcollation\s*=' "$config_file" 2>/dev/null | sed -E "s/.*=\s*['\"]([^'\"]*)['\"].*/\1/" | head -1)
    
    # Valores por defecto si no se especifican
    [[ -z "$dbport" && -n "$dbtype" ]] && dbport="${DB_DEFAULT_PORTS[$dbtype]:-3306}"
    [[ -z "$dbprefix" ]] && dbprefix="mdl_"
    [[ -z "$dbhost" ]] && dbhost="localhost"
    
    # Validar configuración mínima
    if [[ -z "$dbtype" ]] || [[ -z "$dbname" ]] || [[ -z "$dbuser" ]]; then
        log_error "Configuración de BD incompleta en: $config_file"
        return 1
    fi
    
    # Crear objeto de configuración
    local db_config=""
    db_config+="type:$dbtype"
    db_config+="|host:$dbhost"
    db_config+="|name:$dbname"
    db_config+="|user:$dbuser"
    db_config+="|pass:$dbpass"
    db_config+="|port:$dbport"
    db_config+="|prefix:$dbprefix"
    [[ -n "$dbsocket" ]] && db_config+="|socket:$dbsocket"
    [[ -n "$dbcollation" ]] && db_config+="|collation:$dbcollation"
    
    echo "$db_config"
    return 0
}

##
# Obtiene el valor de un parámetro de configuración de BD
# @param $1 - Configuración de BD (formato key:value|key:value)
# @param $2 - Nombre del parámetro
##
get_db_config_value() {
    local db_config="$1"
    local param_name="$2"
    
    echo "$db_config" | grep -oE "${param_name}:[^|]+" | cut -d':' -f2-
}

# ===================== VALIDACIÓN DE CONEXIÓN =====================

##
# Valida conexión MySQL/MariaDB
# @param $1 - Configuración de BD
##
validate_mysql_connection() {
    local db_config="$1"
    
    local host port user pass dbname socket
    host=$(get_db_config_value "$db_config" "host")
    port=$(get_db_config_value "$db_config" "port")
    user=$(get_db_config_value "$db_config" "user")
    pass=$(get_db_config_value "$db_config" "pass")
    dbname=$(get_db_config_value "$db_config" "name")
    socket=$(get_db_config_value "$db_config" "socket")
    
    # Construir comando de conexión
    local mysql_cmd="mysql"
    [[ -n "$host" ]] && mysql_cmd+=" -h '$host'"
    [[ -n "$port" ]] && mysql_cmd+=" -P '$port'"
    [[ -n "$user" ]] && mysql_cmd+=" -u '$user'"
    [[ -n "$pass" ]] && mysql_cmd+=" -p'$pass'"
    [[ -n "$socket" ]] && mysql_cmd+=" -S '$socket'"
    mysql_cmd+=" -e 'SELECT VERSION();' '$dbname'"
    
    # Ejecutar con timeout
    local result
    if command -v timeout >/dev/null 2>&1; then
        result=$(timeout "$DB_CONNECTION_TIMEOUT" bash -c "$mysql_cmd" 2>/dev/null)
    else
        result=$(eval "$mysql_cmd" 2>/dev/null)
    fi
    
    if [[ $? -eq 0 && -n "$result" ]]; then
        # Extraer versión
        local version
        version=$(echo "$result" | tail -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        echo "version:$version|status:connected"
        return 0
    fi
    
    echo "status:connection_failed"
    return 1
}

##
# Valida conexión PostgreSQL
# @param $1 - Configuración de BD
##
validate_postgresql_connection() {
    local db_config="$1"
    
    local host port user pass dbname
    host=$(get_db_config_value "$db_config" "host")
    port=$(get_db_config_value "$db_config" "port")
    user=$(get_db_config_value "$db_config" "user")
    pass=$(get_db_config_value "$db_config" "pass")
    dbname=$(get_db_config_value "$db_config" "name")
    
    # Configurar variables de entorno para PostgreSQL
    export PGHOST="$host"
    export PGPORT="$port"
    export PGUSER="$user"
    export PGPASSWORD="$pass"
    export PGDATABASE="$dbname"
    export PGCONNECT_TIMEOUT="$DB_CONNECTION_TIMEOUT"
    
    # Ejecutar query simple
    local result
    result=$(psql -t -c "SELECT version();" 2>/dev/null)
    
    if [[ $? -eq 0 && -n "$result" ]]; then
        # Extraer versión
        local version
        version=$(echo "$result" | grep -oE '[0-9]+\.[0-9]+')
        echo "version:$version|status:connected"
        return 0
    fi
    
    echo "status:connection_failed"
    return 1
}

##
# Valida conexión a base de datos según el tipo
# @param $1 - Configuración de BD
##
validate_database_connection() {
    local db_config="$1"
    local db_type
    db_type=$(get_db_config_value "$db_config" "type")
    
    if [[ "$MOODLE_CLI_TEST_MODE" == "true" ]]; then
        # En modo test, simular conexión exitosa
        echo "version:test_version|status:connected|mode:test"
        return 0
    fi
    
    # Verificar que el comando cliente esté disponible
    local client_cmd="${DB_CLIENT_COMMANDS[$db_type]:-}"
    if [[ -z "$client_cmd" ]]; then
        echo "status:unsupported_type"
        return 1
    fi
    
    if ! command -v "$client_cmd" >/dev/null 2>&1; then
        echo "status:client_not_found|client:$client_cmd"
        return 1
    fi
    
    log_debug "Validando conexión $db_type..."
    
    case "$db_type" in
        "mysqli"|"mariadb")
            validate_mysql_connection "$db_config"
            ;;
        "pgsql")
            validate_postgresql_connection "$db_config"
            ;;
        *)
            echo "status:validation_not_implemented|type:$db_type"
            return 1
            ;;
    esac
}

# ===================== ANÁLISIS DE BASE DE DATOS =====================

##
# Obtiene información del esquema de la base de datos
# @param $1 - Configuración de BD
##
analyze_database_schema() {
    local db_config="$1"
    local db_type
    db_type=$(get_db_config_value "$db_config" "type")
    
    if [[ "$MOODLE_CLI_TEST_MODE" == "true" ]]; then
        echo "tables:150|size:500MB|moodle_tables:true"
        return 0
    fi
    
    case "$db_type" in
        "mysqli"|"mariadb")
            analyze_mysql_schema "$db_config"
            ;;
        "pgsql")
            analyze_postgresql_schema "$db_config"
            ;;
        *)
            echo "analysis:not_supported"
            return 1
            ;;
    esac
}

##
# Analiza esquema MySQL/MariaDB
# @param $1 - Configuración de BD
##
analyze_mysql_schema() {
    local db_config="$1"
    
    local host port user pass dbname prefix
    host=$(get_db_config_value "$db_config" "host")
    port=$(get_db_config_value "$db_config" "port")
    user=$(get_db_config_value "$db_config" "user")
    pass=$(get_db_config_value "$db_config" "pass")
    dbname=$(get_db_config_value "$db_config" "name")
    prefix=$(get_db_config_value "$db_config" "prefix")
    
    # Construir comando base
    local mysql_base="mysql -h '$host' -P '$port' -u '$user' -p'$pass' '$dbname'"
    
    # Contar tablas totales
    local total_tables
    total_tables=$(eval "$mysql_base -e 'SHOW TABLES;'" 2>/dev/null | wc -l)
    total_tables=$((total_tables - 1))  # Excluir header
    
    # Contar tablas de Moodle
    local moodle_tables
    moodle_tables=$(eval "$mysql_base -e \"SHOW TABLES LIKE '${prefix}%';\"" 2>/dev/null | wc -l)
    moodle_tables=$((moodle_tables - 1))  # Excluir header
    
    # Obtener tamaño de BD
    local db_size
    db_size=$(eval "$mysql_base -e \"SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 1) AS 'DB Size in MB' FROM information_schema.tables WHERE table_schema='$dbname';\"" 2>/dev/null | tail -1)
    
    # Verificar si hay tablas típicas de Moodle
    local has_moodle_tables="false"
    if eval "$mysql_base -e \"SHOW TABLES LIKE '${prefix}user';\"" 2>/dev/null | grep -q "${prefix}user"; then
        has_moodle_tables="true"
    fi
    
    echo "tables:$total_tables|moodle_tables:$moodle_tables|size:${db_size}MB|is_moodle:$has_moodle_tables"
    return 0
}

##
# Analiza esquema PostgreSQL
# @param $1 - Configuración de BD
##
analyze_postgresql_schema() {
    local db_config="$1"
    
    local host port user pass dbname prefix
    host=$(get_db_config_value "$db_config" "host")
    port=$(get_db_config_value "$db_config" "port")
    user=$(get_db_config_value "$db_config" "user")
    pass=$(get_db_config_value "$db_config" "pass")
    dbname=$(get_db_config_value "$db_config" "name")
    prefix=$(get_db_config_value "$db_config" "prefix")
    
    # Configurar variables de entorno
    export PGHOST="$host"
    export PGPORT="$port"
    export PGUSER="$user"
    export PGPASSWORD="$pass"
    export PGDATABASE="$dbname"
    
    # Contar tablas
    local total_tables
    total_tables=$(psql -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null | tr -d ' ')
    
    local moodle_tables
    moodle_tables=$(psql -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name LIKE '${prefix}%';" 2>/dev/null | tr -d ' ')
    
    # Obtener tamaño de BD
    local db_size
    db_size=$(psql -t -c "SELECT pg_size_pretty(pg_database_size('$dbname'));" 2>/dev/null | tr -d ' ')
    
    # Verificar si hay tablas típicas de Moodle
    local has_moodle_tables="false"
    if psql -t -c "SELECT 1 FROM information_schema.tables WHERE table_name = '${prefix}user';" 2>/dev/null | grep -q "1"; then
        has_moodle_tables="true"
    fi
    
    echo "tables:$total_tables|moodle_tables:$moodle_tables|size:$db_size|is_moodle:$has_moodle_tables"
    return 0
}

# ===================== FUNCIÓN PRINCIPAL =====================

##
# Función principal para detectar configuración de base de datos
# @param $1 - Ruta al directorio de Moodle o archivo config.php
##
detect_database() {
    local moodle_path="${1:-}"
    
    if [[ "$DATABASE_DETECTION_STARTED" == "true" ]]; then
        log_debug "Detección de BD ya ejecutada"
        # Retornar resultado existente
        for db_id in "${!DETECTED_DATABASES[@]}"; do
            echo "${DETECTED_DATABASES[$db_id]}"
        done
        return 0
    fi
    
    DATABASE_DETECTION_STARTED=true
    
    # Determinar archivo config.php
    local config_file=""
    if [[ -z "$moodle_path" ]]; then
        # Buscar en directorio actual
        config_file="./config.php"
    elif [[ -f "$moodle_path" ]]; then
        # Es un archivo
        config_file="$moodle_path"
    elif [[ -d "$moodle_path" ]]; then
        # Es un directorio
        config_file="$moodle_path/config.php"
    else
        log_error "Ruta no válida: $moodle_path"
        return 1
    fi
    
    if [[ ! -f "$config_file" ]]; then
        log_error "Archivo config.php no encontrado: $config_file"
        return 1
    fi
    
    log_info "Detectando configuración de base de datos desde: $config_file"
    
    # Parsear configuración
    local db_config
    if ! db_config=$(parse_database_config "$config_file"); then
        log_error "Error parseando configuración de BD"
        return 1
    fi
    
    local db_type
    db_type=$(get_db_config_value "$db_config" "type")
    
    # Validar tipo soportado
    local supported=false
    for supported_type in "${DB_SUPPORTED_TYPES[@]}"; do
        if [[ "$db_type" == "$supported_type" ]]; then
            supported=true
            break
        fi
    done
    
    if [[ "$supported" == "false" ]]; then
        log_warning "Tipo de BD no completamente soportado: $db_type"
    fi
    
    # Validar conexión
    log_debug "Validando conexión a base de datos..."
    local connection_info
    connection_info=$(validate_database_connection "$db_config")
    
    # Analizar esquema si la conexión es exitosa
    local schema_info=""
    if echo "$connection_info" | grep -q "status:connected"; then
        log_debug "Analizando esquema de base de datos..."
        schema_info=$(analyze_database_schema "$db_config")
    fi
    
    # Combinar toda la información
    local complete_info="$db_config"
    [[ -n "$connection_info" ]] && complete_info+="|$connection_info"
    [[ -n "$schema_info" ]] && complete_info+="|$schema_info"
    
    # Almacenar resultado
    local db_id="${db_type}_$(get_db_config_value "$db_config" "name")"
    DETECTED_DATABASES["$db_id"]="$complete_info"
    DATABASE_CONFIGS["$db_id"]="$db_config"
    
    log_success "Configuración de BD detectada: $db_type"
    echo "$complete_info"
    return 0
}

##
# Obtiene configuración de BD específica
# @param $1 - ID de la base de datos
##
get_database_config() {
    local db_id="$1"
    echo "${DATABASE_CONFIGS[$db_id]:-}"
}

##
# Verifica si hay comando de dump disponible
# @param $1 - Tipo de BD
##
has_dump_command() {
    local db_type="$1"
    local dump_cmd="${DB_DUMP_COMMANDS[$db_type]:-}"
    
    if [[ -n "$dump_cmd" ]] && command -v "$dump_cmd" >/dev/null 2>&1; then
        return 0
    fi
    
    return 1
}

# ===================== LIMPIEZA =====================

##
# Limpia el estado de detección de BD
##
database_cleanup() {
    DATABASE_DETECTION_STARTED=false
    DETECTED_DATABASES=()
    DATABASE_CONFIGS=()
    
    log_debug "Estado de detección de BD limpiado"
}

# ===================== MODO SCRIPT INDEPENDIENTE =====================

# Si se ejecuta directamente (no como source)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    detect_database "${1:-}"
fi
