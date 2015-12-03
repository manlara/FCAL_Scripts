# FCAL Perl scripts
> With Great Power Comes Great Responsibility!!

### JInventory:
Thomas Jefferson National Accelerator Facility maintains a MySQL database called JInventory that holds data about hardware components. The database can be conveniently online and off-site. The database has a "Maintenance History" field which can be used to make notes about an entry or keep track of changes. The Forward Calorimeter group at IU has decided to also use this history field to store gain constants related to photomultiplier tubes (PMT). These constants are specially delimited by "#>", as opposed to the normal ">". **The JInventory database is the production database that is actively used by the lab while SP_JInventory is a test database that can be used to test scripts.**

### MySQL configuration
To be able to run these scripts you must have a .my.cnf file in the same directory as the Perl script. Take the demo.my.cnf file rename it to .my.cnf and change the username and password to your own. In this .my.cnf file the database name is overwritten by the Perl scripts database variable. **Please note** the database variable used in the Perl script will overwrite the database variable in the .my.cnf file so make sure the database variable in the Perl script is correct **before executing the script!**

### An important note about coordinate systems:
The FCAL has a two distinct coordinate systems, each applied for different operations, which can make things confusing. For hardware related maintenance the center of the FCAL is taken to be the origin, the positive z-axis follows the photon beam downstream, and the coordinate system is right-handed, i.e, when looking at the FCAL from downstream to upstream up is +y and to the right is +x. When I refer to x and y in this document I mean this coordinate system.

#### The following scripts can be used to interface with the JInventory database:
* calc_voltage.pl
* upload_pmt_gains.pl


## calc_voltage.pl:
#### Purpose:
The purpose of this script is to generate a BURT file of **updated** high-voltages for each FCAL channel. A new high-voltage is calculated for each PMT using the following equation:

Vf = V0 g^(1/B) (1)

where V0 is the initial PMT high-voltage used to determine the gain, g is the gain, and B is a PMT dependent constant. The constant B was determined by placing a PMT in a dark box with an known LED light source. The light output of the PMT was measured as a function of PMT threshold and fit with the equation: A t^(1/B), where t is the threshold. 

#### Requirements 
This script requires the following files:

* A BURT file of each channels high-voltage used in the gain calibration
  * At the top of the BURT file is some header information, see headerBURT.txt
  * The BURT file contains the EPICS name of each channel, an enable channel flag, and the high-voltage, i.e, FCAL:hv:X:Y:v0set 1 hv)
* A file of gain constants tab separated by x, y and the gain, i.e, x y gain. 

Lines 47, and 48 of the Perl script define the required file names. Change these as needed.

#### How to use
1. Be sure to modify lines 47 and 48 in the Perl script to correctly define the name of the required input files
2. Be sure to modify line 49 with your jlab username followed by your first and last name in parentheses
3. Execute the script
4. The resulting BURT file will be named newVoltages.snap, modify line 50 to change the output filename


## upload_pmt_gains.pl:
#### Purpose:


#### Requirements 


#### How to use

