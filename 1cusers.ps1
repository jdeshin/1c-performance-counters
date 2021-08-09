param (
    [switch]$RegisterCounters,
    [switch]$UnregisterCounters,
    [System.String]$ConnectionString,
    [System.String]$UserName,
    [System.String]$Password
)

$categoryName = "1C:Enterprise"
$categoryHelp = "1C:Enterprise performance counters"

$sessionsCounterHelp = "Total sessions count"
$sessionsCounterName = "Sessions Count"

$connectionsCounterHelp = "Total connections count"
$connectionsCounterName = "Connections Count"

$ErrorActionPreference = 'Stop'

if($UnregisterCounters) {
        Write-Host "Trying to unregister performance counters..."
        [System.Diagnostics.PerformanceCounterCategory]::Delete($categoryName)
        Write-Host "Performance counters were successfully unregistered"
        return
}

if (![System.Diagnostics.PerformanceCounterCategory]::Exists($categoryName)) {

    Write-Host "Trying to register performance counters..."
    $customCategory = new-object System.Diagnostics.PerformanceCounterCategory($categoryName)
    $collection = new-object System.Diagnostics.CounterCreationDataCollection

    $counterCreationData = new-object System.Diagnostics.CounterCreationData($sessionsCounterName, $sessionsCounterHelp, [System.Diagnostics.PerformanceCounterType]::NumberOfItems32)
    $collection.Add($counterCreationData) | Out-Null
        
    $counterCreationData = new-object System.Diagnostics.CounterCreationData($connectionsCounterName, $connectionsCounterHelp, [System.Diagnostics.PerformanceCounterType]::NumberOfItems32)
    $collection.Add($counterCreationData) | Out-Null
    
    [System.Diagnostics.PerformanceCounterCategory]::Create($categoryName, $categoryHelp, [System.Diagnostics.PerformanceCounterCategoryType]::SingleInstance, $collection) | Out-Null
    
    
    if ($RegisterCounters) {
        Write-Host "Performance counters were successfully registered"
        return
    }
}

$sessionsCountCounter = new-object System.Diagnostics.PerformanceCounter ($categoryName, $sessionsCounterName) 
$sessionsCountCounter.ReadOnly = $false

$connectionsCountCounter = new-object System.Diagnostics.PerformanceCounter ($categoryName, $connectionsCounterName) 
$connectionsCountCounter.ReadOnly = $false


if ($ConnectionString -ne "") {
    $Global:ConnectionString = $ConnectionString
}
else {
    $Global:ConnectionString = "tcp://localhost:1540"
}

$Global:UserName = $UserName
$Global:Password = $Password

function ConnectTo-1CServer() {

    $V8XCom = New-Object -COMObject "V83.COMConnector"

    $Global:ServerAgent = $V8XCom.ConnectAgent($Global:ConnectionString)

    $Clusters = $ServerAgent.GetClusters()
    $Global:Cluster = $Clusters[0]

    $Global:ServerAgent.Authenticate($Global:Cluster, $Global:UserName, $Global:Password)
} 

ConnectTo-1CServer

while($true) {
    try {
        $sessions = $Global:ServerAgent.GetSessions($Global:Cluster)
        $sessionsCountCounter.RawValue = $sessions.Count
        $connections = $Global:ServerAgent.GetConnections($Global:Cluster)
        $connectionsCountCounter.RawValue = $connections.Count

        Start-Sleep 1
    }
    catch {
        Start-Sleep 1
        try {
            ConnectTo-1CServer
        }
        catch {
        }
    }
}
