# DSC uses the Get-TargetResource function to fetch the status of the resource instance specified in the parameters for the target machine

[int] $currentMaxDOP

function get-NumberOfLogicalProcessors {
        <#
        .Synopsis
            retrieve NumberOfLogicalProcessors by using WMI
        .DESCRIPTION
         this function  is used as a shortcut to 
          $NumberOfLogicalProcessors =  (Get-WmiObject –class Win32_processor -Property NumberOfLogicalProcessors).NumberOfLogicalProcessors                
        no parameters.

    .INPUTS
            none

    .OUTPUTS
            integer value representing the current Number of Logical Processors as shown in WMI
    .Example
            $NumberOfLogicalProcessors =  get-NumberOfLogicalProcessors

            This returns the WMI NumberOfLogicalProcessors in $NumberOfLogicalProcessors
    .LINK
        http://www.themigrationwizard.com

    .NOTES
        none
    #>
                $NumberOfLogicalProcessors =  (Get-WmiObject –class Win32_processor -Property NumberOfLogicalProcessors).NumberOfLogicalProcessors 
                return $NumberOfLogicalProcessors    
}

function get-SQLQueryResult {
            <#
        .Synopsis
                tbd
        .DESCRIPTION
 tbd
    .INPUTS
             input query string $queryString , must represent your query string
    .OUTPUTS
            data table result, representing the result of the input query

    .Example

            $mydt = get-SQLServerQueryResult ($myQueryString)
            ... do something with  the data table in $mydt ...

    .LINK
        http://www.themigrationwizard.com

    .NOTES
        none
    #>
    Param ( 
        [string]$queryString 
        )

              # currently we assume we need to connect to localhost only      
                    $server = "localhost"
                    $database = "master"        
                    $port = 1433
                    $connectionString = "Server="+$server+","+$port+";Database=$database;Integrated Security=True;" 

                    $noneandnull = [Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer')
                    $noneandnull = [Reflection.Assembly]::LoadWithPartialName('System.Data')

                    $conn = new-object System.Data.SqlClient.SqlConnection 
                    $conn.ConnectionString = $connectionString 
                    $conn.Open() 
 
                    $cmd = new-object System.Data.SqlClient.SqlCommand 
                    $cmd.Connection = $conn 
 
                    # Ensure advanced options are available 
                    # $commandText = "sp_configure 'show advanced options', $NumberOfLogicalProcessors;RECONFIGURE WITH OVERRIDE;"         
                    # $commandText = "SELECT name, value_in_use FROM sys.configurations WHERE name LIKE 'max degree of parallelism'";
                    $cmd.CommandText = $queryString 
                    # avoid output as the only result MUST be true or false here
                    $noneandnull = $cmd.executenonquery()

                    #Execute the Command
                    $sqlReader = $cmd.ExecuteReader()

                    $Datatable = New-Object System.Data.DataTable
                    $DataTable.Load($SqlReader)
                    $conn.close() 
                    return ,$Datatable
}

function get-currentMaxDOP {
            <#
        .Synopsis
                tbd
        .DESCRIPTION
 tbd
    .INPUTS
             input query string $queryString , must represent your query string
    .OUTPUTS
            data table result, representing the result of the input query

    .Example

            $mydt = get-SQLServerQueryResult ($myQueryString)
            ... do something with  the data table in $mydt ...

    .LINK
        http://www.themigrationwizard.com

    .NOTES
        none
    #>
    $commandText = "SELECT name, value_in_use FROM sys.configurations WHERE name LIKE 'max degree of parallelism'";
  
    $Datatable = get-SQLQueryResult $CommandText
    $currentMaxDOP = [int]$Datatable.Rows[0].ItemArray[1]
    return $currentMaxDOP
}


function Get-TargetResource
{
    param
    (
        [Parameter(Mandatory)]
        [ValidateSet("Present", "Absent")]
        [string]$ensure,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$targetValue
    )
                    $NumberOfLogicalProcessors =  get-NumberOfLogicalProcessors
                    $currentMaxDOP = get-currentMaxDOP
                                        
                    if ($targetValue -eq "automatic") {
                          $result = ($NumberOfLogicalProcessors -eq $currentMaxDOP)
                    } 
                    else {
                          $result = ($targetValue -eq $currentMaxDOP)
                    }
         
                    @{ 
                        ensure = "Present"
                        targetValue = "$currentMaxDOP ($result, as you configured $targetValue and current value is  $currentMaxDOP while NumberOfLogicalProcessors is $NumberOfLogicalProcessors)" 
                     } 
                    #Stop-Transcript    
}

# The Set-TargetResource function is used to create, delete or configure a service on the target machine. 
function Set-TargetResource
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param
    (
        [Parameter(Mandatory)]
        [ValidateSet("Present", "Absent")]
        [string]$ensure,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$targetValue
    )

    if ($ensure -eq "Present") {
        $NumberOfLogicalProcessors =  get-NumberOfLogicalProcessors
        if ($targetValue -eq "automatic") {  
            Write-Verbose "automatic configuration detected. "  
           $commandText = "sp_configure 'max degree of parallelism', '$NumberOfLogicalProcessors';RECONFIGURE WITH OVERRIDE" 
           Write-Verbose "running statement: $commandText "
           $result = get-SQLQueryResult($commandText)
        } else {
            # object type is string, so check for an int first 
            if ( ($targetValue + 0)  -eq $targetValue ) {
                Write-Verbose "manual configuration will try to set $targetValue "
                $commandText = "sp_configure 'max degree of parallelism', '$targetValue';RECONFIGURE WITH OVERRIDE"     
                Write-Verbose "running this statement: $commandText. "
                $result = get-SQLQueryResult($commandText)
            } else {
                Write-Verbose "something is wrong with $targetValue , does not look like an integer value. operation cancelled."
            }
        }
 
        Write-Verbose ($result | fl)
    } else {
        Write-Verbose "ensure is 'Absent'. I will not make any changes."
    }
}

function Test-TargetResource {
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param (
        [Parameter(Mandatory)]
        [ValidateSet("Present", "Absent")]
        [string]$ensure,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$targetValue
    )

    $NumberOfLogicalProcessors =  get-NumberOfLogicalProcessors
    $currentMaxDOP = get-currentMaxDOP

    if ($targetValue -eq "automatic") {
        write-verbose "Configuration automatic using NumberOfLogicalProcessors: $NumberOfLogicalProcessors and currentMaxDOP: $currentMaxDOP "     
        $result = ($NumberOfLogicalProcessors -eq $currentMaxDOP)
        Write-Verbose "current result is $result"
    } else {
        $result = ($targetValue -eq $currentMaxDOP)
    }

    $result
}