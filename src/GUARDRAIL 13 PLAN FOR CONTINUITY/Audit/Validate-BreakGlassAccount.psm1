<#
.SYNOPSIS
   
The solution will verify the existence of the two Break Glass accounts that you have entered in the config.json during the setup process.Once the solution detects both accounts the check mark status will be changed from (❌) to (✔️).
.DESCRIPTION
The solution will verify the existence of the two Break Glass accounts that you have entered in the config.json during the setup process.Once the solution detects both accounts the check mark status will be changed from (❌) to (✔️).
.PARAMETER Name
        token : auth token 
        ControlName :-  GUARDRAIL 1 PROTECT ROOT  GLOBAL ADMINS ACCOUNT
        FirstBreakGlassUPN: UPN for the first Break Glass account 
        SecondBreakGlassUPN: UPN for the second Break Glass account
        ItemName, 
        WorkSpaceID : Workspace ID to ingest the logs 
        WorkSpaceKey: Workspace Key for the Workdspace 
        LogType: GuardrailsCompliance, it will show in log Analytics search as GuardrailsCompliance_CL
#>
function Get-BreakGlassAccounts {
   
  param (
    [string] $FirstBreakGlassUPN, 
    [string] $SecondBreakGlassUPN,
    [hashtable] $msgTable,
    [string] $itsgcode,
    [string] $ControlName, 
    [string] $ItemName,
    [Parameter(Mandatory=$true)]
    [string]
    $ReportTime,
    [string] 
    $CloudUsageProfiles = "3",  # Passed as a string
    [string] $ModuleProfiles,  # Passed as a string
    [switch] $EnableMultiCloudProfiles # New feature flag, default to false    
  )

  [bool] $IsCompliant = $false
  [PSCustomObject] $ErrorList = New-Object System.Collections.ArrayList

  [String] $FirstBreakGlassUPNUrl = $("/users/" + $FirstBreakGlassUPN + "?$" + "select=userPrincipalName,id,userType")
  [String] $SecondBreakGlassUPNUrl = $("/users/" + $SecondBreakGlassUPN + "?$" + "select=userPrincipalName,id,userType")

if($FirstBreakGlassUPN -eq $SecondBreakGlassUPN){

  $IsCompliant = $false
  $PsObject = [PSCustomObject]@{
    ComplianceStatus = $IsCompliant
    ControlName      = $ControlName
    ItemName         = $ItemName
    Comments          = $msgTable.bgAccountsCompliance2
    ReportTime      = $ReportTime
    itsgcode = $itsgcode
  }

} else {

  $FirstBreakGlassAcct = [PSCustomObject]@{
    UserPrincipalName  = $FirstBreakGlassUPN
    apiUrl             = $FirstBreakGlassUPNUrl
    ComplianceStatus   = $false
  }
  $SecondBreakGlassAcct = [PSCustomObject]@{
    UserPrincipalName   = $SecondBreakGlassUPN
    apiUrl              = $SecondBreakGlassUPNUrl
    ComplianceStatus    = $false
  }
  
  # get 1st break glass account
  try {
    $urlPath = $FirstBreakGlassAcct.apiUrl
    $response = Invoke-GraphQuery -urlPath $urlPath -ErrorAction Stop

    $data = $response.Content
    
    if ($data.userType -eq "Member") {
      $FirstBreakGlassAcct.ComplianceStatus = $true
    } 
  }
  catch {
    $ErrorList.Add("Failed to call Microsoft Graph REST API at URL '$urlPath'; returned error message: $_")
    Write-Warning "Error: Failed to call Microsoft Graph REST API at URL '$urlPath'; returned error message: $_"
  }

  # get 2nd break glass account
  try {
    $urlPath = $SecondBreakGlassAcct.apiURL
    $response = Invoke-GraphQuery -urlPath $urlPath -ErrorAction Stop

    $data = $response.Content

    if ($data.userType -eq "Member") {
      $SecondBreakGlassAcct.ComplianceStatus = $true
    } 
  }
  catch {
    $ErrorList.Add("Failed to call Microsoft Graph REST API at URL '$urlPath'; returned error message: $_")
    Write-Warning "Error: Failed to call Microsoft Graph REST API at URL '$urlPath'; returned error message: $_"
  }

  $IsCompliant = $FirstBreakGlassAcct.ComplianceStatus -and $SecondBreakGlassAcct.ComplianceStatus

  $PsObject = [PSCustomObject]@{
    ComplianceStatus = $IsCompliant
    ControlName      = $ControlName
    ItemName         = $ItemName
    Comments          = $msgTable.bgAccountsCompliance -f $FirstBreakGlassAcct.ComplianceStatus, $SecondBreakGlassAcct.ComplianceStatus
    ReportTime      = $ReportTime
    itsgcode = $itsgcode
  }
}

if ($EnableMultiCloudProfiles) {        
    $evalResult = Get-EvaluationProfile -CloudUsageProfiles $CloudUsageProfiles -ModuleProfiles $ModuleProfiles
    if (!$evalResult.ShouldEvaluate) {
        if ($evalResult.Profile -gt 0) {
            $PsObject.ComplianceStatus = "Not Applicable"
            $PsObject | Add-Member -MemberType NoteProperty -Name "Profile" -Value $evalResult.Profile
            $PsObject.Comments = "Not evaluated - Profile $($evalResult.Profile) not present in CloudUsageProfiles"
        } else {
            $ErrorList.Add("Error occurred while evaluating profile configuration")
        }
    } else {
        
        $PsObject | Add-Member -MemberType NoteProperty -Name "Profile" -Value $evalResult.Profile
    }
}

  $moduleOutput= [PSCustomObject]@{ 
    ComplianceResults = $PsObject
    Errors=$ErrorList
    AdditionalResults = $AdditionalResults
  }
  return $moduleOutput   
}    


