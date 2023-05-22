function Copy-NavDatabase{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [psobject]
        $SourceSystem,
        [Parameter(Mandatory=$true)]
        [psobject] $DestinationSystem,
        [Parameter()]
        [switch]
        $silent

    )
    Process{

    }
}