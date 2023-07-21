if (-not (Get-Module PsLibConfigurationManager)) {
    Import-Module PsLibConfigurationManager
}
$config = Get-Configuration -configurationFile "$PSScriptRoot\config\New-NavTestSystem_config.json"

Write-Host 'Bitte waehlen Sie das System, das neu aufgebaut werden soll:'
$i = 0
foreach ($DestinationSystem in $config.DestinationSystem) {
    $i += 1
    Write-Host $i ': ' $DestinationSystem.DisplayName
}
Write-Host 'Strg-C : Abbruch'

$choice = Read-Host '> '

if ($choice -notin 1..$i) {
    throw "Ungueltige Auswahl: $choice. Abbruch."
}

$createQueriesOnly

Write-Host 'Moechten Sie die Aenderungen [d]urchfuehren oder SQL-Scripts [e]rstellen?'
$choice2 = Read-Host '> ' 
switch ($choice2.ToLower()) {
    'd' {
        $createQueriesOnly = $false
    }
    'e' {
        $createQueriesOnly = $true
    }
    default {
        throw "Ungueltige Auswahl: $choice2. Abbruch."
    }
}

$backupDestinationDatabase

Write-Host 'Soll ein Backup der Zieldatenbank durchgefuehrt werden (j/n)?'
$choice2 = Read-Host '> ' 
switch ($choice2.ToLower()) {
    'j' {
        $backupDestinationDatabase = $true
    }
    'n' {
        $backupDestinationDatabase = $false
    }
    default {
        throw "Ungueltige Auswahl: $choice2. Abbruch."
    }
}

$dstSystem = $config.DestinationSystem[$choice - 1]
$srcSystem = @($config.SourceSystem | Where-Object Architecture -EQ $dstSystem.Architecture)

if ($srcSystem.Length -gt 1) {
    throw 'Es wurde mehr als eine Herkunftsdatenbank gefunden. Derzeit wird pro Architektur nur eine Datenbank unterstuetzt.'
}

if ($dstSystem.Architecture -notin 'NAV09', 'NAV2017') {
    throw "Nicht unterstuetzte Architektur gefunden: $dstSystem.Architecture. Unterstuetzte Architekturen: NAV09, NAV2017."
}

.\New-NavTestSystem\New-NavTestSystem.ps1 -name $dstSystem.Name -backupDestinationDatabase $backupDestinationDatabase -createQueriesOnly $createQueriesOnly