 <# VCSA_Connect MODULE # v1.0 # 28/12/2023 ############################################################################################

 Connect to vCenters like this :

     VCSA_Connect -All_VCs
     VCSA_Connect -vCenters VC1,VC2

 # TO DO OR NOT TO DO ? #-----------------------------------------------------------------

    - Force disconnect before connections ?

 # Useful commands #-----------------------------------------------------------------

 # Set-PowerCLIConfiguration -DefaultVIServerMode Multiple -Confirm:$false
 # Disconnect-VIServer -Server * -Force  -Confirm:$False

 #########################################################################################################################################>

 Function VCSA_Connect {
            [CmdletBinding()]

            Param(
			     [Parameter(Mandatory = $False,
                 HelpMessage='Specify one or multiples vCenters for connection. Ex: "VC1","VC2"
                              Info: This field is not mandatory if "-All_VCs" Switch is used.')]
                 [Array]$vCenters,
			 
                 [Parameter(Mandatory = $False,
                 HelpMessage = "Switch to connect to All vCenters configurated in VCSA.")]
		         [Switch]$All_VCs
			     )

	        Process
	        {
                if( ($vCenters -like "") -and ($All_VCs.IsPresent -like $False) )
                {
                    Write-host -f Yellow "`r`n                #######################################################             `r`n" 
                    Write-host -f White  "                No arguments provided for VCSA_Connect Function -> End of script. "
                    Write-host -f Yellow "`r`n                #######################################################             `r`n"  
                
                    # Disconnect-VIServer -Server * -Force  -Confirm:$False
                    pause
                    exit
                }

                $VCSA_configfile  = "$Path_Niveau_1\InPuts\conf\VCSA_config.json"
                $Global:VC_Infos = convertFrom-Json ([string](gc $VCSA_configfile))

                # Disconnect-VIServer -Server * -Force  -Confirm:$False
                $Global:VCs_OK = @()

                # ALL_VCs OPTION ###################################################################
                if ($All_VCs.IsPresent)
                {
                     $Global:All_VCSA_Array = "VC1","VC2" # <POC
                    # $Global:All_VCSA_Array = "VC1","VC2" # PROD
                }
                else
                {
                    $Global:All_VCSA_Array = $vCenters
                }

                # CONNECT TO ALL VCSA #############################################################################################################################################>
                foreach ($Global:VCSA in $Global:All_VCSA_Array)
                {                  
                    if($Global:VCSA -like "*.*"){$Global:VCSA = $Global:VCSA.split(".")[0]}

                # VCs  CONF ############################################################
                $VC   = ""
                $VCR  = ""
                $VCA  = ""
                $ESXi = ""
                $SSH_HK_FP = ""

                $Global:VC        = $global:VC_Infos.$VCSA.FQDN
                $Global:VCR       = $global:VC_Infos.$VCSA.VCR
                $Global:VCA       = $global:VC_Infos.$VCSA.VCA
                $Global:ESXi      = $global:VC_Infos.$VCSA.ESXi
                $Global:SSH_HK_FP = $global:VC_Infos.$VCSA.SSH_HK_FP


                Credits_Get -filename $Global:VCA
                $VCA_user = $GRUT
                $VCA_Pass = $PW_SS

                $VCA_Credits = New-Object System.Management.Automation.PSCredential -ArgumentList $VCA_user, $VCA_Pass

                Credits_Get -filename $Global:VCR
                $VCR_User = $GRUT
                $VCR_Pass = $PW_SS

                $VCR_Credits = New-Object System.Management.Automation.PSCredential -ArgumentList $VCR_user, $VCR_Pass

                Credits_Get -filename $Global:ESXi
                $ESXi_User = $GRUT
                $ESXi_Pass = $PW_SS

                $ESXi_Credits = New-Object System.Management.Automation.PSCredential -ArgumentList $ESXi_user, $ESXi_Pass

                # VC CONNECT ############################################################
 
                Connect-VIServer -Server $Global:VC -Credential $VCA_Credits

                    if( ($global:DefaultVIServer).Name -like $Global:VC  )
                    {
                        Write-host -f Green "`r`n                #######################################################             `r`n"
                        Write-And-Log $log "[$(($(get-date) - $startdate).minutes) min] Connexion OK au vCenter $Global:VC avec $VCA_User" 0 "full" "vCenter"
                        Write-host -f Green "`r`n                #######################################################             `r`n"
                        [Array]$Global:VCs_OK += $Global:VC
                    }
                    else
                    {
                        Write-host -f Yellow "`r`n                #######################################################             `r`n"
                        Write-And-Log $log "[$(($(get-date) - $startdate).minutes) min] Connexion KO au vCenter $Global:VC avec $VCA_User" 1 "full" "vCenter"
                        Write-host -f Yellow "`r`n                #######################################################             `r`n"
                    }

	
                }
                
                Write-host -f Green "`r`n                #######################################################             `r`n"
                Write-And-Log $log "[$(($(get-date) - $startdate).minutes) min] Connexion effectuée sur les vCenters : $Global:VCs_OK" 0 "full" "vCenter OK"
                Write-host -f Green "`r`n                #######################################################             `r`n"

            }
 
} 