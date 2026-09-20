CREATE TABLE device (
  id INTEGER PRIMARY KEY, 
  uhost varchar(255),       /* user assigned name for nd UI */
  utype varchar(32),        /* user assigned type */
  block BOOLEAN default 0  /* block the device? */
);

CREATE TABLE interface (
  mac varchar(17) NOT NULL,
  devid INTEGER NOT NULL,
  dhost varchar(255),       /* last known domain name */     
  gtype varchar(32),        /* guessed type */
  ghost varchar(255),       /* guessed hostname */
  wifi BOOLEAN default 0,   /* if ever seen by wifi station assume its wifi */
  pinned BOOLEAN default 0,
  PRIMARY KEY (mac),
  FOREIGN KEY (devid) REFERENCES device(id) ON DELETE CASCADE
);

