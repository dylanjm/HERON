#!/bin/bash
SCRIPT_DIRNAME=`dirname $0`
SCRIPT_DIR=`(cd $SCRIPT_DIRNAME; pwd)`
source $SCRIPT_DIR/../../scripts/establish_conda_env.sh --quiet --load
RAVEN_LIBS_PATH=`conda env list | awk -v rln="$RAVEN_LIBS_NAME" '$0 ~ rln {print $NF}'`
BUILD_DIR=${BUILD_DIR:=$RAVEN_LIBS_PATH/build}
INSTALL_DIR=${INSTALL_DIR:=$RAVEN_LIBS_PATH}
PYTHON_CMD=${PYTHON_CMD:=python}
JOBS=${JOBS:=1}
mkdir -p $BUILD_DIR
mkdir -p $INSTALL_DIR
DOWNLOADER='curl -C - -L -O '

ORIGPYTHONPATH="$PYTHONPATH"

update_python_path ()
{
    if ls -d $INSTALL_DIR/lib/python*
    then
        export PYTHONPATH=`ls -d $INSTALL_DIR/lib/python*/site-packages/`:"$ORIGPYTHONPATH"
    fi
}

update_python_path
PATH=$INSTALL_DIR/bin:$PATH

if which coverage
then
    echo coverage already available, skipping building it.
else
    if curl http://www.energy.gov > /dev/null
    then
       echo Successfully got data from the internet
    else
       echo Could not connect to internet
    fi

    cd $BUILD_DIR
    #SHA256=56e448f051a201c5ebbaa86a5efd0ca90d327204d8b059ab25ad0f35fbfd79f1
    $DOWNLOADER https://files.pythonhosted.org/packages/ef/05/31553dc038667012853d0a248b57987d8d70b2d67ea885605f87bcb1baba/coverage-7.5.4.tar.gz
    tar -xvzf coverage-7.5.4.tar.gz
    cd coverage-7.5.4
    (unset CC CXX; $PYTHON_CMD setup.py install --prefix=$INSTALL_DIR)
fi

update_python_path

cd $SCRIPT_DIR

#coverage help run
SRC_DIR=`(cd src && pwd)`

# get display var
DISPLAY_VAR=`(echo $DISPLAY)`
# reset it
export DISPLAY=

SOURCE_DIRS=($SRC_DIR,$SRC_DIR/../templates/)
OMIT_FILES=($SRC_DIR/dispatch/twin_pyomo_test.py,$SRC_DIR/dispatch/twin_pyomo_test_rte.py,$SRC_DIR/dispatch/twin_pyomo_limited_ramp.py)
EXTRA="--rcfile=$SRC_DIR/../tests/.coveragerc --source=${SOURCE_DIRS[@]} --omit=${OMIT_FILES[@]} --parallel-mode "
export COVERAGE_FILE=`pwd`/.coverage

coverage erase --rcfile="$SRC_DIR/../tests/.coveragerc"
($SRC_DIR/../../../run_tests "$@" --re=HERON --python-command="coverage run $EXTRA " || echo run_test done but some tests failed)

#get DISPLAY BACK
DISPLAY=$DISPLAY_VAR

## Go to the final directory and generate the html documents
cd $SCRIPT_DIR/tests/
pwd
rm -f .cov_dirs
for FILE in `find . -name '.coverage.*'`; do dirname $FILE; done | sort | uniq > .cov_dirs
coverage combine `cat .cov_dirs`
coverage html

