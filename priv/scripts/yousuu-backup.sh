#! /bin/bash

DIR=_db/yousuu
SSH=nipin@ssh.chivi.xyz:srv/chivi.xyz

rsync -azui --no-p "$SSH/$DIR/_proxy/.works" "$DIR/_proxy"
rsync -azui --no-p "$SSH/$DIR/infos" "$DIR"
rsync -azui --no-p "$SSH/$DIR/crits" "$DIR"
