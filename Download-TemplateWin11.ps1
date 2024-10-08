# This code is based off of "Create a Windows Custom Managed IMage from an Azure Platform Vanilla OS Image."
# https://github.com/danielsollondon/azvmimagebuilder/tree/master/quickquickstarts/0_Creating_a_Custom_Windows_Managed_Image


# Start by downloading a template
# The template used is from the Azure Quick Start templates
# it creates a Windows image and outputs the finished image to a Managed IMage
# Set the template file path and the template file name
$Win11Url = 'https://raw.githubusercontent.com/tsrob50/AIB/main/Win10MultiTemplate.json'
$Win11FileName = 'Win11MultiTemplate.json'
#Test to see if the path exists.  Create it if not
if ((Test-Path .\Template) -eq $false) {
    New-Item -ItemType Directory -Name 'Template'
}
# Confirm to overwrite file if it already exists
if ((Test-Path .\Template\$Win11FileName) -eq $true) {
    $confirmation = Read-Host 'Are you Sure You Want to Replace the Template?:'
    if ($confirmation -eq 'y' -or $confirmation -eq 'yes' -or $confirmation -eq 'Yes') {
        Invoke-WebRequest -Uri $Win11Url -OutFile ".\Template\$Win11FileName" -UseBasicParsing
    }
} else {
    Invoke-WebRequest -Uri $Win11Url -OutFile ".\Template\$Win11FileName" -UseBasicParsing
}

# Setup the variables
# The first four need to match Enable-identity.ps1 script
# destination image resource group
$imageResourceGroup = 'AIBManagedIDRG'
# location (see possible locations in main docs)
$location = (Get-AzResourceGroup -Name $imageResourceGroup).Location
# your subscription, this will get your current subscription
$subscriptionID = (Get-AzContext).Subscription.Id
# name of the image to be created
$imageName = 'aibCustomImgWin11'
# image template name
$imageTemplateName = 'imageTemplateWin11Multi'
# distribution properties object name (runOutput), i.e. this gives you the properties of the managed image on completion
$runOutputName = 'win11Client'
# Set the Template File Path
$templateFilePath = ".\Template\$Win11FileName"
# user-assigned managed identity
$identityName = (Get-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup).Name
# get the user assigned managed identity id
$identityNameResourceId = (Get-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $identityName).Id

# Update the Template
((Get-Content -Path $templateFilePath -Raw) -replace '<subscriptionID>', $subscriptionID) | Set-Content -Path $templateFilePath
((Get-Content -Path $templateFilePath -Raw) -replace '<rgName>', $imageResourceGroup) | Set-Content -Path $templateFilePath
((Get-Content -Path $templateFilePath -Raw) -replace '<region>', $location) | Set-Content -Path $templateFilePath
((Get-Content -Path $templateFilePath -Raw) -replace '<runOutputName>', $runOutputName) | Set-Content -Path $templateFilePath
((Get-Content -Path $templateFilePath -Raw) -replace '<imageName>', $imageName) | Set-Content -Path $templateFilePath
((Get-Content -Path $templateFilePath -Raw) -replace '<imgBuilderId>', $identityNameResourceId) | Set-Content -Path $templateFilePath

# The following commands require the Az.ImageBuilder module
# Install the PowerShell module if not already installed
Install-Module -Name 'Az.ImageBuilder' -AllowPrerelease

# Run the deployment
New-AzResourceGroupDeployment -ResourceGroupName $imageResourceGroup -TemplateFile $templateFilePath -api-version '2024-02-01' -imageTemplateName $imageTemplateName -svclocation $location

# Verify the template
Get-AzImageBuilderTemplate -ImageTemplateName $imageTemplateName -ResourceGroupName $imageResourceGroup |
    Select-Object -Property Name, LastRunStatusRunState, LastRunStatusMessage, ProvisioningState, ProvisioningErrorMessage

# Start the Image Build Process
Start-AzImageBuilderTemplate -ResourceGroupName $imageResourceGroup -Name $imageTemplateName

# Create a VM to test
$Cred = Get-Credential
$ArtifactId = (Get-AzImageBuilderRunOutput -ImageTemplateName $imageTemplateName -ResourceGroupName $imageResourceGroup).ArtifactId
New-AzVM -ResourceGroupName $imageResourceGroup -Image $ArtifactId -Name myWinVM01 -Credential $Cred -Size Standard_DS2_v2

# Remove the template deployment
Remove-AzImageBuilderTemplate -ImageTemplateName $imageTemplateName -ResourceGroupName $imageResourceGroup





# Find the publisher, offer and Sku
# To use for the deployment template to identify
# source marketplace images
# https://www.ciraltos.com/find-skus-images-available-azure-rm/
Get-AzVMImagePublisher -Location $location | Where-Object { $_.PublisherName -like '*win*' } | Format-Table PublisherName, Location
$pubName = 'MicrosoftWindowsDesktop'
Get-AzVMImageOffer -Location $location -PublisherName $pubName | Format-Table Offer, PublisherName, Location
# Set Offer to 'office-365' for images with O365
# $offerName = 'office-365'
$offerName = 'Windows-11'
Get-AzVMImageSku -Location $location -PublisherName $pubName -Offer $offerName | Format-Table Skus, Offer, PublisherName, Location
$skuName = 'Win11-23h2-pro'
Get-AzVMImage -Location $location -PublisherName $pubName -Skus $skuName -Offer $offerName
$version = '22631.4169.240906'
Get-AzVMImage -Location $location -PublisherName $pubName -Offer $offerName -Skus $skuName -Version $version
