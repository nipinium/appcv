-- +micrate Up
CREATE TABLE ysusers (
  id bigserial primary key,

  zname text unique not null,
  vname text not null,

  like_count int not null default 0,
  list_count int not null default 0,
  crit_count int not null default 0,

  created_at timestamptz not null default CURRENT_TIMESTAMP,
  updated_at timestamptz not null default CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX ysuser_zname_idx ON ysusers (zname);


-- +micrate Down
DROP TABLE IF EXISTS ysusers;
