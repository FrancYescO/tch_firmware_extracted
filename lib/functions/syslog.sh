system_get_log_ip()
{
        get_log_ip_cb()
        {
                config_get $2 $1 log_ip
        }

        config_foreach get_log_ip_cb system "$@"
}

system_get_log_filter_ip()
{
        get_log_filter_ip_cb()
        {
                config_get $2 $1 log_filter_ip
        }

        config_foreach get_log_filter_ip_cb system "$@"
}

get_syslog_iface()
{
        syslog_iface=${2:-wan}
        [ -f $IPKG_INSTROOT/usr/lib/mwan/functions.sh ] && \
        [ -f /etc/config/mwan ] && \
        [ "$(wc -l /etc/config/mwan | cut -d ' ' -f 1)" -gt 0 ] && {
                local syslog_ip
                config_load system
                system_get_log_ip syslog_ip
                [ -n "$syslog_ip" ] || {
	                system_get_log_filter_ip syslog_ip
                }

                config_load mwan
                local policy

		. $IPKG_INSTROOT/usr/lib/mwan/functions.sh
                mwan_get_dest_ip_policy policy "$syslog_ip"
                [ -n "$policy" ] && {
                        config_get syslog_iface $policy interface "$syslog_iface"
                }
        }
        eval echo "$1=$syslog_iface"
}
