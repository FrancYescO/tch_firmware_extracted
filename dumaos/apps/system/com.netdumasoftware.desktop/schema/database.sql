CREATE TABLE panel (
  package varchar(255) NOT NULL,    /* package reverse domain ID */
  url varchar NOT NULL, /* url to panel html file */
  data varchar NOT NULL, /* data in JSON format */
  colsize INTEGER,  /* desired column size */
  rowsize INTEGER, /* desired row size */
  PRIMARY KEY( package, url, data )
);

CREATE TABLE notifications (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title varchar(255) NOT NULL,
  icon varchar(255),
  package varchar(255) NOT NULL,
  description varchar NOT NULL,
  data varchar NOT NULL
);
