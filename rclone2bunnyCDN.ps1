################################################################
# RClone to BunnyCDN Sync Script
# Checks if the source and remote locations specified are in
#  sync, and performs a sync if not
################################################################

# DEFINITIONS
$SleepTimeSecs = 5
$LocalSource = "E:\redirect\kf2maps\"
$RemoteDest = "REDACTED:" 


# Checks if BunnyCDN storage differs from local
# Returns 0 if sync, else 1
function checkIfDesync {

    $IsSynced = 0

    # Perform check, but only via file size, since BunnyCDN
    #  does not support check via hash
    $RCloneCheckOutput = & rclone.exe check $LocalSource $RemoteDest --size-only 2>&1 | Out-String
    Write-Output $RCloneCheckOutput[0]

    # If output contains ERROR text, then assume its caused 
    #  by desync
    if($RCloneCheckOutput -clike '*ERROR :*') {
        $IsSynced = 1
    }
    return $isSynced
}


# Performs an rclone sync
function initiateSync {
    rclone.exe sync $LocalSource $RemoteDest
}


# Main
while(1) {

    # Result of desync check
    $DesyncCheckResult = (checkIfDesync)

    # Check if not in sync, and initiate sync
    if( $DesyncCheckResult -eq 1 ) {
        (initiateSync)
    }

    # Sleep; check again after a period of time
    Start-Sleep($SleepTimeSecs)
}