#!/bin/sh

##############
# Resize partitions script
#
# 2016-09-22
#
# Frank Wolf 
#
# This script will resize the Macintosh HD partition by re-allocating free space from the Users partition.
# Only Macintosh HD partitions using CoreStorage is supported at this time.
#
##############


###########
# Begin defining Functions
###########

# The following functions will gather information about the amount of Free Space 
# is avaialble on the Users Partion and the Total Size or Space for resizing
# operations.

get_free_11() {

			
		csVol=$(diskutil info 'Users' | grep 'Volume Free Space' | awk '{print$4}')
		echo "10.11 or 10.10 Users Free Space is "$csVol
		
		psVol=$( echo ${csVol%.*})
		echo $psvol
		
		tsVol=$(diskutil info 'Users' | grep 'Total Size' | awk '{print$3}')
		echo "Total User Space is "$tsVol
		
		tsVol=$( echo ${tsVol%.*})
		echo $tsVol
		 
		}


get_free_12() {

			
		csVol=$(diskutil info 'Users' | grep 'Volume Available Space' | awk '{print$4}')
		
		echo "CS vOL is "$csVol
		
		# Convert CS free space to integer or drop decimal place

		psVol=$( echo ${csVol%.*})
		
		#Get Users Partition Total Space
		
		tsVol=$(diskutil info 'Users' | grep 'Volume Total Space' | awk '{print$4}')
		
		echo "Total User Space is "$tsVol
		
		# Convert CS free space to integer or drop decimal place

		tsVol=$( echo ${tsVol%.*}) 
		
		
		}
		
		

		
###########
# End Functions
###########	

# Find out if Users is a Partition or discreet Volume

notPart=$(diskutil info 'Users' | grep 'Part of Whole' | awk '{print $4}')

echo $notPart

if [ $notPart != disk0 ]; then

			osascript <<-EOF

				tell application "Finder"
					activate
    				display dialog "The Users Partition is a Physical Hard Drive and cannot be used for expansion or the Users partition does not exist."	
				end tell
			
			EOF

	echo "Not Partition"


			exit 0
fi


# Get OS to determine correct diskutil options

	majver=$(defaults read /System/Library/CoreServices/SystemVersion.plist ProductVersion | awk -F '.' '{print $2}')
	
		echo "Installed MacOS is 10."$majver""


# Detrmine if Volume is resizeable 

	isCStore=$(diskutil info 'Macintosh HD' | grep 'LV UUID' | awk '{print $3}')

	echo $isCStore
		
	if [ -n "$isCStore" ]; then
	
# Get free space on the Users partion

			case "$majver" in 
				"10") get_free_11
				;;
				"11") get_free_11
				;;
				"12") get_free_12
				;;
			esac
			
			
			if [ $psVol -lt 10 ]; then
			
			osascript <<-EOF

				tell application "Finder"
					activate
    				display dialog "There is not enough free space to expand Macintosh HD."
				end tell
			
			EOF
			
			exit 0
			
			fi
			

# Ask for how much space in Gigabytes is needed

			plusSize=$(osascript <<-EOF
			
				tell application "Finder"
				activate
   					set theText to display dialog "There is "& $psVol &" GB available for expansion."& return & "How many Gigabytes would you like to use?"& return & return & " Enter 0 to quit."default answer ""
				end tell
				text returned of theText
			EOF)

			if [ $plusSize = 0 ]; then
			
			osascript <<-EOF

				tell application "Finder"
					activate
    				display dialog "Expand operation cancelled."
				end tell
			
			EOF

			logger "Expand operation cancelled by user."
			
			exit 0
			
			fi

# Do the math to determine new size of Users partition

			newPart=$(( ($tsVol - $plusSize) - 1 ))

# Give user more info about what is going to happen.

			osascript <<-EOF

				tell application "Finder"
					activate
    				set theResp to display dialog "The Macintosh HD and Users partitions will be resized."& return & return &"The Finder will reload so it is advised to close all other windows or applications."& return & return & "Click OK to continue."
				end tell
			
			if button returned of theResp is "Cancel" then
				return 1
			end if
			EOF
			
			if [ "$?" != "0" ]; then
			
						osascript <<-EOF

				tell application "Finder"
					activate
    				display dialog "Expand operation cancelled."
				end tell
			
			EOF
			
			logger "User cancelled operation."
			
			exit 0
			
			
			fi
			
			

# Do the partitioning

	# Get info
	# The disk identifier of the Users partition (ie. disk0s4) is needed for the resize command
	# The Logical Volume Group Unique Identifier (LVG UUID) is gathered for the addDisk command
	# The Macintosh HD partition Logical Volume Unique Identifier is needed for the resize command to expand to new size
	
			udiskDev=$(diskutil info 'Users' | grep "Device Identifier:" | awk '{print $3}')
	
			macLVG=$(diskutil info 'Macintosh HD' | grep 'LVG UUID' | awk '{print $3}')
	
			macLV=$(diskutil info 'Macintosh HD' | grep "LV UUID" | awk '{print$3}')
	
	# Slice off Untitled from Users as non-CoreStorage partition
	
			diskutil resizeVolume $udiskDev "${newPart}"G JHFS+ Untitled 0b
	
	# Next add Untitled  partition to the CoreStorage Logical Volume Group (LVG) as a phyiscal disk
	# This converts the partiton to CoreStorage
	
	# Get the Device name of the Untitled partition (ie. disk0s5)
	# We couldn't get the Device name until it was created by the resizeVolume command above
	
			unDevName=$(diskutil info 'Untitled' | grep 'Device Identifier:' | awk '{print $3}')
	
	# Add to the Logical Volume Group
	
			diskutil cs addDisk $macLVG $unDevName
	
	# Get old Size of Macintosh HD
	
			case "$majver" in 
				"10") oldSize=$(diskutil info 'Macintosh HD' | grep 'Total Size' | awk '{print$3}')
				;;
				"11") goldSize=$(diskutil info 'Macintosh HD' | grep 'Total Size' | awk '{print$3}')
				;;
				"12") oldSize=$(diskutil info 'Macintosh HD' | grep 'Volume Total Space' | awk '{print$4}')
				;;
			esac
			
			echo $oldSize
			
			chSize=$( echo ${oldSize%.*})
			
			echo $chSize
			
			echo $plusSize
	
	# Get new size for Macintosh HD
	
			newSize=$(( $chSize + $plusSize ))
			
			echo $newSize
	
	# Expand Macintosh HD
	
			#diskutil cs resizeVolume $macLV "${newSize}"g
			diskutil cs resizeVolume $macLV 0g

# Reload Finder

			open /System/Library/CoreServices/Finder.app


# Let the user know it's complete 

			osascript <<-MES

				tell application "Finder"
					activate
    				set theText to display dialog "Macintosh HD expansion complete."& return & "It is adviseable to restart your computer now."
				end tell
			
			MES
			
		exit 0
	
	else			# Notify users if it's not resizeable
			osascript <<-EOF

				tell application "Finder"
					activate
    				display dialog "Macintosh HD is not expandable."& return & "Please contact IT support for further options."
				end tell
			
			EOF
		
			logger "Macintosh HD is not expandable"
		
			exit 1

	fi