branch="master"

cd ../
TOP_DIR=`pwd`
BSP_NAME=`basename $TOP_DIR`
MBP_SCRIPTS_URL="git://pek-lpdfs01.wrs.com/managed_builds/Pulsar/MBP/New/mbp-scripts.git"

function clone_extern_git()
{
    #git clone ../mbp
    git clone --bare /git/managed_builds/Pulsar/SRC/Pulsar8/meta-smartpm-secure meta-smartpm-secure 
    #git clone --bare git://pek-lpdfs01.wrs.com/managed_builds/Pulsar/MBP/New/mbp-scripts.git scripts
}

function create_default_conf_link()
{
    git clone scripts scripts.tmp
    cd scripts.tmp
    if [ -f conf/default.conf.$BSP_NAME ]; then
        cd conf
        if [ -f default.conf ]; then
            rm -f default.conf
        fi
        ln -sf default.conf.$BSP_NAME default.conf
        if [ ! -f default.conf ]; then
            echo "ERROR: Link the default.conf.$BSP_NAME to default.conf Failure!"  && exit 1
        fi
        git add default.conf
        git commit -s -m "mbp: $BSP_NAME submodules Initial Commit"
        git push
        cd ..
        rm -fr scripts.tmp
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
    cd mbp
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
create_default_conf_link
bare_git_create
bare_git_init_create

cd mbp
submodule_git
git add .gitmodules

git commit -s -m "mbp: $BSP_NAME submodules Initial Commit"

cd ..
git clone --bare mbp
