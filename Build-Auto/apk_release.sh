#!/bin/bash

#echo "module_name:${module_name}"
#echo "branch_name:${branch_name}"
#echo "apk_version:${apk_version}"
#echo "main_change_select:${main_change_select}"
#echo "main_change_input:${main_change_input}"
#echo "mail_notice_list:${mail_notice_list}"

set -o errexit
set -x

SOURCE_SERVER="gerritroot@192.168.31.242"
PASSWD="sjx1234"
typeset -u tagnumber

current_dir=`pwd`

tmp_folder="${current_dir}/tmpfolder"
tmp_resultfile="${tmp_folder}/result.txt"

acuteag_dir="${current_dir}/../acuteag"
acuteag_release_dir="${SOURCE_SERVER}:/quic/la/acuteag"
acuteag_release_branch="LA.UM.6.4.1.r1"
acuteag_master_branch="LA.UM.6.4.1.r1_master"

release_dir=${branch_name}

release_init()
{
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

release_update_tools()
{
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    cd ${current_dir}

    if [ -d .git ]; then
        echo "****** Release Reset."
        #git reset --hard
        #git clean -df
        #git pull
    fi

    trap - ERR
}

release_checkmodulename()
{
   if [ ${module_name} == 'pls-choose-module' ]; then
      echo "***************Error**************"
      echo "pls-choose-module is not module name."
      echo "Please input correct module_name"
      echo "**********************************"
      exit 1
   fi
}

release_checkinputlog()
{
  if (echo $main_change_input | grep -q "#");then
    echo "****************************Error******************************"
    echo "\"#\" can't be input in main_change_input. Please delete "
    echo "***************************************************************"
    exit 1
  fi

  limitMainchangeinput=12
  lenmain_change_input=${#main_change_input}
  if [ $lenmain_change_input -le $limitMainchangeinput ]; then
    echo "*****************************error**********************************"
    echo "main_change_input=$main_change_input"
    echo "Please input main_change_input more then 20 characters."
    echo "*********************************************************************"  
    exit 1
  fi
}

release_fetchinfo()
{
   cd ${current_dir}

   local apkinfo=`python ./int/common/allinone_match.py table5vol ${module_name} ${branch_name}`

   if [ -z "${apkinfo}" ]; then
        echo "******************************************************Warnig***********************************************************"
        echo "********Run python ${current_dir}/int/common/allinone_match.py table5vol ${module_name} error."
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
        module_name=$(echo ${apkinfo} | cut -d' ' -f3)
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

release_check_dir()
{
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
 
    cd ${current_dir}

    int_dir=`pwd`

    scripts_dir="${int_dir}/assistant"

    apptools_dir="${current_dir}/../AcuteAngle_Generaltools"

    tools_dir="${apptools_dir}/sdk-tools/lib"

    if [ -d "${current_dir}/acuteagapp_rel" ]; then
       rm -rf ${current_dir}/acuteagapp_rel
    fi

    mkdir -p ${current_dir}/acuteagapp_rel/ReleaseNotes

    acuteagapprel_path="${current_dir}/acuteagapp_rel"
    releasenotespath="${current_dir}/acuteagapp_rel/ReleaseNotes"

    if [ -d ${current_dir}/releasecheck ]; then
        rm -rf ${current_dir}/releasecheck
    fi

    release_checkfolder=${current_dir}/releasecheck

    mkdir -p ${release_checkfolder}

    if [ ! -d ${tmp_folder} ]; then
        mkdir -p ${tmp_folder}
    fi

    rm -rf ${current_dir}/sync_*

    trap - ERR
}


release_checkhistory()
{
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    
    cd ${tmp_folder}
  
    if [ -d ${tmp_folder}/standaloneapp_info ]; then
        rm -rf ${tmp_folder}/standaloneapp_info
    fi

    echo "****** Git Clone $SOURCE_SERVER:integration/standaloneapp_info -b master"
  
    git clone -q $SOURCE_SERVER:integration/standaloneapp_info -b master > /dev/null 2>&1

    set +e
    if [ -f ${tmp_folder}/standaloneapp_info/swo_release.csv ]; then

        echo "****** Grep \"${branch_name},${apk_version},${module_name}\" ${tmp_folder}/standaloneapp_info/swo_release.csv"

        if ( grep -q ${branch_name},${apk_version},${module_name} ${tmp_folder}/standaloneapp_info/swo_release.csv );then
            echo "*********************************Error************************************"
            echo "The apk_version ${branch_name} ${apk_version} has been Official/Refused released."
            echo "**************************************************************************"

            exit 1
        fi
   fi
   set -e

   cd ${current_dir}

   trap - ERR
}


############################################################################
#release_checkpara
#Check release_checkpara
############################################################################
release_checkpara()
{
    echo "****** Check Release Parameter..."

    cd ${release_checkfolder}
 
    echo "****** Git Clone $SOURCE_SERVER:apps/qcom/${git_store_name} ${branch_name} -b ${branch_name}"
    git clone $SOURCE_SERVER:apps/qcom/${git_store_name} ${branch_name} -b ${branch_name} > /dev/null 2>&1

    cd ${release_checkfolder}/${branch_name}
    tagnumber=${branch_name}-RELEASE-${apk_version}

    if ( git tag |grep -w "${tagnumber}$" ); then
        git checkout ${tagnumber}
    else
        echo "*********************Error**********************************"
        echo "Can't find tag ${tagnumber} from ${branch_name}."
        echo "***********************************************************"
        exit 1
    fi

    cd ${release_checkfolder}
    if [ ${build_env} == "msm8998" ];then
        if [ -f ${release_checkfolder}/${branch_name}/AndroidManifest.xml ]; then
            var=`sed -n 's/.*android:versionName=\"\(.*\)\".*/\1/p' ${release_checkfolder}/${branch_name}/AndroidManifest.xml | grep -o "[0-9][0-9a-z.]*"`
            vercodetmp=`sed -n 's/.*android:versionCode=\"\(.*\)\"/\1/p' ${release_checkfolder}/${branch_name}/AndroidManifest.xml | grep -o "[0-9][0-9a-z.]*"`
        else
            echo "*********************Error**********************************"
            echo "Can't get versionName from AndroidManifest.xml             ."
            echo "***********************************************************"
            exit 1
        fi
    elif [ ${build_env} == "gradlen" ] || [ ${build_env} == "gradlem" ] ;then
        if [ -f ${release_checkfolder}/${branch_name}/app/build.gradle ]; then
            var=`sed -n 's/.*versionName *\"\(.*\)\".*/\1/p' ${release_checkfolder}/${branch_name}/app/build.gradle | grep -o "[0-9][0-9a-z.]*"`
            vercodetmp=`sed -n 's/.*versionCode *\(.*\)/\1/p' ${release_checkfolder}/${branch_name}/app/build.gradle | grep -o "[0-9][0-9a-z.]*"`
        else
            echo "*********************Error**********************************"
            echo "Can't get versionName from build.gradle."
            echo "***********************************************************"
            exit 1
        fi
    fi

    ver_code=$(echo $vercodetmp | cut -d' ' -f1)

    echo "****** AndroidManifest.xml versionName is v$var"
    echo "****** AndroidManifest.xml/build.gradle versionCode is $ver_code"

    if [ "${apk_version}" == "v${var}" ];then
        echo "****** ${apk_version} is Equal v${var}"
    else
        echo "********************error***************************************************"
        echo "Are you sure, you need release apk Branch=${branch_name} apk_version=${apk_version}"
        echo "${apk_version} is not equal v$var, pls check"
        echo "****************************************************************************"
        exit 1
    fi


    echo "****** Read Sign Mode"
    if [  ${build_env} == "msm8998" ];then
        if [ -f ${release_checkfolder}/${branch_name}/Android.mk ];then
            if !(grep "LOCAL_CERTIFICATE" -q ${branch_name}/Android.mk );then
                echo "****** WARING:${module_dir} has not been set LOCAL_CERTIFICATE, use testkey default."
                sign_mode="releasekey"
            else
                sign_mode=`grep "LOCAL_CERTIFICATE" ${branch_name}/Android.mk | sed s/[[:space:]]//g | cut -d'=' -f 2`
            fi
        else
            echo "*******************************Error******************************************"
            echo "Can't get Android.mk from ${git_store_name}"
            echo "******************************************************************************"

            exit 1
        fi
    elif [ ${build_env} == "gradlen" -o ${build_env} == "gradlem" ];then
        if [ -f ${release_checkfolder}/${branch_name}/app/build.gradle ];then
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
    cd ${current_dir}
}


release_createnotes()
{
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR

    cd ${releasenotespath}


    echo -e "Apk Version: ${apk_version}\n" >> ReleaseNotes.txt
    echo -e "Apk Url: ftp://acuteangleftp@192.168.31.245/APP_Release/${module_name}/${branch_name}/${apk_version}\n" >> ReleaseNotes.txt
    echo -e "Release Files:" >> ReleaseNotes.txt
    echo -e "${module_name}_${apk_version}_signed_${sign_mode_name}key.apk\n" >> ReleaseNotes.txt
    echo -e "Main Change:${main_change_select}\n" >> ReleaseNotes.txt
    echo -e "${main_change_input}\n" >> ReleaseNotes.txt
    mv -v ReleaseNotes.txt ${git_store_name}_${apk_version}_ReleaseNotes.txt

    trap - ERR
}

release_upload_sw()
{
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    cd ${current_dir}/acuteagapp_rel

    local prefix=$(pwd)

    echo "****** Upload Path:"${prefix}
    echo "****** Begin to Upload the Apk..."

    echo "****** ${scripts_dir}/upload_rel.exp ${module_name} ${release_dir} ${prefix} ${apk_version} ${PASSWD}"

    ${scripts_dir}/upload_rel.exp ${module_name} ${release_dir} ${prefix} ${apk_version} ${PASSWD}
    trap - ERR
}

getapkpackagename()
{
    if [ -f $tmp_folder/getaaptlist.txt ];then
        rm -f $tmp_folder/getaaptlist.txt
    fi

    ${tools_dir}/aapt list -v -a ${sync_path}/${apk_version}/$ApkNameSigned > $tmp_folder/getaaptlist.txt

    activityread=""
    serviceread=""
    shareduserid=""
    activityreadflag=true
    servicereadflag=true
    echo "****** Read Package Information From Apk..."

    FILTERAPKLIST=('Stored' 'resource' 'config' 'Deflate')

    for word in ${FILTERAPKLIST[@]}
    do
      sed -i "/"$word"/d" $tmp_folder/getaaptlist.txt
    done

    while read line;
    do
      if ( echo "$line" | grep "android:sharedUserId" ); then
        shareduserid=`echo "$line" | sed -n 's/.*android:sharedUserId.*=\"\(.*\)\".*\Raw: \".*/\1/p'`
      elif ( echo "$line" | grep "android:versionName" ); then
        version_name_final=`echo "$line" | sed -n 's/.*android:versionName.*=\"\(.*\)\".*\Raw: \".*/\1/p'`
      elif ( echo "$line" | grep "packageCount=" ); then
        packagenameread=`echo "$line" | sed -n 's/Package.*packageCount.*name=\(.*\)/\1/p'`
      elif [ $activityreadflag == false ] && ( echo "$line" | grep "android:name" ); then
        activityreadadd=`echo "$line" | sed -n 's/.*android:name.*=\"\(.*\)\".*\Raw: \".*/\1/p'`
        activityread="${activityread}#${activityreadadd}"
        activityreadflag=true
      elif [ $servicereadflag == false ] && ( echo "$line" | grep "android:name" ); then
        servicereadadd=`echo "$line" | sed -n 's/.*android:name.*=\"\(.*\)\".*\Raw: \".*/\1/p'`
        serviceread="${serviceread}#${servicereadadd}"
        servicereadflag=true
      elif ( echo "$line" | grep "E: activity" ); then
        activityreadflag=false
      elif ( echo "$line" | grep "E: service" ); then
        servicereadflag=false
      fi
    done < $tmp_folder/getaaptlist.txt

}

release_syncapkrele()
{
    cd ${current_dir}
  
    ApkNameSigned=${module_name}_${apk_version}_signed_${sign_mode_name}key.apk

    echo "****** Git Clone acuteag."
 
    if [ "${branch_name}" == "acuteag_dev_1.0.1" ];then
        acuteag_release_branch="LA.UM.6.4.1.r1"
    elif [ "${branch_name}" == "acuteag_master_1.0.1" ];then
        acuteag_release_branch="LA.UM.6.4.1.r1_master"
    fi

    if [ ! -d ${acuteag_dir} ];then
        git clone ${acuteag_release_dir}  ${acuteag_dir}
    else
        cd ${acuteag_dir}
        git reset --hard
        git clean -df 
        git checkout ${acuteag_release_branch}
        git pull
        cd ${current_dir}
    fi

    sync_path="${current_dir}/sync_${release_dir}_${apk_version}"

    if [ -d $sync_path ]; then
        rm -rf $sync_path
    fi

    mkdir $sync_path
    cd $sync_path


    echo "****** Check Apk Information on Project_Release Folder..."
    echo "****** ${scripts_dir}/download_check.sh ${module_name} ${release_dir} ${sync_path} ${apk_version} ${ApkNameSigned} ${acuteag_dir} ${acuteag_release_branch}"
    ${scripts_dir}/download_check.sh ${module_name} ${release_dir} ${sync_path} ${apk_version} ${ApkNameSigned} ${acuteag_dir}  ${acuteag_release_branch}
    if [ $? -ne 0 ]; then
        rm -rf $sync_path
        echo "*****************************Error****************************************"
        echo "sync error"
        echo "**************************************************************************"
        exit 1
    fi

    getapkpackagename
    rm -rf $sync_path
    cd ${current_dir}
}

release_updateinfo()
{
   trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
   cd ${current_dir}

   branch_num=${branch_name#${git_store_name}_}
   ver_code_out="I$ver_code"

   echo "****** [./int/common/updatesheet.sh \
   ${branch_name}             \
   ${apk_version}             \
   ${sign_mode}               \
   ${git_store_name}          \
   ${ver_code_out}            \
   ${version_name_final}      \
   ${packagenameread}         \
   ${activityread}            \
   ${serviceread}             \
   ${shareduserid}            \
   ${branch_info}]" 

   ./int/common/updatesheet.sh \
   ${branch_name}             \
   ${apk_version}             \
   ${sign_mode}               \
   ${git_store_name}          \
   ${ver_code_out}            \
   ${version_name_final}      \
   ${packagenameread}         \
   ${activityread}            \
   ${serviceread}             \
   ${shareduserid}            
   cd ${current_dir}
   trap - ERR
}

release_sendemail()
{
    echo "****** Send Email."

    now=$(date +%V.%w)
    nowint=$(echo "$now" | cut -d'.' -f1)
    newdec=$(echo "$now" | cut -d'.' -f2)

    let nowint+=1

    now="$nowint.$newdec"

    local VersionType="Internal"

    if [ ${branch_info} = 'None' ]; then
        mailsubject="[Acuteag App Rlease][${VersionType}]${module_name}\/${apk_version}\/W$now"
        echo "****** Mail Subject:${mailsubject}"
    else
	mailsubject="[Acuteag App Rlease][${VersionType}]${module_name}\/${apk_version}\/W$now --${branch_info} 【本邮件自动下发，请勿回复！】"
        echo "****** Mail Subject:${mailsubject}"
    fi

    cd ${current_dir}/sendemail 

    if [ -f ${current_dir}/../AcuteAngle_Generaltools/maillist/${git_store_name}.list ]; then
        while read mailname;
        do
            echo "******* mailname:${mailname}"
	    if [ -z ${MAIL_LIST} ];then
                MAIL_LIST="$mailname"
	    else
                MAIL_LIST="${MAIL_LIST},$mailname"
	    fi
        done < ${current_dir}/../AcuteAngle_Generaltools/maillist/${git_store_name}.list
    fi

    
    MAIL_LIST=`echo $MAIL_LIST | sed s/[[:space:]]//g`
    echo "**********Check Mail List *****"
    echo $MAIL_LIST
    echo "*******************************"

    if [ "$MAIL_LIST" == "" ]; then
        echo "*************************Error ***********************"
        echo "Mail list has not been set."
        echo "Please contact with integration@acuteangle.cn"
        echo "******************************************************"
        exit 1
    fi
    
    if [ -f ${current_dir}/int/common/acuteagapps_release_cc.list  ]; then
        while read mailname;
        do
            if [ -z ${MAIL_LIST_cc} ];then
		MAIL_LIST_cc="$mailname"
	    else
                MAIL_LIST_cc="${MAIL_LIST_cc},$mailname"
	    fi
        done <${current_dir}/int/common/acuteagapps_release_cc.list 
    else

        MAIL_LIST_cc="integration@acuteangle.cn"
    fi       
        
    echo "****** Mail_notice_list:${mail_notice_list}"

    if [ -n ${mail_notice_list} ];then
        for cc_name in ${mail_notice_list[@]}
        do
            echo "****** Add cc name:${cc_name}"
            MAIL_LIST_cc="${MAIL_LIST_cc},${cc_name}"
        done
    fi

    cp ./PythonTest.py ./PythonTest.py_original


    long_line=""

    while read line;
    do
        echo "****** Line:$line"
        long_line="${long_line}"$line"<br/>"
    done <${releasenotespath}/${git_store_name}_${apk_version}_ReleaseNotes.txt
    
    echo "****** Longline Is:"
    echo "********************************************"
    echo "$long_line"
    echo "********************************************"

    MAIL_LIST=`echo $MAIL_LIST | sed s/[[:space:]]//g`
    MAIL_LIST_cc=`echo $MAIL_LIST_cc | sed s/[[:space:]]//g`

    long_line=${long_line/"apk_version:"/"<font color=\"red\">${VersionType}</font> apk_version:"}

    sed -i -e "s/test@acuteangle.cn/$MAIL_LIST/" -e "s/cc@acuteangle.cn/$MAIL_LIST_cc/" -e "s/email test/$mailsubject/" ./PythonTest.py

    sed -i "s#emailboby#${long_line}#" ./PythonTest.py

    export PATH=/usr/bin/:$PATH

    python -V

    if [ -z ${MAIL_LIST}  ];then 
        echo "****** No Resolved Bugs today!" 
    else
        echo "***** Python ./PythonTest.py "
        #\"${releasenotespath}/${git_store_name}_${apk_version}_buglist.txt\"
        python ./PythonTest.py 
        #"${releasenotespath}/${git_store_name}_${apk_version}_buglist.txt
        echo "***** Send Mail Success!"
    fi

    echo "****** Reset PythonTest.py"
    mv ./PythonTest.py ./PythonTest.py_bak 
    mv ./PythonTest.py_original ./PythonTest.py

    echo "Release finished!"
}

release_init
release_update_tools
release_checkmodulename
release_checkinputlog
release_fetchinfo
release_check_dir
release_checkhistory
release_checkpara
release_createnotes
release_upload_sw
release_syncapkrele
release_updateinfo
release_sendemail
