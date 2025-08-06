<# Dell_SSH_PW_CNC_OME.ps1 # v1 #############################################################

IMPORT : Modules & Fonctions. 

import-module ("$Path_Fonctions" + "Credits_Mgmt_XML.psm1")
import-module ("$Path_Fonctions" + "Output_to_O365.psm1")
import-module "Posh-SSH"
import-module "DellOpenManage"
 
Export_To_o365

--------------------------------------------------------------------

OUTPUT : 
    EXPORT O365 : https://my.sharepoint.com/:x:/r/personal/username_domain_com/Documents/SSH_PW_Check.xlsx

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
$Path_Credits        = $Path_Inputs   + "Creds\"

# EXPORT 0365 CONF #############################################################

$Global:Owner        = "username@domain.com"
$Global:fileId       = "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX" 


$configfile          = "$Path_Niveau_1\InPuts\Graph\conf\config.json"
$global:config       = convertFrom-Json ([string](gc $configfile))
$global:clientId     = secu.de64 ($config.office365.oauth2.id)
$global:clientSecret = secu.de64 ($config.office365.oauth2.secret) 
$Global:TenantName   = $config.office365.oauth2.tenantName
$Global:TenantId     = $config.office365.oauth2.tenantId

$Global:tab = @()


# IMPORT MODULES ##############################################################>

import-module ("$Path_Fonctions" + "Credits_Mgmt_XML.psm1")
import-module ("$Path_Fonctions" + "Output_to_O365.psm1")
import-module "Posh-SSH"
import-module "DellOpenManage"

# OME CONFIG #############################################################>

$OME_SERVER = "YOUR_OME_SERVER"

# CREDENTIALS #############################################################>

Credits_Get -filename "OME"
$OME_user = $GRUT
$OME_Pass = $PW_SS
$OME_Credits = New-Object System.Management.Automation.PSCredential -ArgumentList $OME_user, $OME_Pass

Credits_Get -filename "Drac"
$Drac_User = $GRUT
$Drac_Pass = $PW_SS
$Drac_UnPw = $PW_UC
$Drac_Credits = New-Object System.Management.Automation.PSCredential -ArgumentList $Drac_user, $Drac_Pass

Credits_Get -filename "DracOP"
$DracOP_User = $GRUT
$DracOP_Pass = $PW_SS
$DracOP_Credits = New-Object System.Management.Automation.PSCredential -ArgumentList $DracOP_user, $DracOP_Pass

Credits_Get -filename "DracDP"
$DracDP_User = $GRUT
$DracDP_Pass = $PW_SS
$DracDP_Credits = New-Object System.Management.Automation.PSCredential -ArgumentList $DracDP_user, $DracDP_Pass

Credits_Get -filename "ChassisSW"
$Switch_User = $GRUT 
$Switch_Pass = $PW_SS 
$Switch_Credits = New-Object System.Management.Automation.PSCredential -ArgumentList $Switch_User, $Switch_Pass

##################################################################################>


# CONNECT TO OME SERVER ##############################################################>
Connect-OMEServer -Name $OME_SERVER -Credentials $OME_Credits -IgnoreCertificateWarning

$OME_Devices = Get-OMEDevice | Select-Object DeviceName, NetworkAddress, DeviceServiceTag, Model, ConnectionState


foreach ($OD in $OME_Devices)
{

Write-host -f Gray "`r`n##############################################################################################################`r`n"

# OD SSH CONNECTION AND SSH LOGIN TEST LOOP ###########################################################################################################################
    
    $Global:OD_DN         = [String]($OD.DeviceName)
    $Global:OD_DRAC       = [String]($OD.NetworkAddress)
    $Global:OD_ServiceTag = $OD.DeviceServiceTag

    write-host -f Gray "---------------------------------------------------------------------------"
    $Global:OD_DN         
    $Global:OD_DRAC       
    $Global:OD_ServiceTag 
    $OD.ConnectionState
    write-host -f Gray "---------------------------------------------------------------------------"

    $SSH_Connection = "NOT POSSIBLE"
    $PW_Check = "NOT TESTED"

    if ($Global:OD_DRAC -notlike "")
	{
	# OME DEVICE SSH CHECK ####################################################
	$OD_SshSession = New-SSHSession -ComputerName $OD_DRAC -Credential $Drac_Credits -AcceptKey

    # IF SSH OK ##################################################
		if (($OD_SshSession).connected -like $True)
		{
            $SSH_Connection = "OK"
			$PW_Check = "CURRENT"
			
            # SERVICETAG CHECK ####################################################
            $OD_SshSessionId = (Get-SSHSession | where-object {$_.host -like $OD_DRAC}).sessionid

            $HiMyNameIs = Invoke-SSHCommand -Command "racadm getsvctag" -SessionId $OD_SshSessionId
            
            $HiMyNameIs.Output
            write-host -f cyan "---------------------------------------------------------------------------"

            if(([String]($HiMyNameIs.Output)) -like $OD_ServiceTag)
            {
            write-host -f green "$OD_DN | iDRAC : $OD_DRAC : Connexion SSH $SSH_Connection !"
            write-host -f cyan "---------------------------------------------------------------------------"

            $Output  = New-Object -Type PSObject
            $Output | Add-Member -MemberType NoteProperty -Name "Date"                 -Value (Get-Date -f "dd/MM/yyyy HH:mm")
            $Output | Add-Member -MemberType NoteProperty -Name "Server"               -Value $([string]$OD.DeviceName).ToUpper()
            $Output | Add-Member -MemberType NoteProperty -Name "IP_Drac"              -Value $([string]$OD.NetworkAddress)
            $Output | Add-Member -MemberType NoteProperty -Name "ServiceTag"           -Value $([string]$OD.DeviceServiceTag)
            $Output | Add-Member -MemberType NoteProperty -Name "Model"                -Value $([string]$OD.Model)
            $Output | Add-Member -MemberType NoteProperty -Name "SSH_Connection"       -Value $([string]$SSH_Connection)
            $Output | Add-Member -MemberType NoteProperty -Name "OME_ConnectionState"  -Value $([string]$OD.ConnectionState)
            $Output | Add-Member -MemberType NoteProperty -Name "PW_Check"             -Value $([string]$PW_Check)
            $Global:tab += $Output

            }

        # FIN SERVICETAG CHECK ####################################################

		# SSH DISCONNECT ##################################################
		write-host "$OD_DN : Déconnexion SSH"
		Get-SSHSession | Remove-SSHSession | Out-null
		}
		else
		{
            # SSH DEFAULT CONNECT ##################################################

            $OD_SshSession = New-SSHSession -ComputerName $OD_DRAC -Credential $DracDP_Credits -AcceptKey
            $PW_Check = "DEFAULT"

            if (($OD_SshSession).connected -notlike $true)
            {
            $OD_SshSession = New-SSHSession -ComputerName $OD_DRAC -Credential $DracOP_Credits -AcceptKey
            $PW_Check = "ANCIEN"
            }


            if (($OD_SshSession).connected -like $True)
            {
            $SSH_Connection = "OK"
            $PW_Check

            # SERVICETAG CHECK ####################################################
            $OD_SshSessionId = (Get-SSHSession | where-object {$_.host -like $OD_DRAC}).sessionid

            $HiMyNameIs = Invoke-SSHCommand -Command "racadm getsvctag" -SessionId $OD_SshSessionId
            
            $HiMyNameIs.Output
            $SvcTag = $HiMyNameIs.Output
			
                write-host -f cyan "---------------------------------------------------------------------------"

                if(([String]($HiMyNameIs.Output)) -notlike "")
                {
                write-host -f Yellow "$OD_DN | iDRAC : $OD_DRAC : Connexion SSH $SSH_Connection | PASSWORD CHANGE REQUIRED !! "
                write-host -f Cyan "---------------------------------------------------------------------------"
			    

                $Am_I_root = Invoke-SSHCommand -Command "racadm get iDRAC.Users.2" -SessionId $OD_SshSessionId
			
                $Am_I_root.Output

                    if (($Am_I_root.Output | select-string -simplematch "UserName=root" | sort -unique) -like "UserName=root")
                    {
                    write-host -f Yellow "$OD_DN | iDRAC : $OD_DRAC : Connexion SSH $SSH_Connection | PASSWORD CHANGE TIME !! "
                    write-host -f Cyan "---------------------------------------------------------------------------"
                    $Am_I_changed = Invoke-SSHCommand -Command "racadm set iDRAC.Users.2.Password $Drac_UnPw" -SessionId $OD_SshSessionId
			        
                    $Am_I_changed.Output

                        if (($Am_I_changed.Output | select-string -simplematch "Object value modified successfully" | sort -unique) -like "Object value modified successfully")
                        {
                        $PW_Check = "CHANGED"
                        write-host -f Green "$OD_DN | iDRAC : $OD_DRAC : Connexion SSH $SSH_Connection ! PASSWORD CHANGED. "
                        write-host -f Cyan "---------------------------------------------------------------------------"
                        }



                    } 

                write-host -f cyan "---------------------------------------------------------------------------"
                }
            
            $Output  = New-Object -Type PSObject
            $Output | Add-Member -MemberType NoteProperty -Name "Date"                 -Value (Get-Date -f "dd/MM/yyyy HH:mm")
            $Output | Add-Member -MemberType NoteProperty -Name "Server"               -Value $([string]$OD.DeviceName).ToUpper()
            $Output | Add-Member -MemberType NoteProperty -Name "IP_Drac"              -Value $([string]$OD.NetworkAddress)
            $Output | Add-Member -MemberType NoteProperty -Name "ServiceTag"           -Value $([string]$OD.DeviceServiceTag)
            $Output | Add-Member -MemberType NoteProperty -Name "Model"                -Value $([string]$OD.Model)
            $Output | Add-Member -MemberType NoteProperty -Name "SSH_Connection"       -Value $([string]$SSH_Connection)
            $Output | Add-Member -MemberType NoteProperty -Name "OME_ConnectionState"  -Value $([string]$OD.ConnectionState)
            $Output | Add-Member -MemberType NoteProperty -Name "PW_Check"             -Value $([string]$PW_Check)
            $Global:tab += $Output

            }


            if (($OD_SshSession).connected -notlike $true)
            {
            $SSH_Connection = "FAILED"
            $PW_Check = "3 TRIES FAILED"

            write-host -f Red "$OD_DN | iDRAC : $OD_DRAC : Connexion SSH $SSH_Connection !"
            write-host -f cyan "---------------------------------------------------------------------------"

            $Output  = New-Object -Type PSObject
            $Output | Add-Member -MemberType NoteProperty -Name "Date"                 -Value (Get-Date -f "dd/MM/yyyy HH:mm")
            $Output | Add-Member -MemberType NoteProperty -Name "Server"               -Value $([string]$OD.DeviceName).ToUpper()
            $Output | Add-Member -MemberType NoteProperty -Name "IP_Drac"              -Value $([string]$OD.NetworkAddress)
            $Output | Add-Member -MemberType NoteProperty -Name "ServiceTag"           -Value $([string]$OD.DeviceServiceTag)
            $Output | Add-Member -MemberType NoteProperty -Name "Model"                -Value $([string]$OD.Model)
            $Output | Add-Member -MemberType NoteProperty -Name "SSH_Connection"       -Value $([string]$SSH_Connection)
            $Output | Add-Member -MemberType NoteProperty -Name "OME_ConnectionState"  -Value $([string]$OD.ConnectionState)
			$Output | Add-Member -MemberType NoteProperty -Name "PW_Check"             -Value $([string]$PW_Check)
            $Global:tab += $Output
           }


		}
        # SSH DEFAULT CONNECT ##################################################

        # IF ELSE SSH OK ##################################################

    Write-host -f Gray "`r`n                #######################################################             `r`n"
	# FIN # OME DEVICE SSH CHECK ####################################################
    }
    elseif(($Global:OD_DRAC -like "") -and ($OD_DN -notlike "*-*") -and ($OD_DN -notlike "*.*.*.*")) # REPARTIR DE LA
    {
    # CHASSIS DEVICE SSH CHECK ##################################################
        write-host -f Cyan "---------------------------------------------------------------------------"
        write-host -f Yellow "$OD_DN | Pas de networkaddress : Check par InventoryInfo :"
        $OD_IP = "Pas d'IP dans Get-OMEDevice NetworkAddress"
        $OD_IP = (($OD_DN | Get-OMEDevice -FilterBy "Name" | Get-OMEDeviceDetail).InventoryInfo | Where { $_.DnsName -eq $OD_DN }).IpAddress

        write-host -f Yellow "$OD_DN | Tentative de connexion SSH par IP : $OD_IP"
        write-host -f Cyan "---------------------------------------------------------------------------"

        $OD_SshSession = New-SSHSession -ComputerName $OD_IP -Credential $Drac_Credits -AcceptKey

		# IF SSH OK ##################################################
		if (($OD_SshSession).connected -like $True)
		{
	        $SSH_Connection = "OK"
			$PW_Check = "CURRENT" 
			# SERVICETAG CHECK ####################################################
			$OD_SshSessionId = (Get-SSHSession | where-object {$_.host -like $OD_IP}).sessionid

			$HiMyNameIs = Invoke-SSHCommand -Command "racadm getsvctag" -SessionId $OD_SshSessionId
            
            $HiMyNameIs.Output
            write-host -f cyan "---------------------------------------------------------------------------"

            if(([String]($HiMyNameIs.Output)) -like "*Chassis*$OD_ServiceTag*")
            {
            write-host -f green "$OD_DN | Chassis : $OD_IP : Connexion SSH $SSH_Connection !"
            write-host -f cyan "---------------------------------------------------------------------------"

            $Output  = New-Object -Type PSObject
            $Output | Add-Member -MemberType NoteProperty -Name "Date"             -Value (Get-Date -f "dd/MM/yyyy HH:mm")
            $Output | Add-Member -MemberType NoteProperty -Name "Server"           -Value $([string]$OD.DeviceName).ToUpper()
            $Output | Add-Member -MemberType NoteProperty -Name "IP_Drac"          -Value $([string]$OD_IP)
            $Output | Add-Member -MemberType NoteProperty -Name "ServiceTag"       -Value $([string]$OD.DeviceServiceTag)
            $Output | Add-Member -MemberType NoteProperty -Name "Model"            -Value $([string]$OD.Model)
            $Output | Add-Member -MemberType NoteProperty -Name "SSH_Connection"   -Value $([string]$SSH_Connection)
            $Output | Add-Member -MemberType NoteProperty -Name "OME_ConnectionState"  -Value $([string]$OD.ConnectionState)
			$Output | Add-Member -MemberType NoteProperty -Name "PW_Check"             -Value $([string]$PW_Check)
            $Global:tab += $Output
			}



			# FIN SERVICETAG CHECK ####################################################

		# SSH DISCONNECT ##################################################
		write-host "$OD_DN : Déconnexion SSH"
		Get-SSHSession | Remove-SSHSession | Out-null
		}
		else
		{
 
            $SSH_Connection = "FAILED"
			$PW_Check = "FAILED"
            write-host -f Red "$OD_DN | iDRAC : $OD_IP : Connexion SSH $SSH_Connection !"
            write-host -f Cyan "---------------------------------------------------------------------------"

            $Output  = New-Object -Type PSObject
            $Output | Add-Member -MemberType NoteProperty -Name "Date"             -Value (Get-Date -f "dd/MM/yyyy HH:mm")
            $Output | Add-Member -MemberType NoteProperty -Name "Server"           -Value $([string]$OD.DeviceName).ToUpper()
            $Output | Add-Member -MemberType NoteProperty -Name "IP_Drac"          -Value $([string]$OD_IP)
            $Output | Add-Member -MemberType NoteProperty -Name "ServiceTag"       -Value $([string]$OD.DeviceServiceTag)
            $Output | Add-Member -MemberType NoteProperty -Name "Model"            -Value $([string]$OD.Model)
            $Output | Add-Member -MemberType NoteProperty -Name "SSH_Connection"   -Value $([string]$SSH_Connection)
            $Output | Add-Member -MemberType NoteProperty -Name "OME_ConnectionState"  -Value $([string]$OD.ConnectionState)
			$Output | Add-Member -MemberType NoteProperty -Name "PW_Check"             -Value $([string]$PW_Check)
            $Global:tab += $Output
            
		}

		Write-host -f Gray "`r`n                #######################################################             `r`n"
    # CHASSIS DEVICE SSH CHECK
    }
    else
    {
    # SWITCH DEVICE SSH CHECK ##################################################
        write-host -f Cyan "---------------------------------------------------------------------------"
        write-host -f Yellow "$OD_DN | Pas de networkaddress : Check par InventoryInfo :"
        $OD_IP = "Pas d'IP dans Get-OMEDevice NetworkAddress"
        $OD_IP = (($OD_DN | Get-OMEDevice -FilterBy "Name" | Get-OMEDeviceDetail).InventoryInfo | Where { $_.DnsName -eq $OD_DN }).IpAddress

        if(($OD_IP -like "") -and ($OD_DN -like "*.*.*.*")){$OD_IP = $OD_DN}

        write-host -f Yellow "$OD_DN | Tentative de connexion SSH par IP : $OD_IP"
        write-host -f Cyan "---------------------------------------------------------------------------"

        $OD_SshSession = New-SSHSession -ComputerName $OD_IP -Credential $Switch_Credits -AcceptKey

		# IF SSH OK ##################################################
		if (($OD_SshSession).connected -like $True)
		{
	        $SSH_Connection = "OK"
			$PW_Check = "CURRENT"
			# SERVICETAG CHECK ####################################################
			$OD_SshSessionId = (Get-SSHSession | where-object {$_.host -like $OD_IP}).sessionid

			$HiMyNameIs = Invoke-SSHCommand -Command "show inventory" -SessionId $OD_SshSessionId
            
            $HiMyNameIs.Output

            if($OD_DN -like "*.*.*.*")
            {$OD_DN = ($HiMyNameIs.Output).split(".#")[36]
            }

            write-host -f cyan "---------------------------------------------------------------------------"

			if(([String]($HiMyNameIs.Output)) -like "*$OD_DN*")
			{
			write-host -f green "$OD_DN | Switch : $OD_IP : Connexion SSH $SSH_Connection !"
            write-host -f cyan "---------------------------------------------------------------------------"
            }
            else
            {
			write-host -f Yellow "$OD_DN | Switch : $OD_IP : Connexion SSH $SSH_Connection !"
            write-host -f cyan "---------------------------------------------------------------------------"
            }

            $Output  = New-Object -Type PSObject
            $Output | Add-Member -MemberType NoteProperty -Name "Date"             -Value (Get-Date -f "dd/MM/yyyy HH:mm")
            $Output | Add-Member -MemberType NoteProperty -Name "Server"           -Value $([string]$OD_DN).ToUpper()
            $Output | Add-Member -MemberType NoteProperty -Name "IP_Drac"          -Value $([string]$OD_IP)
            $Output | Add-Member -MemberType NoteProperty -Name "ServiceTag"       -Value $([string]$OD.DeviceServiceTag)
            $Output | Add-Member -MemberType NoteProperty -Name "Model"            -Value $([string]$OD.Model)
            $Output | Add-Member -MemberType NoteProperty -Name "SSH_Connection"   -Value $([string]$SSH_Connection)
            $Output | Add-Member -MemberType NoteProperty -Name "OME_ConnectionState"  -Value $([string]$OD.ConnectionState)
 			$Output | Add-Member -MemberType NoteProperty -Name "PW_Check"             -Value $([string]$PW_Check)

			$Global:tab += $Output

            

			# FIN SERVICETAG CHECK ####################################################

		# SSH DISCONNECT ##################################################
		write-host "$OD_DN : Déconnexion SSH"
		Get-SSHSession | Remove-SSHSession | Out-null
		}
		else
		{
 
            $SSH_Connection = "FAILED"
			$PW_Check = "FAILED"
			
            write-host -f Red "$OD_DN | Switch : $OD_IP : Connexion SSH $SSH_Connection !"
            write-host -f Cyan "---------------------------------------------------------------------------"

            $Output  = New-Object -Type PSObject
            $Output | Add-Member -MemberType NoteProperty -Name "Date"             -Value (Get-Date -f "dd/MM/yyyy HH:mm")
            $Output | Add-Member -MemberType NoteProperty -Name "Server"           -Value $([string]$OD.DeviceName).ToUpper()
            $Output | Add-Member -MemberType NoteProperty -Name "IP_Drac"          -Value $([string]$OD_IP)
            $Output | Add-Member -MemberType NoteProperty -Name "ServiceTag"       -Value $([string]$OD.DeviceServiceTag)
            $Output | Add-Member -MemberType NoteProperty -Name "Model"            -Value $([string]$OD.Model)
            $Output | Add-Member -MemberType NoteProperty -Name "SSH_Connection"   -Value $([string]$SSH_Connection)
            $Output | Add-Member -MemberType NoteProperty -Name "OME_ConnectionState"  -Value $([string]$OD.ConnectionState)
			$Output | Add-Member -MemberType NoteProperty -Name "PW_Check"             -Value $([string]$PW_Check)
            $Global:tab += $Output
            
		}

		Write-host -f Gray "`r`n                #######################################################             `r`n"
    # SWITCH DEVICE SSH CHECK
    }


}


# EXPORT O365 ###########################################################################################################################
GiveMeAToken365
GiveMeASessionId


$WorkSheetName = "DELL_SSH_Check_OME"
WorkSheet.AddName $WorkSheetName
WorkSheet.Clear   $WorkSheetName

write-host -f Green "Export des données vers O365 : Worksheet $WorkSheetName `r`n"

$dataToExport = $Tab
Export_To_o365 -WorkSheetName $WorkSheetName -dataToExport $dataToExport
KilltheSessionId
# FIN # EXPORT O365 ###########################################################################################################################>

write-host -f Green "################## # FIN # ##################"

$STOPPED = (Get-date)
$TOTALTIME = "Temps d'execution : "+ (New-TimeSpan -Start $STARTED -End $STOPPED).Minutes + ":" + (New-TimeSpan -Start $STARTED -End $STOPPED).Seconds
$TOTALTIME
