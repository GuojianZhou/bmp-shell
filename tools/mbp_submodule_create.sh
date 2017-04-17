branch="master"

cd ../
TOP_DIR=`pwd`
BSP_NAME=`basename $TOP_DIR`
BRANCH="master"
MBP_SCRIPTS_URL="git://pek-lpdfs01.wrs.com/managed_builds/Pulsar/MBP/New/mbp-scripts.git"

usage() {
    echo >&2 "usage: ${0##*/} [-b <#branch> ] [-n <#bsp-name>] [-h] [?] "
    echo >&2 "   -b specifies the branch name."
    echo >&2 "   -n specifies the bsp name."
    echo >&2 "   -h Print this help menu"
    echo >&2 "   ?  Print this help menu"
}

while getopts "b:n:?h" FLAG; do
    case $FLAG in
        b)      BRANCH=$OPTARG;;
        n)      BSP_NAME=$OPTARG;;
        h)      usage;;
        \?)     usage;;
    esac
done

shift $((OPTIND - 1))

function clone_extern_git()
{
    #git clone ../mbp
    git clone --bare /git/managed_builds/Pulsar/SRC/Pulsar8/meta-smartpm-secure meta-smartpm-secure 
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
            ln -sf scripts/conf/default.conf.$BSP_NAME conf/default.conf
        else
            echo "SKIP: conf/default.conf link exist!" && return 0
        fi
        if [ ! -f conf/default.conf ]; then
            echo "ERROR: Link the default.conf.$BSP_NAME to default.conf Failure!"  && exit 1
        fi
        git add conf
        git add conf/default.conf
    else
        echo "ERROR: Could not find the valid scripts/default.conf.$BSP_NAME file, Exiting" && exit 2
    fi
}

function bare_git_create ()
{
    cd $TOP_DIR
    for each in buildhistory deploy sstate-cache tmp prdb downloads src ; do
        git init --bare $each
        git --git-dir=$each config core.sharedRepository all
        find "$each" -type d -print0 | xargs -0 chmod g+ws
        git commit -s -m "pulsar: $BSP_NAME $each Initial Commit"
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
    git submodule init --bare
    for each in buildhistory deploy sstate-cache tmp prdb downloads src meta-smartpm-secure; do
       if [ ! -e $each/.git ]; then
           git submodule add ../$each
       fi
       rm -fr $each
    done
    git submodule add $MBP_SCRIPTS_URL scripts
}

clone_extern_git
bare_git_create
bare_git_init_create

submodule_git
create_default_conf_link
cd $TOP_DIR/mbp
git add .gitmodules

git commit -s -m "mbp: $BSP_NAME submodules Initial Commit"

cd ..
git clone --bare mbp
