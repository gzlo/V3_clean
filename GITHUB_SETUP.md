# 📋 Instrucciones para Subir a GitHub

Este documento contiene las instrucciones paso a paso para subir el proyecto Moodle Backup V3 a GitHub y hacer que el instalador web funcione correctamente.

## 🔧 Preparación Inicial

### 1. Verificar Estructura del Proyecto

Asegúrate de que tienes todos los archivos necesarios:

```
moodle-backup-v3/
├── moodle_backup.sh              # Script principal ✅
├── mb                             # Wrapper para comandos cortos ✅
├── moodle_backup.conf.example     # Configuración de ejemplo ✅
├── install.sh                     # Instalador local ✅
├── web-install.sh                 # Instalador web (desde GitHub) ✅
├── README.md                      # Documentación principal ✅
├── INSTALACION_Y_USO.md          # Guía detallada ✅
├── LICENSE                        # Archivo de licencia (crear)
└── .gitignore                     # Archivo gitignore (crear)
```

### 2. Crear Archivos Faltantes

#### Archivo LICENSE (MIT)
```
MIT License

Copyright (c) 2025 GZLOnline

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

#### Archivo .gitignore
```
# Archivos de configuración locales
*.conf
!*.conf.example

# Logs
*.log
logs/

# Archivos temporales
*.tmp
*.temp
/tmp/

# Backups locales
backups/
*.sql
*.tar.gz
*.tar.zst

# Archivos de sistema
.DS_Store
Thumbs.db

# Configuraciones de IDE
.vscode/
.idea/
*.swp
*.swo

# Archivos de prueba
test_*
prueba_*
```

## 🚀 Pasos para Subir a GitHub

### 1. Crear Repositorio en GitHub

1. Ir a https://github.com
2. Hacer clic en "New repository"
3. Nombre: `moodle-backup-v3`
4. Descripción: `Sistema universal de backup para Moodle con soporte multi-panel`
5. ✅ Público
6. ❌ No agregar README (ya tenemos uno)
7. ❌ No agregar .gitignore (crearemos uno específico)
8. ✅ Agregar licencia MIT
9. Hacer clic en "Create repository"

### 2. Inicializar Git Local

```bash
# Ir al directorio del proyecto
cd /ruta/al/proyecto/moodle-backup-v3

# Inicializar repositorio git
git init

# Agregar archivos
git add .

# Primer commit
git commit -m "Initial commit: Moodle Backup V3 - Sistema Universal Multi-Panel

- Script principal con auto-detección multi-panel
- Instalador web automático desde GitHub
- Wrapper mb para comandos simplificados
- Configuración multi-cliente
- Soporte completo para cPanel, Plesk, DirectAdmin, VestaCP, ISPConfig
- Documentación completa y guías de instalación"

# Agregar remote de GitHub (reemplazar 'tu-usuario' con tu usuario)
git remote add origin https://github.com/tu-usuario/moodle-backup-v3.git

# Subir al repositorio
git branch -M main
git push -u origin main
```

### 3. Configurar Releases (Opcional pero Recomendado)

1. Ir a tu repositorio en GitHub
2. Hacer clic en "Releases"
3. Hacer clic en "Create a new release"
4. Tag version: `v3.0.0`
5. Release title: `Moodle Backup V3.0.0 - Universal Multi-Panel`
6. Descripción:
```markdown
## 🚀 Lanzamiento Moodle Backup V3.0.0

### ✨ Nuevas Características
- **Instalador web**: Instalación directa desde GitHub con un comando
- **Auto-detección multi-panel**: Soporte completo para cPanel, Plesk, DirectAdmin, VestaCP, ISPConfig
- **Configuración universal**: Se adapta automáticamente al entorno
- **Wrapper mb**: Comandos simplificados para uso diario
- **Multi-cliente**: Soporte para múltiples instalaciones Moodle

### 📦 Instalación Rápida
```bash
curl -fsSL https://raw.githubusercontent.com/tu-usuario/moodle-backup-v3/main/web-install.sh | bash
```

### 🔧 Características Técnicas
- Compresión zstd para máxima eficiencia
- Sincronización automática con Google Drive
- Sistema robusto de logging y diagnósticos
- Verificación de integridad de backups
- Soporte para CentOS/RHEL, Ubuntu/Debian, Fedora

Ver README.md para documentación completa.
```

### 4. Verificar Instalación Web

Una vez subido el repositorio, prueba que el instalador web funcione:

```bash
# Probar en un servidor de prueba
curl -fsSL https://raw.githubusercontent.com/tu-usuario/moodle-backup-v3/main/web-install.sh | bash

# O en modo automático
curl -fsSL https://raw.githubusercontent.com/tu-usuario/moodle-backup-v3/main/web-install.sh | bash -s -- --auto
```

## 🔧 Configuración Post-GitHub

### 1. Actualizar URLs en Archivos

Asegúrate de que todas las URLs en los archivos apunten al repositorio correcto:

#### En web-install.sh:
```bash
REPO_BASE_URL="https://raw.githubusercontent.com/tu-usuario/moodle-backup-v3/main"
```

#### En README.md:
```bash
curl -fsSL https://raw.githubusercontent.com/tu-usuario/moodle-backup-v3/main/web-install.sh | bash
```

### 2. Configurar GitHub Pages (Opcional)

1. Ir a Settings del repositorio
2. Ir a Pages
3. Source: Deploy from a branch
4. Branch: main
5. Folder: / (root)
6. Esto hará que la documentación esté disponible en:
   `https://tu-usuario.github.io/moodle-backup-v3/`

### 3. Configurar Issues Templates

Crear `.github/ISSUE_TEMPLATE/bug_report.md`:
```markdown
---
name: Bug report
about: Create a report to help us improve
title: '[BUG] '
labels: bug
assignees: ''
---

**Describe the bug**
A clear and concise description of what the bug is.

**Environment**
- OS: [e.g. CentOS 7, Ubuntu 20.04]
- Panel: [e.g. cPanel, Plesk, Manual]
- Moodle Version: [e.g. 4.1.2]

**To Reproduce**
Steps to reproduce the behavior:
1. Go to '...'
2. Click on '....'
3. Scroll down to '....'
4. See error

**Expected behavior**
A clear and concise description of what you expected to happen.

**Screenshots/Logs**
If applicable, add screenshots or log files to help explain your problem.
```

## 📝 Checklist Final

- [ ] ✅ Repositorio creado en GitHub
- [ ] ✅ Archivos subidos correctamente
- [ ] ✅ LICENSE agregado
- [ ] ✅ .gitignore configurado
- [ ] ✅ README.md actualizado con URLs correctas
- [ ] ✅ Instalador web probado desde GitHub
- [ ] ✅ Release v3.0.0 creado
- [ ] ✅ GitHub Pages configurado (opcional)
- [ ] ✅ Issues templates creados (opcional)

## 🎯 URLs Finales

Una vez completado todo:

- **Repositorio**: https://github.com/tu-usuario/moodle-backup-v3
- **Instalación directa**: 
  ```bash
  curl -fsSL https://raw.githubusercontent.com/tu-usuario/moodle-backup-v3/main/web-install.sh | bash
  ```
- **Documentación**: https://tu-usuario.github.io/moodle-backup-v3/ (si GitHub Pages está configurado)
- **Issues**: https://github.com/tu-usuario/moodle-backup-v3/issues

## 🔄 Mantenimiento

Para futuras actualizaciones:

```bash
# Hacer cambios en archivos
git add .
git commit -m "Descripción de los cambios"
git push

# Para nuevas versiones
git tag v3.0.1
git push --tags
```

¡El sistema está listo para ser usado por la comunidad! 🎉
