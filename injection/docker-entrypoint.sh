#!/bin/sh
# vim: set noet :

if [ "$1" = 'api' ] ||  [ "$1" = 'dhcp4' ] || [ "$1" = 'dhcp6' ]; then
	set -e

	##############################################################################
	# Default
	##############################################################################

	if [ -z "${ISC_KEA_UID}" ]; then
		ISC_KEA_UID=1000
	fi
	if [ -z "${ISC_KEA_GID}" ]; then
		ISC_KEA_GID=1000
	fi
	if [ -z "${ISC_KEA_DEBUG}" ]; then
		ISC_KEA_DEBUG=0
	fi

	##############################################################################
	# Check
	##############################################################################

	if echo "${ISC_KEA_UID}" | grep -Eqsv '^[0-9]+$'; then
		echo 'Please numric value: ISC_KEA_UID'
		exit 1
	fi
	if [ "${ISC_KEA_UID}" -le 0 ]; then
		echo 'Please 0 or more: ISC_KEA_UID'
		exit 1
	fi
	if [ "${ISC_KEA_UID}" -ge 60000 ]; then
		echo 'Please 60000 or less: ISC_KEA_UID'
		exit 1
	fi

	if echo "${ISC_KEA_GID}" | grep -Eqsv '^[0-9]+$'; then
		echo 'Please numric value: ISC_KEA_GID'
		exit 1
	fi
	if [ "${ISC_KEA_GID}" -le 0 ]; then
		echo 'Please 0 or more: ISC_KEA_GID'
		exit 1
	fi
	if [ "${ISC_KEA_GID}" -ge 60000 ]; then
		echo 'Please 60000 or less: ISC_KEA_GID'
		exit 1
	fi

	if echo "${ISC_KEA_DEBUG}" | grep -Eqsv '^[0-9]$'; then
		echo 'Please 0 or 1: ISC_KEA_DEBUG'
		exit 1
	fi
	if [ "${ISC_KEA_DEBUG}" -lt 0 ] || [ "${ISC_KEA_DEBUG}" -gt 1 ]; then
		echo 'Please 0 or 1: ISC_KEA_DEBUG'
		exit 1
	fi

	##############################################################################
	# Clear
	##############################################################################

	if getent passwd | awk -F ':' -- '{print $1}' | grep -Eqs '^kea$'; then
		deluser 'kea'
	fi
	if getent passwd | awk -F ':' -- '{print $3}' | grep -Eqs "^${ISC_KEA_UID}$"; then
		deluser "${ISC_KEA_UID}"
	fi
	if getent group | awk -F ':' -- '{print $1}' | grep -Eqs '^kea$'; then
		delgroup 'kea'
	fi
	if getent group | awk -F ':' -- '{print $3}' | grep -Eqs "^${ISC_KEA_GID}$"; then
		delgroup "${ISC_KEA_GID}"
	fi

	##############################################################################
	# Group
	##############################################################################

	addgroup -g "${ISC_KEA_GID}" 'kea'

	##############################################################################
	# User
	##############################################################################

	adduser -h '/nonexistent' \
		-g 'kea,,,' \
		-s '/usr/sbin/nologin' \
		-G 'kea' \
		-D \
		-H \
		-u "${ISC_KEA_UID}" \
		'kea'

	##############################################################################
	# Initialize
	##############################################################################

	if [ ! -d "/etc/kea" ]; then
		mkdir -p "/etc/kea"
	fi

	if [ ! -d "/run/kea" ]; then
		mkdir -p "/run/kea"
	fi

	if [ ! -d "/var/lib/kea" ]; then
		mkdir -p "/var/lib/kea"
	fi

	##############################################################################
	# Config
	##############################################################################

	case "$1" in
		'api' )
			dockerize -template /usr/local/etc/kea-ctrl-agent.conf.tmpl:/etc/kea/kea-ctrl-agent.conf
			;;
		'dhcp4' )
			dockerize -template /usr/local/etc/kea-dhcp4.conf.tmpl:/etc/kea/kea-dhcp4.conf
			;;
		'dhcp6' )
			dockerize -template /usr/local/etc/kea-dhcp6.conf.tmpl:/etc/kea/kea-dhcp6.conf
			;;
	esac

	##############################################################################
	# Permission
	##############################################################################

	chown -R kea:kea /etc/kea
	chown -R kea:kea /run/kea
	chown -R kea:kea /var/lib/kea

	##############################################################################
	# Daemon
	##############################################################################

	mkdir -p /etc/sv/ctrl-agent
	{
		echo '#!/bin/sh'
		echo 'set -e'
		echo 'exec 2>&1'
		if [ "${ISC_KEA_DEBUG}" -eq 1 ]; then
			echo 'exec /usr/sbin/kea-ctrl-agent -d -c /etc/kea/kea-ctrl-agent.conf'
		else
			echo 'exec /usr/sbin/kea-ctrl-agent -c /etc/kea/kea-ctrl-agent.conf'
		fi
	} > /etc/sv/ctrl-agent/run
	chmod 0755 /etc/sv/ctrl-agent/run

	mkdir -p /etc/sv/dhcp4
	{
		echo '#!/bin/sh'
		echo 'set -e'
		echo 'exec 2>&1'
		if [ "${ISC_KEA_DEBUG}" -eq 1 ]; then
			echo 'exec /usr/sbin/kea-dhcp4 -d -c /etc/kea/kea-dhcp4.conf'
		else
			echo 'exec /usr/sbin/kea-dhcp4 -c /etc/kea/kea-dhcp4.conf'
		fi
	} > /etc/sv/dhcp4/run
	chmod 0755 /etc/sv/dhcp4/run

	mkdir -p /etc/sv/dhcp6
	{
		echo '#!/bin/sh'
		echo 'set -e'
		echo 'exec 2>&1'
		if [ "${ISC_KEA_DEBUG}" -eq 1 ]; then
			echo 'exec /usr/sbin/kea-dhcp6 -d -c /etc/kea/kea-dhcp6.conf'
		else
			echo 'exec /usr/sbin/kea-dhcp6 -c /etc/kea/kea-dhcp6.conf'
		fi
	} > /etc/sv/dhcp6/run
	chmod 0755 /etc/sv/dhcp6/run

	##############################################################################
	# Service
	##############################################################################

	if [ "$1" = 'api' ]; then
		SERVER_TYPE="API"
		ln -fs /etc/sv/ctrl-agent /etc/service/ctrl-agent
	else
		rm -f /etc/service/ctrl-agent
	fi

	if [ "$1" = 'dhcp4' ]; then
		SERVER_TYPE="DHCPv4"
		ln -fs /etc/sv/dhcp4 /etc/service/dhcp4
	else
		rm -f /etc/service/dhcp4
	fi

	if [ "$1" = 'dhcp6' ]; then
		SERVER_TYPE="DHCPv6"
		ln -fs /etc/sv/dhcp6 /etc/service/dhcp6
	else
		rm -f /etc/service/dhcp6
	fi

	##############################################################################
	# Running
	##############################################################################

	echo "Starting ${SERVER_TYPE} Server"
	exec runsvdir /etc/service
fi

exec "$@"
