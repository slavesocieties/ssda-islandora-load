mysql --host=ssda-database.cluster-chjmxiqlhp5k.us-east-1.rds.amazonaws.com --user=ssda --password=b3wr4w9UVQ4yk7BdDSqk2ZWk --database=drupal8 --batch --execute="select destid1 from migrate_map_volume order by 1;" | sed -e 's#^#curl "http://localhost/node/#' | sed -e 's#$#/manifest"#' > /tmp/warm_manifest_cache.sh
mysql --host=ssda-database.cluster-chjmxiqlhp5k.us-east-1.rds.amazonaws.com --user=ssda --password=b3wr4w9UVQ4yk7BdDSqk2ZWk --database=drupal8 --batch --execute="select destid1 from migrate_map_volume order by 1;" | sed -e 's#^#curl "http://localhost/node/#' | sed -e 's#$#/"#' > /tmp/warm_page_cache.sh
bash /tmp/warm_manifest_cache.sh
bash /tmp/warm_page_cache.sh
