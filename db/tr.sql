CREATE TABLE IF NOT EXISTS `repo` (
  `repo_url` VARBINARY(511) NOT NULL,
  is_public BOOLEAN NOT NULL,
  created DOUBLE NOT NULL,
  updated DOUBLE NOT NULL,
  PRIMARY KEY (repo_url),
  KEY (created),
  KEY (updated)
) DEFAULT CHARSET=BINARY ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS `repo_access` (
  `repo_url` VARBINARY(511) NOT NULL,
  account_id BIGINT UNSIGNED NOT NULL,
  is_owner BOOLEAN NOT NULL,
  `data` MEDIUMBLOB NOT NULL,
  created DOUBLE NOT NULL,
  updated DOUBLE NOT NULL,
  PRIMARY KEY (repo_url, account_id),
  KEY (account_id, created),
  KEY (created),
  KEY (updated)
) DEFAULT CHARSET=BINARY ENGINE=InnoDB;
