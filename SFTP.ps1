# Powershell script to SFTP file
# Version 0.2: Added "PreserveTimeStamp = $True , Change logging Function, Added FileName parameter as 1st argument ( optional ) 
# Version 0.3: Used config.xml, encrypted password
# Version 1.0: Added test to make sure it can load the config.xml



param ([string]$SourcePathName)

	
$DateTimeStamp = (Get-Date).toString("yyyyMMdd_HHmmss")
	
# Load configuration
if ( Test-Path -Path ".\config.xml" ) {
	[xml]$Config = Get-Content ".\config.xml"
}
Else {
	Write-Host "Error: Could not open .\config.xml"
	Exit 1
}


Function LogIt
	{
		Param ([string]$LogString)
		$LogString = $DateTimeStamp + "::`n" + $DateTimeStamp + ":: " + $LogString + "`n" + $DateTimeStamp + "::`n"
		Add-content  $Config.Configuration.LogFile -value $LogString
	}
	

if  (  Test-Path -Path $SourcePathName ) {
	$msg = "Path $SourcePathName is accessible." 
	LogIt $msg
}
Else {
	$msg = "Error: Could not access $SourcePathName"
	LogIt $msg
	Exit 1
}


try
{

	# Load WinSCP .NET assembly
	Add-Type -Path "WinSCPnet.dll"
	
	# Set up SFTP session options
	$SessionOptions = New-Object WinSCP.SessionOptions -Property @{
		Protocol = [WinSCP.Protocol]::Sftp
		HostName = $Config.Configuration.TargetHost
		UserName =  $Config.Configuration.UserName
		SecurePassword = ConvertTo-SecureString $Config.Configuration.Password
		SshHostKeyFingerprint = $Config.Configuration.SshHostKeyFingerprint
		SshPrivateKeyPath = $Config.Configuration.SshPrivateKeyPath
	}

	$SessionOptions.AddRawSettings("Compression", "1")
	
	$Session = New-Object WinSCP.Session

	try
	{
		# Define Executable Path
		$Session.ExecutablePath = $Config.Configuration.WorkingDir + "WinSCP.exe"
		
		# Define SFTP session logfile which will remain if the SFTP transfer session fails for whatever reason.
		$SessionLogfile = $Config.Configuration.WorkingDir + "SFTP_" + $DateTimeStamp + ".log"
		$Session.SessionLogPath = $sessionLogfile
		
		# Connect
		$Session.Open($sessionOptions)

		# Upload file$SessionLogfile
		$TransferOptions = New-Object WinSCP.TransferOptions
		$TransferOptions.TransferMode = [WinSCP.TransferMode]::Binary
		$TransferOptions.OverwriteMode = [WinSCP.OverwriteMode]::Overwrite
		$TransferOptions.PreserveTimestamp = $True
		
		if ( $SourcePathName -ne "" ) { 
			$TransferFile = $SourcePathName 
		} else {	
			$TransferFile = $config.Configuration.WorkingDir + $config.Configuration.TransferFileName 
		}

		$RemoveSourceFileOption = $False
		
		$TransferResult = $Session.PutFiles($transferFile, $config.Configuration.TargetDir, $RemoveSourceFileOption, $TransferOptions)
		
		#Throw any error
		$TransferResult.Check()
		
		foreach ($Transfer in $TransferResult.Transfers)
		{ 	
			$msg = "Success: Upload of $($transfer.FileName) to sftp://" + $SessionOptions.UserName + "@" + $SessionOptions.HostName + ":" + $Config.Configuration.TargetDir + " completed successfully"
			LogIt $msg

		}
	}

	finally
	{
		# Disconnect, clean up
		$Session.Dispose()
	}
	Remove-item -path $SessionLogfile
	exit 0
	
}

catch
{
	$msg = "Error: $($_.Exception.Message)"
	LogIt $msg
	$msg = " Upload of $transferFile to sftp://" + $sessionOptions.UserName + "@" + $sessionOptions.HostName + ":" + $config.Configuration.targetDir + " failed"
	LogIt $msg

	# Disconnect, clean up
	$session.Dispose()
	
	exit 1
}


