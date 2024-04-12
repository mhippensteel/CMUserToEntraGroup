
param (
    [String] $groupName,
    [String] $siteCode,
    [String] $mpServer
)

Import-module ConfigurationManager
Import-Module Microsoft.Graph.Beta.Groups
Import-Module Microsoft.Graph.Beta.Users

Connect-MgGraph -Scopes 'Group.ReadWrite.All', 'User.Read'

$workstations = Import-Csv -path "Workstations.csv"

function Connect-CMSite {

    if($null -eq (Get-Module ConfigurationManager)) {
        Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" #@initParams 
    }
    # Connect to the site's drive if it is not already present
    if($null -eq (Get-PSDrive -Name $siteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {
        New-PSDrive -Name $siteCode -PSProvider CMSite -Root $mpServer #@initParams
    }
    # Set the current location to be the site code.
    Set-Location "$($siteCode):\" #@initParams
}

$groupName = "APP-BusyLight-Users"
$entraGroup = Get-MgBetaGroup -Filter "DisplayName eq '$groupName'"
$entraGroupMembers = Get-MgBetaGroupMember -GroupId $entraGroup.Id

Connect-CMSite

foreach($workstation in $workstations){

    $userAffinity = Get-CMUserDeviceAffinity -DeviceName $workstation
    $upn = if($null -ne $userAffinity.UniqueUserName){"$($userAffinity.UniqueUserName.split("\")[1])@$((Get-ADDomain).DNSRoot)"} else {Continue}

    if(($entraGroupMembers.AdditionalProperties.userPrincipalName) -notcontains $upn){
        # Write-Output $upn
        if($upn -notmatch '^admin'){
            $entraUser = Get-MgBetaUser -Filter "UserPrincipalName eq '$upn'"
            Write-Host "Adding $($entraUser.UserPrincipalName) to $groupName" -ForegroundColor Green
            New-MgBetaGroupMember -GroupId $entraGroup.Id -DirectoryObjectId $entraUser.Id
        }
    }
}

Set-Location $PSScriptRoot


















