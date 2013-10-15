#!/bin/sh
set -e

# make sure $HOME/.ssh exists
if [ ! -d "$HOME/.ssh" ]; then
  debug "$HOME/.ssh does not exists, creating it"
  mkdir -p $HOME/.ssh
fi

known_hosts_path="$HOME/.ssh/known_hosts"

if [ ! -f "$known_hosts_path" ]; then
  debug "$known_hosts_path does not exists, touching it and chmod it to 600"
  touch $known_hosts_path
  chmod 600 $known_hosts_path
fi

if [ ! -w "$known_hosts_path" ]; then
  fail "$known_hosts_path exists, but it not writeable"
fi

# validate <hostname> exists
if [ ! -n "$WERCKER_ADD_TO_KNOWN_HOSTS_HOSTNAME" ]
then
  fail "missing or empty hostname, please check your wercker.yml"
fi

ssh_keyscan_command="ssh-keyscan"

if [ ! -n "$WERCKER_ADD_TO_KNOWN_HOSTS_PORT" ] ; then
    ssh_keyscan_command="$ssh_keyscan_command $WERCKER_ADD_TO_KNOWN_HOSTS_HOSTNAME"
  else
    ssh_keyscan_command="$ssh_keyscan_command -p $WERCKER_ADD_TO_KNOWN_HOSTS_PORT $WERCKER_ADD_TO_KNOWN_HOSTS_HOSTNAME"
fi

ssh_keyscan_result=`$ssh_keyscan_command`

if [ ! -n "$WERCKER_ADD_TO_KNOWN_HOSTS_FINGERPRINT" ] ; then

  echo $ssh_keyscan_result >> $known_hosts_path
  warn "Skipped checking public key with fingerprint, this setup is vulnerable to a man in the middle attack"
  success "Successfully added host $WERCKER_ADD_TO_KNOWN_HOSTS_HOSTNAME to known_hosts"

else

  debug "Searching for keys that match fingerprint $WERCKER_ADD_TO_KNOWN_HOSTS_FINGERPRINT"
  echo $ssh_keyscan_result | sed "/^ *#/d;s/#.*//" | while read ssh_key; do
    ssh_key_path=`mktemp`
    echo $ssh_key > $ssh_key_path
    ssh_key_fingerprint=`ssh-keygen -l -f $ssh_key_path | awk '{print $2}'`
    if [[ "$ssh_key_fingerprint" == *$WERCKER_ADD_TO_KNOWN_HOSTS_FINGERPRINT* ]] ; then
      debug "Added a key to known_hosts"
      echo $ssh_key >> $known_hosts_path
    else
      warn "Skipped adding a key to known_hosts, it did not match the fingerprint ($ssh_key_fingerprint)"
    fi
    rm -f $ssh_key_path
  done

fi
