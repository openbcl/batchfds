#!/bin/bash

VERSION=1.0.0
PID=$$

# Parse and print BatchFDS, FDS and MPI version
echo BATCH Fire Dynamics Simulator
echo Version: $VERSION
echo
showVersionFDS=()
for param in "$@"
do
    if [[ $param == +([[:digit:]]) ]]; then
        showVersionFDS+=(1)
    else
        showVersionFDS+=($param)
    fi
    
done
${showVersionFDS[@]} 2>&1 | while read line ;
do
    if [[ $line =~ [0-9]+:[0-9]+|FDS[0-9]+|[Vv]ersion ]]; then
        echo $line
        if [[ $line =~ [Cc]ompilation ]]; then
            echo
        fi
    fi
done
echo

# Reset failed tasks from potential pre-runs
resetPreRuns() {
    find . -type f -name "*.$1" | while read line ;
    do
        taskID=$(basename "$line" .$1)
        outfolder="$(dirname "$line")"
        exitcode=$(<"$line")
        if [[ $1 == "running" ]] || [[ $1 == "exitcode" ]] && [[ $exitcode != 0 ]]; then
            inputfile="$outfolder/$outfolder.fds"
            if [[ -f "$inputfile" ]]; then
                mv "$inputfile" "./$outfolder.fds"
                rm -rf "$outfolder"
            fi
        fi
        rm -f "$outfolder/$taskID.running" "$outfolder/$taskID.exitcode"
    done
}
resetPreRuns "exitcode"
resetPreRuns "running"

# Calculate remaining tasks and init TASKS_COMPLETED
shopt -s nullglob
COMPLETEDInputFiles=(**/*.fds)
remainingInputfiles=(*.fds)
shopt -u nullglob
TASKS_COMPLETED=${#COMPLETEDInputFiles[@]}
TASKS_REMAINING=${#remainingInputfiles[@]}
TASKS_ALL=$(( TASKS_COMPLETED + TASKS_REMAINING ))
echo "TASKS COMPLETED: $TASKS_COMPLETED, TASKS TOTAL: $TASKS_ALL, PROGESS: $(( $TASKS_COMPLETED * 100 / $TASKS_ALL ))%"
echo
if (( $TASKS_REMAINING == 0 )); then
    echo "No tasks were found."
    exit
fi

# Get cores of node (potentially with hyperthreading cores)
NODE_CORES=$(nproc --all)

# Calculate cores of node (without hyperthreading cores)
cpuSmtActiveFile=/sys/devices/system/cpu/smt/active
if [[ -f "$cpuSmtActiveFile" ]]; then
    if (($(<$cpuSmtActiveFile) == 1)); then
        NODE_CORES=$((NODE_CORES / 2))
    fi
fi

# Set NODE_CORES to prefered limited value (depending on env MAX_THREADS)
if [[ -v MAX_THREADS ]] && (( $MAX_THREADS < $NODE_CORES )); then
    NODE_CORES=$MAX_THREADS
fi

# Extract threads from input params
THREADS=1
for (( i=1; i<=$#; i++))
do
    param="${!i}"
    if [[ $param == +([[:digit:]]) ]]; then
        THREADS=$param
    fi
done

# Move FDS-Inputfile to sub directory and run task
runTask() {
    if (( $TASKS_COMPLETED < $TASKS_ALL )); then
        shopt -s nullglob
        inputfiles=(*.fds)
        shopt -u nullglob
        if ((${#inputfiles[@]} > 0)); then
            inputfile="${inputfiles[0]}"
            outfolder=$(basename "$inputfile" .fds)
            mkdir "$outfolder"
            mv "$inputfile" "$outfolder/$inputfile"
            commands=()
            for (( i=$#; i>0; i--))
            do
                param="${!i//$(pwd)/$(pwd)/$outfolder}"
                commands[$i-1]="$param"
            done
            commands[$#]="$inputfile"
            cd "$outfolder"
            echo Running task "(${outfolder}_${PID})": "${commands[@]}"
            ( ( touch "${outfolder}_${PID}.running"; "${commands[@]}" > "${outfolder}_${PID}.out" 2> "${outfolder}_${PID}.err"; echo $? > "${outfolder}_${PID}.exitcode" ) & )
            cd ..
        fi
    fi
}

# Init BUSY_CORES
BUSY_CORES=0

# Run new Tasks as long as resources are available
while (($BUSY_CORES == 0)) || (($BUSY_CORES + $THREADS <= $NODE_CORES)) ;
do
    runTask $@
    BUSY_CORES=$((BUSY_CORES + THREADS))
done

# Repeat as long as tasks are running (*.running files found recursively)
while :
do
    # Repeat as long as completed tasks are found (*.exitcode files found recursively)
    while read -r line;
    do
        # Remove *.exitcode and *.running files, print progress to console and run next task
        taskID=$(basename "$line" .exitcode)
        outfolder="$(dirname "$line")"
        rm "$outfolder/$taskID.running"
        exitcode=$(<"$line")
        if [[ $exitcode != 0 ]]; then
            echo Failed task "($taskID)" with exitcode $exitcode
        else
            echo Completed task "($taskID)" successfully.
            rm "$outfolder/$taskID.exitcode"
        fi
        echo
        echo "TASKS COMPLETED: $((++TASKS_COMPLETED)), TASKS TOTAL: $TASKS_ALL, PROGESS: $(( $TASKS_COMPLETED * 100 / $TASKS_ALL ))%"
        echo
        runTask $@
        sleep 1
    done < <(find . -type f -name "*.exitcode")
    sleep 5
    if find . -type f -name "*.running" -exec false {} +; then
        exit 0
    fi
done