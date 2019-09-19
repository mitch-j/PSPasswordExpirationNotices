function Send-AdminExpirationEmail {
    [CmdletBinding()]
    param(
        $users,
        [System.Collections.IDictionary] $EmailParameters,
        [System.Collections.IDictionary] $ConfigurationParameters
    )

    # Import the HTML template that will be used for the email sent to users.
    [string]$AdminEmail = Get-Content $ConfigurationParameters.AdminEmailTemplate

    $AdminEmailSubject = $ConfigurationParameters.AdminEmailSubject

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

    if ($users.count -le 0) {
        $AdminSummary = "No passwords expiring in the next $ExpireInDays Days"
    } else {
        $AdminSummary = "<p>The following users have passwords set to expire in the next $ExpireInDays days.</p>

        <table border=1>
            <tr>
              <th>UserName</th>
              <th>Display Name</th>
              <th>Expiration Date</th>
              <th>Password Last Set</th>
              <th>Days To Expire</th>
            </tr>
            "
        $users = $Users | Sort-object -property DaysToExpire
        # Cycle through all the users with expiring passwords and build a summary with their Info.
        foreach ($user in $users) {

            # Set the CSS Style of message for this user. normal|warning|redalert
            if ($user.DaysToExpire -lt 2 ) {
                # The password is expiring in less than 2 days. Red Alert
                $messageStyle = "redalert" 
            } elseif ($user.DaysToExpire -lt 6 ) {
                # The password expires in less than a week, yellow warning
                $messageStyle = "warning"
            } else {
                # The password expires in more than a week. Normal text style
                $messageStyle = "normal"
            }

            $AdminSummary += "<tr>
            <td> $($user.UserName) </td>
            <td> $($user.Name) </td>
            <td> $($user.PasswordSet) </td>
            <td class='$messageStyle'> $($user.ExpiresOn) </td>
            <td> $($user.DaysToExpire) </td>
            </tr>
            "               
        }
        $AdminSummary += "</table>"
    }

    # Fill in data that's the same for all summary emails
    $AdminEmail = $AdminEmail -replace "<<CompanyName>>", $ConfigurationParameters.CompanyName
    $AdminEmail = $AdminEmail -replace "<<AdminSummary>>",$AdminSummary
    $AdminEmailSubject = $AdminEmailSubject -replace "<<CompanyName>>", $ConfigurationParameters.CompanyName

    $AdminEmail = $AdminEmail.ToString()
    # Send the email
    # Send-Mailmessage -smtpServer $EmailParameters.EmailServer -from $EmailParameters.EmailFrom -to $emailaddress -subject $UserEmailSubject -body $UserEmail -bodyasHTML -priority High -Encoding $EmailParameters.EmailEncoding -ErrorAction Stop
}