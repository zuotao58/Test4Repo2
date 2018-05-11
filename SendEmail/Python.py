#!/bin/bash

echo "---------------ACUTEAG P6 Build START---------------------"

source /etc/profile

ROOT_PATH="/home/jenkinsroot/workspace/AcuteAngle_P6_DailyBuild"
QCOM_BASE_BACKUP="/data/QcomBaseBackup/QcomBase"

QCOM_BASE="${ROOT_PATH}/QcomBase"
AA_BASE="${ROOT_PATH}/AcuteagBase"
ACUTEAG="${ROOT_PATH}/acuteag"
ACUTEAG_FRAMEWORK="${ROOT_PATH}/acuteag-framework"

update_qcom_base_code() {
    echo "update qcom base code...."
    if [  -d ${QCOM_BASE}  ];then
      rm -rf ${QCOM_BASE} 
    fi

    cp -rf ${QCOM_BASE_BACKUP} ${ROOT_PATH}
    reset_edk_tools_path
}

reset_edk_tools_path() {
    if [  -d ${QCOM_BASE}  ];then
    	echo "reset edk tools path..."    
    	cd ${QCOM_BASE}/bootable/bootloader/edk2/
    	rm Conf/BuildEnv.sh
    	./edksetup.sh BaseTools
    	cd ${ROOT_PATH}
    fi
}

update_aa_base_code() {
    echo "update acuteag base code..."    

    if [ -d ${AA_BASE}  ];then
      rm -rf ${AA_BASE} 
    fi

    if [ -d ${ACUTEAG}  ];then
      rm -rf ${ACUTEAG} 
    fi

    if [ -d ${ACUTEAG_FRAMEWORK}  ];then
      rm -rf ${ACUTEAG_FRAMEWORK} 
    fi

    git clone gerritroot@192.168.31.242:AcuteagBase.git -b acuteag_dev_1.0.1

    git clone gerritroot@192.168.31.242:/quic/la/acuteag.git -b LA.UM.6.4.1.r1

    git clone gerritroot@192.168.31.242:apps/qcom/acuteag-framework.git -b acuteag_dev_1.0.1

    if [ -d ${ACUTEAG} ];then
	cp -rf ${ACUTEAG}/acuteag-apps ${AA_BASE}/vendor/acuteangle
	rm -rf ${ACUTEAG}
    fi

    if [ -d ${ACUTEAG_FRAMEWORK} ];then
	cp -rf ${ACUTEAG_FRAMEWORK} ${AA_BASE}/vendor/acuteangle
	rm -rf ${ACUTEAG_FRAMEWORK}
    fi
}

copy_aa_base_code(){
    if [ -d ${AA_BASE} ];then
        echo "copy $AA_BASE to $QCOM_BASE"
    	rm -fv ${QCOM_BASE}/build.sh
	rm -rfv ${QCOM_BASE}/vendor/acuteangle
	cp -rfv ${AA_BASE}/* ${QCOM_BASE} 
    fi
}

build_remake() {
    echo "choose build type: build-remake"
    if [  -d ${QCOM_BASE}  ];then
        update_aa_base_code
	copy_aa_base_code
        cd ${QCOM_BASE}
        ./TmakeAcuteag  -v userdebug acuteangle -r
    else
	echo "QcomBase Not Found! Please Choose build-clobber build."
    fi
}

build_clean() {
    echo "choose build type: build-clean"
    if [  -d ${QCOM_BASE}  ];then
        update_aa_base_code
	copy_aa_base_code
        cd ${QCOM_BASE}
        ./TmakeAcuteag  -v userdebug acuteangle -n
    else
	echo "QcomBase Not Found! Please Choose build-clobber build."
    fi
}

build_clobber() {
    echo "choose build type: build-clobber"
    update_qcom_base_code
    update_aa_base_code
    copy_aa_base_code
    cd ${QCOM_BASE}
    ./TmakeAcuteag  -v userdebug acuteangle -n
}

echo ${build_type}

if [ "${build_type}" == "build-remake" ];then
    build_remake
elif [ "${build_type}" == "build-clean" ];then
    build_clean
else
    build_clobber
fi

if [ $? -ne 0 ];then
    exit -1;
fi

if [ ! -f out/target/product/acuteangle/system.img ];then
   exit -1;
fi

source build/envsetup.sh
choosecombo 1 acuteangle 2
oemtools/make_unsparse_image.sh

OUT_TIME=$(date +%Y%m%d%H%M)

MODULE="ACUTEANGLE_rm69298_FT3517U_s5k3l8_ov8856+imx350_"

RELEASE_DIR="/data/release/ACUTEANGLE_rm69298_FT3517U_s5k3l8_ov8856+imx350_/${OUT_TIME}"

if [ ! -f _unsparse_image/ACUTEANGLE_rm69298_FT3517U_s5k3l8_ov8856+imx350_/ACUTEANGLE_rm69298_FT3517U_s5k3l8_ov8856+imx350_.rar ];then
    echo "error!"
    exit 1;
fi

zip -r ${OUT_TIME}_fullimage.zip out/target/product/acuteangle/*.img

mkdir -p ${RELEASE_DIR}

cp _unsparse_image/ACUTEANGLE_rm69298_FT3517U_s5k3l8_ov8856+imx350_/ACUTEANGLE_rm69298_FT3517U_s5k3l8_ov8856+imx350_.rar ${RELEASE_DIR}
mv ${OUT_TIME}_fullimage.zip ${RELEASE_DIR}

scp -r ${RELEASE_DIR} root@192.168.31.242:/home/acuteangleftp/ROM-Release/ACUTEANGLE_rm69298_FT3517U_s5k3l8_ov8856+imx350_

