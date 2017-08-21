branch="master"

cd ../
TOP_DIR=`pwd`
BSP_NAME_DEFAULT=`basename $TOP_DIR`
BSP_NAME=""
BRANCH="master"
MBP_SCRIPTS_URL="git://pek-lpdfs01.wrs.com/managed_builds/Pulsar/MBP/New/mbp-scripts.git"
SMARTPM_SECURE_URL="git://pek-lpdfs01.wrs.com/managed_builds/Pulsar/SRC/Pulsar8/meta-smartpm-secure"
ima_fsk_passphrase=""
rpm_gpg_passphrase=""

usage() {
    echo >&2 "usage: ${0##*/} [-b <#branch> ] [-n <#bsp-name>] [-h] [?] "
    echo >&2 "   -b specifies the branch name."
    echo >&2 "   -n specifies the bsp name."
    echo >&2 "   -i specifies the IMA FSK user key passphrase."
    echo >&2 "   -r specifies the RPM GPG user key passphrase."
    echo >&2 "   -h Print this help menu"
    echo >&2 "   ?  Print this help menu"
}

while getopts "b:n:i:r:?h" FLAG; do
    case $FLAG in
        b)      BRANCH=$OPTARG;;
        n)      BSP_NAME=$OPTARG;;
        i)      ima_fsk_passphrase=$OPTARG;;
        r)      rpm_gpg_passphrase=$OPTARG;;
        h)      usage;;
        \?)     usage;;
    esac
done

shift $((OPTIND - 1))


function prepare_create_git()
{
    if [ X"$BSP_NAME" != X"$BSP_NAME_DEFAULT" ]; then
        echo "Create the whole MBP in $BSP_NAME directory!"
        if [ -d $BSP_NAME ]; then
            echo "$BSP_NAME directory exist!"
            mv $BSP_NAME $BSP_NAME.bak
        else
            echo "Create the new $BSP_NAME"
            mkdir $BSP_NAME
        fi
    fi
    cd $TOP_DIR/mbp
    MBP_URL="`git remote get-url origin`"
    cd $TOP_DIR/$BSP_NAME
    git clone $MBP_URL
}

function clone_extern_git()
{
    echo "clone_extern_git"
    #git clone ../mbp
    #git clone --bare git://pek-lpdfs01.wrs.com/managed_builds/Pulsar/MBP/New/mbp-scripts.git scripts
}

function create_default_conf_link()
{
    cd $TOP_DIR/mbp
    git clone $MBP_SCRIPTS_URL scripts
    if [ -f scripts/conf/default.conf.$BSP_NAME ]; then
        if [ ! -f conf/default.conf ]; then
            if [ ! -d conf ]; then
                mkdir conf
            fi
            ln -sf ../scripts/conf/default.conf.$BSP_NAME conf/default.conf
            rm -fr scripts
        else
            echo "SKIP: conf/default.conf link exist!" && return 0
        fi
        if [ ! -L conf/default.conf ]; then
            echo "ERROR: Link the default.conf.$BSP_NAME to default.conf Failure!"  && exit 1
        fi
        git add conf
        git add conf/default.conf
    else
        echo "ERROR: Could not find the valid scripts/default.conf.$BSP_NAME file, Exiting" && exit 2
    fi
}

function create_user_keys_passphrase()
{
    cd $TOP_DIR/mbp
    git clone $MBP_SCRIPTS_URL scripts
    if [ -f conf/default.conf ]; then
	ENCRYPTO_FLAG=`grep ENCRYPTO_FLAG conf/default.conf | awk -F= '{print $2}'`
    fi
    if [ X"$ENCRYPTO_FLAG" == X"1" ]; then
	echo "[Note]: mbp will create the user keys pass phrase!"
        if [ ! -f conf/UK-PS ]; then
	    if [ X"$ima_fsk_passphrase" == X"" ]; then
                while true; do
                    echo -e "\033[31m"
                    read -p " [Note]: Do you wish to create the IMA File SIGN KEY passphrase or Sample, S|s/pass phrase?" fsk
                    case $fsk in
                        [Ss]) echo -e "\033[31m [NOTE]: Use the default Sample Key!\033[0m";
	            	  echo SIGNING_MODEL = \"sample\" > conf/UK-PS;
	            	  echo RPM_FSK_PASSWORD = \"password\" >> conf/UK-PS;
                          echo RPM_GPG_PASSPHRASE = \"SecureCore\" >> conf/UK-PS;
	            	  break;;
                        *   ) echo -e "\033[31m [NOTE]: Use key Pass Phrase is $fsk !!\033[0m";
	            	  echo SIGNING_MODEL = \"user\" > conf/UK-PS;
	            	  echo RPM_FSK_PASSWORD = \"$fsk\" >> conf/UK-PS;
	            	  if [ X"$rpm_gpg_passphrase" == X"" ]
                              read -p " [Note]: Do you wish to create the RPM GPG KEY passphrase?" gpgk
                              echo RPM_GPG_PASSPHRASE = \"$gpgk\" >> conf/UK-PS;
	            	  else
                              echo RPM_GPG_PASSPHRASE = \"$rpm_gpg_passphrase\" >> conf/UK-PS;
	                  fi
	            	  break;;
                    esac
                    echo -e "\033[0m"
                done
	    else
		echo SIGNING_MODEL = \"user\" > conf/UK-PS;
	        echo RPM_FSK_PASSWORD = \"$ima_fsk_passphrase\" >> conf/UK-PS;
	        if [ X"$rpm_gpg_passphrase" == X"" ]
                    echo -e "\033[31m"
                    read -p " [Note]: Do you wish to create the RPM GPG KEY passphrase?" gpgk
                    echo RPM_GPG_PASSPHRASE = \"$gpgk\" >> conf/UK-PS;
                    echo -e "\033[0m"
	        else
                    echo RPM_GPG_PASSPHRASE = \"$rpm_gpg_passphrase\" >> conf/UK-PS;
	        fi

	    fi
        else
            echo "[Note]: The UK-PS file has been created!" 
        fi
    fi
    if [ -f conf/UK-PS ];then
        git add conf/UK-PS
    else
	if [ X"$ENCRYPTO_FLAG" == X"1" ]; then
            echo "[Error]: There is no UK-PS file for the Secure Encrypto Feature!!"
	    exit 1
	else
	    echo "[Note]: This BSP is not support the Secure Encrypto Feature!!"
	fi
    fi
    rm -fr scripts
}

function bare_git_create ()
{
    cd $TOP_DIR
    for each in buildhistory deploy sstate-cache tmp prdb downloads src ; do
        git init --bare $each
        git --git-dir=$each config core.sharedRepository all
        find "$each" -type d -print0 | xargs -0 chmod g+ws
        #git commit -s -m "pulsar: $BSP_NAME $each Initial Commit"
    done
}

bare_git_init_create ()
{
    cd $TOP_DIR
    for each in buildhistory deploy sstate-cache tmp prdb downloads src ; do
        echo "git clone $each $each.tmp"
        git clone $each $each.tmp
        cd $each.tmp
        touch .empty && git add .empty
        git commit -s -m "pulsar: $BSP_NAME $each Initial Commit"
        git push origin master
        git log
        cd ..
        rm -fr $each.tmp
    done
}

submodule_git()
{
    cd $TOP_DIR/mbp
    git remote set-url origin $PWD
    git submodule init
    for each in buildhistory deploy sstate-cache tmp prdb downloads src; do
       if [ ! -e $each/.git ]; then
           git submodule add ../$each
       fi
       rm -fr $each
    done
    #echo "sed -i 's/$BSP_NAME\///g' .gitmodules"
    #sed -i "s/${BSP_NAME}\///g" .gitmodules
    #cat .gitmodules
    git submodule add $MBP_SCRIPTS_URL scripts
    rm -fr scripts
    #P9 will not support smartpm, so remove this layer from mbp
    #git submodule add $SMARTPM_SECURE_URL meta-smartpm-secure
    #rm -fr meta-smartpm-secure
}

if [ X"$BSP_NAME" != X"" -a X"$BSP_NAME" != X"$BSP_NAME_DEFAULT" ];then
    prepare_create_git
    cd $TOP_DIR/$BSP_NAME
    TOP_DIR=`pwd`
fi

if [ X"$BSP_NAME" == X"" ]; then
    BSP_NAME=$BSP_NAME_DEFAULT
fi

#clone_extern_git
bare_git_create
bare_git_init_create

submodule_git
create_default_conf_link
create_user_keys_passphrase
cd $TOP_DIR/mbp
git add .gitmodules

git commit -s -m "mbp: $BSP_NAME submodules Initial Commit"

cd ..
git clone --bare mbp
