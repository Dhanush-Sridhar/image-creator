# change Log 
---
## 08.09.2024 --Dhanush Sridhar

### 1. Created change log file 

### 2. creation of cache for rootfs for faster build 
-  the previous method in the image creator script. checks only if rootfs exits or not based on /etc/os-release file 
    This is a problem as it does not check for the rootfs of  machine type againts the settings in build.conf
    Hence it could lead to building an image with machine type .
- to avoid this cahce machanisem is impleamted. create dedicated directory for rootfs cache based on machine type values from      build.conf
- as a result we can acchibve faster build time.
### 2. varible added in  build.conf "ROOTFS_BASE_CACHE_PATH" 
- ROOTFS_BASE_CACHE_PATH: contains the base rootfs with kernal installtion 


### 3. new directory for config file 
- build and image config files are stored under the path scripts/config for better destintion 

### 4. added new variable for `$MACHINE` for which the image is built 
- a new variable in build.conf called MACHINE is added to distinguish based on the 
    maschine type for which image is build.
- the `$MACHINE `takes only specific values "nplus","nprohd" and "pure"
---
## 10.09.2024 -- Dhanush Sridhar

### 1. changes to images for other machine type 
- added MACHINE varible in build.conf # 
- sub directoris for under files/system/etc/NetworkManager/system-connections for 
    each machine type (nplus, nprohd , pure).
- changes in the image-creator for the same.

### 2. `apt -y upgrade`
- in image creator added step to upgrade apt packages to latest 


### 3. added breakPoint function

- To help debug added a helper function called `breakPoint`
- called anywhee in the script will execute the script till that line 
 and pauses and excepts a user user input to continue 

 ### 4. usermanagment before installing package

 - while installing application packages it is required to own the folder where the application is installed by the 
    image user polar.


## 19.09.2024 -- Dhanush Sridhar

### 1. added `KERNEL_PKG` variable as part of image.conf file
- can choose repstice kernal package as per the image configration for a prticular machine type 


### 2. addtional live os distor 
- to spcify the distrubtion of the live os an adtional variable is addeed 
- since copying from the base image for ubuntu version focal is buggy promts user to choose the grun install device 

### 3. changed the format of the `INSTALLER_BINARY` name 
- to avoid unncessary pile up of binary for each build even 
- since copying from the base image for ubuntu version focal is buggy promts user to choose the grun install device 


## 20.09.2024 -- Dhanush Sridhar 

### 1. added TUI backgroud color code based on macine type 

- to better identify the TUI menu backgorud of the installer, is color coded
- green for nplus, red for npro and blue backgorund for pure. 


