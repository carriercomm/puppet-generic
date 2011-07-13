# Author: Kumina bv <support@kumina.nl>

# Class: gen_kvm
#
# Actions:
#	Set up qemu-kvm
#
# Depends:
#	gen_puppet
#
class gen_kvm {
	# Against our policy we use a define from an other gen class here, but we'd have to do other icky stuff if we didn't
	if $lsbmajdistrelease < 6 {
		gen_apt::preference { "qemu-kvm":; }
	}

	kpackage { "qemu-kvm":; }
}
