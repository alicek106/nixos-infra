{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/sda"; # Samsung SSD 850 EVO 500GB
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          type = "EF00";
          size = "512M";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = [ "-f" ];
            subvolumes = {
              "/root" = {
                mountpoint = "/";
                mountOptions = [ "compress=zstd" "noatime" ];
              };
              "/nix" = {
                mountpoint = "/nix";
                mountOptions = [ "compress=zstd" "noatime" ];
              };
              "/home" = {
                mountpoint = "/home";
                mountOptions = [ "compress=zstd" "noatime" ];
              };
              "/var" = {
                mountpoint = "/var";
                mountOptions = [ "compress=zstd" "noatime" ];
              };
              # VM disk images. A separate top-level subvolume, so snapshots of /var
              # don't include them and they can be snapshotted on their own (for backup).
              # Copy-on-write is turned off for this directory below (tmpfiles "+C").
              "/vm-images" = {
                mountpoint = "/var/lib/libvirt/images";
                mountOptions = [ "noatime" ];
              };
            };
          };
        };
      };
    };
  };

  # nodatacow (+C) for VM images. A VM disk is one huge file that gets small random
  # writes in the middle; with copy-on-write every write moves the block elsewhere,
  # so the file ends up in thousands of fragments.
  # +C only affects files created after it is set, so it must be on the empty directory
  # before any image is created. Trade-off: no btrfs checksums/compression for these files.
  systemd.tmpfiles.rules = [ "h /var/lib/libvirt/images - - - - +C" ];
}
