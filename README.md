# Remediate-Services

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