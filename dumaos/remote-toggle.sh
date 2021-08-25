# (C) NETDUMA Software 2020

tmpfile="$(mktemp)"
destfile="$(mktemp)"
tmpdir="$(mktemp -d)"
finaldir="$(mktemp -d)"
usage="Usage: $0 <remote_url> <passphrase> <public_key>"

function cleanup(){
	rm -r $tmpfile
	rm -r $tmpdir
	rm -r $destfile
	rm -r $finaldir
}

function check_exit(){
	if [ "0" != "$?" ]; then
		logger -t telemetry-daemon -p daemon.err -s $1
		cleanup
		exit 1
	fi
}

#Check parameters
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
	logger -t telemetry-daemon -p daemon.err -s "Missing parameters for remote-toggle.sh. $usage"
	exit 1
fi

#check required packages exist exist
which openssl &> /dev/null
check_exit "OpenSSL not found"

which tar &> /dev/null
check_exit "Tar not found"

which cat &> /dev/null
check_exit "Cat not found"

curl --help &> /dev/null
check_exit "CURL not found"

#Download the remote file
curl -XGET $1 --output $tmpfile &> /dev/null
check_exit "Curl failed to download $1 into $tmpfile"

tar -xf $tmpfile -C $tmpdir &> /dev/null
check_exit "Tar failed to extract $tmpfile into $tmpdir"

openssl dgst -sha256 -verify $3 -signature "$tmpdir/payload.sig" "$tmpdir/payload" &> /dev/null
check_exit "Failed to verify signature"

openssl enc -d -aes256 -in "$tmpdir/payload" -k $2 -out $destfile &> /dev/null
check_exit "Failed to decrypt openssl payload"

tar -C $finaldir -xf $destfile &> /dev/null
check_exit "Failed to untar final payload"

cat "$finaldir/remote_rules.json"
check_exit "Failed to print json"

cleanup

exit 0