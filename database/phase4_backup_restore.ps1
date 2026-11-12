# CASMS Phase 4 - MySQL backup + restore validation
# Run in Windows PowerShell. Requires MySQL 8.x mysql.exe and mysqldump.exe.
# Run AS YOURSELF; password is requested by the MySQL client, not stored here.
# Creates a fresh restore database; never deletes your live casms database.
$ErrorActionPreference = 'Stop'

$project = 'D:\KRISTU JAYNATI MCA\SEM I\ADBMS\CASMS'
$backupDir = Join-Path $project 'database\backups'
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

function Find-MySqlTool([string]$name) {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $path = "C:\Program Files\MySQL\MySQL Server 8.0\bin\$name.exe"
    if (Test-Path $path) { return $path }
    throw "Cannot locate $name. Add your MySQL Server bin folder to PATH."
}

$mysql = Find-MySqlTool 'mysql'
$dump = Find-MySqlTool 'mysqldump'
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupFile = Join-Path $backupDir "casms_$stamp.sql"
$restoreDb = "casms_restore_$stamp"

Write-Host "Creating: $backupFile"
Write-Host 'Enter the local MySQL administrator password when prompted.'
& $dump --user=root --password --host=localhost --port=3306 `
    --single-transaction --routines --triggers --events `
    --set-gtid-purged=OFF "--result-file=$backupFile" casms
if ($LASTEXITCODE -ne 0 -or !(Test-Path $backupFile)) {
    throw 'Backup failed. No restore attempted.'
}
if ((Get-Item $backupFile).Length -lt 1000) {
    throw 'Backup looks unexpectedly small. Stop and inspect it.'
}

Write-Host "Creating separate restore database: $restoreDb"
& $mysql --user=root --password --host=localhost --port=3306 `
    "--execute=CREATE DATABASE $restoreDb CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci"
if ($LASTEXITCODE -ne 0) { throw 'Restore database creation failed.' }

# SOURCE is handled by the mysql command-line client.
# Use forward slashes for the Windows filename with spaces.
$forwardPath = $backupFile.Replace('\','/')
Write-Host "Restoring $restoreDb from the backup. Password requested again."
& $mysql --user=root --password --host=localhost --port=3306 `
    "--database=$restoreDb" "--execute=source $forwardPath"
if ($LASTEXITCODE -ne 0) {
    throw "Restore failed. Main casms database is unchanged; inspect $restoreDb."
}

# Compare base-table record counts and important database objects.
$sql = @"
SELECT 'assets' AS metric,(SELECT COUNT(*) FROM casms.assets) AS original,
 (SELECT COUNT(*) FROM $restoreDb.assets) AS restored
UNION ALL SELECT 'service_requests',
 (SELECT COUNT(*) FROM casms.service_requests),
 (SELECT COUNT(*) FROM $restoreDb.service_requests)
UNION ALL SELECT 'maintenance_records',
 (SELECT COUNT(*) FROM casms.maintenance_records),
 (SELECT COUNT(*) FROM $restoreDb.maintenance_records)
UNION ALL SELECT 'maintenance_parts',
 (SELECT COUNT(*) FROM casms.maintenance_parts),
 (SELECT COUNT(*) FROM $restoreDb.maintenance_parts)
UNION ALL SELECT 'audit_log',
 (SELECT COUNT(*) FROM casms.audit_log),
 (SELECT COUNT(*) FROM $restoreDb.audit_log);
"@
Write-Host 'Compare ORIGINAL and RESTORED values (each row must match):'
& $mysql --user=root --password --host=localhost --port=3306 "--execute=$sql"
if ($LASTEXITCODE -ne 0) { throw 'Restore comparison query failed.' }
Write-Host "Finished. Backup: $backupFile"
Write-Host "Restored database: $restoreDb"
Write-Host 'Do not delete your main casms database. Keep the backup private.'
