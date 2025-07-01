# 📋 Historial de Cambios - Moodle Backup V3

Todos los cambios importantes de este proyecto se documentan en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es/1.0.0/),
y este proyecto se adhiere al [Versionado Semántico](https://semver.org/lang/es/).

## [3.1.0] - 2025-07-01

### 🚀 MAJOR: Verificación Inteligente de Procesos y Limpieza Automática

#### ✨ Nuevas Características Principales
- **Verificación Inteligente de PIDs**: Función `validate_and_cleanup_running_processes()` que distingue entre procesos válidos y huérfanos
- **Limpieza Automática**: Eliminación automática de procesos colgados (>2 horas) y lockfiles huérfanos  
- **Manejo de Señales**: Sistema robusto de limpieza al recibir SIGINT, SIGTERM, SIGQUIT, SIGHUP
- **Script de Utilidad**: Nuevo `cleanup_processes.sh` para limpieza manual y diagnóstico

#### 🔧 Mejoras Técnicas
- **Lockfiles por Cliente**: Sistema de lockfiles específicos usando `${CLIENT_NAME}` para isolación multi-cliente
- **Verificación de Antigüedad**: Procesos >2 horas se consideran colgados y se eliminan automáticamente
- **Diagnóstico Mejorado**: Información detallada de procesos, PIDs y estado de lockfiles
- **Compatibilidad mb**: Integración perfecta con el sistema de gestión multi-cliente existente

#### 🛡️ Resolución de Problemas
- **Problema Resuelto**: Error `"Ya hay una instancia de backup ejecutándose (PID: XXXX)"` por procesos fantasma
- **Causa Identificada**: Procesos anteriores no terminados correctamente + lockfiles huérfanos
- **Solución Implementada**: Verificación inteligente que valida PIDs reales vs archivos obsoletos

#### 🎯 Funciones Agregadas
```bash
# Nueva función principal
validate_and_cleanup_running_processes()

# Manejo de señales
setup_signal_handlers()

# Limpieza al interrumpir
cleanup_on_signal()

# Script independiente
./cleanup_processes.sh [--status|--force|--help]
```

#### 💡 Beneficios Operacionales
- **Automatización Completa**: No requiere intervención manual para procesos colgados
- **Inteligencia**: Distingue procesos válidos de problemáticos usando antigüedad y validación real
- **Multi-Cliente**: Funciona perfectamente con `mb` y múltiples configuraciones de cliente
- **Robustez**: Previene problemas futuros con manejo adecuado de señales

#### 🔄 Flujo Mejorado
1. **Antes V3.0**: `pgrep` → encontrar proceso → ERROR y salida
2. **Ahora V3.1**: Verificar lockfile → validar PID real → comprobar antigüedad → limpiar si es necesario → continuar

#### ⚙️ Comandos de Uso
```bash
# Backup normal (con limpieza automática)
./mb

# Diagnóstico con información de procesos
./mb diagnose

# Limpieza manual si necesario
./cleanup_processes.sh --status
./cleanup_processes.sh --force

# Ver estado de lockfiles y procesos
./cleanup_processes.sh --status
```

#### 📦 Archivos Nuevos/Modificados
- ✅ `moodle_backup.sh`: Funciones de verificación y manejo de señales
- ✅ `cleanup_processes.sh`: Script de utilidad independiente
- ✅ Integración completa con sistema `mb` multi-cliente

## [3.0.5] - 2025-07-01

### 🚀 Mayor Mejora: Ejecución en Segundo Plano

#### ✨ Nueva Funcionalidad Principal
- **Ejecución Background**: Por defecto, `mb` ejecuta el backup en segundo plano usando `nohup`
- **Independencia SSH**: El proceso continúa aunque se cierre la sesión SSH
- **Modo Interactivo**: Nuevo comando `mb interactive` para ejecución en primer plano
- **Gestión de Procesos**: Sistema robusto de seguimiento y monitoreo de procesos

#### 🔧 Mejoras del Wrapper `mb`
- **Comando Mejorado**: `mb` → ejecución en segundo plano (recomendado)
- **Nuevo Comando**: `mb interactive` → ejecución en primer plano (modo legacy)
- **Estado Avanzado**: `mb status` muestra información detallada del proceso
- **Logs Mejorados**: `mb logs [número]` con opciones de líneas y seguimiento
- **PID Tracking**: Guardado automático de PID para seguimiento

#### 🛡️ Validación de Entorno
- **Nueva Función**: `validate_environment()` agregada para validación completa del sistema
- **Validaciones Críticas**: 
  - Permisos de lectura/escritura en directorios
  - Espacio en disco (mínimo 2GB)
  - Conectividad de base de datos
  - Memoria disponible (mínimo 1GB)
  - Procesos duplicados
- **Error Detallado**: Reportes específicos de problemas encontrados

#### 💡 Beneficios Operacionales
- **Confiabilidad**: Sin interrupciones por desconexiones SSH
- **Monitoreo**: Seguimiento completo del estado y progreso
- **Flexibilidad**: Opciones para diferentes escenarios de uso
- **Robustez**: Validaciones preventivas antes de ejecutar

#### 🎯 Casos de Uso
- **Producción**: `mb` para backups automáticos desatendidos
- **Desarrollo**: `mb interactive` para debugging y monitoreo directo
- **Monitoreo**: `mb status` y `mb logs` para seguimiento operacional

## [3.0.4] - 2025-07-01

### 🔄 Refactor: CPANEL_USER → PANEL_USER

#### ✨ Mejora de Nomenclatura Universal
- **Variable Renombrada**: `CPANEL_USER` → `PANEL_USER` para mayor claridad y universalidad
- **Compatibilidad Total**: Mantiene soporte completo para `CPANEL_USER` existente
- **Auto-migración**: Detección automática y migración transparente de configuraciones
- **Expansión de Variables**: Corregida expansión de `${CPANEL_USER}` y `${PANEL_USER}` en rutas

#### 🔧 Cambios Técnicos
- **Script Principal**: Actualizado `moodle_backup.sh` con nueva variable y compatibilidad
- **Instaladores**: Actualizados `install.sh` e `install-interactive.sh` 
- **Documentación**: Ejemplos en `moodle_backup.conf.example` y `README.md`
- **Función de Expansión**: Nueva función `expand_configuration_variables()` para variables anidadas

#### 🛡️ Compatibilidad y Migración
- **Sin Interrupciones**: Configuraciones existentes siguen funcionando sin cambios
- **Logs Informativos**: Mensajes claros cuando usa compatibilidad hacia atrás
- **Guía de Migración**: Nuevo archivo `MIGRATION_NOTICE.md` con instrucciones completas
- **Corrección de Errores**: Solucionado error de sintaxis en `install.sh`

#### 🎯 Beneficios
- **Claridad**: `PANEL_USER` es más descriptivo para todos los paneles de control
- **Universalidad**: No sugiere limitación solo a cPanel
- **Mantenibilidad**: Código más consistente y comprensible
- **Escalabilidad**: Mejor base para futuras expansiones multi-panel

## [3.0.3] - 2025-07-01

### 🐛 Corrección Crítica: Variables de Entorno Vacías

#### 🔧 Problema Resuelto
- **Variables Vacías en Producción**: Corregido problema crítico donde variables de entorno definidas pero vacías impedían la carga de configuración desde archivos
- **Síntomas Solucionados**: 
  - Variables mostraban `[]` en lugar de valores del archivo
  - Mensajes "Variable ya definida por entorno" incorrectos
  - Validaciones fallaban por variables requeridas vacías

#### ✨ Mejoras Implementadas
- **Función de Limpieza**: Nueva función `clean_empty_environment_variables()` que elimina variables problemáticas
- **Lógica Robusta**: Mejorada validación en `load_configuration()` usando `declare -p` para verificación
- **Orden Optimizado**: Secuencia corregida: limpia → carga archivo → aplica defaults
- **Validación Mejorada**: Uso de `-v` para detectar variables realmente no definidas

#### 🎯 Wrapper `mb` - Comandos Unificados
Se ha unificado y limpiado completamente el wrapper `mb` con una convención clara:

**Comandos Simples (sin dash)** - Para uso cotidiano:
```bash
mb                    # Ejecutar backup completo
mb config             # Ver configuración actual
mb test               # Probar conectividad
mb help               # Ver ayuda completa
mb diagnose           # Diagnóstico del sistema
mb version            # Ver versión
mb status             # Estado del último backup
mb logs               # Ver logs recientes
mb clean              # Limpiar archivos temporales
```

**Opciones Avanzadas (con dash)** - Para compatibilidad completa:
```bash
mb --help             # Ayuda completa con todas las opciones
mb --diagnose         # Diagnósticos avanzados
mb --test-rclone      # Prueba específica de Google Drive
mb --show-config      # Configuración con validación completa
```
#### 🔧 Mejoras de Documentación
- **README.md**: Actualizado con comandos unificados y convención clara
- **Estructura Clara**: Separación entre comandos simples y opciones avanzadas
- **Ejemplos Prácticos**: Incluidos ejemplos de uso común
- **Limpieza de Código**: Eliminada duplicación de funciones en el wrapper

#### 📁 Limpieza del Repositorio
- **Archivos Sensibles**: Eliminados archivos de configuración con datos reales
- **Archivos de Desarrollo**: Removidos scripts de prueba y validación temporal
- **gitignore Mejorado**: Añadidos patrones para archivos sensibles y temporales

### 🎯 Beneficios para la Comunidad
- **Instalación Simplificada**: Comandos más intuitivos y fáciles de recordar
- **Documentación Completa**: Guías claras para contribuidores y usuarios
- **Código Limpio**: Eliminada redundancia y mejorada la estructura

#### 🧪 Validación Completa
- ✅ Variables vacías se limpian automáticamente
- ✅ Configuración se carga desde archivo sin errores
- ✅ No hay más mensajes "variable ya definida" incorrectos
- ✅ Funciona en desarrollo y producción
- ✅ Retrocompatible con configuraciones existentes

## [3.0.2] - 2025-07-01

### 🐛 Corrección de Errores

#### 🔧 Instalador Web Corregido
- **Fix para BASH_SOURCE Variable**: Corregido error `BASH_SOURCE[0]: unbound variable` en línea 799
- **Compatibilidad con Pipe**: Mejorada compatibilidad cuando se ejecuta vía `curl | bash`
- **Detección de Contexto**: Agregada lógica para detectar si el script se ejecuta directamente o vía pipe
- **Manejo de Variables Seguro**: Implementada expansión de parámetros segura `${BASH_SOURCE[0]:-}`

#### 📋 Detalles Técnicos
- **Problema Original**: El flag `-u` de `set -euo pipefail` causaba fallo con variables no definidas
- **Contexto**: `BASH_SOURCE` puede no estar definida en algunos contextos de ejecución via pipe
- **Solución**: Uso de expansión de parámetros con valor por defecto y condición adicional
- **Compatibilidad**: Funciona tanto en ejecución directa como via `curl | bash`

#### 🎯 Impacto
- **Instalación Confiable**: El instalador web ahora funciona correctamente en todos los contextos
- **Sin Cambios Funcionales**: La corrección no afecta ninguna funcionalidad existente
- **Mejor Experiencia**: Eliminado el error que impedía la instalación automática

## [3.0.1] - 2025-06-29

### 🔒 Seguridad y Configuración Mejorada

#### ✨ Nuevas Funcionalidades
- **Configuración de Contraseñas Inteligente**: Sistema avanzado de configuración de contraseñas de BD con múltiples opciones de seguridad
- **Archivo Protegido Automático**: Creación automática de `/etc/mysql/backup.pwd` con permisos 600
- **Variable de Entorno Interactiva**: Configuración automática de `MYSQL_PASSWORD` durante la instalación
- **Verificación de Estado**: Detección inteligente del método de configuración utilizado en el resumen final

#### 🛠️ Mejoras en el Instalador
- **4 Opciones de Configuración**:
  1. Texto plano en archivo config (menos seguro - para desarrollo)
  2. Archivo protegido automático (recomendado)
  3. Variable de entorno con configuración opcional inmediata
  4. Configuración postpone con instrucciones detalladas
- **Detección de Permisos**: Verificación automática de permisos sudo para crear archivos protegidos
- **Fallback Inteligente**: Si no hay permisos, muestra instrucciones manuales claras
- **Validación de Configuración**: Verifica permisos del archivo creado (600)

#### 📋 Documentación Mejorada
- **Instrucciones Claras**: Comandos específicos listos para copiar y pegar
- **Priorización de Seguridad**: Destaca métodos más seguros con indicadores visuales
- **Resumen Inteligente**: Detecta automáticamente qué configuraciones necesitan atención
- **Estado de Contraseñas**: Muestra el estado actual de todas las configuraciones de BD

#### 🎨 Experiencia de Usuario
- **Indicadores Visuales**: Emojis y colores para destacar información importante
- **Opciones por Defecto**: Opción segura (archivo protegido) como predeterminada
- **Confirmación Visual**: Mensajes de éxito/error claros para cada operación
- **Recordatorios Persistentes**: Información importante visible en múltiples lugares

### 🔧 Mejoras Técnicas
- **Limpieza de Memoria**: Variables temporales de contraseñas se limpian inmediatamente
- **Verificación de Integridad**: Comprueba que los archivos se crearon con permisos correctos
- **Compatibilidad Multiplataforma**: Comandos `stat` funcionan en diferentes sistemas
- **Manejo de Errores Robusto**: Gestión granular de errores en cada opción

## [3.0.0] - 2025-01-29

### 🎉 Características Principales (Versión V3)

#### ✨ Nuevas Funcionalidades
- **Archivos Independientes**: Compresión y subida separada de database.sql.gz, moodle_core.tar.zst y moodledata.tar.zst
- **Multi-Panel Universal**: Soporte automático para cPanel, Plesk, DirectAdmin, VestaCP/HestiaCP, ISPConfig y instalaciones manuales
- **Auto-detección Inteligente**: Detección automática de paneles, directorios, usuarios y configuración de base de datos
- **Configuración Externa Obligatoria**: Sistema de configuración modular con archivos .conf externos
- **Multi-Cliente**: Soporte para múltiples clientes Moodle en el mismo servidor
- **Wrapper 'mb'**: Comandos cortos y alias para facilitar el uso
- **Instalador Web**: Instalación con un solo comando desde GitHub
- **Instalador Interactivo**: Configuración guiada paso a paso
- **Validación de Email Obligatoria**: Requiere al menos un email válido para notificaciones

#### 🛠️ Mejoras Técnicas
- **Logging Avanzado**: Sistema de logging granular con rotación automática
- **Validación Robusta**: Validación exhaustiva de configuración y directorios
- **Recuperación Inteligente**: Manejo de fallos parciales y reintento granular
- **Verificación de Integridad**: Validación individual por archivo
- **Retención por Carpetas**: Gestión de backups por fecha en Google Drive
- **Configuración Dinámica**: Adaptación automática según horarios y recursos

#### 🔒 Seguridad y Privacidad
- **Sin Emails Hardcodeados**: Eliminación completa de emails por defecto en el código
- **Configuración Obligatoria**: Validación de que existe al menos un email de notificación
- **Repo Público Preparado**: Código listo para publicación sin datos sensibles

#### 📦 Sistema de Instalación
- **install.sh**: Instalador automático básico
- **web-install.sh**: Instalador web desde GitHub con detección de entorno
- **install-interactive.sh**: Instalador interactivo con configuración guiada
- **Detección de Dependencias**: Instalación automática de rclone, zstd, y dependencias
- **Configuración de Cron**: Setup automático de tareas programadas

#### 📚 Documentación Completa
- **README.md**: Documentación principal con ejemplos
- **INSTALACION_Y_USO.md**: Guía detallada de instalación y uso
- **GITHUB_SETUP.md**: Instrucciones para configurar el repositorio en GitHub
- **PROYECTO_COMPLETADO.md**: Resumen del proyecto y funcionalidades
- **Ejemplos Multi-Panel**: Archivos de configuración para cada tipo de panel

### 🔄 Cambios desde V2

#### Agregado
- Sistema de archivos independientes para subida secuencial
- Auto-detección universal de paneles de control
- Configuración externa obligatoria con validación
- Soporte multi-cliente en el mismo servidor
- Instaladores automáticos e interactivos
- Wrapper 'mb' para comandos cortos
- Validación obligatoria de email de notificación
- Documentación exhaustiva y ejemplos

#### Cambiado
- Arquitectura de backup: de archivo único a archivos independientes
- Sistema de configuración: de variables internas a archivos externos
- Estructura de directorios en Google Drive: por fecha y cliente
- Logging: sistema más granular y con rotación
- Validación: más robusta y específica por panel

#### Removido
- Emails hardcodeados del código fuente
- Dependencia de configuración manual específica por servidor
- Archivos de backup únicos (mantenido por compatibilidad)

### 🛠️ Correcciones

#### Seguridad
- Eliminación de emails por defecto del código
- Validación obligatoria de configuración de notificaciones
- Preparación para repositorio público

#### Robustez
- Mejor manejo de fallos en subida secuencial
- Recuperación granular ante errores parciales
- Validación exhaustiva de directorios y configuración

#### Compatibilidad
- Soporte universal para diferentes paneles de control
- Auto-detección de configuraciones no estándar
- Fallback inteligente para instalaciones manuales

## [2.0.0] - 2025-01-28

### Agregado
- Sistema de snapshots con hard links (V2)
- Recuperación inteligente ante fallos
- Validación de conectividad con Google Drive
- Logging avanzado con timestamps
- Verificación de cuota antes del backup
- Optimización por horarios
- Configuración de rendimiento dinámica

### Cambiado
- Arquitectura base usando snapshots para eficiencia
- Sistema de logging más robusto
- Manejo de errores mejorado

## [1.0.0] - 2025-01-27

### Agregado
- Funcionalidad básica de backup Moodle
- Compresión con zstd
- Subida a Google Drive con rclone
- Backup de base de datos MySQL
- Sistema básico de logging
- Configuración básica de variables

---

## 🎯 Próximas Versiones

### Planificado para v3.1.0
- Soporte para bases de datos PostgreSQL
- Backup incremental opcional
- Interfaz web de monitoreo
- Integración con webhooks
- Soporte para múltiples proveedores de almacenamiento

### En Consideración
- Backup de configuraciones de servidor
- Restauración automática desde backups
- Métricas y dashboards
- Integración con sistemas de monitoreo (Zabbix, Nagios)
- Soporte para Docker y Kubernetes

---

## 📝 Notas de Versión

### Compatibilidad
- **V3.x**: Compatible con todas las versiones de Moodle 3.9+
- **Paneles**: cPanel, Plesk, DirectAdmin, VestaCP, HestiaCP, ISPConfig
- **SO**: Ubuntu 18.04+, CentOS 7+, Debian 9+, RHEL 7+

### Migración desde Versiones Anteriores
- **V2 → V3**: Migración automática con `install.sh --upgrade`
- **V1 → V3**: Reconfiguración necesaria, usar `install-interactive.sh`

### Dependencias
- **Requeridas**: bash 4.0+, rclone 1.53+, zstd, mysql-client
- **Opcionales**: cpanel-cli, plesk-cli, directadmin-tools

---

**Nota**: Para ver cambios detallados de cada versión, revisar los commits en el repositorio de GitHub.
