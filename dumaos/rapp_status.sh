running_rapps=$(ubus list | grep duma)
pass=0
fail=0
for rapp in $running_rapps; do
        if [ "$rapp" = "com.netdumasoftware.burstwatch" ]; then
                continue
        elif [ "$rapp" = "com.netdumasoftware.datahistory" ]; then
                continue
        fi
        rpc_capable=$(ubus -v list $rapp | grep rpc)
        if [ "$rpc_capable" ]; then
                if ubus call $rapp rpc '{"proc":"__watchdog"}' &>/dev/null; then
                        pass=$((pass+1))
                else
                        fail=$((fail+1))
                fi
        fi
done
echo "PASS:$pass"
echo "FAIL:$fail"

