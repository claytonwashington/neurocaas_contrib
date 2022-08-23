#!/bin/bash
set -e
userhome="/home/ubuntu"
datastore="deepgraphpose/data"
outstore="ncapdata/localout"

echo "----DOWNLOADING DATA----"
source activate DEEPLABCUT
neurocaas-contrib workflow get-data -f 
neurocaas-contrib workflow get-config -f

datapath=$(neurocaas-contrib workflow get-datapath)
datadir="$(dirname $datapath)"
configpath=$(neurocaas-contrib workflow get-configpath)
resultpath=$(neurocaas-contrib workflow get-resultpath-tmp)
taskname=$(neurocaas-contrib scripting parse-zip -z "$datapath")
echo "----DATA DOWNLOADED: $datapath. PARSING PARAMETERS.----"

mode=$(neurocaas-contrib scripting read-yaml -p $configpath -f mode -d predict)
debug=$(neurocaas-contrib scripting read-yaml -p $configpath -f testing -d False)
windows=$(neurocaas-contrib scripting read-yaml -p $configpath -f windows -d False)

echo "----RUNNING ANALYSIS IN MODE: $mode----"
#TODO cd "$userhome/deepgraphpose"

if [ $mode == "train" ]
then
    source deactivate DEEPLABCUT	
    source activate pickleenv
    python "$userhome/neurocaas_contrib/dlc/convert_h5.py" "$datadir/$taskname"	
    source deactivate pickleenv
    source activate DEEPLABCUT
    if [ $debug == "True" ]
    then
        echo "----STARTING TRAINING; SETTING UP DEBUG NETWORK----"
	python "$userhome/neurocaas_contrib/dlc/train_dlc2.py" --config-file "$datadir/$taskname/config.yaml" --test --windows $windows
        #TODO python "demo/run_dgp_demo.py" --dlcpath "$userhome/$datadir/$taskname/" --test
    elif [ $debug == "False" ]    
    then 	
        echo "----STARTING TRAINING; SETTING UP NETWORK----"
	python "$userhome/neurocaas_contrib/dlc/train_dlc2.py" --config-file "$datadir/$taskname/config.yaml" --windows $windows
        #TODO python "demo/run_dgp_demo.py" --dlcpath "$userhome/$datadir/$taskname/"
    else    
        echo "Debug setting $debug not recognized. Valid options are "True" or "False". Exiting."	
        exit
    fi    
    echo "----PREPARING RESULTS----"
    zip -r "/home/ubuntu/results_$taskname.zip" "$datadir/$taskname/"
elif [ $mode == "predict" ]    
then
    if [ $debug == "True" ]
    then
        echo "----STARTING PREDICTION; SETTING UP DEBUG NETWORK----"
	python "$userhome/neurocaas_contrib/dlc/predict_dlc2.py" --config-file "$datadir/$taskname/config.yaml" --test
        #TODO python "demo/predict_dgp_demo.py" --dlcpath "$userhome/$datadir/$taskname/" --test
    elif [ $debug == "False" ]    
    then 	
        echo "----STARTING PREDICTION; SETTING UP NETWORK ----"
	python "$userhome/neurocaas_contrib/dlc/predict_dlc2.py" --config-file "$datadir/$taskname/config.yaml" 
        #TODO python "demo/predict_dgp_demo.py" --dlcpath "$userhome/$datadir/$taskname/"
    else    
        echo "Debug setting $debug not recognized. Valid options are "True" or "False". Exiting."	
        exit
    fi    
    echo "----PREPARING RESULTS----"
    zip -r "/home/ubuntu/results_$taskname.zip" "$datadir/$taskname/videos/"
else    
    echo "Mode setting $mode not recognized. Valid options are "predict" or "train". Exiting."
fi

echo "----UPLOADING RESULTS----"
neurocaas-contrib workflow put-result -r "/home/ubuntu/results_$taskname.zip"  
