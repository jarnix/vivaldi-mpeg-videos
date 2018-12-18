#!/bin/bash

#-----------------------------------------------------------------------------
#
# Installs special libffmpeg.so for Vivaldi on Debian and some other distries
#
# Author:    GwenDragon <dev@gwendragon.de>, <https://gwendragon.de/>
# License:   OpenSource, GPL3
# Date:      2018-10-07
# Version:   1.2.12
# Source:    https://gwendragon.de/repo/linux/vivaldi/vivaldi-libffmpeg-install.sh
#
# Thanks to: Ruarí Ødegaard <https://gist.github.com/ruario>
#            Ike Devolder <http://herecura.eu/>
#            Lamarca <https://twitter.com/lamarca_>
#            Otscho <https://forum.vivaldi.net/user/otscho>
#            and others
#
#-----------------------------------------------------------------------------
#
#  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#  !!!                                                                     !!!
#  !!!              NO WARRANTY!                                           !!!
#  !!!                                                                     !!!
#  !!!       SCRIPT MAY MISBEHAVE AND EXPLODE YOUR LINUX INSTALLATION      !!!
#  !!!                                                                     !!!
#  !!!              NO WARRANTY!                                           !!!
#  !!!                                                                     !!!
#  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#
#
#-----------------------------------------------------------------------------

DATE='2018-10-07 16:18 CEST';
VERSION="1.2.12 (build $DATE)";

SUPPORT="SUPPORT

  Please report problems of this program to Gwen, ask in her blog at <https://labs.gwendragon.de/blog/>
  or at <https://forum.vivaldi.net/category/35/vivaldi-browser-for-linux>

";

THANKS="THANKS TO

  - Ruarí Ødegaard <https://gist.github.com/ruario>
  - Ike Devolder <http://herecura.eu/>
  - Lamarca <https://twitter.com/lamarca_>
  - Otscho <https://forum.vivaldi.net/user/otscho>
  - Harald 
  - and many other Vivaldi users
  - Vivaldi Technologies <https://vivaldi.com/>

";

CRONJOB=0 ;
DEBUG=0 ;
QUIET=0 ;
FORCE=0 ;
USERLOCAL=0 ;
SNAPSHOT=0 ;
INVESTIGATE=0 ;
INSTALL_DIR="";

#-----------------------------------------------------------------------------

### Show Help
function help {
    echo -e "
vivaldi-ffmpeg-install v.${VERSION}

Installs appropriate libffmpeg.so codec library for Vivaldi installation.

USAGE
  vivaldi-ffmpeg-install [-?hViqdIfSucX]

PARAMETERS
  -?  this Help
  -h  this Help
  -V  Show version
  -i  Destination path for installation
  -q  Quiet mode
  -d  Debug mode
  -I  Investigate mode
  -f  Force install
  -S  Install for Snapshot
  -u  Install for current user
  -c  Install a daily cron job
  -X  EXPERIMENTAL feature

OPTIONS

  Quiet (-q)
    Runs without any messages.
    Nice to use in other scripts or with cron.

  Debug (-d)
    Is more verbose and shows information whats going on while updating.
    Good if problems happen.

  Force (-f)
    Installs over existing libffmpeg.so
  
  Destination path for installation (-i)
    Set a destination path for libffmpeg codec if different Vivaldi installation targets are used.
    You need write permission install to the destination dir.
    
	Example to install the libffmpeg into /home/dev/daily/vivaldi-snapshot dir:
    
      \e[1m\e[93m./\e[0mvivaldi-libffmpeg-install.sh -i \"/home/dev/daily/vivaldi-snapshot\"
	      
    After this install ended you can inspect which libffmpeg are installed for Vivaldi by calling the Investigate mode:
    
      sudo \e[1m\e[93m./\e[0mvivaldi-libffmpeg-install.sh -I    

  Install for Snapshot (-S)
    Install for the Vivaldi SNAPSHOT

  Install for current user (-u)
    Install for the current user in $HOME/.local/lib/vivaldi/
    Will overwrite any existing libffmpeg.so there!
    Do no 'Install for current user' for Stable and Snapshot at the same time as this will overwrite the local libffmpeg.so.
    Such action may cause problems in Stable or Snapshot.

  Install daily cron job for codecs update (-c)
    - Add a user cron job in crontab
    - Add a cron job in /etc/cron.daily/ for daily update check of new libffmpeg.so.
      Needs root rights for adding cron job!
      
      Default is a update of codecs for Vivaldi STABLE.
      If a cron job is needed for Snapshot use -S switch.

  Investigate mode (-I)
    Scan for existing libffmpeg.so, shows the filename with version and exits.
    For debugging purposes and bugreports to GwenDragon.


==============================================================================

  \e[1;91m
  !!!! EXPERIMENTAL !!!!
  !!!! these features may cause damage !!!! 
  \e[0m
  
  * Show codecs in online repo for Stable or Snapshot
    To enable use switch:
      -Xrepo    shows package for Stable
      -Xrepo -S shows package for Snapshot

  * Remove codecs and cronjobs installed by vivaldi-ffmpeg-install
    To enable use switch:
      -XDeLeTeMe    removes for Stable
      -XDeLeTeMe -S removes for Snapshot
      -XDeLeTeMe -u removes for local user

==============================================================================

${SUPPORT}    

==============================================================================

$THANKS
";

    exit 0;
}

function show_version { echo "${VERSION}"; exit 0; }
function error { echo -e "\e[1;91m"ERROR:"\e[0m" "\e[1;93m""$1""\e[0m" >&2; } 
function debugmsg { if [ "${DEBUG}" == 1 ] ; then echo -e "\e[93m"DEBUG:"\e[0m" "$1" >&2; fi } 
function msg { if [[ "$0" =~ cron ]] ; then true; elif [ "${QUIET}" == 0 ] ; then echo "$1"; fi }

function yesno {
    local MSG=${1:-"Do you want to continue?"};
    local YN="";
    read -p "$MSG [y/N]: " YN ;
    case "$YN" in
        [Yy]*)  : ;;
        [Nn]*)  msg "Exiting.";
                exit ;;
            *)  msg 'Answer not recognised, assuming "No". Exiting.';
                exit ;;
    esac;
}

### Send a notification with the installed notify program
function send_notify {
  local MSG="$1";
  local TITLE=$(basename "$0") update completed;

  if [ $UID = 0 ] ; then return; fi # if called from sudo no notify for root
  
  if [ -z $DISPLAY ] ; then 		# fix if no Display Manager is running
    msg "$MSG";
    return;
  fi

  if [ -x "$(which notify-send)" ] ; then
    debugmsg "Send notify with $(which notify-send)";
    $(which notify-send) -t 5000 "$TITLE" "$MSG";
  # elif [ -x "$(which zenity)" ] ; then
  #   debugmsg "Send notify with $(which zenity)";
  #   echo "message:$MSG" | $(which zenity) --notification --listen ;
  elif [ -x "$(which kdialog)" ] ; then
    debugmsg "Send notify with $(which kdialog)";
    $(which kdialog) --title="$TITLE" --passivepopup "$MSG" 5 ;
  elif [ -x "$(which xmessage)" ] ; then
    debugmsg "Send notify with $(which xmessage)";
    $(which xmessage) -center "$MSG";
  fi
}

### Cleanp before exiting script
function cleanup {
    debugmsg "Cleanup is done now.";
    if [ -d "$TMPDIR" ] ; then rm -fr "$TMPDIR"; fi
}
trap cleanup EXIT
###

function install_as_cronjob {
    if [ "$UID" != "0" ] ; then
        local TMPCRON=$(tempfile);
        crontab -u $USER -l > "${TMPCRON}";

        local CRON_FOUND=$(grep "$(basename $0)" "${TMPCRON}");
        if [ ! -z "${CRON_FOUND}" ] ; then
            msg "cron job already in crontab";
            debugmsg "${CRON_FOUND}";
            yesno "Do you want to update crontab entry?";
        fi

        local CRONENTRY;
        local SELF=$(readlink -f "$0");
        if [ "$SNAPSHOT" = 1 ] ; then
            CRONENTRY="0 */3 * * * export DISPLAY=:0 && /bin/bash ${SELF} -quS";
        else
            CRONENTRY="0 */3 * * * export DISPLAY=:0 && /bin/bash ${SELF} -qu";
        fi

        local CRONTAB;
        if [ ! -z "${CRON_FOUND}" ] ; then
            CRONTAB=$(grep -v "$(basename $0)" "${TMPCRON}" | grep -v '^#$');
            echo "${CRONTAB}" > "${TMPCRON}";
        fi
        echo "${CRONENTRY}" >> "${TMPCRON}";
        echo "#" >> "${TMPCRON}";

        CRONTAB=$(cat "${TMPCRON}");
        debugmsg "------------ new crontab ---------------------";
        debugmsg "${CRONTAB}";
        debugmsg "----------------------------------------------";

        crontab -u $USER "${TMPCRON}";
        msg "Cron job added to crontab of user '$USER'";

        rm -f "${TMPCRON}";
    else
        if [ -d /etc/cron.daily/ ] ; then
            cp -f "$0" /etc/cron.daily/vivaldi-libffmpeg-install ;
            chmod 0755 /etc/cron.daily/vivaldi-libffmpeg-install ;
            msg "Cron job set for vivaldi-libffmpeg-install in /etc/cron.daily/";

            # Install cron job for Snapshot
            if [ "${SNAPSHOT}" = "1" ] ; then
                cp -f "$0" /etc/cron.daily/vivaldi-snapshot-libffmpeg-install ;
                chmod 0755 /etc/cron.daily/vivaldi-snapshot-libffmpeg-install ;
                msg "Cron job set for vivaldi-snapshot-libffmpeg-install in /etc/cron.daily/";
            fi ;
        fi ;
    fi ;

    exit 0;
}

function vivaldi_version {
  local path=$1;
  local ver="";
  if [ -f $path/vivaldi-bin ] ; then
    ver=$(strings $path/vivaldi-bin | \
      egrep '^1\.1[0-9]*\.[0-9]+\.[0-9]+$'); # old version is 1.xx.yyyy.zz
    if [ -z "$ver" ] ; then 
        ver=$($path/vivaldi-bin --version | cut -d" " -f2)         
    fi
    echo $ver
  fi
}

function vivaldi_chrome_version {
  local path=$1;
  local ver="";
  if [ -f $path/vivaldi-bin ] ; then
    ver=$(strings $path/vivaldi-bin | \
      egrep '^[67][0-9]\.[0]\.[0-9]+\.[0-9]+$'); # version is 6x.0.yyyy.zz and newer
  fi
  echo $ver
}

function search_vivaldi_bin {
    local path=$1;
    path=$(dirname "$path");

    while [ ! $path = "/" ] ; do
        debugmsg "search vivaldi-bin: $path";
        if [ -x $path/vivaldi-bin ] ; then
            debugmsg "vivaldi-bin FOUND: $path/vivaldi-bin";
            echo $path;
            return 1;
        fi ;
        path=$(readlink -f $path/..);
    done ;
}

function investigate {
    if [ "${INVESTIGATE}" = "1" ] ; then
        debugmsg "Scanning for existing libffmpeg.so";

        local VV;
        local CV;
        local VP;
        local FOUNDFFMPEG=$(find / -name libffmpeg.so 2>/dev/null);
        if [ ! -z "${FOUNDFFMPEG}" ] ; then
            echo -e "\nFound different libffmpeg.so on system:\n";

            for i in $FOUNDFFMPEG ; do
                if [[ $i =~ '/root/' ]] ; then
                    # SKIP root's folder";
                    VV="";
                    CV="";
                elif [[ $i =~ '.local/lib/vivaldi/' ]] ; then
                    VV="????";
                    CV="";
                elif [[ $i =~ 'vivaldi-snapshot' ]] ; then
                    VP=$(search_vivaldi_bin $i);
                    VV=$(vivaldi_version "$VP");
                    CV=$(vivaldi_chrome_version "$VP");
                elif [[ $i =~ 'vivaldi' ]] ; then
                    VP=$(search_vivaldi_bin $i);
                    VV=$(vivaldi_version "$VP");
                    CV=$(vivaldi_chrome_version "$VP");
                else
                    VV="";
                    CV="";
                fi

                echo -n "Vivaldi $VV";
                if [ ! -z "$CV" ]; then echo -ne "\tChromium/$CV"; fi

                echo -ne "\n\t$i - version ";
                grep -aom1 'FFmpeg version N-[0-9]\+-' $i | cut -f2 -d-;

                if [ -r $(dirname "$i")/chromium-codecs-ffmpeg-extra-version.txt ] ; then
                    echo -ne "\tfrom chromium-codecs-ffmpeg-extra ";
                    cat $(dirname "$i")/chromium-codecs-ffmpeg-extra-version.txt | sed -e 's/INSTALLED_VERSION=//';
                fi

                echo "";
 
            done ;

        fi ;

        debugmsg "Scanning for existing user cron job in crontab";
        local FOUNDCRONS=$(crontab -u $USER -l 2>/dev/null| grep "$(basename $0)");
        echo "-----------------------------------------------";
        echo "";
        if [ ! -z "$FOUNDCRONS" ] ; then
            echo "Found cron job for user '$USER':";
            echo "$FOUNDCRONS";
        else
            echo "No user cron job found.";
        fi
        echo "";

        debugmsg "Scanning for existing other cron jobs in folders /etc/cron*";
        FOUNDCRONS=$(find /etc/cron*/ -name "vivaldi*libffmpeg-install" 2>/dev/null);
        if [ ! -z "$FOUNDCRONS" ] ; then
            echo "Found other cron job:";
            echo "$FOUNDCRONS";
        else
            echo "No other cron job found.";
        fi
        echo "";

    fi ;

    exit 0;
}

function is_debian_alike {
    local OS=$(grep "^ID=" /usr/lib/os-release | sed -r "s/ID=//") ;
    local OS_LIKE=$(grep "^ID_LIKE=" /usr/lib/os-release | sed -r "s/ID_LIKE=//");

    if [[ "${OS_LIKE}" =~ debian ]] || [[ "$OS" =~ debian ]]; then
        return 1;
    else
        return 0;
    fi
}

function experimental {
    echo -e "\e[1;91m";
    echo "*******************************";
    echo "******    EXPERIMENTAL    *****";
    echo "*******************************"
    echo -e "\e[0m";

    debugmsg "EXPERIMENTAL started with switch: $EXPERIMENTAL";

    if [[ $EXPERIMENTAL =~ DeLeTeMe ]] ; then
        echo "This will delete libffmpeg.so codecs and cronjobs installed by previous runs of vivaldi-ffmpeg-install.";
        yesno "Do you wish to continue anyway?";
        if [ "$USERLOCAL" = "1" ] ; then
            debugmsg "Checking for user $USER at ${INSTALL_DIR}/";
            if [ -d $INSTALL_DIR/ ] ; then
                files=($(ls ${INSTALL_DIR}/));
                debugmsg "${#files[@]} files in ${INSTALL_DIR}/";
                if [ ! ${#files[@]} = 0 ] ; then
                    rm -i ${INSTALL_DIR}/*;
                fi ;
            else
                debugmsg "User $USER has no ${INSTALL_DIR}/";
            fi

            debugmsg "Reading crontab for user $USER"
            local TMPCRON=$(tempfile);
            crontab -u $USER -l | grep -v "$(basename $0)" > "${TMPCRON}";
            debugmsg "Generating new crontab for user $USER"
            echo "------------ new crontab ---------------------";
            cat "${TMPCRON}"
            echo "----------------------------------------------";
            local YN=N;
            read -p "Update contab now? [y/N]: " YN ;
            if [ "$YN" = "y" ] || [ "$YN" = "Y" ] ; then
            crontab -u $USER "${TMPCRON}";
            echo "Crontab changed."
            else
            debugmsg "Crontab left unchanged"
            fi
        else
            debugmsg "Checking for ${INSTALL_DIR}/";
            if [ -f ${INSTALL_DIR}/libffmpeg.so ] ; then
                debugmsg "Deleting program related libffmpeg.so files in ${INSTALL_DIR}/";
                rm -i ${INSTALL_DIR}/libffmpeg.so;
                rm -i ${INSTALL_DIR}/chromium-codecs-ffmpeg-extra-version.txt;
                debugmsg "Deleting program related cron job /etc/cron.daily/${VIVALDI_CHANNEL}";
                if [ -f /etc/cron.daily/${VIVALDI_CHANNEL}-libffmpeg-install ] ; then
                    rm -i /etc/cron.daily/${VIVALDI_CHANNEL}-libffmpeg-install;
                fi ;
            else
                debugmsg "No libffmpeg found for ${INSTALL_DIR}/";
            fi ;
        fi ;
        echo "";
        echo "Please recheck with "$(basename $0)" -I"
    elif [[ $EXPERIMENTAL =~ repo ]] ; then
        echo "Found codec package on ";
        if [ "$SNAPSHOT" == "1" ] ; then
            echo "Chromium Beta PPA repo for ${VIVALDI_CHANNEL}";
            debugmsg "Searching in online Chromium Beta PPA repo at $REPO";
            # Use a PPA with Chromium beta as source for libffmpeg
			REPO=http://ppa.launchpad.net/chromium-team/beta/ubuntu/pool/main/c/chromium-browser/
			# hack did not catch correct older version 
			wget -qO- $REPO | sed -rn "s/.*(chromium-codecs-ffmpeg-extra_([0-9]+\.){3}[0-9]+-[0-9]ubuntu[0-9]\.16\.04\.[1-9]_$DEB_ARCH.deb).+>.+>([0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]).+/\1  \3/p" | sort | tail -n 1;
        else
            echo "Ubuntu repo for ${VIVALDI_CHANNEL}";
            debugmsg "Searching in online Ubuntu repo at $REPO";
			wget -qO- $REPO | sed -rn "s/.*(chromium-codecs-ffmpeg-extra_([0-9]+\.){3}[0-9]+-[0-9]ubuntu[0-9]\.16\.04\.[1-9]_$DEB_ARCH.deb).+>.+>([0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]).+/\1  \3/p" | sort | tail -n 1;
        fi
    else # no valid switch
        help;
    fi

    exit;
}

##############################################################################
##############################################################################
##############################################################################

### test for commandline parematers
while getopts ?hVi:cqdfuISX: option ; do
    case "${option}" in
        \?) help; ;;
        h)  help; ;;
        V)  show_version; ;;
        c)  CRONJOB=1;  ;;
        q)  QUIET=1; ;;
        d)  DEBUG=1; ;;
        f)  FORCE=1; ;;
		i)  INSTALL_DIR=$OPTARG; ;; # set a different dest dir
        u)  USERLOCAL=1; ;;
        S)  SNAPSHOT=1; ;; # for Snapshot
        I)  INVESTIGATE=1; ;;
        X)  EXPERIMENTAL=$OPTARG; ;;
    esac ;
done ;

### Get architecture
case $(uname -m) in
  x86_64) ARCH=x86_64; DEB_ARCH=amd64; REPO=http://security.ubuntu.com/ubuntu/pool/universe/c/chromium-browser/ ;;
    i?86) ARCH=i386;   DEB_ARCH=i386;  REPO=http://security.ubuntu.com/ubuntu/pool/universe/c/chromium-browser/ ;;
    arm*) ARCH=arm;    DEB_ARCH=armhf; REPO=http://ports.ubuntu.com/ubuntu-ports/pool/universe/c/chromium-browser/ ;;
esac ;
debugmsg "Architecture is ${ARCH}";


#### check if script has 'snapshot' in filename
#  as two scripts can be used in cron!!!
#  one for Stable   : vivaldi-ffmpeg-install
#  one for Snapshot : vivaldi-snapshot-ffmpeg-install
SCRIPT_FOR_SNAPSHOT=$(basename "$0" | grep -i 'snapshot');
if [ ! -z "$SCRIPT_FOR_SNAPSHOT" ] ; then SNAPSHOT=1; fi


#### remember which Vivaldi channel to be installed
VIVALDI_CHANNEL=vivaldi;   # is the Stable by default
if [ "$SNAPSHOT" = "1" ] ; then VIVALDI_CHANNEL=vivaldi-snapshot; fi
debugmsg "Channel is ${VIVALDI_CHANNEL}";


#### Set location of Vivaldi installation
if [ "$USERLOCAL" = "0" ] ; then         # called as root?
    INSTALL_DIR="/opt/$VIVALDI_CHANNEL"; # then use correct install target 
elif [ "$USERLOCAL" = "1" ] && [ -z "${INSTALL_DIR}" ] ; then
    INSTALL_DIR=$HOME/.local/lib/vivaldi
fi


#### Get selected Vivaldi version
VIVALDI_VERSION=$(vivaldi_version "${INSTALL_DIR}");
VIVALDI_CHROME_VERSION=$(vivaldi_chrome_version "${INSTALL_DIR}");

#### Experimental mode
if [ ! -z "$EXPERIMENTAL" ] ; then experimental; fi

### Investigate installed libffmpeg and cron jobs
if [ "$INVESTIGATE" = "1" ] ; then investigate; fi

### Add cron job if wanted
if [ "$CRONJOB" = "1" ] ; then install_as_cronjob; fi

### Check for Linux distri
if [ ! is_debian_alike ] ; then
    msg "Sorry! You should not use this script on ${OS}. It is only for Debian or Ubuntu.";
    msg "Please go to <https://gist.github.com/ruario/bec42d156d30affef655> and read how to install libffmgeg.so from chromium-codecs-ffmpeg-extra on your OS";
fi

OS=$(grep "^ID=" /usr/lib/os-release | sed -r "s/ID=//");

### Dont use script on non-Debians!
if [[ "$OS" =~ (debian|devuan|bunsenlabs|linuxmint) ]] ; then
   debugmsg "Installing on ${OS}, a OS like Debian.";
else
    msg "You should not use this script on ${OS}, try to install codec package chromium-codecs-ffmpeg-extra or similar package on your OS.";

    if [ "$USERLOCAL" = "1" ] ; then # seems to be running from user's shell
        yesno "Do you wish to continue anyway?";
    else
        if [ "$FORCE" = "0" ] ; then # if not forced mode do not start a systemwide install on non-Debian OS!
            msg 'You can override this with switch -f for forced systemwide install or -u for user install.' ;
            exit;
        fi
    fi
fi

### Check if user wants to do things only root is allowed
if [ "$UID" != "0" ] && [ "$USERLOCAL" = "0" ] ; then
    error "You want to install into Vivaldi program folder as user?";
    error "Only root is allowed to do this!";
    error "If you want to install for user only you need switch -u";
    error "Please read help first (vivaldi-ffmpeg-install -h)";

    exit 1;
fi

### check if root like to install in .local
if [ "$UID" = "0" ] && [ "$USERLOCAL" = "1" ] ; then
    error "Do not run this script with parameter -u as root or via sudo.";
    error "Start it as normal user if you want to install for user only.";
    error "Please read help first (vivaldi-ffmpeg-install -h)";
    exit 1;
fi

### Check for installed needed progs
if [ ! -e $(which ar) ] ; then
    error "Missing program: ar ";
    error "Needed to extract downloaded files";
    exit 1;
fi

if [ "$SNAPSHOT" == "1" ] ; then
    debugmsg "Using Chromium Beta PPA repo $REPO for Vivaldi Snapshot";
    # Use a PPA with Chromium beta as source for libffmpeg
	REPO=http://ppa.launchpad.net/chromium-team/beta/ubuntu/pool/main/c/chromium-browser/
	UBUNTU_PACKAGE=$(wget -qO- $REPO | sed -rn "s/.*(chromium-codecs-ffmpeg-extra_([0-9]+\.){3}[0-9]+-[0-9]ubuntu[0-9]\.16\.04\.[1-9]_$DEB_ARCH.deb).*/\1/p" | sort | tail -n 1);	
else
    UBUNTU_PACKAGE=$(wget -qO- $REPO | sed -rn "s/.*(chromium-codecs-ffmpeg-extra_([0-9]+\.){3}[0-9]+-[0-9]ubuntu[0-9]\.16\.04\.[1-9]_$DEB_ARCH.deb).*/\1/p" | sort | tail -n 1);
fi

debugmsg "Fetching version of latest chromium-codecs-ffmpeg-extra from Ubuntu repo $REPO"
UBUNTU_VERSION=$(echo "${UBUNTU_PACKAGE}" | sed -rn "s/.*_(([0-9]+\.){3}[0-9]+)-.*/\1/p");
debugmsg "found chromium-codecs-ffmpeg-extra on Ubuntu repo $REPO - ${UBUNTU_PACKAGE} version ${UBUNTU_VERSION}";

if [ -z "$UBUNTU_VERSION" ] ; then
    error "Could not work out the latest version of chromium-codecs-ffmpeg-extra; exiting";
    exit 1;
fi

### check if install for user only
if [ "$USERLOCAL" = "1" ] ; then # check for user install
    if [ -r "${INSTALL_DIR}/chromium-codecs-ffmpeg-extra-version.txt" ] ; then
        . "${INSTALL_DIR}/chromium-codecs-ffmpeg-extra-version.txt";
        # Don't start if the same version is already installed
        if [ "$INSTALLED_VERSION" = "$UBUNTU_VERSION" ] ; then
            #send_notify "For ${VIVALDI_CHANNEL} the latest chromium-codecs-ffmpeg-extra ($UBUNTU_VERSION) is already installed for local user";
            msg "For ${VIVALDI_CHANNEL} the latest chromium-codecs-ffmpeg-extra ($UBUNTU_VERSION) is already installed for local user";
            if [ "$FORCE" != 1 ] ; then
                exit 0;
            else
                msg "For ${VIVALDI_CHANNEL} force install chromium-codecs-ffmpeg-extra ($UBUNTU_VERSION) over existing ($INSTALLED_VERSION) for local user";
            fi
        fi
    fi
else
### check install systemwide
    if [ -r "${INSTALL_DIR}/chromium-codecs-ffmpeg-extra-version.txt" ] ; then
        . "${INSTALL_DIR}/chromium-codecs-ffmpeg-extra-version.txt";
        if [ "$INSTALLED_VERSION" = "$UBUNTU_VERSION" ] ; then
            msg "For ${VIVALDI_CHANNEL} (${VIVALDI_VERSION}) the latest chromium-codecs-ffmpeg-extra ($UBUNTU_VERSION) is already installed";
            #send_notify "For ${VIVALDI_CHANNEL} (${VIVALDI_VERSION}) the latest chromium-codecs-ffmpeg-extra ($UBUNTU_VERSION) is already installed";
            if [ "$FORCE" != 1 ] ; then
                exit 0;
            else
                msg "For ${VIVALDI_CHANNEL} (${VIVALDI_VERSION}) forced install chromium-codecs-ffmpeg-extra ($UBUNTU_VERSION) over existing ($INSTALLED_VERSION)";
            fi
        fi
    fi
fi

#
set -e

### Create temporary dir
TMPDIR=/tmp/vivaldi-libffmpeg;
debugmsg "Creating temporary dir ${TMPDIR}";
mkdir -p "${TMPDIR}" || error "Cant create dir ${TMPDIR}";
cd "${TMPDIR}" || (error "Fail to change to dir ${TMPDIR}"; exit 255) ;

### Install from Ubuntu deb package (chromium-codecs-ffmpeg-extra)
#
# Fetch the deb package
debugmsg "Fetching package chromium-codecs-ffmpeg-extra from Ubuntu repo";
wget -nc -q "$REPO$UBUNTU_PACKAGE";

# Extract contents of chromium-codecs package
debugmsg "Extracting from package chromium-codecs-ffmpeg-extra"
( ar p ${UBUNTU_PACKAGE} data.tar.xz | tar xJf - ./usr/lib/chromium-browser/libffmpeg.so --strip 4 ) || ( error "Cant extract files from ${UBUNTU_PACKAGE}"; exit 1; );

# Check the libffmpeg.so dependencies are resolved
debugmsg "Checking extracted libffmpeg.so for unresolved dependencies"
if LANGUAGE=en ldd libffmpeg.so 2>&1 | grep -qm1 'not \(a dynamic executable\|found\)'; then 
  error "It is not possible to use this alternative libffmpeg on your system. 
Let us know via a post in our forums, mentioning your distro and distro version:
  https://forum.vivaldi.net/category/35/vivaldi-browser-for-linux
";
  exit 255
fi

# save new codec's version info
echo "INSTALLED_VERSION=$UBUNTU_VERSION" > chromium-codecs-ffmpeg-extra-version.txt;

# Install the files
debugmsg "Installing to ${INSTALL_DIR}/";
install -Dm644 libffmpeg.so "${INSTALL_DIR}/libffmpeg.so";
install -Dm644 chromium-codecs-ffmpeg-extra-version.txt "${INSTALL_DIR}/chromium-codecs-ffmpeg-extra-version.txt";

### Notify desktop user
send_notify "New libffmpeg.so was installed for ${VIVALDI_CHANNEL}\nchromium-codecs-ffmpeg-extra ${UBUNTU_VERSION}";

msg "
------------------------------------------------------------------------------

For ${VIVALDI_CHANNEL} (${VIVALDI_VERSION}) the chromium-codecs-ffmpeg-extra ($UBUNTU_VERSION) is installed:

  ${INSTALL_DIR}/libffmpeg.so
  ${INSTALL_DIR}/chromium-codecs-ffmpeg-extra-version.txt

Restart Vivaldi and test H.264/MP4 support via this page:

  http://www.quirksmode.org/html5/tests/video.html

------------------------------------------------------------------------------
";

### Cleanup temp dir
debugmsg "Remove of temporary dir";
rm -fr "${TMPDIR}";
