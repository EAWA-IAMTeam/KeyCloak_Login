1. Run application
    Please use the command below to run frontend-logout.

        fvm flutter run -d chrome --web-port=3001

    Frontend-login is for testing purpose.<br><br>

2. Progress<br>
    i.   Sign in using GOOGLE SIGN-IN (store data in storage if not signed out)<br>
    ii.  Signout (Kill KeyCloak Sessions, Clear storage and cookies)<br>
    iii. Connect to APISIX (domain mapping)<br>
    iv.  Create Company (Automatically create admin subgroup, add member and role mapping)<br>
    v.   Select Company (Select Company to view the data of the company)<br>
    vi.  Invite User (Invite User using encrypted plaintext containing groupid, subgroupid and expiration time) <br>
    vii. Join Company (Join Company using the invitation code and join relevant subgroup)<br><br><br>

//TODO:<br>
//shorten invitation code - could not find shortener for code, only url<br>
    flutter_url_shortener <br>
//generate new invitation code or use the original before expiration time ? store in storage or cache<br>
//role mapping for admin only, will implement for other roles later<br>
//Remove Admin join company option assuming that he is owner <br>
//limit or threshold of groups and subgroups not tested yet.
