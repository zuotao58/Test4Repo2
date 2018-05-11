#!/bin/bash

set -o errexit
set -x

#echo "******module_name:${module_name}"
#echo "******branch_name:${branch_name}"
#echo "******apk_version:${apk_version}"

typeset -u tagnumber

echo "apk_build"

current_dir=`pwd`
android_key_dir="${current_dir}/security"
tmp_folder="${current_dir}/tmpfolder"

SOURCE_SERVER="gerritroot@192.168.31.242"
HOST="192.168.31.242"
USER="acuteangle"
PASS="sjx1234"

release_dir=${branch_name}


build_init(){
    if [ -d ${tmp_folder} ];then
        rm -rf ${tmp_folder}
    fi
    mkdir -p ${tmp_folder}
    apk_version=`echo ${apk_version} | sed s/[[:space:]]//g`
    if ! ( echo "${apk_version}" | grep -qi 'v' );then
         echo "****** Apk_version Set Error!"
         exit 1
    fi
    apk_version=${apk_version/'V'/'v'}
}

############################################################################
#build_checkmodule
#check module_name whether correct.
##############################################################################
build_check_module()
{
   if [ ${module_name} == 'pls-choose-module' ]; then
      echo "***************Error**************"
      echo "pls-choose-module is not module name."
      echo "Please input correct apk module name"
      echo "**********************************"
      exit 1
   fi
}


############################################################################
#build_fetch_apkconfig
#fetch info following the branch. 
#fetch info from int/jenkins_common/allinone_table.txt
#Use method:
#fetchinfo in the shell.
##############################################################################
build_fetch_apkconfig()
{
   cd ${current_dir}

   local apkinfo=`python ./int/common/allinone_match.py table5vol ${module_name} ${branch_name}`

   if [ -z "${apkinfo}" ]; then
        echo "******************************************************Warnig***********************************************************"
        echo "********Run python ${current_dir}/int/common/allinone_match.py table5vol ${module_name} error."
        echo "********Pls Contant Jenkins Manager."
        echo "***********************************************************************************************************************"
        exit 1
   fi

   git_store_name=$(echo ${apkinfo} | cut -d' ' -f2)

   if [ ${git_store_name} == 'None' ]; then
        echo "*********************************Error**********************************"
        echo "Can't find branch ${branch_name} information in the table allinone_table.txt."
        echo "Please insert branch information to the table"
        echo "************************************************************************"
        exit 1
   else
        git_store_name=$(echo ${apkinfo} | cut -d' ' -f2)
        build_env=$(echo ${apkinfo} | cut -d' ' -f4)
        branch_info=$(echo ${apkinfo} | cut -d' ' -f1)
        sign_table=$(echo ${apkinfo} | cut -d' ' -f5)
   fi
   echo "******Check config."

   if [ ${build_env} == "msm8998" ]; then
        product_name="acuteangle"
        is_sdk_make='false'
        platform_name=${build_env}
   elif [ ${build_env} == "gradlen" ] || [ ${build_env} == "gradlem" ] ;then
        is_sdk_make='true'
        platform_name=""
   elif [ ${build_env} == "thirdparty" ] || [ ${build_env} == "jar" ] || [ ${build_env} == "none" ]; then
        is_sdk_make=''
        platform_name=""
   else
        echo "Get build tools parameter from allinone_table.txt error."
   fi

   echo "***************Read parameters***********"
   echo "* module_name: ${module_name}"
   echo "* branch_name: ${branch_name}"
   echo "* git_store_name: ${git_store_name}"
   echo "* build_env: ${build_env}"
   echo "* platform_name: ${platform_name}"
   echo "* apk_version: ${apk_version}"
   echo "* sign_mode: ${sign_table}"
   echo "*****************************************"
}

update_tools()
{
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR

    #if [ -d .git ]; then
        #git clean -df
        #git reset --hard
        #git pull
    #fi

    apptools_dir="${current_dir}/../acuteag_generaltools"
    int_dir="${current_dir}/int"
    scripts_dir="${current_dir}/assistant"
    tools_dir="${apptools_dir}/sdk-tools/lib"

    trap - ERR
}

download_module_code()
{
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR

    code_dir=${current_dir}/../${platform_name}

    if [ "${is_sdk_make}" == "false" ]; then
       if [ ! -d ${code_dir} ]; then
            echo "*****************error*********************"
            echo "Please download ${platform_name} source code."
            echo "*******************************************"
            exit 1
        fi

        if [ -d ${code_dir}/packages/apps/${git_store_name} ]; then
           rm -rf ${code_dir}/packages/apps/${git_store_name}
        fi

        #mkdir -p $code_dir/packages/apps

        module_dir=${code_dir}/packages/apps/${git_store_name}
        branch_num=${branch_name#${git_store_name}_}

        echo "Start Clone All Acuteags Apps."
        #while read i
        #do
        #    echo "Clone ${i}"
        #    git clone -q ${SOURCE_SERVER}:apps/qcom/${i}.git -b ${branch_name} ${code_dir}/packages/apps/${i}
        git clone -q ${SOURCE_SERVER}:apps/qcom/${git_store_name}.git -b ${branch_name} ${code_dir}/packages/apps/${git_store_name}
        #done < ${current_dir}/int/common/acuteagapps_module.list

    else
        source_dir=${current_dir}/..
        module_dir=${source_dir}/${git_store_name}
        
        if [ -d ${module_dir} ];then
            rm -rf ${module_dir}
        fi

        echo "module_dir:${module_dir}"
        mkdir -p ${module_dir}

        cd ${source_dir}

        echo "git clone  ${SOURCE_SERVER}:apps/qcom/${git_store_name}.git -b ${branch_name}"
        git clone  ${SOURCE_SERVER}:apps/qcom/${git_store_name}.git -b ${branch_name}
    fi

    cd ${current_dir}

    trap - ERR
}

update_versioncode()
{
    echo "****** update_versioncode"
    if [  ${build_env} == "msm8998" ];then
        if [ -f ${module_dir}/AndroidManifest.xml ];then
            #vercodetmp=`sed -n 's/.*android:versionCode=\"\(.*\)\"/\1/p' ${module_dir}/AndroidManifest.xml | grep -o "[0-9][0-9.]*"`
            vercodetmp=`grep -oP 'android:versionCode=\"\K\S+(?=\")' ${module_dir}/AndroidManifest.xml` 
            #echo "vercodetmp:${vercodetmp}"
        else
            echo "*******************************Error******************************************"
            echo "Can't get versionName and versionCode from AndroidManifest.xml/build.gradle."
            echo "******************************************************************************"

            exit 1
        fi
    elif [ ${build_env} == "gradlen" -o ${build_env} == "gradlem" ];then
        if [ -f ${module_dir}/build.gradle -o -f ${module_dir}/app/build.gradle   ];then
            #vercodetmp=`sed -n 's/.*versionCode *\(.*\)/\1/p' ${module_dir}/app/build.gradle | grep -o "[0-9][0-9.]*"`
            vercodetmp=`grep -oP 'valueOf\(\"\K\S+(?=\")' ${module_dir}/app/build.gradle`
            #echo "vercodetmp:${vercodetmp}"
        else
            echo "**************************************Error******************************************"
            echo "Can't upload versionName and versionCode. Can't find AndroidManifest.xml/build.gradle."
            echo "*************************************************************************************"

            exit 1
        fi
    fi

    vercodetmp=`echo ${vercodetmp} | sed s/[[:space:]]//g`

    cur_version_code_suffix=${vercodetmp:6:3}

    date_version_code=`date "+%y%m%d"`

    old_version_code=${vercodetmp:0:6}

    if [ ${old_version_code} != ${date_version_code} ];then
        new_version_code_suffix="001"
    else
        new_version_code_suffix_TMP=`expr ${cur_version_code_suffix} + 1`

        new_version_code_suffix=`printf "%03d\n" ${new_version_code_suffix_TMP}`
    fi

    version_code=${date_version_code}${new_version_code_suffix}

    echo "****** The Priv Versioncode:${vercodetmp}"
    echo "****** The New  Versioncode:${version_code}"
}


build_check_release()
{
    if [ -d tmpswo ];then
        rm -rf tmpswo
    fi

    mkdir -p ${current_dir}/tmpswo

    cd ${current_dir}/tmpswo

    if [ -d standaloneapp_info ];then
        rm -rf standaloneapp_info
    fi

    git clone -q ${SOURCE_SERVER}:integration/standaloneapp_info.git -b master
   
    cd ${current_dir}

    para_all="${branch_name},${apk_version},${module_name}"

    if ( grep -qw ${para_all} ${current_dir}/tmpswo/standaloneapp_info/swo_release.csv ); then
        echo "****************************Error********************************"
        echo "The version $para_all has been released."
        echo "Please generate correct version."
        echo "*****************************************************************"  

        exit 1
    fi

    #The Version need higher then the latest released.
    local versionlatest=`grep -nr "${branch_name}" ${current_dir}/tmpswo/standaloneapp_info/swo_release.csv | grep -w ${module_name} | cut -d"," -f2`

    if [ "${versionlatest}" == "" ];then
        echo "****** The ${module_name} in ${branch_name} First Time Release."
        versionlatest=0
    else
        echo "${versionlatest}" | sed "s/ /\n/g"  > ${tmp_folder}/versionlatest_${branch_name}.txt
        versionlatest=`tail -1 ${tmp_folder}/versionlatest_${branch_name}.txt`
        versionlatest=${versionlatest//' '/''}
    fi

    versioncomp=${apk_version//'.'/''}
    versioncomp=${versioncomp/'v'/''}
    versionlatestcomp=${versionlatest//'.'/''}
    versionlatestcomp=${versionlatestcomp/'v'/''}
    compbits=${#versioncomp}
    latestcompbits=${#versionlatestcomp}
    echo "****** Compbits:${compbits}"
    echo "****** Latestcompbits:${latestcompbits}"

    echo "****** Apk VersionName Comp:"${versioncomp}
    echo "****** Apk VersionName Catestcomp:"${versionlatestcomp}

    if [ ${latestcompbits} -gt 1  ];then
        if [ ${compbits} -ne ${latestcompbits} ];then
            echo "****************************Error********************************"
            echo "Apk VersionName  Bits Settings is Error!"
            echo "****************************************************************"
            exit 1
        fi
    fi

    if [[ ${versioncomp} > ${versionlatestcomp} ]]; then
        echo "****** Apk VersionName Settings is Right."
    else
        echo "****************************Error********************************"
        echo "Version is ${apk_version}"
        echo "The lastest relesased version is ${versionlatest}"
        echo "The version need higher then latest released."
        echo "*****************************************************************"  
        rm -rf ${current_dir}/tmpswo
        exit 1
    fi   

    #The VersionCode need higher then the latest released.
    expr ${version_code} "+" 10 &> /dev/null
    if [ $? -ne 0 ];then
        echo "****************************Error********************************"
        echo "Version Code is ${version_code}."
        echo "Please set Version Code numbers."
        echo "If you release thirdparty apk or jar package, you can input 0."
        echo "*****************************************************************"
        exit 1  
    fi

    versioncodelatest=`grep -nr "${branch_name}" ${current_dir}/tmpswo/standaloneapp_info/swo_release.csv | grep "${module_name},"  |cut -d"," -f10`
    echo "${versioncodelatest}" | sed "s/ /\n/g"  > ${tmp_folder}/versioncodelatest_${branch_name}.txt
    versioncodelatest=`tail -1 ${tmp_folder}/versioncodelatest_${branch_name}.txt`
    versioncodelatest=`echo ${versioncodelatest} | sed s/[[:space:]]//g`
    versioncodelatest=${versioncodelatest/'I'/''}
    echo "****** Apk VersionCode:"${version_code}
    echo "****** Apk VersionCode Latest:"${versioncodelatest}
    if [ ${versioncodelatest} ]; then
        versioncodelatestbit=${#versioncodelatest}
        versioncodebit=${#version_code}
        if [ ${versioncodelatestbit} -ne ${versioncodebit} ]; then
            echo "****************************Error********************************"
            echo "You set the VersionCode ${versioncodebit} bits."
            echo "The lastest relesased VersionCode is ${versioncodelatestbit} bits."
            echo "Please set the same bits with released Version."
            echo "*****************************************************************"  
            exit 1
        fi
        if [ ${version_code} -gt ${versioncodelatest} ]; then
            echo "****** Apk versionCode settings is right."
        elif [ ${version_code} -le ${versioncodelatest} ]; then
            echo "****************************Error********************************"
            echo "The VersionCode is ${version_code}"
            echo "The lastest relesased VersionCode is ${versioncodelatest}"
            echo "The VersionCode need higher then latest released."
            echo "*****************************************************************"  
            rm -rf ${current_dir}/tmpswo
            exit 1
        else
            echo "****** The Version Code can't be checked."
        fi
    else
        echo "****** The Latest Released Versioncode is Empty."
    fi   
  
    set -e
    rm -rf ${current_dir}/tmpswo
    rm -f ${tmp_folder}/versionlatest_${branch_name}.txt
    rm -f ${tmp_folder}/versioncodelatest_${branch_name}.txt
    
}

build_check_version(){

    echo "****** Checking versionName and versionCode..."

    cd ${current_dir}

    set +e

    if [  ${build_env} == "msm8998" ];then
        if [ -f ${module_dir}/AndroidManifest.xml ];then
            var=`sed -n 's/.*android:versionName=\"\(.*\)\".*/\1/p' ${module_dir}/AndroidManifest.xml | grep -o "[0-9][0-9a-z.]*"`
            vercodetmp=`sed -n 's/.*android:versionCode=\"\(.*\)\"/\1/p' ${module_dir}/AndroidManifest.xml | grep -o "[0-9][0-9a-z.]*"`

            echo "****** var:${var}"
            echo "****** vercodetmp:${vercodetmp}"
        else
            echo "*******************************Error******************************************"
            echo "Can't get versionName and versionCode from AndroidManifest.xml/build.gradle."
            echo "******************************************************************************"

            exit 1
        fi
    elif [ ${build_env} == "gradlen" -o ${build_env} == "gradlem" ];then
        if [ -f ${module_dir}/build.gradle ];then
            var=`sed -n 's/.*versionName *\"\(.*\)\".*/\1/p' ${module_dir}/app/build.gradle | grep -o "[0-9][0-9a-z.]*"`
            vercodetmp=`sed -n 's/.*versionCode *\(.*\)/\1/p' ${module_dir}/app/build.gradle | grep -o "[0-9][0-9a-z.]*"`
        else
            echo "**************************************Error******************************************"
            echo "Can't upload versionName and versionCode. Can't find AndroidManifest.xml/build.gradle."
            echo "*************************************************************************************"

            exit 1
        fi
    fi

    set -e

    vercode=$(echo $vercodetmp | cut -d' ' -f1)

    echo "****** AndroidManifest.xml/build.gradle versionName is v${var}"
    echo "****** AndroidManifest.xml/build.gradle versionCode is ${vercode}"

    if [ "${apk_version}" == "v${var}" ];then
        echo "****** ${apk_version} is Equal v${var}"
    else
        echo "********************error******************************"
        echo "Jenkins version should be same with AndroidManifest.xml/build.gradle version."
        echo "${apk_version} is not equal v${var}, pls check"
        echo "*******************************************************"

        exit 1
    fi

    cd ${current_dir}
}

updateantversionandcode()
{
   sed -i "s/android:versionName=\"v[0-9a-z.]*\"/android:versionName=\"${apk_version}\"/" ${BUILD_CONFIG_FILE}
   sed -i "s/android:versionName=\"[0-9a-z.]*\"/android:versionName=\"${apk_version}\"/" ${BUILD_CONFIG_FILE}
   sed -i "s/android:versionCode=\"[0-9a-z]*\"/android:versionCode=\"${version_code}\"/" ${BUILD_CONFIG_FILE}
}

updategradleversionandcode()
{
   sed -i "s/versionName *\"v[0-9a-z.]*\"/versionName \"${apk_version}\"/" ${BUILD_CONFIG_FILE}
   sed -i "s/versionName *\"[0-9a-z.]*\"/versionName \"${apk_version}\"/" ${BUILD_CONFIG_FILE}
   sed -i "s/versionCode *.*[0-9a-z].*/versionCode Integer.valueOf(\"${version_code}\")/" ${BUILD_CONFIG_FILE}

}

build_upgrade_version()
{
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    echo "****** Start updating versionName and versionCode..."
    cd ${current_dir}

    if [ ${build_env} == "msm8998" ];then
        if [ -f ${module_dir}/AndroidManifest.xml ];then
            BUILD_CONFIG_FILE=${module_dir}/AndroidManifest.xml
            updateantversionandcode
        else
            echo "**************************************Error******************************************"
            echo "Can't upload versionName and versionCode. Can't find AndroidManifest.xml/build.gradle."
            echo "*************************************************************************************"
            exit 1
        fi
    elif [ ${build_env} == "gradlen" -o ${build_env} == "gradlem" ];then
        if [ -f ${module_dir}/app/build.gradle ];then
            BUILD_CONFIG_FILE=${module_dir}/app/build.gradle
            updategradleversionandcode
        else
            echo "**************************************Error******************************************"
            echo "Can't upload versionName and versionCode. Can't find AndroidManifest.xml/build.gradle."
            echo "*************************************************************************************"
            exit 1
        fi
    fi
    cd ${current_dir}
    trap - ERR
}

build_setsignmode()
{
    cd ${current_dir}

    if [  ${build_env} == "msm8998" ];then
        if [ -f ${module_dir}/Android.mk ];then
            if !(grep "LOCAL_CERTIFICATE" -q ${module_dir}/Android.mk );then
                echo "****** WARING:${module_dir} has not been set LOCAL_CERTIFICATE, use testkey default."
                sign_mode="releasekey"
            else
                sign_mode=`grep "LOCAL_CERTIFICATE" ${module_dir}/Android.mk | sed s/[[:space:]]//g | cut -d'=' -f 2`
            fi
        else
            echo "*******************************Error******************************************"
            echo "Can't get Android.mk from ${git_store_name}"
            echo "******************************************************************************"

            exit 1
        fi
    elif [ ${build_env} == "gradlen" -o ${build_env} == "gradlem" ];then
        if [ -f ${module_dir}/app/build.gradle ];then
            sign_mode=${sign_table}
        else
            echo "*******************************Error******************************************"
            echo "Can't get build.gradle from ${git_store_name}"
            echo "******************************************************************************"

            exit 1
        fi
    fi

    if [ "${sign_mode}" == "releasekey" ]; then
       sign_mode_name="release"
       android_sign_mode="testkey"
    else
       sign_mode_name=${sign_mode}
       android_sign_mode=${sign_mode}
    fi

    if !( echo "${sign_table}" | grep -q "${sign_mode}" );then
       echo "*****************************Error****************************************"
       echo "Waring:${module_name} tables default sign key=${sign_table},then Android.mk"
       echo "set sign mode with ${sign_mode_name}                                      "
       echo "**************************************************************************"
    fi
    echo "****** Sign Mode with ${sign_mode_name}"

}


build_deliver_version()
{
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR

    cd ${module_dir}
   
    if ( ! ((git status | grep "nothing to commit") || (git status | grep "无文件要提交") ));then
        echo "****** Jenkins Auto Upgrade VersionName and VersionCode."
        git add .
        git commit -am "jenkins auto update versionName and versionCode."
        git pull
        git push
    fi

    cd ${current_dir}
    echo "****** End deliver versionName and versionCode."

    trap - ERR
}

build_externalinfo(){
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR

    if (echo ${BUILD_CONFIG_FILE} | grep -q "build.gradle" ); then
        var=`sed -n 's/.*versionName *\"\(.*\)\".*/\1/p' ${BUILD_CONFIG_FILE}`
    else
        var=`sed -n 's/.*android:versionName=\"\(.*\)\".*/\1/p' ${BUILD_CONFIG_FILE}`
    fi

    len_var=${#var}
    timesufixtmp=${var:${len_var}-5:5}

    if (echo ${timesufixtmp} | grep -o -q "_[0-9][0-9][0-9][0-9]");then
         echo "******* Get versionName from ${BUILD_CONFIG_FILE}."
         var=${var:0:${len_var}-5}
    fi

    timesufix=$(date "+%m%d")

    echo "****** Final VersionName=${var}_${timesufix}"

    if ( echo ${BUILD_CONFIG_FILE} | grep -q "build.gradle" ); then
        sed -i "s/versionName *\".*\"/versionName \"${var}_${timesufix}\"/" ${BUILD_CONFIG_FILE}
    else
        sed -i "s/android:versionName=\".*\"/android:versionName=\"${var}_${timesufix}\"/" ${BUILD_CONFIG_FILE}
    fi
    trap - ERR
}

sign_apk()
{
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR

    cd ${current_dir}

    if [ -d ${current_dir}/apk_version ]; then
        echo "rm -rf ${current_dir}/apk_version"
        rm -rf ${current_dir}/apk_version
    fi

    mkdir -p ${current_dir}/apk_version
    cd ${current_dir}/apk_version

    echo "****** Sign apk ${module_name}"

    if [ "${is_sdk_make}" == "false" ]; then
        module_out_app_dir="${code_dir}/out/target/product/${product_name}/system/app/${module_name}"
        module_out_privapp_dir="${code_dir}/out/target/product/${product_name}/system/priv-app/${module_name}"

        if [ -d ${module_out_app_dir} ];then
           cp ${module_out_app_dir}/${module_name}.apk release_signed_platform.apk
        elif [ -d ${module_out_privapp_dir} ];then
           cp ${module_out_privapp_dir}/${module_name}.apk release_signed_platform.apk
        else
           echo "****** Error:${module_name} general build failed!"
           exit 1
        fi
    elif [ ${build_env} == "gradlem" ];then
        cp ${module_dir}/app/build/outputs/apk/*-release*.apk release.apk

        java -Xmx512m -jar ${tools_dir}/signapk.jar ${android_key_dir}/${android_sign_mode}.x509.pem ${android_key_dir}/${android_sign_mode}.pk8 release.apk release_signed_platform.apk
    elif [ ${build_env} == "gradlen" ];then
        cp ${module_dir}/app/build/outputs/apk/*-release*.apk release.apk

        java -Djava.library.path=${tools_dir}/so -jar ${tools_dir}/signapk.jar \
        ${android_key_dir}/${android_sign_mode}.x509.pem ${android_key_dir}/${android_sign_mode}.pk8 release.apk release_signed_platform.apk
    else
        echo "****************************Error********************************"
        echo "Can't find output apk.Please select correct environment."
        echo "*****************************************************************"  

        exit 1
    fi

    trap - ERR

}

optimize_apk()
{
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR

    echo "****** Begin to optimize apk..."
    echo "****** Tools_dir:${tools_dir}"

    if [ "${sign_mode}" == "releasekey" ]; then
        sign_mode_name=release
    else
        sign_mode_name=${sign_mode}
    fi

    if [ ${build_env} == "gradlem" -o ${build_env} == "gradlen" ];then
        ${tools_dir}/zipalign -f -v 4 release_signed_platform.apk ${module_name}_${apk_version}_signed_${sign_mode_name}key.apk
    else
        mv -v release_signed_platform.apk ${module_name}_${apk_version}_signed_${sign_mode_name}key.apk
    fi
    trap - ERR
}


upload_tag()
{
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR

    tagnumber=${branch_name}-RELEASE-${apk_version}
    echo "****** Tagnumber:"$tagnumber

    cd ${module_dir}

    if ( git tag |grep -w "${tagnumber}$" ); then
        git tag -d ${tagnumber}
        git push ${SOURCE_SERVER}:apps/qcom/${git_store_name}.git :refs/tags/${tagnumber}
    fi

    git tag -a ${tagnumber} -m "ADD ${tagnumber}"
    git push ${SOURCE_SERVER}:apps/qcom/${git_store_name}.git refs/tags/${tagnumber}

    trap - ERR
}

upload_sw()
{
    uploaddate=$(date "+%Y-%m-%d")

    cd $current_dir/apk_version

    local prefix=$(pwd)

    echo "prefix= "${prefix}

    echo "****** Begin to upload the apk..."

    echo "${scripts_dir}/upload_make.exp $module_name ${release_dir} $prefix ${apk_version} $PASS"
    ${scripts_dir}/upload_make.exp $module_name "${release_dir}"  $prefix ${apk_version} $PASS

    echo "*****************************************Info********************************************"
    echo "Please download apk from 192.168.31.242 /APP_Release/$module_name/${branch_name}/${apk_version}/"
    echo "*****************************************************************************************"
}

build_init
build_check_module
build_fetch_apkconfig
update_tools
download_module_code
update_versioncode
build_check_release
build_check_version
build_upgrade_version
build_deliver_version
build_setsignmode
build_externalinfo

echo "****** Start building apk..."
source ${apptools_dir}/envsetup.sh
echo "****** Build_apk ${git_store_name} ${build_env} ${branch_name}"
build_apk ${git_store_name} ${build_env} ${branch_name}
echo "****** End building apk."

sign_apk
optimize_apk
upload_tag
upload_sw
