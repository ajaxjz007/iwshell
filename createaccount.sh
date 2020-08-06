#!/bin/bash
iwserver="127.0.0.1";                    # IceWarp server IP/host
adminemail="admin@domain";               # IceWarp administrator email
adminpass="PassWord";                    # IceWarp administrator password
domain="domain.com"                      # IceWarp domain in which accounts will be created

ctimeout="10";                                # curl connection timeout in seconds
logpath="./logs/";                            # script logpath
logfile="`date +%Y%m%d`-user_create.log";     # script logfile

function log {
  echo $(date +%H:%M:%S) $1 >> ${logpath}/${logfile}
  echo $1
}

# Create log folder if it doesn't exist
mkdir -p "${logpath}"


# Authenticate to IceWarp server

log "Authenticating to IceWarp."

iwsid_request="<iq uid=\"1\" format=\"text/xml\"> \
    <query xmlns=\"admin:iq:rpc\" > \
      <commandname>authenticate</commandname> \
      <commandparams> \
        <authtype>0</authtype> \
        <email>${adminemail}</email> \
        <password>${adminpass}</password> \
        <persistentlogin>0</persistentlogin> \
      </commandparams> \
    </query> \
  </iq>"

iwauth="$(curl -s --connect-timeout ${ctimeout} -m ${ctimeout} -ikL --data-binary "${iwsid_request}" "https://${iwserver}/icewarpapi/")"
authcheck="$(echo ${iwauth} | egrep -o "<result>(.*)</result>" | sed -r s'|<result>(.*)</result>|\1|')"
iwsid="$(echo ${iwauth} | egrep -o "sid=\"(.*)\"" | sed -r s'|sid=\"(.*)\"|\1|')"

if [ "$authcheck" != "1" ]
then
  log "Authentication to IceWarp failed."
else
  log "Authentication to IceWarp successful."
fi


# Read CSV file and create user account in IceWarp for each line

{ while IFS=';' read user pass name
do

iw_create_account="<iq format=\"application/xml\" type=\"set\" sid=\"${iwsid}\"> \
    <query xmlns=\"admin:iq:rpc\"> \
      <commandname>createaccount</commandname> \
      <commandparams> \
        <domainstr>${domain}</domainstr> \
        <accountproperties> \
          <item> \
            <apiproperty> \
              <propname>u_type</propname> \
            </apiproperty> \
            <propertyval> \
              <classname>tpropertystring</classname> \
              <val>0</val> \
            </propertyval> \
          </item> \
          <item> \
            <apiproperty> \
              <propname>u_mailbox</propname> \
            </apiproperty> \
            <propertyval> \
              <classname>tpropertystring</classname> \
              <val>${user}</val> \
            </propertyval> \
          </item> \
          <item> \
            <apiproperty> \
              <propname>a_name</propname> \
            </apiproperty> \
            <propertyval> \
              <classname>taccountname</classname> \
              <name></name> \
              <surname>${name}</surname> \
            </propertyval> \
          </item> \
          <item> \
            <apiproperty> \
              <propname>u_password</propname> \
            </apiproperty> \
            <propertyval> \
              <classname>tpropertystring</classname> \
              <val>${pass}</val> \
            </propertyval> \
          </item> \
        </accountproperties> \
      </commandparams> \
    </query> \
  </iq>"

createuser="$(curl -s --connect-timeout ${ctimeout} -m ${ctimeout} -ikL --data-binary "${iw_create_account}" "https://${iwserver}/icewarpapi/" | egrep -o "<result>(.*)</result>" | sed -r s'|<result>(.*)</result>|\1|')"

if [ "$createuser" != "1" ]
then
  log "Creating account ${user}@${domain} failed."
else
  log "Created account ${user}@${domain}."
fi

done
} < accounts.txt
