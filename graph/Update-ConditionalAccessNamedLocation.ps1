#=============================================================================================================================
#
# Script Name:     Add-ASNNetworkRangestoCondtionalAccessNamedLocation.PS1
# Script Date:     2025-12-17
#  Script Ver:     v1.0 
#   Script By:     <> 
# Description:     Pulls subnet information from an ASN and adds it to a Microsoft Entra Conditional Access Named Location
# 
# Notes:           
#
#=============================================================================================================================

$ASN = Read-Host "Enter AS Number numerals"

$response = Invoke-RestMethod -Method GET -Uri "https://api.hackertarget.com/aslookup/?q=AS$ASN&output=json"

$Params = @{
    "@odata.type" = "#microsoft.graph.ipNamedLocation"
    ipRanges = @(
        foreach($Prefix in $response.prefixes){
            @{
                "@odata.type" = "#microsoft.graph.iPv4CidrRange"
                "cidrAddress" = $prefix
            }
        }
    )
}
#TODO:Update this to allow using existing location or create a new one
$LocationID = Read-Host "Provide the locationID"

Update-MgIdentityConditionalAccessNamedLocation -NamedLocationId $LocationID -BodyParameter $Params
