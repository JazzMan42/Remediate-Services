#function remediate-services () {
#requires -version 2
<#
    .SYNOPSIS
    Starts Stops or Restarts a service with it's dependent services in concurrency using jobs, 
    also works with services without dependencies.
    .DESCRIPTION
    There are ~three steps to this process:
    1) Stop the dependent child services
    2) Restart the parent services
    3) Start the dependent child services
    .PARAMETER ServiceName
    Name of the Service, not the display name.
    .INPUTS
    ServiceName
    .OUTPUTS
    Updates throughout the process.
    .NOTES
    Version:        1.0
    Author:         BattleBugs
    Creation Date:  01/01/2014
    Purpose/Change: Initial script development
    .EXAMPLE
    Restart-Service -ServiceName "MySQL"
#>

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Set Error Action to Silently Continue
#$ErrorActionPreference = "SilentlyContinue"

#Dot Source required Function Libraries
#. "C:\Scripts\Functions\Logging_Functions.ps1"

#----------------------------------------------------------[Declarations]----------------------------------------------------------

#Script Version
#$sScriptVersion = "1.0"

#Log File Info

[CmdletBinding()]
Param(

  [Parameter(Mandatory = $True,Position = 1)]
  $ServiceNames,
  [Parameter(Mandatory = $True,Position = 2)]
  [string]$action,
  [switch]$DisplayName
)
$ErrorActionPreference = 'SilentlyContinue'


#-----------------------------------------------------------[Functions]------------------------------------------------------------

$functions = {
  function startServiceDependencies($gsd)
  {
    $ErrorActionPreference = 'SilentlyContinue'
    $gjStart = $gsd | ForEach-Object -Process {
      $tdn = $_.displayname
      Start-Job -Name "Start '$tdn'" -ArgumentList $_ -ScriptBlock{
        $sdn = $args[0].displayname
        $gdsd = $args[0].dependentservices
        #echo $args[0].dependentservices
        try
        {
          $gsmp = (($args[0]).name |
            ForEach-Object -Process {
              tasklist.exe /svc /fi "SERVICES eq $_" /fo csv
            } |
          ConvertFrom-Csv).pid
        }
        catch
        {
          $errormessage = ''
        }
        try
        {
          $gsmpi = Get-Process -pid $gsmp
        }
        catch
        {
          $errormessage
        }
        if(!($gsmp))
        {
          Write-Output -InputObject "Starting dependent service '$sdn'."
          Start-Service -DisplayName $args[0].displayname
          $servicePID = (($args[0]).name |
            ForEach-Object -Process {
              tasklist.exe /svc /fi "SERVICES eq $_" /fo csv
            } |
          ConvertFrom-Csv).pid
          Write-Output -InputObject "Started dependent service '$sdn', new PID $servicePID."
          if(($gdsd))
          {
            $gdjStart = $gdsd | ForEach-Object -Process {
              $tdn = $_.displayname
              Start-Job -Name "Start '$tdn'" -ArgumentList $_ -ScriptBlock{
                try
                {
                  $gsmp = (($args[0]).name |
                    ForEach-Object -Process {
                      tasklist.exe /svc /fi "SERVICES eq $_" /fo csv
                    } |
                  ConvertFrom-Csv).pid
                }
                catch
                {
                  $errormessage
                }
                 
                try
                {
                  $gsmpi = Get-Process -pid $gsmp
                }
                catch
                {
                  $errormessage = ''
                }
                 
                $dsdn = $args[0].displayname
                if(!($gsmp))
                {
                  Write-Output -InputObject "Starting sub dependent service '$dsdn'."
                  Start-Service -DisplayName $args[0].displayname
                  $servicePID = (($args[0]).name |
                    ForEach-Object -Process {
                      tasklist.exe /svc /fi "SERVICES eq $_" /fo csv
                    } |
                  ConvertFrom-Csv).pid
                  Write-Output -InputObject "Started sub dependent service '$dsdn', new PID $servicePID."
                }
                else
                {
                  Write-Output -InputObject "Sub dependent service '$dsdn' has already been started, PID $gsmp"
                }
              }
            }
            if($gdjStart)
            {
              $gdjStart |
              Wait-Job -Timeout 240 |
              Receive-Job -Keep
              $gdjStart | ForEach-Object -Process {
                Format-Table -AutoSize
              }
              $gdjStart | Remove-Job -Force
            }
          }
        }
        else
        {
          Write-Output -InputObject "Dependent service '$sdn' has already been started, PID $gsmp"
        }
      }
    }
    if($gjStart)
    {
      $gjStart |
      Wait-Job -Timeout 240 |
      Receive-Job -Keep
      $gjStart | ForEach-Object -Process {
        Format-Table -AutoSize
      }
      $gjStart | Remove-Job -Force  
    }
  }
  #}
  #$stopServiceDependencies =  {
  function stopServiceDependencies($gsd)
  {
    $gjStop = $gsd | ForEach-Object -Process {
      $tdn = $_.displayname
      Start-Job -Name "Stop '$tdn'" -ArgumentList $_ -ScriptBlock{
        $servicePID = (($args[0]).name |
          ForEach-Object -Process {
            tasklist.exe /svc /fi "SERVICES eq $_" /fo csv
          } |
        ConvertFrom-Csv).pid
        $processInfo = Get-Process -pid $servicePID
        $sdn = $args[0].displayname
        if(($servicePID -gt 0) -and (($processInfo).responding) -and (($args[0]).status -eq 'Running'))
        {
          Write-Output -InputObject "Stopping dependent service '$sdn', PID $servicePID."
          Stop-Service -DisplayName $args[0].displayname -Force
          Write-Output -InputObject "dependent service '$sdn' has been stopped."
        }
        else
        {
          if(($servicePID) -and ($servicePID -gt 0))
          {
            Write-Output -InputObject "Killing dependent service '$sdn',PID $servicePID."
            taskkill.exe /pid $servicePID /f /t
            Write-Output -InputObject "dependent service '$sdn' has been stopped."
          }
          else
          {
            Write-Output -InputObject "dependent service '$sdn' has already been stopped."
          }
        }
      }#end service scriptblock
    }
    if($gjStop)
    {
      $gjStop |
      Wait-Job -Timeout 240 |
      Receive-Job -Keep
      #wait for jobs
      $gjStop | ForEach-Object -Process {
        Format-Table -AutoSize
      }
      $gjStop | Remove-Job -Force
    }
  }

  function remediateStart($ServiceName)
  {
    #Set varables
    $gsmi = Get-Service $ServiceName
    $dn = $gsmi.displayname
    try
    {
      $gsmp = ($gsmi.name |
        ForEach-Object -Process {
          tasklist.exe /svc /fi "SERVICES eq $_" /fo csv
        } |
      ConvertFrom-Csv).pid
    }
    catch
    {
      $errormessage
    }
    try
    {
      $gsmpi = Get-Process -pid $gsmp
    }
    catch
    {
      $errormessage
    }
    $gsd = $gsmi | Select-Object -ExpandProperty dependentservices
    if(($gsd))
    {
      #Begin Starting Process
      Write-Output -InputObject 'Has dependencies!'
      if(!($gsmp))
      {
        Write-Output -InputObject "Starting parent service '$dn'."
        Start-Service -DisplayName $dn
        $gsmp = ($gsmi.name |
          ForEach-Object -Process {
            tasklist.exe /svc /fi "SERVICES eq $_" /fo csv
          } |
        ConvertFrom-Csv).pid
        Write-Output -InputObject "Parent service '$dn' has been started, new PID $gsmp."
        if($gsd)
        {
          startServiceDependencies $gsd
        }
      }
      else
      {
        Write-Output -InputObject "Parent service '$dn' has already been started, PID $gsmp"
        if($gsd)
        {
          startServiceDependencies $gsd
        }
      }
    }
    else
    {
      if(!($gsmp))
      {
        Write-Output -InputObject "Starting main service '$dn'."
        Start-Service -DisplayName $dn
        $gsmp = ($gsmi.name |
          ForEach-Object -Process {
            tasklist.exe /svc /fi "SERVICES eq $_" /fo csv
          } |
        ConvertFrom-Csv).pid
        Write-Output -InputObject "Main service '$dn' has been started, new PID $gsmp."
      }
      else
      {
        Write-Output -InputObject "Main service '$dn' has already been started, PID $gsmp."
      }
    }
  }

  function remediateStop($ServiceName)
  {
    #Set varables
    $gsmi = Get-Service $ServiceName
    $dn = $gsmi.displayname
    try
    {
      $gsmp = ($gsmi.name |
        ForEach-Object -Process {
          tasklist.exe /svc /fi "SERVICES eq $_" /fo csv
        } |
      ConvertFrom-Csv).pid
      $gsmpi = Get-Process -pid $gsmp
    }
    catch
    {
      $errormessage
    }
    $gsd = $gsmi | Select-Object -ExpandProperty dependentservices
       
    if(($gsd))
    {
      #Check if service has dependencies
      stopServiceDependencies $gsd #execute function to stop dependencies using jobs
    }#end
    if(($gsmp -gt 0) -and (($gsmpi).responding) -and (($gsmi).status -eq 'Running'))
    {
      #Check service is responding
      Write-Output -InputObject "Stopping main service '$dn', PID $gsmp."
      Stop-Service -DisplayName $dn -Force
      $gsmi.WaitForStatus('Stopped','00:00:30')
      if($gsmi.status -ne 'stopped')
      {
        Write-Output -InputObject "Killing main service '$dn', PID $gsmp."
        taskkill.exe /pid $gsmp /f /t
        #Force kill of service and it's children
        Write-Output -InputObject "Main service '$dn' has been stopped."
      }
      Write-Output -InputObject "Main service '$dn' has been stopped."
    }
    else
    {
      if(($gsmp) -and ($gsmp -gt 0))
      {
        Write-Output -InputObject "Killing main service '$dn', PID $gsmp."
        taskkill.exe /pid $gsmp /f /t
        #Force kill of service and it's children
        Write-Output -InputObject "Main service '$dn' has been stopped."
      }
      else
      {
        Write-Output -InputObject "Main service '$dn' has already been stopped."
      }
    }
    #end check service responding remediation
  }



  #$remediateRestart = {
  function remediateRestart($ServiceName)
  {
    remediateStop $ServiceName
       
    remediateStart $ServiceName
  }

  #}

  function remediateKill($ServiceName)
  {
    #Set varables
    $gsmi = Get-Service $ServiceName
    $dn = $gsmi.displayname
    $gsmp = ($gsmi.name |
      ForEach-Object -Process {
        tasklist.exe /svc /fi "SERVICES eq $_" /fo csv
      } |
    ConvertFrom-Csv).pid
    $gsmpi = Get-Process -pid $gsmp
    $gsd = $gsmi | Select-Object -ExpandProperty dependentservices
    if(($gsmp) -and ($gsmp -gt 0))
    {
      Write-Output -InputObject "Killing main service '$dn', PID $gsmp."
      taskkill.exe /pid $gsmp /f /t
      #Force kill of service and it's children
      Write-Output -InputObject "Main service '$dn' has been stopped."
    }
    else
    {
      Write-Output -InputObject "Main service '$dn' has already been stopped."
    }
  }
}

#-----------------------------------------------------------[Execution]------------------------------------------------------------

<#
    Varable Naming Convention:
    gsmi = Get Service Main Information
    gsmp = Get Service Main PID
    dn = Display name
    gsmpi = Get Service Main Process Information
    gsd = Get Service Dependencies
    gj = Get Job
    gdj = Get Dependent Job
    sdn = Service Display Name   
    tdn = temp display name  
    tsn = temp service name
#>

#filter services for duplicate parent/child restart duplicate relations 
if($DisplayName)
{
  [array]$getserviceinfo = Get-Service -DisplayName $ServiceNames
}
else
{
  [array]$getserviceinfo = Get-Service $ServiceNames
}

[array]$myservices = (((($getserviceinfo) + (($getserviceinfo) |
        ForEach-Object -Process {
          $_.dependentservices
    })) |
    Group-Object -Property displayname |
    Where-Object -FilterScript {
      $_.count -eq 1
})) | ForEach-Object -Process {
  $_.name
}

$ServiceNames = $myservices

#forEach($ServiceName in $ServiceNames){
if((Get-Service $ServiceNames) -and ($ServiceNames))
{
  #Check Service Exists
              
  if(($action.tolower() -eq 'stop') -or ($action.tolower() -eq 'start') -or ($action.tolower() -eq 'kill'))
  {
    $scriptBlock = {
      $sdn = $args[0]
      Write-Output -InputObject "SDN: $sdn"
      $sa = $args[1]
      Write-Output -InputObject "SA: $sa"
      Write-Output -InputObject "Action '$sa' on service name '$sdn'."
              
      switch($sa.toLower()){  
        stop 
        {
          remediateStop $sdn
        }
        start 
        {
          remediateStart $sdn
        }
        restart 
        {
          remediateRestart $sdn
        }
        kill 
        {
          remediateKill $sdn
        }
        default 
        {
          remediateStart $sdn
        }
      }
    }

    $startRemediateJobs = $ServiceNames | ForEach-Object -Process {
      $tsn = $_
      Start-Job -InitializationScript $functions -Name "Start '$tsn'" -ArgumentList $tsn, $action -ScriptBlock $scriptBlock
    }
    if(($startRemediateJobs))
    {
      $startRemediateJobs |
      Wait-Job -Timeout 240 |
      Receive-Job -Keep
      $startRemediateJobs | ForEach-Object -Process {
        Format-Table -AutoSize
      }
      $startRemediateJobs | Remove-Job -Force  
    }
    else
    {
      Write-Output -InputObject 'No jobs to start.'
    }
  }
  elseif($action.tolower() -eq 'restart')
  {
    $scriptBlock1 = {
      $sdn = $args[0]
      Write-Output -InputObject "SDN: $sdn"
      $sa = 'Stop'
      Write-Output -InputObject "SA: $sa"
      Write-Output -InputObject "Action '$sa' on service name '$sdn'."
      remediateStop $sdn
    }
             
    $scriptBlock2 = {
      $sdn = $args[0]
      Write-Output -InputObject "SDN: $sdn"
      $sa = 'Start'
      Write-Output -InputObject "SA: $sa"
      Write-Output -InputObject "Action '$sa' on service name '$sdn'."
      remediateStart $sdn
    }
             
    $startRemediateJobs1 = $ServiceNames | ForEach-Object -Process {
      $tsn = $_
      Start-Job -InitializationScript $functions -Name "Start '$tsn'" -ArgumentList $tsn -ScriptBlock $scriptBlock1
    }
    if(($startRemediateJobs1))
    {
      $startRemediateJobs1 |
      Wait-Job -Timeout 240 |
      Receive-Job -Keep
      $startRemediateJobs1 | ForEach-Object -Process {
        Format-Table -AutoSize
      }
      $startRemediateJobs1 | Remove-Job -Force  
    }
    else
    {
      Write-Output -InputObject 'No jobs to start.'
    }
      
    $startRemediateJobs2 = $ServiceNames | ForEach-Object -Process {
      $tsn = $_
      Start-Job -InitializationScript $functions -Name "Start '$tsn'" -ArgumentList $tsn -ScriptBlock $scriptBlock2
    }
    if(($startRemediateJobs2))
    {
      $startRemediateJobs2 |
      Wait-Job -Timeout 240 |
      Receive-Job -Keep
      $startRemediateJobs2 | ForEach-Object -Process {
        Format-Table -AutoSize
      }
      $startRemediateJobs2 | Remove-Job -Force  
    }
    else
    {
      Write-Output -InputObject 'No jobs to start.'
    }
  }
  else
  {
    Write-Output -InputObject 'Error: Please provide a correct action, -action Restart,Start,Stop,Kill'
  }
}
else
{
  Write-Output -InputObject 'Error: Process not found.'
}
#}