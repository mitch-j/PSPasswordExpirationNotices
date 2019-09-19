
function Get-UsersExipringPasswords {
<#
.SYNOPSIS
    Returns a list of users with passwords that are expiring soon.
.DESCRIPTION
    Searches the AD domain for accounts with passwords that are expiring soon.
.EXAMPLE
    PS C:\> Get-ExpiringPasswords
    
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
    [cmdletbinding()]
    param (
        # Threshold of password expiration to check. If no value is passed, default to 14 days.
        [Parameter(Position=1)]
        [System.Collections.IDictionary] $ConfigurationParameters
    )

    # Time / Date Info used for calculating when passwords will expire
    $start = [datetime]::Now
    $today = $start
    $midnight = $start.Date.AddDays(1)
    $timeToMidnight = New-TimeSpan -Start $start -end $midnight.Date
    $midnight2 = $start.Date.AddDays(2)
    $timeToMidnight2 = New-TimeSpan -Start $start -end $midnight2.Date

    # Declare some Variables for use Later
    $Results = @()

    # Load AD Module so we can gather the info we need.
    try{
        Import-Module ActiveDirectory -ErrorAction Stop
    }
    catch{
        Write-Warning "Unable to load Active Directory PowerShell Module"
    }

    # We find the highest number of days out we will notify users.
    $HighestDay = 0 
    If ($ConfigurationParameters.NotificationDays.count -gt 0) {
        # We were passed an array of days to notify users on with at least one day defined.
        foreach ($NotificationDay in $ConfigurationParameters.NotificationDays) {
            # Cycle through all the days in the array and find the highest number in the array.
            if ($NotificationDay -gt $highestDay) {
                $HighestDay = $NotificationDay
            }
        }
    } else {
        $HighestDay = 14 # If we weren't passed any days to notify on, notify 14 days before password expiration.
    }
    $expireInDays = $HighestDay

    # Gather users who are enabled, have password expiration enabled, and their passwords haven't expired.
    Write-Verbose "Searching AD for accounts that are enabled, have password expiration enabled, and their passwords haven't expired."
    $users = get-aduser -filter {(Enabled -eq $true) -and (PasswordNeverExpires -eq $false)} -properties Name, PasswordNeverExpires, PasswordExpired, PasswordLastSet, EmailAddress | Where-Object { $_.passwordexpired -eq $false }
    # Count Users
    $usersCount = ($users | Measure-Object).Count
    Write-Verbose "Found $usersCount User Objects"

    # Find Default Password Age for the domain
    $defaultMaxPasswordAge = (Get-ADDefaultDomainPasswordPolicy -ErrorAction Stop).MaxPasswordAge.Days 
    Write-Verbose "Domain Default Password Age: $defaultMaxPasswordAge"

    # Process Each User for Password Expiry
    Write-Verbose "Process User Objects"
    foreach ($user in $users) {
        # Store User information
        $Name = $user.Name
        write-verbose "Gathering info on $name"
        $FirstName = $user.GivenName
        $emailaddress = $user.emailaddress
        $samAccountName = $user.SamAccountName
        $pwdLastSet = $user.PasswordLastSet

        # Check for Fine Grained Password
        $maxPasswordAge = $defaultMaxPasswordAge
        $PasswordPol = (Get-AduserResultantPasswordPolicy $user) 
        if ($null -ne $PasswordPol) {
            $maxPasswordAge = ($PasswordPol).MaxPasswordAge.Days
        }

        # Determine Number of days till password expires
        $expireson = $pwdLastSet.AddDays($maxPasswordAge)
        $daysToExpire = New-TimeSpan -Start $today -End $Expireson

        # If the password is expiring within the threshold, gather some information about the user to return.
        if ($daysToExpire.Days -lt $expireInDays) {
            # Create User Object
            $userObj = New-Object System.Object

            $userObj | Add-Member -Type NoteProperty -Name UserMessage -Value "."
            # Round Expiry Date Up or Down and generate a user message.
            if(($daysToExpire.Days -eq "0") -and ($daysToExpire.TotalHours -le $timeToMidnight.TotalHours)) {
                $userObj.UserMessage = "today!"
            }
            if(($daysToExpire.Days -eq "0") -and ($daysToExpire.TotalHours -gt $timeToMidnight.TotalHours) -or ($daysToExpire.Days -eq "1") -and ($daysToExpire.TotalHours -le $timeToMidnight2.TotalHours)) {
                $userObj.UserMessage = "tomorrow!"
            }
            if(($daysToExpire.Days -ge "1") -and ($daysToExpire.TotalHours -gt $timeToMidnight2.TotalHours)) {
                $days = $daysToExpire.TotalDays
                $days = [math]::Round($days)
                $userObj.UserMessage = "in $days days."
            }

            Write-verbose "$name's password expires $($UserObj.UserMessage.tostring())"
            $daysToExpire = [math]::Round($daysToExpire.TotalDays)
            $userObj | Add-Member -Type NoteProperty -Name UserName -Value $samAccountName
            $userObj | Add-Member -Type NoteProperty -Name Name -Value $Name
            $userObj | Add-Member -Type NoteProperty -Name FirstName -Value $FirstName
            $userObj | Add-Member -Type NoteProperty -Name EmailAddress -Value $emailAddress
            $userObj | Add-Member -Type NoteProperty -Name PasswordSet -Value $pwdLastSet
            $userObj | Add-Member -Type NoteProperty -Name DaysToExpire -Value $daysToExpire
            $userObj | Add-Member -Type NoteProperty -Name ExpiresOn -Value $expiresOn
            # Add this user's info to the results we've gathered.
            $results += $userObj
        }
    }
    return $results
}