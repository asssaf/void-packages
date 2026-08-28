#!/bin/bash

set -eux

: ${DEST_DIR:="hostdir/binpkgs"}
export XBPS_TARGET_ARCH="$1"

cat > /tmp/excludes <<EOF
usr/share/man
usr/share/doc
usr/share/info
var/db/xbps
EOF


function convert_package() {
	local PKG="$1"
	local VCE_INSTALLED="/usr/local/vce.installed/${PKG}"
	local PKG_DIR="$(mktemp -d)"

	if [ ! -e ${DEST_DIR}/${PKG}*.xbps ]
	then
		echo "Skipping ${PKG}"
		return 0
	fi
	zstdcat ${DEST_DIR}/${PKG}*.xbps | tar xv -C ${PKG_DIR}

	mkdir -p "${PKG_DIR}/${VCE_INSTALLED}"
	if [ -e "${PKG_DIR}/INSTALL" ]; then mv "${PKG_DIR}/INSTALL" "${PKG_DIR}/${VCE_INSTALLED}/"; fi
	if [ -e "${PKG_DIR}/REMOVE" ]; then mv "${PKG_DIR}/REMOVE" "${PKG_DIR}/${VCE_INSTALLED}/"; fi

	mksquashfs ${PKG_DIR} "${DEST_DIR}/${PKG}.vcz" -root-mode 0777 -ef /tmp/excludes
	unsquashfs -l "${DEST_DIR}/${PKG}.vcz" | sed 's|^squashfs-root||;/^$/d' > "${DEST_DIR}/${PKG}.list"
	xbps-rindex -a ${DEST_DIR}/*.xbps
	xbps-query -R --repository ${DEST_DIR} -x "${PKG}" | sed 's/\(.*\)[-><].*$/\1/' | sed -n '/musl/!p' | sed -n '/^$/!p' > "${DEST_DIR}/${PKG}.dep"
	( cd ${DEST_DIR} && sha256sum ${PKG}.vcz > ${PKG}.sha256 )

        rm -r "${PKG_DIR}"
        echo "${PKG}" >> /tmp/converted
}


while IFS= read -r PKG || [ -n "${PKG}" ]
do
	convert_package  "${PKG}"
done < "/tmp/templates"

exit 0
