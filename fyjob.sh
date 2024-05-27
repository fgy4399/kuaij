#!/bin/bash

export LC_ALL=C
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8


sudoCmd=""
if [[ $(/usr/bin/id -u) -ne 0 ]]; then
  sudoCmd="sudo"
fi


# fonts color
red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}
green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}
blue(){
    echo -e "\033[34m\033[01m$1\033[0m"
}
bold(){
    echo -e "\033[1m\033[01m$1\033[0m"
}



osCPU=""
osArchitecture="arm"
osInfo=""
osRelease=""
osReleaseVersion=""
osReleaseVersionNo=""
osReleaseVersionNoShort=""
osReleaseVersionCodeName="CodeName"
osSystemPackage=""
osSystemMdPath=""
osSystemShell="bash"

function checkArchitecture(){
	# https://stackoverflow.com/questions/48678152/how-to-detect-386-amd64-arm-or-arm64-os-architecture-via-shell-bash

	case $(uname -m) in
		i386)   osArchitecture="386" ;;
		i686)   osArchitecture="386" ;;
		x86_64) osArchitecture="amd64" ;;
		arm)    dpkg --print-architecture | grep -q "arm64" && osArchitecture="arm64" || osArchitecture="arm" ;;
		aarch64)    dpkg --print-architecture | grep -q "arm64" && osArchitecture="arm64" || osArchitecture="arm" ;;
		* )     osArchitecture="arm" ;;
	esac
}

function checkCPU(){
	osCPUText=$(cat /proc/cpuinfo | grep vendor_id | uniq)
	if [[ $osCPUText =~ "GenuineIntel" ]]; then
		osCPU="intel"
    elif [[ $osCPUText =~ "AMD" ]]; then
        osCPU="amd"
    else
        echo
    fi

	# green " Status 状态显示--当前CPU是: $osCPU"
}

# 检测系统版本号
getLinuxOSVersion(){
    if [[ -s /etc/redhat-release ]]; then
        osReleaseVersion=$(grep -oE '[0-9.]+' /etc/redhat-release)
    else
        osReleaseVersion=$(grep -oE '[0-9.]+' /etc/issue)
    fi

    # https://unix.stackexchange.com/questions/6345/how-can-i-get-distribution-name-and-version-number-in-a-simple-shell-script

    if [ -f /etc/os-release ]; then
        # freedesktop.org and systemd
        source /etc/os-release
        osInfo=$NAME
        osReleaseVersionNo=$VERSION_ID

        if [ -n "$VERSION_CODENAME" ]; then
            osReleaseVersionCodeName=$VERSION_CODENAME
        fi
    elif type lsb_release >/dev/null 2>&1; then
        # linuxbase.org
        osInfo=$(lsb_release -si)
        osReleaseVersionNo=$(lsb_release -sr)
    elif [ -f /etc/lsb-release ]; then
        # For some versions of Debian/Ubuntu without lsb_release command
        . /etc/lsb-release
        osInfo=$DISTRIB_ID
        
        osReleaseVersionNo=$DISTRIB_RELEASE
    elif [ -f /etc/debian_version ]; then
        # Older Debian/Ubuntu/etc.
        osInfo=Debian
        osReleaseVersion=$(cat /etc/debian_version)
        osReleaseVersionNo=$(sed 's/\..*//' /etc/debian_version)
    elif [ -f /etc/redhat-release ]; then
        osReleaseVersion=$(grep -oE '[0-9.]+' /etc/redhat-release)
    else
        # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
        osInfo=$(uname -s)
        osReleaseVersionNo=$(uname -r)
    fi

    osReleaseVersionNoShort=$(echo $osReleaseVersionNo | sed 's/\..*//')
}

# 检测系统发行版代号
function getLinuxOSRelease(){
    if [[ -f /etc/redhat-release ]]; then
        osRelease="centos"
        osSystemPackage="yum"
        osSystemMdPath="/usr/lib/systemd/system/"
        osReleaseVersionCodeName=""
    elif cat /etc/issue | grep -Eqi "debian|raspbian"; then
        osRelease="debian"
        osSystemPackage="apt-get"
        osSystemMdPath="/lib/systemd/system/"
        osReleaseVersionCodeName="buster"
    elif cat /etc/issue | grep -Eqi "ubuntu"; then
        osRelease="ubuntu"
        osSystemPackage="apt-get"
        osSystemMdPath="/lib/systemd/system/"
        osReleaseVersionCodeName="bionic"
    elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
        osRelease="centos"
        osSystemPackage="yum"
        osSystemMdPath="/usr/lib/systemd/system/"
        osReleaseVersionCodeName=""
    elif cat /proc/version | grep -Eqi "debian|raspbian"; then
        osRelease="debian"
        osSystemPackage="apt-get"
        osSystemMdPath="/lib/systemd/system/"
        osReleaseVersionCodeName="buster"
    elif cat /proc/version | grep -Eqi "ubuntu"; then
        osRelease="ubuntu"
        osSystemPackage="apt-get"
        osSystemMdPath="/lib/systemd/system/"
        osReleaseVersionCodeName="bionic"
    elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
        osRelease="centos"
        osSystemPackage="yum"
        osSystemMdPath="/usr/lib/systemd/system/"
        osReleaseVersionCodeName=""
    fi

    getLinuxOSVersion
    checkArchitecture
	checkCPU
    

    [[ -z $(echo $SHELL|grep zsh) ]] && osSystemShell="bash" || osSystemShell="zsh"

    green " OS info: ${osInfo}, ${osRelease}, ${osReleaseVersion}, ${osReleaseVersionNo}, ${osReleaseVersionCodeName}, ${osCPU} CPU ${osArchitecture}, ${osSystemShell}, ${osSystemPackage}, ${osSystemMdPath}"
}





function promptContinueOpeartion(){
	read -r -p "是否继续操作? 直接回车默认继续操作, 请输入[Y/n]:" isContinueInput
	isContinueInput=${isContinueInput:-Y}

	if [[ $isContinueInput == [Yy] ]]; then
		echo ""
	else 
		exit 1
	fi
}

osPort80=""
osPort443=""
osSELINUXCheck=""
osSELINUXCheckIsRebootInput=""

function testLinuxPortUsage(){
    $osSystemPackage -y install net-tools socat

    osPort80=$(netstat -tlpn | awk -F '[: ]+' '$1=="tcp"{print $5}' | grep -w 80)
    osPort443=$(netstat -tlpn | awk -F '[: ]+' '$1=="tcp"{print $5}' | grep -w 443)

    if [ -n "$osPort80" ]; then
        process80=$(netstat -tlpn | awk -F '[: ]+' '$5=="80"{print $9}')
        red "==========================================================="
        red "检测到80端口被占用，占用进程为：${process80} "
        red "==========================================================="
        promptContinueOpeartion
    fi

    if [ -n "$osPort443" ]; then
        process443=$(netstat -tlpn | awk -F '[: ]+' '$5=="443"{print $9}')
        red "============================================================="
        red "检测到443端口被占用，占用进程为：${process443} "
        red "============================================================="
        promptContinueOpeartion
    fi

    osSELINUXCheck=$(grep SELINUX= /etc/selinux/config | grep -v "#")
    if [ "$osSELINUXCheck" == "SELINUX=enforcing" ]; then
        red "======================================================================="
        red "检测到SELinux为开启强制模式状态, 为防止申请证书失败 将关闭SELinux. 请先重启VPS后，再执行本脚本"
        red "======================================================================="
        read -p "是否现在重启? 请输入 [Y/n] :" osSELINUXCheckIsRebootInput
        [ -z "${osSELINUXCheckIsRebootInput}" ] && osSELINUXCheckIsRebootInput="y"

        if [[ $osSELINUXCheckIsRebootInput == [Yy] ]]; then
            sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
            setenforce 0
            echo -e "VPS 重启中..."
            reboot
        fi
        exit
    fi

    if [ "$osSELINUXCheck" == "SELINUX=permissive" ]; then
        red "======================================================================="
        red "检测到SELinux为宽容模式状态, 为防止申请证书失败, 将关闭SELinux. 请先重启VPS后，再执行本脚本"
        red "======================================================================="
        read -p "是否现在重启? 请输入 [Y/n] :" osSELINUXCheckIsRebootInput
        [ -z "${osSELINUXCheckIsRebootInput}" ] && osSELINUXCheckIsRebootInput="y"

        if [[ $osSELINUXCheckIsRebootInput == [Yy] ]]; then
            sed -i 's/SELINUX=permissive/SELINUX=disabled/g' /etc/selinux/config
            setenforce 0
            echo -e "VPS 重启中..."
            reboot
        fi
        exit
    fi

    if [ "$osRelease" == "centos" ]; then
        if  [[ ${osReleaseVersionNoShort} == "6" || ${osReleaseVersionNoShort} == "5" ]]; then
            green " =================================================="
            red " 本脚本不支持 Centos 6 或 Centos 6 更早的版本"
            green " =================================================="
            exit
        fi

        red " 关闭防火墙 firewalld"
        ${sudoCmd} systemctl stop firewalld
        ${sudoCmd} systemctl disable firewalld

    elif [ "$osRelease" == "ubuntu" ]; then
        if  [[ ${osReleaseVersionNoShort} == "14" || ${osReleaseVersionNoShort} == "12" ]]; then
            green " =================================================="
            red " 本脚本不支持 Ubuntu 14 或 Ubuntu 14 更早的版本"
            green " =================================================="
            exit
        fi

        red " 关闭防火墙 ufw"
        ${sudoCmd} systemctl stop ufw
        ${sudoCmd} systemctl disable ufw
        ufw disable
        
    elif [ "$osRelease" == "debian" ]; then
        $osSystemPackage update -y
    fi

}

# 设置北京时区
function setLinuxDateZone(){

    tempCurrentDateZone=$(date +'%z')

    echo
    if [[ ${tempCurrentDateZone} == "+0800" ]]; then
        yellow "当前时区已经为北京时间  $tempCurrentDateZone | $(date -R) "
    else 
        green " =================================================="
        yellow " 当前时区为: $tempCurrentDateZone | $(date -R) "
        yellow " 是否设置时区为北京时间 +0800区, 以便cron定时重启脚本按照北京时间运行."
        green " =================================================="
        # read 默认值 https://stackoverflow.com/questions/2642585/read-a-variable-in-bash-with-a-default-value

        read -p "是否设置为北京时间 +0800 时区? 请输入[Y/n]:" osTimezoneInput
        osTimezoneInput=${osTimezoneInput:-Y}

        if [[ $osTimezoneInput == [Yy] ]]; then
            if [[ -f /etc/localtime ]] && [[ -f /usr/share/zoneinfo/Asia/Shanghai ]];  then
                mv /etc/localtime /etc/localtime.bak
                cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

                yellow " 设置成功! 当前时区已设置为 $(date -R)"
                green " =================================================="
            fi
        fi

    fi
    echo

    if [ "$osRelease" == "centos" ]; then   
        if  [[ ${osReleaseVersionNoShort} == "7" ]]; then
            systemctl stop chronyd
            systemctl disable chronyd

            $osSystemPackage -y install ntpdate
            $osSystemPackage -y install ntp
            ntpdate -q 0.rhel.pool.ntp.org
            systemctl enable ntpd
            systemctl restart ntpd
            ntpdate -u  pool.ntp.org

        elif  [[ ${osReleaseVersionNoShort} == "8" || ${osReleaseVersionNoShort} == "9" ]]; then
            $osSystemPackage -y install chrony
            systemctl enable chronyd
            systemctl restart chronyd

            firewall-cmd --permanent --add-service=ntp
            firewall-cmd --reload    

            chronyc sources

            echo
        fi
        
    else
        $osSystemPackage install -y ntp
        systemctl enable ntp
        systemctl restart ntp
    fi    
}

##########################################################


# 软件安装
function installSoftDownload(){
	if [[ "${osRelease}" == "debian" || "${osRelease}" == "ubuntu" ]]; then
		if ! dpkg -l | grep -qw wget; then
			${osSystemPackage} -y install wget git unzip curl apt-transport-https
			
			# https://stackoverflow.com/questions/11116704/check-if-vt-x-is-activated-without-having-to-reboot-in-linux
			${osSystemPackage} -y install cpu-checker
		fi

		if ! dpkg -l | grep -qw curl; then
			${osSystemPackage} -y install curl git unzip wget apt-transport-https
			
			${osSystemPackage} -y install cpu-checker
		fi

	elif [[ "${osRelease}" == "centos" ]]; then

        if  [[ ${osReleaseVersion} == "8.1.1911" || ${osReleaseVersion} == "8.2.2004" || ${osReleaseVersion} == "8.0.1905" ]]; then

            # https://techglimpse.com/failed-metadata-repo-appstream-centos-8/

            cd /etc/yum.repos.d/
            sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*
            sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*
            yum update -y

            sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-Linux-*
            sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-Linux-*

            ${sudoCmd} dnf install centos-release-stream -y
            ${sudoCmd} dnf swap centos-{linux,stream}-repos -y
            ${sudoCmd} dnf distro-sync -y
        fi
        
        if ! rpm -qa | grep -qw wget; then
		    ${osSystemPackage} -y install wget curl git unzip

        elif ! rpm -qa | grep -qw git; then
		    ${osSystemPackage} -y install wget curl git unzip
		fi
	fi
}













##########################################################################################

acmeSSLRegisterEmailInput=""
isDomainSSLGoogleEABKeyInput=""
isDomainSSLGoogleEABIdInput=""

function getHTTPSCertificateCheckEmail(){
    if [ -z $2 ]; then
        
        if [[ $1 == "email" ]]; then
            red " 输入邮箱地址不能为空, 请重新输入!"
            getHTTPSCertificateInputEmail
        elif [[ $1 == "googleEabKey" ]]; then
            red " 输入EAB key 不能为空, 请重新输入!"
            getHTTPSCertificateInputGoogleEABKey
        elif [[ $1 == "googleEabId" ]]; then
            red " 输入EAB Id 不能为空, 请重新输入!"
            getHTTPSCertificateInputGoogleEABId            
        fi
    fi
}
function getHTTPSCertificateInputEmail(){
    echo
    read -r -p "请输入邮箱地址, 用于申请证书:" acmeSSLRegisterEmailInput
    getHTTPSCertificateCheckEmail "email" "${acmeSSLRegisterEmailInput}"
}
function getHTTPSCertificateInputGoogleEABKey(){
    echo
    read -r -p "请输入 Google EAB key :" isDomainSSLGoogleEABKeyInput
    getHTTPSCertificateCheckEmail "googleEabKey" "${isDomainSSLGoogleEABKeyInput}"
}
function getHTTPSCertificateInputGoogleEABId(){
    echo
    read -r -p "请输入 Google EAB id :" isDomainSSLGoogleEABIdInput
    getHTTPSCertificateCheckEmail "googleEabId" "${isDomainSSLGoogleEABIdInput}"
}

configNetworkRealIp=""
configSSLDomain=""

acmeSSLDays="89"
acmeSSLServerName="letsencrypt"
acmeSSLDNSProvider="dns_cf"

configRanPath="${HOME}/ran"
configSSLAcmeScriptPath="${HOME}/.acme.sh"
configWebsiteFatherPath="/nginxweb"
configSSLCertPath="${configWebsiteFatherPath}/cert"
configSSLCertPathV2board="${configWebsiteFatherPath}/cert/v2board"
configSSLCertKeyFilename="server.key"
configSSLCertFullchainFilename="server.crt"




function getHTTPSCertificateWithAcme(){

    # 申请https证书
	mkdir -p ${configSSLCertPath}
	mkdir -p ${configWebsitePath}
	curl https://get.acme.sh | sh

    echo
    green " ================================================== "
    green " 请选择证书提供商, 默认通过 Letsencrypt.org 来申请证书 "
    green " 如果证书申请失败, 例如一天内通过 Letsencrypt.org 申请次数过多, 可选 BuyPass.com 或 ZeroSSL.com 来申请."
    green " 1 Letsencrypt.org "
    green " 2 BuyPass.com "
    green " 3 ZeroSSL.com "
    green " 4 Google Public CA "
    echo
    read -r -p "请选择证书提供商? 默认直接回车为通过 Letsencrypt.org 申请, 请输入纯数字:" isDomainSSLFromLetInput
    isDomainSSLFromLetInput=${isDomainSSLFromLetInput:-1}
    
    if [[ "$isDomainSSLFromLetInput" == "2" ]]; then
        getHTTPSCertificateInputEmail
        acmeSSLDays="179"
        acmeSSLServerName="buypass"
        echo
        ${configSSLAcmeScriptPath}/acme.sh --register-account --accountemail ${acmeSSLRegisterEmailInput} --server buypass
        
    elif [[ "$isDomainSSLFromLetInput" == "3" ]]; then
        getHTTPSCertificateInputEmail
        acmeSSLServerName="zerossl"
        echo
        ${configSSLAcmeScriptPath}/acme.sh --register-account -m ${acmeSSLRegisterEmailInput} --server zerossl

    elif [[ "$isDomainSSLFromLetInput" == "4" ]]; then
        green " ================================================== "
        yellow " 请先按照如下链接申请 google Public CA  https://hostloc.com/thread-993780-1-1.html"
        yellow " 具体可参考 https://github.com/acmesh-official/acme.sh/wiki/Google-Public-CA"
        getHTTPSCertificateInputEmail
        acmeSSLServerName="google"
        getHTTPSCertificateInputGoogleEABKey
        getHTTPSCertificateInputGoogleEABId
        ${configSSLAcmeScriptPath}/acme.sh --register-account -m ${acmeSSLRegisterEmailInput} --server google --eab-kid ${isDomainSSLGoogleEABIdInput} --eab-hmac-key ${isDomainSSLGoogleEABKeyInput}    
    else
        acmeSSLServerName="letsencrypt"
        #${configSSLAcmeScriptPath}/acme.sh --issue -d ${configSSLDomain} --webroot ${configWebsitePath} --keylength ec-256 --days 89 --server letsencrypt
    fi


    echo
    green " ================================================== "
    green " 请选择 acme.sh 脚本申请SSL证书方式: 1 http方式, 2 dns方式 "
    green " 默认直接回车为 http 申请方式, 选否则为 dns 方式"
    echo
    read -r -p "请选择SSL证书申请方式 ? 默认直接回车为http方式, 选否则为 dns 方式申请证书, 请输入[Y/n]:" isAcmeSSLRequestMethodInput
    isAcmeSSLRequestMethodInput=${isAcmeSSLRequestMethodInput:-Y}
    echo

    if [[ $isAcmeSSLRequestMethodInput == [Yy] ]]; then
        acmeSSLHttpWebrootMode=""

        if [[ "${isInstallNginx}" == "true" ]]; then
            acmeDefaultValue="3"
            acmeDefaultText="3. webroot 并使用ran作为临时的Web服务器"
            acmeSSLHttpWebrootMode="webrootran"
        else
            acmeDefaultValue="1"
            acmeDefaultText="1. standalone 模式"
            acmeSSLHttpWebrootMode="standalone"
        fi

        if [ -z "$1" ]; then
            green " ================================================== "
            green " 请选择 http 申请证书方式: 默认直接回车为 ${acmeDefaultText} "
            green " 1 standalone 模式, 适合没有安装Web服务器, 如已选择不安装Nginx 请选择此模式. 请确保80端口不被占用. 注意:三个月后续签时80端口被占用会导致续签失败!"
            green " 2 webroot 模式, 适合已经安装Web服务器, 例如 Caddy Apache 或 Nginx, 请确保Web服务器已经运行在80端口"
            green " 3 webroot 模式 并使用 ran 作为临时的Web服务器, 如已选择同时安装Nginx，请使用此模式, 可以正常续签"
            green " 4 nginx 模式 适合已经安装 Nginx, 请确保 Nginx 已经运行"
            echo
            read -r -p "请选择http申请证书方式? 默认为 ${acmeDefaultText}, 请输入纯数字:" isAcmeSSLWebrootModeInput
       
            isAcmeSSLWebrootModeInput=${isAcmeSSLWebrootModeInput:-${acmeDefaultValue}}
            
            if [[ ${isAcmeSSLWebrootModeInput} == "1" ]]; then
                acmeSSLHttpWebrootMode="standalone"
            elif [[ ${isAcmeSSLWebrootModeInput} == "2" ]]; then
                acmeSSLHttpWebrootMode="webroot"
            elif [[ ${isAcmeSSLWebrootModeInput} == "4" ]]; then
                acmeSSLHttpWebrootMode="nginx"
            else
                acmeSSLHttpWebrootMode="webrootran"
            fi
        else
            if [[ $1 == "standalone" ]]; then
                acmeSSLHttpWebrootMode="standalone"
            elif [[ $1 == "webroot" ]]; then
                acmeSSLHttpWebrootMode="webroot"
            elif [[ $1 == "webrootran" ]] ; then
                acmeSSLHttpWebrootMode="webrootran"
            elif [[ $1 == "nginx" ]] ; then
                acmeSSLHttpWebrootMode="nginx"
            fi
        fi

        echo
        if [[ ${acmeSSLHttpWebrootMode} == "standalone" ]] ; then
            green " 开始申请证书 acme.sh 通过 http standalone mode 从 ${acmeSSLServerName} 申请, 请确保80端口不被占用 "
            
            echo
            ${configSSLAcmeScriptPath}/acme.sh --issue -d ${configSSLDomain} --standalone --keylength ec-256 --days ${acmeSSLDays} --server ${acmeSSLServerName}
        
        elif [[ ${acmeSSLHttpWebrootMode} == "webroot" ]] ; then
            green " 开始申请证书, acme.sh 通过 http webroot mode 从 ${acmeSSLServerName} 申请, 请确保web服务器 例如 nginx 已经运行在80端口 "
            
            echo
            read -r -p "请输入Web服务器的html网站根目录路径? 例如/usr/share/nginx/html:" isDomainSSLNginxWebrootFolderInput
            echo " 您输入的网站根目录路径为 ${isDomainSSLNginxWebrootFolderInput}"

            if [ -z ${isDomainSSLNginxWebrootFolderInput} ]; then
                red " 输入的Web服务器的 html网站根目录路径不能为空, 网站根目录将默认设置为 ${configWebsitePath}, 请修改你的web服务器配置后再申请证书!"
                
            else
                configWebsitePath="${isDomainSSLNginxWebrootFolderInput}"
            fi
            
            echo
            ${configSSLAcmeScriptPath}/acme.sh --issue -d ${configSSLDomain} --webroot ${configWebsitePath} --keylength ec-256 --days ${acmeSSLDays} --server ${acmeSSLServerName}
        
        elif [[ ${acmeSSLHttpWebrootMode} == "nginx" ]] ; then
            green " 开始申请证书, acme.sh 通过 http nginx mode 从 ${acmeSSLServerName} 申请, 请确保web服务器 nginx 已经运行 "
            
            echo
            ${configSSLAcmeScriptPath}/acme.sh --issue -d ${configSSLDomain} --nginx --keylength ec-256 --days ${acmeSSLDays} --server ${acmeSSLServerName}

        elif [[ ${acmeSSLHttpWebrootMode} == "webrootran" ]] ; then

            # https://github.com/m3ng9i/ran/issues/10

            ranDownloadUrl="https://github.com/m3ng9i/ran/releases/download/v0.1.6/ran_linux_amd64.zip"
            ranDownloadFileName="ran_linux_amd64"
            
            if [[ "${osArchitecture}" == "arm64" || "${osArchitecture}" == "arm" ]]; then
                ranDownloadUrl="https://github.com/m3ng9i/ran/releases/download/v0.1.6/ran_linux_arm64.zip"
                ranDownloadFileName="ran_linux_arm64"
            fi


            mkdir -p ${configRanPath}
            
            if [[ -f "${configRanPath}/${ranDownloadFileName}" ]]; then
                green " 检测到 ran 已经下载过, 准备启动 ran 临时的web服务器 "
            else
                green " 开始下载 ran 作为临时的web服务器 "
                downloadAndUnzip "${ranDownloadUrl}" "${configRanPath}" "${ranDownloadFileName}" 
                chmod +x "${configRanPath}/${ranDownloadFileName}"
            fi

            echo "nohup ${configRanPath}/${ranDownloadFileName} -l=false -g=false -sa=true -p=80 -r=${configWebsitePath} >/dev/null 2>&1 &"
            nohup ${configRanPath}/${ranDownloadFileName} -l=false -g=false -sa=true -p=80 -r=${configWebsitePath} >/dev/null 2>&1 &
            echo
            
            green " 开始申请证书, acme.sh 通过 http webroot mode 从 ${acmeSSLServerName} 申请, 并使用 ran 作为临时的web服务器 "
            echo
            ${configSSLAcmeScriptPath}/acme.sh --issue -d ${configSSLDomain} --webroot ${configWebsitePath} --keylength ec-256 --days ${acmeSSLDays} --server ${acmeSSLServerName}

            sleep 4
            ps -C ${ranDownloadFileName} -o pid= | xargs -I {} kill {}
        fi

    else
        green " 开始申请证书, acme.sh 通过 dns mode 申请 "

        echo
        green "请选择 DNS provider DNS 提供商: 1 CloudFlare, 2 AliYun,  3 DNSPod(Tencent), 4 GoDaddy "
        red "注意 CloudFlare 针对某些免费域名例如 .tk .cf 等  不再支持使用API 申请DNS证书 "
        echo
        read -r -p "请选择 DNS 提供商 ? 默认直接回车为 1. CloudFlare, 请输入纯数字:" isAcmeSSLDNSProviderInput
        isAcmeSSLDNSProviderInput=${isAcmeSSLDNSProviderInput:-1}    

        
        if [ "$isAcmeSSLDNSProviderInput" == "2" ]; then
            read -r -p "Please Input Ali Key: " Ali_Key
            export Ali_Key="${Ali_Key}"
            read -r -p "Please Input Ali Secret: " Ali_Secret
            export Ali_Secret="${Ali_Secret}"
            acmeSSLDNSProvider="dns_ali"

        elif [ "$isAcmeSSLDNSProviderInput" == "3" ]; then
            read -r -p "Please Input DNSPod API ID: " DP_Id
            export DP_Id="${DP_Id}"
            read -r -p "Please Input DNSPod API Key: " DP_Key
            export DP_Key="${DP_Key}"
            acmeSSLDNSProvider="dns_dp"

        elif [ "$isAcmeSSLDNSProviderInput" == "4" ]; then
            read -r -p "Please Input GoDaddy API Key: " gd_Key
            export GD_Key="${gd_Key}"
            read -r -p "Please Input GoDaddy API Secret: " gd_Secret
            export GD_Secret="${gd_Secret}"
            acmeSSLDNSProvider="dns_gd"

        else
            read -r -p "Please Input CloudFlare Email: " cf_email
            export CF_Email="${cf_email}"
            read -r -p "Please Input CloudFlare Global API Key: " cf_key
            export CF_Key="${cf_key}"
            acmeSSLDNSProvider="dns_cf"
        fi
        
        echo
        ${configSSLAcmeScriptPath}/acme.sh --issue -d "${configSSLDomain}" --dns ${acmeSSLDNSProvider} --force --keylength ec-256 --server ${acmeSSLServerName} --debug 
        
    fi

    echo
    if [[ ${isAcmeSSLWebrootModeInput} == "1" ]]; then
        ${configSSLAcmeScriptPath}/acme.sh --installcert --ecc -d ${configSSLDomain} \
        --key-file ${configSSLCertPath}/${configSSLCertKeyFilename} \
        --fullchain-file ${configSSLCertPath}/${configSSLCertFullchainFilename} 
    else
        ${configSSLAcmeScriptPath}/acme.sh --installcert --ecc -d ${configSSLDomain} \
        --key-file ${configSSLCertPath}/${configSSLCertKeyFilename} \
        --fullchain-file ${configSSLCertPath}/${configSSLCertFullchainFilename} \
        --reloadcmd "systemctl restart nginx.service"
    fi
    green " ================================================== "

}



function compareRealIpWithLocalIp(){
    echo
    echo
    green " 是否检测域名指向的IP正确 直接回车默认检测"
    red " 如果域名指向的IP不是本机IP, 或已开启CDN不方便关闭 或只有IPv6的VPS 可以选否不检测"
    read -r -p "是否检测域名指向的IP正确? 请输入[Y/n]:" isDomainValidInput
    isDomainValidInput=${isDomainValidInput:-Y}

    if [[ $isDomainValidInput == [Yy] ]]; then
        if [ -n "$1" ]; then
            configNetworkRealIp=$(ping $1 -c 1 | sed '1{s/[^(]*(//;s/).*//;q}')
            # https://unix.stackexchange.com/questions/22615/how-can-i-get-my-external-ip-address-in-a-shell-script
            configNetworkLocalIp1="$(curl http://whatismyip.akamai.com/)"
            configNetworkLocalIp2="$(curl https://checkip.amazonaws.com/)"
            #configNetworkLocalIp3="$(curl https://ipv4.icanhazip.com/)"
            #configNetworkLocalIp4="$(curl https://v4.ident.me/)"
            #configNetworkLocalIp5="$(curl https://api.ip.sb/ip)"
            #configNetworkLocalIp6="$(curl https://ipinfo.io/ip)"
            
            #configNetworkLocalIPv61="$(curl https://ipv6.icanhazip.com/)"
            #configNetworkLocalIPv62="$(curl https://v6.ident.me/)"

            green " ================================================== "
            green " 域名解析地址为 ${configNetworkRealIp}, 本VPS的IP为 ${configNetworkLocalIp1} "

            echo
            if [[ ${configNetworkRealIp} == "${configNetworkLocalIp1}" || ${configNetworkRealIp} == "${configNetworkLocalIp2}" ]] ; then

                green " 域名解析的IP正常!"
                green " ================================================== "
                true
            else
                red " 域名解析地址与本VPS的IP地址不一致!"
                red " 本次安装失败，请确保域名解析正常, 请检查域名和DNS是否生效!"
                green " ================================================== "
                false
            fi
        else
            green " ================================================== "        
            red "     域名输入错误!"
            green " ================================================== "        
            false
        fi
        
    else
        green " ================================================== "
        green "     不检测域名解析是否正确!"
        green " ================================================== "
        true
    fi
}



acmeSSLRegisterEmailInput=""
isDomainSSLGoogleEABKeyInput=""
isDomainSSLGoogleEABIdInput=""



function getHTTPSCertificateStep1(){

    testLinuxPortUsage

    echo
    green " ================================================== "
    yellow " 请输入绑定到本VPS的域名 例如www.xxx.com: (此步骤请关闭CDN后和nginx后安装 避免80端口占用导致申请证书失败)"
    read -r -p "请输入解析到本VPS的域名:" configSSLDomain
    
    if compareRealIpWithLocalIp "${configSSLDomain}" ; then
        echo
        green " =================================================="
        green " 是否申请证书? 默认直接回车为申请证书, 如第二次安装或已有证书 可以选否"
        green " 如果已经有SSL证书文件 请放到下面路径"
        red " ${configSSLDomain} 域名证书内容文件路径 ${configSSLCertPath}/${configSSLCertFullchainFilename} "
        red " ${configSSLDomain} 域名证书私钥文件路径 ${configSSLCertPath}/${configSSLCertKeyFilename} "
        echo

        read -r -p "是否申请证书? 默认直接回车为自动申请证书,请输入[Y/n]?" isDomainSSLRequestInput
        isDomainSSLRequestInput=${isDomainSSLRequestInput:-Y}

        if [[ $isDomainSSLRequestInput == [Yy] ]]; then
            
            getHTTPSCertificateWithAcme ""

            if test -s "${configSSLCertPath}/${configSSLCertFullchainFilename}"; then
                green " =================================================="
                green "   域名SSL证书申请成功 !"
                green " ${configSSLDomain} 域名证书内容文件路径 ${configSSLCertPath}/${configSSLCertFullchainFilename} "
                green " ${configSSLDomain} 域名证书私钥文件路径 ${configSSLCertPath}/${configSSLCertKeyFilename} "
                green " =================================================="

            else
                red "==================================="
                red " https证书没有申请成功，安装失败!"
                red " 请检查域名和DNS是否生效, 同一域名请不要一天内多次申请!"
                red " 请检查80和443端口是否开启, VPS服务商可能需要添加额外防火墙规则，例如阿里云、谷歌云等!"
                red " 重启VPS, 重新执行脚本, 可重新选择修复证书选项再次申请证书 ! "
                red "==================================="
                exit
            fi

        else
            green " =================================================="
            green "  不申请域名的证书, 请把证书放到如下目录, 或自行修改配置!"
            green "  ${configSSLDomain} 域名证书内容文件路径 ${configSSLCertPath}/${configSSLCertFullchainFilename} "
            green "  ${configSSLDomain} 域名证书私钥文件路径 ${configSSLCertPath}/${configSSLCertKeyFilename} "
            green " =================================================="
        fi
    else
        exit
    fi

}








############################################################################


function installXUI(){
	
	bash <(curl -Ls https://raw.githubusercontent.com/vaxilu/x-ui/master/install.sh)

}

function installXUI2(){

	### bash <(curl -Ls https://raw.githubusercontent.com/FranzKafkaYu/x-ui/master/install.sh)
	bash <(curl -Ls https://gitlab.com/misakablog/x-ui/-/raw/main/install.sh)

}


function installWARP(){

	bash <(curl -Ls https://raw.githubusercontent.com/fgy4399/kuaij/main/CFwarp.sh)

}

function installWARP2(){

	wget -N https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh && bash menu.sh

}



function installWARP3(){

	wget -N https://gitlab.com/fscarmen/warp/-/raw/main/warp-go.sh && bash warp-go.sh


}

function upgradeScript(){
    wget -Nq --no-check-certificate -O ./linux_install_software.sh "https://raw.githubusercontent.com/jinwyp/one_click_script/master/linux_install_software.sh"
    green " 本脚本升级成功! "
    chmod +x ./linux_install_software.sh
    sleep 2s
    exec "./linux_install_software.sh"
}




function downLoad(){
	wget -Nq --no-check-certificate -O ./fyjob.sh "https://raw.githubusercontent.com/fgy4399/kuaij/main/fyjob.sh"
	chmod +x ./fyjob.sh
}


debian(){
	curl -fLO https://raw.githubusercontent.com/bohanyang/debi/master/debi.sh && chmod a+rx debi.sh && ./debi.sh --install 'curl wget neofetch htop net-tools git' --hostname fgy4399 --bbr --timezone Asia/Shanghai --cloud-kernel --user root --password ffffff && shutdown -r now
}


gost(){
	bash <(curl -Ls https://raw.githubusercontent.com/fgy4399/kuaij/main/gost.sh)	
}

vpsTest(){
	bash <(wget -qO- --no-check-certificate https://gitlab.com/spiritysdx/za/-/raw/main/ecs.sh)
}

LMTTest(){
	bash <(curl -L -s https://raw.githubusercontent.com/lmc999/RegionRestrictionCheck/main/check.sh)
}

SWHTTest(){
	curl https://raw.githubusercontent.com/zhucaidan/mtr_trace/main/mtr_trace.sh|bash
}

SWTest(){
	bash <(curl -Lso- https://git.io/superspeed_uxh)
}

addSwap(){
	bash <(curl -Lso- https://www.moerats.com/usr/shell/swap.sh)
}

installAAP(){
	bash <(curl -Lso- http://www.aapanel.com/script/install-ubuntu_6.0_en.sh aapanel)
}

ipCut(){
    ipYuan(){
    	wget -Nq --no-check-certificate -O /usr/local/etc/xray/config.json "https://raw.githubusercontent.com/fgy4399/kuaij/main/xrayConfig/config.json"
	airu restart
    }
    
    ipWarp(){
    	wget -Nq --no-check-certificate -O /usr/local/etc/xray/config.json "https://raw.githubusercontent.com/fgy4399/kuaij/main/xrayConfig/configWarp.json"
	mport=`warp-cli --accept-tos settings 2>/dev/null | grep 'WarpProxy on port' | awk -F "port " '{print $2}'`
	mport2=`cat /usr/local/etc/xray/config.json 2>/dev/null | grep -o '"port.*' | tail -n1`
	sed -i "s/$mport2/\"port\": $mport/g" /usr/local/etc/xray/config.json
	
	airu restart
    }


    green " ========切换访问奈飞出口========"
    green " 1. 切换Xray原IP出口"
    green " 2. 切换Xray至Socks5-WARP出口"
    green " 0. 返回主菜单"

    echo
    read -p "Please input number:" NumberInput
    case "$NumberInput" in
    	
        	1 )
          ipYuan
        ;;
		2 )
          ipWarp
        ;;
		0 )
           start_menu
        ;;
	
        	* )
           clear
           red "请输入正确数字 !"
           sleep 2s
           ipCut
        ;;
    esac
}

function start_menu(){
    downLoad
    clear

    if [[ $1 == "first" ]] ; then
        getLinuxOSRelease
        installSoftDownload
    fi

    
    green " =================================================="
    green " Linux 常用工具 一键安装脚本 | 2022-8-15 | 系统支持：centos7+ / debian9+ / ubuntu16.04+"
    green " =================================================="
    green " 1. 申请域名SSL证书"
	green " 2. 安装X-UI面板(原版)"
	green " 3. 安装X-UI面板(修改版)"
	green " 4. WARP_kkkyg"
	green " 5. WARP_fscsrmen"
	green " 6. WARP-GO_fscsrmen"
	green " 7. 工具集合"
	green " 8. DD最新的diban11系统默认密码ffffff"
	green " 9. 安装Gost"
	green " 10. VPS测评"
	green " 11. 切换访问奈菲出口"
	green " 12. 流媒体解锁检测"
	green " 13. 三网回程测试"
	green " 14. 三网测速"
 	green " 15. 添加Swap内存"
  	green " 16. 安装aapanel面板"

    green " 0. exit"

    


    echo
    read -p "Please input number:" menuNumberInput
    case "$menuNumberInput" in
        1 )
            getHTTPSCertificateStep1
        ;;
		2 )
            installXUI
        ;;
		3 )
            installXUI2
        ;;
		4 )
            installWARP
        ;;
		5 )
            installWARP2
        ;;
		6 )
            installWARP3
        ;;
		7 )
            upgradeScript
        ;;
		8 )
            debian
        ;;
		9 )
            gost
        ;;
		10 )
            vpsTest
        ;;
		11 )
            ipCut
        ;;
		12 )
            LMTTest
        ;;
		13 )
            SWHTTest
        ;;
		14 )
            SWTest
        ;;
		15 )
            addSwap
        ;;
		16 )
            installAAP
        ;;
        0 )
            exit 1
        ;;
	
        * )
            clear
            red "请输入正确数字 !"
            sleep 2s
            start_menu
        ;;
    esac
}

start_menu
