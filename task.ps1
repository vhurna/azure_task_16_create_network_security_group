$location = "uksouth"
$resourceGroupName = "mate-azure-task-15"
$virtualNetworkName = "todoapp"

$webSubnetName = "webservers"
$dbSubnetName = "database"
$mngSubnetName = "management"

# Отримуємо існуючу віртуальну мережу та підмережі
Write-Host "Getting existing virtual network and subnets..."
$vnet = Get-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName
$webSubnet = Get-AzVirtualNetworkSubnetConfig -Name $webSubnetName -VirtualNetwork $vnet
$dbSubnet = Get-AzVirtualNetworkSubnetConfig -Name $dbSubnetName -VirtualNetwork $vnet
$mngSubnet = Get-AzVirtualNetworkSubnetConfig -Name $mngSubnetName -VirtualNetwork $vnet

# Створюємо NSG-и
Write-Host "Creating NSGs..."
$webNsg = New-AzNetworkSecurityGroup -Name $webSubnetName -ResourceGroupName $resourceGroupName -Location $location
$dbNsg = New-AzNetworkSecurityGroup -Name $dbSubnetName -ResourceGroupName $resourceGroupName -Location $location
$mngNsg = New-AzNetworkSecurityGroup -Name $mngSubnetName -ResourceGroupName $resourceGroupName -Location $location

# Загальне правило для всіх NSG (дозволити трафік всередині віртуальної мережі)
$commonRule = @{
    Name = "Allow-VNet-Internal"
    Protocol = "*"
    Direction = "Inbound"
    Priority = 100
    SourceAddressPrefix = "VirtualNetwork"
    SourcePortRange = "*"
    DestinationAddressPrefix = "VirtualNetwork"
    DestinationPortRange = "*"
    Access = "Allow"
}

# Правила для web NSG
$webHttpRule = @{
    Name = "Allow-HTTP"
    Protocol = "Tcp"
    Direction = "Inbound"
    Priority = 200
    SourceAddressPrefix = "Internet"
    SourcePortRange = "*"
    DestinationAddressPrefix = "*"
    DestinationPortRange = "80"
    Access = "Allow"
}
$webHttpsRule = @{
    Name = "Allow-HTTPS"
    Protocol = "Tcp"
    Direction = "Inbound"
    Priority = 201
    SourceAddressPrefix = "Internet"
    SourcePortRange = "*"
    DestinationAddressPrefix = "*"
    DestinationPortRange = "443"
    Access = "Allow"
}

# Правила для management NSG
$mngSshRule = @{
    Name = "Allow-SSH"
    Protocol = "Tcp"
    Direction = "Inbound"
    Priority = 200
    SourceAddressPrefix = "Internet"
    SourcePortRange = "*"
    DestinationAddressPrefix = "*"
    DestinationPortRange = "22"
    Access = "Allow"
}

# Додаємо правила
Add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $webNsg @commonRule
Add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $webNsg @webHttpRule
Add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $webNsg @webHttpsRule

Add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $dbNsg @commonRule

Add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $mngNsg @commonRule
Add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $mngNsg @mngSshRule

# Оновлюємо NSG-и
$webNsg | Set-AzNetworkSecurityGroup
$dbNsg | Set-AzNetworkSecurityGroup
$mngNsg | Set-AzNetworkSecurityGroup

# Прив’язуємо NSG-и до підмереж
Write-Host "Associating NSGs with subnets..."
$webSubnet.NetworkSecurityGroup = $webNsg
$dbSubnet.NetworkSecurityGroup = $dbNsg
$mngSubnet.NetworkSecurityGroup = $mngNsg

# Оновлюємо підмережі у віртуальній мережі
Set-AzVirtualNetwork -VirtualNetwork $vnet

# Запуск скриптів
Write-Host "Running artifacts generation script..."
.\scripts\generate-artifacts.ps1

Write-Host "Running validation script..."
.\scripts\validate-artifacts.ps1
