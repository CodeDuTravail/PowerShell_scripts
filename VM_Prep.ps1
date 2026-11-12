<#
.SYNOPSIS
    Prépare une liste de VM pour le PRA : poweroff, renommage _PRA, NIC déconnectées, bascule sur un réseau isolé, vérification.

.DESCRIPTION
    Pour chaque VM de la liste :
      1. S'assure que la VM est PoweredOff
      2. Ajoute le suffixe _PRA au nom (idempotent : pas de double suffixe)
      3. Déconnecte les cartes réseau (sans les retirer, StartConnected = $false aussi)
      4. Positionne les cartes réseau sur le port group défini dans $TargetNetwork
      5. Vérifie (par le NOUVEAU nom) que les cartes sont bien sur le bon réseau et déconnectées
         -> les cartes ne sont reconnectées (StartConnected) que si -ConnectNics est passé ET que le check est OK.

.PARAMETER vCenter       FQDN/IP du vCenter
.PARAMETER VMListFile    Fichier texte : 1 nom de VM par ligne (lignes vides et # ignorées)
.PARAMETER Credential    Optionnel (sinon invite ou SSO)
.PARAMETER Graceful      Tente d'abord un Shutdown-VMGuest (VMware Tools) avant le Stop-VM forcé
.PARAMETER ConnectNics   Après check OK, active "Connect at power on" sur les cartes des VM validées
.PARAMETER IgnoreCert    Ignore les certificats vCenter invalides (session uniquement)

.EXAMPLE
    .\PRA_Prepare-VMs.ps1 -vCenter vcsa01.mondomaine.local -VMListFile .\vms.txt -Graceful
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$vCenter,
    [Parameter(Mandatory)][string]$VMListFile,
    [pscredential]$Credential,
    [switch]$Graceful,
    [switch]$ConnectNics,
    [switch]$IgnoreCert
)

# ======================= VARIABLES À ADAPTER =======================
$TargetNetwork     = 'DVS_NSX_ADMIN_Isole'   # Port group cible
$Suffix            = '_PRA'                  # Suffixe ajouté au nom des VM
$PowerOffTimeout   = 300                     # Secondes max d'attente du poweroff
$ReportPath        = Join-Path $PSScriptRoot ("PRA_Report_{0:yyyyMMdd_HHmmss}.csv" -f (Get-Date))
# ===================================================================

$ErrorActionPreference = 'Stop'
Start-Transcript -Path ($ReportPath -replace '\.csv$', '.log') | Out-Null

# --- Module PowerCLI -------------------------------------------------
if (-not (Get-Module -ListAvailable -Name VMware.PowerCLI)) {
    Write-Host "Installation du module VMware.PowerCLI..." -ForegroundColor Yellow
    Install-Module -Name VMware.PowerCLI -Scope CurrentUser -Force -AllowClobber
}
Import-Module VMware.PowerCLI -ErrorAction Stop
Set-PowerCLIConfiguration -Scope Session -ParticipateInCEIP $false -Confirm:$false | Out-Null
if ($IgnoreCert) {
    Set-PowerCLIConfiguration -Scope Session -InvalidCertificateAction Ignore -Confirm:$false | Out-Null
}

# --- Liste des VM ----------------------------------------------------
$VMNames = Get-Content -Path $VMListFile |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -and -not $_.StartsWith('#') } |
    Select-Object -Unique
if (-not $VMNames) { throw "Aucune VM dans $VMListFile" }

# --- Connexion vCenter -----------------------------------------------
$conn = @{ Server = $vCenter }
if ($Credential) { $conn.Credential = $Credential }
Connect-VIServer @conn | Out-Null

# --- Port group cible (choisi par VM si plusieurs DVS ont le même nom) -
$AllPG = @(Get-VDPortgroup -Name $TargetNetwork -ErrorAction SilentlyContinue)
if ($AllPG.Count -eq 0) {
    Disconnect-VIServer -Confirm:$false
    throw "Port group '$TargetNetwork' introuvable."
}
function Get-TargetPortgroup {
    param($VM)
    if ($AllPG.Count -eq 1) { return $AllPG[0] }
    $switches = Get-VDSwitch -VMHost $VM.VMHost | Select-Object -ExpandProperty Name
    $match = $AllPG | Where-Object { $_.VDSwitch.Name -in $switches } | Select-Object -First 1
    if (-not $match) { throw "Aucun '$TargetNetwork' sur un DVS de l'hôte $($VM.VMHost.Name)" }
    return $match
}

$Report   = New-Object System.Collections.Generic.List[object]
$NewNames = New-Object System.Collections.Generic.List[string]

# ===================== PHASES 1 à 4 (par VM) =========================
foreach ($name in $VMNames) {
    $status = [ordered]@{ VM = $name; NewName = ''; PowerOff = ''; Rename = ''; NicDisconnect = ''; Network = ''; Error = '' }
    try {
        # Retrouve la VM (nom d'origine, ou déjà renommée lors d'un run précédent)
        $vm = Get-VM -Name $name -ErrorAction SilentlyContinue
        if (-not $vm -and -not $name.EndsWith($Suffix)) {
            $vm = Get-VM -Name "$name$Suffix" -ErrorAction SilentlyContinue
        }
        if (-not $vm)          { throw "VM introuvable" }
        if (@($vm).Count -gt 1) { throw "Plusieurs VM portent ce nom" }

        # --- 1. Poweroff ---
        if ($vm.PowerState -ne 'PoweredOff') {
            Write-Host "[$($vm.Name)] Extinction..." -ForegroundColor Cyan
            if ($Graceful -and $vm.PowerState -eq 'PoweredOn' -and $vm.ExtensionData.Guest.ToolsRunningStatus -eq 'guestToolsRunning') {
                Shutdown-VMGuest -VM $vm -Confirm:$false | Out-Null
                $t = 0
                while ((Get-VM -Id $vm.Id).PowerState -ne 'PoweredOff' -and $t -lt 120) { Start-Sleep 5; $t += 5 }
            }
            if ((Get-VM -Id $vm.Id).PowerState -ne 'PoweredOff') {
                Stop-VM -VM $vm -Confirm:$false | Out-Null
            }
            $t = 0
            while ((Get-VM -Id $vm.Id).PowerState -ne 'PoweredOff') {
                if ($t -ge $PowerOffTimeout) { throw "Timeout poweroff" }
                Start-Sleep 3; $t += 3
            }
            $status.PowerOff = 'Eteinte'
        } else { $status.PowerOff = 'Deja eteinte' }
        $vm = Get-VM -Id $vm.Id

        # --- 2. Renommage ---
        if ($vm.Name.EndsWith($Suffix)) {
            $status.Rename = 'Deja suffixee'
        } else {
            $vm = Set-VM -VM $vm -Name ($vm.Name + $Suffix) -Confirm:$false
            $status.Rename = 'Renommee'
        }
        $status.NewName = $vm.Name
        $NewNames.Add($vm.Name)

        # --- 3. NIC déconnectées (conservées sur la VM) ---
        $nics = @(Get-NetworkAdapter -VM $vm)
        if ($nics.Count -eq 0) { throw "Aucune carte reseau sur la VM" }
        foreach ($nic in $nics) {
            Set-NetworkAdapter -NetworkAdapter $nic -StartConnected:$false -Connected:$false -Confirm:$false | Out-Null
        }
        $status.NicDisconnect = "$($nics.Count) NIC"

        # --- 4. Réseau cible ---
        $pg = Get-TargetPortgroup -VM $vm
        foreach ($nic in (Get-NetworkAdapter -VM $vm)) {
            Set-NetworkAdapter -NetworkAdapter $nic -Portgroup $pg -Confirm:$false | Out-Null
        }
        $status.Network = $TargetNetwork
        Write-Host "[$($vm.Name)] OK (poweroff, renommage, NIC deconnectees, reseau applique)" -ForegroundColor Green
    }
    catch {
        $status.Error = $_.Exception.Message
        Write-Warning "[$name] $($status.Error)"
    }
    $Report.Add([pscustomobject]$status)
}

# ===================== PHASE 5 : CHECK par nouveau nom ================
Write-Host "`n=== Verification par nouveau nom ===" -ForegroundColor Yellow
$Check = foreach ($newName in $NewNames) {
    $vm = Get-VM -Name $newName -ErrorAction SilentlyContinue
    if (-not $vm) {
        [pscustomobject]@{ VM = $newName; PowerState = 'N/A'; NIC = 'N/A'; Network = 'N/A'; Connected = 'N/A'; StartConnected = 'N/A'; OK = $false }
        continue
    }
    foreach ($nic in (Get-NetworkAdapter -VM $vm)) {
        $netOk  = ($nic.NetworkName -eq $TargetNetwork)
        $discOk = (-not $nic.ConnectionState.Connected) -and (-not $nic.ConnectionState.StartConnected)
        [pscustomobject]@{
            VM             = $vm.Name
            PowerState     = $vm.PowerState
            NIC            = $nic.Name
            Network        = $nic.NetworkName
            Connected      = $nic.ConnectionState.Connected
            StartConnected = $nic.ConnectionState.StartConnected
            OK             = ($netOk -and $discOk -and $vm.PowerState -eq 'PoweredOff')
        }
    }
}
$Check | Format-Table -AutoSize

# VM validées = toutes leurs NIC OK
$ValidVMs = $Check | Group-Object VM | Where-Object { ($_.Group.OK -notcontains $false) } | Select-Object -ExpandProperty Name
$BadVMs   = $Check | Group-Object VM | Where-Object { ($_.Group.OK -contains $false) } | Select-Object -ExpandProperty Name

if ($BadVMs) { Write-Warning ("VM en ECHEC au check : " + ($BadVMs -join ', ')) }

# --- Connexion des cartes (optionnel, uniquement si check OK) --------
if ($ConnectNics) {
    foreach ($n in $ValidVMs) {
        $vm = Get-VM -Name $n
        # VM éteinte : on active "Connect at power on" (la carte se connectera au démarrage)
        Get-NetworkAdapter -VM $vm | Set-NetworkAdapter -StartConnected:$true -Confirm:$false | Out-Null
        Write-Host "[$n] NIC : Connect at power on = True" -ForegroundColor Green
    }
} else {
    Write-Host "`nCartes laissees deconnectees (utiliser -ConnectNics pour les connecter apres check OK)." -ForegroundColor Yellow
}

# --- Rapport ---------------------------------------------------------
$Report | Export-Csv -Path $ReportPath -NoTypeInformation -Encoding UTF8 -Delimiter ';'
$Report | Format-Table -AutoSize
Write-Host "Rapport : $ReportPath"

Disconnect-VIServer -Server $vCenter -Confirm:$false
Stop-Transcript | Out-Null
