# BatchFDS
This script allows batch processing of FDS simulations on a single computer.
All simulations must have the same number of meshes.
The execution of FDS is done by MPI.

## Installation (Linux)
1. Download the file [src/BatchFDS.sh](src/BatchFDS.sh) or clone this repository.
2. Move the file to a filesystem path of your choice.
To be able to call the script from any working directory, the script directory should be listed in the PATH environment variable.
It's recommended to copy the script to the path `/usr/bin`:
```bash
# Copy the file
sudo cp src/BatchFDS.sh /usr/bin/
# Make the file executable
sudo chmod +x /usr/bin/BatchFDS.sh
```

## Usage
*FDS must already be installed on your system.*
1. Put all your FDS input files in a common directory.
2. Navigate to the directory (e.g. `cd samples`)
3. Run the script and pass the standard commands to start a FDS simulation (but without the inputfilename).
```bash
# If you use FDS in a version older than 6.7.8, you have to set the environment variable OMP_NUM_THREADS to 1 before.
export OMP_NUM_THREADS=1

# Info: Please replace "-n <nr of meshes>" with with the actual number of your meshes, e.g. "-n 3"
BatchFDS.sh mpiexec -n <nr of meshes> fds
```


## Computation
* Depending on your configuration (e.g. CPU cores, number of meshes), the script will automatically decide how many simulations to start.
* The script automatically detects whether your system has hyperthreading enabled or not.
If your system consists of 8 physical and 8 hyperthreading CPU cores, it will automatically choose a maximum limit of 8 threads.
* If the simulations have two meshes, the script will start 4 simulations simultaneously in this case.
As soon as a simulation is started, it is moved to a subfolder that derives its name from the input file name.
After one of the running simulations is finished, the next one is started automatically until all simulations are finished.

If you do not want to provide all available processor cores for simulations, you can define an environment variable before executing the script, which limits the available CPU cores.
```bash
# Setting limit to 4 CPU cores
export MAX_THREADS=4
# Unset limit
unset MAX_THREADS
```

## Interrupt script / computer crash
If the script is interrupted accidentally or intentionally, it can be restarted with the same command described above.
Simulations that have already been completed will not be restarted.
Simulations that are not completed successfully are automatically restarted.
Thus, you will only lose the progress of the most recently run, unfinished simulations.
