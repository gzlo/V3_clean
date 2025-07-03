# 🚀 Roadmap - Modularización Moodle Backup CLI v3.5.0

> **Objetivo**: Transformar el sistema monolítico actual (3,014 líneas) en una arquitectura modular, escalable y mantenible para distribución open source.

## 📊 Resumen del Proyecto

- **Estado Actual**: Script monolítico `moodle_backup.sh` (3,014 líneas)
- **Estado Objetivo**: Sistema modular con 90% test coverage
- **Estrategia**: Desarrollo modular + Build system para single-file distribution
- **Timeline Estimado**: 12-15 días de desarrollo

---

## 🎯 Fases de Implementación

### 📋 **FASE 1: Setup Inicial y Fundamentos** (2-3 días)

#### 1.1 Estructura Base del Proyecto
- [ ] Crear estructura de carpetas completa según arquitectura definida
- [ ] Configurar `.gitignore` y archivos base del repositorio
- [ ] Crear `package.json` para dependencias de desarrollo (BATS, etc.)
- [ ] Setup inicial de documentación (`README.md`, `CONTRIBUTING.md`)

#### 1.2 Sistema de Build y CI/CD
- [ ] Implementar `scripts/build.sh` para generar single-file
- [ ] Crear `scripts/lint.sh` con shellcheck
- [ ] Configurar GitHub Actions para CI/CD (`.github/workflows/`)
  - [ ] Workflow de testing automático
  - [ ] Workflow de build y release
  - [ ] Workflow de generación de documentación
- [ ] Setup de herramientas de coverage (bashcov/kcov)

#### 1.3 Framework de Testing
- [ ] Instalar y configurar BATS (Bash Automated Testing System)
- [ ] Crear estructura base de tests (`tests/unit/`, `tests/integration/`)
- [ ] Configurar mocks básicos (`tests/mocks/`)
- [ ] Crear fixtures de testing (`tests/fixtures/`)
- [ ] Implementar script de testing principal (`tests/run-all-tests.sh`)

#### 1.4 Librerías Fundamentales
- [ ] **`lib/constants.sh`**: Constantes globales del sistema
- [ ] **`lib/utils.sh`**: Utilidades generales reutilizables
- [ ] **`lib/colors.sh`**: Sistema de colores y UI
- [ ] **`lib/filesystem.sh`**: Utilidades de manejo de archivos
- [ ] Tests unitarios para cada librería

---

### 🔧 **FASE 2: Módulos Core Transversales** (3-4 días)

#### 2.1 Sistema de Logging Avanzado
- [ ] **`src/core/logging.sh`**: Extraer y modularizar sistema de logging
  - [ ] Función `log()` con niveles (INFO, WARN, ERROR)
  - [ ] Rotación de logs automática
  - [ ] Logging a archivo y stdout simultáneo
  - [ ] Control de verbosidad configurable
- [ ] **Tests**: `tests/unit/core/test-logging.bats`
  - [ ] Test de escritura de logs
  - [ ] Test de rotación automática
  - [ ] Test de niveles de logging
  - [ ] Test de configuración de verbosidad

#### 2.2 Sistema de Configuración Externa
- [ ] **`src/core/config.sh`**: Sistema de configuración modular
  - [ ] Carga desde múltiples fuentes (archivos, env vars)
  - [ ] Validación de configuración
  - [ ] Expansión de variables
  - [ ] Configuración por defecto (fallback)
- [ ] **`config/defaults.conf`**: Configuración por defecto
- [ ] **`config/templates/`**: Templates por tipo de panel
- [ ] **Tests**: `tests/unit/core/test-config.bats`
  - [ ] Test de carga de configuración
  - [ ] Test de precedencia de configuración
  - [ ] Test de validación
  - [ ] Test de expansión de variables

#### 2.3 Sistema de Validación de Entorno
- [ ] **`src/core/validation.sh`**: Validación de entorno y dependencias
  - [ ] Validación de dependencias del sistema
  - [ ] Verificación de permisos
  - [ ] Validación de configuración
  - [ ] Diagnóstico de problemas
- [ ] **Tests**: `tests/unit/core/test-validation.bats`
  - [ ] Test de detección de dependencias
  - [ ] Test de verificación de permisos
  - [ ] Test de validación de paths

#### 2.4 Manejo de Procesos y Señales
- [ ] **`src/core/process.sh`**: Gestión de procesos y lockfiles
  - [ ] Prevención de ejecuciones concurrentes
  - [ ] Manejo de señales (SIGINT, SIGTERM, etc.)
  - [ ] Limpieza automática en exit
  - [ ] Gestión de procesos zombies
- [ ] **Tests**: `tests/unit/core/test-process.bats`
  - [ ] Test de lockfiles
  - [ ] Test de manejo de señales
  - [ ] Test de limpieza automática

#### 2.5 Bootstrap y Carga de Módulos
- [ ] **`src/core/bootstrap.sh`**: Inicialización del sistema
  - [ ] Carga ordenada de módulos
  - [ ] Validación de dependencias entre módulos
  - [ ] Configuración de entorno de ejecución
  - [ ] Manejo de errores de inicialización
- [ ] **Tests**: `tests/unit/core/test-bootstrap.bats`

---

### 🔍 **FASE 3: Sistema de Detección Automática** (2-3 días)

#### 3.1 Orquestador de Detección
- [ ] **`src/detection/auto-detector.sh`**: Controlador principal de detección
  - [ ] Coordinación de todos los detectores
  - [ ] Algoritmo de priorización
  - [ ] Cache de resultados de detección
  - [ ] Reporting de detección

#### 3.2 Detección de Paneles de Control
- [ ] **`src/detection/panels.sh`**: Detección de paneles de control
  - [ ] cPanel detection
  - [ ] Plesk detection
  - [ ] DirectAdmin detection
  - [ ] VestaCP/HestiaCP detection
  - [ ] ISPConfig detection
  - [ ] Docker/Manual detection
- [ ] **Tests**: `tests/unit/detection/test-panels.bats`
  - [ ] Test para cada tipo de panel
  - [ ] Test de detección fallback

#### 3.3 Detección de Instalaciones Moodle
- [ ] **`src/detection/moodle.sh`**: Auto-detección de Moodle
  - [ ] Búsqueda inteligente de instalaciones
  - [ ] Validación de config.php
  - [ ] Detección de múltiples instancias
  - [ ] Selección interactiva de instancia
- [ ] **Tests**: `tests/unit/detection/test-moodle.bats`
  - [ ] Test con múltiples config.php fixtures
  - [ ] Test de validación de Moodle válido

#### 3.4 Detección de Base de Datos
- [ ] **`src/detection/database.sh`**: Detección de configuración de BD
  - [ ] Parsing de config.php para datos de BD
  - [ ] Detección de tipo de BD (MySQL/PostgreSQL)
  - [ ] Validación de conexión
  - [ ] Extracción de credenciales
- [ ] **Tests**: `tests/unit/detection/test-database.bats`

#### 3.5 Detección de Directorios
- [ ] **`src/detection/directories.sh`**: Detección de paths críticos
  - [ ] Auto-detección de WWW_DIR
  - [ ] Auto-detección de MOODLEDATA_DIR
  - [ ] Detección de directorios específicos por panel
  - [ ] Validación de permisos de directorio
- [ ] **Tests**: `tests/unit/detection/test-directories.bats`

---

### 💾 **FASE 4: Sistema de Backup y Compresión** (3-4 días)

#### 4.1 Orquestador de Backup
- [ ] **`src/backup/orchestrator.sh`**: Coordinador principal de backup
  - [ ] Secuenciación de operaciones
  - [ ] Manejo de errores y rollback
  - [ ] Progress reporting
  - [ ] Coordinación de recursos

#### 4.2 Backup de Base de Datos
- [ ] **`src/backup/database.sh`**: Sistema de backup de BD
  - [ ] Backup MySQL con mysqldump optimizado
  - [ ] Backup PostgreSQL con pg_dump
  - [ ] Compresión de dumps (gzip/zstd)
  - [ ] Validación de integridad de dumps
- [ ] **Tests**: `tests/unit/backup/test-database.bats`
  - [ ] Test de backup MySQL
  - [ ] Test de backup PostgreSQL
  - [ ] Test de validación de integridad

#### 4.3 Backup de Archivos
- [ ] **`src/backup/files.sh`**: Sistema de backup de archivos
  - [ ] Backup de código Moodle (WWW_DIR)
  - [ ] Backup de datos Moodle (MOODLEDATA_DIR)
  - [ ] Exclusión de archivos temporales
  - [ ] Preservación de permisos y timestamps
- [ ] **Tests**: `tests/unit/backup/test-files.bats`

#### 4.4 Sistema de Snapshots
- [ ] **`src/backup/snapshots.sh`**: Creación de snapshots con hard links
  - [ ] Snapshots eficientes con hard links
  - [ ] Gestión de espacio en disco
  - [ ] Limpieza automática de snapshots
  - [ ] Verificación de integridad
- [ ] **Tests**: `tests/unit/backup/test-snapshots.bats`

#### 4.5 Sistema de Compresión Avanzada
- [ ] **`src/backup/compression.sh`**: Compresión optimizada
  - [ ] Compresión paralela con zstd
  - [ ] Compresión adaptativa según tamaño
  - [ ] Verificación de archivos comprimidos
  - [ ] Estimación de ratios de compresión
- [ ] **Tests**: `tests/unit/backup/test-compression.bats`
  - [ ] Test de diferentes algoritmos
  - [ ] Test de compresión paralela
  - [ ] Test de verificación de integridad

---

### ☁️ **FASE 5: Integración Cloud y Distribución** (2-3 días)

#### 5.1 Manager de Cloud Providers
- [ ] **`src/cloud/manager.sh`**: Gestión de proveedores cloud
  - [ ] Abstracción de proveedores
  - [ ] Configuración multi-provider
  - [ ] Failover entre proveedores
  - [ ] Métricas de rendimiento

#### 5.2 Integración Google Drive
- [ ] **`src/cloud/gdrive.sh`**: Integración específica Google Drive
  - [ ] Configuración de rclone
  - [ ] Verificación de credenciales
  - [ ] Gestión de cuotas
  - [ ] Creación de estructuras de carpetas
- [ ] **Tests**: `tests/unit/cloud/test-gdrive.bats`

#### 5.3 Sistema de Subida Robusto
- [ ] **`src/cloud/upload.sh`**: Sistema de subida con reintentos
  - [ ] Subida paralela de archivos
  - [ ] Reintentos inteligentes
  - [ ] Verificación de integridad post-subida
  - [ ] Progress reporting con ETA
- [ ] **Tests**: `tests/unit/cloud/test-upload.bats`

#### 5.4 Sistema de Limpieza y Retención
- [ ] **`src/cloud/cleanup.sh`**: Gestión de retención automática
  - [ ] Limpieza basada en políticas
  - [ ] Retención por fecha/cantidad
  - [ ] Verificación antes de eliminación
  - [ ] Reporting de espacio liberado
- [ ] **Tests**: `tests/unit/cloud/test-cleanup.bats`

---

### 🎮 **FASE 6: Integración Moodle y Notificaciones** (2 días)

#### 6.1 Integración Principal con Moodle
- [ ] **`src/moodle/integration.sh`**: Coordinador de operaciones Moodle
  - [ ] Detección de versión de Moodle
  - [ ] Verificación de compatibilidad
  - [ ] Coordinación de operaciones específicas

#### 6.2 Parser de Configuración Moodle
- [ ] **`src/moodle/config-parser.sh`**: Parser robusto de config.php
  - [ ] Parsing de sintaxis PHP compleja
  - [ ] Extracción de variables $CFG
  - [ ] Manejo de includes y configuración dinámica
  - [ ] Validación de configuración extraída
- [ ] **Tests**: `tests/unit/moodle/test-config-parser.bats`
  - [ ] Test con múltiples formatos de config.php
  - [ ] Test de configuraciones complejas

#### 6.3 Modo Mantenimiento
- [ ] **`src/moodle/maintenance.sh`**: Control de modo mantenimiento
  - [ ] Activación/desactivación segura
  - [ ] Backup de estado anterior
  - [ ] Verificación de estado
  - [ ] Rollback automático en errores
- [ ] **Tests**: `tests/unit/moodle/test-maintenance.bats`

#### 6.4 Verificación de Integridad
- [ ] **`src/moodle/integrity.sh`**: Verificación de integridad Moodle
  - [ ] Verificación de archivos core
  - [ ] Validación de base de datos
  - [ ] Detección de modificaciones
  - [ ] Reporting de estado

#### 6.5 Sistema de Notificaciones
- [ ] **`src/notifications/dispatcher.sh`**: Dispatcher de notificaciones
  - [ ] Gestión de múltiples canales
  - [ ] Templates de mensajes
  - [ ] Configuración de destinatarios
- [ ] **`src/notifications/email.sh`**: Notificaciones por email
  - [ ] Soporte SMTP/sendmail
  - [ ] Templates HTML/texto
  - [ ] Adjuntos de reportes
- [ ] **Tests**: `tests/unit/notifications/test-email.bats`

---

### 🔗 **FASE 7: Scripts Ejecutables y CLI** (1-2 días)

#### 7.1 Script Principal Modular
- [ ] **`bin/moodle-backup`**: Script principal que carga módulos
  - [ ] Carga dinámica de módulos necesarios
  - [ ] Parsing de argumentos avanzado
  - [ ] Help system contextual
  - [ ] Modo debug/verbose

#### 7.2 Wrapper Simplificado
- [ ] **`bin/mb`**: Wrapper corto para uso frecuente
  - [ ] Comandos simplificados más comunes
  - [ ] Auto-completado para bash/zsh
  - [ ] Aliases inteligentes

#### 7.3 Versión de Desarrollo
- [ ] **`bin/moodle-backup-dev`**: Versión para desarrollo
  - [ ] Carga módulos sin build
  - [ ] Modo debug automático
  - [ ] Hot reloading de módulos
  - [ ] Profiling de rendimiento

---

### 📦 **FASE 8: Sistema de Build y Release** (1-2 días)

#### 8.1 Build System
- [ ] **`scripts/build.sh`**: Generador de single-file
  - [ ] Concatenación inteligente de módulos
  - [ ] Resolución de dependencias
  - [ ] Optimización de código
  - [ ] Generación de checksums
- [ ] **Tests**: Validación de build generado

#### 8.2 Sistema de Release
- [ ] **`scripts/release.sh`**: Automatización de releases
  - [ ] Versionado automático
  - [ ] Generación de changelog
  - [ ] Creación de GitHub releases
  - [ ] Distribución multi-canal

#### 8.3 Instalador Público
- [ ] **`install/install.sh`**: Instalador público moderno
  - [ ] Descarga de latest release
  - [ ] Verificación de checksums
  - [ ] Instalación con permisos mínimos
  - [ ] Configuración post-instalación

#### 8.4 Sistema de Migración
- [ ] **`install/migrate.sh`**: Migración desde versiones anteriores
  - [ ] Detección de versión actual
  - [ ] Backup de configuración existente
  - [ ] Migración automática de configuración
  - [ ] Validación post-migración

---

### 🧪 **FASE 9: Testing Comprehensivo y QA** (2 días)

#### 9.1 Tests de Integración End-to-End
- [ ] **`tests/integration/test-full-backup.bats`**: Test completo de backup
  - [ ] Backup completo en entorno simulado
  - [ ] Verificación de todos los archivos generados
  - [ ] Validación de integridad end-to-end
- [ ] **`tests/integration/test-recovery.bats`**: Test de recuperación
  - [ ] Simulación de fallos en diferentes etapas
  - [ ] Verificación de rollback automático
  - [ ] Test de limpieza en errores

#### 9.2 Tests de Ambiente Multi-Panel
- [ ] **`tests/integration/test-multi-client.bats`**: Tests multi-cliente
  - [ ] Configuraciones simultáneas
  - [ ] Aislamiento entre clientes
  - [ ] Performance con múltiples instancias

#### 9.3 Tests de Performance y Stress
- [ ] **`tests/performance/`**: Suite de performance
  - [ ] Benchmarks de compresión
  - [ ] Tests de memoria con archivos grandes
  - [ ] Stress testing de subida cloud

#### 9.4 Cobertura de Testing (Objetivo: 90%)
- [ ] Configurar reporting de coverage automático
- [ ] Identificar gaps de coverage
- [ ] Implementar tests faltantes
- [ ] Validar coverage mínimo en CI/CD

#### 9.5 Documentación de Testing
- [ ] **`tests/README.md`**: Guía completa de testing
- [ ] Documentación de fixtures y mocks
- [ ] Guía para contribuyentes sobre testing

---

### 📚 **FASE 10: Documentación y Finalización** (1 día)

#### 10.1 Documentación Técnica
- [ ] **`docs/modules/`**: Documentación de cada módulo
  - [ ] API documentation para cada módulo
  - [ ] Ejemplos de uso y integración
  - [ ] Troubleshooting por módulo
- [ ] **`docs/api/`**: Referencia completa de API
- [ ] **`docs/examples/`**: Ejemplos prácticos

#### 10.2 Documentación de Usuario
- [ ] **`README.md`**: README principal actualizado
  - [ ] Instalación y setup
  - [ ] Uso básico y avanzado
  - [ ] FAQ y troubleshooting
- [ ] **`CONTRIBUTING.md`**: Guía para contribuciones
- [ ] **Documentación de configuración**: Todas las opciones disponibles

#### 10.3 Release Preparation
- [ ] **Validación final**: Testing completo de release candidate
- [ ] **Performance benchmarks**: Comparación con versión monolítica
- [ ] **Security review**: Validación de seguridad del código
- [ ] **Preparación de release notes**: Changelog detallado

---

## 📊 Métricas de Éxito

### Métricas Técnicas
- [ ] **Coverage de Testing**: Mínimo 90%
- [ ] **Tiempo de Build**: < 10 segundos
- [ ] **Tamaño del Bundle**: < 5MB (single-file)
- [ ] **Performance**: ±5% vs versión monolítica
- [ ] **Modularidad**: 100% de funciones movidas a módulos

### Métricas de Calidad
- [ ] **Shellcheck**: 0 warnings en todos los archivos
- [ ] **Documentación**: 100% de funciones públicas documentadas
- [ ] **Tests**: 0 tests failing en CI/CD
- [ ] **Compatibilidad**: Funciona en todos los paneles soportados

### Métricas de Usuario
- [ ] **Instalación**: Un solo comando de instalación
- [ ] **Configuración**: Auto-detección exitosa en 90% de casos
- [ ] **Usabilidad**: Comando `mb backup` funciona out-of-the-box
- [ ] **Troubleshooting**: Mensajes de error específicos y accionables

---

## 🎯 Hitos Principales

| Hito   | Descripción      | ETA    | Criterios de Aceptación                    |
| ------ | ---------------- | ------ | ------------------------------------------ |
| **M1** | Setup Completo   | Día 3  | Estructura, CI/CD, testing framework       |
| **M2** | Core Modules     | Día 7  | Logging, config, validation funcionando    |
| **M3** | Detection System | Día 10 | Auto-detección completa implementada       |
| **M4** | Backup System    | Día 13 | Backup completo funcionando modularmente   |
| **M5** | Release Ready    | Día 15 | Build system, 90% coverage, docs completas |

---

## 🚨 Riesgos y Mitigaciones

| Riesgo                           | Probabilidad | Impacto | Mitigación                              |
| -------------------------------- | ------------ | ------- | --------------------------------------- |
| **Regresiones de funcionalidad** | Media        | Alto    | Testing exhaustivo con casos reales     |
| **Performance degradation**      | Baja         | Medio   | Benchmarking continuo vs versión actual |
| **Complejidad de build**         | Baja         | Medio   | Keep it simple, documentación clara     |
| **Compatibilidad breaking**      | Media        | Alto    | Mantener API backward-compatible        |

---

## 💡 Notas de Implementación

### Principios de Desarrollo
- **DRY**: No duplicar lógica entre módulos
- **SOLID**: Responsabilidad única por módulo
- **Fail-fast**: Validación temprana y errores claros
- **Backward-compatible**: API compatible con v3.x

### Convenciones de Código
- **Naming**: `snake_case` para funciones, `UPPER_CASE` para constantes
- **Error handling**: Siempre usar `set -euo pipefail`
- **Documentation**: JSDoc-style comments para funciones públicas
- **Testing**: Al menos 3 test cases por función pública

### Git Workflow
- **Feature branches**: `feature/fase-X-descripcion`
- **Commits**: Conventional commits en español
- **PRs**: Revisión obligatoria antes de merge
- **Releases**: Tags semánticos (v3.5.0, v3.5.1, etc.)

---

**¿Todo listo para empezar? 🚀**

_Este roadmap será actualizado conforme avancemos en la implementación._
