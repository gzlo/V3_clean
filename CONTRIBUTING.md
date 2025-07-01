# 🤝 Contribuir a Moodle Backup V3

¡Gracias por tu interés en contribuir al proyecto Moodle Backup V3! Este proyecto está diseñado para la comunidad Moodle y agradecemos todas las contribuciones.

## 📋 Cómo Contribuir

### 🐛 Reportar Errores

1. **Busca primero** en los [issues existentes](https://github.com/gzlo/moodle-backup/issues)
2. **Usa el template** de reporte de errores
3. **Incluye información del sistema**:
   - SO y versión
   - Panel de control (cPanel, Plesk, etc.)
   - Versión de Moodle
   - Logs relevantes

### ✨ Solicitar Funcionalidades

1. **Describe el caso de uso** claramente
2. **Explica el beneficio** para la comunidad
3. **Considera la compatibilidad** con diferentes paneles

### 🔧 Enviar Cambios

1. **Fork** el repositorio
2. **Crea una rama** descriptiva: `git checkout -b feat/nueva-funcionalidad`
3. **Sigue las convenciones** de código
4. **Incluye tests** si es posible
5. **Actualiza documentación**
6. **Envía un Pull Request**

## 🏗️ Estructura del Proyecto

```
moodle-backup/
├── moodle_backup.sh          # Script principal
├── mb                        # Wrapper para comandos simplificados
├── install.sh               # Instalador local
├── install-interactive.sh   # Instalador interactivo
├── web-install.sh          # Instalador web (curl | bash)
├── moodle_backup.conf.example # Ejemplo de configuración
├── README.md               # Documentación principal
├── CHANGELOG.md           # Historial de cambios
└── LICENSE               # Licencia MIT
```

## 📝 Convenciones de Código

### Bash/Shell
- **Usar `set -euo pipefail`** al inicio
- **Nombres descriptivos** para variables y funciones
- **Comentarios claros** para secciones complejas
- **Validación de parámetros** en funciones
- **Logging apropiado** con niveles INFO/WARN/ERROR

### Documentación
- **README actualizado** con nuevas funcionalidades
- **CHANGELOG con formato estándar**
- **Comentarios en código** para lógica compleja
- **Ejemplos prácticos** en documentación

## 🧪 Testing

### Entornos de Prueba
- **cPanel**: Hosting compartido
- **Plesk**: VPS
- **DirectAdmin**: Servidor dedicado
- **Manual**: Instalación directa

### Casos de Prueba
- **Auto-detección**: Diferentes estructuras de directorios
- **Configuración**: Variables de entorno vs archivo
- **Backup**: Diferentes tamaños de instalaciones
- **Recovery**: Restauración de archivos

## 📦 Versionado

Seguimos [Semantic Versioning](https://semver.org/):

- **MAJOR.MINOR.PATCH** (ej: 3.0.1)
- **MAJOR**: Cambios incompatibles
- **MINOR**: Nueva funcionalidad compatible
- **PATCH**: Correcciones de errores

## 🏷️ Commits

Usamos [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(instalador): agregar soporte para Rocky Linux
fix(backup): corregir permisos en archivos temporales
docs(readme): actualizar ejemplos de configuración
chore(deps): actualizar dependencias
```

## 🌟 Reconocimientos

### Mantenedores
- **Desarrollador Principal**: Sistema de desarrollo GZLOnline
- **Comunidad**: Contribuidores de la comunidad Moodle

### Tecnologías Utilizadas
- **Bash**: Script principal y herramientas
- **rclone**: Sincronización con Google Drive
- **MySQL/MariaDB**: Backup de base de datos
- **tar/zstd**: Compresión de archivos

## 📄 Licencia

Este proyecto está bajo la [Licencia MIT](LICENSE), lo que significa:

- ✅ **Uso comercial y privado**
- ✅ **Modificación y distribución**
- ✅ **Sublicenciamiento**
- ❗ **Sin garantía**
- ❗ **Incluir aviso de copyright**

## 🚀 Roadmap

### V3.1 (Próxima)
- [ ] Soporte para PostgreSQL
- [ ] Integración con webhooks
- [ ] Dashboard web básico
- [ ] Backup incremental

### V3.2 (Futuro)
- [ ] Soporte para Docker
- [ ] Backup a múltiples destinos
- [ ] Encriptación de backups
- [ ] API REST

## 💬 Comunidad

- **GitHub Issues**: Para reportes y discusiones técnicas
- **GitHub Discussions**: Para preguntas generales
- **Foro Moodle**: Para casos de uso específicos

## 🙏 Agradecimientos

Agradecemos a toda la comunidad Moodle por hacer posible este proyecto, especialmente a quienes han probado, reportado errores y sugerido mejoras.

---

**¿Tienes preguntas?** No dudes en abrir un issue o iniciar una discusión. ¡Estamos aquí para ayudar! 🤗
