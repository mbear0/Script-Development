#!/bin/bash
#This script creates a bootable disk from a valid image

diskutil list

Echo ‘Please input the path ,/dev/diskN, that will be imaged’
read disk

Echo $disk
Echo ‘Please input the path to the image you wish to burn to this disk’

read img

Echo ‘Please be patient this will take awhile, as long as the cursor is flashing image is in progress’

Diskutil unmount $disk

Sudo dd if=$img of=$disk bs=1m

Diskutil eject $disk