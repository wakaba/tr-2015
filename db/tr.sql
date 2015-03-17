CREATE TABLE IF NOT EXISTS `repo_owner` (
  `repo_url` VARBINARY(511) NOT NULL,
  account_id BIGINT UNSIGNED NOT NULL,
  created DOUBLE NOT NULL,
  PRIMARY KEY (repo_url),
  KEY (account_id, created),
  KEY (created)
) DEFAULT CHARSET=BINARY ENGINE=InnoDB;
