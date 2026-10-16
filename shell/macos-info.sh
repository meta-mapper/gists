#!/bin/bash
# macinfo.sh — Complete hardware & software report for a Mac
#
# Usage:
#   ./macinfo.sh                 Full report to the terminal (colored)
#   ./macinfo.sh -o report.txt   Save the report to a plain-text file
#   ./macinfo.sh -s cpu,memory   Only run the listed sections (see -l)
#   ./macinfo.sh -s hardware     Group shortcuts: hardware, software, stats, all
#   ./macinfo.sh -l              List available section names and groups
#   ./macinfo.sh -q, --quick     Skip slow items: update check, Wi-Fi scan,
#                                home-folder sizes, app signature scan
#   ./macinfo.sh --no-color      Disable colors
#   ./macinfo.sh -h              Help
#
# Hardware sections describe the machine itself (static facts).
# Software sections describe the OS, settings and installed programs.
# The stats section shows what is happening right now (load, usage, processes).
# Tip: run with sudo for fan speeds and temperatures (powermetrics).

set -u

# ---------------------------------------------------------------- sections
HW_GROUP="overview firmware cpu memory storage graphics battery network bluetooth usb audio camera"
SW_GROUP="os security power users devtools apps services kernel"
ST_GROUP="stats"
ALL_SECTIONS="$HW_GROUP $SW_GROUP $ST_GROUP"

# ---------------------------------------------------------------- options
OUTFILE=""; SECTIONS=""; QUICK=0; USE_COLOR=1
usage() { sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }
list_sections() {
  echo "Hardware sections:"; echo "  $HW_GROUP"
  echo "Software sections:"; echo "  $SW_GROUP"
  echo "Live stats:";        echo "  $ST_GROUP"
  echo; echo "Groups (use with -s):"
  echo "  hardware  = all hardware sections"
  echo "  software  = all software sections"
  echo "  stats     = live usage right now"
  echo "  all       = everything (default)"
  exit 0
}
while [ $# -gt 0 ]; do
  case "$1" in
    -o|--output)   OUTFILE="$2"; USE_COLOR=0; shift 2 ;;
    -s|--sections) SECTIONS="$(echo "$2" | tr ',' ' ')"; shift 2 ;;
    -l|--list)     list_sections ;;
    -q|--quick)    QUICK=1; shift ;;
    --no-color)    USE_COLOR=0; shift ;;
    -h|--help)     usage ;;
    *) echo "Unknown option: $1 (try -h)" >&2; exit 1 ;;
  esac
done
[ -t 1 ] || USE_COLOR=0

# expand group names into their sections, validate the rest
EXPANDED=""
for s in $SECTIONS; do
  case "$s" in
    all)      EXPANDED="$EXPANDED $ALL_SECTIONS" ;;
    hardware) EXPANDED="$EXPANDED $HW_GROUP" ;;
    software) EXPANDED="$EXPANDED $SW_GROUP" ;;
    stats)    EXPANDED="$EXPANDED $ST_GROUP" ;;
    *) case " $ALL_SECTIONS " in *" $s "*) EXPANDED="$EXPANDED $s" ;; *) echo "Unknown section: $s (see -l)" >&2; exit 1 ;; esac ;;
  esac
done
SECTIONS="$EXPANDED"
[ -z "$SECTIONS" ] && SECTIONS="$ALL_SECTIONS"

# ---------------------------------------------------------------- formatting
if [ "$USE_COLOR" = 1 ]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'
  BLUE=$'\033[34m'; CYAN=$'\033[36m'; GREEN=$'\033[32m'; MAGENTA=$'\033[35m'; YELLOW=$'\033[33m'
else
  BOLD=""; DIM=""; RESET=""; BLUE=""; CYAN=""; GREEN=""; MAGENTA=""; YELLOW=""
fi

WIDTH=78
SECNO=0
rule()   { printf '%*s\n' "$WIDTH" '' | tr ' ' "${1:-=}"; }
header() { SECNO=$((SECNO+1)); echo; echo "${BOLD}${BLUE}$(rule '=')${RESET}"; echo "${BOLD}${BLUE}  $SECNO. $1${RESET}"; echo "${BOLD}${BLUE}$(rule '=')${RESET}"; }
sub()    { echo; echo "${BOLD}${CYAN}--- $1 ${RESET}${DIM}$(printf '%*s' $((WIDTH - 5 - ${#1})) '' | tr ' ' '-')${RESET}"; }
kv()     { printf "  ${GREEN}%-28s${RESET} %s\n" "$1" "${2:-n/a}"; }
note()   { echo "  ${DIM}$1${RESET}"; }
indent() { sed 's/^/  /'; }
or_none() { local out; out="$(cat)"; if [ -n "$out" ]; then printf '%s\n' "$out" | indent; else note "${1:-none}"; fi; }
cols()   { awk -v W="$WIDTH" '{ l[NR]=$0; if (length($0)>m) m=length($0) } END { if (NR==0) exit; c=int((W-2)/(m+2)); if (c<1) c=1; r=int((NR+c-1)/c); for (i=1;i<=r;i++){ line="  "; for (j=0;j<c;j++){ k=i+j*r; if (k<=NR) line=line sprintf("%-*s", m+2, l[k]) } sub(/ +$/,"",line); print line } }'; }

sp()    { system_profiler "$@" 2>/dev/null | sed '1{/:$/d;}' | sed '/./,$!d' | sed 's/^    //' | or_none "nothing detected"; }
spraw() { system_profiler "$@" 2>/dev/null; }
sc()    { sysctl -n "$1" 2>/dev/null || echo "n/a"; }
have()  { command -v "$1" >/dev/null 2>&1; }
want()  { case " $SECTIONS " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }
gb()    { awk -v b="${1:-0}" 'BEGIN { printf "%.2f GB", b/1024/1024/1024 }'; }
mb()    { awk -v b="${1:-0}" 'BEGIN { printf "%.0f MB", b/1024/1024 }'; }
num()   { case "$1" in ''|*[!0-9]*) echo 0 ;; *) echo "$1" ;; esac; }
field() { echo "$1" | awk -F': ' -v k="$2" 'index($0, k": "){sub(/^[ \t]+/,"",$2); print $2; exit}'; }

IS_ARM=0; [ "$(uname -m)" = "arm64" ] && IS_ARM=1
HW="$(spraw SPHardwareDataType)"
IB="$(spraw SPiBridgeDataType)"
HAS_BATTERY=0; pmset -g batt 2>/dev/null | grep -q InternalBattery && HAS_BATTERY=1
# battery registry helpers (shared by battery + stats)
IO="$(ioreg -rn AppleSmartBattery 2>/dev/null | grep -v BatteryData)"
iov()    { echo "$IO" | awk -F' = ' -v k="\"$1\"" '$1 ~ k"$"{gsub(/^ +/,"",$2); print $2; exit}'; }
signed() { local v; v=$(num "$1"); echo $(( v )); }

# ---------------------------------------------------------------- report
report() {

echo "${BOLD}${MAGENTA}"
rule '#'
echo "#  MAC SYSTEM REPORT"
echo "#  Generated : $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "#  Computer  : $(scutil --get ComputerName 2>/dev/null || hostname)"
echo "#  Mode      : $([ "$QUICK" = 1 ] && echo quick || echo complete)"
rule '#'
echo "${RESET}"

# =================================================================== HARDWARE
if want overview; then
header "OVERVIEW"
kv "Model Name"        "$(field "$HW" "Model Name")"
kv "Model Identifier"  "$(field "$HW" "Model Identifier")"
kv "Model Number"      "$(field "$HW" "Model Number")"
kv "Chip / Processor"  "$(field "$HW" "Chip")$(field "$HW" "Processor Name")"
kv "Cores"             "$(field "$HW" "Total Number of Cores")"
kv "Memory"            "$(field "$HW" "Memory")"
kv "Storage"           "$(diskutil info / 2>/dev/null | awk -F': +' '/Container Total Space/{print $2}' | sed 's/ (.*//') internal SSD"
kv "Display"           "$(spraw SPDisplaysDataType | awk -F': ' '/Resolution:/{print $2; exit}')"
kv "Serial Number"     "$(field "$HW" "Serial Number (system)")"
kv "Hardware UUID"     "$(field "$HW" "Hardware UUID")"
kv "macOS"             "$(sw_vers -productName) $(sw_vers -productVersion) (build $(sw_vers -buildVersion))"
kv "Kernel"            "$(uname -sr)"
kv "Architecture"      "$(uname -m)"
kv "Computer Name"     "$(scutil --get ComputerName 2>/dev/null)"
kv "Local Hostname"    "$(scutil --get LocalHostName 2>/dev/null).local"
kv "Current User"      "$(whoami) (uid $(id -u))"
fi

if want firmware; then
header "HARDWARE, FIRMWARE & BOOT SECURITY"
sub "System Profiler: Hardware"
sp SPHardwareDataType
sub "Firmware & Boot Security"
kv "System Firmware"   "$(field "$HW" "System Firmware Version")"
kv "OS Loader Version" "$(field "$HW" "OS Loader Version")"
kv "Provisioning UDID" "$(field "$HW" "Provisioning UDID")"
kv "Activation Lock"   "$(field "$HW" "Activation Lock Status")"
kv "Secure Boot"       "$(field "$IB" "Secure Boot")"
kv "Signed System Vol" "$(field "$IB" "Signed System Volume")"
kv "Kernel CTRR"       "$(field "$IB" "Kernel CTRR")"
kv "3rd-party Kexts"   "$(field "$IB" "Allow All Kernel Extensions")"
[ "$IS_ARM" = 1 ] && kv "Secure Enclave" "Yes (Apple Silicon)"
sub "Boot Controller (T2 / Apple Silicon iBridge)"
sp SPiBridgeDataType
fi

if want cpu; then
header "CPU / PROCESSOR"
kv "Brand String"      "$(sc machdep.cpu.brand_string)"
kv "Architecture"      "$(uname -m)"
kv "Physical Cores"    "$(sc hw.physicalcpu)"
kv "Logical Cores"     "$(sc hw.logicalcpu)"
if [ "$IS_ARM" = 1 ]; then
  kv "Performance Cores" "$(sc hw.perflevel0.physicalcpu) ($(sc hw.perflevel0.name)), L2 $(mb "$(num "$(sc hw.perflevel0.l2cachesize)")") per cluster"
  kv "Efficiency Cores"  "$(sc hw.perflevel1.physicalcpu) ($(sc hw.perflevel1.name)), L2 $(mb "$(num "$(sc hw.perflevel1.l2cachesize)")") per cluster"
else
  kv "CPU Frequency"     "$(awk -v f="$(num "$(sc hw.cpufrequency)")" 'BEGIN{printf "%.2f GHz", f/1e9}')"
  kv "Vendor"            "$(sc machdep.cpu.vendor)"
  kv "Family / Model"    "$(sc machdep.cpu.family) / $(sc machdep.cpu.model) (stepping $(sc machdep.cpu.stepping))"
  kv "Microcode"         "$(sc machdep.cpu.microcode_version)"
fi
kv "Byte Order"        "$([ "$(sc hw.byteorder)" = 1234 ] && echo 'Little-endian' || echo 'Big-endian')"
kv "L1 Instruction"    "$(awk -v b="$(num "$(sc hw.l1icachesize)")" 'BEGIN{printf "%d KB",b/1024}')"
kv "L1 Data"           "$(awk -v b="$(num "$(sc hw.l1dcachesize)")" 'BEGIN{printf "%d KB",b/1024}')"
kv "L2 Cache"          "$(mb "$(num "$(sc hw.l2cachesize)")")"
kv "L3 Cache"          "$(sysctl -n hw.l3cachesize 2>/dev/null | awk '{printf "%d MB",$1/1024/1024}' | grep . || echo 'none / not exposed')"
kv "Cache Line Size"   "$(sc hw.cachelinesize) bytes"
kv "Page Size"         "$(sc hw.pagesize) bytes"
kv "64-bit Capable"    "$([ "$(sc hw.cpu64bit_capable)" = 1 ] && echo Yes || echo No)"
sub "CPU Feature Flags (sysctl hw.optional, present = 1)"
sysctl hw.optional 2>/dev/null | awk -F': ' '$2==1{sub("hw.optional.","",$1); printf "%s ", $1} END{print ""}' | fold -w 76 -s | indent
fi

if want memory; then
header "MEMORY (RAM)"
MEMB=$(sc hw.memsize)
kv "Total Physical RAM" "$(gb "$MEMB") ($MEMB bytes)"
kv "Type"              "$(spraw SPMemoryDataType | awk -F': ' '/Type:/{print $2; exit}')"
kv "Manufacturer"      "$(spraw SPMemoryDataType | awk -F': ' '/Manufacturer:/{print $2; exit}')"
kv "Upgradeable"       "$([ "$IS_ARM" = 1 ] && echo 'No (unified memory, soldered)' || spraw SPMemoryDataType | awk -F': ' '/Upgradeable Memory:/{print $2; exit}')"
kv "Page Size"         "$(sc hw.pagesize) bytes"
sub "Memory Modules (System Profiler)"
sp SPMemoryDataType
fi

if want storage; then
header "STORAGE"
sub "Physical Disks (NVMe / SATA)"
sp SPNVMeDataType
sp SPSerialATADataType
sub "Disk Layout (diskutil list)"
diskutil list 2>/dev/null | indent
sub "Boot Volume"
diskutil info / 2>/dev/null | grep -E 'Device Node|Volume Name|File System|Mount Point|Container Total|Container Free|Volume Used|Encrypted|FileVault|Solid State|Protocol|SMART|Disk Size|Owners|Sealed' | sed 's/^ *//' | indent
sub "APFS Containers"
diskutil apfs list 2>/dev/null | grep -E 'Container disk|Size \(Capacity|Capacity In Use|Capacity Not Allocated|Volume disk|Name:|Mount Point|Capacity Consumed|Encrypted|FileVault' | indent
sub "Mounted Volumes"
df -H 2>/dev/null | awk '{printf "%-28s %7s %7s %7s %6s  %s\n",$1,$2,$3,$4,$5,$9}' | indent
sub "Volumes (System Profiler)"
sp SPStorageDataType
sub "Local APFS Snapshots"
tmutil listlocalsnapshots / 2>/dev/null | grep -v '^Snapshots for' | or_none "none"
sub "Time Machine"
tmutil destinationinfo 2>&1 | indent
kv "Latest Backup" "$(tmutil latestbackup 2>/dev/null | grep . || echo 'none')"
fi

if want graphics; then
header "GRAPHICS & DISPLAYS"
sp SPDisplaysDataType
sub "Display Summary"
spraw SPDisplaysDataType | awk '
  /^ {8}[^ ].*:$/ && !/Displays:/ { d=$0; sub(/^ +/,"",d); sub(/:$/,"",d) }
  /^ {10}[^ ].*:$/ { d=$0; sub(/^ +/,"",d); sub(/:$/,"",d) }
  /Resolution:|UI Looks like:|Refresh Rate:|Connection Type:|Main Display:|Display Type:/ { l=$0; sub(/^ +/,"",l); printf "%-30s %s\n", d, l }
' | indent
fi

if want battery; then
header "BATTERY (health & specifications)"
if [ "$HAS_BATTERY" = 1 ]; then
  PB="$(spraw SPPowerDataType)"
  DESIGN=$(num "$(iov DesignCapacity)"); MAXC=$(num "$(iov AppleRawMaxCapacity)")
  kv "Condition"         "$(field "$PB" "Condition")"
  kv "Maximum Capacity"  "$(field "$PB" "Maximum Capacity")  ($MAXC mAh now vs $DESIGN mAh design)"
  kv "Cycle Count"       "$(iov CycleCount) (design limit $(iov DesignCycleCount9C))"
  kv "Design Capacity"   "$DESIGN mAh"
  kv "Battery Serial"    "$(field "$PB" "Serial Number")"
  kv "Battery Model"     "$(field "$PB" "Device Name")"
  kv "Battery Firmware"  "$(field "$PB" "Firmware Version")"
  kv "Manufacturer"      "$(field "$PB" "Manufacturer" | grep . || echo 'Apple / SMP')"
  note "Live charge, current draw and temperature are in the stats section."
else
  note "No internal battery detected (desktop Mac)."
fi
fi

if want network; then
header "NETWORK INTERFACES"
sub "Hostnames"
kv "Computer Name"     "$(scutil --get ComputerName 2>/dev/null)"
kv "Local Hostname"    "$(scutil --get LocalHostName 2>/dev/null).local"
kv "Host Name"         "$(scutil --get HostName 2>/dev/null || hostname)"
sub "Hardware Ports & MAC Addresses"
networksetup -listallhardwareports 2>/dev/null | awk '/Hardware Port:/{p=$0;sub(/Hardware Port: /,"",p)} /Device:/{d=$2} /Ethernet Address:/{printf "%-34s %-10s %s\n",p,d,$3}' | indent
sub "Network Services (service order, * = disabled)"
networksetup -listnetworkserviceorder 2>/dev/null | grep -E '^\(' | paste - - | sed 's/\t/  /' | indent
sub "IP Addresses (active interfaces)"
for IF in $(ifconfig -lu 2>/dev/null); do
  IP4=$(ifconfig "$IF" 2>/dev/null | awk '/inet /{print $2}' | tr '\n' ' ')
  IP6=$(ifconfig "$IF" 2>/dev/null | awk '/inet6 / && !/fe80/ {print $2}' | tr '\n' ' ')
  [ -n "$IP4$IP6" ] && kv "$IF" "${IP4}${IP6}"
done
kv "Public IP" "$(curl -s --max-time 4 https://api.ipify.org 2>/dev/null || echo 'unavailable (offline?)')"
sub "Routing & DNS"
kv "Default Gateway"   "$(route -n get default 2>/dev/null | awk '/gateway/{print $2}') via $(route -n get default 2>/dev/null | awk '/interface/{print $2}')"
kv "DNS Servers"       "$(scutil --dns 2>/dev/null | awk '/nameserver\[/{print $3}' | sort -u | tr '\n' ' ')"
kv "Search Domains"    "$(scutil --dns 2>/dev/null | awk '/search domain\[/{print $4}' | sort -u | tr '\n' ' ')"
sub "Wi-Fi"
WIFI_IF=$(networksetup -listallhardwareports 2>/dev/null | awk '/Hardware Port: Wi-Fi/{getline; print $2}')
if [ -n "$WIFI_IF" ]; then
  kv "Interface"       "$WIFI_IF"
  kv "Power"           "$(networksetup -getairportpower "$WIFI_IF" 2>/dev/null | awk -F': ' '{print $2}')"
  if [ "$QUICK" = 0 ]; then
    AP="$(spraw SPAirPortDataType)"
    EN="$(echo "$AP" | sed -n "/^ *$WIFI_IF:/,/^ *Other Local Wi-Fi Networks/p")"
    SSID=$(echo "$EN" | awk '/Current Network Information:/{getline; sub(/^ +/,""); sub(/:$/,""); print; exit}')
    case "$SSID" in "") SSID="not connected" ;; "<redacted>") SSID="connected (name hidden by macOS privacy; see: sudo wdutil info)" ;; esac
    kv "Network (SSID)"  "$SSID"
    echo "$EN" | sed -n '/Current Network Information/,/Other Local/p' | grep -E 'PHY Mode|Channel|Security|Signal|Transmit Rate|MCS|Network Type|Country Code' | sed 's/^ *//' | indent
    sub "Wi-Fi Card"
    echo "$EN" | grep -E 'Card Type|Firmware Version|MAC Address|Supported PHY|Wake On Wireless|AirDrop|Auto Unlock|Status' | sed 's/^ *//' | sort -u | indent
    echo "$EN" | grep -E 'Supported Channels' | head -1 | sed 's/^ *//' | fold -w 76 -s | indent
  else
    note "Wi-Fi details skipped in quick mode."
  fi
  sub "Known Wi-Fi Networks (preferred list)"
  networksetup -listpreferredwirelessnetworks "$WIFI_IF" 2>/dev/null | tail -n +2 | sed 's/^\t//' | cols
fi
sub "Ethernet / Thunderbolt Network Adapters"
sp SPEthernetDataType
fi

if want bluetooth; then
header "BLUETOOTH"
sp SPBluetoothDataType
fi

if want usb; then
header "USB, THUNDERBOLT & PCI"
sub "USB Devices"
sp SPUSBDataType
sub "Thunderbolt / USB4 Buses"
sp SPThunderboltDataType
sub "PCI Devices"
sp SPPCIDataType
sub "Card Readers"
sp SPCardReaderDataType
fi

if want audio; then
header "AUDIO"
sp SPAudioDataType
fi

if want camera; then
header "CAMERA"
sp SPCameraDataType
fi

# =================================================================== SOFTWARE
if want os; then
header "OPERATING SYSTEM & SOFTWARE"
sub "macOS"
kv "Product"           "$(sw_vers -productName)"
kv "Version"           "$(sw_vers -productVersion)"
kv "Build"             "$(sw_vers -buildVersion)"
kv "Kernel Version"    "$(sc kern.version | head -1)"
kv "OS Type / Release" "$(sc kern.ostype) $(sc kern.osrelease)"
kv "System Language"   "$(defaults read -g AppleLanguages 2>/dev/null | tr -d '\n "' | sed 's/[()]//g;s/,/, /g')"
kv "Locale"            "$(defaults read -g AppleLocale 2>/dev/null)"
kv "Time Zone"         "$(readlink /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||')"
kv "Boot Volume"       "$(diskutil info / 2>/dev/null | awk -F': +' '/Volume Name/{print $2}')"
kv "Boot Args"         "$(nvram boot-args 2>/dev/null | cut -f2- | grep . || echo 'none (normal boot)')"
kv "Login Shell"       "$SHELL ($($SHELL --version 2>/dev/null | head -1))"
kv "Terminal"          "${TERM_PROGRAM:-unknown} ${TERM_PROGRAM_VERSION:-}"
kv "Appearance"        "$(defaults read -g AppleInterfaceStyle 2>/dev/null || echo Light)"
sub "System Profiler: Software"
sp SPSoftwareDataType
if [ "$QUICK" = 0 ]; then
  sub "Available Software Updates (checking with Apple, ~10s)"
  softwareupdate --list 2>&1 | grep -E 'Title:|No new software' | sed 's/^[ \t]*//' | or_none "none"
fi
sub "Install History (last 20 installs / updates)"
spraw SPInstallHistoryDataType | awk '
  /^    [^ ].*:$/ { name=$0; sub(/^ +/,"",name); sub(/:$/,"",name) }
  /Version:/      { v=$0; sub(/.*Version: /,"",v) }
  /Source:/       { s=$0; sub(/.*Source: /,"",s) }
  /Install Date:/ { d=$0; sub(/.*Install Date: /,"",d); printf "%-22s  %-45s %-12s %s\n", d, name, v, s; v=""; s="" }
' | tail -20 | indent
fi

if want security; then
header "SECURITY"
SU="$(defaults read /Library/Preferences/com.apple.SoftwareUpdate 2>/dev/null)"
onoff() { case "$1" in 1) echo On ;; 0) echo Off ;; *) echo "On (default)" ;; esac; }
kv "System Integrity Protection" "$(csrutil status 2>/dev/null | sed 's/.*status: //')"
kv "FileVault"             "$(fdesetup status 2>/dev/null | head -1)"
kv "Gatekeeper"            "$(spctl --status 2>/dev/null)"
kv "Secure Boot"           "$(field "$IB" "Secure Boot")"
kv "Activation Lock"       "$(field "$HW" "Activation Lock Status")"
kv "Find My Mac"           "$(defaults read /Library/Preferences/com.apple.FindMyMac.plist FMMEnabled 2>/dev/null | sed 's/1/Enabled/;s/0/Disabled/' || echo 'unknown')"
kv "Auto Login"            "$(defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser 2>/dev/null || echo 'Off')"
kv "Screen Lock"           "$(sysadminctl -screenLock status 2>&1 | sed 's/.*] //')"
kv "XProtect Version"      "$(defaults read /Library/Apple/System/Library/CoreServices/XProtect.bundle/Contents/Info.plist CFBundleShortVersionString 2>/dev/null || echo 'n/a')"
kv "MRT Version"           "$(defaults read /Library/Apple/System/Library/CoreServices/MRT.app/Contents/Info.plist CFBundleShortVersionString 2>/dev/null || echo 'n/a')"
kv "Auto Update: check"    "$(onoff "$(echo "$SU" | awk -F'= ' '/AutomaticCheckEnabled/{print $2+0}')")"
kv "Auto Update: download" "$(onoff "$(echo "$SU" | awk -F'= ' '/AutomaticDownload/{print $2+0}')")"
kv "Auto Update: macOS"    "$(onoff "$(echo "$SU" | awk -F'= ' '/AutomaticallyInstallMacOSUpdates/{print $2+0}')")"
kv "Auto Update: security" "$(onoff "$(echo "$SU" | awk -F'= ' '/CriticalUpdateInstall/{print $2+0}')")"
kv "Sealed System Volume"  "$(diskutil info / 2>/dev/null | awk -F': +' '/Sealed/{print $2}')"
sub "Firewall"
kv "Application Firewall" "$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null | sed 's/.*is //')"
kv "Stealth Mode"         "$(/usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode 2>/dev/null | sed 's/.*mode //')"
sub "Sharing Services"
for s in "Remote Login (SSH)=com.openssh.sshd" "Screen Sharing=com.apple.screensharing" "File Sharing (SMB)=com.apple.smbd" "Remote Management=com.apple.RemoteDesktop" "Printer Sharing=org.cups.cupsd"; do
  NAME="${s%%=*}"; ID="${s##*=}"
  STATE=$(launchctl print system/"$ID" >/dev/null 2>&1 && echo "enabled" || echo "disabled")
  kv "$NAME" "$STATE"
done
kv "AirDrop" "$(defaults read com.apple.sharingd DiscoverableMode 2>/dev/null || echo 'default')"
sub "Proxies"
scutil --proxy 2>/dev/null | grep -E 'Enable|Proxy|Port' | grep -v ' 0$' | sed 's/^ *//' | or_none "none configured"
sub "Secure Element (Apple Pay)"
sp SPSecureElementDataType
sub "Keychains & Certificates"
kv "System Root CAs"       "$(security find-certificate -a /System/Library/Keychains/SystemRootCertificates.keychain 2>/dev/null | grep -c '"labl"')"
kv "Login Keychain Items"  "$(security dump-keychain 2>/dev/null | grep -c 'class:')"
kv "Keychain Files"        "$(security list-keychains 2>/dev/null | tr -d ' "' | tr '\n' ' ')"
sub "Configuration Profiles / MDM"
profiles status -type enrollment 2>/dev/null | indent
profiles list 2>/dev/null | head -20 | indent
fi

if want power; then
header "POWER SETTINGS"
sub "Active Power Settings (pmset -g)"
pmset -g 2>/dev/null | indent
sub "Settings per Power Source (pmset -g custom)"
pmset -g custom 2>/dev/null | indent
fi

if want users; then
header "USERS & GROUPS"
sub "Local User Accounts"
printf "  %-20s %-8s %-9s %-20s %s\n" "USER" "UID" "ROLE" "SHELL" "HOME"
dscl . list /Users 2>/dev/null | grep -v '^_' | while read -r u; do
  UID_=$(dscl . -read "/Users/$u" UniqueID 2>/dev/null | awk '{print $2}')
  HOME_=$(dscl . -read "/Users/$u" NFSHomeDirectory 2>/dev/null | awk '{print $2}')
  SHELL_=$(dscl . -read "/Users/$u" UserShell 2>/dev/null | awk '{print $2}')
  ADMIN=$(dseditgroup -o checkmember -m "$u" admin 2>/dev/null | grep -q '^yes' && echo "admin" || echo "standard")
  printf "  %-20s %-8s %-9s %-20s %s\n" "$u" "$UID_" "$ADMIN" "$SHELL_" "$HOME_"
done
sub "Logged-in Sessions"
who 2>/dev/null | indent
sub "Current User Groups"
id -Gn 2>/dev/null | tr ' ' '\n' | cols
sub "Login Items (open at login)"
osascript -e 'tell application "System Events" to get the name of every login item' 2>/dev/null | tr ',' '\n' | sed 's/^ *//' | or_none "none"
if [ "$QUICK" = 0 ]; then
  sub "Home Folder Sizes (top-level)"
  du -sh "$HOME"/* 2>/dev/null | sort -rh | head -15 | indent
fi
fi

if want devtools; then
header "DEVELOPER TOOLS & RUNTIMES"
vers() { if have "$2"; then kv "$1" "$("$2" "${@:3}" 2>&1 | grep -v '^$' | head -1)"; else kv "$1" "${DIM}not installed${RESET}"; fi; }
if have xcodebuild && xcodebuild -version >/dev/null 2>&1; then kv "Xcode" "$(xcodebuild -version 2>/dev/null | tr '\n' ' ')"; else kv "Xcode" "${DIM}not installed${RESET}"; fi
kv "Xcode CLT"        "$(xcode-select -p 2>/dev/null || echo 'not installed') $(pkgutil --pkg-info=com.apple.pkg.CLTools_Executables 2>/dev/null | awk '/version/{print "(v"$2")"}')"
kv "macOS SDK"        "$(xcrun --show-sdk-version 2>/dev/null || echo 'n/a')"
vers "Homebrew"       brew --version
vers "Git"            git --version
vers "Clang"          clang --version
vers "Swift"          swift --version
vers "Python 3"       python3 --version
vers "pip3"           pip3 --version
vers "Node.js"        node --version
vers "npm"            npm --version
vers "pnpm"           pnpm --version
vers "Yarn"           yarn --version
vers "Bun"            bun --version
vers "Deno"           deno --version
vers "Ruby"           ruby --version
vers "Perl"           perl -e 'print "perl $^V\n"'
vers "PHP"            php --version
vers "Java"           java -version
vers "Go"             go version
vers "Rust (rustc)"   rustc --version
vers "Cargo"          cargo --version
vers "Docker"         docker --version
vers "Podman"         podman --version
vers "kubectl"        kubectl version --client
vers "Terraform"      terraform --version
vers "AWS CLI"        aws --version
vers "gcloud"         gcloud --version
vers "Azure CLI"      az version
vers "Postgres (psql)" psql --version
vers "MySQL"          mysql --version
vers "SQLite"         sqlite3 --version
vers "Redis"          redis-server --version
vers "Vim"            vim --version
vers "Neovim"         nvim --version
vers "Tmux"           tmux -V
vers "Zsh"            zsh --version
vers "Bash"           bash --version
vers "Fish"           fish --version
vers "Claude Code"    claude --version
vers "GitHub CLI"     gh --version
if have ollama; then kv "Ollama" "$(ollama --version 2>&1 | grep -o 'version is.*\|[0-9][0-9.]*$' | tail -1)"; else kv "Ollama" "${DIM}not installed${RESET}"; fi
if have brew; then
  sub "Homebrew Formulae ($(brew list --formula 2>/dev/null | wc -l | tr -d ' '))"
  brew list --formula --versions 2>/dev/null | awk '{print $1" "$NF}' | cols
  sub "Homebrew Casks ($(brew list --cask 2>/dev/null | wc -l | tr -d ' '))"
  brew list --cask --versions 2>/dev/null | awk '{print $1" "$NF}' | cols
  sub "Homebrew Services"
  brew services list 2>/dev/null | or_none "none"
fi
if have npm; then
  sub "Global npm Packages"
  npm ls -g --depth=0 2>/dev/null | tail -n +2 | sed 's/^[├└]── //' | or_none "none"
fi
if have pip3; then kv "Python Packages (pip3)" "$(pip3 list 2>/dev/null | tail -n +3 | wc -l | tr -d ' ') installed"; fi
sub "PATH"
echo "$PATH" | tr ':' '\n' | indent
fi

if want apps; then
header "INSTALLED APPLICATIONS"
sub "User-installed Apps (/Applications, ~/Applications)"
printf "  %-42s %-20s %s\n" "NAME" "VERSION" "SOURCE / SIGNING"
COUNT=0
for APP in /Applications/*.app /Applications/Utilities/*.app "$HOME"/Applications/*.app; do
  [ -d "$APP" ] || continue
  COUNT=$((COUNT+1))
  NAME=$(basename "$APP" .app)
  VER=$(defaults read "$APP/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || defaults read "$APP/Contents/Info.plist" CFBundleVersion 2>/dev/null || echo "?")
  if [ "$QUICK" = 1 ]; then SRC="-"
  elif [ -d "$APP/Contents/_MASReceipt" ]; then SRC="App Store"
  else
    CS="$(codesign -dvv "$APP" 2>&1)"
    case "$CS" in
      *"Apple Mac OS Application Signing"*) SRC="App Store" ;;
      *"Authority=Software Signing"*)        SRC="Apple" ;;
      *"Developer ID Application: "*)        SRC="Developer ID ($(echo "$CS" | sed -n 's/.*Developer ID Application: \(.*\) (.*/\1/p' | head -1))" ;;
      *"Authority=Apple Development"*)       SRC="Development build" ;;
      *"adhoc"*)                             SRC="ad-hoc signed" ;;
      *"not signed"*)                        SRC="unsigned" ;;
      *)                                     SRC="other" ;;
    esac
  fi
  printf "  %-42s %-20s %s\n" "$NAME" "$VER" "$SRC"
done
kv "Total" "$COUNT apps"
sub "Apple System Apps (/System/Applications)"
ls /System/Applications 2>/dev/null | sed 's/\.app$//' | cols
sub "Defaults & Compatibility"
kv "Default Browser" "$(defaults read "$HOME/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist" LSHandlers 2>/dev/null | awk '/^        LSHandlerRoleAll/{r=$3} /LSHandlerURLScheme = https/{gsub(/[";]/,"",r); print r; exit}' | grep . || echo "com.apple.Safari (system default)")"
if [ "$IS_ARM" = 1 ]; then
  if [ -f /Library/Apple/usr/share/rosetta/rosetta ] || arch -x86_64 /usr/bin/true 2>/dev/null; then kv "Rosetta 2" "Installed"; else kv "Rosetta 2" "Not installed"; fi
else
  kv "Rosetta 2" "n/a (Intel Mac)"
fi
kv "App Store Account" "$(defaults read com.apple.commerce 2>/dev/null | grep -c 'AppleID' | sed 's/^0$/not signed in/;s/^[1-9].*/signed in/')"
fi

if want services; then
header "BACKGROUND SERVICES & LAUNCH ITEMS"
sub "User LaunchAgents (~/Library/LaunchAgents)"
ls -1 "$HOME/Library/LaunchAgents" 2>/dev/null | or_none "none"
sub "Global LaunchAgents (/Library/LaunchAgents)"
ls -1 /Library/LaunchAgents 2>/dev/null | or_none "none"
sub "Global LaunchDaemons (/Library/LaunchDaemons)"
ls -1 /Library/LaunchDaemons 2>/dev/null | or_none "none"
sub "Third-party Services Loaded for This User (launchctl list, non-Apple)"
launchctl list 2>/dev/null | awk 'NR>1 && $3 !~ /com\.apple\./ && $3 !~ /^application\./ {printf "%-55s pid=%-6s status=%s\n", $3, $1, $2}' | sort | or_none "none"
sub "Cron Jobs (current user)"
crontab -l 2>/dev/null | or_none "none"
sub "Printers"
lpstat -p 2>/dev/null | or_none "none configured"
fi

if want kernel; then
header "KERNEL & SYSTEM EXTENSIONS"
sub "Third-party Kernel Extensions (loaded)"
kextstat 2>/dev/null | grep -v 'com.apple' | awk 'NR>1{print $6, $7}' | or_none "none"
sub "System Extensions (systemextensionsctl)"
systemextensionsctl list 2>/dev/null | indent
sub "Kernel Parameters (selected)"
kv "Max Processes"    "$(sc kern.maxproc)"
kv "Max Open Files"   "$(sc kern.maxfiles) (per process: $(sc kern.maxfilesperproc))"
kv "Secure Level"     "$(sc kern.securelevel)"
kv "Kernel UUID"      "$(sc kern.uuid)"
kv "Boot Args"        "$(nvram boot-args 2>/dev/null | cut -f2- | grep . || echo 'none')"
kv "Boot Session UUID" "$(sc kern.bootsessionuuid)"
sub "NVRAM (selected)"
nvram -p 2>/dev/null | grep -Ei '^(SystemAudioVolume|boot-args|fmm-|csr-active|prev-lang|StartupMute|LocationServicesEnabled|AutoBoot|bluetoothInternal)' | cut -c1-$WIDTH | or_none "nothing notable"
sub "Kernel Panic Reports"
ls -t /Library/Logs/DiagnosticReports/*.panic 2>/dev/null | head -5 | xargs -n1 basename 2>/dev/null | or_none "no kernel panics on record"
sub "Recent Crash Reports (last 10, this user)"
ls -t "$HOME"/Library/Logs/DiagnosticReports/*.ips 2>/dev/null | head -10 | xargs -n1 basename 2>/dev/null | or_none "none"
fi

# =================================================================== LIVE STATS
if want stats; then
header "LIVE STATS (right now)"
sub "System"
kv "Uptime"            "$(uptime | sed 's/.*up \(.*\), [0-9]* user.*/\1/')"
kv "Boot Time"         "$(sysctl -n kern.boottime | sed 's/.*} //')"
kv "Load Average"      "$(sysctl -n vm.loadavg | tr -d '{}' | sed 's/^ *//;s/ *$//')  (1, 5, 15 min)"
kv "Total Processes"   "$(ps -ax 2>/dev/null | wc -l | tr -d ' ')"
kv "Total Threads"     "$(ps -axM 2>/dev/null | wc -l | tr -d ' ')"
kv "Running Apps"      "$(osascript -e 'tell application "System Events" to count (every process whose background only is false)' 2>/dev/null)"
sub "CPU"
TOPH="$(top -l 2 -n 0 -s 1 2>/dev/null | grep 'CPU usage' | tail -1)"
kv "CPU Usage"         "$(echo "$TOPH" | sed 's/CPU usage: //')"
kv "Thermal State"     "$(pmset -g therm 2>/dev/null | grep -i 'CPU_Scheduler_Limit\|Speed_Limit' | tr '\n' ' ' | sed 's/^ *//' | grep . || echo 'nominal (no throttling recorded)')"
if [ "$(id -u)" = 0 ] && have powermetrics; then
  sub "Temperatures & Fans (powermetrics)"
  powermetrics --samplers smc,thermal -i 500 -n 1 2>/dev/null | grep -Ei 'fan|temp|thermal|pressure' | or_none "no SMC sensor data"
else
  note "Fan speeds and temperatures need root:  sudo ./macinfo.sh -s stats"
fi
sub "Top 10 CPU Consumers"
ps -Arco pid,pcpu,pmem,comm 2>/dev/null | head -11 | indent
sub "Memory"
PAGESZ=$(num "$(sc hw.pagesize)")
VM="$(vm_stat 2>/dev/null)"
pg()  { echo "$VM" | awk -F': +' -v k="$1" '$1==k{gsub("\\.","",$2); print $2}'; }
tog() { awk -v p="$(num "${1:-0}")" -v s="$PAGESZ" 'BEGIN{printf "%.2f GB", p*s/1024/1024/1024}'; }
kv "Total"             "$(gb "$(sc hw.memsize)")"
kv "Wired (kernel)"    "$(tog "$(pg 'Pages wired down')")"
kv "Active"            "$(tog "$(pg 'Pages active')")"
kv "Inactive"          "$(tog "$(pg 'Pages inactive')")"
kv "Speculative"       "$(tog "$(pg 'Pages speculative')")"
kv "Compressed"        "$(tog "$(pg 'Pages occupied by compressor')")"
kv "Purgeable"         "$(tog "$(pg 'Pages purgeable')")"
kv "File-backed (cache)" "$(tog "$(pg 'File-backed pages')")"
kv "Anonymous (apps)"  "$(tog "$(pg 'Anonymous pages')")"
kv "Free"              "$(tog "$(pg 'Pages free')")"
kv "Swap Usage"        "$(sysctl -n vm.swapusage 2>/dev/null)"
kv "Memory Pressure"   "$(memory_pressure 2>/dev/null | awk -F': ' '/System-wide memory free percentage/{print $2 " free"}')"
sub "Top 10 Memory Consumers"
ps -Amco pid,pmem,rss,comm 2>/dev/null | head -11 | awk 'NR==1{print; next}{printf "%6s %5s %7.0f MB  %s\n",$1,$2,$3/1024,substr($0,index($0,$4))}' | indent
sub "Disk"
df -H / 2>/dev/null | awk 'NR==2{print "Boot volume: " $3 " used of " $2 " (" $5 "), " $4 " free"}' | indent
df -H 2>/dev/null | awk 'NR>1 && $1 ~ /^\/\/|^\/dev\/disk[0-9]+s[0-9]+$/ && $9 !~ /^\/System/ && $9 != "/" {print $9 ": " $3 " used of " $2 " (" $5 ")"}' | indent
if [ "$HAS_BATTERY" = 1 ]; then
  sub "Battery & Power"
  BAT="$(pmset -g batt 2>/dev/null)"
  PB="$(spraw SPPowerDataType)"
  kv "Status"            "$(echo "$BAT" | grep InternalBattery | sed 's/.*)\t//;s/ present.*//')"
  kv "Power Source"      "$(echo "$BAT" | head -1 | sed "s/Now drawing from '//;s/'//")"
  kv "Charge"            "$(field "$PB" "State of Charge (%)")%  ($(num "$(iov AppleRawCurrentCapacity)") mAh)"
  kv "Charging"          "$(field "$PB" "Charging")"
  kv "Fully Charged"     "$(field "$PB" "Fully Charged")"
  kv "Voltage"           "$(awk -v v="$(num "$(iov Voltage)")" 'BEGIN{printf "%.3f V", v/1000}')"
  kv "Current Draw"      "$(awk -v a="$(signed "$(iov InstantAmperage)")" 'BEGIN{printf "%d mA (%s)", a, (a<0?"discharging":(a>0?"charging":"idle"))}')"
  kv "Temperature"       "$(awk -v t="$(num "$(iov Temperature)")" 'BEGIN{printf "%.1f °C", t/100}')"
  kv "Time to Empty"     "$(awk -v m="$(num "$(iov AvgTimeToEmpty)")" 'BEGIN{ if (m>=65535) print "n/a (not discharging)"; else printf "%dh %02dm", m/60, m%60 }')"
  kv "Time to Full"      "$(awk -v m="$(num "$(iov AvgTimeToFull)")" 'BEGIN{ if (m>=65535) print "n/a (not charging)"; else printf "%dh %02dm", m/60, m%60 }')"
  kv "Low Power Mode"    "$(pmset -g 2>/dev/null | awk '/lowpowermode/{print ($2==1?"On":"Off")}')"
  if echo "$PB" | grep -q 'Connected: Yes'; then
    echo "$PB" | sed -n '/AC Charger Information/,/^$/p' | grep -E 'Wattage|Family|Name|Manufacturer|Serial' | sed 's/^ *//' | sed 's/^/Adapter /' | indent
  else
    note "No power adapter connected."
  fi
fi
sub "Sleep Assertions (what is keeping the Mac awake)"
pmset -g assertions 2>/dev/null | sed -n '/Listed by owning process/,$p' | grep -E '^\s+pid' | sed 's/^ *//' | cut -c1-$((WIDTH+30)) | or_none "none"
sub "Listening TCP Ports (process -> address)"
lsof +c 0 -nP -iTCP -sTCP:LISTEN 2>/dev/null | awk 'NR>1{printf "%-30s %s\n", $1, $9}' | sort -u | or_none "none"
sub "Active Network Connections (established, by process)"
lsof +c 0 -nP -iTCP -sTCP:ESTABLISHED 2>/dev/null | awk 'NR>1{print $1}' | sort | uniq -c | sort -rn | head -15 | awk '{printf "%-40s %s\n",$2,$1}' | or_none "none"
fi

echo
echo "${BOLD}${MAGENTA}$(rule '#')${RESET}"
echo "${BOLD}${MAGENTA}#  END OF REPORT${RESET}"
echo "${BOLD}${MAGENTA}$(rule '#')${RESET}"
}

# ---------------------------------------------------------------- run
if [ -n "$OUTFILE" ]; then
  report > "$OUTFILE" 2>&1
  echo "Report saved to: $OUTFILE ($(wc -l < "$OUTFILE" | tr -d ' ') lines)"
else
  report
fi
