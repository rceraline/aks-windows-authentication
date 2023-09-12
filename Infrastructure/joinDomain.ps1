$username = "useradmin";
$password = Read-Host "Enter the admin password" -AsSecureString;
$domain = "mycompany.local";

$joinCred = New-Object pscredential -ArgumentList ([pscustomobject]@{  
    UserName = $username;
    Password = (ConvertTo-SecureString -String $password -AsPlainText -Force)[0] 
});
    
Add-Computer -Domain $domain -Credential $joinCred -Force -Restart