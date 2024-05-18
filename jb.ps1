# Get DNS server IP address from network configuration
$dnsServer = (Get-DnsClientServerAddress | Where-Object { $_.InterfaceAlias -eq 'Ethernet' }).ServerAddresses[0]

# Define IDE paths
$idePaths = @(
    "C:\Users\$env:USERNAME\AppData\Local\Programs\JetBrains Rider\bin\rider64.exe",
    "C:\Users\$env:USERNAME\AppData\Local\Programs\IntelliJ IDEA\bin\idea64.exe"
    # Add more IDE paths here as needed
)

# Iterate through each IDE path
foreach ($path in $idePaths) {
    # Extract IDE name from the path
    $ideName = [System.IO.Path]::GetFileNameWithoutExtension($path)
    # Fix IDE name - capitalize first letter and remove "64"
    $ideName = $ideName.Substring(0, $ideName.IndexOf("64")).ToUpper().Substring(0,1) + $ideName.Substring(1).Replace("64", "")
    $firewallRuleName = "$ideName Activation"
    # Perform nslookup and extract IP addresses
    $nslookupOutput = nslookup account.jetbrains.com 2>$null
    # Extract IP addresses using Select-String and regex
    $ipAddresses = $nslookupOutput | Select-String -Pattern '\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b' | ForEach-Object { $_.Matches } | ForEach-Object { $_.Value }
    # Filter out the DNS server IP address
    $ipAddresses = $ipAddresses | Where-Object { $_ -ne $dnsServer }
    # Check if the rule exists
    $rule = Get-NetFirewallRule -DisplayName $firewallRuleName -ErrorAction SilentlyContinue
    if ($rule) {
        # Disable firewall rule for the current IDE
        Set-NetFirewallRule -DisplayName $firewallRuleName -Enabled False
        # Enable firewall rule for the current IDE with the retrieved IP addresses
        Set-NetFirewallRule -DisplayName $firewallRuleName -RemoteAddress $ipAddresses -Enabled True
    } else {
        # Create a new firewall rule
        New-NetFirewallRule -DisplayName $firewallRuleName -Direction Outbound -Action Block -Program $path -RemoteAddress $ipAddresses
        Write-Host "Created new firewall rule for $firewallRuleName"
    }
}
