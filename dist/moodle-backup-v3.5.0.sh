#!/bin/bash

# ===================== MOODLE BACKUP CLI - SINGLE FILE DISTRIBUTION =====================
# Version: 3.5.0
# Build Date: 2025-07-03 01:11:50
# Build Commit: a1c60fa
# Generated automatically from modular source code
# 
# Original repository: https://github.com/gzlo/moodle-backup-cli
# Documentation: https://github.com/gzlo/moodle-backup-cli/wiki
# 
# This file contains the complete Moodle Backup CLI system in a single executable.
# =====================================================================================


# ===================== BUILD METADATA =====================
readonly MOODLE_BACKUP_BUILD_VERSION="3.5.0"
readonly MOODLE_BACKUP_BUILD_DATE="2025-07-03 01:11:50"
readonly MOODLE_BACKUP_BUILD_COMMIT="a1c60fa"
readonly MOODLE_BACKUP_IS_SINGLE_FILE=true


# ===================== ENTRY POINT =====================
# Punto de entrada principal del sistema

# Si el script se ejecuta directamente (no se hace source)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Cargar configuración global
    main "$@"
fi
