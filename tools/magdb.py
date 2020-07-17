#!/usr/bin/env python2.6
# coding=utf8
# vi:ts=4:

"""Package containing interfaces to Magdb"""

import sys
import prettytable
import ConfigParser

config = ConfigParser.ConfigParser()
config.read(['/etc/magdb/magdb.conf'])

DEFAULT_DOMAIN = config.get("defaults", "domain")
CS = config.get("database", "sqlalchemy")

class MagdbRecord:
    """Class defining a complete host network record"""
    def __init__(self, id, mac, ip, fqdn):
        """Create and return a Magdb network object, aliases can be added by appending to the aliases property"""
        self.id = id
        self.mac = mac
        self.ip = ip
        self.fqdn = fqdn
        self.aliases = []

    def __str__(self):
        t = prettytable.PrettyTable(("SystemID", "MAC", "IP", "FQDN", "Aliases"))
        als = ""
        for a in self.aliases:
            als += "%s\n%s" % (als, a)

        t.add_row((self.id, self.mac, self.ip, self.fqdn, als))

        result = t.printt()

        if t is not None:
            return(result)
        else:
            return("Nada")

    def __repr__(self):
        return("__ not implemented")


class MagdbError(Exception):
    """Exception class for all Magdb Errors"""
    def __init__(self, value):
        self.value = value

    def __str__(self):
        return repr(self.value)


class Magdb:
    """Class defining an interface to MagDB"""
    def __init__(self, conn_string):
        """Create and return a connected Magdb interface object"""
        from sqlalchemy import create_engine, MetaData, Table, Column, Integer, String
        self.engine = create_engine(conn_string, echo=False)

        self.metadata = MetaData()
        self.metadata.reflect(bind=self.engine)

        self.view = Table("vNetwork2", self.metadata, Column("systemId", Integer), Column("macAddress", Integer), Column("ipAddress", Integer, primary_key=True), Column("fqdn", Integer), autoload_with=self.engine)
        self.view_aliases = Table("vAliases", self.metadata, Column("hostnameId", Integer, primary_key=True), Column("aliasId", Integer, primary_key=True), Column("alias", String), Column("aliasDomian", String), Column("host", String), Column("hostDomain", String), autoload_with=self.engine)

        self.tables = self.metadata.tables
        self.hostnames = Table('hostnames', self.metadata, autoload=True)

        self.aliases = self.tables["aliases"]
        self.systems = self.tables["systems"]
        self.domains = self.tables["domains"]
        self.hostAddresses = self.tables["hostAddresses"]
        self.hostnames = self.tables["hostnames"]
        self.hostnameAliases = self.tables["hostnamesAliases"]
        self.networkInterfaces = self.tables["networkInterfaces"]
        self.networkSubnets = self.tables["networkSubnets"]
        self.vendors = self.tables["vendors"]
        self.racks = self.tables["racks"]
        self.categories = self.tables["categories"]
        self.manufacturers = self.tables["manufacturers"]
        self.ipSurvey = self.tables["ipSurvey"]

        from sqlalchemy.orm import sessionmaker
        Session = sessionmaker(bind=self.engine)

        self.session = Session()

    def split_fqdn(self, fqdn):
        """Split fqdn into a tuple containing (hostname, domain). If domain not present, appends DEFAULT_DOMAIN"""
        result = fqdn.split('.', 1)
        if len(result) == 1:
            result.append(DEFAULT_DOMAIN)
        return((result[0], result[1]))

    def get_hostname(self, fqdn):
        """"""
        h_list = fqdn.split('.', 1)
        if len(h_list) == 1:
            raise MagdbError("Incomplete FQDN provided to get_hostname")
        else:
            d = self.session.query(domains).filter(domains.columns["domainName"] == h_list[1]).first()
            if not d:
                raise MagdbError("Invalid domain passed as part of fqdn to get_hostname")
            else:
                h = self.session.query(view).filter(self.view.columns["fqdn"] == h_list[0] + '.' + h_list[1]).first()
                if h:
                    raise MagdbError("Hostname %s already exists in database" % (hostname))
                else:
                    return(h_list[0], d.id)

    def info_host(self, fqdn):
        """Return info on specified host and any aliases that target it. Returns None if no host matching fqdn is found."""
        h, d = self.split_fqdn(fqdn)
        fqdn = "%s.%s" % (h, d)
        result = None

        vn = self.session.query(self.view).filter(self.view.columns["fqdn"] == fqdn).first()
        if vn:
            result = MagdbRecord(vn[0], vn[1], vn[2], vn[3])

            hostname = self.session.query(self.hostnames).filter(self.domains.columns["id"] == self.hostnames.columns["domainId"]).filter(self.domains.columns["domainName"] == d).filter(self.hostnames.columns["name"] == h).first()
            aliases = self.session.query(self.view_aliases).filter(self.view_aliases.columns["hostnameId"] == hostname.id).all()

            if aliases:
                for a in aliases:
                    result.aliases.append(a.alias + "." + a.aliasDomian)

            return(result)
        else:
            return(None)

    def info_alias(self, fqdn):
        """"""
        h, d = self.split_fqdn(fqdn)
        fqdn = "%s.%s" % (h, d)

        try:
            alias = self.session.query(view_aliases).filter(self.view_aliases.columns["alias"] == h).filter(self.view_aliases.columns["aliasDomian"] == d).first()
            print "hostname: " + alias.host + '.' + alias.hostDomain
        except:
            print("Alias not found")
            sys.exit(3)

    def info_ip(self, ip):
        """"""
        try:
            vn = self.session.query(view).filter(self.view.columns["ipAddress"] == ip).all()
            if vn is not None:
                for v in vn:
                    print("\t%s\t%s\t%s\t%s" % v)
            else:
                print("IP not found")
        except:
            print("Invalid IP")
            sys.exit(3)

    def update_host(self, current_fqdn, new_fqdn):
        """"""
        c_h, c_d = self.split_fqdn(current_fqdn)
        current_fqdn = "%s.%s" % (c_h, c_d)

        old_hostname = self.session.query(hostnames).filter(domains.columns["id"] == hostnames.columns["domainId"]).filter(domains.columns["domainName"] == h_list[1]).filter(hostnames.columns["name"] == c_h).first()
        if not old_hostname:
            raise MagdbError("Hostname does not exist")

        (new_name, domain_id) = get_hostname(new_fqdn)

        operation = update(hostnames, hostnames.columns["id"] == old_hostname.id, values={hostnames.columns["name"]: new_name, hostnames.columns["domainId"]: domain_id, hostnames.columns["lastUpdatedBy"]: user_name})

        try:
            self.session.execute(operation)
        except:
            raise MagdbError("Database operation failed")

    def update_ip(self, current_ip, new_ip):
        """"""
        try:
            old_host_address = self.session.query(hostAddresses).filter(hostAddresses.columns["ipAddress"] == current_ip).first()
            if not old_host_address:
                raise MagdbError("IP not found")
        except:
            raise MagdbError("Invalid IP")

        try:
            operation = update(
                hostAddresses,
                hostAddresses.columns["id"] == old_host_address.id,
                values={
                    hostAddresses.columns["ipAddress"]: new_ip,
                    hostAddresses.columns["lastUpdatedBy"]: user_name
                }
            )
            self.session.execute(operation)
        except:
            raise MagdbError("Dodgy IP while performing DB operation")

    def add_ip(self, ip, mac):
        """Find interface with specified mac and allocate IP to it, returns nothing, throws MagdbError if problems occur"""
        try:
            network_inter = self.session.query(self.networkInterfaces).filter(self.networkInterfaces.columns["macAddress"] == mac.lower()).first()
            if not network_inter:
                return(False)
        except:
            raise MagdbError("Malformed MAC address")

        insert_stmt = self.hostAddresses.insert(
            values={
                self.hostAddresses.columns["ipAddress"]: ip,
                self.hostAddresses.columns["networkInterfaceId"]: network_inter.id
            }
        )

        if self.session.execute(insert_stmt):
            return(True)

    def add_host(self, fqdn, ip, user_name):
        """"""
        host_address = self.session.query(self.hostAddresses).filter(self.hostAddresses.columns["ipAddress"] == ip).first()
        if not host_address:
            print 'specified ip address does not exist'
            return(False)
        # except:
        #    print 'wrong ip address'
        #    return(False)

        h_list = fqdn.split('.', 1)
        if len(h_list) == 1:
            print 'Wrong hostname name.domain'
            return(False)

        d = self.session.query(self.domains).filter(self.domains.columns["domainName"] == h_list[1]).first()
        if not d:
            print "Domain " + h_list[1] + " does not exist"
            return(False)

        c = self.hostnames.columns
        insert_stmt = self.hostnames.insert(
            values={
                c["name"]: h_list[0],
                c["hostAddressId"]: host_address.id,
                c["domainId"]: d.id,
                c["lastUpdatedBy"]: user_name
            }
        )
        self.session.execute(insert_stmt)
        return(True)

    def add_alias(self, fqdn_alias, fqdn_target, user_name):
        """"""
        h_list = fqdn_target.split('.', 1)
        if len(h_list) == 1:
            h_list.append(DEFAULT_DOMAIN)

        hostname = self.session.query(self.tables["hostnames"]).filter(self.tables["domains"].columns["id"] == self.tables["hostnames"].columns["domainId"]).filter(self.tables["domains"].columns["domainName"] == h_list[1]).filter(self.tables["hostnames"].columns["name"] == h_list[0]).first()
        if not hostname:
            print 'specified hostname does not exist'
            return(False)

        a_list = fqdn_alias.split('.', 1)
        if len(a_list) == 1:
            print 'Wrong alias name name.domain'
            return(False)

        d = self.session.query(self.tables["domains"]).filter(self.tables["domains"].columns["domainName"] == a_list[1]).first()
        if not d:
            print "Domain " + h_list[1] + " does not exist"
            sys.exit(3)

        try:
            insert_stmt = self.tables["aliases"].insert(values={self.tables["aliases"].columns["name"]: a_list[0], self.tables["aliases"].columns["domainId"]: d.id, self.tables["hostnames"].columns["lastUpdatedBy"]: user_name})
            print insert_stmt
            self.session.execute(insert_stmt)
            self.session.commit()

            new_alias = self.session.query(self.tables['aliases']).filter(self.tables['aliases'].columns['domainId'] == d.id).filter(self.tables['aliases'].columns['name'] == a_list[0]).first()

            insert_stmt = self.tables["hostnamesAliases"].insert(values={self.tables["hostnamesAliases"].columns["hostnameId"]: hostname.id, self.tables["hostnamesAliases"].columns["aliasId"]: new_alias.id, tables["hostnames"].columns["lastUpdatedBy"]: user_name})
            print insert_stmt
            self.session.execute(insert_stmt)
            self.session.commit()
            return(True)
        except:
            print("Error - wrong alias name  %s %s %s" % sys.exc_info())
            return(False)

    def remove_host(self, fqdn, cascade):
        """"""
        if target:
            h_list = target.split('.', 1)
            if len(h_list) == 1:
                h_list.append(DEFAULT_DOMAIN)

            old_hostname = self.session.query(hostnames).filter(domains.columns["id"] == hostnames.columns["domainId"]).filter(domains.columns["domainName"] == h_list[1]).filter(hostnames.columns["name"] == h_list[0]).first()

            if old_hostname:

                aliases = self.session.query(view_aliases).filter(self.view_aliases.columns["hostnameId"] == old_hostname.id).all()

                if not aliases or (aliases and cascade):
                    try:
                        delete_stmt = delete(hostnames, hostnames.columns["id"] == old_hostname.id)
                        self.session.execute(delete_stmt)
                    except:
                        print "Error on delete"
                        sys.exit(3)
                else:
                    print 'to delete a hostname with all connected aliases specify --cascade'
                    sys.exit(3)
            else:
                print "No such hostname"
                sys.exit(3)

    def remove_alias(self, fqdn):
        """"""
        if fqdn:
            h_list = fqdn.split('.', 1)

            if len(h_list) == 1:
                h_list.append(DEFAULT_DOMAIN)

            old_alias = self.session.query(aliases).filter(domains.columns["id"] == aliases.columns["domainId"]).filter(domains.columns["domainName"] == h_list[1]).filter(aliases.columns["name"] == h_list[0]).first()

            if old_alias:
                try:
                    delete_stmt = delete(aliases, aliases.columns["id"] == old_alias.id)
                    self.session.execute(delete_stmt)
                except:
                    print "Error on delete"
                    sys.exit(3)
            else:
                return(False)

    def remove_ip(self, ip, cascade):
        """"""
        try:
            old_host_address = self.session.query(hostAddresses).filter(hostAddresses.columns["ipAddress"] == target).first()
        except:
            print 'wrong ip address'
            sys.exit(3)

        if old_host_address:
            vn = self.session.query(view).filter(self.view.columns["ipAddress"] == target).all()
            if not vn or (vn and cascade):
                try:
                    delete_stmt = delete(hostAddresses, hostAddresses.columns["id"] == old_host_address.id)
                    self.session.execute(delete_stmt)
                    return(True)
                except:
                    print "Error on delete"
                    sys.exit(3)
            else:
                print 'to delete ip address which has hostname(s) type --cascade'
                sys.exit(3)
        else:
            print "No such IP address in database"
            sys.exit(3)

    def saw_ip(self, ip):
        """Mark IP as last seen at current timestamp"""
        from sqlalchemy.exc import IntegrityError
        c = self.ipSurvey.columns
        v = {
            c["ipAddress"]: ip,
            c["lastSeen"]: "now()",
        }
        # Update if already in table, otherwise insert new row
        if self.session.execute(self.ipSurvey.update(c["ipAddress"] == ip, values=v)).rowcount == 0:
            self.session.execute(self.ipSurvey.insert(values=v))
