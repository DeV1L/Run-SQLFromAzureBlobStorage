   param( 
        [parameter(Mandatory=$True)] 
        [string] $SqlServer,
        [parameter(Mandatory=$False)] 
        [string] $SqlServerPort = 1433,
        [parameter(Mandatory=$True)] 
        [string] $Database,
        [parameter(Mandatory=$True)] 
        [string] $Script
     ) 

##########Login##########
$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

    "Logging in to Azure..."
    Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

##########Download SQL script from blob##########
$ResourceGroupName = "automationuems"
$StorageAccountName = "automationuems"
$Container = "scripts"
$Path = "$env:TEMP\$Script"

$StorageAccountKey = Get-AutomationVariable -Name 'StorageAccountKey'
$Ctx = New-AzureStorageContext $StorageAccountName -StorageAccountKey $StorageAccountKey

Get-AzureStorageBlobContent -Container $Container -Blob $Script -Destination $Path -Context $Ctx -Verbose

##########Run SQL script##########
$CmdCommandText = Get-Content $Path

$SqlCredential = Get-AutomationPSCredential -Name "SqlCredentialAsset"
 
    if ($SqlCredential -eq $null) 
    { 
        throw "Could not retrieve '$SqlCredentialAsset' credential asset. Check that you created this first in the Automation service." 
    }   
    # Get the username and password from the SQL Credential 
    $SqlUsername = $SqlCredential.UserName 
    $SqlPass = $SqlCredential.GetNetworkCredential().Password 
     
    # Define the connection to the SQL Database 
    $Conn = New-Object System.Data.SqlClient.SqlConnection("Server=tcp:$SqlServer,$SqlServerPort;Database=$Database;User ID=$SqlUsername;Password=$SqlPass;Trusted_Connection=False;Encrypt=True;Connection Timeout=30;") 
         
    # Open the SQL connection 
    $Conn.Open()
  
    # Define the SQL command to run. In this case we are getting the number of rows in the table 
    $Cmd=new-object system.Data.SqlClient.SqlCommand($CmdCommandText, $Conn) 
    $Cmd.CommandTimeout=120 
 
    ###
    $CmdDbResult = $Cmd.ExecuteReader()
    $CmdDbResult

    $Conn.Close()
