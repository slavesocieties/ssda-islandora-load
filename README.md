# ssda-islandora-load



SSDA Load Process

Log in via the command line using SSH:
ssh -i /home/saracarl/.ssh/SSDA-Brumfield.pem ubuntu@52.1.163.15

~ is the home directory of the ubuntu user.  A "cd" will get you there.

You should run "tmux" before running any of the following commands.  This will allow commands to run even if you are disconnected.  To reconnect after logging back in, type "tmux attach".

1)  Read directories and metadata file to generate migration csv files.

cd ~/s3
./import.rb your-directory-name

i.e.:  ./import.rb Cuba/Havana

This will run for hours or days and the result will populate the ~/working directory with data files:  SSDA_volumes.csv, SSDA_collections.csv, SSDA_pages.csv.  It will delete any files that are already there.  You can verify your files with a "ls -l" in ~/working to look at their date.  It won't delete subdirectories of the working directory, so if you'd like to save old CSV files you can make a directory and copy them there.

2)  Load migrations into Islandora from CSVs using 1000 record batches.

cd ~/working
bash run.sh

This will loop through the each type of CSV file
(copy collections to the Islandora data directory, then run the collections migration command, then copies each of the volume CSVs and runs their migration.  For pages it will run 3 migrations -- file, node, media)



3)  Warm manifest and page cache.

