#!/usr/bin/env bash

# trap signals 0, 2, 3, 15
trap 'exit' EXIT SIGINT SIGQUIT SIGTERM

# Ensure the script is run as root
if [ "$(id -u)" != "0" ]; then
	echo "This script must be run as root" 1>&2
	exit 1
fi

check_docker_group() {
	if getent group docker | grep -q "\b$SUDO_USER\b"; then
		echo "User is already in the docker group."
		return 0
	fi
}

add_user_to_docker_group() {
	if check_docker_group; then
		return 0
	fi
	usermod -aG docker "$SUDO_USER"
	echo "User added to the docker group. "
	read -p "Press Enter to activate the changes or CTRL+C to cancel..."
	newgrp docker
}

check_docker_service() {
	if systemctl is-active --quiet docker; then
		echo "Docker service is already running."
		return 0
	fi
}

ask_enable_docker_service() {
	if ! check_docker_service; then
		echo "Would you like to start and enable Docker? [y/N]"
		read -r response
		if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
			systemctl enable --now docker
			echo "Docker service started and enabled."
		else
			echo "Skipping Docker service start and enable."
		fi
	fi
}

add_docker_repo() {
	if [[ ! -f "/etc/yum.repos.d/docker.repo" ]]; then
		tee -a /etc/yum.repos.d/docker.repo <<-EOF
		[docker-ce-stable]
		name=Docker CE Stable - \$basearch
		baseurl=https://download.docker.com/linux/fedora/\$releasever/\$basearch/stable
		enabled=1
		gpgcheck=1
		gpgkey=https://download.docker.com/linux/fedora/gpg

		[docker-ce-stable-debuginfo]
		name=Docker CE Stable - Debuginfo \$basearch
		baseurl=https://download.docker.com/linux/fedora/\$releasever/debug-\$basearch/stable
		enabled=0
		gpgcheck=1
		gpgkey=https://download.docker.com/linux/fedora/gpg

		[docker-ce-stable-source]
		name=Docker CE Stable - Sources
		baseurl=https://download.docker.com/linux/fedora/\$releasever/source/stable
		enabled=0
		gpgcheck=1
		gpgkey=https://download.docker.com/linux/fedora/gpg
		EOF
	fi
}

check_docker_install() {
	if rpm-ostree status | grep -q "docker"; then
		echo "Docker is already installed."
		ask_enable_docker_service
		add_user_to_docker_group
		exit 0
	fi
}

install_docker() {
	rpm-ostree install \
		docker-ce \
		docker-ce-cli \
		containerd.io \
		docker-buildx-plugin \
		docker-compose-plugin

	echo "Docker packages installed. The system will now reboot to apply changes."
	read -p "Press Enter to continue with the reboot or CTRL+C to cancel..."
	reboot
}

main() {
	check_docker_install
	add_docker_repo
	install_docker
}
main
