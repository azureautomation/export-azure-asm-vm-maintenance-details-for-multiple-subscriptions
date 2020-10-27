Add-AzureAccount  
$Subs = @()
$Subs = Get-AzureSubscription | Select-Object SubscriptionId, SubscriptionName, TenantID | Out-GridView -Title "Select Subscriptions (use Ctrl/Shift for multiples)" -PassThru
$VMs = @()

$DateFormat = "dd/MM/yyyy HH:mm"
$usCulture = [Globalization.CultureInfo]'en-US'
$KnownUTCDates=((Get-Date -Date "10 January  2018 00:00"),(Get-Date -Date "11 January  2018 00:00"),(Get-Date -Date "12 January  2018 00:00"),(Get-Date -Date "15 January  2018 00:00"))
$TZ = [System.TimeZoneInfo]::Local

foreach ($Sub in $Subs) {
    Select-AzureSubscription -SubscriptionId $sub.SubscriptionId

    $ASMVMs = Get-AzureVM
    $ASMServs = Get-AzureService
    $SubVMs = @()
    foreach ($ASMVM in $ASMVMs) {
        $Loc = ($ASMServs | Where-Object {$_.ServiceName -eq $ASMVMs.ServiceName}).Location
        $VMdet = new-object psobject -Property @{
            SubscriptionGuid = $($sub.SubscriptionId)
            SubscriptionName = $($sub.SubscriptionName)
            Name = $ASMVM.Name
            ServiceName = $ASMVM.ServiceName
            PowerState = $ASMVM.PowerState
            AvailabilitySetName = $ASMVM.AvailabilitySetName
            VMSize = $ASMVM.InstanceSize
            Location = $Loc
            CustomerInitiatedMaintenanceAllowed = $($ASMVM.MaintenanceStatus.IsCustomerInitiatedMaintenanceAllowed)
            PreMaintenanceWindowStartTime = if($ASMVM.PreMaintenanceWindowStartTime -ne $null) {[datetime]::Parse($ASMVM.PreMaintenanceWindowStartTime,$usCulture)} else {$null}
            PreMaintenanceWindowEndTime = if($ASMVM.PreMaintenanceWindowEndTime -ne $null) {[datetime]::Parse($ASMVM.PreMaintenanceWindowEndTime,$usCulture)} else {$null}
            MaintenanceWindowStartTime = if($ASMVM.MaintenanceWindowStartTime -ne $null) {[datetime]::Parse($ASMVM.MaintenanceWindowStartTime,$usCulture)} else {$null}
            MaintenanceWindowEndTime = if($ASMVM.MaintenanceWindowEndTime -ne $null) {[datetime]::Parse($ASMVM.MaintenanceWindowEndTime,$usCulture)} else {$null}
            LastOperationResultCode = $($ASMVM.MaintenanceStatus.LastOperationResultCode)
            LastOperationMessage = $($ASMVM.MaintenanceStatus.LastOperationMessage)
        }
        $SubVMs += $VMDet
    }
    if (($SubVMs.MaintenanceWindowStartTime |Sort-Object | Select-Object -First 1) -in $KnownUTCDates) {
        $UTCFlag = $true
        foreach ($VM in $SubVMs) {
            if ($VM.PreMaintenanceWindowStartTime -ne $null) {
                $VM.PreMaintenanceWindowStartTime = Get-Date -Date ([System.TimeZoneInfo]::ConvertTimeFromUtc($VM.PreMaintenanceWindowStartTime, $TZ)) -Format $DateFormat 
            }
            if ($VM.PreMaintenanceWindowEndTime -ne $null) {
                $VM.PreMaintenanceWindowEndTime = Get-Date -Date ([System.TimeZoneInfo]::ConvertTimeFromUtc($VM.PreMaintenanceWindowEndTime, $TZ)) -Format $DateFormat 
            }
            if ($VM.MaintenanceWindowStartTime -ne $null) {
                $VM.MaintenanceWindowStartTime = Get-Date -Date ([System.TimeZoneInfo]::ConvertTimeFromUtc($VM.MaintenanceWindowStartTime, $TZ)) -Format $DateFormat 
            }
            if ($VM.MaintenanceWindowEndTime -ne $null) {
                $VM.MaintenanceWindowEndTime = Get-Date -Date ([System.TimeZoneInfo]::ConvertTimeFromUtc($VM.MaintenanceWindowEndTime, $TZ)) -Format $DateFormat 
            }
        }
    } else {
        $UTCFlag = $false
    }
    $VMs += $SubVMs
}

$VMs  | `
    Select-Object SubscriptionGuid, SubscriptionName, `
        Name, ServiceName, PowerState, Location, `
        VMSize, CustomerInitiatedMaintenanceAllowed, `
        PreMaintenanceWindowStartTime, PreMaintenanceWindowEndTime, `
        MaintenanceWindowStartTime, MaintenanceWindowEndTime, `
        LastOperationResultCode, LastOperationMessage, `
        AvailabilitySetReference `
    | Export-Csv -Path "$($Env:Temp)\ASM_Maint_VMs.csv" -NoTypeInformation

Invoke-Item "$($Env:Temp)\ASM_Maint_VMs.csv"
