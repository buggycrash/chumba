#!/bin/bash
# --------------------------------------------------------
# This script will apply a moderate level of STIG compliance to CentOS 7 using the OpenSCAP framework and security policies provided by SCAP Security Guides
#
# https://www.open-scap.org/
# https://www.open-scap.org/security-policies/
# The OpenSCAP tool is NIST validated
# https://nvd.nist.gov/scap/validation/128
#
# Run this script from UserData in a Cloud Formation Script during provisioning, or manually execute it soon after initial login on a new host.  
# Running after host modification (such as adding httpd or other installs) may create changes leading to unexpected behaviour.
#
# --------------------------------------------------------
# Human Safety Valve
# Make sure user is aware of changes
function ask_yes_or_no() {
    read -p "$1 ([y]es or [N]o): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}
clear
echo ""
if [[ "no" == $(ask_yes_or_no "Would you like to apply all patches and remediate security findings based on STIG guidance?") || \
      "no" == $(ask_yes_or_no "Please only run this script on a newly provisioned host. Are you still sure you wish to proceed?") ]]
then
    echo "Script exited.  No changes made."
    exit 0
fi
#
# Human Safety valve.  Comment the entire if statement above to enable the script to run automatically via User Data.
#
if ! grep 'CentOS Linux release 7' /etc/redhat-release; then
    echo "Script exited.  This remediation script is only designed to work on CentOS 7.  No changes made."
    exit 0
fi
echo ""
echo "Beginning patching and remediation.  The process may take several minutes if a large number of patches need to be applied."
sleep 1
#
# Install epel repository, needed for some of the scap-scanner and SSG dependencies
#
echo "Installing requirements...."
yum -y install epel-release
#
# Add newline to sshd_config to ensure that remediate won't break SSH and brick the host.
echo "" >> /etc/ssh/sshd_config
#
# Install openscap-scanner, scap-security-guide, and ntp packages.  Ntp is not installed by default on some minimal AMIs.
yum -y install openscap-scanner scap-security-guide ntp
#
# Update all packages
clear
sleep 1
echo "Updating patches.  This may take some time...."
yum -y update
#
# Remediate using STIG SCAP Profile provided by Red Hat, based on the DISA STIG SCAP Profile.  
# This implementation will not fully meet DoD or IC requirements, but will provide a very close representative baseline.  
#
clear
sleep 1
echo "Evaluating the system and then Remediating discovered vulnerabilities...." 
if ! grep 'CentOS Linux release 7' /etc/redhat-release; then
    echo "Script exited.  This remediation script is only designed to work on CentOS 7."
    exit 0
   elif grep 'CentOS Linux release 7' /etc/redhat-release; then
	yum -y install firewalld
	# firewalld is not installed by default on some minimal AMIs, yet the remediation assumes it is available
	oscap xccdf eval --remediate --profile xccdf_org.ssgproject.content_profile_stig-rhel7-server-upstream /usr/share/xml/scap/ssg/content/ssg-centos7-ds.xml
fi
#
# Evaluate and generate html report
clear
sleep 1
echo "Generating remediation report...."
if ! grep 'CentOS Linux release 7' /etc/redhat-release; then
    echo "Script exited.  This version is only designed to work on CentOS 7."
    exit 0
   elif grep 'CentOS Linux release 7' /etc/redhat-release; then
	oscap xccdf eval --profile xccdf_org.ssgproject.content_profile_stig-rhel7-server-upstream --report /tmp/remediation-results.html /usr/share/xml/scap/ssg/content/ssg-centos7-ds.xml
fi
#
# Recommend reboot for kernal update and audit update
echo ""
echo "The scripted portion of remediation is complete."
echo "Please reboot in order to apply the kernal updates, enable compliant auditing, and implement other fixes which can only be applied at boot time."
echo "A STIG compliance report (status before the reboot) is available at /tmp/remediation-results.html"