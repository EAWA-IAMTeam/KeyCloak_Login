1. Run application<br><br>
    Backend: <br>

        cd otp_login/invite_code_service
        go run main.go
           
    Frontend:<br>

        cd frontend_logout
        fvm flutter run -d chrome --web-port=3001

    <br>

2. Progress<br>
    i.   Sign in using GOOGLE SIGN-IN (store data in storage if not signed out)<br>
    ii.  Signout (Kill KeyCloak Sessions, Clear storage and cookies)<br>
    iii. Connect to APISIX (domain mapping)<br>
    iv.  Create Company (Automatically create admin subgroup, add member and role mapping)<br>
    v.   Select Company (Select Company to view the data of the company)<br>
    vi.  Invite User (Invite User using encrypted plaintext containing groupid, subgroupid and expiration time) <br>
    vii. Join Company (Join Company using the invitation code and join relevant subgroup)<br>
    viii.Keys stored in environment file rather than hardcoded<br>
    ix.  Encryption and Decryption processed at backend<br>
    x.   Code lengths: 152<br>
    xi.  Role Mapping for Owner, Admin, Account and Packer<br>
    xii. Secret at backend .env file <br>
    xiii.Tokens stored in cookies<br><br><br>

//TODO:<br>
//shorten invitation code - could not find shortener for code, only url<br>
    flutter_url_shortener <br>


