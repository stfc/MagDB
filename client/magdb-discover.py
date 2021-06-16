#!/usr/bin/env python2

from os import listdir
from os.path import isfile, isdir, join, dirname
from re import sub
from urllib import urlopen
from subprocess import Popen, PIPE
from configparser import ConfigParser
import fcntl, socket, struct


def getHwAddr(ifname):
    """The pure python solution for this problem under Linux to get the MAC for a specific local interface,
       originally posted as a comment by vishnubob and improved by on Ben Mackey in http://code.activestate.com/recipes/439094-get-the-ip-address-associated-with-a-network-inter/"""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    info = fcntl.ioctl(s.fileno(), 0x8927,  struct.pack('256s', ifname[:15]))
    return ''.join(['%02x:' % ord(char) for char in info[18:24]])[:-1]


def bonding(config):
    try:
        out, err = Popen([config['binaries']['quattor-query'], "/hardware/name"], stdout=PIPE).communicate()
        system_id = out.splitlines()[-1].split("'")[1].replace('system','')
    except:
        system_id = False

    mac_addresses = {}

    if system_id:
        record = {
            "systemId" : system_id,
            "bonds" : {}
        }

        if isdir(config['paths']['bonding']):
            bonds = listdir(config['paths']['bonding'])
            if bonds:
                for bond in bonds:
                    bond_file = join(config['paths']['bonding'],bond)
                    if isfile(bond_file) and 'bond' in bond:
                        # Read bond information and tokenise
                        fh = open(bond_file)
                        data = fh.read()
                        fh.close()
                        data = data.splitlines()
                        data = [ l.split(': ', 1) for l in data ]

                        # Initialise structure
                        sections = [{}]

                        for line in data:
                            if len(line) == 2:
                                key, value = line
                                # Munge the keys slightly
                                key = sub(r'\(.+\)', '', key)
                                key = key.title().replace(' ', '')
                                sections[-1][key] = value
                            else:
                                sections.append({})

                        record["bonds"][bond] = sections

                        # Store the mac addresses behind bonded links for later use
                        for section in sections:
                            if 'PermanentHwAddr' in section:
                                mac_addresses[section['SlaveInterface']] = section['PermanentHwAddr']

                print "Submitting bonding data to MagDB."
                record = str(record).replace("'", '"')
                try:
                    f = urlopen(config['urls']['bonding'], "system="+system_id+"&record="+record)
                    print "MagDB says: " + f.read()
                except IOError:
                    print "Unable to submit results to MagDB"
            else:
                print "No network bonds found."
        else:
            print "No bonding information on system."
    else:
        print "Unable to determine systemId, will not look for network bonds."

    return mac_addresses


def lldp(config, mac_addresses):
    try:
        out, err = Popen([config['binaries']['lldpctl'], "-f", "keyvalue"], stdout=PIPE).communicate()
    except:
        out = False

    if out:
        out = out.split('\n')[:-1]
        data = []

        for line in out:
            if 'via=LLDP' in line:
                data.append({})
            if 'unknown-tlvs' in line:
                continue

            key, value = line.split('=')
            key = key.split('.')[1:]

            leaf = data[-1]
            for k in key[:-1]:
                if k not in leaf:
                    leaf[k] = {}
                leaf = leaf[k]
            leaf[key[-1]] = value.replace("'", "`")

        # Initialise structure
        record = []

        for d in data:
            link = {}
            rid = 0
            for k, v in d.iteritems():
                rid = int(v['rid'])
                # If the port is a member of a bonded link, the apparent mac address may have changed therefore we should use the mac address behind the bond
                if k in mac_addresses:
                    mac = mac_addresses[k]
                else:
                    mac = getHwAddr(k)
                link[mac] = v
                link[mac]['name'] = k
            if rid <= 1:
                record.append(link)

        print "Submitting LLDP data to MagDB."
        record = str(record).replace("'", '"')
        try:
            f = urlopen(config['urls']['lldp'], "record="+record)
            print "MagDB says: " + f.read()
        except IOError:
            print "Unable to submit results to MagDB"
    else:
        print "No LLDP data found."

    print "Complete."


def main():
    config = ConfigParser()
    config.read(['/etc/magdb-discover.conf', join(dirname(__file__), 'magdb-discover.conf')])
    mac_addresses = bonding(config)
    lldp(config, mac_addresses)


if __name__ == "__main__":
    main()
