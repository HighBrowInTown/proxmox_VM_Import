#!/bin/sh

URL="${1}"
[ -z "${URL}" ] && INPUT_FILE="${1}"
[ -n "${URL}" ] && INPUT_FILE="$(basename "${URL}")"
STORE="/mnt/pve/local-storage/vulnhub"
TEMP="${STORE}/tmp/"

VM_ID="1000"


DOWNLOAD_FILES () {
    [ -z "${URL}" ] && echo "ERROR: NO URL FOUND" && exit 1
    echo "INFO: REMOVING OLD WORKING DIRECTORY"
    [ -d "${TEMP}" ] && rm -rf "${TEMP}" && mkidr -p "${TEMP}"
    [ ! -d "${TEMP}" ] && mkdir -p "${TEMP}"
    echo "INFO: DOWNLOADING FILE FROM - ${URL}"
    wget "${URL}" -P "${TEMP}"
}

#extract file
EXTRACT_FILE () {

    local EXTNS
    EXTNS="${INPUT_FILE##*.}"
    if [ "${EXTNS}" = 'rar' ] 
        then 
            echo "INFO: EXTRACTING RAR FILE"
            unrar x "${TEMP}/${INPUT_FILE}" "${TEMP}" 
            rm "${TEMP}/${INPUT_FILE}"
    fi
}


#Create a VM using vmdk file
IMPORT_VMDK () {

    local VM_NAME VMDK_FILE LAST_VMID
    VM_NAME="$(basename "${INPUT_FILE%.*}")" 
    VMDK_FILE="$(find "${TEMP}" -name "*.vmdk")"
    LAST_VMID="$(qm list | awk 'END{print $1}')"
    [ "${VM_ID}" -le "${LAST_VMID}" ] && VM_ID=$((LAST_VMID + 1))

    echo "INFO: CREATING NEW VIRTUAL MACHINE: ${VM_NAME}"
    qm create "${VM_ID}" --memory 1024 --cores 1 --name "${VM_NAME}" --ostype l24
    echo "INFO: CONVERTING VMDK DISK ${VMDK_FILE} TO QCOW2 DISK"
    if  qm importdisk "${VM_ID}" "${VMDK_FILE}" local-storage --format qcow2
        then    
            echo "INFO: IMPORT SUCCESS"
        else 
            echo "ERROR: CONVERSION FAILED"
            qm destroy "${VM_ID}"
            exit 1
    fi 
    echo "INFO: ADDING QCOW2 DISK"
    qm set "${VM_ID}" --ide0 local-storage:"${VM_ID}"/vm-"${VM_ID}"-disk-0.qcow2
    echo "INFO: SET BOOT ORDER AND ADD NETWORK CARD"
    qm set "${VM_ID}" --boot order=ide0 --net0 model=virtio,bridge=vmbr0,tag=10
}

MAIN () {
    
    DOWNLOAD_FILES 
    EXTRACT_FILE
    IMPORT_VMDK
}

MAIN