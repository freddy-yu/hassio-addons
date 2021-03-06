#!/bin/bash
options="/data/options.json"
[[ $(jq -r '.debug' $options) == "true" ]] && set -x
auto_download=$(jq -r '.auto_download' $options)
cmd_num=$(jq -r '.cmd | length' $options)
version=$(jq -r '.frp_version' $options)
[[ "$auto_download" == "true" ]] && remote_version=$(curl -Ls https://api.github.com/repos/fatedier/frp/releases/latest | jq -r '.tag_name' | sed 's/v//')
[[ "$version" == "null" ]] || [[ "$version" == "" ]] && version=$remote_version

app_path="/share/frp"
app_root_path=${app_path%/*}
arch=$(uname -m)
frp_url="https://github.com/fatedier/frp/releases/download/"

select_machine(){
	case $arch in
		"i386" | "i686" | "x86_64")
			if [[ $(getconf LONG_BIT) == "64" ]]; then
				machine="amd64"
			else
				machine="386"
			fi
		;;
		"arm"* | "armv7l" | "armv61" | "aarch64")
			if [[ $(getconf LONG_BIT) == "64" ]]; then
				machine="arm64"
			else
				machine="arm"
			fi
		;;
		*)
			echo "[Error] $arch unknown!"
			exit 1
		;;
	esac
}

download(){
	local i=10
	while [[ ! -f $2 ]]; do
		# wget --no-check-certificate  "$1" -O "$2"
		echo "[info]: Start downloading file $2"
		wget --no-check-certificate "$1" -O /tmp/tmp_file
		# curl -o "$2" -sSL "$1"
		[[ $? -eq 0 ]] || [[ $i -eq 0 ]] && break
		let i--
	done
	[[ ! -f /tmp/tmp_file ]] && [[ ! -f $2 ]] && echo "[Error]: Unreachable address $1 " && exit 1
	[[ ! -f $2 ]] && mv /tmp/tmp_file $2
}

# frp download
frp_install(){
	mkdir -p $app_path
	## frp install
	select_machine
	## download
	local file_name="frp_${version}_linux_${machine}.tar.gz"
	local file_path="${app_root_path}/${file_name}"
	local file_dir=$(echo ${file_name} | sed 's/.tar.gz//')
	download "${frp_url}v${version}/${file_name}" ${file_path}
	tar xzf ${file_path} -C $app_root_path
	cp -f ${app_root_path}/${file_dir}/frps ${app_path}/
	cp -f ${app_root_path}/${file_dir}/frpc ${app_path}/
	cp -f ${app_root_path}/${file_dir}/frpc_full.ini ${app_path}/
	cp -f ${app_root_path}/${file_dir}/frps_full.ini ${app_path}/
	[[ ! -f "${app_path}/frps.ini" ]] && cp ${app_root_path}/${file_dir}/frps.ini ${app_path}/
	[[ ! -f "${app_path}/frpc.ini" ]] && cp ${app_root_path}/${file_dir}/frpc.ini ${app_path}/
	rm -rf ${app_root_path}/${file_dir}
	rm -f ${file_path}
}

# check_installed
auto_install(){
	if [[ -f $app_path/frps ]] || [[ -f $app_path/frpc ]]; then
		local_version=$(if [[ -f $app_path/frps ]];then
							 $app_path/frps --version
						else
							 $app_path/frpc --version
						fi)
		# check_change_version
		if [[ "$version" != "$local_version" ]]; then
			cp -R $app_path "${app_root_path}/frp_${local_version}"
			frp_install
		fi
	else
		echo "[info]: The frp file was not found and the installation process started."
		frp_install
	fi
}

[[ "$auto_download" == "true" ]] && auto_install

# run shell
for (( i = 0; i < $cmd_num; i++ )); do
	bash -c "$(jq -r ".cmd[$i]" $options)"
done
