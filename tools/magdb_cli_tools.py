#!/usr/bin/python2.6

import re
import readline
import prettytable
import socket
from socket import gethostbyname_ex, gethostbyaddr

RE_MAC = re.compile("([a-fA-F0-9]{2}:?){6}")
RE_FQDN = re.compile("^[a-zA-Z0-9\-.]{1,}$")


def get(m, name, table, column):
    i = raw_input("> ")
    if i == "?":
        t = prettytable.PrettyTable(table.columns.keys())
        q = m.session.query(table)
        for e in q.all():
            t.add_row(e)
        t.printt()
        return(None)
    return(i)


def valid(m, name, table, column, i):
    r = m.session.query(table).filter(column == i).first()
    if r is None:
        print("ERROR: %s %s not found, try again" % (name.title(), i))
    return(r)


def getValid(m, name, table, column):
    r = None
    while r is None:
        i = get(m, name, table, column)
        if i is not None:
            r = valid(m, name, table, column, i)
            return(r)


def getInteger(lower, upper):
    invalid = True
    while invalid:
        i = raw_input("> ")
        try:
            r = int(i)
            if (r is not None) and (lower <= r <= upper):
                invalid = False
            else:
                print("ERROR: Input must be between %i and %i" % (lower, upper))
        except ValueError:
            print("ERROR: Input must be an integer between %i and %i" % (lower, upper))
    print("OK")
    return(r)


def unused(m, name, table, column, i):
    try:
        r = m.session.query(table).filter(column == i).first()
        if r is None:
            return(i)
        else:
            print("ERROR: %s is in use, please specify another" % name)
    except sqlalchemy.exc.DataError:
        print("ERROR: Must be a valid %s" % name)
        m.session.rollback()

    return(None)


def getUnused(m, name, table, column, acceptable=""):
    invalid = True
    while invalid:
        i = raw_input("> ")
        if i == "?":
            print(acceptable)
        else:
            i = unused(m, name, table, column, i)
            if i:
                invalid = False
    print("OK")
    return(i)


def getMAC(m):
    mac = ""
    invalid = True
    while invalid:
        mac = getUnused(m, "MAC address", m.networkInterfaces, m.networkInterfaces.columns["macAddress"])
        if RE_MAC.match(mac):
            invalid = False
    return(mac)


def getIP(m, acceptable):
    invalid = True
    while invalid:
        ip = getUnused(m, "IP address", m.hostAddresses, m.hostAddresses.columns["ipAddress"], acceptable)
        try:
            socket.inet_aton(ip)
            subs = m.session.query(m.networkSubnets).filter('\'%s\' << "ipAddress"' % ip).all()
            for s in subs:
                print(s.name)
            if len(subs) > 0:
                invalid = False
            else:
                print("ERROR: IP not in any valid subnets")
        except socket.error:
            print("ERROR: Input must be a valid IP address")
    print("OK: Accepted IP %s" % ip)

    dns_entry = None
    try:
        dns_entry = gethostbyaddr(ip)
    except:
        pass

    if dns_entry:
        print("WARNING: Existing reverse DNS entry for IP %s - %s" % (dns_entry[0], dns_entry[2]))
    return(ip)


def getFQDN(m, acceptable):
    invalid = True
    while invalid:
        f = getUnused(m, "FQDN", m.view, m.view.columns["fqdn"], acceptable)
        if RE_FQDN.match(f):
            h, d = m.split_fqdn(f)
            r = m.session.query(m.domains).filter(m.domains.columns["domainName"] == d).first()
            if r:
                f = "%s.%s" % (h, d)
                invalid = False
            else:
                print("ERROR: %s is not a supported domain" % d)
    print("OK: Accepted FQDN %s" % f)

    dns_entry = None
    try:
        dns_entry = gethostbyname_ex(f)
    except:
        pass
    if dns_entry:
        print("WARNING: Existing DNS entry for FQDN %s - %s" % (dns_entry[0], dns_entry[2]))
    return(f)


def printRecord(record):
    t = prettytable.PrettyTable(record.keys())
    t.add_row(record)
    t.printt()
