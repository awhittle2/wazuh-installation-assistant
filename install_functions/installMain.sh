# Wazuh installer - main functions
# Copyright (C) 2015, Wazuh Inc.
#
# This program is a free software; you can redistribute it
# and/or modify it under the terms of the GNU General Public
# License (version 2) as published by the FSF - Free Software
# Foundation.

function getHelp() {

    echo -e ""
    echo -e "NAME"
    echo -e "        $(basename "$0") - Install and configure Wazuh central components: Wazuh server, Wazuh indexer, and Wazuh dashboard."
    echo -e ""
    echo -e "SYNOPSIS"
    echo -e "        $(basename "$0") [OPTIONS] -a | -c | -s | -wi <indexer-node-name> | -wd <dashboard-node-name> | -ws <server-node-name>"
    echo -e ""
    echo -e "DESCRIPTION"
    echo -e "        -a,  --all-in-one"
    echo -e "                Install and configure Wazuh server, Wazuh indexer, Wazuh dashboard."
    echo -e ""
    echo -e "        -c,  --config-file <path-to-config-yml>"
    echo -e "                Path to the configuration file used to generate wazuh-install-files.tar file containing the files that will be needed for installation. By default, the Wazuh installation assistant will search for a file named config.yml in the same path as the script."
    echo -e ""
    echo -e "        -d [pre-release|staging],  --development"
    echo -e "                Use development repositories. By default it uses the pre-release package repository. If staging is specified, it will use that repository."
    echo -e ""
    echo -e "        -dw,  --download-wazuh <deb|rpm>"
    echo -e "                Download all the packages necessary for offline installation. Type of packages to download for offline installation (rpm, deb)"
    echo -e ""
    echo -e "        -da,  --download-arch <amd64|arm64|x86_64|aarch64>"
    echo -e "                Define the architecture of the packages to download for offline installation."
    echo -e ""
    echo -e "        -fd,  --force-install-dashboard"
    echo -e "                Force Wazuh dashboard installation to continue even when it is not capable of connecting to the Wazuh indexer."
    echo -e ""
    echo -e "        -g,  --generate-config-files"
    echo -e "                Generate wazuh-install-files.tar file containing the files that will be needed for installation from config.yml. In distributed deployments you will need to copy this file to all hosts."
    echo -e ""
    echo -e "        -h,  --help"
    echo -e "                Display this help and exit."
    echo -e ""
    echo -e "        -i,  --ignore-check"
    echo -e "                Ignore the check for minimum hardware requirements."
    echo -e ""
    echo -e "        -o,  --overwrite"
    echo -e "                Overwrites previously installed components. This will erase all the existing configuration and data."
    echo -e ""
    echo -e "        -of,  --offline-installation"
    echo -e "                Perform an offline installation. This option must be used with -a, -ws, -s, -wi, or -wd."
    echo -e ""
    echo -e "        -p,  --port"
    echo -e "                Specifies the Wazuh web user interface port. By default is the 443 TCP port. Recommended ports are: 8443, 8444, 8080, 8888, 9000."
    echo -e ""
    echo -e "        -s,  --start-cluster"
    echo -e "                Initialize Wazuh indexer cluster security settings."
    echo -e ""
    echo -e "        -t,  --tar <path-to-certs-tar>"
    echo -e "                Path to tar file containing certificate files. By default, the Wazuh installation assistant will search for a file named wazuh-install-files.tar in the same path as the script."
    echo -e ""
    echo -e "        -u,  --uninstall"
    echo -e "                Uninstalls all Wazuh components. This will erase all the existing configuration and data."
    echo -e ""
    echo -e "        -v,  --verbose"
    echo -e "                Shows the complete installation output."
    echo -e ""
    echo -e "        -V,  --version"
    echo -e "                Shows the version of the script and Wazuh packages."
    echo -e ""
    echo -e "        -wd,  --wazuh-dashboard <dashboard-node-name>"
    echo -e "                Install and configure Wazuh dashboard, used for distributed deployments."
    echo -e ""
    echo -e "        -wi,  --wazuh-indexer <indexer-node-name>"
    echo -e "                Install and configure Wazuh indexer, used for distributed deployments."
    echo -e ""
    echo -e "        -ws,  --wazuh-server <server-node-name>"
    echo -e "                Install and configure Wazuh manager and Filebeat, used for distributed deployments."
    exit 1

}


function main() {
    umask 177

    if [ -z "${1}" ]; then
        getHelp
    fi

    while [ -n "${1}" ]
    do
        case "${1}" in
            "-a"|"--all-in-one")
                AIO=1
                shift 1
                ;;
            "-c"|"--config-file")
                if [ -z "${2}" ]; then
                    common_logger -e "Error on arguments. Probably missing <path-to-config-yml> after -c|--config-file"
                    getHelp
                    exit 1
                fi
                file_conf=1
                config_file="${2}"
                shift 2
                ;;
            "-d"|"--development")
                development=1
                if [ -n "${2}" ] && [[ ! "${2}" =~ ^- ]]; then
                    if [ "${2}" = "pre-release" ] || [ "${2}" = "staging" ]; then
                        devrepo="${2}"
                    else
                        common_logger -e "Error: Invalid value '${2}' after -d|--development. Accepted values are 'pre-release' or 'staging'."
                        getHelp
                        exit 1
                    fi
                    shift 2
                else
                    devrepo="pre-release"
                    shift 1
                fi
                checks_development_source_tag
                repogpg="https://packages-dev.wazuh.com/key/GPG-KEY-WAZUH"
                repobaseurl="https://packages-dev.wazuh.com/${devrepo}"
                reporelease="unstable"
                filebeat_wazuh_template="https://raw.githubusercontent.com/wazuh/wazuh/${source_branch}/extensions/elasticsearch/7.x/wazuh-template.json"
                filebeat_wazuh_module="${repobaseurl}/filebeat/wazuh-filebeat-0.4.tar.gz"
                bucket="packages-dev.wazuh.com"
                repository="${devrepo}"
                ;;

            "-fd"|"--force-install-dashboard")
                force=1
                shift 1
                ;;
            "-g"|"--generate-config-files")
                configurations=1
                shift 1
                ;;
            "-h"|"--help")
                getHelp
                ;;
            "-i"|"--ignore-check")
                ignore=1
                shift 1
                ;;
            "-o"|"--overwrite")
                overwrite=1
                shift 1
                ;;
            "-of"|"--offline-installation")
                offline_install=1
                shift 1
                ;;
            "-p"|"--port")
                if [ -z "${2}" ]; then
                    common_logger -e "Error on arguments. Probably missing <port> after -p|--port"
                    getHelp
                    exit 1
                fi
                port_specified=1
                port_number="${2}"
                shift 2
                ;;
            "-s"|"--start-cluster")
                start_indexer_cluster=1
                shift 1
                ;;
            "-t"|"--tar")
                if [ -z "${2}" ]; then
                    common_logger -e "Error on arguments. Probably missing <path-to-certs-tar> after -t|--tar"
                    getHelp
                    exit 1
                fi
                tar_conf=1
                tar_file="${2}"
                shift 2
                ;;
            "-u"|"--uninstall")
                uninstall=1
                shift 1
                ;;
            "-v"|"--verbose")
                debugEnabled=1
                debug="2>&1 | tee -a ${logfile}"
                shift 1
                ;;
            "-V"|"--version")
                showVersion=1
                shift 1
                ;;
            "-wd"|"--wazuh-dashboard")
                if [ -z "${2}" ]; then
                    common_logger -e "Error on arguments. Probably missing <node-name> after -wd|---wazuh-dashboard"
                    getHelp
                    exit 1
                fi
                dashboard=1
                dashname="${2}"
                shift 2
                ;;
            "-wi"|"--wazuh-indexer")
                if [ -z "${2}" ]; then
                    common_logger -e "Arguments contain errors. Probably missing <node-name> after -wi|--wazuh-indexer."
                    getHelp
                    exit 1
                fi
                indexer=1
                indxname="${2}"
                shift 2
                ;;
            "-ws"|"--wazuh-server")
                if [ -z "${2}" ]; then
                    common_logger -e "Error on arguments. Probably missing <node-name> after -ws|--wazuh-server"
                    getHelp
                    exit 1
                fi
                wazuh=1
                winame="${2}"
                shift 2
                ;;
            "-dw"|"--download-wazuh")
                if [ "${2}" != "deb" ] && [ "${2}" != "rpm" ]; then
                    common_logger -e "Error on arguments. Probably missing <deb|rpm> after -dw|--download-wazuh"
                    getHelp
                    exit 1
                fi
                download=1
                package_type="${2}"
                shift 2
                ;;
            "-da"|"--download-arch")
                if [ "${2}" != "amd64" ] && [ "${2}" != "x86_64" ] && [ "${2}" != "arm64" ] && [ "${2}" != "aarch64" ]; then
                    common_logger -e "Error on arguments. Probably missing <amd64|x86_64|arm64|aarch64> after -da|--download-arch"
                    getHelp
                    exit 1
                fi
                download_arch=1
                arch="${2}"
                shift 2
                ;;
            *)
                echo "Unknow option: ${1}"
                getHelp
        esac
    done

    cat /dev/null > "${logfile}"

    if [ -z "${download}" ] && [ -z "${showVersion}" ]; then
        common_checkRoot
    fi

    if [ -n "${showVersion}" ]; then
        common_logger "Wazuh version: ${wazuh_version}"
        common_logger "Filebeat version: ${filebeat_version}"
        common_logger "Wazuh installation assistant version: ${wazuh_install_vesion}"
        exit 0
    fi

    common_logger "Starting Wazuh installation assistant. Wazuh version: ${wazuh_version}"
    common_logger "Verbose logging redirected to ${logfile}"

# -------------- Uninstall case  ------------------------------------

    common_checkSystem

    if [ -z "${download}" ]; then
        check_dist
    fi

    if [ -z "${uninstall}" ] && [ -z "${offline_install}" ]; then
        installCommon_installCheckDependencies
    elif [ -n "${offline_install}" ]; then
        offline_checkPrerequisites "wia_offline_dependencies" "${wia_offline_dependencies[@]}"
    fi

    common_checkInstalled
    checks_arguments
    if [ -n "${development}" ]; then
        checks_filebeatURL
    fi
    if [ -n "${uninstall}" ]; then
        installCommon_rollBack
        exit 0
    fi

    checks_arch
    if [ -n "${ignore}" ]; then
        common_logger -w "Hardware checks ignored."
    else
        common_logger "Verifying that your system meets the recommended minimum hardware requirements."
        checks_health
    fi

# -------------- Preliminary checks and Prerequisites --------------------------------

    if [ -z "${configurations}" ] && [ -z "${AIO}" ] && [ -z "${download}" ]; then
        checks_previousCertificate
    fi

    if [ -n "${port_specified}" ]; then
        checks_available_port "${port_number}" "${wazuh_aio_ports[@]}"
        dashboard_changePort "${port_number}"
    elif [ -n "${AIO}" ] || [ -n "${dashboard}" ]; then
        dashboard_changePort "${http_port}"
    fi

    if [ -n "${AIO}" ]; then
        rm -f "${tar_file}"
        checks_ports "${wazuh_aio_ports[@]}"
        installCommon_installPrerequisites "AIO"
    fi

    if [ -n "${indexer}" ]; then
        checks_ports "${wazuh_indexer_ports[@]}"
        installCommon_installPrerequisites "indexer"
    fi

    if [ -n "${wazuh}" ]; then
        checks_ports "${wazuh_manager_ports[@]}"
        installCommon_installPrerequisites "wazuh"
    fi

    if [ -n "${dashboard}" ]; then
        checks_ports "${wazuh_dashboard_port}"
        installCommon_installPrerequisites "dashboard"
    fi


# --------------  Wazuh repo  ----------------------

    # Offline installation case: extract the compressed files
    if [ -n "${offline_install}" ]; then
        offline_checkPreinstallation
        offline_extractFiles
        offline_importGPGKey
    fi

    if [ -n "${AIO}" ] || [ -n "${indexer}" ] || [ -n "${dashboard}" ] || [ -n "${wazuh}" ]; then
        check_curlVersion
        if [ -z "${offline_install}" ]; then
            installCommon_addWazuhRepo
        fi
    fi

# -------------- Configuration creation case  -----------------------

    # Creation certificate case: Only AIO and -g option can create certificates.
    if [ -n "${configurations}" ] || [ -n "${AIO}" ]; then
        common_logger "--- Configuration files ---"
        installCommon_createInstallFiles
    fi

    if [ -z "${configurations}" ] && [ -z "${download}" ]; then
        installCommon_extractConfig
        config_file="/tmp/wazuh-install-files/config.yml"
        cert_readConfig
    fi

    # Distributed architecture: node names must be different
    if [[ -z "${AIO}" && -z "${download}" && ( -n "${indexer}"  || -n "${dashboard}" || -n "${wazuh}" ) ]]; then
        checks_names
    fi

    if [ -n "${configurations}" ]; then
        installCommon_removeWIADependencies
    fi

# -------------- Wazuh indexer case -------------------------------

    if [ -n "${indexer}" ]; then
        common_logger "--- Wazuh indexer ---"
        indexer_install
        indexer_configure
        installCommon_startService "wazuh-indexer"
        indexer_initialize
        installCommon_removeWIADependencies
    fi

# -------------- Start Wazuh indexer cluster case  ------------------

    if [ -n "${start_indexer_cluster}" ]; then
        indexer_startCluster
        installCommon_changePasswords
        installCommon_removeWIADependencies
    fi

# -------------- Wazuh dashboard case  ------------------------------

    if [ -n "${dashboard}" ]; then
        common_logger "--- Wazuh dashboard ----"
        dashboard_install
        dashboard_configure
        installCommon_startService "wazuh-dashboard"
        installCommon_changePasswords
        dashboard_initialize
        installCommon_removeWIADependencies

    fi

# -------------- Wazuh server case  ---------------------------------------

    if [ -n "${wazuh}" ]; then
        common_logger "--- Wazuh server ---"
        manager_install
        manager_configure
        if [ -n "${server_node_types[*]}" ]; then
            manager_startCluster
        fi
        installCommon_startService "wazuh-manager"
        filebeat_install
        filebeat_configure
        installCommon_changePasswords
        installCommon_startService "filebeat"
        installCommon_removeWIADependencies
    fi

# -------------- AIO case  ------------------------------------------

    if [ -n "${AIO}" ]; then

        common_logger "--- Wazuh indexer ---"
        indexer_install
        indexer_configure
        installCommon_startService "wazuh-indexer"
        indexer_initialize
        common_logger "--- Wazuh server ---"
        manager_install
        manager_configure
        installCommon_startService "wazuh-manager"
        filebeat_install
        filebeat_configure
        installCommon_startService "filebeat"
        common_logger "--- Wazuh dashboard ---"
        dashboard_install
        dashboard_configure
        installCommon_startService "wazuh-dashboard"
        installCommon_changePasswords
        dashboard_initializeAIO
        installCommon_removeWIADependencies

    fi

# -------------- Offline case  ------------------------------------------

    if [ -n "${download}" ]; then
        common_logger "--- Download Packages ---"
        offline_download
    fi


# -------------------------------------------------------------------

    if [ -z "${configurations}" ] && [ -z "${download}" ] && [ -z "${offline_install}" ]; then
        installCommon_restoreWazuhrepo
    fi

    if [ -n "${AIO}" ] || [ -n "${indexer}" ] || [ -n "${dashboard}" ] || [ -n "${wazuh}" ]; then
        eval "rm -rf /tmp/wazuh-install-files ${debug}"
        common_logger "Installation finished."
    elif [ -n "${start_indexer_cluster}" ]; then
        common_logger "Wazuh indexer cluster started."
    fi

}
