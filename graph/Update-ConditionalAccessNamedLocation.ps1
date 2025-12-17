$ASN = Read-Host "Enter AS Number numerals"

# Replace 'API_URL' with the actual URL of the API.
$apiUrl = "https://api.bgpview.io/asn/$ASN/prefixes"

# Perform the GET request and convert the JSON response into a PowerShell object.
$response = Invoke-RestMethod -Uri $apiUrl -Method Get

# Extract the 'prefix' field from each element in the 'ipv4_prefixes' arraya.
$prefixes = $response.data.ipv4_prefixes | ForEach-Object { $_.prefix }
# Print the prefixes with desired format.

foreach ($prefix in $prefixes) {
    Write-Output "/ip route add dst-address=$prefix gateway=10.10.0.1 comment=AS$ASN"
}

$Params = @{
"@odata.type" = "#microsoft.graph.ipNamedLocation"
ipRanges = @(
    foreach($Prefix in $prefixes){
        @{
            "@odata.type" = "#microsoft.graph.iPv4CidrRange"
            "cidrAddress" = $prefix
        }
    }
)

}
$LocationID = Read-Host "Provide the locationID"

Update-MgIdentityConditionalAccessNamedLocation -NamedLocationId $LocationID -BodyParameter $Params
