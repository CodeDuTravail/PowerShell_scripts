<# VMware_SSH_PW_TMP_DNS_Certs.ps1 # v1.5 # 3/11/2023 ############################################################

IMPORT : Modules & Fonctions. 

import-module ("$Path_Fonctions" + "Credits_Mgmt_XML.psm1")
import-module ("$Path_Fonctions" + "Output_to_O365.psm1")
import-module "Posh-SSH"
import-module "DellOpenManage"

Export_To_o365

--------------------------------------------------------------------

OUTPUT : Log files for SSH, Export O365 & Mail Alert.

$Log_File       = $Path_Log + $VC + "_ESXi_PW_Check_$REPORT_DATE.txt"
$Log_SSH_OK     = $Path_Log + $VC + "_PW_Check_SSH_OK.txt"
$Log_SSH_FAILED = $Path_Log + $VC + "_PW_Check_SSH_FAILED.txt"
EXPORT O365 TEST : https://my.sharepoint.com/:x:/r/personal/username_domain_com/Documents/SSH_PW_Check.xlsx

--------------------------------------------------------------------

Mail options to configure in Build mail section :

# BUILD MAIL ########################################################

$SmtpServer = "smtp_server@domain.com"
$From = "VMware Supervision <VMwareSupervision@domain.com>"

$To1  = "L3_virtualization_team@domain.com"
$To2  = "L4_VMware_admins@domain.com"
$To3  = "Team_Manager@domain.com"


--------------------------------------------------------------------
Pour le warning SSL/TLS des vCenters aux certificats autosignés : 
Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $true -DefaultVIServerMode Multiple -InvalidCertificateAction Ignore -Confirm:$false

En cas d'échec de négociation SSH
Get-SSHTrustedHost | Remove-SSHTrustedHost
Get-SSHTrustedHost | where HostName -Like "SERVER_NAME*" | Remove-SSHTrustedHost
--------------------------------------------------------------------



# PATH CONF ##############################################################>

$STARTED = (Get-date)

$Path_Script         = Split-Path $MyInvocation.MyCommand.Path
$Path_Niveau_1	     = Split-Path -Parent $Path_Script
$Path_de_Base        = Split-Path -Parent $Path_Niveau_1
$Nom_du_ScriptFull   = Split-Path -Leaf $MyInvocation.MyCommand.Definition
$Extension_Script    = $Nom_du_ScriptFull.SubString( ( $Nom_du_ScriptFull.Length )-3,3 )
$Nom_du_Script       = $Nom_du_ScriptFull.SubString( 0, ( ($Nom_du_ScriptFull.Length )-4) )
$Path_Log            = $Path_Niveau_1 + "\Logs\" + $Nom_du_Script + "\"
$Path_Inputs         = $Path_Niveau_1 + "\InPuts\"
$Path_OutPuts        = $Path_Niveau_1 + "\OutPuts\"
$Path_Fonctions      = $Path_Niveau_1 + "\Fonctions\"
$Path_Credits        = $Path_Inputs + "Creds\"

if((test-path $Path_Log) -like $False){New-Item -ItemType Directory -Force -Path $Path_Log}

$REPORT_DATE = [string](Get-date -format yyyy_MM_dd)

# EXPORT 0365 CONF #############################################################

$Global:Owner        = "username@domain.com"
$Global:fileId       = "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX" 

$configfile = "$Path_Niveau_1\InPuts\Graph\conf\config.json"
$global:config = convertFrom-Json ([string](gc $configfile))
$global:clientId = secu.de64 ($config.office365.oauth2.id)
$global:clientSecret = secu.de64 ($config.office365.oauth2.secret) 
$Global:TenantName = $config.office365.oauth2.tenantName
$Global:TenantId = $config.office365.oauth2.tenantId

$Global:Tab = @()

# BUILD MAIL ########################################################

$SmtpServer = "smtp_server@domain.com"
$From = "VMware Supervision <VMwareSupervision@domain.com>"

$To1  = "L3_virtualization_team@domain.com"
$To2  = "L4_VMware_admins@domain.com"
$To3  = "Team_Manager@domain.com"

# IMPORT MODULES ##############################################################>

import-module "Posh-SSH"
import-module ("$Path_Fonctions" + "Output_to_O365.psm1")
import-module ("$Path_Fonctions" + "Credits_Mgmt_XML.psm1")

# CREDENTIALS #############################################################>

Credits_Get -filename "VCA"
$VCA_user = $GRUT
$VCA_Pass = $PW_SS
$VCA_Credits = New-Object System.Management.Automation.PSCredential -ArgumentList $VCA_user, $VCA_Pass

Credits_Get -filename "VC"
$VC_User = $GRUT
$VC_Pass = $PW_SS
$VC_Credits = New-Object System.Management.Automation.PSCredential -ArgumentList $VC_user, $VC_Pass

Credits_Get -filename "ESXi"
$ESXi_User = $GRUT
$ESXi_Pass = $PW_SS
$ESXi_Credits = New-Object System.Management.Automation.PSCredential -ArgumentList $ESXi_user, $ESXi_Pass

# CREDENTIALS #############################################################>

$VC = ""

if ($VC -like ""){$VCs = @("VC1","VC2","VC3","VC4")}
else
{
	Switch ($VC)
	{
			"VC1"   { $global:vCenter = "VC1.domain.com" }
			"VC2"   { $global:vCenter = "VC2.domain.com" }
			"VC3"   { $global:vCenter = "VC3.domain.com" }
			"VC4"   { $global:vCenter = "VC4.domain.com" }		
	}
	$VCs = $VC
}


foreach ($VC in ($VCs))
{                  

Connect-VIServer -Server $VC -Credential $VCA_Credits

$VMhosts = ""
$VMhosts = (Get-VMHost *).Name

$Log_File            = $Path_Log + $VC + "_Log_PW_Check_$REPORT_DATE.txt"
$Log_SSH_OK          = $Path_Log + $VC + "_PW_Check_SSH_OK.txt"
$Log_SSH_FAILED      = $Path_Log + $VC + "_PW_Check_SSH_FAILED_$REPORT_DATE.txt"

# Headers of Log Files ####################################################
"VMhost;SSH Connection Status;SSH Service Status;Date du check;VC/ESXI/Nutanix" | Out-File -FilePath $Log_SSH_OK
"VMhost;SSH Connection Status;SSH Service Status;Date du check;VC/ESXI/Nutanix" | Out-File -FilePath $Log_SSH_FAILED

Write-host -f Gray "`r`n##############################################################################################################`r`n"

# VC CERT CHECK ###########################################################################################################################

$VC_CertExpiresOn = ""

# Ignore SSL Warning
[Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

$VC_uri = "https://$VC/" 
$VC_webRequest = [Net.HttpWebRequest]::Create($VC_uri)

$VC_webRequest.ServicePoint
$VC_webRequest.GetResponse() | Out-NULL
$VC_webRequest.ServicePoint.Certificate
$VC_CertExpiresOn = $VC_webRequest.ServicePoint.Certificate.GetExpirationDateString()
$VC_CertExpiresOn

# SSH CONNECTION AND LOGIN TEST LOOP ###########################################################################################################################

	# VCENTER SSH CHECK ####################################################>
	$VC_SshSession = New-SSHSession -ComputerName $VC -Credential $VC_Credits -AcceptKey

		# IF SSH OK ##################################################
		if (($VC_SshSession).connected -like $True)
		{
	  
			# VCENTER CHECK ####################################################
			$VC_SshSessionId = (Get-SSHSession | where-object {$_.host -like $VC}).sessionid 

			$HiMyNameIs = Invoke-SSHCommand -Command "uname -n" -SessionId $VC_SshSessionId

			if(([String]($HiMyNameIs.Output)) -like "$VC*")
			{
			write-host -f green "$VC : Connexion vCenter SSH OK ! - vCENTER"
			"$VC;Connexion SSH OK;Service SSH OK;$REPORT_DATE;vCENTER" | Out-File -FilePath $Log_File -Append
			"$VC;Connexion SSH OK;Service SSH OK;$REPORT_DATE;vCENTER" | Out-File -FilePath $Log_SSH_OK -Append


            $Output  = New-Object -Type PSObject
            $Output | Add-Member -MemberType NoteProperty -Name "Date"                   -Value (Get-Date -f "dd/MM/yyyy HH:mm")
            $Output | Add-Member -MemberType NoteProperty -Name "vCenter"                -Value $([string]$VC).ToUpper()
            $Output | Add-Member -MemberType NoteProperty -Name "Hostname"               -Value $([string]$VC).ToUpper()
            $Output | Add-Member -MemberType NoteProperty -Name "Type"                   -Value "VCENTER"
            $Output | Add-Member -MemberType NoteProperty -Name "SSH Connection Status"  -Value "Connexion SSH OK"
            $Output | Add-Member -MemberType NoteProperty -Name "SSH Service Status"     -Value "Service SSH OK"

            $Output | Add-Member -MemberType NoteProperty -Name "iDRAC_IP"               -Value ""
            $Output | Add-Member -MemberType NoteProperty -Name "iDRAC_NSLU"             -Value ""
            $Output | Add-Member -MemberType NoteProperty -Name "IP"                     -Value ""
            $Output | Add-Member -MemberType NoteProperty -Name "IP_NSLU"                -Value ""
            $Output | Add-Member -MemberType NoteProperty -Name "vMotion_IP"             -Value ""

            $Output | Add-Member -MemberType NoteProperty -Name "DrtmEnabled"            -Value ""
            $Output | Add-Member -MemberType NoteProperty -Name "TpmPresent"             -Value ""

            $Output | Add-Member -MemberType NoteProperty -Name "Cert Expires On"        -Value "$VC_CertExpiresOn"

            $Global:Tab += $Output


			}

			# FIN VCENTER CHECK ####################################################

		# SSH DISCONNECT ##################################################
		write-host "$VC : Déconnexion SSH - vCENTER"
		Get-SSHSession | Remove-SSHSession | Out-null
		}
		else
		{
		write-host -Red "$VC : Connexion vCenter SSH KO ! - vCENTER"
		
        "$VC;Connexion SSH KO;Service SSH KO ?;$REPORT_DATE;vCENTER" | Out-File -FilePath $Log_File -Append
		"$VC;Connexion SSH KO;Service SSH KO ?;$REPORT_DATE;vCENTER" | Out-File -FilePath $Log_SSH_FAILED -Append

        $Output  = New-Object -Type PSObject
        $Output | Add-Member -MemberType NoteProperty -Name "Date"                   -Value (Get-Date -f "dd/MM/yyyy HH:mm")
        $Output | Add-Member -MemberType NoteProperty -Name "vCenter"                -Value $([string]$VC).ToUpper()
        $Output | Add-Member -MemberType NoteProperty -Name "Hostname"               -Value $([string]$VC).ToUpper()
        $Output | Add-Member -MemberType NoteProperty -Name "Type"                   -Value "VCENTER"
        $Output | Add-Member -MemberType NoteProperty -Name "SSH Connection Status"  -Value "Connexion SSH KO"
        $Output | Add-Member -MemberType NoteProperty -Name "SSH Service Status"     -Value "Service SSH KO ?"

        $Output | Add-Member -MemberType NoteProperty -Name "iDRAC_IP"               -Value ""
        $Output | Add-Member -MemberType NoteProperty -Name "iDRAC_NSLU"             -Value ""
        $Output | Add-Member -MemberType NoteProperty -Name "IP"                     -Value ""
        $Output | Add-Member -MemberType NoteProperty -Name "IP_NSLU"                -Value ""
        $Output | Add-Member -MemberType NoteProperty -Name "vMotion_IP"             -Value ""
        $Output | Add-Member -MemberType NoteProperty -Name "DrtmEnabled"            -Value ""
        $Output | Add-Member -MemberType NoteProperty -Name "TpmPresent"             -Value ""

        $Output | Add-Member -MemberType NoteProperty -Name "Cert Expires On"        -Value "$VC_CertExpiresOn"

        $Global:Tab += $Output

		}

		Write-host -f Gray "`r`n                #######################################################             `r`n"
	# FIN VCENTER SSH CHECK ####################################################

	# LOOP VMHOSTS 
	foreach ($VMhost in ($VMhosts))
	{
        # CERT CHECK # 
        $VMhost_CertExpiresOn = ""

        $VMhost_uri = "https://$VMhost/" 
        $VMhost_webRequest = [Net.HttpWebRequest]::Create($VMhost_uri)

        $VMhost_webRequest.ServicePoint
        $VMhost_webRequest.GetResponse() | Out-NULL
        $VMhost_webRequest.ServicePoint.Certificate
        $VMhost_CertExpiresOn = $VMhost_webRequest.ServicePoint.Certificate.GetExpirationDateString()
        $VMhost_CertExpiresOn
                

		# GET vMotionIP
        $VMhost_NIC = Get-VMHostNetworkAdapter -VMHost $VMhost -VMKernel
		
        $VMhost_vMotionIP = ($VMhost_NIC | Where {$_.VMotionEnabled -eq "True"}).IP
        $VMhost_MgmtIP    = ($VMhost_NIC | Where {$_.ManagementTrafficEnabled}).IP
        

        # CHECK DNS ####################

        $NSLU_VMhost_Name   = (([string](nslookup $VMhost | select-string -SimpleMatch Name)).split(":")[1]).TrimStart()
        $NSLU_VMhost_MgmtIP = (([string](nslookup $VMhost | select-string -SimpleMatch Address)).split(":")[2]).TrimStart()

        if($VMhost -like $NSLU_VMhost_Name)
            {
                if ($VMhost_MgmtIP -like $NSLU_VMhost_MgmtIP)
                {
                $NSLU_VMhost_MgmtIP = "OK"
                }
                elseif($NSLU_VMhost_MgmtIP -like "*.*.*.*")
                {
                $NSLU_VMhost_MgmtIP
                }
                else
                {
                $NSLU_VMhost_MgmtIP = "NO DNS ENTRY"
                }
                
            }

        # FIN # CHECK DNS ###################

		# CHECK SSH SERVICE STATUS AND START IF NEEDED ##################################
		$SSH_Status = ""
		#Get-VMHost $VMhost | Get-VMHostService | Where { $_.Key -eq "TSM-SSH" } | Select VMHost, Label, Running

			if( (Get-VMHost $VMhost | Get-VMHostService | Where { $_.Key -eq "TSM-SSH" }).Running -like $true )
			{
			$VMhost_SSH_Status = "Service SSH déjà démarré."
			$SSH_Status = "D"
			}
			elseif( (Get-VMHost $VMhost | Get-VMHostService | Where { $_.Key -eq "TSM-SSH" }).Running -like $false )
			{
			$VMhost_SSH_Status = "Service SSH pas démarré."
			$SSH_Status = "S"

			Write-host -f yellow "$VMhost : Démarrage du service SSH sur $VMhost du vCenter $VC"
			(Get-VMHost $VMhost | Get-VMHostService | Where { $_.Key -eq "TSM-SSH" }) | Start-VMHostService -Confirm:$False
			"$VMhost;Démarrage du service SSH;$VMhost_SSH_Status." | Out-File -FilePath $Log_File -Append

				if( (Get-VMHost $VMhost | Get-VMHostService | Where { $_.Key -eq "TSM-SSH" }).Running -like $true )
				{$VMhost_SSH_Status = "Service SSH démarré"}
				else
				{$VMhost_SSH_Status = "Service SSH ne démarre pas"}

			Write-host "$VMhost_SSH_Status sur $VMhost du vCenter $VC"
			}
			else
			{
			Write-host -f Yellow "$VMhost pas joignable sur le vCenter $VC"
			}

		##################################
			if( (Get-VMHost $VMhost | Get-VMHostService | Where { $_.Key -eq "TSM-SSH" }).Running -like $true )
			{
			 # SSH CONNECTION AND LOGIN TEST CLI ###########################################################################################################################

				$VMhost_SshSession = New-SSHSession -ComputerName $VMhost -Credential $ESXi_Credits -AcceptKey

				# IF SSH OK ##################################################
				if (($VMhost_SshSession).connected -like $True)
				{
	            
                $GET_TPM = (Get-EsxCli -VMHost $VMhost -V2).Hardware.trustedboot.get.invoke() 
                $GET_IPMI = (Get-EsxCli -VMHost $VMhost -V2).Hardware.ipmi.bmc.get.invoke()
                
                # CHECK DNS ####################
                $iDRAC_DNS = $VMhost.split(".")[0] + "-lc" + $VMhost.substring(8)
                ($GET_IPMI.IPv4Address)

                $NSLU_iDRAC_Name   = (([string](nslookup $iDRAC_DNS | select-string -SimpleMatch Name)).split(":")[1]).TrimStart()
                $NSLU_iDRAC_IP = (([string](nslookup $iDRAC_DNS | select-string -SimpleMatch Address)).split(":")[2]).TrimStart()
               

                if($NSLU_iDRAC_Name -like $null)
                  {
                   $NSLU_iDRAC_IP = "NO DNS ENTRY"
                  }
                elseif($iDRAC_DNS -like $NSLU_iDRAC_Name)
                    {

                        if (($GET_IPMI.IPv4Address) -like $NSLU_iDRAC_IP)
                        {
                        $NSLU_iDRAC_IP = "OK"
                        }
                        elseif($NSLU_iDRAC_IP -like "*.*.*.*")
                        {
                        $NSLU_iDRAC_IP
                        }
                        else
                        {
                        $NSLU_iDRAC_IP = "NO DNS ENTRY"
                        }

                    }

                # FIN # CHECK DNS ###################

					# NUTANIX CHECK ####################################################
					$VMhost_SshSessionId = (Get-SSHSession | where-object {$_.host -like $VMhost}).sessionid 
					$Deez_Nuts = Invoke-SSHCommand -Command "du -sh /vmfs/volumes/NTNX*" -SessionId $VMhost_SshSessionId

					if(([String]($Deez_Nuts.Output)) -like "*NTNX*")
					{
					write-host -f green "$VMhost : Connexion SSH OK ! - $VMhost_SSH_Status - ESXI NUTANIX"
					"$VMhost;Connexion SSH OK;$VMhost_SSH_Status;$REPORT_DATE;ESXI NUTANIX" | Out-File -FilePath $Log_File -Append
					"$VMhost;Connexion SSH OK;$VMhost_SSH_Status;$REPORT_DATE;ESXI NUTANIX" | Out-File -FilePath $Log_SSH_OK -Append

                    $Output  = New-Object -Type PSObject
                    $Output | Add-Member -MemberType NoteProperty -Name "Date"                   -Value (Get-Date -f "dd/MM/yyyy HH:mm")
                    $Output | Add-Member -MemberType NoteProperty -Name "vCenter"                -Value $([string]$VC).ToUpper()
                    $Output | Add-Member -MemberType NoteProperty -Name "Hostname"               -Value $([string]$VMhost).ToUpper()
                    $Output | Add-Member -MemberType NoteProperty -Name "Type"                   -Value "ESXI NUTANIX"
                    $Output | Add-Member -MemberType NoteProperty -Name "SSH Connection Status"  -Value "Connexion SSH OK"
                    $Output | Add-Member -MemberType NoteProperty -Name "SSH Service Status"     -Value "$VMhost_SSH_Status"

                    $Output | Add-Member -MemberType NoteProperty -Name "iDRAC_IP"               -Value $([string]($GET_IPMI.IPv4Address))
                    $Output | Add-Member -MemberType NoteProperty -Name "iDRAC_NSLU"             -Value $([string]($NSLU_iDRAC_IP))
                    $Output | Add-Member -MemberType NoteProperty -Name "IP"                     -Value $([string]$VMhost_MgmtIP)
                    $Output | Add-Member -MemberType NoteProperty -Name "IP_NSLU"                -Value $([string]$NSLU_VMhost_MgmtIP)
                    $Output | Add-Member -MemberType NoteProperty -Name "vMotion_IP"             -Value $([string]$VMhost_vMotionIP)                   
                    $Output | Add-Member -MemberType NoteProperty -Name "DrtmEnabled"            -Value $([string]($GET_TPM.DrtmEnabled))
                    $Output | Add-Member -MemberType NoteProperty -Name "TpmPresent"             -Value $([string]($GET_TPM.TpmPresent))

                    $Output | Add-Member -MemberType NoteProperty -Name "Cert Expires On"        -Value "$VMhost_CertExpiresOn"

                    $Global:Tab += $Output

					}
					else
					{
					write-host -f green "$VMhost : Connexion SSH OK ! - $VMhost_SSH_Status - ESXI"
					"$VMhost;Connexion SSH OK;$VMhost_SSH_Status;$REPORT_DATE;ESXI" | Out-File -FilePath $Log_File -Append
					"$VMhost;Connexion SSH OK;$VMhost_SSH_Status;$REPORT_DATE;ESXI" | Out-File -FilePath $Log_SSH_OK -Append


                    $Output  = New-Object -Type PSObject
                    $Output | Add-Member -MemberType NoteProperty -Name "Date"                   -Value (Get-Date -f "dd/MM/yyyy HH:mm")
                    $Output | Add-Member -MemberType NoteProperty -Name "vCenter"                -Value $([string]$VC).ToUpper()
                    $Output | Add-Member -MemberType NoteProperty -Name "Hostname"               -Value $([string]$VMhost).ToUpper()
                    $Output | Add-Member -MemberType NoteProperty -Name "Type"                   -Value "ESXI"
                    $Output | Add-Member -MemberType NoteProperty -Name "SSH Connection Status"  -Value "Connexion SSH OK"
                    $Output | Add-Member -MemberType NoteProperty -Name "SSH Service Status"     -Value "$VMhost_SSH_Status"

                    $Output | Add-Member -MemberType NoteProperty -Name "iDRAC_IP"               -Value $([string]($GET_IPMI.IPv4Address))
                    $Output | Add-Member -MemberType NoteProperty -Name "iDRAC_NSLU"             -Value $([string]($NSLU_iDRAC_IP))
                    $Output | Add-Member -MemberType NoteProperty -Name "IP"                     -Value $([string]$VMhost_MgmtIP)
                    $Output | Add-Member -MemberType NoteProperty -Name "IP_NSLU"                -Value $([string]$NSLU_VMhost_MgmtIP)
                    $Output | Add-Member -MemberType NoteProperty -Name "vMotion_IP"             -Value $([string]$VMhost_vMotionIP)  
                    $Output | Add-Member -MemberType NoteProperty -Name "DrtmEnabled"            -Value $([string]($GET_TPM.DrtmEnabled))
                    $Output | Add-Member -MemberType NoteProperty -Name "TpmPresent"             -Value $([string]($GET_TPM.TpmPresent))

                    $Output | Add-Member -MemberType NoteProperty -Name "Cert Expires On"        -Value "$VMhost_CertExpiresOn"

                    $Global:Tab += $Output

                    # SSH STOP FOR NON NUTANIX ##################################################
                    Write-host -f yellow "$VMhost : Arrêt du service SSH..."
				    (Get-VMHost $VMhost | Get-VMHostService | Where { $_.Key -eq "TSM-SSH" }) | Stop-VMHostService -Confirm:$False
				
					    if( (Get-VMHost $VMhost | Get-VMHostService | Where { $_.Key -eq "TSM-SSH" }).Running -like $false )
					    {
					    Write-host -f Green "$VMhost : Arrêt du service SSH OK ! sur $VMhost du vCenter $VC"
					    "$VMhost;Arrêt du service SSH;$VMhost_SSH_Status." | Out-File -FilePath $Log_File -Append
					    }

					}
					# FIN NUTANIX CHECK # LET SSH RUNNING ###################################################
                


				# SSH DISCONNECT ##################################################
				write-host "$VMhost : Déconnexion SSH - $VMhost_SSH_Status - ESXI"
				Get-SSHSession | Remove-SSHSession | Out-null
				}
				else
				{
				write-host "$VMhost : Connexion SSH FAILED - $VMhost_SSH_Status - ESXI" 
				"$VMhost;Connexion SSH FAILED;$VMhost_SSH_Status;$REPORT_DATE;ESXI" | Out-File -FilePath $Log_File -Append
				"$VMhost;Connexion SSH FAILED;$VMhost_SSH_Status;$REPORT_DATE;ESXI" | Out-File -FilePath $Log_SSH_FAILED -Append

                $Output  = New-Object -Type PSObject
                $Output | Add-Member -MemberType NoteProperty -Name "Date"                   -Value (Get-Date -f "dd/MM/yyyy HH:mm")
                $Output | Add-Member -MemberType NoteProperty -Name "vCenter"                -Value $([string]$VC).ToUpper()
                $Output | Add-Member -MemberType NoteProperty -Name "Hostname"               -Value $([string]$VMhost).ToUpper()
                $Output | Add-Member -MemberType NoteProperty -Name "Type"                   -Value "ESXI"
                $Output | Add-Member -MemberType NoteProperty -Name "SSH Connection Status"  -Value "Connexion SSH FAILED"
                $Output | Add-Member -MemberType NoteProperty -Name "SSH Service Status"     -Value "$VMhost_SSH_Status"

                $Output | Add-Member -MemberType NoteProperty -Name "iDRAC_IP"               -Value $([string]($GET_IPMI.IPv4Address))
                $Output | Add-Member -MemberType NoteProperty -Name "iDRAC_NSLU"             -Value $([string]($NSLU_iDRAC_IP)) 
                $Output | Add-Member -MemberType NoteProperty -Name "IP"                     -Value $([string]$VMhost_MgmtIP)
                $Output | Add-Member -MemberType NoteProperty -Name "IP_NSLU"                -Value $([string]$NSLU_VMhost_MgmtIP) 
                $Output | Add-Member -MemberType NoteProperty -Name "vMotion_IP"             -Value $([string]$VMhost_vMotionIP)  
                $Output | Add-Member -MemberType NoteProperty -Name "DrtmEnabled"            -Value ""
                $Output | Add-Member -MemberType NoteProperty -Name "TpmPresent"             -Value ""

                $Output | Add-Member -MemberType NoteProperty -Name "Cert Expires On"        -Value "$VMhost_CertExpiresOn"

                $Global:Tab += $Output
				}


				# SSH STOP IF NEEDED ##################################################
				if($SSH_Status -like "S")
				{
				Write-host -f yellow "$VMhost : Arrêt du service SSH..."
				(Get-VMHost $VMhost | Get-VMHostService | Where { $_.Key -eq "TSM-SSH" }) | Stop-VMHostService -Confirm:$False
				
					if( (Get-VMHost $VMhost | Get-VMHostService | Where { $_.Key -eq "TSM-SSH" }).Running -like $false )
					{
					Write-host -f Green "$VMhost : Arrêt du service SSH OK ! sur $VMhost du vCenter $VC"
					"$VMhost;Arrêt du service SSH;$VMhost_SSH_Status." | Out-File -FilePath $Log_File -Append
					}

				}
				else
				{
				Write-host -f Cyan "$VMhost : Pas d'arrêt sur le service SSH, il était déjà démarré auparavant."
				"$VMhost;Service SSH déjà démarré, pas d'arrêt;$VMhost_SSH_Status." | Out-File -FilePath $Log_File -Append
				# SSH STOP IF NEEDED ##################################################
				}
				Write-host -f Gray "`r`n                #######################################################             `r`n"
			}

		############################################################################################################################>


	}


Disconnect-VIServer -Server * -Force  -Confirm:$False

}

# EXPORT O365 ###########################################################################################################################>
GiveMeAToken365
GiveMeASessionId


$WorkSheetName = "SSH_Check_VCs"

write-host -f Green "Export des données vers O365 : Worksheet $WorkSheetName `r`n"
WorkSheet.AddName $WorkSheetName
WorkSheet.Clear   $WorkSheetName


$dataToExport = $Tab
Export_To_o365 -WorkSheetName $WorkSheetName -dataToExport $dataToExport
KilltheSessionId

# FIN # EXPORT O365 ###########################################################################################################################>


# MAIL ALERT CERTS EXPIRATION ###########################################################################################################################>
$TOTAL_RECALL = ""
$RECALL_COUNT = 0

foreach($RNWC in  ($dataToExport | Where-Object  {$_."Cert Expires On" -notlike "" })) 
{
 $RNW_NEED = ((New-TimeSpan -start (get-date) -end ((get-date($RNWC."Cert Expires On")))).Days)
 $RECALL = ""

     If($RNW_NEED -le 30)
     {
       $RECALL = [string]($RNWC.Hostname) + "`r`n" + [string]($RNWC."Cert Expires On")  + "`r`n" + $RNW_NEED + " Jours restants avant expiration."
       $Global:TOTAL_RECALL = $TOTAL_RECALL + "<br>" + $RECALL + "<br>" + "`r`n`r`n"
       $RECALL_COUNT++
     }  
}

$TOTAL_RECALL.replace("<br>","")

# BUILD MAIL ########################################################

$Body = "Hello Ladies and Gents,
	    <P> 
	    <P> Look out for these hosts with an almost expiring SSL Cert :
	    <P>
        <P>
	    <P> $TOTAL_RECALL
	    <P>
        <P><br>
	    <P><i>Email sent from $env:computername by ServiceControl_Check.ps1</i></p>
	    <P>--
	    <P>Best regards, from The Virtualization Team."


    if($TOTAL_RECALL -like "")
    {
        $Subject = "VMware Expiring SSL Certs Check : OK. "
        # Send-MailMessage -to $To1,$To2,$To3 -Cc $Cc1,$Cc2 -From $From -Subject $Subject -SmtpServer $SmtpServer -Bodyashtml $body -Attachments $allattachements
        write-host -f Green "$Subject `r`n"
    }
    else
    {
        $Subject = "VMware Expiring SSL Certs Check : " + $RECALL_COUNT + " Hosts."
        Send-MailMessage -to $To2,$To3 -From $From -Subject $Subject -SmtpServer $SmtpServer -Bodyashtml $Body
        # Send-MailMessage -to $To1,$To2,$To3 -Cc $Cc1,$Cc2 -From $From -Subject $Subject -SmtpServer $SmtpServer -Bodyashtml $body -Attachments $allattachements
        write-host -f Yellow "$Subject `r`n"
    }



# FIN # MAIL ALERT CERTS EXPIRATION ###########################################################################################################################>


write-host -f Green "################## # FIN # ##################"

$STOPPED = (Get-date)
$TOTALTIME = "Temps d'execution : "+ (New-TimeSpan -Start $STARTED -End $STOPPED).Minutes + ":" + (New-TimeSpan -Start $STARTED -End $STOPPED).Seconds
$TOTALTIME

