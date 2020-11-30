<#
.SYNOPSIS
Set resolution state using SCOM REST API.

Author: Patrick Seidl
        (c) s2 - seidl solutions

Date:   05.06.2019

.DESCRIPTION
This script sets the resolution state in SCOM using the SCOM REST API (version 1801 or newer).
The final Invoke-WebRequest (setting the resolution state) is supposed to end with http status 200 (OK).

.CONFIGURATION
It is possible to define multiple SCOM web servers directly in the script or pass a web server using the parameter.
In order to reset monitors there is a notification channel solution here: https://gallery.technet.microsoft.com/systemcenter/PoSh-Reset-Monitor-On-c288374a?redir=0

.PARAMETER alertId
Mandatory.
The alertID(s) supposed to be updated.

.PARAMETER comment
Optionally.
The comment which should be written to the alerts comment field. Default = "Incident has been resolved in SNOW"

.PARAMETER resolutionstate
Optionally.
The resolution state which should be set. Default = 255 (= Closed)
Monitors will be reseted by a notification channel (see configuration chapter above).

.PARAMETER scomWS
Optionally.
The FQDN of the web server. Could be hard-coded in the script either.

.PARAMETER scomUsername
Optionally.

.PARAMETER scomPassword
Optionally.
If not provided the script will use the current users name and password

.EXAMPLE 1 (Default)
.\Set-RestApiResolutionState.ps1 -alertId 907c16f1-f54f-44ab-9a4a-a1a1ce795154
200
OK

.EXAMPLE 2
.\Set-RestApiResolutionState.ps1 -alertId 907c16f1-f54f-44ab-9a4a-a1a1ce795154 -comment "Hello World" -resolutionstate 255 -scomWS server.domain.tld -scomUsername domain\username -scomPassword password
200
OK
#>

param(
    [Parameter(Mandatory=$true)]
    [string[]]$alertId,
    [Parameter(Mandatory=$false)]
    $comment = "Incident has been resolved in SNOW",
    [Parameter(Mandatory=$false)]
    $resolutionstate = "255",
    [Parameter(Mandatory=$false)]
    $scomWS,
    [Parameter(Mandatory=$false)]
    $scomUsername,
    [Parameter(Mandatory=$false)]
    $scomPassword
)

if (!$scomWS) {
    # enter here a list of pre-defined SCOM web servers or pass the server using the parameters
    $scomWSs = @(
        "server1.domain.tld"
        "server2.domain.tld"
    )
    foreach ($scomWS in $scomWSs) {
        $uriTest = "https://$($scomWS)/OperationsManager/authenticationMode"
        if ($scomPassword) {
            $authMode = Invoke-RestMethod -Uri $uriTest -Method Get -Credential $cred
        } else {
            $authMode = Invoke-RestMethod -Uri $uriTest -Method Get -UseDefaultCredentials
        }
        if ($authMode -eq "Windows") {
            break            
        }
    }
}

if ($scomPassword) {
    $scomPassword = ConvertTo-SecureString -AsPlainText $scomPassword -Force
    $SecureString = $scomPassword
    $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $scomUsername,$SecureString 
}

$jsonHeaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$jsonHeaders.Add('Content-Type','application/json; charset=utf-8')

$rawBody = "Windows"
$byteBody = [System.Text.Encoding]::UTF8.GetBytes($rawBody)
$encodedBody =[Convert]::ToBase64String($byteBody)
$jsonBody = $encodedBody | ConvertTo-Json

$uriAuth = "https://$($scomWS)/OperationsManager/authenticate"
if ($scomPassword) {
    $authLogon = Invoke-RestMethod -Uri $uriAuth -Method Post -Headers $jsonHeaders -Body $jsonBody -Credential $cred -SessionVariable websession
} else {
    $authLogon = Invoke-RestMethod -Uri $uriAuth -Method Post -Headers $jsonHeaders -Body $jsonBody -UseDefaultCredentials -SessionVariable websession
}

$queryTable = @{
       "alertIds"= $alertId;
    "comment"= $comment;
       "resolutionState"= $resolutionstate
}
$jsonQuery = $queryTable | ConvertTo-Json

$uriPayload = "https://$($scomWS)/OperationsManager/data/alertResolutionStates"
if ($scomPassword) {
    $response = Invoke-WebRequest -Uri $uriPayload -Method Post -Headers $jsonHeaders -Body $jsonQuery -Credential $cred -WebSession $websession
} else {
    $response = Invoke-WebRequest -Uri $uriPayload -Method Post -Headers $jsonHeaders -Body $jsonQuery -UseDefaultCredentials -WebSession $websession
}    
$response.StatusCode
$response.StatusDescription 
