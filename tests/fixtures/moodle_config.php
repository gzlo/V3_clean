# Fixture: Configuración de Moodle de prueba
# Este archivo simula una configuración típica de config.php de Moodle

<?php
unset($CFG);
global $CFG;
$CFG = new stdClass();

// Database settings
$CFG->dbtype    = 'mariadb';
$CFG->dblibrary = 'native';
$CFG->dbhost    = 'localhost';
$CFG->dbname    = 'moodle_test';
$CFG->dbuser    = 'moodle_user';
$CFG->dbpass    = 'moodle_password';
$CFG->prefix    = 'mdl_';
$CFG->dboptions = array(
    'dbpersist' => 0,
    'dbport' => 3306,
    'dbsocket' => '',
    'dbcollation' => 'utf8mb4_unicode_ci',
);

// Web address
$CFG->wwwroot   = 'https://test.moodle.local';

// Data directory
$CFG->dataroot  = '/var/moodledata_test';

// Admin directory
$CFG->admin     = 'admin';

// Security
$CFG->directorypermissions = 0777;
$CFG->passwordsaltmain = 'test_salt_main_12345';

// Debug settings (for testing)
$CFG->debug = 0;
$CFG->debugdisplay = 0;

// Performance settings
$CFG->cachejs = true;
$CFG->cachecss = true;

// Additional test settings
$CFG->backup_auto_active = 1;
$CFG->backup_auto_weekdays = '0000001';
$CFG->backup_auto_hour = 2;
$CFG->backup_auto_minute = 30;

require_once(__DIR__ . '/lib/setup.php');
