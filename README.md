# EFI-Agent
Simple, low resource, efficient and no frills tool to mount EFI partitions.

# Features:
* Shows EFI disks to mount / unmount and open in Finder
* Shows disk icons and color-coded partition scheme
* Shows boot EFI partition (uses IODeviceTree:/chosen/boot-device-path if IODeviceTree:/options/efi-boot-device is unavailable)
* Shows link for APFS containers to physical store and vice versa
* Shows device name if media name is not available
* Mount / unmount, eject and open context menu for partition scheme table
* Tools to delete APFS container or converting HFS to APFS
* Shows notifications on disk actions
* Percentage bars show space used on mounted partitions
* Drag the position of the splitter to adjust the table views
* Launch at Login option

![Screenshot 1](https://github.com/headkaze/EFI-Agent/blob/master/EFIAgent01.png?raw=true)![Screenshot 2](https://github.com/headkaze/EFI-Agent/blob/master/EFIAgent02.png?raw=true)
