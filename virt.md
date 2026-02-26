DEPLOY=/tmp/qemuarm
VMDIR=/var/lib/libvirt/images

sudo cp "$DEPLOY/core-image-minimal-qemuarm.rootfs.ext4" "$VMDIR/qemuarm-core-image-minimal.ext4"

virt-install \
  --name qemuarm-core-image-minimal \
  --arch armv7l \
  --machine virt \
  --cpu cortex-a15 \
  --vcpus 4 \
  --memory 256 \
  --boot kernel="$DEPLOY/zImage",kernel_args="root=/dev/vda rw mem=256M ip=dhcp console=ttyAMA0 swiotlb=0" \
  --disk path="$VMDIR/qemuarm-core-image-minimal.ext4",format=raw,bus=virtio \
  --network bridge=br0-vlan100,model=virtio \
  --graphics none \
  --serial pty \
  --os-variant detect=off,require=off \
  --import \
  --noautoconsole

virsh console qemuarm-core-image-minimal
# Login: root (no password)
# Detach: Ctrl-]

virsh destroy qemuarm-core-image-minimal
virsh undefine qemuarm-core-image-minimal