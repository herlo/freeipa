#!/bin/bash

# Copyright (C) 2014  Clint Savage <herlo1@gmail.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
# The license is also available at http://www.gnu.org/licenses/gpl-2.0.txt

#
# This code has been tested on FreeIPA version 3.3. If you test this on
# another version, please let me know with a pull request or
# by email <herlo1@gmail.com>.


HOST=192.168.122.200
LDAP_USER="cn=Directory Manager"
LDAP_PW="-w manager72"
LDAP_USERDN="cn=users,cn=accounts"
LDAP_GROUPDN="cn=groups,cn=accounts"
LDAP_BASEDN="dc=example,dc=com"
GIVE_HEAD=" | head"

KLIST="/usr/bin/klist"
IPA="/usr/bin/ipa"
LDAPADD="/usr/bin/ldapadd"
LDAPMODIFy="/usr/bin/ldapmodify"


# test to ensure kerberos principal is in place

${KLIST} 2> /dev/null | grep 'Default principal:'
echo

if [ $? -ne 0 ]; then
    echo "Please kinit before running this program"
    exit 1
fi

USERS=$(ldapsearch -LLL -b ${LDAP_USERDN},${LDAP_BASEDN} '(!(objectclass=mepOriginEntry))' -h ${HOST} -D "${LDAP_USER}" ${LDAP_PW} uid | grep 'uid:' | cut -d' ' -f2 | grep -v '^admin' | head) 
#echo "ldapsearch -LLL -b ${LDAP_USERDN},${LDAP_BASEDN} '(!(objectclass=mepOriginEntry))' -h ${HOST} -D \"${LDAP_USER}\" ${LDAP_PW} uid | grep 'uid:' | cut -d' ' -f2 | grep -v '^admin' | head"

echo ${USERS}

for user in ${USERS}; do

usergid=$(${IPA} user-show ${user} | grep GID | awk -F' ' '{ print $2 }')

cat << EOF > /tmp/${user}groupcreate.ldif
dn: cn=${user},${LDAP_GROUPDN},${LDAP_BASEDN}
objectClass: posixgroup
objectClass: ipaobject
objectClass: mepManagedEntry
objectClass: top
cn: ${user}
gidNumber: ${usergid}
description: User private group for ${user}
mepManagedBy: uid=${user},${LDAP_USERDN},${LDAP_BASEDN}
EOF

cat << EOF > /tmp/${user}usermodify.ldif
dn: uid=${user},${LDAP_USERDN},${LDAP_BASEDN}
changetype: modify
add: objectClass
objectClass: mepOriginEntry
-
add: mepManagedEntry
mepManagedEntry: cn=${user},${LDAP_GROUPDN},${LDAP_BASEDN}
EOF

${LDAPADD} -h ${HOST} -D \"${LDAP_USER}\" ${LDAP_PW} -xf /tmp/${user}groupcreate.ldif
${LDAPMODIFY} -h ${HOST} -D \"${LDAP_USER}\" ${LDAP_PW} -xf /tmp/${user}usermodify.ldif

done
