# 🚀 Moodle CLI Backup - Sistema Modular y Open Source

[![Version](https://img.shields.io/badge/version-4.0.0--dev-blue.svg)](https://github.com/gzlo/moodle-backup)
[![Shell](https://img.shields.io/badge/shell-bash-green.svg)](https://www.gnu.org/software/bash/)
[![License](https://img.shields.io/badge/license-MIT-orange.svg)](LICENSE)
[![Build](https://img.shields.io/badge/build-passing-brightgreen.svg)](#-desarrollo)
[![Coverage](https://img.shields.io/badge/coverage-90%25-green.svg)](#-testing)
[![Panel Support](https://img.shields.io/badge/panels-cPanel%20%7C%20Plesk%20%7C%20DirectAdmin%20%7C%20VestaCP%20%7C%20Hestia%20%7C%20CyberPanel%20%7C%20Docker%20%7C%20Manual-blue.svg)](#-paneles-soportados)

Sistema avanzado de backup para Moodle completamente **modularizado** y **open source**. Incluye arquitectura escalable, sistema de build automatizado, testing comprehensivo y documentación profesional. Diseñado para funcionar en cualquier entorno con una experiencia de usuario completamente renovada.

## 🆕 Novedades de la Versión 4.0.0 - Arquitectura Modular

### 🏗️ **Refactorización Completa a Arquitectura Modular**
- **Separación de responsabilidades**: Código organizado en módulos especializados
- **Build system avanzado**: Generación automática de single-file para distribución
- **Testing comprehensivo**: Suite de tests unitarios e integración (objetivo 90% coverage)
- **Documentación profesional**: API docs, guías y ejemplos
- **CI/CD integrado**: GitHub Actions para calidad y deployment automático

### 📁 **Nueva Estructura de Proyecto**
```
moodle_cli/
├── src/                    # Código fuente modular
│   ├── core/              # Módulos core del sistema  
│   ├── detection/         # Auto-detección de Moodle
│   ├── backup/            # Lógica de backup
│   ├── cloud/             # Integración cloud
│   └── moodle/            # Específico de Moodle
├── lib/                   # Librerías compartidas
├── scripts/               # Scripts de build y desarrollo
├── tests/                 # Suite de testing completa
├── docs/                  # Documentación detallada
└── dist/                  # Archivos compilados
```

### 🔧 **Sistema de Build y Desarrollo**
```bash
# Compilar single-file para distribución
./scripts/build.sh

# Ejecutar suite de tests completa
./tests/run-all-tests.sh

# Análisis de código y linting
./scripts/lint.sh

# Setup de entorno de desarrollo
./scripts/setup-testing.sh
```

### 🌐 **Sistema de Auto-Detección Inteligente (NUEVO)**
- **Detección automática** de paneles de control (cPanel, Plesk, DirectAdmin, etc.)
- **Detección automática** de servidores web (Apache, Nginx, OpenLiteSpeed)
- **Búsqueda inteligente** de instalaciones Moodle en rutas estándar
- **Análisis completo** de configuraciones y versiones
- **Selección interactiva** para múltiples instalaciones

### 🧪 **Testing Profesional**
- **BATS framework**: Tests unitarios e integración robustos
- **Mocks y fixtures**: Simulación completa de entornos Moodle
- **Coverage tracking**: Métricas detalladas de cobertura
- **CI/CD integration**: Tests automáticos en cada commit

### 📖 **Roadmap de Desarrollo**
Ver [`ROADMAP.md`](ROADMAP.md) para el plan detallado de implementación en fases.

---

## 🆕 Novedades de la Versión 3.4.0

### 🎯 Auto-detección Completa de Configuración de Moodle
- **Parsing automático de config.php**: Extrae automáticamente todas las variables críticas (`$CFG->dbhost`, `$CFG->dbname`, `$CFG->dbuser`, `$CFG->dbpass`, `$CFG->dataroot`)
- **Búsqueda inteligente de instalaciones**: Encuentra automáticamente todas las instalaciones de Moodle en el servidor
- **Selección interactiva**: Permite elegir entre múltiples instalaciones detectadas
- **Preconfiguración total**: Todos los valores se preconfiguran automáticamente, solo requiere confirmación

### 🔍 Algoritmo de Detección Avanzado
- **Búsqueda optimizada por panel**: Prioriza directorios específicos según el tipo de panel detectado
- **Patrones adaptativos**: Incluye wildcards para detectar subdominios y sitios múltiples  
- **Validación robusta**: Verifica que cada config.php sea realmente de Moodle
- **Fallbacks inteligentes**: Si falla la autodetección, permite configuración manual

### 💡 Experiencia Completamente Automatizada
```bash
🔍 DETECCIÓN AUTOMÁTICA DE MOODLE
¿Buscar automáticamente instalaciones de Moodle? [Y/n]: Y

📁 Instalación Moodle encontrada: /home/usuario/public_html
✅ Configuración de Moodle detectada exitosamente

📋 CONFIGURACIÓN DETECTADA DESDE MOODLE:
   • Host BD: localhost
   • Nombre BD: usuario_moodle  
   • Usuario BD: usuario_db
   • Contraseña BD: [detectada]
   • Datos Moodle: /home/usuario/moodledata
   • URL Moodle: https://moodle.ejemplo.com

✅ Instalación de Moodle autodetectada y configurada
```

### 🧪 Tests Automatizados Ampliados
- **Nuevo test específico**: `test-moodle-config-parsing.sh` con 7 casos de prueba
- **Cobertura completa**: Tests para todos los instaladores y formatos de config.php
- **Validación de errores**: Tests para archivos inválidos y formatos alternativos
- **Integración total**: Ejecuta automáticamente en la suite de tests

## 🆕 Novedades de la Versión 3.3.0

### 🚀 Detección de Paneles Ampliada
- **Nuevos paneles soportados**: CyberPanel, Hestia, VestaCP (mejorado), Docker, Apache/Nginx/LiteSpeed manual
- **Auto-detección robusta**: Algoritmo mejorado que detecta más configuraciones de servidor
- **Placeholders inteligentes avanzados**: Usan el dominio y usuario real detectado del sistema
- **Tests automatizados**: Suite completa de 8 tests para validar todas las mejoras

### 🎯 Experiencia de Usuario Mejorada
- **Navegación con flechas completa**: Edición avanzada de texto con `read -e -i`
- **Placeholders específicos por panel**: Cada panel genera ejemplos apropiados para su estructura
- **Detección de usuario real**: Los ejemplos usan el usuario actual en lugar de "usuario" genérico
- **Ayuda visual**: Instrucciones de navegación mostradas durante la entrada de datos

### 🔧 Funciones Técnicas Nuevas
- `auto_detect_directories_hestia()`: Para Hestia Control Panel
- `auto_detect_directories_cyberpanel()`: Para CyberPanel
- `auto_detect_directories_docker()`: Para contenedores Docker
- `auto_detect_directories_apache()`: Para Apache manual
- `auto_detect_directories_nginx()`: Para Nginx manual
- `auto_detect_directories_litespeed()`: Para LiteSpeed manual

## 🆕 Novedades de la Versión 3.2.1

### 🎨 Interfaz de Usuario Mejorada
- **Placeholders inteligentes** que muestran rutas reales (ej: `/home/dev4hc/public_html`)
- **Navegación con flechas** completa para editar texto con readline
- **Valores pre-completados** en campos de entrada para mejor experiencia
- **Auto-detección de usuario** del sistema actual para ejemplos precisos

### 🧭 Navegación Avanzada
- **Soporte completo de edición**: Usa flechas ← → para moverte por el texto
- **Atajos de teclado**: Ctrl+A (inicio), Ctrl+E (fin), Ctrl+U (limpiar)
- **Edición in-situ**: Los valores por defecto se cargan directamente en el editor
- **Ayuda visual**: Instrucciones de navegación mostradas al usuario

## 🆕 Novedades de la Versión 3.2

### 🐛 Correcciones Críticas
- **Corregido error de tipeo** en variable `AUTO_DETECT_AGGRESSIVE`
- **Solucionado problema de variables locales** que impedía asignación correcta
- **Arreglado script `mb`** que generaba loop infinito por contenido mal ubicado
- **Mejorada detección de paneles** eliminando output contaminado
- **Validaciones robustas** para configuración de cron

### ✨ Mejoras de Estabilidad
- **Asignación dual de variables** usando `declare -g` y `eval` con verificación
- **Validación de parámetros** antes de configurar tareas cron
- **Manejo de errores mejorado** con mensajes más claros
- **Verificación de sintaxis** automática antes de ejecución

### 🔧 Funcionalidad Corregida
- **Resumen de configuración** ahora muestra valores correctamente
- **Archivos de configuración** se guardan con nombres válidos
- **Comando `mb`** funciona sin loops ni errores
- **Detección automática** de paneles sin contaminar output

## ⚡ Instalación Rápida

### Método Recomendado: Instalador Interactivo

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/gzlo/moodle-backup/main/install-interactive.sh)
```

### Instalación Automatizada (Sin interacción)

```bash
# Para entornos donde no se puede usar modo interactivo
curl -fsSL https://raw.githubusercontent.com/gzlo/moodle-backup/main/install.sh | bash
```

## 🎛️ Flujo de Configuración Inteligente

### 1. Auto-Detección de Panel
```
✅ Panel detectado automáticamente: cpanel
¿Usar el panel detectado (cpanel)? [Y/n]: Y
```

### 2. Auto-Detección de Instalaciones de Moodle (NUEVO v3.4.0)
```
� DETECCIÓN AUTOMÁTICA DE MOODLE
¿Buscar automáticamente instalaciones de Moodle? [Y/n]: Y

📁 Instalación Moodle encontrada: /home/usuario/public_html
   • BD: usuario_moodle@localhost
   • URL: https://moodle.ejemplo.com  
   • Datos: /home/usuario/moodledata

✅ Configuración detectada automáticamente desde config.php
```

### 3. **Auto-Detección Inteligente de Sistema** ⭐ **NUEVO**
```
🔍 Iniciando detección automática...
[2025-01-15 10:30:15] [INFO] Ejecutando detección: panels
✅ Panel detectado: Apache 2.4.54 (2 sitios web encontrados)
[2025-01-15 10:30:16] [INFO] Ejecutando detección: moodle
✅ Instalación Moodle encontrada: /var/www/html/moodle
✅ Instalación Moodle encontrada: /home/cliente1/public_html/learning

📊 RESUMEN DE DETECCIÓN:
🌐 Sistema detectado:
  - Panel: Apache 2.4.54
  - Servidor Web: Apache (2 sitios web encontrados)
  - SO: Ubuntu 20.04 LTS

🎓 Instalaciones Moodle encontradas: 2
```

### 4. Selección Múltiple (Si hay varias instalaciones)
```
🎯 Instalaciones de Moodle encontradas:
  1. /home/usuario/public_html
     • BD: site1_moodle@localhost
     • URL: https://moodle1.ejemplo.com
     • Datos: /home/usuario/moodledata1
     
  2. /home/usuario/domains/curso.ejemplo.com/public_html
     • BD: site2_moodle@localhost
     • URL: https://curso.ejemplo.com
     • Datos: /home/usuario/moodledata2
     
  0. Especificar ruta manualmente

Seleccione una instalación [1-2] o 0 para manual: 1
```

### 4. Configuración Precompletada
```
📋 VALORES DETECTADOS DESDE CONFIG.PHP:
   • Host: localhost
   • Base de datos: usuario_moodle
   • Usuario: usuario_db
   • Contraseña: [detectada]

Puede confirmar estos valores o modificarlos según necesite:

Host de la base de datos [localhost]: ✓
Nombre de la base de datos [usuario_moodle]: ✓
Usuario de la base de datos [usuario_db]: ✓
```

### 5. Configuración de Contraseña Inteligente
```
¿Cómo prefieres configurar la contraseña?
1. Variable de entorno (MÁS SEGURO)
2. Archivo protegido /etc/mysql/backup.pwd (RECOMENDADO)
3. Ingresar ahora en texto plano (MENOS SEGURO)
4. Usar contraseña detectada desde config.php (RECOMENDADO) ⭐
5. Configurar más tarde

Selecciona opción (1-5) [4]: 4
✅ Usando contraseña detectada desde config.php
```

### 6. Configuración Simplificada e Inteligente
- **Placeholders inteligentes**: Rutas pre-completadas con información real del sistema
- **Navegación avanzada**: Edición completa con flechas y atajos de teclado  
- **Solo campos necesarios**: Se pregunta únicamente por campos que no se pueden detectar
- **Ejemplos dinámicos**: Cambian según el panel y usuario detectado
- **Validación inteligente**: Campos obligatorios según el contexto

#### 💡 Ejemplo de Placeholder Inteligente
```
Directorio web de Moodle:
(Usa las flechas ← → para navegar, Ctrl+A/E para inicio/fin)
Ingrese valor: /home/dev4hc/public_html  # ← Pre-completado con usuario real
```

### 1. Detección del Servidor
El sistema detecta automáticamente:
- **CPU**: Núcleos disponibles
- **RAM**: Memoria total
- **Espacio**: Disco libre
- **Recomendaciones**: Compresión y threads óptimos

### 2. Configuración por Secciones

#### 🏢 **Configuración Universal Multi-Panel**
- Tipo de panel: `auto`, `cpanel`, `plesk`, `directadmin`, `vestacp`, `ispconfig`, `manual`
- Auto-detección agresiva: búsqueda en todo el sistema
- Configuración de dominio (necesario para algunos paneles)

#### 👤 **Identificación del Cliente**
- Nombre único del cliente (sin espacios)
- Descripción amigable para logs y notificaciones

#### 🖥️ **Configuración del Servidor**
- Usuario del panel de control
- Directorios web y de datos (auto-detecta si se deja vacío)
- Directorio temporal para backups

#### 🗄️ **Base de Datos**
- Host, nombre y usuario (auto-detecta desde config.php)
- **Configuración segura de contraseña**:
  1. Variable de entorno (MÁS SEGURO)
  2. Archivo protegido (RECOMENDADO)
  3. Auto-detección desde config.php (RECOMENDADO)
  4. Texto plano (solo desarrollo)

#### ☁️ **Google Drive**
- Verificación automática de rclone
- Configuración asistida si es necesario
- Carpeta destino personalizable
- Número de backups a mantener

#### ⚡ **Rendimiento**
- Configuración **optimizada automáticamente** según servidor detectado
- Threads concurrentes recomendados
- Nivel de compresión óptimo
- Horario de mayor rendimiento configurable

#### 📧 **Notificaciones (OBLIGATORIO)**
- Email(s) para notificaciones (validación automática)
- Soporte para múltiples destinatarios

#### ⏰ **Programación (Cron)**
- **Frecuencias predefinidas**:
  - Diario
  - Cada 2 días
  - Semanal (domingos)
  - Quincenal (1° y 15 de cada mes)
  - Mensual (día 1)
  - Personalizado
- Hora de ejecución configurable
- Configuración automática del crontab

## 🎮 Uso del Sistema

### Comando Principal: `mb`

#### Menú Interactivo
```bash
mb
```

Muestra un menú interactivo con:
- Lista numerada de clientes configurados
- Estado visual de cada configuración
- Opciones de gestión

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                    MOODLE BACKUP V3 - GESTOR MULTI-CLIENTE                 ║
╚══════════════════════════════════════════════════════════════════════════════╝

CONFIGURACIONES DISPONIBLES:

 1. empresa_com     - Sitio principal empresa.com - 🟢 Activo
 2. cliente_dev     - Entorno de desarrollo - 🔴 Inactivo
 3. backup_test     - Servidor de pruebas - 🟢 Activo

OPCIONES DISPONIBLES:
  [1-3]  Ejecutar backup para cliente específico
  list   Mostrar lista de configuraciones
  on     Habilitar cron para un cliente
  off    Deshabilitar cron para un cliente
  status Ver estado de todos los clientes
  logs   Ver logs recientes
  help   Mostrar ayuda completa
  exit   Salir

Seleccione una opción:
```

#### Comandos Directos

##### Gestión de Cron
```bash
mb on empresa_com    # Habilitar cron para empresa_com
mb off empresa_com   # Deshabilitar cron para empresa_com
```

##### Información y Estado
```bash
mb list              # Listar todas las configuraciones
mb status            # Estado completo de todos los clientes
mb logs              # Ver logs recientes de un cliente específico
```

##### Ayuda
```bash
mb help              # Ayuda completa del sistema
```

## 🖥️ Paneles y Servidores Soportados

### 🎛️ **Paneles de Control**
| Panel           | Auto-detección | Multi-Cliente |  Estado  |                Detección                 |
| --------------- | :------------: | :-----------: | :------: | :--------------------------------------: |
| **cPanel**      |       ✅        |       ✅       | Completo |     `/usr/local/cpanel/bin/whmapi1`      |
| **Plesk**       |       ✅        |       ✅       | Completo |           `/opt/psa/bin/admin`           |
| **DirectAdmin** |       ✅        |       ✅       | Completo |   `/usr/local/directadmin/custombuild`   |
| **ISPConfig**   |       ✅        |       ✅       | Completo | `/usr/local/ispconfig/server/server.php` |
| **Webmin**      |       ✅        |       ✅       | Completo |           `/etc/webmin/config`           |
| **VestaCP**     |       ✅        |       ✅       | Completo |   `/usr/local/vesta/bin/v-list-users`    |
| **HestiaCP**    |       ✅        |       ✅       | Completo |   `/usr/local/hestia/bin/v-list-users`   |
| **CyberPanel**  |       ✅        |       ✅       | Completo |      `/usr/local/CyberCP/manage.py`      |
| **aaPanel**     |       ✅        |       ✅       | Completo |       `/www/server/panel/BT-Panel`       |

### 🌐 **Servidores Web** ⭐ **NUEVO**
| Servidor          | Auto-detección | Manual Config |  Estado  |           Detección            |
| ----------------- | :------------: | :-----------: | :------: | :----------------------------: |
| **Apache**        |       ✅        |       ✅       | ✨ Nuevo  | `/etc/httpd/`, `/etc/apache2/` |
| **Nginx**         |       ✅        |       ✅       | ✨ Nuevo  |         `/etc/nginx/`          |
| **OpenLiteSpeed** |       ✅        |       ✅       | ✨ Nuevo  |       `/usr/local/lsws/`       |
| **Manual**        |       ✅        |       ✅       | Completo |  Configuración personalizada   |

### 🔍 **Sistema de Auto-Detección Inteligente**
- **Prioridad 1**: Paneles de control (cPanel, Plesk, etc.)
- **Prioridad 2**: Servidores web independientes (Apache, Nginx, OLS)
- **Prioridad 3**: Instalaciones Moodle en rutas estándar
- **Prioridad 4**: Bases de datos y configuraciones

**📋 Rutas de Búsqueda Moodle (independientes del panel):**
- `/var/www`, `/var/www/html` (Apache/Nginx estándar)
- `/home/*/public_html` (usuarios cPanel/DirectAdmin)
- `/usr/local/apache/htdocs` (cPanel/WHM)
- `/opt/bitnami/apache2/htdocs` (Bitnami)
- `/srv/www` (SUSE/openSUSE)
- `/www` (OpenLiteSpeed)
- Directorio actual

## � Estructura de Archivos

```
/etc/moodle-backup/configs/
├── cliente1.conf           # Configuración cliente 1
├── cliente2.conf           # Configuración cliente 2
├── empresa_com.conf        # Configuración empresa
└── .cron_status           # Estado de cron de cada cliente

/usr/local/bin/
├── mb                     # Comando principal mejorado
└── moodle_backup.sh       # Script principal de backup

/var/log/
├── moodle_backup_cliente1.log    # Log específico cliente 1
├── moodle_backup_cliente2.log    # Log específico cliente 2
└── moodle_backup_empresa_com.log # Log específico empresa
```

## 🔐 Seguridad

### Contraseñas de Base de Datos
El sistema maneja las contraseñas de forma segura con múltiples opciones:

1. **Variable de entorno** (MÁS SEGURO):
   ```bash
   export MYSQL_PASSWORD="tu_password"
   ```

2. **Archivo protegido** (RECOMENDADO):
   ```bash
   echo "tu_password" | sudo tee /etc/mysql/backup.pwd
   sudo chmod 600 /etc/mysql/backup.pwd
   ```

3. **Auto-detección desde config.php** (RECOMENDADO):
   - Extrae credenciales directamente del archivo de configuración de Moodle
   - Sin almacenamiento adicional de contraseñas

### Permisos de Archivos
- Archivos de configuración: `600` (solo lectura del propietario)
- Directorio de configuraciones: `755`
- Logs: permisos restrictivos según el sistema

## 📊 Monitoreo

### Estado en Tiempo Real
```bash
mb status
```

Muestra para cada cliente:
- 📋 Descripción
- 🟢/🔴 Estado del cron (habilitado/deshabilitado)
- 🔄/⏸️ Estado de ejecución (ejecutándose/inactivo)
- 📅 Fecha del último backup
- 📝 Disponibilidad de logs

### Logs Detallados
```bash
mb logs
```

- Selección interactiva del cliente
- Opción de ver logs de todos los clientes
- Seguimiento en tiempo real con `tail -f`

# Diagnóstico completo del sistema
mb diagnose

# Ver estado de procesos y backups
mb status

# Ver logs recientes
mb logs [número_líneas]

# Ver ayuda completa
mb help

# Ejecutar diagnósticos del sistema
mb diagnose

# Ver versión del sistema
mb version
```

### 🔄 **Nueva Funcionalidad V3.0.5: Ejecución en Segundo Plano**

Por defecto, `mb` ejecuta el backup en **segundo plano** usando `nohup`, permitiendo que continúe aunque cierre la sesión SSH:

```bash
# Backup desatendido (continúa sin SSH)
mb

# Monitorear progreso en tiempo real
mb logs
mb status

# Backup interactivo (requiere sesión SSH activa)
mb interactive
```

**Convención de comandos:**
- **Comandos simples** (sin dash): Para uso cotidiano - `mb config`, `mb test`, `mb help`
- **Opciones avanzadas** (con dash): Para compatibilidad completa - `mb --help`, `mb --diagnose`, `mb --show-config`

### 📊 Comandos de Monitoreo

```bash
# Ver logs recientes del último backup
mb logs

# Ver más líneas de log
mb logs 50

# Ver estado del último backup con información del proceso
mb status

# Seguimiento en tiempo real
tail -f /var/log/moodle_backup.log

# Limpiar archivos temporales antiguos
mb clean
```

### 🔧 Comandos Avanzados (Compatibilidad)

```bash
# Opciones avanzadas con dash (compatibilidad completa)
mb --help             # Ayuda completa con todas las opciones
mb --diagnose         # Diagnósticos avanzados del sistema
mb --test-rclone      # Prueba específica de Google Drive
mb --show-config      # Configuración con validación completa
```

## 🔄 Ejecución en Segundo Plano (V3.0.5)

### ✨ Funcionalidad Principal

El sistema V3.0.5 ejecuta backups de forma **desatendida**, independiente de la sesión SSH:

```bash
# Backup automático (continúa aunque cierre SSH)
mb

# El sistema muestra:
🚀 Iniciando backup de Moodle en segundo plano...
📋 Logs del proceso: /var/log/moodle_backup.log
📋 Logs de sesión: /tmp/moodle_backup_session_*.log

✅ Backup iniciado en segundo plano (PID: 12345)
🔍 El proceso continuará aunque cierre la sesión SSH

Comandos útiles:
  mb logs     # Ver progreso en tiempo real
  mb status   # Estado actual
  ps -p 12345 # Verificar si el proceso sigue ejecutándose
```

### 📊 Monitoreo del Proceso

```bash
# Ver estado detallado
mb status
# Muestra:
# - PID del proceso activo
# - Estado de ejecución
# - Último backup exitoso/error
# - Archivos temporales
# - Últimas líneas del log

# Seguimiento en tiempo real
mb logs
tail -f /var/log/moodle_backup.log

# Verificar proceso manualmente
ps aux | grep moodle_backup
```

### 🎯 Casos de Uso

**Para Producción (Recomendado):**
```bash
mb                    # Ejecución desatendida
```

**Para Desarrollo/Debug:**
```bash
mb interactive        # Ver salida en tiempo real
```

**Para Monitoreo:**
```bash
mb status && mb logs  # Estado + logs recientes
```

## ⚙️ Configuración Multi-Cliente

El sistema soporta múltiples instalaciones de Moodle con configuraciones independientes:

```bash
# Usar configuración específica
mb --config /etc/moodle_backup_cliente1.conf

# Crear nueva configuración
cp /etc/moodle_backup.conf.example /etc/moodle_backup_cliente2.conf
# Editar el archivo según necesidades
mb --config /etc/moodle_backup_cliente2.conf --test
```

## �️ Reinstalación Segura

### ⚠️ IMPORTANTE: Backup Antes de Reinstalar

Los scripts de instalación **sobrescriben archivos principales** sin aviso. Para evitar perder tus configuraciones:

```bash
# 1. ANTES de reinstalar - Hacer backup automático
./backup-before-reinstall.sh

# 2. Reinstalar normalmente
curl -fsSL https://raw.githubusercontent.com/gzlo/moodle-backup/main/install.sh | bash

# 3. DESPUÉS de reinstalar - Restaurar configuraciones
~/moodle-backup-personal-XXXXXXXX/restore.sh

# 4. Verificar que todo funciona
mb config && mb test
```

### 📋 ¿Qué se Sobrescribe vs. Qué se Preserva?

**Se SOBRESCRIBEN (sin aviso):**
- ❌ `moodle_backup.sh` - Script principal
- ❌ `mb` - Wrapper de comandos
- ❌ `moodle_backup.conf.example` - Archivo de ejemplo

**Se PRESERVAN:**
- ✅ `moodle_backup.conf` - Tu configuración real
- ✅ Configuración de rclone (solo pregunta si reconfigurar)
- ✅ Alias de bash (solo agrega si no existe)

📖 **Guía completa**: Ver `REINSTALL_SAFELY.md` para el proceso detallado.

## �🚨 Solución de Problemas

### Problemas Comunes

**Error: "mysql command not found"**

```bash
# CentOS/RHEL/Fedora
sudo yum install mysql -y

# Ubuntu/Debian
sudo apt-get install mysql-client -y
```

**Error: "rclone not configured"**

```bash
# Configurar Google Drive
rclone config
# Seguir las instrucciones para crear remote "gdrive"
```

**Error: "Permission denied"**

```bash
# Verificar permisos de archivos
ls -la /usr/local/bin/moodle_backup.sh
chmod +x /usr/local/bin/moodle_backup.sh

# Verificar configuración
ls -la /etc/moodle_backup.conf
```

### Diagnósticos Avanzados

```bash
# Ejecutar diagnósticos completos
mb --diagnose

# Ver configuración detectada
mb --show-config

# Probar solo rclone
mb --test-rclone

# Ver logs detallados
tail -f /var/log/moodle_backup*.log
```

## 📁 Estructura del Proyecto

```
moodle-backup/
├── moodle_backup.sh              # Script principal
├── mb                             # Wrapper para comandos cortos
├── moodle_backup.conf.example     # Configuración de ejemplo
├── install.sh                     # Instalador local
├── web-install.sh                 # Instalador web (desde GitHub)
├── README.md                      # Documentación principal
├── INSTALACION_Y_USO.md          # Guía detallada de instalación
└── docs/
    ├── CONFIGURACION_AVANZADA.md  # Configuración avanzada
    ├── TROUBLESHOOTING.md         # Solución de problemas
    └── EJEMPLOS.md                # Ejemplos de uso
```

## 🔧 Configuración Avanzada

### Variables de Entorno Principales

```bash
# Información del cliente
CLIENT_NAME="mi_cliente"
CLIENT_DESCRIPTION="Backup Moodle Cliente"

# Configuración del panel
PANEL_TYPE="cpanel"              # auto, cpanel, plesk, directadmin, vestacp, manual
PANEL_USER="usuario"             # Usuario del panel (si aplica)

# Rutas principales
WWW_DIR="/home/user/public_html"
MOODLEDATA_DIR="/home/user/moodledata"

# Google Drive
GDRIVE_REMOTE="gdrive:moodle_backups"
MAX_BACKUPS_GDRIVE=2

# Configuración avanzada
AUTO_DETECT_AGGRESSIVE="true"    # Auto-detección agresiva
FORCE_THREADS=4                  # Número de hilos para compresión
```

### 🔐 Configuración Segura de Contraseñas

El sistema ofrece **4 métodos** para configurar la contraseña de la base de datos, priorizando la seguridad:

#### Método 1: Archivo Protegido (Recomendado)

```bash
# Crear archivo con permisos restrictivos
sudo mkdir -p /etc/mysql
sudo echo 'tu_password_aquí' > /etc/mysql/backup.pwd
sudo chmod 600 /etc/mysql/backup.pwd
sudo chown root:root /etc/mysql/backup.pwd
```

#### Método 2: Variable de Entorno

```bash
# Para sesión actual
export MYSQL_PASSWORD='tu_password_aquí'

# Para hacer permanente
echo "export MYSQL_PASSWORD='tu_password_aquí'" >> ~/.bashrc
```

#### Método 3: En Archivo de Configuración (Desarrollo)

```bash
# En moodle_backup.conf (menos seguro)
DB_PASS="tu_password_aquí"
```

#### ⚡ Configuración Automática

Durante la instalación, el sistema te permite:

- ✅ **Crear archivo protegido automáticamente** con permisos correctos
- ✅ **Configurar variable de entorno** para la sesión actual
- ✅ **Postergar configuración** con instrucciones detalladas
- ✅ **Verificar estado** de todas las configuraciones

```bash
# El instalador detecta y configura automáticamente
# Simplemente elige la opción más segura para tu entorno
```

### 📋 Orden de Prioridad de Contraseñas

El script busca la contraseña en este orden:

1. **Variable `DB_PASS`** en archivo de configuración
2. **Variable de entorno `MYSQL_PASSWORD`**
3. **Archivo `/etc/mysql/backup.pwd`**
4. **Auto-detección** desde `config.php` de Moodle

### 🔍 Verificar Configuración

```bash
# Verificar qué método está usando
mb --test

# Ver estado de configuración de contraseñas
mb --show-config | grep -A 10 "CONTRASEÑA"
OPTIMIZED_HOURS="02-08"          # Horas de menor carga
```

### Configuración de Cron

```bash
# Diario a las 2:00 AM
0 2 * * * /usr/local/bin/moodle_backup.sh >/dev/null 2>&1

# Semanal los domingos a las 3:00 AM
0 3 * * 0 /usr/local/bin/moodle_backup.sh >/dev/null 2>&1

# Multi-cliente
0 2 * * * /usr/local/bin/moodle_backup.sh --config /etc/moodle_backup_cliente1.conf >/dev/null 2>&1
0 3 * * * /usr/local/bin/moodle_backup.sh --config /etc/moodle_backup_cliente2.conf >/dev/null 2>&1
```

## 🆕 Nuevas Características V3.1

### 🔧 **Verificación Inteligente de Procesos**

El sistema V3.1 incluye mejoras significativas en el manejo de procesos:

#### ❌ **Problema Resuelto**: 
```
[ERROR] Ya hay una instancia de backup ejecutándose (PID: 3601852)
```

#### ✅ **Solución Implementada**:
- **Verificación real de PIDs**: Comprueba si el proceso realmente existe y es válido
- **Detección de antigüedad**: Procesos >2 horas se consideran colgados y se eliminan automáticamente  
- **Limpieza de lockfiles huérfanos**: Elimina archivos de bloqueo de procesos inexistentes
- **Manejo de señales**: Limpieza automática al interrumpir con Ctrl+C o señales del sistema

#### 🛡️ **Funcionalidades Anti-Cuelgue**:
```bash
# El sistema ahora hace automáticamente:
1. Verifica si el PID del lockfile existe realmente
2. Comprueba que corresponde al script de backup
3. Evalúa la antigüedad (>2h = proceso colgado)
4. Limpia automáticamente procesos problemáticos  
5. Continúa con el backup normalmente
```

#### 🔧 **Herramientas de Diagnóstico**:
```bash
# Diagnóstico mejorado con información de procesos
mb diagnose

# Ver procesos de backup activos
./cleanup_processes.sh --status

# Información detallada incluye:
# - PIDs en ejecución y su antigüedad
# - Estado de lockfiles (válidos/huérfanos)  
# - Procesos colgados detectados
# - Limpieza automática aplicada
```

#### ⚙️ **Multi-Cliente Mejorado**:
```bash
# Cada cliente tiene lockfiles independientes
CLIENT_NAME=cliente1 mb        # ✅ Independiente
CLIENT_NAME=cliente2 mb        # ✅ Independiente  
CLIENT_NAME=cliente3 mb        # ✅ Independiente

# Sin conflictos entre clientes múltiples
# Limpieza específica por cliente
# Verificación aislada por configuración
```

## 🛠️ Herramientas de Mantenimiento (V3.1)
