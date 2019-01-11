# Name: 3PAR_RC_Check.ps1
# Author: Naz Snidanko
# Date Created: Nov 11, 2015
# Date Modified: 
# Version: 0.1
# Description: uses WSAPI to poll last sync of the 3par group. Checks if last sync is older than X days and sends email alert.
# Credit: http://setspn.blogspot.ca/2014/11/3par-connect-to-webapi-using-powershell.html
############# START EDIT ##############
#Credentials  
$username = "uname"  
$password = "****"  
#IP of the 3PAR device  
$IP = "10.10.10.10"
#name of the RC group
$RCGroup = "TEST.r12345"
#Alert when older than X minutes
$oldThanMinutes = 10
#SMTP Server
$smtp = "mail.domain.com"
#Sender of Alerts
$FromEm = "noreply@domaincom"
#Recipient for alerts
$ToEm = "nsnidanko@domain.com"
#API URL  
$APIurl = "https://$($IP):8080/api/v1"  
############# END EDIT ##############

#avoid issues with an invalid (self-signed) certificate, try avoid tabs/spaces as this might mess up the string block  
#http://stackoverflow.com/questions/11696944/powershell-v3-invoke-webrequest-https-error  
add-type @" 
    using System.Net; 
    using System.Security.Cryptography.X509Certificates; 
    public class TrustAllCertsPolicy : ICertificatePolicy { 
        public bool CheckValidationResult( 
            ServicePoint srvPoint, X509Certificate certificate, 
            WebRequest request, int certificateProblem) { 
            return true; 
        } 
    } 
"@  
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

#connect to 3PAR WSAPI
$postParams = @{user=$username;password=$password} | ConvertTo-Json  
$headers = @{}  
$headers["Accept"] = "application/json"  
$credentialdata = Invoke-WebRequest -Uri "$APIurl/credentials" -Body $postParams -ContentType "application/json" -Headers $headers -Method POST -UseBasicParsing  
$key = ($credentialdata.Content | ConvertFrom-Json).key

#Poll 3PAR Remote Copy data
$headers = @{} 
$headers["Accept"] = "application/json" 
$headers["Accept-Language"] = "en"
$headers["X-HP3PAR-WSAPI-SessionKey"] = $key
$WSAPIdata = Invoke-WebRequest -Uri "$APIurl/remotecopygroups/$RCGroup" -ContentType "application/json" -Headers $headers -Method GET -UseBasicParsing  

#get last sync time of the first volume in Remote Copy group as string in ISO 8601 and cast it
[DateTime]$volLastSync = ( $WSAPIdata.content | Convertfrom-Json ).volumes[0].remoteVolumes.volumeLastSyncTime

#close 3PAR WSAPI connection
Invoke-WebRequest -Uri "$APIurl/credentials/$key" -ContentType "application/json" -Method DELETE -UseBasicParsing 

# get current date in ISO 8601 Format
$date = Get-Date -format "s"
#compare how much time since last sync
$Diff = new-timespan -Start $volLastSync -end $date

#logic to compare timespan
if ( $diff.TotalMinutes -ge $oldThanMinutes ) {
#send email
Send-MailMessage -From $FromEm -To $ToEm -SmtpServer $smtp -Subject "3PAR Replication Alert for $RCGroup" -Body "Last sync happened at $volLastSync"
}