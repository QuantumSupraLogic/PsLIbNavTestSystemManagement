param (
    [Parameter(Mandatory)]
    [string] $name,
    [bool] $backupDestinationDatabase,
    [bool] $createQueriesOnly
)
if (!Get-Module PsLibSqlQueries) {
    Import-Module PsLibSqlQueries
}
if (!Get-Module PsLibSqlTools) {
    Import-Module PsLibSqlTools
}
if (!Get-Module PsLibConfigurationManager) {
    Import-Module PsLibConfigurationManager
}
if (!Get-Module PsLibPowerShellTools) {
    Import-Module PsLibPowerShellTools
}
if (!Get-Module PsLibNavTools) {
    Import-Module PsLibNavTools
}

function Main {
    $config = Get-Configuration -configurationFile "$PSScriptRoot\config\New-NavTestSystem_config.json"

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

    New-BackupDatabaseSqlQuery -srcDatabaseName $srcSystem[0].DatabaseName -backupLocation $backupLocation -withCompression | Out-File "$tempFolder\01-BackupSourceDatabase.sql" 

    $dataPathNewDb = Get-DatabaseDataPath -dataSource $dstSystem.DataSource -databaseName $dstSystem.DatabaseName
    $logPathNewDb = Get-DatabaseLogPath -dataSource $dstSystem.DataSource -databaseName $dstSystem.DatabaseName
    New-RestoreDatabaseSqlWithOverwriteQuery -dstDataSource $dstSystem.DataSource -dstDatabaseName $dstSystem.DatabaseName -backupLocation $backupLocation -dataPathNewDb $dataPathNewDb -logPathNewDb $logPathNewDb | Out-File "$tempFolder\02-RestoreIntoDestinationDatabase.sql" 

    New-ChangeDatabaseRecoveryModelSqlQuery -databaseName $dstSystem.DatabaseName -recoveryModel 'SIMPLE' | Out-File "$tempFolder\03-PostProcessing.sql" 
    New-UseDatabaseQuery -databaseName $dstSystem.DatabaseName | Add-Content -Path "$tempFolder\03-PostProcessing.sql" 
    New-ShrinkDatabaseQuery -databaseName $dstSystem.DatabaseName | Add-Content -Path "$tempFolder\03-PostProcessing.sql" 
    foreach ($alterUser in $dstSystem.PostProcessing.AlterUser) {
        New-AlterUserQuery -userName $alterUser.User -login $alterUser.Login | Add-Content -Path "$tempFolder\03-PostProcessing.sql" 
    }
    foreach ($dropUser in $dstSystem.PostProcessing.DropUser) {
        New-DropUserQuery -userName $dropUser.User | Add-Content -Path "$tempFolder\03-PostProcessing.sql" 
    }
    foreach ($createUser in $dstSystem.PostProcessing.CreateUser) {
        New-CreateUserQuery -userName $createUser.User | Add-Content -Path "$tempFolder\03-PostProcessing.sql" 
    }
    foreach ($alterRole in $dstSystem.PostProcessing.AlterRole) {
        New-AlterRoleAddMemberQuery -userName $alterRole.AddMember -role $alterRole.Role | Add-Content -Path "$tempFolder\03-PostProcessing.sql" 
    }

    $PostProcessing | Add-Content -Path "$tempFolder\03-PostProcessing.sql" 
    
    if ($execute) {
        if ($backupDestinationDatabase) {
            Get-Content -Path "$tempFolder\00-BackupDestinationDatabase.sql" | Invoke-SQL -dataSource $dstSystem.DataSource -databaseName $dstSystem.DatabaseName
        }
        Get-Content -Path "$tempFolder\01-BackupSourceDatabase.sql" | Invoke-SQL -dataSource $srcSystem[0].DataSource -databaseName $srcSystem[0].DatabaseName
        Get-Content -Path "$tempFolder\02-RestoreIntoDestinationDatabase.sql" | Invoke-SQL -dataSource $dstSystem.DataSource -databaseName $dstSystem.DatabaseName
        Get-Content -Path "$tempFolder\03-PostProcessing.sql" | Invoke-SQL -dataSource $dstSystem.DataSource -databaseName $dstSystem.DatabaseName

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
    Write-Verbose "$tempFolder\03-PostProcessing.sql"
}

Main