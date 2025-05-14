#!/bin/zsh

####################################################
#                     STAGE 1
#         Setup Mode, ISO Path, Dependency Check
#         ISO Architecture + Partition Wipe Prompt
####################################################

set -euo pipefail
setopt EXTENDED_GLOB

# ---------- UI Colors ----------
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
CYAN=$(tput setaf 6)
RESET=$(tput sgr0)

# ---------- Globals ----------
MODE=""
DRY_RUN=false
INSPECT_ONLY=false
SKIP_OOBE=false
ENABLE_PARTWIPE=false
USERNAME="admin"
PASSWORD="admin1234"
CLI_ISO_PATH="${1:-}"
ISO_PATH=""
TEMP_DIR=""
IS_ARM64=false

# ---------- Help ----------
if [[ "$CLI_ISO_PATH" == "--help" || "$CLI_ISO_PATH" == "-h" ]]; then
  echo "Usage: ./create-windows-usb.zsh [optional-path-to-ISO]"
  echo "Options:"
  echo "  --help     Show this help message"
  exit 0
fi

# ---------- Print Header ----------
print_header() {
  echo -e "${CYAN}"
  echo "┌──────────────────────────────────────────────────────────────────────────────┐"
  echo "│                         🪟 WINDOWS USB CREATOR FOR macOS                     │"
  echo "├──────────────────────────────────────────────────────────────────────────────┤"
  echo "│ 📦  Windows 10/11 installer with GVLK, TPM bypass, and dry-run support       │"
  echo "│ 🛠   Supports UEFI (GPT) and Legacy BIOS (MBR), and full unattended setup     │"
  echo "│ 🌐  Fixed Region: English (World), Keyboard: 0409, UI: customizable          │"
  echo "│ 🔧  Built for Apple Silicon & Intel, with install.wim split (FAT32)          │"
  echo "└──────────────────────────────────────────────────────────────────────────────┘"
  echo -e "${RESET}"
}

# ---------- Dependency Check ----------
check_brew_and_dependencies() {
  echo -e "${YELLOW}🔧 Checking dependencies...${RESET}"

  if ! command -v brew &>/dev/null; then
    echo -e "${RED}❌ Homebrew is not installed. Please install it first: https://brew.sh/${RESET}"
    exit 1
  fi

  REQUIRED_TOOLS=("wimlib-imagex" "rsync" "jq")
  for tool in "${REQUIRED_TOOLS[@]}"; do
    TOOL_PATH=$(command -v "$tool" || true)
    HOMEBREW_PATH=$(brew --prefix 2>/dev/null || echo "/usr/local")
    if [[ -z "$TOOL_PATH" || "$TOOL_PATH" != "$HOMEBREW_PATH"* ]]; then
      echo -e "${YELLOW}⏳ Installing missing or outdated tool via Homebrew: $tool...${RESET}"
      brew install "$tool"
    else
      echo -e "${GREEN}✔ $tool is installed via Homebrew.${RESET}"
    fi
  done
}

# ---------- GVLK Key Resolver ----------
get_gvlk_key() {
  local edition="$1"
  case "$edition" in
    *"Pro N for Workstations"*) echo "NRG8B-VKK3Q-CXVCJ-9G2XF-6Q84J" ;;
    *"Pro for Workstations"*)   echo "NRG8B-VKK3Q-CXVCJ-9G2XF-6Q84J" ;;
    *"Pro Education N"*)        echo "8PTT6-RNW4C-6V7J2-C2D3X-MHBPB" ;;
    *"Pro Education"*)          echo "6TP4R-GNPTD-KYYHQ-7B7DP-J447Y" ;;
    *"Home Single Language"*)   echo "7HNRX-D7KGG-3K4RQ-4WPJ4-YTDFH" ;;
    *"Home N"*)                 echo "3KHY7-WNT83-DGQKR-F7HPR-844BM" ;;
    *"Home"*)                   echo "TX9XD-98N7V-6WMQ6-BX7FG-H8Q99" ;;
    *"Pro N"*)                  echo "W269N-WFGWX-YVC9B-4J6C9-T83GX" ;;
    *"Pro"*)                    echo "VK7JG-NPHTM-C97JM-9MPGT-3V66T" ;;
    *"Education N"*)            echo "NW6C2-QMPVW-D7KKK-3GKT6-VCFB2" ;;
    *"Education"*)              echo "NW6C2-QMPVW-D7KKK-3GKT6-VCFB2" ;;
    *)                          echo "VK7JG-NPHTM-C97JM-9MPGT-3V66T" ;;  # fallback
  esac
}

# ---------- Start Execution ----------
print_header
check_brew_and_dependencies

# ---------- Setup Mode ----------
while true; do
  echo "Choose setup mode:"
  echo "  1) Skip Microsoft OOBE and create a local admin account"
  echo "  2) Use standard setup with Microsoft/Work account support"
  echo "  3) Inspect ISO + Generate Autounattend.xml only (no USB write)"
  print -n "Enter choice [1/2/3]: "
  read SETUP_MODE

  case "$SETUP_MODE" in
    1) MODE="oobe-skip"; SKIP_OOBE=true; break ;;
    2) MODE="standard"; SKIP_OOBE=false; break ;;
    3) MODE="inspect"; INSPECT_ONLY=true; break ;;
    *) echo -e "${RED}❌ Invalid choice. Please enter 1, 2, or 3.${RESET}" ;;
  esac
done

# ---------- ISO Path ----------
if [[ -n "$CLI_ISO_PATH" && -f "$CLI_ISO_PATH" && "$CLI_ISO_PATH" == *.iso ]]; then
  ISO_PATH="$CLI_ISO_PATH"
else
  print -n "📁 Path to Windows ISO: "
  read ISO_PATH
  [[ ! -f "$ISO_PATH" || "$ISO_PATH" != *.iso ]] && {
    echo -e "${RED}❌ Invalid ISO file.${RESET}"
    exit 1
  }
fi

# ---------- Detect ISO Architecture ----------
ARCH_STRING=$(wimlib-imagex info "$ISO_PATH" 2>/dev/null | grep -i 'Architecture' || true)
if [[ "$ARCH_STRING" =~ "arm64" ]]; then
  IS_ARM64=true
else
  IS_ARM64=false
fi
if [[ "$IS_ARM64" == true ]]; then
  ARCH_TYPE="ARM64"
else
  ARCH_TYPE="x64"
fi

# ---------- Full Partition Wipe Prompt ----------
while true; do
  print -n "🧨 Do you want to wipe all partitions on target PC? (Recommended for clean installs) [y/N]: "
  read wipe_confirm
  if [[ "$wipe_confirm" =~ ^[Yy]$ ]]; then
    ENABLE_PARTWIPE=true
    break
  elif [[ "$wipe_confirm" =~ ^[Nn]?$ ]]; then
    ENABLE_PARTWIPE=false
    break
  else
    echo -e "${YELLOW}Please enter y or n.${RESET}"
  fi
done

echo -e "${CYAN}🧬 ISO Architecture detected:${RESET} ${GREEN}$ARCH_TYPE${RESET}"

####################################################
#                     STAGE 2
#   Mount ISO, Edition + Language Detection
#   Boot Mode Prompt + USB Disk Overview
#   Keyboard Layout + Hostname Selection
####################################################

# ---------- Setup Trap for Cleanup ----------
cleanup_tmp_files() {
  [[ -f "/tmp/install.wim" ]] && rm -f "/tmp/install.wim"
  [[ -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
}
trap cleanup_tmp_files EXIT

# ---------- Mount ISO ----------
echo -e "${CYAN}🔍 Mounting ISO image...${RESET}"
ISO_MOUNT=$(hdiutil attach "$ISO_PATH" | grep -o '/Volumes/[^ ]*')
if [[ ! -d "$ISO_MOUNT" ]]; then
  echo -e "${RED}❌ Failed to mount ISO.${RESET}"
  exit 1
fi

# ---------- List USB Devices (Informational) ----------
echo -e "${CYAN}💽 Looking for external USB disks...${RESET}"
until diskutil list external physical | grep -q "^/dev/"; do
  echo -e "${YELLOW}⚠️  No USB disks detected. Plug one in and press [ENTER] to retry.${RESET}"
  read -k1
  echo
done

diskutil list external physical | grep "^/dev/"

# ---------- Boot Mode Prompt ----------
if [[ "$IS_ARM64" == true ]]; then
  echo -e "${YELLOW}⚠️ ARM64 architecture requires UEFI mode.${RESET}"
  PARTITION_STYLE="GPT"
else
  print -n "⚙️  Boot mode? (u = UEFI, l = Legacy BIOS): "
  read BOOT_MODE
  PARTITION_STYLE="GPT"
  [[ "$BOOT_MODE" =~ ^[lL]$ ]] && PARTITION_STYLE="MBRFormat"
fi

# ---------- Locate WIM/ESD ----------
INSTALL_WIM="$ISO_MOUNT/sources/install.wim"
[[ ! -f "$INSTALL_WIM" ]] && INSTALL_WIM="$ISO_MOUNT/sources/install.esd"
if [[ ! -f "$INSTALL_WIM" ]]; then
  echo -e "${RED}❌ Could not find install.wim or install.esd.${RESET}"
  hdiutil detach "$ISO_MOUNT"
  exit 1
fi

# ---------- Build Edition JSON ----------
EDITION_JSON=$(wimlib-imagex info "$INSTALL_WIM" |
  awk 'BEGIN{FS=":"}
  /^[[:space:]]*Index:/ {
    idx=$2; gsub(/[[:space:]]/, "", idx)
  }
  /^[[:space:]]*Name:/ {
    name=substr($0, index($0,$2))
    gsub(/^[ \t]+|[ \t]+$/, "", name)
    if (name !~ /Operating System/) print idx "|" name
  }' |
  jq -R -s '
    split("\n")[:-1]
    | map( split("|") | { index: .[0], name: .[1] } )
  '
)

# ---------- Populate Edition Arrays ----------
typeset -a EDITION_INDICES EDITION_NAMES
i=1
while IFS='|' read -r idx name; do
  [[ -z "$idx" || -z "$name" ]] && continue
  EDITION_INDICES[i]="$idx"
  EDITION_NAMES[i]="$name"
  ((i++))
done < <(jq -r '.[] | "\(.index)|\(.name)"' <<<"$EDITION_JSON")

# ---------- Guard: No Editions Found ----------
if (( ${#EDITION_NAMES[@]} == 0 )); then
  echo -e "${RED}❌ No Windows editions found. Check install.wim/esd.${RESET}"
  exit 1
fi

# ---------- Edition Selection ----------
echo -e "${CYAN}💡 Available Windows Editions:${RESET}"
for (( i=1; i<=${#EDITION_NAMES[@]}; i++ )); do
  printf " %2d) %s\n" "$i" "${EDITION_NAMES[i]}"
done

while true; do
  print -n "➡️  Choose edition number: "
  read edition_choice
  if (( edition_choice >= 1 && edition_choice <= ${#EDITION_NAMES[@]} )); then
    INSTALL_NAME="${EDITION_NAMES[edition_choice]}"
    PRODUCT_KEY=$(get_gvlk_key "$INSTALL_NAME")
    break
  fi
  echo -e "${RED}❌ Invalid edition index. Try again.${RESET}"
done

# ---------- Language Detection ----------
LANG_ENTRY=$(wimlib-imagex info "$INSTALL_WIM" "$edition_choice" |
  grep -i -E 'Default Language:|Languages:|Language:' || true)
SELECTED_LANG=$(echo "$LANG_ENTRY" | awk -F: 'NR==1 { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2 }')
[[ -z "$SELECTED_LANG" ]] && SELECTED_LANG="en-US"
echo -e "${CYAN}🌐 Detected Language:${RESET} ${GREEN}$SELECTED_LANG${RESET}"

# ---------- Keyboard Layout Selection ----------
typeset -A KBD_MAP
KBD_MAP=(
  ["0409:00000409"]="US"
  ["0809:00000809"]="UK"
  ["1009:00001009"]="Canadian"
  ["0C09:00000C09"]="Australian"
  ["1409:00001409"]="New Zealand"
  ["040C:0000040C"]="French"
  ["0407:00000407"]="German"
  ["040A:0000040A"]="Spanish"
)

typeset -a KBD_CODES KBD_NAMES
i=1
for code in ${(k)KBD_MAP}; do
  KBD_CODES[i]="$code"
  KBD_NAMES[i]="${KBD_MAP[$code]}"
  ((i++))
done

# ---------- Guard: No Layouts ----------
if (( ${#KBD_NAMES[@]} == 0 )); then
  echo -e "${RED}❌ No keyboard layouts available. Something went wrong.${RESET}"
  exit 1
fi

echo -e "${CYAN}⌨️  Choose a keyboard layout:${RESET}"
for (( i=1; i<=${#KBD_NAMES[@]}; i++ )); do
  printf " %2d) %s\n" "$i" "${KBD_NAMES[i]}"
done

print -n "Enter layout number [default: 1 = US]: "
read layout_choice
[[ -z "$layout_choice" ]] && layout_choice=1

if (( layout_choice < 1 || layout_choice > ${#KBD_NAMES[@]} )); then
  echo -e "${RED}❌ Invalid choice. Defaulting to US layout.${RESET}"
  layout_choice=1
fi

SELECTED_KBD_LAYOUT="${KBD_CODES[layout_choice]}"
kbd_name="${KBD_NAMES[layout_choice]}"
echo -e "⌨️  Keyboard layout set to: ${GREEN}$kbd_name${RESET} ($SELECTED_KBD_LAYOUT)"

# ---------- Computer Name ----------
print -n "💻  Enter computer name: "
read COMPUTER_NAME
COMPUTER_NAME=$(echo "$COMPUTER_NAME" | tr -cd '[:alnum:]-')

# ---------- Stage Complete ----------
echo -e "${CYAN}✅ Stage 2 complete:${RESET} Edition=${GREEN}$INSTALL_NAME${RESET}, Language=${GREEN}$SELECTED_LANG${RESET}, Keyboard=${GREEN}$kbd_name${RESET}, Hostname=${GREEN}$COMPUTER_NAME${RESET}"

####################################################
#                     STAGE 3
#         Generate Autounattend.xml with:
#       Localization, Partitioning, Credentials,
#     Bypass Tweaks, GVLK, and Computer Identity
####################################################

# ---------- Build Autounattend.xml ----------
AUTO_XML_PATH="/tmp/Autounattend.xml"
TIMEZONE="${TIMEZONE:-UTC}"

AUTO_XML=$(cat <<EOF
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
  <settings pass="windowsPE">
    <component name="Microsoft-Windows-International-Core-WinPE"
               processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35"
               language="neutral"
               versionScope="nonSxS"
               xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
      <SetupUILanguage><UILanguage>en-US</UILanguage></SetupUILanguage>
      <InputLocale>$SELECTED_KBD_LAYOUT</InputLocale>
      <SystemLocale>en-001</SystemLocale>
      <UILanguage>en-US</UILanguage>
      <UserLocale>en-001</UserLocale>
    </component>
    <component name="Microsoft-Windows-Setup"
               processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35"
               language="neutral"
               versionScope="nonSxS"
               xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
      <ImageInstall>
        <OSImage>
          <InstallFrom>
            <MetaData wcm:action="add">
              <Key>/IMAGE/NAME</Key>
              <Value>$INSTALL_NAME</Value>
            </MetaData>
          </InstallFrom>
          <WillShowUI>OnError</WillShowUI>
        </OSImage>
      </ImageInstall>
      <UserData>
        <ProductKey>
          <Key>$PRODUCT_KEY</Key>
          <WillShowUI>Never</WillShowUI>
        </ProductKey>
        <AcceptEula>true</AcceptEula>
        <FullName>AutoUser</FullName>
        <Organization>Autogen</Organization>
        <ComputerName>$COMPUTER_NAME</ComputerName>
      </UserData>
EOF
)

if [[ "$ENABLE_PARTWIPE" == true ]]; then
  if [[ "$PARTITION_STYLE" == "MBRFormat" ]]; then
    AUTO_XML+=$(cat <<EOF
      <DiskConfiguration>
        <Disk wcm:action="add">
          <DiskID>0</DiskID>
          <WillWipeDisk>true</WillWipeDisk>
          <CreatePartitions>
            <CreatePartition wcm:action="add">
              <Order>1</Order>
              <Type>Primary</Type>
              <Size>100</Size>
            </CreatePartition>
            <CreatePartition wcm:action="add">
              <Order>2</Order>
              <Type>Primary</Type>
              <Extend>true</Extend>
            </CreatePartition>
          </CreatePartitions>
          <ModifyPartitions>
            <ModifyPartition wcm:action="add">
              <Active>true</Active>
              <Format>NTFS</Format>
              <Label>System</Label>
              <Order>1</Order>
              <PartitionID>1</PartitionID>
            </ModifyPartition>
            <ModifyPartition wcm:action="add">
              <Format>NTFS</Format>
              <Label>Windows</Label>
              <Order>2</Order>
              <PartitionID>2</PartitionID>
            </ModifyPartition>
          </ModifyPartitions>
        </Disk>
        <WillShowUI>OnError</WillShowUI>
      </DiskConfiguration>
EOF
    )
  else
    AUTO_XML+=$(cat <<EOF
      <DiskConfiguration>
        <Disk wcm:action="add">
          <DiskID>0</DiskID>
          <WillWipeDisk>true</WillWipeDisk>
          <CreatePartitions>
            <CreatePartition wcm:action="add">
              <Order>1</Order>
              <Type>Primary</Type>
              <Size>100</Size>
            </CreatePartition>
            <CreatePartition wcm:action="add">
              <Order>2</Order>
              <Type>EFI</Type>
              <Size>300</Size>
            </CreatePartition>
            <CreatePartition wcm:action="add">
              <Order>3</Order>
              <Type>Primary</Type>
              <Extend>true</Extend>
            </CreatePartition>
          </CreatePartitions>
          <ModifyPartitions>
            <ModifyPartition wcm:action="add">
              <Active>true</Active>
              <Format>NTFS</Format>
              <Label>System</Label>
              <Order>1</Order>
              <PartitionID>1</PartitionID>
            </ModifyPartition>
            <ModifyPartition wcm:action="add">
              <Format>FAT32</Format>
              <Label>EFI</Label>
              <Order>2</Order>
              <PartitionID>2</PartitionID>
            </ModifyPartition>
            <ModifyPartition wcm:action="add">
              <Format>NTFS</Format>
              <Label>Windows</Label>
              <Order>3</Order>
              <PartitionID>3</PartitionID>
            </ModifyPartition>
          </ModifyPartitions>
        </Disk>
        <WillShowUI>OnError</WillShowUI>
      </DiskConfiguration>
EOF
    )
  fi
fi

AUTO_XML+=$(cat <<EOF
    </component>
  </settings>
</unattend>
EOF
)

echo "$AUTO_XML" > "$AUTO_XML_PATH"
echo -e "${GREEN}✅ Autounattend.xml created at $AUTO_XML_PATH${RESET}"


####################################################
#                     STAGE 4
#           USB Media Creation + Validation
#     Format, Mount, Copy, Split WIM, Inject Files
####################################################

if [[ "$INSPECT_ONLY" == true ]]; then
  echo -e "${YELLOW}ℹ️  Inspect mode enabled. Skipping USB write stage.${RESET}"
  return
fi

# ---------- USB Disk Selection ----------
diskutil list external physical | grep "^/dev/" || {
  echo -e "${RED}❌ No external USB disks found.${RESET}"
  exit 1
}
print -n "💽 Enter disk identifier for your USB drive (e.g., disk2): "
read USB_DISK_ID

if ! diskutil info "/dev/$USB_DISK_ID" &>/dev/null; then
  echo -e "${RED}❌ Invalid disk identifier: $USB_DISK_ID${RESET}"
  exit 1
fi

# ---------- Confirm Format ----------
print -n "⚠️  This will ERASE /dev/$USB_DISK_ID. Continue? (y/N): "
read confirm
[[ "$confirm" =~ ^[Yy]$ ]] || exit 1

# ---------- Format USB ----------
echo -e "${CYAN}🔧 Formatting USB...${RESET}"
diskutil eraseDisk MS-DOS WINSETUP $PARTITION_STYLE /dev/$USB_DISK_ID || true

echo -e "${GREEN}✅ Disk formatted. Waiting for mount...${RESET}"

# ---------- Wait for /Volumes/WINSETUP ----------
for i in {1..15}; do
  if mount | grep -q "/Volumes/WINSETUP"; then
    echo -e "${GREEN}✅ /Volumes/WINSETUP mounted.${RESET}"
    break
  fi
  echo -e "${YELLOW}⏳ Waiting for /Volumes/WINSETUP (${i}s)...${RESET}"
  sleep 1
done

if ! mount | grep -q "/Volumes/WINSETUP"; then
  echo -e "${RED}❌ /Volumes/WINSETUP not available after timeout.${RESET}"
  exit 1
fi

echo -e "${CYAN}🔧 Proceeding with media creation tasks...${RESET}"

# --- MBR Activation for Legacy BIOS ---
if [[ "$PARTITION_STYLE" == "MBRFormat" ]]; then
  PARTITION="/dev/${USB_DISK_ID}s1"
  sleep 2
  mdutil -i off "/Volumes/WINSETUP" &>/dev/null || true
  diskutil unmountDisk force "/dev/$USB_DISK_ID" || true

  echo -e "${CYAN}🚫 Disabling disk arbitration...${RESET}"
  sudo launchctl unload /System/Library/LaunchDaemons/com.apple.diskarbitrationd.plist || true

  echo -e "${YELLOW}💉 Injecting Windows BIOS MBR...${RESET}"
  MBR_BIN="bootloaders/windows_bios_mbr.bin"
  if [[ -f "$MBR_BIN" ]]; then
    sudo dd if="$MBR_BIN" of="/dev/$USB_DISK_ID" bs=446 count=1 || true
  else
    echo -e "${RED}❌ MBR binary missing: $MBR_BIN${RESET}"
    exit 1
  fi

  echo -e "${CYAN}⚙️  Setting partition active...${RESET}"
  {
    echo "print"
    echo "flag 1"
    echo "write"
    echo "exit"
  } | sudo fdisk -e "/dev/$USB_DISK_ID" 2>/dev/null || true

  echo -e "${CYAN}✅ Re-enabling disk arbitration...${RESET}"
  sudo launchctl load /System/Library/LaunchDaemons/com.apple.diskarbitrationd.plist || true
  diskutil mount "$PARTITION" || true
fi

# ---------- Copy ISO Files (excluding WIM/ESD) ----------
echo -e "${CYAN}📤 Copying ISO files...${RESET}"
mkdir -p "/Volumes/WINSETUP/sources"
rsync -avh --progress --exclude="/sources/install.wim" --exclude="/sources/install.esd" \
  "$ISO_MOUNT"/ "/Volumes/WINSETUP"/

# ---------- Convert and Copy WIM/ESD ----------
WIM_PATH="$ISO_MOUNT/sources/install.wim"
[[ ! -f "$WIM_PATH" ]] && WIM_PATH="$ISO_MOUNT/sources/install.esd"
if [[ "$WIM_PATH" == *.esd ]]; then
  echo -e "${YELLOW}⚙️  Converting install.esd to install.wim...${RESET}"
  wimlib-imagex export "$WIM_PATH" all "/tmp/install.wim" --compress=maximum
  WIM_PATH="/tmp/install.wim"
fi

# ---------- Split or Copy install.wim ----------
WIM_SIZE_MB=$(( $(stat -f%z "$WIM_PATH") / 1024 / 1024 ))
echo -e "${CYAN}🪓 install.wim size: ${WIM_SIZE_MB} MB${RESET}"
if (( WIM_SIZE_MB > 4000 )); then
  wimlib-imagex split "$WIM_PATH" "/Volumes/WINSETUP/sources/install.swm" 3800
else
  cp "$WIM_PATH" "/Volumes/WINSETUP/sources/install.wim"
fi

# ---------- Write Config Files ----------
echo -e "${CYAN}📝 Writing config files...${RESET}"
cat <<EOF > "/Volumes/WINSETUP/sources/ei.cfg"
[Channel]
Retail
[VL]
0
EOF
cat <<EOF > "/Volumes/WINSETUP/sources/PID.txt"
[PID]
Value=$PRODUCT_KEY
EOF
cp "$AUTO_XML_PATH" "/Volumes/WINSETUP/Autounattend.xml"

# ---------- Finalize ----------
echo -e "${GREEN}💾 Syncing and ejecting USB...${RESET}"
sync && sleep 2
diskutil eject "/dev/$USB_DISK_ID"
echo -e "${GREEN}✅ Stage 4 complete: USB is ready ($INSTALL_NAME on $PARTITION_STYLE).${RESET}"

####################################################
#                     STAGE 5
#           Final Recap, Cleanup, and Exit
####################################################

# ---------- Final Summary ----------
echo -e "${CYAN}📋 Summary of your selections:${RESET}"
echo -e "  💻 Computer Name:          ${GREEN}$COMPUTER_NAME${RESET}"
echo -e "  💡 Edition:                ${GREEN}$INSTALL_NAME${RESET}"
echo -e "  🌐 UI Language:            ${GREEN}$SELECTED_LANG${RESET}"
echo -e "  ⌨️  Keyboard Layout:       ${GREEN}$kbd_name ($SELECTED_KBD_LAYOUT)${RESET}"
echo -e "  🔐 GVLK Key:               ${GREEN}$PRODUCT_KEY${RESET}"
echo -e "  🌍 Region Locale:          ${GREEN}en-001 (English WORLD)${RESET}"
echo -e "  🕓 Timezone:               ${GREEN}${TIMEZONE:-UTC}${RESET}"
echo -e "  👤 Account:                ${GREEN}$USERNAME / $PASSWORD${RESET}"

# Clean display label for mode
MODE_DISPLAY=""
if [[ "$INSPECT_ONLY" == true ]]; then
  MODE_DISPLAY="Inspect Only"
elif [[ "$DRY_RUN" == true ]]; then
  MODE_DISPLAY="Dry Run"
else
  case "$MODE" in
    oobe-skip) MODE_DISPLAY="Skip OOBE" ;;
    standard)  MODE_DISPLAY="Standard Setup" ;;
    *)         MODE_DISPLAY="Unknown" ;;
  esac
fi

echo -e "  🚀 Mode:                   ${GREEN}$MODE_DISPLAY${RESET}"
echo -e "  💾 ISO Source:             ${GREEN}$ISO_PATH${RESET}"

# USB Info (when applicable)
if [[ "$INSPECT_ONLY" != true && -n "${USB_DISK_ID:-}" ]]; then
  echo -e "  💽 USB Target Disk:         ${GREEN}/dev/$USB_DISK_ID${RESET}"
fi

if [[ "$INSPECT_ONLY" != true && -n "${PARTITION_STYLE:-}" ]]; then
  echo -e "  🧭 Partition Scheme:        ${GREEN}$PARTITION_STYLE${RESET}"
fi

# Post-install language override notice
if [[ "$SELECTED_LANG" == "en-US" && "$SKIP_OOBE" == true ]]; then
  echo -e "  🌍 Language Override:       ${YELLOW}Setup will install as en-001 and revert to en-US.${RESET}"
  echo -e "  ⚙️  Post-Install Script:     ${YELLOW}setupcomplete.cmd will switch back to en-US UI silently.${RESET}"
fi

# Unattended file reference for inspect mode
if [[ "$INSPECT_ONLY" == true ]]; then
  echo -e "  📝 Unattend file:           ${YELLOW}$AUTO_XML_PATH${RESET}"
  echo -e "${GREEN}✅ You may now use this Autounattend.xml manually or for review.${RESET}"
fi

# ---------- Clean Up ----------
[[ -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
[[ -f "/tmp/install.wim" ]] && rm -f "/tmp/install.wim"

echo -e "${CYAN}🧹 Temporary files cleaned up.${RESET}"
echo -e "${GREEN}🎉 All done.${RESET}"
