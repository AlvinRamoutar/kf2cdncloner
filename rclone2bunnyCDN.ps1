################################################################
# RClone to BunnyCDN Sync Script
# Checks if the source and remote locations specified are in
#  sync, and performs a sync if not
################################################################

# !!! START EDITING !!!
# Configuration options

$SleepTimeSecs = 5
## example: 5

$CDNURL = ""
## example: "http://kf2.b-cdn.net/"

$LocalSource = ""
## example: "E:\hosted\kf2\"

$RemoteDest = "" 
## example: "kf2:"
## You must manually configure by running 'rclone config'
## Refer to: https://rclone.org/commands/rclone_config/

$BunnyCDN_APIKey = ""
## example: 0j30j2f80823-28f392h89f32-2f32j9083f-28fj2938fj2-239f
## You can find this on your BunnyCDN Dashboard

# !!! STOP EDITING !!!


# Definitions
$LocalFilePushQueue = New-Object System.Collections.ArrayList


# Checks if BunnyCDN storage differs from local
# Returns 0 if sync, else 1
function checkIfDesync {

    $IsSynced = 0

    # Perform check, but only via file size, since BunnyCDN
    #  does not support check via hash
    $script:RCloneCheckOutput = & rclone.exe check $script:LocalSource $script:RemoteDest --size-only 2>&1 | Out-String

    # If output contains ERROR text, then assume its caused 
    #  by desync
    if($script:RCloneCheckOutput -clike '*ERROR :*') {
        $IsSynced = 1
    }
    return $isSynced
}


# Assemble list with all missing files
# A file is considered missing if it differs;
# - Either exists on local ONLY
# - OR, filesize differs between local and remote version
function assembleMissingFileList {

    # RClone log excerpts
    $cr_errPrefix = "ERROR : "
    $cr_errSuffix1 = ": File not in ftp"
    $cr_errSuffix2 = ": Sizes differ"

    $cr_tmpline = ""
    $cr_lines = $script:RCloneCheckOutput -Split "`r`n"

    foreach($line in $cr_lines) {

        # IF file is marked as being missing from remote
        if($line -match $cr_errPrefix + ".*" + $cr_errSuffix1) {
            $cr_tmpline = $line.Substring($line.IndexOf($cr_errPrefix) + $cr_errPrefix.Length)
            $script:LocalFilePushQueue.Add(
                $cr_tmpline.Substring(0, $cr_tmpline.IndexOf($cr_errSuffix1)))
        }
        # ELSE file is marked as different (filesize mismatch) between local and remote
        elseif($line -match $cr_errPrefix + ".*" + $cr_errSuffix2) {
            $cr_tmpline = $line.Substring($line.IndexOf($cr_errPrefix) + $cr_errPrefix.Length)
            $script:LocalFilePushQueue.Add(
                $cr_tmpline.Substring(0, $cr_tmpline.IndexOf($cr_errSuffix2)))
        }
    }

}


# Performs a purge for the diff files - just in case variations exist in the CDN
# Refer to https://bunnycdn.docs.apiary.io/
function sanityPurge_POST {

    $sp_api_URL = "https://bunnycdn.com/api/purge?url="
    $sp_uri = ""

    $sp_header = @{
        "AccessKey"=$script:BunnyCDN_APIKey
        "Accept"="application/json"
        "Content-Type"="application/json"
    }

    foreach($file in $script:LocalFilePushQueue) {
        $sp_uri = $sp_api_URL + [System.Web.HttpUtility]::UrlEncode($script:CDNURL + $file)

        # Perform REST call to API Purge cmd
        $PurgeResult = Invoke-RestMethod -Uri $sp_uri -Method POST -Headers $sp_header
    }
}

# Performs an rclone sync
function initiateSync {
    rclone.exe sync $script:LocalSource $script:RemoteDest
}








# == MAIN ==
while(1) {

    # Result of desync check
    $DesyncCheckResult = (checkIfDesync)

    # Check if not in sync, and initiate sync
    if( $DesyncCheckResult -eq 1 ) {
        (assembleMissingFileList)
        (sanityPurge_POST)
        (initiateSync)
    }

    # Sleep; check again after a period of time
    Start-Sleep($script:SleepTimeSecs)

}