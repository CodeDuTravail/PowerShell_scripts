# GLE.ps1 ###########################################################################################
Start-Transcript -path "D:\Maintenance\GLE\GLE.log"
Write-host -f Yellow "** Get Event Logs **"

$Started = (Get-date)

# LOCALISATION DES LOGS ###########################################################################################

$FolderName= $STARTED.ToString("yyyy-MM-dd")

$RootExportFolder = "\\NOM_DU_SHARE" # Emplacement du dépôt sur partage réseau
$ExportFolder = "$RootExportFolder\$FolderName" # Dossier d'export du jour sur partage réseau
$ExportLocalFolder = "D:\Maintenance\GLE\" # Emplacement du dépôt local

$ExportFile=$ExportFolder + "\" + "$env:COMPUTERNAME" + "_" + $Started.ToString("yyyy-MM-dd") + ".csv"
$ExportLocalFile=$ExportLocalFolder + "$env:COMPUTERNAME" + $Started.ToString("_yyyy_MM_dd") + ".csv"

############################################################################################

Set-Variable -Name EventAgeDays -Value 30       	 # Plage de jours à auditer
Set-Variable -Name LogNames -Value @("Security")     # Check du security log
Set-Variable -Name InstanceID -Value @("4624", "4800", "4801","4647")  # InstanceID de LogOn/LogOff

############################################################################################

$LogEventsCollector = @()   # Array de consolidation des logs
$startdate=$Started.adddays(-$EventAgeDays)

############################################################################################

  if ((Test-Path -Path $RootExportFolder) -like $True)
  {
    
          if ((Test-Path -Path $ExportFolder) -like $True)
          {Write-Host "Dossier d'export : $ExportFolder"}
          else
          {New-Item -ItemType "directory" -Path $ExportFolder}
  }

############################################################################################

  foreach($log in $LogNames)
  {
    Write-Host Processing $env:COMPUTERNAME\$log
    $EventLog = get-eventlog -ComputerName $env:COMPUTERNAME -log $log -After $startdate -InstanceID $InstanceID | Where-Object{$_.Message -notmatch "Type d'ouverture de session : [0|3|4|5|8|9|10]|wininit.exe|consent.exe|DWM-[1|2]|UMFD-[1|2]"}

    $EventLogFiltered = $EventLog | Select MachineName, InstanceID, EntryType, TimeGenerated, @{n='Action';e={if($_.InstanceID -like "4800"){"Lock"}elseif($_.InstanceID -like "4801"){"Unlock"}elseif($_.InstanceID -like "4624"){"Logon"}elseif($_.InstanceID -like "4647"){"Logoff"}}}, @{n='Compte';e={if($_.InstanceID -like "4624"){((([string]($_.Message)).split("`r`n").TrimStart()| select-string -simplematch "Nom du compte :") -replace "Nom du compte :","").Trimstart()}else{((([string]($_.Message)).split("`r`n").TrimStart()| select-string -simplematch "nom ") -replace "Nom du compte :","").Trimstart()}}}, @{n='SessionType';e={(([string]($_.Message)).split("`r`n,")| select-string -simplematch "Type d'ouverture de session :") -replace "Type d'ouverture de session :",""}}

    $LogEventsCollector += $EventLogFiltered  # Consolidation des logs
  }

$LogEventSorted = $LogEventsCollector | Sort-Object TimeGenerated    # Classement par temps

Write-Host Exporting to $ExportFile

$LogEventSorted | Select MachineName, TimeGenerated, InstanceID, Action, Compte | Export-CSV $ExportFile -NoTypeInfo    # EXPORT SHARE
$LogEventSorted | Select MachineName, TimeGenerated, InstanceID, Action, Compte | Export-CSV $ExportLocalFile -NoTypeInfo  # EXPORT LOCAL

Write-Host -f green "Done!"

$Stopped = (Get-date)
$TOTALTIME = "Temps d'éxécution : "+ (New-TimeSpan -Start $Started -End $Stopped).Minutes + ":" + (New-TimeSpan -Start $Started -End $Stopped).Seconds
$TOTALTIME
Stop-Transcript
