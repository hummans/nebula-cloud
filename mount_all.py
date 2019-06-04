#!/usr/bin/env python3

import os
import posixpath


try:
    import psycopg2
except ImportError:
    log_traceback("Import error")
    critical_error("Unable to import psycopg2")

class DB(object):
    def __init__(self, **kwargs):
        self.conn = psycopg2.connect(**kwargs)
        self.cur = self.conn.cursor()

    def lastid(self):
        self.query("SELECT LASTVAL()")
        return self.fetchall()[0][0]

    def query(self, query, *args):
        self.cur.execute(query, *args)

    def fetchone(self):
        return self.cur.fetchone()

    def fetchall(self):
        return self.cur.fetchall()

    def commit(self):
        self.conn.commit()

    def rollback(self):
        self.conn.rollback()

    def close(self):
        self.conn.close()

    def __len__(self):
        return True



base_dir = os.path.dirname(os.path.realpath(__file__))
sites = []
sites_dir = os.path.join(base_dir, "sites")
for f in os.listdir(sites_dir):
    if not os.path.isdir(os.path.join(sites_dir, f)):
        continue
    sites.append(f)


for site in sites:
    stripname = site.replace("-","")
    db = DB(
            host="localhost",
            user=stripname,
            password="nebula",
            database="nebula_{}".format(stripname)
        )
    db.query("SELECT id, settings FROM storages")
    for id_storage, settings in db.fetchall():
        mountpoint = "/mnt/{}_{:02d}".format(site, id_storage)
        if not os.path.isdir(mountpoint):
            print("Creating mountpoint {}".format(mountpoint))
            os.makedirs(mountpoint)

        if not posixpath.ismount(mountpoint):
            print("Mounting {} storage {}".format(site, id_storage))
            credentials="user={},pass={}".format(
                        settings["login"],
                        settings["password"]
                    )

            cmd="mount.cifs {} {} -o '{}'".format(
                        settings["path"],
                        mountpoint,
                        credentials
                    )
            os.system(cmd)
