#!/bin/sh

##############
# Partition with existing Users folder and data
#
# 2016-09-22
#
# Frank Wolf 
#
# This script will resize the Macintosh HD volume and create a Users Partition and
# whle preserving user data.
#
##############

# Run disk repair to ensure proper partitioning

#diskutil repairVolume 'Macintosh HD'

#Determine if drive is CoreStorage

isCStore=$(diskutil info 'Macintosh HD' | grep 'LV UUID' | awk '{print $3}')

echo $isCStore

	if [ -z "$isCStore" ]; then
		
		############################
		## Convert to CoreStorage
		############################
		
		diskutil cs convert 'Macintosh HD'
		
		fi
	
		############################
		## Resize CoreStorage Volume
		############################
		
		## set variables
		
		# Get LV UUID to resize Macintosh HD
		
		logVolume=$(diskutil info 'Macintosh HD' | grep 'LV UUID' | awk '{print $3}')
		echo $logVolume
		
		# Get Size and Freespace for CoreStorage Volume

		echo "getting sizes"

		csFreeSpace=$(diskutil info 'Macintosh HD' | grep 'Volume Free Space' | awk '{print $4}')
		
		echo $csFreeSpace
		
		csTotalSize=$(diskutil info 'Macintosh HD' | grep 'Total Size' | awk '{print $3}')

		echo $csTotalSize
		
		# Process free space size to ensure space requirements for volumes
		csPosPart=$( echo $csFreeSpace-100 | bc)
		csPosPart=$( echo ${csPosPart%.*} )

		echo $csPosPart
		
		# check if difference is greater than 100 gigabytes.
		if [ $csPosPart -lt 100 ]; then
				
				echo "Available space too small for system volume."
				echo "Confirm space requirements"
				echo "Exiting workflow."
				exit 1
				
				else
				
				#continue with resizing and Users volume creation
				
				echo "Renaming Macintosh HD to Users"
				
				diskutil renameVolume 'Macintosh HD' Users
				
				gSize=g
				
				echo "Resizing Macintosh HD and creating Users Volume"
		
						diskutil cs resizeVolume Users $csPosPart$gSize
		
						# Create New CoreStorage Volume Macintosh HD
		
						logVolumeGroup=$(diskutil info Users | grep 'LVG UUID' | awk '{print $3}')
						echo $logVolumeGroup
		
						diskutil cs createVolume $logVolumeGroup jhfs+ 'Macintosh HD' 100g
						
			fi
			
		###############################
		## Prep the new Users partition
		###############################
		
		#### Clean up /Users partition

	if [ -d /Volumes/Users/Users ]; then
	
		echo “Cleaning up Users Partition”
		
		##### delete old System folders and files
		cd /Volumes/Users/ 
		find * -maxdepth 0 -name 'Users' -prune -o -exec rm -rf '{}' ';'
		rm -r /Volumes/Users/System
		
		echo “Moving user data into place”

		##### move folders to appropriate path
		mv /Volumes/Users/Users/* /Volumes/Users/ 
		
		##### delete the old Users folder
		rm -rf /Volumes/Users/Users 
		
		##### Add user folder icon to Users partition	
		#cp /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/UsersFolderIcon.icns /Volumes/Users/.VolumeIcon.icns 
		
		##### Set permissions
		chown root:admin /Volumes/Users 
		chmod 755 /Volumes/Users
		chgrp -R wheel /Volumes/Users/Shared 
		
		else
			echo "Partitioning failed. Check data integrity"
			exit 1
		fi
		

 