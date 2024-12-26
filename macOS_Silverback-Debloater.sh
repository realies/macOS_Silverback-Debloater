#!/bin/bash

# macOS Silverback Debloater
# A privacy-focused system debloater for macOS
# Requirements: SIP disabled ("csrutil disable" from Recovery)
#
# Note: Modifications are written to:
# /private/var/db/com.apple.xpc.launchd/disabled.plist
# /private/var/db/com.apple.xpc.launchd/disabled.501.plist
#
# To revert all changes:
# 1. sudo rm -r /private/var/db/com.apple.xpc.launchd/*
# 2. Reboot your system

# Print with color
print_status() {
    local color=$1
    local message=$2
    case $color in
        "green") echo -e "\033[32m$message\033[0m" ;;
        "red") echo -e "\033[31m$message\033[0m" ;;
        *) echo "$message" ;;
    esac
}

# Check if SIP is disabled
check_sip() {
    if [[ $(csrutil status) == *"enabled"* ]]; then
        print_status "red" "Error: System Integrity Protection is enabled. Please disable it first."
        print_status "red" "1. Restart your Mac and hold Command+R during startup"
        print_status "red" "2. Open Terminal from Utilities menu"
        print_status "red" "3. Run: csrutil disable"
        print_status "red" "4. Restart and run this script again"
        exit 1
    fi
}

# Configure system preferences
configure_system() {
    print_status "green" "Configuring system preferences..."
    
    # Disable Spotlight indexing
    sudo mdutil -i off -a
    
    # Optimize UI performance
    defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
    defaults write NSGlobalDomain NSWindowResizeTime -float 0.001
    defaults write -g QLPanelAnimationDuration -float 0
    defaults write com.apple.dock autohide-time-modifier -float 0
    defaults write com.apple.Dock autohide-delay -float 0
    defaults write com.apple.dock expose-animation-duration -float 0.001
    defaults write com.apple.dock launchanim -bool false
    defaults write com.apple.finder DisableAllAnimations -bool true
    
    # Configure OpenDirectory
    sudo defaults write /Library/Preferences/com.apple.opendirectoryd.plist "Delay before configured automatic" -int 0
    sudo defaults write /Library/Preferences/com.apple.opendirectoryd.plist "Delay before automatic" -int 0
    sudo defaults write /Library/Preferences/com.apple.opendirectoryd.plist "Module automatic" -bool false
    sudo defaults write /Library/Preferences/com.apple.opendirectoryd.plist "Search node automatic" -bool false

    # Disable application state on shutdown
    defaults write com.apple.loginwindow TALLogoutSavesState -bool false

    print_status "green" "Disabling automatic updates..."
    # Disable automatic updates
    local updates=("AutomaticDownload" "AutomaticCheckEnabled" "CriticalUpdateInstall" "ConfigDataInstall")
    for val in "${updates[@]}"; do
        sudo defaults write com.apple.SoftwareUpdate $val -int 0
    done
}

# Configure background services
configure_background_services() {
    print_status "green" "Configuring background services..."
    
    # Enable essential background management
    sudo launchctl enable system/com.apple.backgroundtaskmanagement.bgservicesd
    launchctl enable gui/501/com.apple.backgroundtaskmanagement.agent
    
    # Disable telemetry
    sudo defaults write /Library/Preferences/com.apple.backgroundtaskmanagement.plist "Application Resource Usage Monitoring" -bool false
    sudo defaults write /Library/Preferences/com.apple.backgroundtaskmanagement.plist "Data Collection" -bool false
}

# Define services to disable
declare -a USER_SERVICES=(
    # Analytics and Telemetry
    'com.apple.analyticsd'
    'com.apple.proactived'
    'com.apple.geoanalyticsd'
    'com.apple.diagnostics_agent'
    'com.apple.spindump_agent'
    'com.apple.ReportCrash'
    'com.apple.webprivacyd'
    'com.apple.privacyd'
    'com.apple.osanalytics.osanalyticshelper'
    'com.apple.UsageTrackingAgent'
    
    # Cloud Services
    'com.apple.cloudd'
    'com.apple.cloudpaird'
    'com.apple.cloudphotod'
    'com.apple.icloud.*'
    'com.apple.bird'
    'com.apple.security.cloudkeychainproxy3'
    
    # Safari Services
    'com.apple.SafariCloudHistoryPushAgent'
    'com.apple.Safari.SafeBrowsing.Service'
    'com.apple.SafariNotificationAgent'
    'com.apple.SafariPlugInUpdateNotifier'
    'com.apple.SafariHistoryServiceAgent'
    'com.apple.SafariLaunchAgent'
    'com.apple.safaridavclient'
    
    # Siri and Intelligence
    'com.apple.Siri.agent'
    'com.apple.siriknowledged'
    'com.apple.assistant_service'
    'com.apple.intelligenceplatformd'
    'com.apple.BiomeAgent'
    'com.apple.biomesyncd'
    'com.apple.knowledge-agent'
    
    # Communication & Sharing
    'com.apple.screensharing.agent'
    'com.apple.screensharing.menuextra'
    'com.apple.sharingd'
    'com.apple.sidecar-hid-relay'
    'com.apple.sidecar-relay'
    'com.apple.rapportd-user'
    
    # Unused Apple Services
    'com.apple.Maps.*'
    'com.apple.facetime.*'
    'com.apple.iMessage.*'
    'com.apple.AirPlayXPCHelper'
    'com.apple.AddressBook.ContactsAccountsService'
    'com.apple.AMPArtworkAgent'
    'com.apple.AMPDeviceDiscoveryAgent'
    'com.apple.AMPLibraryAgent'
    'com.apple.CalendarAgent'
    'com.apple.calaccessd'
    'com.apple.avconferenced'
    'com.apple.telephonyutilities.callservicesd'
    
    # System Services
    'com.apple.ap.adservicesd'
    'com.apple.ap.promotedcontentd'
    'com.apple.dataaccess.dataaccessd'
    'com.apple.ensemble'
    'com.apple.familynotificationd'
    'com.apple.financed'
    'com.apple.followupd'
    'com.apple.gamed'
    'com.apple.geodMachServiceBridge'
    'com.apple.homed'
    'com.apple.newsd'
    'com.apple.passd'
    'com.apple.photolibraryd'
    'com.apple.progressd'
    'com.apple.remindd'
    'com.apple.TMHelperAgent'
    'com.apple.TMHelperAgent.SetupOffer'
    'com.apple.triald'
    'com.apple.videosubscriptionsd'
    'com.apple.WiFiVelocityAgent'
    'com.apple.weatherd'
    
    # Additional Telemetry
    'com.apple.coreduetd'
    'com.apple.studentd'
    'com.apple.translationd'
    'com.apple.backgroundassets.user'
    'com.apple.accessibility.MotionTrackingAgent'
    'com.apple.dprivacyd'
    'com.apple.metrickitd'
    'com.apple.ciphermld'
    'com.apple.intelligencecontextd'
    'com.apple.mlhostd'
    'com.apple.idsfoundation.IDSRemoteURLConnectionAgent'
    'com.apple.cache_delete'
    'com.apple.CrashReporterSupportHelper'
    'com.apple.accessibility.heard'
    'com.apple.accessibility.HeardAgent'
    'com.apple.sysmond'
)

declare -a SYSTEM_SERVICES=(
    # System Analytics
    'com.apple.analyticsd'
    'com.apple.proactived'
    'com.apple.diagnosticd'
    'com.apple.spindump'
    'com.apple.osanalytics.osanalyticshelper'
    'com.apple.systemstats.daily'
    'com.apple.systemstats.analysis'
    
    # Cloud and Network
    'com.apple.cloudd'
    'com.apple.cloudpaird'
    'com.apple.networkserviceproxy'
    'com.apple.netbiosd'
    'com.apple.ftp-proxy'
    'com.apple.ftpd'
    'com.apple.bootpd'
    'com.apple.backupd'
    'com.apple.backupd-helper'
    'com.apple.telnetd'
    
    # Media and Device Services
    'com.apple.amp.mediasharingd'
    'com.apple.mediaremoteagent'
    'com.apple.java.InstallOnDemand'
    'com.apple.voicememod'
    
    # Location and Recent Items
    'com.apple.locate'
    'com.apple.locationd'
    'com.apple.recentsd'
    
    # Additional System Services
    'com.apple.biometrickitd'
    'com.apple.ReportCrash.Root'
    'com.apple.awdd'
    'com.apple.AMPDevicesAgent'
    'com.apple.diagnosticextensionsd'
    'com.apple.eapolcfg_auth'
    'com.apple.avatarsd'
    'com.apple.businessservicesd'
    'com.apple.contextstore'
    'com.apple.contextstored'
    'com.apple.usernoted'
    'com.apple.containermanagerd'
    'com.apple.coreservices.useractivityd'
    'com.apple.powerexperienced'
    'com.apple.nfcd'
    'com.apple.storekitd'
    'com.apple.storedownloadd'
    'com.apple.fairplayd'
    'com.apple.appstoreagent'
    'com.apple.CoreRoutine'
)

# Disable services
disable_services() {
    print_status "green" "Disabling unnecessary services..."
    
    # Disable user services
    for service in "${USER_SERVICES[@]}"; do
        if launchctl print gui/501/${service} &>/dev/null; then
            launchctl bootout gui/501/${service} 2>/dev/null || true
            launchctl disable gui/501/${service} 2>/dev/null || true
        fi
    done
    
    # Explicitly unload cloudpaird
    launchctl unload -w /System/Library/LaunchAgents/com.apple.cloudpaird.plist 2>/dev/null || true
    
    # Disable system services
    for service in "${SYSTEM_SERVICES[@]}"; do
        if sudo launchctl print system/${service} &>/dev/null; then
            sudo launchctl bootout system/${service} 2>/dev/null || true
            sudo launchctl disable system/${service} 2>/dev/null || true
        fi
    done
}

# Print essential services that remain enabled
print_essential_services() {
    print_status "green" "The following essential services remain enabled:"
    echo "- com.apple.softwareupdated (System updates)"
    echo "- com.apple.XprotectFramework (Security protection)"
    echo "- com.apple.MRTd (Malware protection)"
    echo "- com.apple.apsd (Basic push notifications)"
    echo "- com.apple.secd (Keychain security)"
    echo "- com.apple.identityservicesd (Basic system authentication)"
    echo "- com.apple.audio.* (Audio functionality)"
    echo "- com.apple.coreaudiod (Core Audio)"
}

# Print Spotlight alternatives
print_spotlight_alternatives() {
    print_status "green" "Spotlight alternatives:"
    echo "- Raycast (privacy-focused): https://www.raycast.com/"
    echo "- Albert (opensource): https://albertlauncher.github.io/"
    echo "- Cerebro (opensource): https://github.com/cerebroapp/cerebro"
    echo "- Quicksilver (opensource): https://qsapp.com/"
}

# Main execution
main() {
    print_status "green" "Starting macOS Silverback Debloater..."
    check_sip
    configure_system
    configure_background_services
    disable_services
    print_essential_services
    print_spotlight_alternatives
    
    print_status "green" "Debloat complete!"
    read -e -p "Do you want to reboot now? (y/N) " yn
    if [[ $yn == "y" ]]; then
        print_status "green" "Rebooting..."
        sleep 3
        sudo reboot
    else
        print_status "green" "Please reboot your system manually to apply all changes."
        exit 0
    fi
}

# Run the script
main
