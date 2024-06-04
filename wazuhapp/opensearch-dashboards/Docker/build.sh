#!/bin/bash

set -ex

# Script parameters
wazuh_branch=$1
checksum=$2
app_revision=$3

# Paths
plugin_platform_dir="/tmp/antest/OpenSearch-Dashboards"
source_dir="${plugin_platform_dir}/plugins/wazuh"
build_dir="${source_dir}/build"
destination_dir="/lancs_dashboard"
checksum_dir="/var/local/checksum"
git_clone_tmp_dir="/tmp/lancs_dashboard"

# Repositories URLs
wazuh_app_raw_repo_url="https://raw.githubusercontent.com/wazuh/wazuh-dashboard-plugins"
plugin_platform_app_raw_repo_url="https://raw.githubusercontent.com/opensearch-project/OpenSearch-Dashboards"

# Script vars
wazuh_version=""
plugin_platform_version=""
plugin_platform_yarn_version=""
plugin_platform_node_version=""

change_node_version () {
    installed_node_version="$(node -v)"
    node_version=$1

    n ${node_version}

    if [[ "${installed_node_version}" != "v${node_version}" ]]; then
        mv /usr/local/bin/node /usr/bin
        mv /usr/local/bin/npm /usr/bin
        mv /usr/local/bin/npx /usr/bin
    fi

    echo "Using $(node -v) node version"
}

prepare_env() {
# Lay 2 file o trong repo wazuh-dashborad-plugin
    echo "Using local package.json and .nvmrc from /tmp directory"

    if [ ! -f /tmp/ahihi/package.json ]; then
        echo "Error: /tmp/lancs_dashboard/plugins/main/package.json not found."
        exit 1
    fi

    if [ ! -f /tmp/ahihi/nvmrc ]; then
        echo "Error: /tmp/.nvmrc not found."
        exit 1
    fi

    wazuh_version=$(python -c 'import json, os; f=open("/tmp/ahihi/package.json"); pkg=json.load(f); f.close(); print(pkg["version"])')
    plugin_platform_version=$(python -c 'import json, os; f=open("/tmp/ahihi/package.json"); pkg=json.load(f); f.close(); plugin_platform_version=pkg.get("pluginPlatform", {}).get("version"); print(plugin_platform_version)')

# Lay 2 file trong opensearch-dashborad
    plugin_platform_node_version=$(cat /tmp/ahihi/nvmrc)
    plugin_platform_node_version="v18.20.3"
    echo "Using local OpenSearch-Dashboards package.json from /tmp directory"
    if [ ! -f /tmp/antest/OpenSearch-Dashboards/package.json ]; then
        echo "Error: /tmp/antest/OpenSearch-Dashboards/package.json not found."
        exit 1
    fi

    plugin_platform_yarn_version=$(python -c 'import json, os; f=open("/tmp/antest/OpenSearch-Dashboards/package.json"); pkg=json.load(f); f.close(); print(str(pkg["engines"]["yarn"]).replace("^",""))')
    plugin_platform_yarn_version="1.22.19"
}

download_plugin_platform_sources() {
    echo "Using existing OpenSearch-Dashboards source code from /tmp directory"
    if [ ! -d ${plugin_platform_dir} ]; then
        echo "Error: opensearch directory not found."
        exit 1
    fi
}

install_dependencies () {
    cd ${plugin_platform_dir}
    change_node_version $plugin_platform_node_version
    npm install -g "yarn@${plugin_platform_yarn_version}"

    sed -i 's/node scripts\/build_ts_refs/node scripts\/build_ts_refs --allow-root/' ${plugin_platform_dir}/package.json
    sed -i 's/node scripts\/register_git_hook/node scripts\/register_git_hook --allow-root/' ${plugin_platform_dir}/package.json
    ls /tmp/antest
    yarn osd bootstrap --skip-opensearch-dashboards-plugins
}

download_wazuh_app_sources() {
    echo "Using existing Wazuh source code from /tmp directory"
    if [ ! -d ${git_clone_tmp_dir} ]; then
        echo "Error: ${git_clone_tmp_dir} directory not found."
        exit 1
    fi

    cp -r ${git_clone_tmp_dir}/plugins/main ${source_dir}
}

build_package(){
    cd $source_dir

    # Set pkg name
    if [ -z "${app_revision}" ]; then
        wazuh_app_pkg_name="wazuh-${wazuh_version}.zip"
    else
        wazuh_app_pkg_name="wazuh-${wazuh_version}-${app_revision}.zip"
    fi

    # Build the package
    yarn
    OPENSEARCH_DASHBOARDS_VERSION=${plugin_platform_version} yarn build --deb --skip-archives --allow-root

    find ${build_dir} -name "*.zip" -exec mv {} ${destination_dir}/${wazuh_app_pkg_name} \;

    if [ "${checksum}" = "yes" ]; then
        cd ${destination_dir} && sha512sum "${wazuh_app_pkg_name}" > "${checksum_dir}/${wazuh_app_pkg_name}".sha512
    fi

    exit 0
}

prepare_env
download_plugin_platform_sources
install_dependencies
#download_wazuh_app_sources
build_package
