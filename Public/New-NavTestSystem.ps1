param (
    [Parameter(Mandatory)]
    [string] $name,
    [bool] $backupDestinationDatabase,
    [bool] $createQueriesOnly
)
Import-Module PsLibSqlQueries
Import-Module PsLibSqlTools
Import-Module PsLibConfigurationManager
Import-Module PsLibPowerShellTools

function Main {
    $config = Get-Configuration -configurationFile '.\New-NavTestSystem\config\New-NavTestSystem_config.json'

    $tempFolder = New-TemporaryDirectory 
    $execute = -not $createQueriesOnly

    $srcSystem = @($config.SourceSystem | Where-Object Architecture -EQ $dstSystem.Architecture)
    if ($srcSystem.Length -gt 1) {
        throw 'Es wurde mehr als eine Herkunftsdatenbank gefunden. Derzeit wird nur eine Datenbank unterstuetzt.'
    }

    $timeStamp = Get-Date -Format yyyyMMddThhmmss
    $backupLocation = $config.TransferBackupLocation + $srcSystem.Name + '_' + $timeStamp + '.bak'
    $dstBackupLocation = $config.DestinationBackupLocation + $dstSystem.Name + '_' + $timeStamp + '.bak'
    if ($backupDestinationDatabase) {
        New-BackupDatabaseSqlQuery -srcDatabaseName $dstSystem.DatabaseName -backupLocation $dstBackupLocation | Out-File "$tempFolder\00-BackupDestinationDatabase.sql" 
    }

    New-BackupDatabaseSqlQuery -srcDatabaseName $srcSystem[0].DatabaseName -backupLocation $backupLocation | Out-File "$tempFolder\01-BackupSourceDatabase.sql" 

    New-RestoreDatabaseSqlWithOverwriteQuery -dstDataSource $dstSystem.DataSource -dstDatabaseName $dstSystem.DatabaseName -backupLocation $backupLocation | Out-File "$tempFolder\02-RestoreIntoDestinationDatabase.sql" 

    New-ChangeDatabaseRecoveryModelSqlQuery -databaseName $dstSystem.DatabaseName -recoveryModel 'Simple' | Out-File "$tempFolder\03-AlterDatabaseRecoveryModel.sql" 

    if ($execute) {
        if ($backupDestinationDatabase) {
            Get-Content -Path "$tempFolder\00-BackupDestinationDatabase.sql" | Invoke-SQL -dataSource $dstSystem.DataSource -databaseName $dstSystem.DatabaseName
        }
        Get-Content -Path "$tempFolder\01-BackupSourceDatabase.sql" | Invoke-SQL -dataSource $srcSystem[0].DataSource -databaseName $srcSystem[0].DatabaseName
        Get-Content -Path "$tempFolder\02-RestoreIntoDestinationDatabase.sql" | Invoke-SQL -dataSource $dstSystem.DataSource -databaseName $dstSystem.DatabaseName
        Get-Content -Path "$tempFolder\03-AlterDatabaseRecoveryModel.sql" | Invoke-SQL -dataSource $dstSystem.DataSource -databaseName $dstSystem.DatabaseName

        WriteScriptOutput -execute $execute -backupDestinationDatabase $backupDestinationDatabase
    } else {
        Set-Location $tempFolder
        Invoke-Item .

        WriteScriptOutput -execute $execute -backupDestinationDatabase $backupDestinationDatabase
    }
}

function WriteScriptOutput {
    param(
        [bool] $execute,
        [bool] $backupDestinationDatabase
    )
    if ($execute) {
        Write-Verbose 'SQL scripts have been executed:'
    } else {
        Write-Verbose 'SQL scripts have been created:'
    }
    if ($backupDestinationDatabase) {
        Write-Verbose "$tempFolder\00-BackupDestinationDatabase.sql"
    }
    Write-Verbose "$tempFolder\01-BackupSourceDatabase.sql"
    Write-Verbose "$tempFolder\02-RestoreIntoDestinationDatabase.sql"
    Write-Verbose "$tempFolder\03-AlterDatabaseRecoveryModel.sql"
}

Main