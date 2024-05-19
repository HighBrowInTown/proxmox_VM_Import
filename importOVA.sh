#!/bin/sh

URL="${1}"
INPUT_FILE="${1}"
STORE="/mnt/pve/local-storage/vulnhub"
TEMP="${STORE}/tmp"
EXTNS="${INPUT_FILE##*.}"
VM_NAME="$(basename ${INPUT_FILE%.*})" 
VMDK_FILE="$(basename ${1})"
VM_ID="1000"
LAST_VMID="$(qm list | awk 'END{print $1}')"
[ "${VM_ID}" -le "${LAST_VMID}" ] && VM_ID=$((${LAST_VMID} + 1))

DOWNLOAD_FILES () {
    echo "INFO: REMOVING OLD WORKING DIRECTORY"
    [-d ${TEMP} ]&& rm -rf ${TEMP} && mkidr -p ${TEMP}
    wget ${URL} -o "${TEMP}"
}

#extract tarfile
#Create a VM using vmdk file
IMPORT_VMDK () {
    echo "INFO: CREATING NEW VIRTUAL MACHINE: ${VM_NAME}"
    qm create "${VM_ID}" --memory 1024 --cores 1 --name "${VM_NAME}" --ostype l24
    echo "INFO: CONVERTING VMDK DISK ${VMDK_FILE} TO QCOW2 DISK"
    qm importdisk "${VM_ID}" "${VMDK_FILE}" local-storage --format qcow2 || echo "ERROR: CONVERSION FAILED"; qm destroy "${VM_ID}"; exit 1 
    echo "INFO: ADDING QCOW2 DISK"
    qm set "${VM_ID}" --ide0 local-storage:"${VM_ID}"/vm-"${VM_ID}"-disk-0.qcow2
    echo "INFO: SET BOOT ORDER AND ADD NETWORK CARD"
    qm set "${VM_ID}" --boot order=ide0 --net0 model=virtio,bridge=vmbr0,tag=10
}

IMPORT_VMDK 