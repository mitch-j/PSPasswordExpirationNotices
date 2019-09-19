function Send-UserExpirationEmail {
    [CmdletBinding()]
    param(
        $users,
        [System.Collections.IDictionary] $EmailParameters,
        [System.Collections.IDictionary] $ConfigurationParameters
    )

    # Import the HTML template that will be used for the email sent to users.
    [string]$EmailTemplate = Get-Content $ConfigurationParameters.UserEmailTemplate

    # Fill in the email data that's the same for all users
    $EmailTemplate = $EmailTemplate -replace "<<CompanyName>>", $ConfigurationParameters.CompanyName
    $EmailTemplate = $EmailTemplate -replace "<<webmail>>", $ConfigurationParameters.webmail
    $EmailTemplate = $EmailTemplate -replace "<<helpdeskemail>>", $ConfigurationParameters.helpdeskemail

    # Cycle through all the users to notify, build and send their email notififcation.
    foreach ($user in $users) {
        # start with the blank email template for each user
        $UserEmail = $EmailTemplate

        $CheckDays = $ConfigurationParameters.NotificationDays

        if ($Checkdays -contains $user.DaysToExpire) {
            $EmailAddress = $user.EmailAddress
            write-verbose "Emailing $EmailAddress"
            
            $emailaddress = "mjurisch@unitedhardware.com"

            # Set the CSS Style of the warning message.
            if ($user.DaysToExpire -lt 2 ) {
                # The password is expiring in less than 2 days. Red Alert
                $messageStyle = "redalert" # normal|warning|redalert
            } elseif ($user.DaysToExpire -lt 6 ) {
                # The password expires in less than a week, yellow warning
                $messageStyle = "warning"
            } else {
                # The password expires in more than a week. Normal text style
                $messageStyle = "normal"
            }

            # Fill in email data that's user specific.
            $UserEMail = $UserEmail -replace "<<ExpiresOn>>",$user.ExpiresOn
            $UserEmail = $UserEmail -replace "<<FirstName>>", $user.FirstName
            $UserEmail = $UserEmail -replace "<<messageStyle>>", $messageStyle
            $UserEmail = $UserEmail -replace "<<userMessage>>", $user.userMessage
            
            $UserEmailSubject = $ConfigurationParameters.UserEmailSubject
            $UserEmailSubject = $UserEmailSubject -replace "<<CompanyName>>", $ConfigurationParameters.CompanyName
            $UserEmailSubject = $UserEmailSubject -replace "<<userMessage>>",$user.usermessage
            
            $UserEmail = $UserEmail.ToString()
            # Send the email
            Send-Mailmessage -smtpServer $EmailParameters.EmailServer -from $EmailParameters.EmailFrom -to $emailaddress -subject $UserEmailSubject -body $UserEmail -bodyasHTML -priority High -Encoding $EmailParameters.EmailEncoding -ErrorAction Stop
        }
    }
}