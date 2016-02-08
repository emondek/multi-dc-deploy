<#
.SYNOPSIS
	This script provisions an environment across multiple Azure regions.
	
.DESCRIPTION
	This script provisions an environment across multiple Azure regions.

    Resource naming convention uses the following format:  <appName><region><resource><resourceInstanceName><resourceInstanceCount>
    Ex. mdcwuvmweb1 where mdc=Multi-Datacenter, wu=West US, vm=Virtual Machine, web1=Web Server #1
	
.NOTES
	Author: Ed Mondek
	Date: 01/30/2016
	Revision: 1.0

.CHANGELOG
    1.0  01/30/2016  Ed Mondek  Initial commit
#>

# Sign in to your Azure account
<#
Login-AzureRMAccount
#>

# Initialize variables
$subscriptionName = "Windows Azure Internal Consumption"
$location1 = "West US"
$location2 = "East US"
$userName = "mdcadmin"
$password = "mdcpwd123!"
$vmInstances = 3

# Values for resource names
$appName = "mdc"
$region1 = "wu"
$region2 = "eu"

# Set the current subscription
Select-AzureRmSubscription -SubscriptionName $subscriptionName

# Create the resource group.  Even though a Resource Group is created in a specific location, it can contain resources in multiple locations.
$rgName = "${appName}${region1}rg1"
$tags = @{Name="App";Value="Multi-Datacenter"}
New-AzureRMResourceGroup -Name $rgName -Location $location1 -Tag $tags
Get-AzureRmResourceGroup -Name $rgName -Location $location1

# Create the storage accounts
$storageAccount1 = "${appName}${region1}ssaweb1"
$storageAccount2 = "${appName}${region2}ssaweb1"
New-AzureRMStorageAccount -ResourceGroupName $rgName -Name $storageAccount1 -Type Standard_LRS -Location $location1 -Tags $tags
New-AzureRMStorageAccount -ResourceGroupName $rgName -Name $storageAccount2 -Type Standard_LRS -Location $location2 -Tags $tags

# Set the current storage account
Set-AzureRmCurrentStorageAccount -ResourceGroupName $rgName -StorageAccountName $storageAccount1

# Upload the DSC files to the storage accounts
$path = "C:\Users\emondek\Documents\Git-Repos\multi-dc-deploy\Install-IIS.ps1"
Publish-AzureRmVMDscConfiguration -ResourceGroupName $rgName -ConfigurationPath $path -StorageAccountName $storageAccount1
Publish-AzureRmVMDscConfiguration -ResourceGroupName $rgName -ConfigurationPath $path -StorageAccountName $storageAccount2

# Get the latest version of the PowerShell DSC extension
Get-AzureVMAvailableExtension -Publisher Microsoft.PowerShell
$dscExtensionVersion = "2.13"

# Create the VNets
$vnetName1 = "${appName}${region1}vnet1"
$vnetName2 = "${appName}${region2}vnet1"
$vnetAddressPrefix1 = "172.17.38.0/23"
$vnetAddressPrefix2 = "172.17.39.0/23"

$webSubnetName = "WEB"
$appSubnetName = "APP"
$dbSubnetName = "DB"
$infSubnetName = "INF"

$webAddressPrefix1 = "172.17.38.0/26"
$appAddressPrefix1 = "172.17.38.68/26"
$dbAddressPrefix1 = "172.17.38.128/27"
$infAddressPrefix1 = "172.17.38.160/28"

$webAddressPrefix2 = "172.17.39.0/26"
$appAddressPrefix2 = "172.17.39.68/26"
$dbAddressPrefix2 = "172.17.39.128/27"
$infAddressPrefix2 = "172.17.39.160/28"

$webSubnetConfig1 = New-AzureRmVirtualNetworkSubnetConfig -Name $webSubnetName -AddressPrefix $webAddressPrefix1
$appSubnetConfig1 = New-AzureRmVirtualNetworkSubnetConfig -Name $appSubnetName -AddressPrefix $appAddressPrefix1
$dbSubnetConfig1 = New-AzureRmVirtualNetworkSubnetConfig -Name $dbSubnetName -AddressPrefix $dbAddressPrefix1
$infSubnetConfig1 = New-AzureRmVirtualNetworkSubnetConfig -Name $infSubnetName -AddressPrefix $infAddressPrefix1

$webSubnetConfig2 = New-AzureRmVirtualNetworkSubnetConfig -Name $webSubnetName -AddressPrefix $webAddressPrefix2
$appSubnetConfig2 = New-AzureRmVirtualNetworkSubnetConfig -Name $appSubnetName -AddressPrefix $appAddressPrefix2
$dbSubnetConfig2 = New-AzureRmVirtualNetworkSubnetConfig -Name $dbSubnetName -AddressPrefix $dbAddressPrefix2
$infSubnetConfig2 = New-AzureRmVirtualNetworkSubnetConfig -Name $infSubnetName -AddressPrefix $infAddressPrefix2

$vnet1 = New-AzureRmVirtualNetwork -ResourceGroupName $rgName -Name $vnetName1 -Location $location1 -AddressPrefix $vnetAddressPrefix1 -Subnet $webSubnetConfig1,$appSubnetConfig1,$dbSubnetConfig1,$infSubnetConfig1 -Tag $tags
$vnet2 = New-AzureRmVirtualNetwork -ResourceGroupName $rgName -Name $vnetName2 -Location $location2 -AddressPrefix $vnetAddressPrefix2 -Subnet $webSubnetConfig2,$appSubnetConfig2,$dbSubnetConfig2,$infSubnetConfig2 -Tag $tags

$vnet1 = Get-AzureRmVirtualNetwork -ResourceGroupName $rgName -Name $vnetName1
$vnet2 = Get-AzureRmVirtualNetwork -ResourceGroupName $rgName -Name $vnetName2

$webSubnet1 = $vnet1.Subnets[0]
$appSubnet1 = $vnet1.Subnets[1]
$dbSubnet1 = $vnet1.Subnets[2]
$infSubnet1 = $vnet1.Subnets[3]

$webSubnet2 = $vnet2.Subnets[0]
$appSubnet2 = $vnet2.Subnets[1]
$dbSubnet2 = $vnet2.Subnets[2]
$infSubnet2 = $vnet2.Subnets[3]

# Create the Public IP Addresses for RDP access
$publicIPName3 = "${appName}${region1}vipweb2"
$publicIPName4 = "${appName}${region2}vipweb2"

$publicIP3 = New-AzureRmPublicIpAddress -ResourceGroupName $rgName -Name $publicIPName3 -Location $location1 -AllocationMethod Dynamic -IdleTimeoutInMinutes 30 -Tag $tags
$publicIP4 = New-AzureRmPublicIpAddress -ResourceGroupName $rgName -Name $publicIPName4 -Location $location2 -AllocationMethod Dynamic -IdleTimeoutInMinutes 30 -Tag $tags

$publicIP3 = Get-AzureRmPublicIpAddress -ResourceGroupName $rgName -Name $publicIPName3
$publicIP4 = Get-AzureRmPublicIpAddress -ResourceGroupName $rgName -Name $publicIPName4

# Create the Load Balancers
$lbName1 = "${appName}${region1}lbweb1"
$lbName2 = "${appName}${region2}lbweb1"

# Frontend IP Config using the Public VIP
$lbFeIpConfigName1 = "lb-feip-1"
$lbFeIpConfigName2 = "lb-feip-2"

$lbFeIpConfig1 = New-AzureRmLoadBalancerFrontendIpConfig -Name $lbFeIpConfigName1 -PublicIpAddress $publicIP3
$lbFeIpConfig2 = New-AzureRmLoadBalancerFrontendIpConfig -Name $lbFeIpConfigName2 -PublicIpAddress $publicIP4

# Inbound NAT Rules for Remote Desktop per VM
$lbInboundNatRules1 = @()
for ($count = 1; $count -le $vmInstances; $count++) 
{
    $ruleName = "nat-rdp-${count}"
    $frontEndPort = 57100 + $count
    $backendPort = 3389
    $lbInboundNatRules1 += New-AzureRmLoadBalancerInboundNatRuleConfig -Name $ruleName -FrontendIpConfiguration $lbFeIpConfig1 -Protocol Tcp -FrontendPort $frontEndPort -BackendPort $backendPort -IdleTimeoutInMinutes 30
}
$lbInboundNatRules2 = @()
for ($count = 1; $count -le $vmInstances; $count++) 
{
    $ruleName = "nat-rdp-${count}"
    $frontEndPort = 57100 + $count
    $backendPort = 3389
    $lbInboundNatRules2 += New-AzureRmLoadBalancerInboundNatRuleConfig -Name $ruleName -FrontendIpConfiguration $lbFeIpConfig2 -Protocol Tcp -FrontendPort $frontEndPort -BackendPort $backendPort -IdleTimeoutInMinutes 30
}

# Backend IP Address Pool
$lbBeIpPoolName1 = "lb-be-ip-pool-1"
$lbBeIpPoolName2 = "lb-be-ip-pool-2"
$lbBeIpPool1 = New-AzureRmLoadBalancerBackendAddressPoolConfig -Name $lbBeIpPoolName1
$lbBeIpPool2 = New-AzureRmLoadBalancerBackendAddressPoolConfig -Name $lbBeIpPoolName2

# Health Check Probe Config for HTTP
<#
$lbProbeName1 = "lb-probe-1"
$lbProbeName2 = "lb-probe-2"
$lbProbe1 = New-AzureRmLoadBalancerProbeConfig -Name $lbProbeName1 -RequestPath "/" -Protocol Http -Port 80 -IntervalInSeconds 15 -ProbeCount 2
$lbProbe2 = New-AzureRmLoadBalancerProbeConfig -Name $lbProbeName2 -RequestPath "/" -Protocol Http -Port 80 -IntervalInSeconds 15 -ProbeCount 2
#>

# Load Balancing Rule for HTTP
<#
$lbRuleName1 = "lb-http-1"
$lbRuleName2 = "lb-http-2"
$lbRule1 = New-AzureRmLoadBalancerRuleConfig -Name $lbRuleName1 -FrontendIpConfiguration $lbFeIpConfig1 -BackendAddressPool $lbBeIpPool1 -Probe $lbProbe1 -Protocol Tcp -FrontendPort 80 -BackendPort 80 -LoadDistribution Default
$lbRule2 = New-AzureRmLoadBalancerRuleConfig -Name $lbRuleName2 -FrontendIpConfiguration $lbFeIpConfig2 -BackendAddressPool $lbBeIpPool2 -Probe $lbProbe2 -Protocol Tcp -FrontendPort 80 -BackendPort 80 -LoadDistribution Default
#>

# Create the Load Balancer using above config objects
<#
$lb1 = New-AzureRmLoadBalancer -ResourceGroupName $rgName -Name $lbName1 -Location $location1 -FrontendIpConfiguration $lbFeIpConfig1 -BackendAddressPool $lbBeIpPool1 -Probe $lbProbe1 -InboundNatRule $lbInboundNatRules1 -LoadBalancingRule $lbRule1
$lb2 = New-AzureRmLoadBalancer -ResourceGroupName $rgName -Name $lbName2 -Location $location2 -FrontendIpConfiguration $lbFeIpConfig2 -BackendAddressPool $lbBeIpPool2 -Probe $lbProbe2 -InboundNatRule $lbInboundNatRules2 -LoadBalancingRule $lbRule2
#>

$lb1 = New-AzureRmLoadBalancer -ResourceGroupName $rgName -Name $lbName1 -Location $location1 -FrontendIpConfiguration $lbFeIpConfig1 -BackendAddressPool $lbBeIpPool1 -InboundNatRule $lbInboundNatRules1 -Tag $tags
$lb2 = New-AzureRmLoadBalancer -ResourceGroupName $rgName -Name $lbName2 -Location $location2 -FrontendIpConfiguration $lbFeIpConfig2 -BackendAddressPool $lbBeIpPool2 -InboundNatRule $lbInboundNatRules2 -Tag $tags

# Create the NICs for each VM
$nics1 = @()
for ($count=1; $count -le $vmInstances; $count++)
{
    $nicName = "${appName}${region1}nic${count}"
    $nicIndex = $count - 1
    $nics1 += New-AzureRmNetworkInterface -ResourceGroupName $rgName -Name $nicName -Location $location1 -SubnetId $vnet1.Subnets[0].Id -LoadBalancerBackendAddressPoolId $lb1.BackendAddressPools[0].Id -LoadBalancerInboundNatRuleId $lb1.InboundNatRules[$nicIndex].Id -Tag $tags
}
$nics2 = @()
for ($count=1; $count -le $vmInstances; $count++)
{
    $nicName = "${appName}${region2}nic${count}"
    $nicIndex = $count - 1
    $nics2 += New-AzureRmNetworkInterface -ResourceGroupName $rgName -Name $nicName -Location $location2 -SubnetId $vnet2.Subnets[0].Id -LoadBalancerBackendAddressPoolId $lb2.BackendAddressPools[0].Id -LoadBalancerInboundNatRuleId $lb2.InboundNatRules[$nicIndex].Id -Tag $tags
}

<#
# Create the NICs for each VM
$nics1 = @()
for ($count=1; $count -le $vmInstances; $count++)
{
    $nicName = "${appName}${region1}nic${count}"
    $nicIndex = $count - 1
    $nics1 += New-AzureRmNetworkInterface -ResourceGroupName $rgName -Name $nicName -Location $location1 -SubnetId $vnet1.Subnets[0].Id
}
$nics2 = @()
for ($count=1; $count -le $vmInstances; $count++)
{
    $nicName = "${appName}${region2}nic${count}"
    $nicIndex = $count - 1
    $nics2 += New-AzureRmNetworkInterface -ResourceGroupName $rgName -Name $nicName -Location $location2 -SubnetId $vnet2.Subnets[0].Id
}
#>

# Create the Availability Sets
$avSetName1 = "${appName}${region1}asweb1"
$avSetName2 = "${appName}${region2}asweb1"

$avSet1 = New-AzureRmAvailabilitySet -ResourceGroupName $rgName -Name $avSetName1 -Location $location1
$avSet2 = New-AzureRmAvailabilitySet -ResourceGroupName $rgName -Name $avSetName2 -Location $location2

# Specify local Admin credentials
$vmAdminCreds = Get-Credential -Message "Enter local admin credentials for new VMs..."

# Create the VMs
$publisher = "MicrosoftWindowsServer"
$offer = "WindowsServer"
$sku = "2012-R2-Datacenter"
$version = "4.0.20151214"
<#
Get-AzureRmVMImagePublisher -Location $location1
Get-AzureRmVMImageOffer -Location $location1 -PublisherName $publisher
Get-AzureRmVMImageSku -Location $location1 -PublisherName $publisher -Offer $offer
Get-AzureRmVMImage -Location $location1 -PublisherName $publisher -Offer $offer -Sku $sku
#>

$vmSize = "Standard_DS1"

$vms1 = @()
for ($count = 1; $count -le $vmInstances; $count++)
{
    $vmName = "${appName}${region1}vmweb${count}"

    $vmIndex = $count - 1

    $osDiskLabel = "OSDisk"
    $osDiskName = "${vmName}-osdisk"
    $osDiskUri = "https://${storageAccount1}.blob.core.windows.net/vhds/${osDiskName}.vhd"

    $vmConfig = New-AzureRmVMConfig -VMName $vmName -VMSize $vmSize -AvailabilitySetId $avSet1.Id | `
        Set-AzureRmVMOperatingSystem -Windows -ComputerName $vmName -Credential $vmAdminCreds -ProvisionVMAgent -EnableAutoUpdate | `
        Set-AzureRmVMSourceImage -PublisherName $publisher -Offer $offer -Skus $sku -Version $version | `
        Set-AzureRmVMOSDisk -Name $osDiskLabel -VhdUri $osDiskUri -CreateOption fromImage | `
        Add-AzureRmVMNetworkInterface -Id $nics1[$vmIndex].Id -Primary

    New-AzureRmVM -VM $vmConfig -ResourceGroupName $rgName -Location $location1 -Tags $tags

#    Set-AzureRmVMDscExtension -ResourceGroupName $rgName -VMName $vmName -ArchiveBlobName "Install-IIS.ps1.zip" -ArchiveStorageAccountName $storageAccount1 -ConfigurationName "IISInstall" -Version $dscExtensionVersion

    $vms1 += Get-AzureRmVM -ResourceGroupName $rgName -Name $vmName
}

$vms2 = @()
for ($count = 1; $count -le $vmInstances; $count++)
{
    $vmName = "${appName}${region2}vmweb${count}"

    $vmIndex = $count - 1

    $osDiskLabel = "OSDisk"
    $osDiskName = "${vmName}-osdisk"
    $osDiskUri = "https://${storageAccount2}.blob.core.windows.net/vhds/${osDiskName}.vhd"

    $vmConfig = New-AzureRmVMConfig -VMName $vmName -VMSize $vmSize -AvailabilitySetId $avSet2.Id | `
        Set-AzureRmVMOperatingSystem -Windows -ComputerName $vmName -Credential $vmAdminCreds -ProvisionVMAgent -EnableAutoUpdate | `
        Set-AzureRmVMSourceImage -PublisherName $publisher -Offer $offer -Skus $sku -Version $version | `
        Set-AzureRmVMOSDisk -Name $osDiskLabel -VhdUri $osDiskUri -CreateOption fromImage | `
        Add-AzureRmVMNetworkInterface -Id $nics2[$vmIndex].Id -Primary

    New-AzureRmVM -VM $vmConfig -ResourceGroupName $rgName -Location $location2 -Tags $tags

#    Set-AzureRmVMDscExtension -ResourceGroupName $rgName -VMName $vmName -ArchiveBlobName "Install-IIS.ps1.zip" -ArchiveStorageAccountName $storageAccount2 -ConfigurationName "IISInstall" -Version $dscExtensionVersion

    $vms2 += Get-AzureRmVM -ResourceGroupName $rgName -Name $vmName
}

# Install IIS on each VM using PowerShell DSC
<#
for ($count = 1; $count -le $vmInstances; $count++)
{
    $vmName = "${appName}${region1}vmweb${count}"
    Set-AzureRmVMDscExtension -ResourceGroupName $rgName -VMName $vmName -ArchiveBlobName "Install-IIS.ps1.zip" -ArchiveStorageAccountName $storageAccount1 -ConfigurationName "IISInstall" -Version $dscExtensionVersion
}
for ($count = 1; $count -le $vmInstances; $count++)
{
    $vmName = "${appName}${region2}vmweb${count}"
    Set-AzureRmVMDscExtension -ResourceGroupName $rgName -VMName $vmName -ArchiveBlobName "Install-IIS.ps1.zip" -ArchiveStorageAccountName $storageAccount2 -ConfigurationName "IISInstall" -Version $dscExtensionVersion
}
#>

# Create the Public IP Addresses for the Application Gateways
$publicIPName1 = "${appName}${region1}vipweb1"
$publicIPName2 = "${appName}${region2}vipweb1"

$publicIP1 = New-AzureRmPublicIpAddress -ResourceGroupName $rgName -Name $publicIPName1 -Location $location1 -AllocationMethod Dynamic -IdleTimeoutInMinutes 30 -Tag $tags
$publicIP2 = New-AzureRmPublicIpAddress -ResourceGroupName $rgName -Name $publicIPName2 -Location $location2 -AllocationMethod Dynamic -IdleTimeoutInMinutes 30 -Tag $tags

$publicIP1 = Get-AzureRmPublicIpAddress -ResourceGroupName $rgName -Name $publicIPName1
$publicIP2 = Get-AzureRmPublicIpAddress -ResourceGroupName $rgName -Name $publicIPName2

# Create the Application Gateways
$appGWIPConfigName1 = "appgw-ip-config-1"
$appGWIPConfigName2 = "appgw-ip-config-2"

$appGWIPConfig1 = New-AzureRmApplicationGatewayIPConfiguration -Name $appGWIPConfigName1 -Subnet $appSubnet1
$appGWIPConfig2 = New-AzureRmApplicationGatewayIPConfiguration -Name $appGWIPConfigName2 -Subnet $appSubnet2

$appGWBEPoolName1 = "appgw-be-pool-1"
$appGWBEPoolName2 = "appgw-be-pool-2"

<#
$appGWBEPoolIPAddrs1 = "172.17.38.4", "172.17.38.5", "172.17.38.6"
$appGWBEPoolIPAddrs2 = "172.17.39.4", "172.17.39.5", "172.17.39.6"

$appGWBEPool1 = New-AzureRmApplicationGatewayBackendAddressPool -Name $appGWBEPoolName1 -BackendIPAddresses $appGWBEPoolIPAddrs1
$appGWBEPool2 = New-AzureRmApplicationGatewayBackendAddressPool -Name $appGWBEPoolName2 -BackendIPAddresses $appGWBEPoolIPAddrs2
#>

$appGWBEPoolIPConfigIds1 = @()
for ($index = 0; $index -lt $nics1.Count; $index++)
{
    $appGWBEPoolIPConfigIds1 += $nics1[$index].Id
}
$appGWBEPoolIPConfigIds2 = @()
for ($index = 0; $index -lt $nics2.Count; $index++)
{
    $appGWBEPoolIPConfigIds2 += $nics2[$index].Id
}

$appGWBEPool1 = New-AzureRmApplicationGatewayBackendAddressPool -Name $appGWBEPoolName1 -BackendIPConfigurationIds $appGWBEPoolIPConfigIds1
$appGWBEPool2 = New-AzureRmApplicationGatewayBackendAddressPool -Name $appGWBEPoolName2 -BackendIPConfigurationIds $appGWBEPoolIPConfigIds2

$appGWBEHttpSettingName1 = "appgw-be-http-setting-1"
$appGWBEHttpSettingName2 = "appgw-be-http-setting-2"

$appGWBEHttpSetting1 = New-AzureRmApplicationGatewayBackendHttpSettings -Name $appGWBEHttpSettingName1 -Port 80 -Protocol Http -CookieBasedAffinity Disabled
$appGWBEHttpSetting2 = New-AzureRmApplicationGatewayBackendHttpSettings -Name $appGWBEHttpSettingName2 -Port 80 -Protocol Http -CookieBasedAffinity Disabled

$appGWFEPortName1 = "appgw-fe-port-1"
$appGWFEPortName2 = "appgw-fe-port-2"

$appGWFEPort1 = New-AzureRmApplicationGatewayFrontendPort -Name $appGWFEPortName1  -Port 80
$appGWFEPort2 = New-AzureRmApplicationGatewayFrontendPort -Name $appGWFEPortName2  -Port 80

$appGWFEIPConfigName1 = "appgw-fe-ip-config-1"
$appGWFEIPConfigName2 = "appgw-fe-ip-config-2"

$appGWFEIPConfig1 = New-AzureRmApplicationGatewayFrontendIPConfig -Name $appGWFEIPConfigName1 -PublicIPAddress $publicIP1
$appGWFEIPConfig2 = New-AzureRmApplicationGatewayFrontendIPConfig -Name $appGWFEIPConfigName2 -PublicIPAddress $publicIP2

$appGWHttpListenerName1 = "appgw-http-listener-1"
$appGWHttpListenerName2 = "appgw-http-listener-2"

$appGWHttpListener1 = New-AzureRmApplicationGatewayHttpListener -Name $appGWHttpListenerName1  -Protocol Http -FrontendIPConfiguration $appGWFEIPConfig1 -FrontendPort $appGWFEPort1
$appGWHttpListener2 = New-AzureRmApplicationGatewayHttpListener -Name $appGWHttpListenerName2  -Protocol Http -FrontendIPConfiguration $appGWFEIPConfig2 -FrontendPort $appGWFEPort2

$appGWRequestRoutingRuleName1 = "appgw-request-routing-rule-1"
$appGWRequestRoutingRuleName2 = "appgw-request-routing-rule-2"

$appGWRequestRoutingRule1 = New-AzureRmApplicationGatewayRequestRoutingRule -Name $appGWRequestRoutingRuleName1 -RuleType Basic -BackendHttpSettings $appGWBEHttpSetting1 -HttpListener $appGWHttpListener1 -BackendAddressPool $appGWBEPool1
$appGWRequestRoutingRule2 = New-AzureRmApplicationGatewayRequestRoutingRule -Name $appGWRequestRoutingRuleName2 -RuleType Basic -BackendHttpSettings $appGWBEHttpSetting2 -HttpListener $appGWHttpListener2 -BackendAddressPool $appGWBEPool2

$appGWSku1 = New-AzureRmApplicationGatewaySku -Name Standard_Medium -Tier Standard -Capacity 2
$appGWSku2 = New-AzureRmApplicationGatewaySku -Name Standard_Medium -Tier Standard -Capacity 2

$appGWName1 = "${appName}${region1}apgwweb1"
$appGWName2 = "${appName}${region2}apgwweb1"

$appGW1 = New-AzureRmApplicationGateway -Name $appGWName1 -ResourceGroupName $rgName -Location $location1 -BackendAddressPools $appGWBEPool1 -BackendHttpSettingsCollection $appGWBEHttpSetting1 -FrontendIpConfigurations $appGWFEIPConfig1  -GatewayIpConfigurations $appGWIPConfig1 -FrontendPorts $appGWFEPort1 -HttpListeners $appGWHttpListener1 -RequestRoutingRules $appGWRequestRoutingRule1 -Sku $appGWSku1 -Tag $tags
$appGW2 = New-AzureRmApplicationGateway -Name $appGWName2 -ResourceGroupName $rgName -Location $location2 -BackendAddressPools $appGWBEPool2 -BackendHttpSettingsCollection $appGWBEHttpSetting2 -FrontendIpConfigurations $appGWFEIPConfig2  -GatewayIpConfigurations $appGWIPConfig2 -FrontendPorts $appGWFEPort2 -HttpListeners $appGWHttpListener2 -RequestRoutingRules $appGWRequestRoutingRule2 -Sku $appGWSku2 -Tag $tags

Get-AzureRmApplicationGateway -ResourceGroupName $rgName -Name $appGWName1
Get-AzureRmApplicationGateway -ResourceGroupName $rgName -Name $appGWName2

# Configure Azure Traffic Manager
$tmName = "${appName}tm1"
$tmDomainName = "${appName}tm1"
$endPoint1 = "${appName}${region1}ep1"
$endPoint2 = "${appName}${region2}ep1"
$tmProfile = New-AzureRmTrafficManagerProfile -ResourceGroupName $rgName –Name $tmName -TrafficRoutingMethod Weighted -RelativeDnsName $tmDomainName -Ttl 300 -MonitorProtocol HTTP -MonitorPort 80 -MonitorPath "/"
New-AzureRmTrafficManagerEndpoint -ResourceGroupName $rgName –Name $endPoint1 –ProfileName $tmName –Type AzureEndpoints -TargetResourceId $publicIP1.Id –EndpointStatus Enabled
New-AzureRmTrafficManagerEndpoint -ResourceGroupName $rgName –Name $endPoint2 –ProfileName $tmName –Type AzureEndpoints -TargetResourceId $publicIP2.Id –EndpointStatus Enabled

# Configure Azure Insights with Auto-scale
### TO DO ###

# Clean up the environment
Remove-AzureRmResourceGroup -Name $rgName
