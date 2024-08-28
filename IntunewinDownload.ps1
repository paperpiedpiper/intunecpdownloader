Param(
    [Parameter(Mandatory=$true)]
    [string] $FullAppName,
    [Parameter(Mandatory= $false)]
    [string] $OutputDir = "Desktop Default"
)

######
$agentLogPath = "${env:ProgramData}\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log"
$search1_string = "<![LOG[outbound data:"
$jsonExtractPattern = '<!\[LOG\[outbound data:(.*?)\]LOG\]!'
$search2_string = "<![LOG[Response from Intune = {"
$search3_string = "`"odata.metadata`":"
$scriptRootpath = Split-Path -Parent $MyInvocation.MyCommand.Definition

######
Function Decrypt($base64string)
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.Security") | Out-Null

    $content = [Convert]::FromBase64String($base64string)
    $envelopedCms = New-Object Security.Cryptography.Pkcs.EnvelopedCms
    $certCollection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
    $envelopedCms.Decode($content)
    $envelopedCms.Decrypt($certCollection)

    $utf8content = [text.encoding]::UTF8.getstring($envelopedCms.ContentInfo.Content)
    return $utf8content
}

Function Get-LoggedInUser {
	$explorerProcesses = Get-WmiObject Win32_Process -Filter "Name='explorer.exe'"
	$explorerOwners = $explorerProcesses | ForEach-Object { $_.GetOwner().User }
	
	If ($explorerOwners.count -gt 1) {
		$loggedInUser = $explorerOwners[0]
	} Else { $loggedInUser = $explorerOwners }
	
	return $loggedInUser
}
######
######
Clear-Host
$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
If (!$IsAdmin) {
    Write-Output "Script needs Administrator privileges to decode .intunewin.bin - please run script as Admin"
    return
}


$appidLogline = Get-Content $agentLogPath | ForEach-Object {
    If ($_.ToString().StartsWith($search1_string) -eq $true) {
        If ($_.ToString() -like "*$FullAppName*") {
            $_
        }
    }
} | Select-Object -First 1

$appidLogline -match $jsonExtractPattern | Out-Null
If ($Matches) {
	$dataObject = $Matches[1] | ConvertFrom-Json
    $requestPayload = $dataObject.RequestPayload | ConvertFrom-Json
    $appID = $requestPayload.ApplicationId
	
	$nextLine = $false

    $responseObject = Get-Content $agentLogPath | ForEach-Object {
        $cleanedString = $_.ToString().Trim()

        If ($cleanedString.StartsWith($search2_string)) {
            $nextLine = $true
        }
		
        If ($nextLine -and ($cleanedString -like "*$appID*") -and ($cleanedString.StartsWith($search3_string))) {
            $nextLine = $false
            $initialObject = "{$($cleanedString)}" | ConvertFrom-Json
            Write-Output $initialObject
        }
    }

    $responsePayload = $responseObject.ResponsePayload | ConvertFrom-Json
    $contentInfo = $responsePayload.ContentInfo | ConvertFrom-Json
    $decryptInfo = Decrypt( ([xml]$responsePayload.DecryptInfo).EncryptedMessage.EncryptedContent ) | ConvertFrom-Json

    Write-Output "- URL: $($contentInfo.UploadLocation)"
    Write-Output "- Key: $($decryptInfo.EncryptionKey)"
    Write-Output "- IV:  $($decryptInfo.IV)"

    If ($OutputDir -eq "Desktop Default") {
        $loggedInUser = Get-LoggedInUser
        $OutputDir = "${env:SystemDrive}\Users\$loggedInUser\Desktop"
        If (!($loggedInUser)) { $OutputDir = "${env:USERPROFILE}\Desktop" }
    } 

    If (Test-Path "$scriptRootpath\IntuneWinAppUtilDecoder.exe") {
        Write-Output "`t.\IntuneWinAppUtilDecoder.exe `"$($contentInfo.UploadLocation)`" /key:$($decryptInfo.EncryptionKey) /iv:$($decryptInfo.IV) /filePath:`"$OutputDir\$FullAppName-intunewin.zip`"`n"
        Start-Process "$scriptRootpath\IntuneWinAppUtilDecoder.exe" -ArgumentList "`"$($contentInfo.UploadLocation)`" /key:$($decryptInfo.EncryptionKey) /iv:$($decryptInfo.IV) /filePath:`"$OutputDir\$FullAppName-intunewin.zip`"" -NoNewWindow -Wait
        Remove-Item "$OutputDir\$FullAppName-intunewin.zip" -Force -ErrorAction SilentlyContinue | Out-Null
    } Else {
        Write-Output "IntuneWinAppUtilDecoder.exe not found in script root dir - cannot produce package .zip"
    }
} Else {
	Write-Host "`"$FullAppName`" not found as recently downloaded in Company Portal logs" -BackgroundColor Yellow -ForegroundColor Red
	Write-Host "Check app name or [Install] app again & try script once more" -BackgroundColor Yellow -ForegroundColor Black
}