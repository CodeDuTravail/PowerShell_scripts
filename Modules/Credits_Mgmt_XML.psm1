<# CREDITS_MGMT_XML MODULE # v1.0 #############################################################################################

import-module E:\Scripts_Prod\Fonctions\Credits_Mgmt.psm1 -force
import-module Posh-SSH



Credits_Gen
Credits_Get
Credits_List

-----------------------------------------------------------------------------------------------------------------------

TO DO :
Credits_SSH
Credits Cleaner

-----------------------------------------------------------------------------------------------------------------------

Get-Help Credits_Gen -examples
Get-Help Credits_Get -examples

-----------------------------------------------------------------------------------------------------------------------

$SRVR = "SERVERNAME"
$SRVR_User = $GRUT
$SRVR_Pass = $PW_SS

$SRVR_Credits = New-Object System.Management.Automation.PSCredential -ArgumentList $SRVR_User, $SRVR_Pass

$SRVR_SshSession = New-SSHSession -ComputerName $SRVR -Credential $SRVR_Credits -AcceptKey
$SRVR_SshSessionId = (Get-SSHSession | where-object {$_.host -like $SRVR}).sessionid 

Invoke-SSHCommand -Command "uname -n" -SessionId $SRVR_SshSessionId
#########################################################################################################################################>

# DEFAULT CRED PATH STORAGE ########################################################################################

$Global:DefaultCredPath = "E:\Scripts_Prod\InPuts\Creds"

# FONCTION CREDIT_GEN ##############################################################################################

function Credits_Gen
{
    <#
    .SYNOPSIS
        Encrypted Credential Generator.
        Generate .cred and .key files associated to store encrypted credentials 
 
 
    .NOTES
        Name: Credits_Gen
        Author: TORCATO Jean-michel
        Version: 1.0
        DateCreated: 2014-Jun-20
 
 
    .EXAMPLE
        Credits_Gen -FolderPath "C:\YOUR\FOLDER\PATH" -FileName "YOUR_FILENAME"
		
		Defining "C:\YOUR\FOLDER\PATH" to store your Credentials files named "YOUR_FILENAME_PP.cred".
		
    .EXAMPLE
        Credits_Gen -FileName "YOUR_FILENAME" 

        Using $DefaultCredPath as the Default Credits folder configured to store your Credentials files.

    .EXAMPLE
        Credits_Gen -FileName "YOUR_FILENAME" -ShowPassword

		ShowPassword option for big fingers people. XDDD
 

    #>

	# KEYFILE N CREDFILE GENERATOR FOR SCRIPTS ###################################################################
	[CmdletBinding()]

	Param(
		 [Parameter(Mandatory = $False,
		 HelpMessage="Enter the path of your Cred folder.")]
		 [string[]]
		 $FolderPath,

		 [Parameter(Mandatory = $True,
		 HelpMessage="Enter the name of your Cred file.")]
		 [string[]]
		 $FileName,
		 
		 [Parameter(Mandatory = $False)]
		 [Switch]$ShowPassword
		 )

	Process
	{ 
	if(((Test-path $DefaultCredPath) -like $true) -and ($FolderPath -like ""))
		{
		$Global:CredPath = $DefaultCredPath 
		write-host -f Gray "`r`n###################################################################"
		write-host "			Credits FolderPath : $CredPath"
		write-host -f Gray "###################################################################`r`n"
		}
	elseif($FolderPath -notlike "")
		{
		$Global:CredPath = $FolderPath
		
			if((Test-path $CredPath) -like $False)
				{
				New-Item -Path "$CredPath" -ItemType Directory
				write-host -f Gray "`r`n###################################################################"
				write-host "			Credits FolderPath : $CredPath"
				write-host -f Gray "###################################################################`r`n"
				}
			else
				{
				write-host -f Gray "`r`n###################################################################"
				write-host "			Credits FolderPath : $CredPath"
				write-host -f Gray "###################################################################`r`n"
				}
		
		}
	
	$CREDFILE = "$CredPath" + "\" + "$FileName" + ".cred"

	$GET_CRED = get-credential
	$GET_CRED | Export-CliXml -Path $CREDFILE
	
	write-host -f Gray "`r`n###################################################################"
	gci -path $Global:CredPath -Attributes !Directory
	write-host -f Gray "`r`n###################################################################"

 
		# SHOW PASSWORD OPTION ###################################################################
		if ($ShowPassword.IsPresent)
		{
			$GET_CRED = Import-Clixml -Path $CREDFILE
			 
			$Global:PW_UC = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($GET_CRED.password))
			$Global:PW_SS = $GET_CRED.Password
			$Global:GRUT = $GET_CRED.Username
  
			write-host -f Cyan "`r`n#####################################################################################################"
			write-host "				Decrypted PW : $PW_UC"
			write-host "				Encrypted PW : `$PW_SS"
			write-host -f Cyan "#####################################################################################################`r`n"
		} # FIN # SHOW PASSWORD OPTION #####################################################################################
		

	}	
	# FIN DE SCRIPT ################################################################################################
}
# FIN # FONCTION CREDIT_GEN ########################################################################################




# FONCTION CREDIT_GET ##############################################################################################

function Credits_Get
{
    <#
    .SYNOPSIS
        Encrypted Credential Reader.
        Read .cred files associated to use encrypted credentials
 
 
    .NOTES
        Name   : Credits_Get
        Author : TORCATO Jean-michel
        Version: 1.0
        DateCreated: 2014-Jun-20
 

	.EXAMPLE
        Credits_Get -FileName "YOUR_FILENAME" 

        Using the Default Credits folder configured to store your Credentials files.
		
    .EXAMPLE
        Credits_Get -Filepath "C:\YOUR\FOLDER\PATH\YOUR_CRED_FILENAME.cred" -ShowPassword
		
		Enter the fullname of your Credential file with -Filepath argument.
		Do I need to explain ShowPassword switch is for ? ;D
 
    #>

	# KEYFILE N CREDFILE READER FOR SCRIPTS ########################################################################
    [CmdletBinding()]

        Param(
			 [Parameter(Mandatory = $False,
             HelpMessage = "Enter the fullpath of your Cred file.")]
             [string[]]
			 $FilePath,
			 
             [Parameter(Mandatory = $False,
             HelpMessage = "Enter the name of your Cred file.")]
             [string[]]
             $FileName,
			 
			 [Parameter(Mandatory = $False)]
			 [Switch]$ShowPassword
             )

	Process
	{ 
		if(($Filepath -notlike "") -and ($Filename -notlike ""))
		{
		write-host -f Red "`r`n#####################################################################################################"
		write-host "			WARNING : You can't use both options : Filename and Filepath ! Exiting Script."
		write-host -f Red "#####################################################################################################`r`n"
		Break
		}
		
		if(((Test-path $DefaultCredPath) -like $true) -and ($Filepath -like ""))
			{
			$Global:CredPath = $DefaultCredPath 
			write-host -f Gray "`r`n#####################################################################################################"
			write-host "	Test path Default Credits FolderPath : $CredPath OK for use."
			write-host -f Gray "#####################################################################################################`r`n"
			
				if((Test-path ($CredPath + "\" + $Global:FileName)) -like $False)
				{
				write-host -f Yellow "`r`n#####################################################################################################"
				write-host "		WARNING : Credits FileName : $FileName Don't exist ! Exiting Script."
				write-host -f Yellow "#####################################################################################################`r`n"
				Break
				}
				
			}
		elseif($Filepath -notlike "")
			{
			$Global:PathCut  = $FilePath.LastIndexOf("\")
			$Global:CredPath = $FilePath.substring(0,$PathCut)
			$FileName = ($FilePath.substring($PathCut)).replace("\","").replace(".cred","")
			
			
			
				if((Test-path $Global:CredPath) -like $False)
				{
				write-host -f Yellow "`r`n#####################################################################################################"
				write-host "		WARNING : Credits FolderPath : $CredPath Don't exist ! Exiting Script."
				write-host -f Yellow "#####################################################################################################`r`n"
				Break
				}
				elseif((Test-path $Filepath) -like $False)
				{
				write-host -f Yellow "`r`n#####################################################################################################"
				write-host "		WARNING : Credits FileName : $Filepath Don't exist ! Exiting Script."
				write-host -f Yellow "#####################################################################################################`r`n"
				Break
				}
				else
				{
				write-host -f Gray "`r`n#####################################################################################################"
				write-host "			Credits FolderPath : $CredPath"
				write-host -f Gray "#####################################################################################################`r`n"
				}
			
			}


		$CREDFILE = "$CredPath" + "\" + "$FileName" + ".cred"
		
		$GET_CRED = Import-Clixml -Path $CREDFILE

		# GIVE IT TO ME ###################################################################
		$Global:PW_UC = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($GET_CRED.password))
		$Global:PW_SS = $GET_CRED.Password
		$Global:GRUT = $GET_CRED.Username

		write-host -f Gray  "`r`n#####################################################################################################"
		write-host -f White  "			Credits FolderPath : $CredPath"
		write-host -f Green "	'$FileName' Credential password variable is available."	
		write-host -f Gray  "#####################################################################################################`r`n"
					
		# SHOW PASSWORD OPTION ###################################################################
		if ($ShowPassword.IsPresent)
		{
			write-host -f Cyan "`r`n#####################################################################################################"
			write-host "				Decrypted PW : $PW_UC"
			write-host "				Encrypted PW : `$PW_SS"
			write-host -f Cyan "#####################################################################################################`r`n"
		} # FIN # SHOW PASSWORD OPTION #####################################################################################
			
		# FIN # GIVE IT TO ME ##############################################################################################>	
    }

}
# FIN # FONCTION CREDIT_GET ##############################################################################################



# FONCTION CREDIT_LIST ##############################################################################################

function Credits_List
    {
    <#
    .SYNOPSIS
        List Encrypted Credential available. 
 
 
    .NOTES
        Name: Credits_List
        Author: TORCATO Jean-michel
        Version: 1.0
        DateCreated: 2014-Jun-20
 
 
    .EXAMPLE
        Credits_List -FolderPath "C:\YOUR\CRED\FOLDER\PATH"

    .EXAMPLE
        Credits_List

        Using your Default Credits folder store to list your Credentials files.
 
    #>

	# CRED FILES LISTER FOR SCRIPTS ########################################################################
        [CmdletBinding()]

        Param(
             [Parameter(Mandatory = $False,
             HelpMessage="Enter the path of your Cred folder.")]
             [string[]]
             $FolderPath
             )

        Process
        { 
        
			if(((Test-path $DefaultCredPath) -like $true) -and ($FolderPath -like ""))
				{
				$Global:CredPath = $DefaultCredPath 
				write-host -f Gray "`r`n#####################################################################################################"
				write-host "	Test path Default Credits FolderPath : $CredPath OK for use."
				write-host -f Gray "#####################################################################################################`r`n"
				
					if((Test-path ($CredPath + "\" + $FileName)) -like $False)
					{
					write-host -f Yellow "`r`n#####################################################################################################"
					write-host "		WARNING : Credits FolderPath : $CredPath Don't exist ! Exiting Script."
					write-host -f Yellow "#####################################################################################################`r`n"
					Break
					}
				}
			elseif($FolderPath -notlike "")
				{
				$Global:CredPath = $FolderPath
			
				if((Test-path $CredPath) -like $False)
					{
					write-host -f Yellow "`r`n#####################################################################################################"
					write-host "		WARNING : Credits FolderPath : $CredPath Don't exist ! Exiting Script."
					write-host -f Yellow "#####################################################################################################`r`n"
					Break
					}
				else
					{
					write-host -f Gray "`r`n#####################################################################################################"
					write-host "			Credits FolderPath : $CredPath"
					write-host -f Gray "#####################################################################################################`r`n"
					}
				}
			
			write-host -f Gray "`r`n###################################################################"
			gci -path $Global:CredPath -Attributes !Directory
			write-host -f Gray "`r`n###################################################################"


        }
    
    }
# FIN # FONCTION CREDIT_LIST ##############################################################################################>
