# Fix: Error "N: command not found" en instalador web

## Problema identificado

El error `-bash: N: command not found` ocurría cuando el usuario ejecutaba el instalador desde una tubería (como `curl | bash`) y respondía "N" a la pregunta sobre reconfigurar Google Drive.

## Causa del problema

1. **Ejecución desde tubería**: Cuando el script se ejecuta con `curl | bash`, la entrada estándar (stdin) está siendo utilizada por la tubería, no por el terminal del usuario.
2. **Conflicto de entrada**: El comando `read` no podía acceder al teclado del usuario, causando que la respuesta "N" fuera interpretada como un comando de bash.

## Soluciones implementadas

### 1. Función `safe_read()`
- Implementada función segura para leer entrada del usuario
- Usa `/dev/tty` para acceder directamente al terminal
- Fallback a valores por defecto si no puede leer entrada
- Manejo robusto de errores de entrada

### 2. Detección automática de tubería
- Función `detect_pipe_execution()` que detecta si el script se ejecuta desde tubería
- Activación automática del modo `--auto` cuando se detecta tubería sin parámetros explícitos
- Opción de forzar modo interactivo con `--interactive`

### 3. Mejoras en el manejo de entrada
- Todas las llamadas `read -r` reemplazadas por `safe_read()`
- Valores por defecto definidos para todas las preguntas
- Manejo consistente de respuestas vacías

## Uso correcto después del fix

### Instalación automática (recomendada para curl | bash)
```bash
curl -fsSL https://raw.githubusercontent.com/gzlo/moodle-backup/main/web-install.sh | bash
# O con parámetro explícito
curl -fsSL https://raw.githubusercontent.com/gzlo/moodle-backup/main/web-install.sh | bash -s -- --auto
```

### Instalación interactiva
```bash
# Descargar y ejecutar localmente
wget https://raw.githubusercontent.com/gzlo/moodle-backup/main/web-install.sh
chmod +x web-install.sh
./web-install.sh

# O forzar modo interactivo desde tubería
curl -fsSL https://raw.githubusercontent.com/gzlo/moodle-backup/main/web-install.sh | bash -s -- --interactive
```

## Opciones disponibles

- `--auto`: Instalación completamente automática sin preguntas
- `--interactive`: Modo interactivo con preguntas al usuario  
- `--skip-deps`: Omitir instalación de dependencias
- `--skip-rclone`: Omitir configuración de rclone
- `--skip-cron`: Omitir configuración de cron
- `--help`: Mostrar ayuda

## Pruebas

Ejecutar `./test-install.sh` para ver comandos de prueba y verificar el funcionamiento.
