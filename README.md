1. Run application
    Please use the command below to run frontend-logout.

        fvm flutter run -d chrome --web-port=3001

    Frontend-login is for testing purpose.

2. Progress
    i.   Sign in using GOOGLE SIGN-IN (store data in storage if not signed out)
    ii.  Signout (Kill KeyCloak Sessions, Clear storage and cookies)
    iii. Connect to APISIX (domain mapping)
    iv.  Create Company (Automatically create admin subgroup, add member and role mapping)
    v.   Select Company (Select Company to view the data of the company and invite users)
    vi.  Invite User (Invite User using encrypted plaintext containing groupid, subgroupid and expiration time) 
    vii. Join Company (Join Company using the invitation code and join relevant subgroup)


//TODO:
//Pop-up to show details once joined.
//extract select company into a new class
//shorten invitation code
//generate new invitation code or use the original before expiration time ? store in storage or cache
//role mapping for admin only, will implement for other roles later
//limit or threshold of groups and subgroups not tested sucessfully.
