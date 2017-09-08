#!/bin/sh


##############
# New Mac Partitioning
#
# 2016-09-22
#
# Frank Wolf 
# This script will partition a Single Macintosh HD volume into two partitions to separate System and Users data.
# 
#
##############

echo "New Mac Deploy Prod V4 !!!"

###########
#
# Begin defining Functions
#
#############


get_free_11() {

			
		csVol=$(diskutil info 'Macintosh HD' | grep 'Volume Free Space' | awk '{print$4}')
		
		echo "CS vOL is "$csVol
		
		# Convert CS free space to integer or drop decimal place

		psVol=$( echo ${csVol%.*} )
		}


get_free_12() {

			
		csVol=$(diskutil info 'Macintosh HD' | grep 'Volume Available Space' | awk '{print$4}')
		
		echo "CS vOL is "$csVol
		
		# Convert CS free space to integer or drop decimal place

		psVol=$( echo ${csVol%.*} )
		}


partition_10() {

		# CoreStorage partitioning for 10.10.x and previous
		
		diskutil cs resizeVolume $logVolume 150g
		
		# Create New CoreStorage Volume
		
		logVolumeGroup=$(diskutil info 'Macintosh HD' | grep 'LVG UUID' | awk '{print $3}')
		echo $logVolumeGroup
		echo "Creating Users Partition"
		
		diskutil cs createVolume $logVolumeGroup jhfs+ Users 100%
		}

partition_11() {

			# 10.11 El Cap broken - New CoreStorage partition command
			
			echo "Creating Users Partition"
		
			diskutil cs resizeStack $logVolume 150g JHFS+ Users 0
			}

###########
#
# End Functions
#
#############


###########
#
# Main Script
#
#############


# Determine OS of DP Key

	majver=$(defaults read /System/Library/CoreServices/SystemVersion.plist ProductVersion | awk -F'.' '{print $2}')
	
		echo "DP KEY OS is 10."$majver""

#Determine if drive is CoreStorage

	echo "Determining if drive is CoreStorage"

	isCStore=$(diskutil info 'Macintosh HD' | grep 'LV UUID' | awk '{print $3}')

		echo $isCStore
		
	# Get Logical Volume UUID
	
	logVolume=$(diskutil info 'Macintosh HD' | grep 'LV UUID' | awk '{print $3}')
	
		echo $logVolume

	if [ -n "$isCStore" ]; then
		# Get Available space
		case "$majver" in 
			"10") get_free_11
			;;
			"11") get_free_11
			;;
			"12") get_free_12
			;;
		esac

		echo "Free Space is is "$psVol

		# Perform sanity check so we know we have enough free space
		if [[ $psVol -lt 200 ]]; then

			echo "Available space too small for system partition"
				exit 1
			else
			
			case "$majver" in 
				"10") partition_11
				;;
				"11") partition_11
				;;
				"12") partition_12
				;;
			esac
		fi

	else
		
# Non Core Storage functions
	
		# 1. get device identifier

			diskDev=$(diskutil info 'Macintosh HD' | grep "Device Identifier:" | awk '{ print $3 }')

		# 2. get minimum size

			driveMin=$(diskutil resizeVolume $diskDev limits | grep 'Minimum' | awk '{ print $3 }')

			driveMax=$(diskutil resizeVolume $diskDev limits | grep 'Maximum' | awk '{ print $3 }')

			posPart=$( echo $driveMax-$driveMin | bc )

			posPart=$( echo ${posPart%.*} )

			echo $posPart

		# Create Users Partiton
				# Perform sanity check so we know we have enough free space
				if [ $posPart -lt 200 ]; then

						echo "Available space too small for system partition"
						exit 1
				else
						# Resize Macintosh HD to drivePart size, format and name new partition using
						# all available space
						# command verb device size numberofpartitions 
						echo "Creating Users Partion"
						diskutil resizeVolume $diskDev 150G JHFS+ Users 0b
				fi


	fi
	
# Set permissions
	chown root:admin /Volumes/Users
	chgrp -R wheel /Volumes/Users/Shared
	chmod 755 /Volumes/Users
	
exit 0